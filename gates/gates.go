// Package gates implements GB_GATES from Stanford GraphBase.
//
// Six routines are provided:
//   - Risc(regs)          – directed acyclic graph for a simple RISC CPU
//   - Prod(m,n)           – directed acyclic graph for parallel multiplication
//   - PrintGates(g)       – print a symbolic representation to stdout
//   - GateEval(g,in,out)  – evaluate gate values
//   - PartialGates(g,…)   – reduce network by fixing some inputs
//   - RunRisc(g,rom,…)    – simulate the RISC CPU
//
// Vertex utility fields (UtilTypes "ZZZIIVZZZZZZZA"):
//
//	X = val  (int64: 0 or 1 boolean value)
//	Y = typ  (int64: ASCII gate type: 'I','&','|','^','~','L','C','=')
//	Z = alt  (any: *Vertex for latch/NOT/= gates; int64 for 'C' bit)
//	W = bar  (any: *Vertex pointing to complement gate, if computed)
//
// Graph utility fields:
//
//	ZZ = outs (*Arc: list of output arc records)
package gates

import (
	"fmt"

	"github.com/sjnam/go-sgb/flip"
	"github.com/sjnam/go-sgb/graph"
)

// Gate type constants.
const (
	AND   = '&'
	OR    = '|'
	NOT   = '~'
	XOR   = '^'
	INP   = 'I'
	LAT   = 'L'
	CON   = 'C'
	EQL   = '='
	DELAY = 100
)

// ---- Utility-field accessors ----

func Val(v *graph.Vertex) int64         { i, _ := v.X.(int64); return i }
func Typ(v *graph.Vertex) byte          { i, _ := v.Y.(int64); return byte(i) }
func Alt(v *graph.Vertex) *graph.Vertex { p, _ := v.Z.(*graph.Vertex); return p }
func Bit(v *graph.Vertex) int64         { i, _ := v.Z.(int64); return i }
func Outs(g *graph.Graph) *graph.Arc    { a, _ := g.ZZ.(*graph.Arc); return a }

func setVal(v *graph.Vertex, x int64)         { v.X = x }
func setTyp(v *graph.Vertex, t byte)          { v.Y = int64(t) }
func setAlt(v *graph.Vertex, u *graph.Vertex) { v.Z = u }
func setBit(v *graph.Vertex, b int64)         { v.Z = b }
func setBar(v *graph.Vertex, u *graph.Vertex) { v.W = u }
func getBar(v *graph.Vertex) *graph.Vertex    { p, _ := v.W.(*graph.Vertex); return p }

// ---- Internal gate-building state ----

var (
	gateGraph *graph.Graph
	nextVI    int64  // index of next vertex to allocate
	gPrefix   string // current naming prefix
	gCount    int64  // serial number; -1 = no number (use prefix as-is)
)

func vAt(i int64) *graph.Vertex { return &gateGraph.Vertices[i] }

func newVert(t byte) *graph.Vertex {
	v := vAt(nextVI)
	nextVI++
	if gCount < 0 {
		v.Name = gPrefix
	} else {
		v.Name = fmt.Sprintf("%s%d", gPrefix, gCount)
		gCount++
	}
	setTyp(v, t)
	return v
}

func startPrefix(s string) { gPrefix = s; gCount = 0 }

func numericPrefix(ch byte, k int64) {
	gPrefix = fmt.Sprintf("%c%d:", ch, k)
	gCount = 0
}

// firstOf creates n vertices of type t and returns the index of the first.
func firstOf(n int64, t byte) int64 {
	idx := nextVI
	for k := int64(0); k < n; k++ {
		newVert(t)
	}
	return idx
}

func make2(t byte, v1, v2 *graph.Vertex) *graph.Vertex {
	v := newVert(t)
	gateGraph.NewArc(v, v1, DELAY)
	gateGraph.NewArc(v, v2, DELAY)
	return v
}

func make3(t byte, v1, v2, v3 *graph.Vertex) *graph.Vertex {
	v := newVert(t)
	gateGraph.NewArc(v, v1, DELAY)
	gateGraph.NewArc(v, v2, DELAY)
	gateGraph.NewArc(v, v3, DELAY)
	return v
}

func make4(t byte, v1, v2, v3, v4 *graph.Vertex) *graph.Vertex {
	v := newVert(t)
	gateGraph.NewArc(v, v1, DELAY)
	gateGraph.NewArc(v, v2, DELAY)
	gateGraph.NewArc(v, v3, DELAY)
	gateGraph.NewArc(v, v4, DELAY)
	return v
}

func make5(t byte, v1, v2, v3, v4, v5 *graph.Vertex) *graph.Vertex {
	v := newVert(t)
	gateGraph.NewArc(v, v1, DELAY)
	gateGraph.NewArc(v, v2, DELAY)
	gateGraph.NewArc(v, v3, DELAY)
	gateGraph.NewArc(v, v4, DELAY)
	gateGraph.NewArc(v, v5, DELAY)
	return v
}

// comp returns the complement of v, creating a NOT gate if needed.
// The complement is cached in v.W (bar field).
func comp(v *graph.Vertex) *graph.Vertex {
	if b := getBar(v); b != nil {
		return b
	}
	u := vAt(nextVI)
	nextVI++
	setBar(u, v)
	setBar(v, u)
	u.Name = v.Name + "~"
	setTyp(u, NOT)
	gateGraph.NewArc(u, v, 1)
	return u
}

// evenComp returns comp(v) if s is odd, v if s is even.
func evenComp(s int64, v *graph.Vertex) *graph.Vertex {
	if s&1 != 0 {
		return comp(v)
	}
	return v
}

// makeXor constructs XOR(u,v) = OR(AND(u,comp(v)), AND(comp(u),v)).
func makeXor(u, v *graph.Vertex) *graph.Vertex {
	t1 := make2(AND, u, comp(v))
	t2 := make2(AND, comp(u), v)
	return make2(OR, t1, t2)
}

// latchit sets latch.alt = AND(u, runBit).
func latchit(u, latch, runBit *graph.Vertex) {
	setAlt(latch, make2(AND, u, runBit))
}

// ---- GateEval ----

// GateEval evaluates each gate of g.
// If inVec is non-empty, its characters '0'/'1' are assigned to the input gates.
// If outVec is non-nil it receives the output values.
// Returns 0 on success, -1 on unknown gate type, -2 if g is nil.
func GateEval(g *graph.Graph, inVec string, outVec []byte) int64 {
	if g == nil {
		return -2
	}
	vi := int64(0)
	// load inputs
	for vi < g.N && vi < int64(len(inVec)) {
		setVal(&g.Vertices[vi], int64(inVec[vi]-'0'))
		vi++
	}
	// evaluate each gate
	for ; vi < g.N; vi++ {
		v := &g.Vertices[vi]
		var t int64
		switch Typ(v) {
		case INP:
			continue
		case LAT:
			t = Val(Alt(v))
		case AND:
			t = 1
			for a := v.Arcs; a != nil; a = a.Next {
				t &= Val(a.Tip)
			}
		case OR:
			t = 0
			for a := v.Arcs; a != nil; a = a.Next {
				t |= Val(a.Tip)
			}
		case XOR:
			t = 0
			for a := v.Arcs; a != nil; a = a.Next {
				t ^= Val(a.Tip)
			}
		case NOT:
			t = 1 - Val(v.Arcs.Tip)
		default:
			return -1
		}
		setVal(v, t)
	}
	// store outputs
	if outVec != nil {
		i := 0
		for a := Outs(g); a != nil; a = a.Next {
			if i < len(outVec) {
				outVec[i] = byte('0') + tipValue(a.Tip)
				i++
			}
		}
		if i < len(outVec) {
			outVec[i] = 0
		}
	}
	return 0
}

// tipValue returns the boolean value of an arc tip, handling boolean constants
// (represented as uintptr 0 or 1 stored in the tip pointer — not used in Go).
// In Go, all tips are real vertices; this function just returns Val(tip).
func tipValue(tip *graph.Vertex) byte {
	if tip == nil {
		return 0
	}
	return byte(Val(tip))
}

// ---- PrintGates ----

// PrintGates prints a symbolic representation of gate graph g.
func PrintGates(g *graph.Graph) {
	for i := int64(0); i < g.N; i++ {
		prGate(&g.Vertices[i])
	}
	for a := Outs(g); a != nil; a = a.Next {
		fmt.Printf("Output %s\n", a.Tip.Name)
	}
}

func prGate(v *graph.Vertex) {
	fmt.Printf("%s = ", v.Name)
	switch Typ(v) {
	case INP:
		fmt.Print("input")
	case LAT:
		fmt.Print("latch")
		if u := Alt(v); u != nil {
			fmt.Printf("ed %s", u.Name)
		}
	case NOT:
		fmt.Print("~ ")
	case CON:
		fmt.Printf("constant %d", Bit(v))
	case EQL:
		fmt.Printf("copy of %s", Alt(v).Name)
	}
	first := true
	for a := v.Arcs; a != nil; a = a.Next {
		if !first {
			fmt.Printf(" %c ", Typ(v))
		}
		fmt.Print(a.Tip.Name)
		first = false
	}
	fmt.Println()
}

// ---- Risc ----

// RiscState holds the register values after RunRisc terminates.
var RiscState [18]uint64

// Risc constructs a gate graph for a simple 16-bit RISC CPU.
// regs must be 2..16; values outside this range are replaced with 16.
// The graph has 1400+115*regs vertices.
// UtilTypes = "ZZZIIVZZZZZZZA".
func Risc(regs int64) (*graph.Graph, error) {
	if regs < 2 || regs > 16 {
		regs = 16
	}
	// Allocate generously; trim after construction.
	g := graph.NewGraph(8 * (1400 + 115*regs))
	if g == nil {
		return nil, graph.ErrNoRoom
	}
	g.ID = fmt.Sprintf("risc(%d)", regs)
	g.UtilTypes = "ZZZIIVZZZZZZZA"

	gateGraph = g
	nextVI = 0

	buildRisc(regs)

	g.N = nextVI
	g.Vertices = g.Vertices[:nextVI+graph.ExtraN]
	return g, nil
}

func buildRisc(regs int64) {
	// ---- Inputs and latches ----
	gPrefix = "RUN"
	gCount = -1
	runBit := newVert(INP)

	startPrefix("M")
	var mem [16]*graph.Vertex
	for k := int64(0); k < 16; k++ {
		mem[k] = newVert(INP)
	}

	startPrefix("P")
	progIdx := firstOf(10, LAT)

	gPrefix = "S"
	gCount = -1
	sign := newVert(LAT)
	gPrefix = "N"
	gCount = -1
	nonzero := newVert(LAT)
	gPrefix = "K"
	gCount = -1
	carry := newVert(LAT)
	gPrefix = "V"
	gCount = -1
	overflow := newVert(LAT)
	gPrefix = "X"
	gCount = -1
	extra := newVert(LAT)

	regIdx := make([]int64, regs)
	for r := int64(0); r < regs; r++ {
		numericPrefix('R', r)
		regIdx[r] = firstOf(16, LAT)
	}

	// ---- Instruction decoding ----
	startPrefix("D")
	imm := make3(AND, comp(extra), comp(mem[4]), comp(mem[5])) // A=0
	rel := make3(AND, comp(extra), mem[4], comp(mem[5]))       // A=1
	dir := make3(AND, comp(extra), comp(mem[4]), mem[5])       // A=2
	ind := make3(AND, comp(extra), mem[4], mem[5])             // A=3

	op := make2(OR, make2(AND, extra, vAt(progIdx)), make2(AND, comp(extra), mem[6]))
	cond := make2(OR, make2(AND, extra, vAt(progIdx+1)), make2(AND, comp(extra), mem[7]))

	var mod [4]*graph.Vertex
	var dest [4]*graph.Vertex
	for k := int64(0); k < 4; k++ {
		mod[k] = make2(OR, make2(AND, extra, vAt(progIdx+2+k)), make2(AND, comp(extra), mem[8+k]))
		dest[k] = make2(OR, make2(AND, extra, vAt(progIdx+6+k)), make2(AND, comp(extra), mem[12+k]))
	}

	// ---- Fetch source value ----
	startPrefix("F")

	// old_dest: present value of destination register
	var destMatch [16]*graph.Vertex
	for r := int64(0); r < regs; r++ {
		destMatch[r] = make4(AND,
			evenComp(r, dest[0]), evenComp(r>>1, dest[1]),
			evenComp(r>>2, dest[2]), evenComp(r>>3, dest[3]))
	}
	var oldDest [16]*graph.Vertex
	var tmp [16]*graph.Vertex
	for k := int64(0); k < 16; k++ {
		for r := int64(0); r < regs; r++ {
			tmp[r] = make2(AND, destMatch[r], vAt(regIdx[r]+k))
		}
		oldDest[k] = newVert(OR)
		for r := int64(0); r < regs; r++ {
			gateGraph.NewArc(oldDest[k], tmp[r], DELAY)
		}
	}

	// old_src: present value of source register
	var oldSrc [16]*graph.Vertex
	for k := int64(0); k < 16; k++ {
		for r := int64(0); r < regs; r++ {
			tmp[r] = make5(AND, vAt(regIdx[r]+k),
				evenComp(r, mem[0]), evenComp(r>>1, mem[1]),
				evenComp(r>>2, mem[2]), evenComp(r>>3, mem[3]))
		}
		oldSrc[k] = newVert(OR)
		for r := int64(0); r < regs; r++ {
			gateGraph.NewArc(oldSrc[k], tmp[r], DELAY)
		}
	}

	// inc_dest: old_dest + SRC (4-bit adder for low 4 bits)
	var incDest [16]*graph.Vertex
	makeAdder(4, oldDest[:], mem[:], incDest[:], nil, true)
	up := make2(AND, incDest[4], comp(mem[3]))
	down := make2(AND, comp(incDest[4]), mem[3])
	for k := int64(4); ; k++ {
		comp(up)
		comp(down)
		incDest[k] = make3(OR,
			make2(AND, comp(oldDest[k]), up),
			make2(AND, comp(oldDest[k]), down),
			make3(AND, oldDest[k], comp(up), comp(down)))
		if k < 15 {
			up = make2(AND, up, oldDest[k])
			down = make2(AND, down, comp(oldDest[k]))
		} else {
			break
		}
	}

	// source[k]
	var source [16]*graph.Vertex
	for k := int64(0); k < 16; k++ {
		immK := mem[k]
		if k >= 4 {
			immK = mem[3]
		}
		source[k] = make4(OR,
			make2(AND, imm, immK),
			make2(AND, rel, incDest[k]),
			make2(AND, dir, oldSrc[k]),
			make2(AND, extra, mem[k]))
	}

	// ---- General logic operation ----
	startPrefix("L")
	var logOp [16]*graph.Vertex
	for k := int64(0); k < 16; k++ {
		logOp[k] = make4(OR,
			make3(AND, mod[0], comp(oldDest[k]), comp(source[k])),
			make3(AND, mod[1], comp(oldDest[k]), source[k]),
			make3(AND, mod[2], oldDest[k], comp(source[k])),
			make3(AND, mod[3], oldDest[k], source[k]))
	}

	// ---- Conditional load ----
	startPrefix("C")
	tmp[0] = make4(OR,
		make3(AND, mod[0], comp(sign), comp(nonzero)),
		make3(AND, mod[1], comp(sign), nonzero),
		make3(AND, mod[2], sign, comp(nonzero)),
		make3(AND, mod[3], sign, nonzero))
	tmp[1] = make4(OR,
		make3(AND, mod[0], comp(carry), comp(overflow)),
		make3(AND, mod[1], comp(carry), overflow),
		make3(AND, mod[2], carry, comp(overflow)),
		make3(AND, mod[3], carry, overflow))
	change := make3(OR, comp(cond), make2(AND, tmp[0], comp(op)), make2(AND, tmp[1], op))

	// ---- Arithmetic ----
	startPrefix("A")

	// Shift operations
	var shift [18]*graph.Vertex
	for k := int64(0); k < 16; k++ {
		var s0, s1, s2, s3 *graph.Vertex
		if k == 0 {
			s0 = make4(AND, source[15], mod[0], comp(mod[1]), comp(mod[2]))
		} else {
			s0 = make3(AND, source[k-1], comp(mod[1]), comp(mod[2]))
		}
		if k < 4 {
			s1 = make4(AND, source[k+12], mod[0], mod[1], comp(mod[2]))
		} else {
			s1 = make3(AND, source[k-4], mod[1], comp(mod[2]))
		}
		if k == 15 {
			s2 = make4(AND, source[15], comp(mod[0]), comp(mod[1]), mod[2])
		} else {
			s2 = make3(AND, source[k+1], comp(mod[1]), mod[2])
		}
		if k > 11 {
			s3 = make4(AND, source[15], comp(mod[0]), mod[1], mod[2])
		} else {
			s3 = make3(AND, source[k+4], mod[1], mod[2])
		}
		shift[k] = make4(OR, s0, s1, s2, s3)
	}
	shift[16] = make4(OR,
		make2(AND, comp(mod[2]), source[15]),
		make3(AND, comp(mod[2]), mod[1], make3(OR, source[14], source[13], source[12])),
		make3(AND, mod[2], comp(mod[1]), source[0]),
		make3(AND, mod[2], mod[1], source[3]))
	shift[17] = make3(OR,
		make3(AND, comp(mod[2]), comp(mod[1]), makeXor(source[15], source[14])),
		make4(AND, comp(mod[2]), mod[1],
			make5(OR, source[15], source[14], source[13], source[12], source[11]),
			make5(OR, comp(source[15]), comp(source[14]), comp(source[13]), comp(source[12]), comp(source[11]))),
		make3(AND, mod[2], mod[1], make3(OR, source[0], source[1], source[2])))

	var sum [18]*graph.Vertex
	var diff [18]*graph.Vertex
	makeAdder(16, oldDest[:], source[:], sum[:], make2(AND, carry, mod[0]), true)
	makeAdder(16, oldDest[:], source[:], diff[:], make2(AND, carry, mod[0]), false)
	sum[17] = make2(OR,
		make3(AND, oldDest[15], source[15], comp(sum[15])),
		make3(AND, comp(oldDest[15]), comp(source[15]), sum[15]))
	diff[17] = make2(OR,
		make3(AND, oldDest[15], comp(source[15]), comp(diff[15])),
		make3(AND, comp(oldDest[15]), source[15], diff[15]))

	// ---- Bring everything together ----
	startPrefix("Z")

	// next_loc and next_next_loc (reg[0] + 1 and + 2)
	var nextLoc [16]*graph.Vertex
	var nextNextLoc [16]*graph.Vertex
	nextLoc[0] = comp(vAt(regIdx[0]))
	nextNextLoc[0] = vAt(regIdx[0])
	nextLoc[1] = makeXor(vAt(regIdx[0]+1), vAt(regIdx[0]))
	nextNextLoc[1] = comp(vAt(regIdx[0] + 1))
	t5 := vAt(regIdx[0] + 1)
	for k := int64(2); k < 16; k++ {
		nextLoc[k] = makeXor(vAt(regIdx[0]+k), make2(AND, vAt(regIdx[0]), t5))
		nextNextLoc[k] = makeXor(vAt(regIdx[0]+k), t5)
		if k < 15 {
			t5 = make2(AND, t5, vAt(regIdx[0]+k))
		}
	}

	// result bits
	jump := make5(AND, op, mod[0], mod[1], mod[2], mod[3])
	var result [18]*graph.Vertex
	for k := int64(0); k < 16; k++ {
		result[k] = make5(OR,
			make2(AND, comp(op), logOp[k]),
			make2(AND, jump, nextLoc[k]),
			make3(AND, op, comp(mod[3]), shift[k]),
			make5(AND, op, mod[3], comp(mod[2]), comp(mod[1]), sum[k]),
			make5(AND, op, mod[3], comp(mod[2]), mod[1], diff[k]))
		result[k] = make2(OR,
			make3(AND, cond, change, source[k]),
			make2(AND, comp(cond), result[k]))
	}
	for k := int64(16); k < 18; k++ {
		result[k] = make3(OR,
			make3(AND, op, comp(mod[3]), shift[k]),
			make5(AND, op, mod[3], comp(mod[2]), comp(mod[1]), sum[k]),
			make5(AND, op, mod[3], comp(mod[2]), mod[1], diff[k]))
	}

	// Program register and extra bit
	for k := int64(0); k < 10; k++ {
		latchit(mem[k+6], vAt(progIdx+k), runBit)
	}
	nextra := make2(OR, make2(AND, ind, comp(cond)), make2(AND, ind, change))
	latchit(nextra, extra, runBit)
	nzs := make4(OR, mem[0], mem[1], mem[2], mem[3])
	nzd := make4(OR, dest[0], dest[1], dest[2], dest[3])

	// New values for registers 1..regs-1
	t5chg := make2(AND, change, comp(ind))
	for r := int64(1); r < regs; r++ {
		t4 := make2(AND, t5chg, destMatch[r])
		for k := int64(0); k < 16; k++ {
			t3 := make2(OR, make2(AND, t4, result[k]), make2(AND, comp(t4), vAt(regIdx[r]+k)))
			latchit(t3, vAt(regIdx[r]+k), runBit)
		}
	}

	// New values of S, N, K, V
	t5 = make4(OR,
		make2(AND, sign, cond),
		make2(AND, sign, jump),
		make2(AND, sign, ind),
		make4(AND, result[15], comp(cond), comp(jump), comp(ind)))
	latchit(t5, sign, runBit)

	t5 = make4(OR,
		make4(OR, result[0], result[1], result[2], result[3]),
		make4(OR, result[4], result[5], result[6], result[7]),
		make4(OR, result[8], result[9], result[10], result[11]),
		make4(OR, result[12], result[13], result[14],
			make5(AND, make2(OR, nonzero, sign), op, mod[0], comp(mod[2]), mod[3])))
	t5 = make4(OR,
		make2(AND, nonzero, cond),
		make2(AND, nonzero, jump),
		make2(AND, nonzero, ind),
		make4(AND, t5, comp(cond), comp(jump), comp(ind)))
	latchit(t5, nonzero, runBit)

	t5 = make5(OR,
		make2(AND, overflow, cond),
		make2(AND, overflow, jump),
		make2(AND, overflow, comp(op)),
		make2(AND, overflow, ind),
		make5(AND, result[17], comp(cond), comp(jump), comp(ind), op))
	latchit(t5, overflow, runBit)

	t5 = make5(OR,
		make2(AND, carry, cond),
		make2(AND, carry, jump),
		make2(AND, carry, comp(op)),
		make2(AND, carry, ind),
		make5(AND, result[16], comp(cond), comp(jump), comp(ind), op))
	latchit(t5, carry, runBit)

	// New values of register 0 and memory address register (outputs)
	skip := make2(AND, cond, comp(change))
	hop := make2(AND, comp(cond), jump)
	normal := make4(OR,
		make2(AND, skip, comp(ind)),
		make2(AND, skip, nzs),
		make3(AND, comp(skip), ind, comp(nzs)),
		make3(AND, comp(skip), comp(hop), nzd))
	special := make3(AND, comp(skip), ind, nzs)

	for k := int64(0); k < 16; k++ {
		t5 = make4(OR,
			make2(AND, normal, nextLoc[k]),
			make4(AND, skip, ind, comp(nzs), nextNextLoc[k]),
			make3(AND, hop, comp(ind), source[k]),
			make5(AND, comp(skip), comp(hop), comp(ind), comp(nzd), result[k]))
		t4 := make2(OR,
			make2(AND, special, vAt(regIdx[0]+k)),
			make2(AND, comp(special), t5))
		latchit(t4, vAt(regIdx[0]+k), runBit)
		t4 = make2(OR,
			make2(AND, special, oldSrc[k]),
			make2(AND, comp(special), t5))
		// output arc (big-endian order: prepend)
		a := &graph.Arc{}
		a.Tip = make2(AND, t4, runBit)
		a.Next, _ = gateGraph.ZZ.(*graph.Arc)
		gateGraph.ZZ = a
	}
}

// makeAdder builds an n-bit ripple-carry adder (add=true) or subtracter (add=false).
// x[0..n-1], y[0..n-1] are input gate pointer slices; z[0..n] receives output gate pointers.
// carry is an optional incoming carry gate (nil = no incoming carry).
func makeAdder(n int64, x, y, z []*graph.Vertex, carry *graph.Vertex, add bool) {
	k := int64(0)
	if carry == nil {
		z[0] = makeXor(x[0], y[0])
		if add {
			carry = make2(AND, x[0], y[0])
		} else {
			carry = make2(AND, comp(x[0]), y[0])
		}
		k = 1
	}
	for ; k < n; k++ {
		comp(x[k])
		comp(y[k])
		comp(carry)
		z[k] = make4(OR,
			make3(AND, x[k], comp(y[k]), comp(carry)),
			make3(AND, comp(x[k]), y[k], comp(carry)),
			make3(AND, comp(x[k]), comp(y[k]), carry),
			make3(AND, x[k], y[k], carry))
		carry = make3(OR,
			make2(AND, evenComp(boolInt(!add), x[k]), y[k]),
			make2(AND, evenComp(boolInt(!add), x[k]), carry),
			make2(AND, y[k], carry))
	}
	z[n] = carry
}

func boolInt(b bool) int64 {
	if b {
		return 1
	}
	return 0
}

// ---- RunRisc ----

// RunRisc simulates the RISC CPU built by Risc().
// g is the gate graph, rom is the read-only memory, size is its length.
// traceRegs, if >0, prints register state each cycle.
// Returns 0 on success, negative on error.
func RunRisc(g *graph.Graph, rom []uint64, size, traceRegs int64) int64 {
	if g == nil {
		return -2
	}
	if traceRegs > 0 {
		for r := int64(0); r < traceRegs; r++ {
			fmt.Printf(" r%-2d ", r)
		}
		fmt.Println(" P XSNKV MEM")
	}

	r := GateEval(g, "0", nil) // reset: RUN=0
	if r < 0 {
		return r
	}
	g.Vertices[0].X = int64(1) // RUN=1

	var l uint64
	for {
		// read memory address from outputs (big-endian)
		l = 0
		for a := Outs(g); a != nil; a = a.Next {
			l = 2*l + uint64(Val(a.Tip))
		}
		if traceRegs > 0 {
			printRiscState(g, traceRegs, l, rom, size)
		}
		if l >= uint64(size) {
			break
		}
		m := rom[l]
		for vi := int64(1); vi <= 16; vi++ {
			g.Vertices[vi].X = int64(m & 1)
			m >>= 1
		}
		GateEval(g, "", nil)
	}
	if traceRegs > 0 {
		fmt.Printf("Execution terminated with memory address %d.\n", l)
	}
	dumpRiscState(g)
	return 0
}

// RISC vertex layout (from buildRisc):
//   0       = RUN
//   1..16   = M0..M15
//   17..26  = P0..P9  (prog, 10-bit PC)
//   27      = S (sign), 28=N (nonzero), 29=K (carry), 30=V (overflow), 31=X (extra)
//   32+16*r .. 47+16*r = R[r]:0 .. R[r]:15

func riscRegVal(g *graph.Graph, r int64) uint64 {
	var m uint64
	for k := int64(15); k >= 0; k-- {
		m = 2*m + uint64(Val(&g.Vertices[32+16*r+k]))
	}
	return m
}

func printRiscState(g *graph.Graph, traceRegs int64, l uint64, rom []uint64, size int64) {
	for r := int64(0); r < traceRegs; r++ {
		fmt.Printf("%04x ", riscRegVal(g, r))
	}
	// prog register P0..P9, MSB (P9) first
	var m uint64
	for k := int64(9); k >= 0; k-- {
		m = 2*m + uint64(Val(&g.Vertices[17+k]))
	}
	x := Val(&g.Vertices[31])
	s := Val(&g.Vertices[27])
	n := Val(&g.Vertices[28])
	c := Val(&g.Vertices[29])
	o := Val(&g.Vertices[30])
	xc, sc, nc, cc, oc := '.', '.', '.', '.', '.'
	if x != 0 {
		xc = 'X'
	}
	if s != 0 {
		sc = 'S'
	}
	if n != 0 {
		nc = 'N'
	}
	if c != 0 {
		cc = 'K'
	}
	if o != 0 {
		oc = 'V'
	}
	fmt.Printf("%03x%c%c%c%c%c ", m, xc, sc, nc, cc, oc)
	if l >= uint64(size) {
		fmt.Println("????")
	} else {
		fmt.Printf("%04x\n", rom[l])
	}
}

func dumpRiscState(g *graph.Graph) {
	for r := int64(0); r < 16; r++ {
		RiscState[r] = riscRegVal(g, r)
	}
	var m uint64
	for k := int64(9); k >= 0; k-- {
		m = 2*m + uint64(Val(&g.Vertices[17+k]))
	}
	m = 4*m + uint64(Val(&g.Vertices[31]))
	m = 2*m + uint64(Val(&g.Vertices[27]))
	m = 2*m + uint64(Val(&g.Vertices[28]))
	m = 2*m + uint64(Val(&g.Vertices[29]))
	m = 2*m + uint64(Val(&g.Vertices[30]))
	RiscState[16] = m
}

// ---- Prod ----

// Prod constructs a gate graph for parallel multiplication of m-bit by n-bit numbers.
// m >= 2 and n >= 2; smaller values are replaced with 2.
// The result is reduced (simplified) before being returned.
// UtilTypes = "ZZZIIVZZZZZZZA".
func Prod(m, n int64) (*graph.Graph, error) {
	if m < 2 {
		m = 2
	}
	if n < 2 {
		n = 2
	}
	mPlusN := m + n

	// Compute f = flog(m+n)
	f := int64(4)
	fj := int64(3)
	fk := int64(5)
	for fk < mPlusN {
		fk = fk + fj
		fj = fk - fj
		f++
	}

	size := (6*m - 7 + 3*f) * mPlusN
	g := graph.NewGraph(size)
	if g == nil {
		return nil, graph.ErrNoRoom
	}
	g.ID = fmt.Sprintf("prod(%d,%d)", m, n)
	g.UtilTypes = "ZZZIIVZZZZZZZA"

	gateGraph = g
	nextVI = 0

	buildProd(m, n, mPlusN, f)

	g.N = nextVI // actual number of gates used
	g.Vertices = g.Vertices[:g.N+graph.ExtraN]

	g, err := reduce(g)
	if err != nil {
		return nil, err
	}
	return g, nil
}

func aPos(j, m int64) int64 {
	if j < m {
		return j + 1
	}
	jj := j - m
	return m + 5*(jj>>1) + 3 + ((jj & 1) << 1)
}

func buildProd(m, n, mPlusN, f int64) {
	startPrefix("X")
	xIdx := firstOf(m, INP)
	startPrefix("Y")
	yIdx := firstOf(n, INP)

	// Define A_j for 0 <= j < m
	for j := int64(0); j < m; j++ {
		numericPrefix('A', j)
		for k := int64(0); k < j; k++ {
			v := newVert(CON)
			setBit(v, 0)
		}
		for k := int64(0); k < n; k++ {
			make2(AND, vAt(xIdx+j), vAt(yIdx+k))
		}
		for k := j + n; k < mPlusN; k++ {
			v := newVert(CON)
			setBit(v, 0)
		}
	}

	// Define P_j, Q_j, A_{m+2j}, R_j, A_{m+2j+1} for 0 <= j < m-2
	for j := int64(0); j < m-2; j++ {
		alpha := aPos(3*j, m) * mPlusN
		beta := aPos(3*j+1, m) * mPlusN
		numericPrefix('P', j)
		for k := int64(0); k < mPlusN; k++ {
			make2(XOR, vAt(alpha+k), vAt(beta+k))
		}
		numericPrefix('Q', j)
		for k := int64(0); k < mPlusN; k++ {
			make2(AND, vAt(alpha+k), vAt(beta+k))
		}
		alpha2 := nextVI - 2*mPlusN
		beta2 := aPos(3*j+2, m) * mPlusN
		numericPrefix('A', m+2*j)
		for k := int64(0); k < mPlusN; k++ {
			make2(XOR, vAt(alpha2+k), vAt(beta2+k))
		}
		numericPrefix('R', j)
		for k := int64(0); k < mPlusN; k++ {
			make2(AND, vAt(alpha2+k), vAt(beta2+k))
		}
		alpha3 := nextVI - 3*mPlusN
		beta3 := nextVI - mPlusN
		numericPrefix('A', m+2*j+1)
		v := newVert(CON)
		setBit(v, 0)
		for k := int64(0); k < mPlusN-1; k++ {
			make2(OR, vAt(alpha3+k), vAt(beta3+k))
		}
	}

	// Define U and V
	alpha := aPos(3*m-6, m) * mPlusN
	beta := aPos(3*m-5, m) * mPlusN
	startPrefix("U")
	for k := int64(0); k < mPlusN; k++ {
		make2(XOR, vAt(alpha+k), vAt(beta+k))
	}
	startPrefix("V")
	for k := int64(0); k < mPlusN; k++ {
		make2(AND, vAt(alpha+k), vAt(beta+k))
	}

	// Parallel addition: compute Z = U ⊕ W
	uu := nextVI - mPlusN - mPlusN // points to U[0]
	vv := nextVI - mPlusN          // points to V[0]

	// Build flog and down tables
	flogT := make([]int64, mPlusN+1)
	downT := make([]int64, mPlusN+1)
	flogT[1] = 0
	flogT[2] = 2
	downT[1] = 0
	downT[2] = 1
	{
		fi, fj2, fk2 := int64(3), int64(2), int64(3)
		for l := int64(3); l <= mPlusN; l++ {
			if l > fk2 {
				fk2 = fk2 + fj2
				fj2 = fk2 - fj2
				fi++
			}
			flogT[l] = fi
			downT[l] = l - fk2 + fj2
		}
	}

	w := make([]*graph.Vertex, mPlusN)
	cT := make([]*graph.Vertex, f*mPlusN)

	startPrefix("W")
	v0 := newVert(CON)
	setBit(v0, 0)
	w[0] = v0
	v1 := newVert(EQL)
	setAlt(v1, vAt(vv))
	w[1] = v1

	anc := make([]int64, f+2)
	for k := int64(2); k < mPlusN; k++ {
		// Build anc list (ancestors of k in decreasing order, stopping at 2)
		l := int64(0)
		for j := k; ; l++ {
			anc[l] = j
			if j == 2 {
				break
			}
			j = downT[j]
		}

		i := int64(1)
		cc := vAt(vv + k - 1)
		dd := vAt(uu + k - 1)

		for {
			j := anc[l]
			// gate b_k^j = d_k^i AND c_{k-i}^{j-i}
			bv := vAt(nextVI)
			nextVI++
			bv.Name = fmt.Sprintf("B%d:%d", k, j)
			setTyp(bv, AND)
			gateGraph.NewArc(bv, dd, DELAY)
			ji := j - i
			fl := flogT[ji]
			var cArg *graph.Vertex
			if fl > 0 {
				cArg = cT[(k-i)+(fl-2)*mPlusN]
			} else {
				cArg = vAt(vv + k - i - 1)
			}
			gateGraph.NewArc(bv, cArg, DELAY)

			// gate c_k^j = c_k^i OR b_k^j
			var cv *graph.Vertex
			if l != 0 {
				cv = vAt(nextVI)
				nextVI++
				cv.Name = fmt.Sprintf("C%d:%d", k, j)
				setTyp(cv, OR)
			} else {
				cv = newVert(OR)
			}
			gateGraph.NewArc(cv, cc, DELAY)
			gateGraph.NewArc(cv, bv, DELAY)

			if flogT[j] < flogT[j+1] { // j is a Fibonacci number
				cT[k+(flogT[j]-2)*mPlusN] = cv
			}
			if l == 0 {
				break
			}
			cc = cv

			// gate d_k^j = d_k^i AND d_{k-i}^{j-i}
			dv := vAt(nextVI)
			nextVI++
			dv.Name = fmt.Sprintf("D%d:%d", k, j)
			setTyp(dv, AND)
			gateGraph.NewArc(dv, dd, DELAY)
			var dArg *graph.Vertex
			if fl > 0 {
				dArg = cT[(k-i)+(fl-2)*mPlusN+1]
			} else {
				dArg = vAt(uu + k - i - 1)
			}
			gateGraph.NewArc(dv, dArg, DELAY)
			dd = dv
			i = j
			l--
		}
		w[k] = vAt(nextVI - 1)
	}

	// Compute Z = U XOR W, record outputs
	startPrefix("Z")
	for k := int64(0); k < mPlusN; k++ {
		zv := make2(XOR, vAt(uu+k), w[k])
		a := &graph.Arc{}
		a.Tip = zv
		a.Next, _ = gateGraph.ZZ.(*graph.Arc)
		gateGraph.ZZ = a
	}
}

// ---- reduce (internal) ----

// reduce simplifies a generalized gate graph by eliminating constant and copy gates.
// It marks only reachable gates and copies them to a new graph. g is recycled.
func reduce(g *graph.Graph) (*graph.Graph, error) {
	if g == nil {
		return nil, graph.ErrMissingOperand
	}
	sentinel := g.N

	// Iterate until no more constant latches are produced.
	for {
		latchPtr := []*graph.Vertex(nil) // list of latches linked via V
		for i := int64(0); i < sentinel; i++ {
			v := &g.Vertices[i]
			reduceGate(v, &latchPtr)
		}
		changed := false
		for _, v := range latchPtr {
			u := Alt(v)
			if Typ(u) == EQL {
				setAlt(v, Alt(u))
			} else if Typ(u) == CON {
				setTyp(v, CON)
				setBit(v, Bit(u))
				changed = true
			}
		}
		if !changed {
			break
		}
	}

	// Mark reachable gates
	n := int64(0)
	for i := int64(0); i < sentinel; i++ {
		g.Vertices[i].V = nil // clear lnk
	}
	for a := Outs(g); a != nil; a = a.Next {
		v := a.Tip
		if v == nil {
			continue
		}
		if Typ(v) == EQL {
			v = Alt(v)
			a.Tip = v
		}
		if Typ(v) == CON {
			// constant output: set tip to nil with value encoded
			// In Go we use a sentinel approach: tip = nil means val 0, tip=one means val 1
			// We'll just keep the CON vertex for now; GateEval handles it
			continue
		}
		markGates(g, v, &n)
	}

	// Copy marked gates to new graph
	newG := graph.NewGraph(n)
	if newG == nil {
		return nil, graph.ErrNoRoom
	}
	newG.ID = g.ID
	newG.UtilTypes = "ZZZIIVZZZZZZZA"

	// Build mapping from old to new vertices (stored in old vertex's V field after marking)
	newVI := int64(0)
	var latchList []*graph.Vertex // old latch vertices to fix up

	gateGraph = newG
	nextVI = 0

	for i := int64(0); i < sentinel; i++ {
		v := &g.Vertices[i]
		if v.V == nil {
			continue // not marked
		}
		// v.V was set to sentinel+1..∞ as a mark; now use it to store new vertex pointer
		u := &newG.Vertices[newVI]
		newVI++
		v.V = u // store mapping

		u.Name = v.Name
		setTyp(u, Typ(v))

		if Typ(v) == LAT {
			latchList = append(latchList, v)
		}

		// Reverse and copy arcs
		var reversed []*graph.Arc
		for a := v.Arcs; a != nil; a = a.Next {
			reversed = append(reversed, a)
		}
		for j := len(reversed) - 1; j >= 0; j-- {
			a := reversed[j]
			tip := a.Tip
			newTip, _ := tip.V.(*graph.Vertex)
			if newTip != nil {
				newG.NewArc(u, newTip, a.Len)
			}
		}
	}

	// Fix up latch alt fields
	for _, v := range latchList {
		u, _ := v.V.(*graph.Vertex)
		oldAlt := Alt(v)
		if oldAlt == nil {
			continue
		}
		newAlt, _ := oldAlt.V.(*graph.Vertex)
		if newAlt != nil {
			setAlt(u, newAlt)
		} else {
			// latched gate is an input that precedes the latch: create an OR copy
			orV := &newG.Vertices[newVI]
			newVI++
			orV.Name = fmt.Sprintf("%s>%s", oldAlt.Name, u.Name)
			setTyp(orV, OR)
			newAltMapped, _ := oldAlt.V.(*graph.Vertex)
			if newAltMapped != nil {
				newG.NewArc(orV, newAltMapped, DELAY)
				newG.NewArc(orV, newAltMapped, DELAY)
			}
			setAlt(u, orV)
		}
	}

	// Copy output arc list
	var outArcs []*graph.Arc
	for a := Outs(g); a != nil; a = a.Next {
		outArcs = append(outArcs, a)
	}
	for i := len(outArcs) - 1; i >= 0; i-- {
		a := outArcs[i]
		b := &graph.Arc{}
		if a.Tip != nil {
			newTip, _ := a.Tip.V.(*graph.Vertex)
			b.Tip = newTip
		}
		b.Next, _ = newG.ZZ.(*graph.Arc)
		newG.ZZ = b
	}

	return newG, nil
}

// reduceGate simplifies gate v in place using identity rules.
func reduceGate(v *graph.Vertex, latchPtr *[]*graph.Vertex) {
	switch Typ(v) {
	case LAT:
		*latchPtr = append(*latchPtr, v)
		return
	case INP, CON:
		return
	case EQL:
		u := Alt(v)
		if Typ(u) == EQL {
			setAlt(v, Alt(u))
		} else if Typ(u) == CON {
			setBit(v, Bit(u))
			setTyp(v, CON)
		}
		return
	case NOT:
		u := v.Arcs.Tip
		if Typ(u) == EQL {
			u = Alt(u)
			v.Arcs.Tip = u
		}
		if Typ(u) == CON {
			setBit(v, 1-Bit(u))
			setTyp(v, CON)
			v.Arcs = nil
		} else if getBar(u) != nil && getBar(u) != v {
			setAlt(v, getBar(u))
			setTyp(v, EQL)
			v.Arcs = nil
		} else {
			setBar(u, v)
			setBar(v, u)
		}
		return
	case AND:
		reduceAnd(v)
	case OR:
		reduceOr(v)
	case XOR:
		reduceXor(v)
	}
	// test_single_arg
	if v.Arcs != nil && v.Arcs.Next == nil {
		setAlt(v, v.Arcs.Tip)
		setTyp(v, EQL)
		v.Arcs = nil
	}
	setBar(v, nil)
}

func reduceAnd(v *graph.Vertex) {
	var prev *graph.Arc
	a := v.Arcs
	for a != nil {
		u := a.Tip
		if Typ(u) == EQL {
			u = Alt(u)
			a.Tip = u
		}
		if Typ(u) == CON {
			if Bit(u) == 0 {
				setBit(v, 0)
				setTyp(v, CON)
				v.Arcs = nil
				return
			}
			// bypass: remove this arc (constant 1 doesn't affect AND)
			if prev == nil {
				v.Arcs = a.Next
			} else {
				prev.Next = a.Next
			}
			a = a.Next
			continue
		}
		// check for duplicate or complement
		found := false
		for b := v.Arcs; b != a; b = b.Next {
			if b.Tip == u {
				// duplicate input: bypass
				if prev == nil {
					v.Arcs = a.Next
				} else {
					prev.Next = a.Next
				}
				a = a.Next
				found = true
				break
			}
			if b.Tip == getBar(u) {
				// complementary input: result is 0
				setBit(v, 0)
				setTyp(v, CON)
				v.Arcs = nil
				return
			}
		}
		if !found {
			prev = a
			a = a.Next
		}
	}
	if v.Arcs == nil {
		setBit(v, 1)
		setTyp(v, CON)
	}
}

func reduceOr(v *graph.Vertex) {
	var prev *graph.Arc
	a := v.Arcs
	for a != nil {
		u := a.Tip
		if Typ(u) == EQL {
			u = Alt(u)
			a.Tip = u
		}
		if Typ(u) == CON {
			if Bit(u) == 1 {
				setBit(v, 1)
				setTyp(v, CON)
				v.Arcs = nil
				return
			}
			// bypass constant 0
			if prev == nil {
				v.Arcs = a.Next
			} else {
				prev.Next = a.Next
			}
			a = a.Next
			continue
		}
		found := false
		for b := v.Arcs; b != a; b = b.Next {
			if b.Tip == u {
				if prev == nil {
					v.Arcs = a.Next
				} else {
					prev.Next = a.Next
				}
				a = a.Next
				found = true
				break
			}
			if b.Tip == getBar(u) {
				setBit(v, 1)
				setTyp(v, CON)
				v.Arcs = nil
				return
			}
		}
		if !found {
			prev = a
			a = a.Next
		}
	}
	if v.Arcs == nil {
		setBit(v, 0)
		setTyp(v, CON)
	}
}

func reduceXor(v *graph.Vertex) {
	cmp := int64(0)
	var prev *graph.Arc
	a := v.Arcs
	for a != nil {
		u := a.Tip
		if Typ(u) == EQL {
			u = Alt(u)
			a.Tip = u
		}
		if Typ(u) == CON {
			if Bit(u) != 0 {
				cmp = 1 - cmp
			}
			if prev == nil {
				v.Arcs = a.Next
			} else {
				prev.Next = a.Next
			}
			a = a.Next
			continue
		}
		// check for duplicate or complement
		found := false
		var prevB *graph.Arc
		for b := v.Arcs; b != a; b = b.Next {
			if b.Tip == u {
				// double XOR = 0: remove both
				if prevB == nil {
					v.Arcs = b.Next
				} else {
					prevB.Next = b.Next
				}
				if prev == nil {
					v.Arcs = a.Next
				} else {
					prev.Next = a.Next
				}
				a = a.Next
				found = true
				break
			}
			if b.Tip == getBar(u) {
				// XOR complement = 1: remove both, flip cmp
				cmp = 1 - cmp
				if prevB == nil {
					v.Arcs = b.Next
				} else {
					prevB.Next = b.Next
				}
				if prev == nil {
					v.Arcs = a.Next
				} else {
					prev.Next = a.Next
				}
				a = a.Next
				found = true
				break
			}
			prevB = b
		}
		if !found {
			prev = a
			a = a.Next
		}
	}
	if v.Arcs == nil {
		setBit(v, cmp)
		setTyp(v, CON)
		return
	}
	if cmp != 0 {
		// complement one argument
		for a = v.Arcs; ; a = a.Next {
			u := a.Tip
			if getBar(u) != nil {
				a.Tip = getBar(u)
				break
			}
			if a.Next == nil {
				// create new NOT gate
				nb := vAt(nextVI)
				nextVI++
				nb.Name = u.Name + "~"
				setTyp(nb, NOT)
				gateGraph.NewArc(nb, u, 1)
				setBar(u, nb)
				setBar(nb, u)
				a.Tip = nb
				break
			}
		}
	}
}

// markGates marks v and all gates it depends on via DFS.
func markGates(g *graph.Graph, v *graph.Vertex, n *int64) {
	if v.V != nil {
		return // already marked
	}
	// Use a stack for iterative DFS
	type frame struct {
		v    *graph.Vertex
		next *graph.Arc
	}
	stack := []frame{{v, v.Arcs}}
	v.V = v // mark as "in progress"
	*n++

	for len(stack) > 0 {
		top := &stack[len(stack)-1]
		if top.next != nil {
			u := top.next.Tip
			top.next = top.next.Next
			if u != nil && u.V == nil {
				u.V = u
				*n++
				stack = append(stack, frame{u, u.Arcs})
			}
			continue
		}
		// Handle latch dependency
		if Typ(top.v) == LAT {
			altV := Alt(top.v)
			if altV != nil && altV.V == nil {
				altV.V = altV
				*n++
				if altIdx := vertIdx(g, altV); altIdx < vertIdx(g, top.v) {
					*n++ // extra gate for copy
				}
				stack = append(stack, frame{altV, altV.Arcs})
				continue
			}
		}
		stack = stack[:len(stack)-1]
	}
}

func vertIdx(g *graph.Graph, v *graph.Vertex) int64 {
	return graph.VertexIndex(g, v)
}

// ---- PartialGates ----

// PartialGates performs partial evaluation of gate graph g.
// The first r input gates are retained. Each subsequent input is retained
// with probability prob/65536; otherwise it gets a random constant value.
// buf, if non-nil, receives '*', '0', or '1' for each non-retained input.
// g is destroyed in the process; the reduced graph is returned.
func PartialGates(g *graph.Graph, r, prob, seed int64, buf []byte) (*graph.Graph, error) {
	if g == nil {
		return nil, graph.ErrMissingOperand
	}
	rng := flip.New(seed)

	bi := 0
inputs:
	for vi := r; vi < g.N; vi++ {
		v := &g.Vertices[vi]
		switch Typ(v) {
		case CON, EQL:
			continue
		case INP:
			if rng.Next()>>15 >= prob {
				setTyp(v, CON)
				setBit(v, rng.Next()>>30)
				if buf != nil && bi < len(buf) {
					buf[bi] = byte('0' + Bit(v))
					bi++
				}
			} else if buf != nil && bi < len(buf) {
				buf[bi] = '*'
				bi++
			}
		default:
			break inputs
		}
	}
	if buf != nil && bi < len(buf) {
		buf[bi] = 0
	}
	g, err := reduce(g)
	if err != nil {
		return nil, err
	}
	if g != nil {
		oldID := g.ID
		if len(oldID) > 54 {
			oldID = oldID[:51] + "..."
		}
		g.ID = fmt.Sprintf("partial_gates(%s,%d,%d,%d)", oldID, r, prob, seed)
	}
	return g, nil
}
