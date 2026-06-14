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
package gbgates

import (
	"fmt"
	"io"

	gbflip "github.com/sjnam/go-sgb/gb-flip"
	gbgraph "github.com/sjnam/go-sgb/gb-graph"
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

func Val(v *gbgraph.Vertex) int64           { i, _ := v.X.(int64); return i }
func Typ(v *gbgraph.Vertex) byte            { i, _ := v.Y.(int64); return byte(i) }
func Alt(v *gbgraph.Vertex) *gbgraph.Vertex { p, _ := v.Z.(*gbgraph.Vertex); return p }
func Bit(v *gbgraph.Vertex) int64           { i, _ := v.Z.(int64); return i }
func Outs(g *gbgraph.Graph) *gbgraph.Arc    { a, _ := g.ZZ.(*gbgraph.Arc); return a }

func setVal(v *gbgraph.Vertex, x int64)           { v.X = x }
func setTyp(v *gbgraph.Vertex, t byte)            { v.Y = int64(t) }
func setAlt(v *gbgraph.Vertex, u *gbgraph.Vertex) { v.Z = u }
func setBit(v *gbgraph.Vertex, b int64)           { v.Z = b }
func setBar(v *gbgraph.Vertex, u *gbgraph.Vertex) { v.W = u }
func getBar(v *gbgraph.Vertex) *gbgraph.Vertex    { p, _ := v.W.(*gbgraph.Vertex); return p }

// ---- Gate-building state ----

// builder holds the working state used while constructing a gate graph.
type builder struct {
	g      *gbgraph.Graph
	nextVI int64  // index of next vertex to allocate
	prefix string // current naming prefix
	count  int64  // serial number; -1 = no number (use prefix as-is)
}

func (b *builder) vAt(i int64) *gbgraph.Vertex { return &b.g.Vertices[i] }

func (b *builder) newVert(t byte) *gbgraph.Vertex {
	v := b.vAt(b.nextVI)
	b.nextVI++
	if b.count < 0 {
		v.Name = b.prefix
	} else {
		v.Name = fmt.Sprintf("%s%d", b.prefix, b.count)
		b.count++
	}
	setTyp(v, t)
	return v
}

func (b *builder) startPrefix(s string) { b.prefix = s; b.count = 0 }

// soloPrefix names the next vertex exactly s, with no serial number.
func (b *builder) soloPrefix(s string) { b.prefix = s; b.count = -1 }

func (b *builder) numericPrefix(ch byte, k int64) {
	b.prefix = fmt.Sprintf("%c%d:", ch, k)
	b.count = 0
}

// firstOf creates n vertices of type t and returns the index of the first.
func (b *builder) firstOf(n int64, t byte) int64 {
	idx := b.nextVI
	for range n {
		b.newVert(t)
	}
	return idx
}

func (b *builder) make2(t byte, v1, v2 *gbgraph.Vertex) *gbgraph.Vertex {
	v := b.newVert(t)
	b.g.NewArc(v, v1, DELAY)
	b.g.NewArc(v, v2, DELAY)
	return v
}

func (b *builder) make3(t byte, v1, v2, v3 *gbgraph.Vertex) *gbgraph.Vertex {
	v := b.make2(t, v1, v2)
	b.g.NewArc(v, v3, DELAY)
	return v
}

func (b *builder) make4(t byte, v1, v2, v3, v4 *gbgraph.Vertex) *gbgraph.Vertex {
	v := b.make3(t, v1, v2, v3)
	b.g.NewArc(v, v4, DELAY)
	return v
}

func (b *builder) make5(t byte, v1, v2, v3, v4, v5 *gbgraph.Vertex) *gbgraph.Vertex {
	v := b.make4(t, v1, v2, v3, v4)
	b.g.NewArc(v, v5, DELAY)
	return v
}

// comp returns the complement of v, creating a NOT gate if needed.
// The complement is cached in v.W (bar field).
func (b *builder) comp(v *gbgraph.Vertex) *gbgraph.Vertex {
	if u := getBar(v); u != nil {
		return u
	}
	u := b.vAt(b.nextVI)
	b.nextVI++
	setBar(u, v)
	setBar(v, u)
	u.Name = v.Name + "~"
	setTyp(u, NOT)
	b.g.NewArc(u, v, 1)
	return u
}

// evenComp returns comp(v) if s is odd, v if s is even.
// evenComp returns v when s is odd and comp(v) when s is even, matching the
// original macro even_comp(s,v) == ((s)&1 ? v : comp(v)).
func (b *builder) evenComp(s int64, v *gbgraph.Vertex) *gbgraph.Vertex {
	if s&1 != 0 {
		return v
	}
	return b.comp(v)
}

// makeXor constructs XOR(u,v) = OR(AND(u,comp(v)), AND(comp(u),v)).
func (b *builder) makeXor(u, v *gbgraph.Vertex) *gbgraph.Vertex {
	t1 := b.make2(AND, u, b.comp(v))
	t2 := b.make2(AND, b.comp(u), v)
	return b.make2(OR, t1, t2)
}

// latchit sets latch.alt = AND(u, runBit).
func (b *builder) latchit(u, latch, runBit *gbgraph.Vertex) {
	setAlt(latch, b.make2(AND, u, runBit))
}

// ---- GateEval ----

// GateEval evaluates each gate of g.
// If inVec is non-empty, its characters '0'/'1' are assigned to the input gates.
// If outVec is non-nil it receives the output values.
// Returns 0 on success, -1 on unknown gate type, -2 if g is nil.
func GateEval(g *gbgraph.Graph, inVec string, outVec []byte) int64 {
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
			for a := range v.AllArcs() {
				t &= Val(a.Tip)
			}
		case OR:
			t = 0
			for a := range v.AllArcs() {
				t |= Val(a.Tip)
			}
		case XOR:
			t = 0
			for a := range v.AllArcs() {
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
func tipValue(tip *gbgraph.Vertex) byte {
	if tip == nil {
		return 0
	}
	return byte(Val(tip))
}

// ---- PrintGates ----

// PrintGates writes a symbolic representation of gate graph g to w.
func PrintGates(w io.Writer, g *gbgraph.Graph) {
	for i := int64(0); i < g.N; i++ {
		prGate(w, &g.Vertices[i])
	}
	for a := Outs(g); a != nil; a = a.Next {
		fmt.Fprintf(w, "Output %s\n", a.Tip.Name)
	}
}

func prGate(w io.Writer, v *gbgraph.Vertex) {
	fmt.Fprintf(w, "%s = ", v.Name)
	switch Typ(v) {
	case INP:
		fmt.Fprint(w, "input")
	case LAT:
		fmt.Fprint(w, "latch")
		if u := Alt(v); u != nil {
			fmt.Fprintf(w, "ed %s", u.Name)
		}
	case NOT:
		fmt.Fprint(w, "~ ")
	case CON:
		fmt.Fprintf(w, "constant %d", Bit(v))
	case EQL:
		fmt.Fprintf(w, "copy of %s", Alt(v).Name)
	}
	first := true
	for a := range v.AllArcs() {
		if !first {
			fmt.Fprintf(w, " %c ", Typ(v))
		}
		fmt.Fprint(w, a.Tip.Name)
		first = false
	}
	fmt.Fprintln(w)
}

// ---- Risc ----

// Risc constructs a gate graph for a simple 16-bit RISC CPU.
// regs must be 2..16; values outside this range are replaced with 16.
// The graph has 1400+115*regs vertices.
// UtilTypes = "ZZZIIVZZZZZZZA".
func Risc(regs int64) (*gbgraph.Graph, error) {
	if regs < 2 || regs > 16 {
		regs = 16
	}
	// Allocate generously; trim after construction.
	g := gbgraph.NewGraph(8 * (1400 + 115*regs))
	if g == nil {
		return nil, gbgraph.ErrNoRoom
	}
	g.ID = fmt.Sprintf("risc(%d)", regs)
	g.UtilTypes = "ZZZIIVZZZZZZZA"

	b := &builder{g: g}
	b.buildRisc(regs)

	g.N = b.nextVI
	g.Vertices = g.Vertices[:b.nextVI+gbgraph.ExtraN]
	return g, nil
}

func (b *builder) buildRisc(regs int64) {
	// ---- Inputs and latches ----
	b.soloPrefix("RUN")
	runBit := b.newVert(INP)

	b.startPrefix("M")
	var mem [16]*gbgraph.Vertex
	for k := range int64(16) {
		mem[k] = b.newVert(INP)
	}

	b.startPrefix("P")
	progIdx := b.firstOf(10, LAT)

	b.soloPrefix("S")
	sign := b.newVert(LAT)
	b.soloPrefix("N")
	nonzero := b.newVert(LAT)
	b.soloPrefix("K")
	carry := b.newVert(LAT)
	b.soloPrefix("V")
	overflow := b.newVert(LAT)
	b.soloPrefix("X")
	extra := b.newVert(LAT)

	regIdx := make([]int64, regs)
	for r := range regs {
		b.numericPrefix('R', r)
		regIdx[r] = b.firstOf(16, LAT)
	}

	// ---- Instruction decoding ----
	b.startPrefix("D")
	imm := b.make3(AND, b.comp(extra), b.comp(mem[4]), b.comp(mem[5])) // A=0
	rel := b.make3(AND, b.comp(extra), mem[4], b.comp(mem[5]))         // A=1
	dir := b.make3(AND, b.comp(extra), b.comp(mem[4]), mem[5])         // A=2
	ind := b.make3(AND, b.comp(extra), mem[4], mem[5])                 // A=3

	op := b.make2(OR, b.make2(AND, extra, b.vAt(progIdx)), b.make2(AND, b.comp(extra), mem[6]))
	cond := b.make2(OR, b.make2(AND, extra, b.vAt(progIdx+1)), b.make2(AND, b.comp(extra), mem[7]))

	var mod [4]*gbgraph.Vertex
	var dest [4]*gbgraph.Vertex
	for k := range int64(4) {
		mod[k] = b.make2(OR, b.make2(AND, extra, b.vAt(progIdx+2+k)), b.make2(AND, b.comp(extra), mem[8+k]))
		dest[k] = b.make2(OR, b.make2(AND, extra, b.vAt(progIdx+6+k)), b.make2(AND, b.comp(extra), mem[12+k]))
	}

	// ---- Fetch source value ----
	b.startPrefix("F")

	// old_dest: present value of destination register
	var destMatch [16]*gbgraph.Vertex
	for r := range regs {
		destMatch[r] = b.make4(AND,
			b.evenComp(r, dest[0]), b.evenComp(r>>1, dest[1]),
			b.evenComp(r>>2, dest[2]), b.evenComp(r>>3, dest[3]))
	}
	var oldDest [16]*gbgraph.Vertex
	var tmp [16]*gbgraph.Vertex
	for k := range int64(16) {
		for r := range regs {
			tmp[r] = b.make2(AND, destMatch[r], b.vAt(regIdx[r]+k))
		}
		oldDest[k] = b.newVert(OR)
		for r := range regs {
			b.g.NewArc(oldDest[k], tmp[r], DELAY)
		}
	}

	// old_src: present value of source register
	var oldSrc [16]*gbgraph.Vertex
	for k := range int64(16) {
		for r := range regs {
			tmp[r] = b.make5(AND, b.vAt(regIdx[r]+k),
				b.evenComp(r, mem[0]), b.evenComp(r>>1, mem[1]),
				b.evenComp(r>>2, mem[2]), b.evenComp(r>>3, mem[3]))
		}
		oldSrc[k] = b.newVert(OR)
		for r := range regs {
			b.g.NewArc(oldSrc[k], tmp[r], DELAY)
		}
	}

	// inc_dest: old_dest + SRC (4-bit adder for low 4 bits)
	var incDest [16]*gbgraph.Vertex
	b.makeAdder(4, oldDest[:], mem[:], incDest[:], nil, true)
	up := b.make2(AND, incDest[4], b.comp(mem[3]))
	down := b.make2(AND, b.comp(incDest[4]), mem[3])
	for k := int64(4); ; k++ {
		b.comp(up)
		b.comp(down)
		incDest[k] = b.make3(OR,
			b.make2(AND, b.comp(oldDest[k]), up),
			b.make2(AND, b.comp(oldDest[k]), down),
			b.make3(AND, oldDest[k], b.comp(up), b.comp(down)))
		if k < 15 {
			up = b.make2(AND, up, oldDest[k])
			down = b.make2(AND, down, b.comp(oldDest[k]))
		} else {
			break
		}
	}

	// source[k]
	var source [16]*gbgraph.Vertex
	for k := range int64(16) {
		immK := mem[k]
		if k >= 4 {
			immK = mem[3]
		}
		source[k] = b.make4(OR,
			b.make2(AND, imm, immK),
			b.make2(AND, rel, incDest[k]),
			b.make2(AND, dir, oldSrc[k]),
			b.make2(AND, extra, mem[k]))
	}

	// ---- General logic operation ----
	b.startPrefix("L")
	var logOp [16]*gbgraph.Vertex
	for k := range int64(16) {
		logOp[k] = b.make4(OR,
			b.make3(AND, mod[0], b.comp(oldDest[k]), b.comp(source[k])),
			b.make3(AND, mod[1], b.comp(oldDest[k]), source[k]),
			b.make3(AND, mod[2], oldDest[k], b.comp(source[k])),
			b.make3(AND, mod[3], oldDest[k], source[k]))
	}

	// ---- Conditional load ----
	b.startPrefix("C")
	tmp[0] = b.make4(OR,
		b.make3(AND, mod[0], b.comp(sign), b.comp(nonzero)),
		b.make3(AND, mod[1], b.comp(sign), nonzero),
		b.make3(AND, mod[2], sign, b.comp(nonzero)),
		b.make3(AND, mod[3], sign, nonzero))
	tmp[1] = b.make4(OR,
		b.make3(AND, mod[0], b.comp(carry), b.comp(overflow)),
		b.make3(AND, mod[1], b.comp(carry), overflow),
		b.make3(AND, mod[2], carry, b.comp(overflow)),
		b.make3(AND, mod[3], carry, overflow))
	change := b.make3(OR, b.comp(cond), b.make2(AND, tmp[0], b.comp(op)), b.make2(AND, tmp[1], op))

	// ---- Arithmetic ----
	b.startPrefix("A")

	// Shift operations
	var shift [18]*gbgraph.Vertex
	for k := range int64(16) {
		var s0, s1, s2, s3 *gbgraph.Vertex
		if k == 0 {
			s0 = b.make4(AND, source[15], mod[0], b.comp(mod[1]), b.comp(mod[2]))
		} else {
			s0 = b.make3(AND, source[k-1], b.comp(mod[1]), b.comp(mod[2]))
		}
		if k < 4 {
			s1 = b.make4(AND, source[k+12], mod[0], mod[1], b.comp(mod[2]))
		} else {
			s1 = b.make3(AND, source[k-4], mod[1], b.comp(mod[2]))
		}
		if k == 15 {
			s2 = b.make4(AND, source[15], b.comp(mod[0]), b.comp(mod[1]), mod[2])
		} else {
			s2 = b.make3(AND, source[k+1], b.comp(mod[1]), mod[2])
		}
		if k > 11 {
			s3 = b.make4(AND, source[15], b.comp(mod[0]), mod[1], mod[2])
		} else {
			s3 = b.make3(AND, source[k+4], mod[1], mod[2])
		}
		shift[k] = b.make4(OR, s0, s1, s2, s3)
	}
	shift[16] = b.make4(OR,
		b.make2(AND, b.comp(mod[2]), source[15]),
		b.make3(AND, b.comp(mod[2]), mod[1], b.make3(OR, source[14], source[13], source[12])),
		b.make3(AND, mod[2], b.comp(mod[1]), source[0]),
		b.make3(AND, mod[2], mod[1], source[3]))
	shift[17] = b.make3(OR,
		b.make3(AND, b.comp(mod[2]), b.comp(mod[1]), b.makeXor(source[15], source[14])),
		b.make4(AND, b.comp(mod[2]), mod[1],
			b.make5(OR, source[15], source[14], source[13], source[12], source[11]),
			b.make5(OR, b.comp(source[15]), b.comp(source[14]), b.comp(source[13]), b.comp(source[12]), b.comp(source[11]))),
		b.make3(AND, mod[2], mod[1], b.make3(OR, source[0], source[1], source[2])))

	var sum [18]*gbgraph.Vertex
	var diff [18]*gbgraph.Vertex
	b.makeAdder(16, oldDest[:], source[:], sum[:], b.make2(AND, carry, mod[0]), true)
	b.makeAdder(16, oldDest[:], source[:], diff[:], b.make2(AND, carry, mod[0]), false)
	sum[17] = b.make2(OR,
		b.make3(AND, oldDest[15], source[15], b.comp(sum[15])),
		b.make3(AND, b.comp(oldDest[15]), b.comp(source[15]), sum[15]))
	diff[17] = b.make2(OR,
		b.make3(AND, oldDest[15], b.comp(source[15]), b.comp(diff[15])),
		b.make3(AND, b.comp(oldDest[15]), source[15], diff[15]))

	// ---- Bring everything together ----
	b.startPrefix("Z")

	// next_loc and next_next_loc (reg[0] + 1 and + 2)
	var nextLoc [16]*gbgraph.Vertex
	var nextNextLoc [16]*gbgraph.Vertex
	nextLoc[0] = b.comp(b.vAt(regIdx[0]))
	nextNextLoc[0] = b.vAt(regIdx[0])
	nextLoc[1] = b.makeXor(b.vAt(regIdx[0]+1), b.vAt(regIdx[0]))
	nextNextLoc[1] = b.comp(b.vAt(regIdx[0] + 1))
	t5 := b.vAt(regIdx[0] + 1)
	for k := int64(2); k < 16; k++ {
		nextLoc[k] = b.makeXor(b.vAt(regIdx[0]+k), b.make2(AND, b.vAt(regIdx[0]), t5))
		nextNextLoc[k] = b.makeXor(b.vAt(regIdx[0]+k), t5)
		if k < 15 {
			t5 = b.make2(AND, t5, b.vAt(regIdx[0]+k))
		}
	}

	// result bits
	jump := b.make5(AND, op, mod[0], mod[1], mod[2], mod[3])
	var result [18]*gbgraph.Vertex
	for k := range int64(16) {
		result[k] = b.make5(OR,
			b.make2(AND, b.comp(op), logOp[k]),
			b.make2(AND, jump, nextLoc[k]),
			b.make3(AND, op, b.comp(mod[3]), shift[k]),
			b.make5(AND, op, mod[3], b.comp(mod[2]), b.comp(mod[1]), sum[k]),
			b.make5(AND, op, mod[3], b.comp(mod[2]), mod[1], diff[k]))
		result[k] = b.make2(OR,
			b.make3(AND, cond, change, source[k]),
			b.make2(AND, b.comp(cond), result[k]))
	}
	for k := int64(16); k < 18; k++ {
		result[k] = b.make3(OR,
			b.make3(AND, op, b.comp(mod[3]), shift[k]),
			b.make5(AND, op, mod[3], b.comp(mod[2]), b.comp(mod[1]), sum[k]),
			b.make5(AND, op, mod[3], b.comp(mod[2]), mod[1], diff[k]))
	}

	// Program register and extra bit
	for k := range int64(10) {
		b.latchit(mem[k+6], b.vAt(progIdx+k), runBit)
	}
	nextra := b.make2(OR, b.make2(AND, ind, b.comp(cond)), b.make2(AND, ind, change))
	b.latchit(nextra, extra, runBit)
	nzs := b.make4(OR, mem[0], mem[1], mem[2], mem[3])
	nzd := b.make4(OR, dest[0], dest[1], dest[2], dest[3])

	// New values for registers 1..regs-1
	t5chg := b.make2(AND, change, b.comp(ind))
	for r := int64(1); r < regs; r++ {
		t4 := b.make2(AND, t5chg, destMatch[r])
		for k := range int64(16) {
			t3 := b.make2(OR, b.make2(AND, t4, result[k]), b.make2(AND, b.comp(t4), b.vAt(regIdx[r]+k)))
			b.latchit(t3, b.vAt(regIdx[r]+k), runBit)
		}
	}

	// New values of S, N, K, V
	t5 = b.make4(OR,
		b.make2(AND, sign, cond),
		b.make2(AND, sign, jump),
		b.make2(AND, sign, ind),
		b.make4(AND, result[15], b.comp(cond), b.comp(jump), b.comp(ind)))
	b.latchit(t5, sign, runBit)

	t5 = b.make4(OR,
		b.make4(OR, result[0], result[1], result[2], result[3]),
		b.make4(OR, result[4], result[5], result[6], result[7]),
		b.make4(OR, result[8], result[9], result[10], result[11]),
		b.make4(OR, result[12], result[13], result[14],
			b.make5(AND, b.make2(OR, nonzero, sign), op, mod[0], b.comp(mod[2]), mod[3])))
	t5 = b.make4(OR,
		b.make2(AND, nonzero, cond),
		b.make2(AND, nonzero, jump),
		b.make2(AND, nonzero, ind),
		b.make4(AND, t5, b.comp(cond), b.comp(jump), b.comp(ind)))
	b.latchit(t5, nonzero, runBit)

	t5 = b.make5(OR,
		b.make2(AND, overflow, cond),
		b.make2(AND, overflow, jump),
		b.make2(AND, overflow, b.comp(op)),
		b.make2(AND, overflow, ind),
		b.make5(AND, result[17], b.comp(cond), b.comp(jump), b.comp(ind), op))
	b.latchit(t5, overflow, runBit)

	t5 = b.make5(OR,
		b.make2(AND, carry, cond),
		b.make2(AND, carry, jump),
		b.make2(AND, carry, b.comp(op)),
		b.make2(AND, carry, ind),
		b.make5(AND, result[16], b.comp(cond), b.comp(jump), b.comp(ind), op))
	b.latchit(t5, carry, runBit)

	// New values of register 0 and memory address register (outputs)
	skip := b.make2(AND, cond, b.comp(change))
	hop := b.make2(AND, b.comp(cond), jump)
	normal := b.make4(OR,
		b.make2(AND, skip, b.comp(ind)),
		b.make2(AND, skip, nzs),
		b.make3(AND, b.comp(skip), ind, b.comp(nzs)),
		b.make3(AND, b.comp(skip), b.comp(hop), nzd))
	special := b.make3(AND, b.comp(skip), ind, nzs)

	for k := range int64(16) {
		t5 = b.make4(OR,
			b.make2(AND, normal, nextLoc[k]),
			b.make4(AND, skip, ind, b.comp(nzs), nextNextLoc[k]),
			b.make3(AND, hop, b.comp(ind), source[k]),
			b.make5(AND, b.comp(skip), b.comp(hop), b.comp(ind), b.comp(nzd), result[k]))
		t4 := b.make2(OR,
			b.make2(AND, special, b.vAt(regIdx[0]+k)),
			b.make2(AND, b.comp(special), t5))
		b.latchit(t4, b.vAt(regIdx[0]+k), runBit)
		t4 = b.make2(OR,
			b.make2(AND, special, oldSrc[k]),
			b.make2(AND, b.comp(special), t5))
		// output arc (big-endian order: prepend)
		a := &gbgraph.Arc{}
		a.Tip = b.make2(AND, t4, runBit)
		a.Next, _ = b.g.ZZ.(*gbgraph.Arc)
		b.g.ZZ = a
	}
}

// makeAdder builds an n-bit ripple-carry adder (add=true) or subtracter (add=false).
// x[0..n-1], y[0..n-1] are input gate pointer slices; z[0..n] receives output gate pointers.
// carry is an optional incoming carry gate (nil = no incoming carry).
func (b *builder) makeAdder(n int64, x, y, z []*gbgraph.Vertex, carry *gbgraph.Vertex, add bool) {
	k := int64(0)
	if carry == nil {
		z[0] = b.makeXor(x[0], y[0])
		if add {
			carry = b.make2(AND, x[0], y[0])
		} else {
			carry = b.make2(AND, b.comp(x[0]), y[0])
		}
		k = 1
	}
	for ; k < n; k++ {
		b.comp(x[k])
		b.comp(y[k])
		b.comp(carry)
		z[k] = b.make4(OR,
			b.make3(AND, x[k], b.comp(y[k]), b.comp(carry)),
			b.make3(AND, b.comp(x[k]), y[k], b.comp(carry)),
			b.make3(AND, b.comp(x[k]), b.comp(y[k]), carry),
			b.make3(AND, x[k], y[k], carry))
		carry = b.make3(OR,
			b.make2(AND, b.evenComp(boolInt(add), x[k]), y[k]),
			b.make2(AND, b.evenComp(boolInt(add), x[k]), carry),
			b.make2(AND, y[k], carry))
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
// traceRegs, if >0, writes the register state to w each cycle (w may be nil
// when traceRegs is 0).
//
// Returns the final machine state and a status code (0 on success, negative
// on error): state[0..15] hold the registers and state[16] packs the program
// counter and the X, S, N, K, V flags.
func RunRisc(w io.Writer, g *gbgraph.Graph, rom []uint64, size, traceRegs int64) (state [18]uint64, status int64) {
	if g == nil {
		return state, -2
	}
	if traceRegs > 0 {
		for r := range traceRegs {
			fmt.Fprintf(w, " r%-2d ", r)
		}
		fmt.Fprintln(w, " P XSNKV MEM")
	}

	r := GateEval(g, "0", nil) // reset: RUN=0
	if r < 0 {
		return state, r
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
			printRiscState(w, g, traceRegs, l, rom, size)
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
		fmt.Fprintf(w, "Execution terminated with memory address %d.\n", l)
	}
	return dumpRiscState(g), 0
}

// RISC vertex layout (from buildRisc):
//   0       = RUN
//   1..16   = M0..M15
//   17..26  = P0..P9  (prog, 10-bit PC)
//   27      = S (sign), 28=N (nonzero), 29=K (carry), 30=V (overflow), 31=X (extra)
//   32+16*r .. 47+16*r = R[r]:0 .. R[r]:15

func riscRegVal(g *gbgraph.Graph, r int64) uint64 {
	var m uint64
	for k := int64(15); k >= 0; k-- {
		m = 2*m + uint64(Val(&g.Vertices[32+16*r+k]))
	}
	return m
}

func printRiscState(w io.Writer, g *gbgraph.Graph, traceRegs int64, l uint64, rom []uint64, size int64) {
	for r := range traceRegs {
		fmt.Fprintf(w, "%04x ", riscRegVal(g, r))
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
	fmt.Fprintf(w, "%03x%c%c%c%c%c ", m, xc, sc, nc, cc, oc)
	if l >= uint64(size) {
		fmt.Fprintln(w, "????")
	} else {
		fmt.Fprintf(w, "%04x\n", rom[l])
	}
}

func dumpRiscState(g *gbgraph.Graph) (state [18]uint64) {
	for r := range int64(16) {
		state[r] = riscRegVal(g, r)
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
	state[16] = m
	return state
}

// ---- Prod ----

// Prod constructs a gate graph for parallel multiplication of m-bit by n-bit numbers.
// m >= 2 and n >= 2; smaller values are replaced with 2.
// The result is reduced (simplified) before being returned.
// UtilTypes = "ZZZIIVZZZZZZZA".
func Prod(m, n int64) (*gbgraph.Graph, error) {
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
	g := gbgraph.NewGraph(size)
	if g == nil {
		return nil, gbgraph.ErrNoRoom
	}
	g.ID = fmt.Sprintf("prod(%d,%d)", m, n)
	g.UtilTypes = "ZZZIIVZZZZZZZA"

	b := &builder{g: g}
	b.buildProd(m, n, mPlusN, f)

	g.N = b.nextVI // actual number of gates used
	g.Vertices = g.Vertices[:g.N+gbgraph.ExtraN]

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

func (b *builder) buildProd(m, n, mPlusN, f int64) {
	b.startPrefix("X")
	xIdx := b.firstOf(m, INP)
	b.startPrefix("Y")
	yIdx := b.firstOf(n, INP)

	// Define A_j for 0 <= j < m
	for j := range m {
		b.numericPrefix('A', j)
		for k := int64(0); k < j; k++ {
			v := b.newVert(CON)
			setBit(v, 0)
		}
		for k := range n {
			b.make2(AND, b.vAt(xIdx+j), b.vAt(yIdx+k))
		}
		for k := j + n; k < mPlusN; k++ {
			v := b.newVert(CON)
			setBit(v, 0)
		}
	}

	// Define P_j, Q_j, A_{m+2j}, R_j, A_{m+2j+1} for 0 <= j < m-2
	for j := int64(0); j < m-2; j++ {
		alpha := aPos(3*j, m) * mPlusN
		beta := aPos(3*j+1, m) * mPlusN
		b.numericPrefix('P', j)
		for k := range mPlusN {
			b.make2(XOR, b.vAt(alpha+k), b.vAt(beta+k))
		}
		b.numericPrefix('Q', j)
		for k := range mPlusN {
			b.make2(AND, b.vAt(alpha+k), b.vAt(beta+k))
		}
		alpha2 := b.nextVI - 2*mPlusN
		beta2 := aPos(3*j+2, m) * mPlusN
		b.numericPrefix('A', m+2*j)
		for k := range mPlusN {
			b.make2(XOR, b.vAt(alpha2+k), b.vAt(beta2+k))
		}
		b.numericPrefix('R', j)
		for k := range mPlusN {
			b.make2(AND, b.vAt(alpha2+k), b.vAt(beta2+k))
		}
		alpha3 := b.nextVI - 3*mPlusN
		beta3 := b.nextVI - mPlusN
		b.numericPrefix('A', m+2*j+1)
		v := b.newVert(CON)
		setBit(v, 0)
		for k := int64(0); k < mPlusN-1; k++ {
			b.make2(OR, b.vAt(alpha3+k), b.vAt(beta3+k))
		}
	}

	// Define U and V
	alpha := aPos(3*m-6, m) * mPlusN
	beta := aPos(3*m-5, m) * mPlusN
	b.startPrefix("U")
	for k := range mPlusN {
		b.make2(XOR, b.vAt(alpha+k), b.vAt(beta+k))
	}
	b.startPrefix("V")
	for k := range mPlusN {
		b.make2(AND, b.vAt(alpha+k), b.vAt(beta+k))
	}

	// Parallel addition: compute Z = U ⊕ W
	uu := b.nextVI - mPlusN - mPlusN // points to U[0]
	vv := b.nextVI - mPlusN          // points to V[0]

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

	w := make([]*gbgraph.Vertex, mPlusN)
	cT := make([]*gbgraph.Vertex, f*mPlusN)

	b.startPrefix("W")
	v0 := b.newVert(CON)
	setBit(v0, 0)
	w[0] = v0
	v1 := b.newVert(EQL)
	setAlt(v1, b.vAt(vv))
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
		cc := b.vAt(vv + k - 1)
		dd := b.vAt(uu + k - 1)

		for {
			j := anc[l]
			// gate b_k^j = d_k^i AND c_{k-i}^{j-i}
			bv := b.vAt(b.nextVI)
			b.nextVI++
			bv.Name = fmt.Sprintf("B%d:%d", k, j)
			setTyp(bv, AND)
			b.g.NewArc(bv, dd, DELAY)
			ji := j - i
			fl := flogT[ji]
			var cArg *gbgraph.Vertex
			if fl > 0 {
				cArg = cT[(k-i)+(fl-2)*mPlusN]
			} else {
				cArg = b.vAt(vv + k - i - 1)
			}
			b.g.NewArc(bv, cArg, DELAY)

			// gate c_k^j = c_k^i OR b_k^j
			var cv *gbgraph.Vertex
			if l != 0 {
				cv = b.vAt(b.nextVI)
				b.nextVI++
				cv.Name = fmt.Sprintf("C%d:%d", k, j)
				setTyp(cv, OR)
			} else {
				cv = b.newVert(OR)
			}
			b.g.NewArc(cv, cc, DELAY)
			b.g.NewArc(cv, bv, DELAY)

			if flogT[j] < flogT[j+1] { // j is a Fibonacci number
				cT[k+(flogT[j]-2)*mPlusN] = cv
			}
			if l == 0 {
				break
			}
			cc = cv

			// gate d_k^j = d_k^i AND d_{k-i}^{j-i}
			dv := b.vAt(b.nextVI)
			b.nextVI++
			dv.Name = fmt.Sprintf("D%d:%d", k, j)
			setTyp(dv, AND)
			b.g.NewArc(dv, dd, DELAY)
			var dArg *gbgraph.Vertex
			if fl > 0 {
				// d_{k-i}^{j-i} is the gate immediately following the
				// stored C gate; the original uses Vertex-pointer
				// arithmetic c[...]+1, since the C and D gates are
				// allocated consecutively.
				cGate := cT[(k-i)+(fl-2)*mPlusN]
				dArg = b.vAt(gbgraph.VertexIndex(b.g, cGate) + 1)
			} else {
				dArg = b.vAt(uu + k - i - 1)
			}
			b.g.NewArc(dv, dArg, DELAY)
			dd = dv
			i = j
			l--
		}
		w[k] = b.vAt(b.nextVI - 1)
	}

	// Compute Z = U XOR W, record outputs
	b.startPrefix("Z")
	for k := range mPlusN {
		zv := b.make2(XOR, b.vAt(uu+k), w[k])
		a := &gbgraph.Arc{}
		a.Tip = zv
		a.Next, _ = b.g.ZZ.(*gbgraph.Arc)
		b.g.ZZ = a
	}
}

// ---- reduce (internal) ----

// reduce simplifies a generalized gate graph by eliminating constant and copy gates.
// It marks only reachable gates and copies them to a new graph. g is recycled.
func reduce(g *gbgraph.Graph) (*gbgraph.Graph, error) {
	if g == nil {
		return nil, gbgraph.ErrMissingOperand
	}
	sentinel := g.N
	// Builder over the old graph: reduceXor may append fresh NOT gates after
	// the existing ones (the slack comes from the graph's shadow vertices).
	b := &builder{g: g, nextVI: sentinel}

	// Iterate until no more constant latches are produced.
	for {
		latchPtr := []*gbgraph.Vertex(nil) // list of latches linked via V
		for i := range sentinel {
			v := &g.Vertices[i]
			b.reduceGate(v, &latchPtr)
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
	for i := range sentinel {
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
	newG := gbgraph.NewGraph(n)
	if newG == nil {
		return nil, gbgraph.ErrNoRoom
	}
	newG.ID = g.ID
	newG.UtilTypes = "ZZZIIVZZZZZZZA"

	// Build mapping from old to new vertices (stored in old vertex's V field after marking)
	newVI := int64(0)
	var latchList []*gbgraph.Vertex // old latch vertices to fix up

	for i := range sentinel {
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
		var reversed []*gbgraph.Arc
		for a := range v.AllArcs() {
			reversed = append(reversed, a)
		}
		for j := len(reversed) - 1; j >= 0; j-- {
			a := reversed[j]
			tip := a.Tip
			newTip, _ := tip.V.(*gbgraph.Vertex)
			if newTip != nil {
				newG.NewArc(u, newTip, a.Len)
			}
		}
	}

	// Fix up latch alt fields
	for _, v := range latchList {
		u, _ := v.V.(*gbgraph.Vertex)
		oldAlt := Alt(v)
		if oldAlt == nil {
			continue
		}
		newAlt, _ := oldAlt.V.(*gbgraph.Vertex)
		if newAlt != nil && vertIdx(g, oldAlt) < vertIdx(g, v) {
			// The latched gate precedes the latch, so reading it directly would
			// yield the current cycle's value; insert an OR "copy gate" after the
			// latch that captures it (the original reduce does the same, and an OR
			// must have two inputs, hence the doubled arc).
			orV := &newG.Vertices[newVI]
			newVI++
			orV.Name = fmt.Sprintf("%s>%s", oldAlt.Name, u.Name)
			setTyp(orV, OR)
			newG.NewArc(orV, newAlt, DELAY)
			newG.NewArc(orV, newAlt, DELAY)
			setAlt(u, orV)
		} else {
			setAlt(u, newAlt)
		}
	}

	// Copy output arc list
	var outArcs []*gbgraph.Arc
	for a := Outs(g); a != nil; a = a.Next {
		outArcs = append(outArcs, a)
	}
	for i := len(outArcs) - 1; i >= 0; i-- {
		a := outArcs[i]
		b := &gbgraph.Arc{}
		if a.Tip != nil {
			newTip, _ := a.Tip.V.(*gbgraph.Vertex)
			b.Tip = newTip
		}
		b.Next, _ = newG.ZZ.(*gbgraph.Arc)
		newG.ZZ = b
	}

	return newG, nil
}

// reduceGate simplifies gate v in place using identity rules.
func (b *builder) reduceGate(v *gbgraph.Vertex, latchPtr *[]*gbgraph.Vertex) {
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
		b.reduceXor(v)
	}
	// test_single_arg
	if v.Arcs != nil && v.Arcs.Next == nil {
		setAlt(v, v.Arcs.Tip)
		setTyp(v, EQL)
		v.Arcs = nil
	}
	setBar(v, nil)
}

func reduceAnd(v *gbgraph.Vertex) {
	var prev *gbgraph.Arc
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

func reduceOr(v *gbgraph.Vertex) {
	var prev *gbgraph.Arc
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

func (b *builder) reduceXor(v *gbgraph.Vertex) {
	cmp := int64(0)
	var prev *gbgraph.Arc
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
		var prevB *gbgraph.Arc
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
				nb := b.vAt(b.nextVI)
				b.nextVI++
				nb.Name = u.Name + "~"
				setTyp(nb, NOT)
				b.g.NewArc(nb, u, 1)
				setBar(u, nb)
				setBar(nb, u)
				a.Tip = nb
				break
			}
		}
	}
}

// markGates marks v and all gates it depends on via DFS.
func markGates(g *gbgraph.Graph, v *gbgraph.Vertex, n *int64) {
	if v.V != nil {
		return // already marked
	}
	// Use a stack for iterative DFS
	type frame struct {
		v    *gbgraph.Vertex
		next *gbgraph.Arc
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
				stack = append(stack, frame{altV, altV.Arcs})
				continue
			}
			// About to pop this latch: if its latched gate precedes it, the copy
			// phase inserts an OR "copy gate" for it, so count that gate now —
			// unconditionally, matching the original's `if (u<v) n++`.
			if altV != nil && vertIdx(g, altV) < vertIdx(g, top.v) {
				*n++
			}
		}
		stack = stack[:len(stack)-1]
	}
}

func vertIdx(g *gbgraph.Graph, v *gbgraph.Vertex) int64 {
	return gbgraph.VertexIndex(g, v)
}

// ---- PartialGates ----

// PartialGates performs partial evaluation of gate graph g.
// The first r input gates are retained. Each subsequent input is retained
// with probability prob/65536; otherwise it gets a random constant value.
// buf, if non-nil, receives '*', '0', or '1' for each non-retained input.
// g is destroyed in the process; the reduced graph is returned.
func PartialGates(g *gbgraph.Graph, r, prob, seed int64, buf []byte) (*gbgraph.Graph, error) {
	if g == nil {
		return nil, gbgraph.ErrMissingOperand
	}
	rng := gbflip.New(seed)

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
