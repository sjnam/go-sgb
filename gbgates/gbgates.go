//line gbgates.w:79
package gbgates

import (
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
)

const (
	AND   = '&'
	OR    = '|'
	NOT   = '~'
	XOR   = '^'
	DELAY = 100 // 게이트에서 인수로 가는 호의 길이
)

var (
	gateFalse = &gbgraph.Vertex{}                      // 상수 0 (|X.I=0|)
	gateTrue  = &gbgraph.Vertex{X: gbgraph.Util{I: 1}} // 상수 1 (|X.I=1|)
)

func isBoolean(v *gbgraph.Vertex) bool { return v == gateFalse || v == gateTrue }

//line gbgates.w:105
func theBoolean(v *gbgraph.Vertex) int64 {
	if v == gateTrue {
		return 1
	}
	return 0
}

//line gbgates.w:106
func tipValue(v *gbgraph.Vertex) int64 { return v.X.I }

//line gbgates.w:107
func boolGate(bit int64) *gbgraph.Vertex {
	if bit != 0 {
		return gateTrue
	}
	return gateFalse
}

// IsBoolean은 v가 상수 게이트(0이나 1)인지 알려주는 공개 술어다.
//
//line gbgates.w:109
//line gbgates.w:110
func IsBoolean(v *gbgraph.Vertex) bool { return isBoolean(v) }

//line gbgates.w:195
type builder struct {
	g      *gbgraph.Graph
	nextV  int    // 아직 이름을 안 매긴 첫 정점
	prefix string // 정점 이름의 접두사
	count  int64  // 정점 이름의 일련번호
}

func (b *builder) newVert(t int64) *gbgraph.Vertex {
	v := &b.g.Vertices[b.nextV]
	b.nextV++
	if b.count < 0 {
		v.Name = b.prefix
	} else {
		v.Name = b.prefix + strconv.FormatInt(b.count, 10)
		b.count++
	}
	v.Y.I = t
	return v
}

//line gbgates.w:220
func (b *builder) vAt(i int64) *gbgraph.Vertex { return &b.g.Vertices[i] }

func (b *builder) at(v *gbgraph.Vertex, k int64) *gbgraph.Vertex {
	return &b.g.Vertices[b.g.Index(v)+k]
}

func (b *builder) startPrefix(s string) { b.prefix = s; b.count = 0 }

func (b *builder) numericPrefix(a byte, n int64) {
	b.prefix = fmt.Sprintf("%c%d:", a, n)
	b.count = 0
}

func (b *builder) firstOf(n int, t int64) *gbgraph.Vertex {
	first := b.newVert(t)
	for k := 1; k < n; k++ {
		b.newVert(t)
	}
	return first
}

//line gbgates.w:247
func (b *builder) make2(t int64, v1, v2 *gbgraph.Vertex) *gbgraph.Vertex {
	v := b.newVert(t)
	b.g.NewArc(v, v1, DELAY)
	b.g.NewArc(v, v2, DELAY)
	return v
}

func (b *builder) make3(t int64, v1, v2, v3 *gbgraph.Vertex) *gbgraph.Vertex {
	v := b.make2(t, v1, v2)
	b.g.NewArc(v, v3, DELAY)
	return v
}

func (b *builder) make4(t int64, v1, v2, v3, v4 *gbgraph.Vertex) *gbgraph.Vertex {
	v := b.make3(t, v1, v2, v3)
	b.g.NewArc(v, v4, DELAY)
	return v
}

func (b *builder) make5(t int64, v1, v2, v3, v4, v5 *gbgraph.Vertex) *gbgraph.Vertex {
	v := b.make4(t, v1, v2, v3, v4)
	b.g.NewArc(v, v5, DELAY)
	return v
}

//line gbgates.w:278
func (b *builder) comp(v *gbgraph.Vertex) *gbgraph.Vertex {
	if v.W.V != nil {
		return v.W.V
	}
	u := &b.g.Vertices[b.nextV]
	b.nextV++
	u.W.V, v.W.V = v, u
	u.Name = v.Name + "~"
	u.Y.I = NOT
	b.g.NewArc(u, v, 1)
	return u
}

func (b *builder) evenComp(s int64, v *gbgraph.Vertex) *gbgraph.Vertex {
	if s&1 != 0 {
		return v
	}
	return b.comp(v)
}

func (b *builder) makeXor(u, v *gbgraph.Vertex) *gbgraph.Vertex {
	t1 := b.make2(AND, u, b.comp(v))
	t2 := b.make2(AND, b.comp(u), v)
	return b.make2(OR, t1, t2)
}

//line gbgates.w:136
func GateEval(g *gbgraph.Graph, inVec string) (string, int64) {
	if g == nil {
		return "", -2 // 그래프가 없다
	}
	vi := 0
	for i := 0; i < len(inVec) && vi < int(g.N); i++ {
		g.Vertices[vi].X.I = int64(inVec[i] - '0')
		vi++
	}
	for ; vi < int(g.N); vi++ {
		v := &g.Vertices[vi]
		var t int64

//line gbgates.w:155
		switch v.Y.I {
		case 'I':
			continue // 입력 게이트 값은 밖에서 매긴다
		case 'L':
			t = v.Z.V.X.I // |alt.val|
		case AND:
			t = 1
			for a := range v.AllArcs() {
				t &= a.Tip.X.I
			}
		case OR:
			t = 0
			for a := range v.AllArcs() {
				t |= a.Tip.X.I
			}
		case XOR:
			t = 0
			for a := range v.AllArcs() {
				t ^= a.Tip.X.I
			}
		case NOT:
			t = 1 - v.Arcs.Tip.X.I
		default:
			return "", -1 // 모르는 게이트 종류
		}

//line gbgates.w:149
		v.X.I = t
	}

//line gbgates.w:182
	var sb strings.Builder
	for a := g.ZZ.A; a != nil; a = a.Next {
		sb.WriteByte(byte('0' + tipValue(a.Tip)))
	}
	return sb.String(), 0

//line gbgates.w:152
}

//line gbgates.w:389
func Risc(regs int64) (*gbgraph.Graph, error) {
	if regs < 2 || regs > 16 {
		regs = 16
	}
	b := &builder{g: gbgraph.NewGraph(1400 + 115*regs)}
	b.g.ID = fmt.Sprintf("risc(%d)", regs)
	b.g.UtilTypes = "ZZZIIVZZZZZZZA"

//line gbgates.w:414
	var (
		mem                                 [16]*gbgraph.Vertex
		reg                                 [16]*gbgraph.Vertex
		mod, dest                           [4]*gbgraph.Vertex
		destMatch, oldDest, oldSrc, incDest [16]*gbgraph.Vertex
		source, log, nextLoc, nextNextLoc   [16]*gbgraph.Vertex
		tmp                                 [16]*gbgraph.Vertex
		shift, sum, diff, result            [18]*gbgraph.Vertex
		runBit, prog, sign, nonzero, carry  *gbgraph.Vertex
		overflow, extra, imm, rel, dir, ind *gbgraph.Vertex
		op, cond, change, jump, nextra      *gbgraph.Vertex
		nzs, nzd, up, down, skip, hop       *gbgraph.Vertex
		normal, special, t5                 *gbgraph.Vertex
		k, r                                int64
	)
	latchit := func(u, latch *gbgraph.Vertex) {
		latch.Z.V = b.make2(AND, u, runBit) // |u&runBit|가 래치의 새 값
	}

//line gbgates.w:397

//line gbgates.w:437
	b.prefix, b.count = "RUN", -1
	runBit = b.newVert('I')
	b.startPrefix("M")
	for k = 0; k < 16; k++ {
		mem[k] = b.newVert('I')
	}
	b.startPrefix("P")
	prog = b.firstOf(10, 'L')
	for _, nm := range []string{"S", "N", "K", "V", "X"} {
		b.prefix, b.count = nm, -1
		switch nm {
		case "S":
			sign = b.newVert('L')
		case "N":
			nonzero = b.newVert('L')
		case "K":
			carry = b.newVert('L')
		case "V":
			overflow = b.newVert('L')
		case "X":
			extra = b.newVert('L')
		}
	}
	for r = 0; r < regs; r++ {
		b.numericPrefix('R', r)
		reg[r] = b.firstOf(16, 'L')
	}

//line gbgates.w:398

//line gbgates.w:470
	b.startPrefix("D")
	imm = b.make3(AND, b.comp(extra), b.comp(mem[4]), b.comp(mem[5])) // $\.A=0$
	rel = b.make3(AND, b.comp(extra), mem[4], b.comp(mem[5]))         // $\.A=1$
	dir = b.make3(AND, b.comp(extra), b.comp(mem[4]), mem[5])         // $\.A=2$
	ind = b.make3(AND, b.comp(extra), mem[4], mem[5])                 // $\.A=3$
	op = b.make2(OR, b.make2(AND, extra, prog), b.make2(AND, b.comp(extra), mem[6]))
	cond = b.make2(OR, b.make2(AND, extra, b.at(prog, 1)), b.make2(AND, b.comp(extra), mem[7]))
	for k = 0; k < 4; k++ {
		mod[k] = b.make2(OR, b.make2(AND, extra, b.at(prog, 2+k)),
			b.make2(AND, b.comp(extra), mem[8+k]))
		dest[k] = b.make2(OR, b.make2(AND, extra, b.at(prog, 6+k)),
			b.make2(AND, b.comp(extra), mem[12+k]))
	}

//line gbgates.w:399

//line gbgates.w:485
	b.startPrefix("F")

//line gbgates.w:505
	for r = 0; r < regs; r++ {
		destMatch[r] = b.make4(AND, b.evenComp(r, dest[0]), b.evenComp(r>>1, dest[1]),
			b.evenComp(r>>2, dest[2]), b.evenComp(r>>3, dest[3]))
	}
	for k = 0; k < 16; k++ {
		for r = 0; r < regs; r++ {
			tmp[r] = b.make2(AND, destMatch[r], b.at(reg[r], k))
		}
		oldDest[k] = b.newVert(OR)
		for r = 0; r < regs; r++ {
			b.g.NewArc(oldDest[k], tmp[r], DELAY)
		}
	}

//line gbgates.w:520
	for k = 0; k < 16; k++ {
		for r = 0; r < regs; r++ {
			tmp[r] = b.make5(AND, b.at(reg[r], k), b.evenComp(r, mem[0]),
				b.evenComp(r>>1, mem[1]), b.evenComp(r>>2, mem[2]), b.evenComp(r>>3, mem[3]))
		}
		oldSrc[k] = b.newVert(OR)
		for r = 0; r < regs; r++ {
			b.g.NewArc(oldSrc[k], tmp[r], DELAY)
		}
	}

//line gbgates.w:730
	b.makeAdder(4, oldDest[:], mem[:], incDest[:], nil, 1)
	up = b.make2(AND, incDest[4], b.comp(mem[3]))   // 나머지 비트는 늘어야 한다
	down = b.make2(AND, b.comp(incDest[4]), mem[3]) // 나머지 비트는 줄어야 한다
	for k = 4; ; k++ {
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

//line gbgates.w:489
	for k = 0; k < 16; k++ {
		mk := 3
		if k < 4 {
			mk = int(k)
		}
		source[k] = b.make4(OR,
			b.make2(AND, imm, mem[mk]),
			b.make2(AND, rel, incDest[k]),
			b.make2(AND, dir, oldSrc[k]),
			b.make2(AND, extra, mem[k]))
	}

//line gbgates.w:400

//line gbgates.w:532
	b.startPrefix("L")
	for k = 0; k < 16; k++ {
		log[k] = b.make4(OR,
			b.make3(AND, mod[0], b.comp(oldDest[k]), b.comp(source[k])),
			b.make3(AND, mod[1], b.comp(oldDest[k]), source[k]),
			b.make3(AND, mod[2], oldDest[k], b.comp(source[k])),
			b.make3(AND, mod[3], oldDest[k], source[k]))
	}

//line gbgates.w:401

//line gbgates.w:542
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
	change = b.make3(OR, b.comp(cond), b.make2(AND, tmp[0], b.comp(op)), b.make2(AND, tmp[1], op))

//line gbgates.w:402

//line gbgates.w:751
	b.startPrefix("A")

//line gbgates.w:763
	for k = 0; k < 16; k++ {

//line gbgates.w:783
		var a1, a2, a3, a4 *gbgraph.Vertex
		if k == 0 {
			a1 = b.make4(AND, source[15], mod[0], b.comp(mod[1]), b.comp(mod[2]))
		} else {
			a1 = b.make3(AND, source[k-1], b.comp(mod[1]), b.comp(mod[2]))
		}
		if k < 4 {
			a2 = b.make4(AND, source[k+12], mod[0], mod[1], b.comp(mod[2]))
		} else {
			a2 = b.make3(AND, source[k-4], mod[1], b.comp(mod[2]))
		}
		if k == 15 {
			a3 = b.make4(AND, source[15], b.comp(mod[0]), b.comp(mod[1]), mod[2])
		} else {
			a3 = b.make3(AND, source[k+1], b.comp(mod[1]), mod[2])
		}
		if k > 11 {
			a4 = b.make4(AND, source[15], b.comp(mod[0]), mod[1], mod[2])
		} else {
			a4 = b.make3(AND, source[k+4], mod[1], mod[2])
		}
		shift[k] = b.make4(OR, a1, a2, a3, a4)

//line gbgates.w:765
	}
	shift[16] = b.make4(OR,
		b.make2(AND, b.comp(mod[2]), source[15]),
		b.make3(AND, b.comp(mod[2]), mod[1], b.make3(OR, source[14], source[13], source[12])),
		b.make3(AND, mod[2], b.comp(mod[1]), source[0]),
		b.make3(AND, mod[2], mod[1], source[3])) // ``자리 올림''
	shift[17] = b.make3(OR,
		b.make3(AND, b.comp(mod[2]), b.comp(mod[1]), b.makeXor(source[15], source[14])),
		b.make4(AND, b.comp(mod[2]), mod[1],
			b.make5(OR, source[15], source[14], source[13], source[12], source[11]),
			b.make5(OR, b.comp(source[15]), b.comp(source[14]), b.comp(source[13]),
				b.comp(source[12]), b.comp(source[11]))),
		b.make3(AND, mod[2], mod[1], b.make3(OR, source[0], source[1], source[2]))) // ``넘침''

//line gbgates.w:753
	b.makeAdder(16, oldDest[:], source[:], sum[:], b.make2(AND, carry, mod[0]), 1)  // 가산기
	b.makeAdder(16, oldDest[:], source[:], diff[:], b.make2(AND, carry, mod[0]), 0) // 감산기
	sum[17] = b.make2(OR,
		b.make3(AND, oldDest[15], source[15], b.comp(sum[15])),
		b.make3(AND, b.comp(oldDest[15]), b.comp(source[15]), sum[15])) // 넘침
	diff[17] = b.make2(OR,
		b.make3(AND, oldDest[15], b.comp(source[15]), b.comp(diff[15])),
		b.make3(AND, b.comp(oldDest[15]), source[15], diff[15])) // 넘침

//line gbgates.w:403

//line gbgates.w:559
	b.startPrefix("Z")

//line gbgates.w:568
	nextLoc[0] = b.comp(reg[0])
	nextNextLoc[0] = reg[0]
	nextLoc[1] = b.makeXor(b.at(reg[0], 1), reg[0])
	nextNextLoc[1] = b.comp(b.at(reg[0], 1))
	t5 = b.at(reg[0], 1)
	for k = 2; k < 16; k++ {
		nextLoc[k] = b.makeXor(b.at(reg[0], k), b.make2(AND, reg[0], t5))
		nextNextLoc[k] = b.makeXor(b.at(reg[0], k), t5)
		t5 = b.make2(AND, t5, b.at(reg[0], k))
	}

//line gbgates.w:580
	jump = b.make5(AND, op, mod[0], mod[1], mod[2], mod[3]) // |cond=0|이라 가정
	for k = 0; k < 16; k++ {
		result[k] = b.make5(OR,
			b.make2(AND, b.comp(op), log[k]),
			b.make2(AND, jump, nextLoc[k]),
			b.make3(AND, op, b.comp(mod[3]), shift[k]),
			b.make5(AND, op, mod[3], b.comp(mod[2]), b.comp(mod[1]), sum[k]),
			b.make5(AND, op, mod[3], b.comp(mod[2]), mod[1], diff[k]))
		result[k] = b.make2(OR,
			b.make3(AND, cond, change, source[k]),
			b.make2(AND, b.comp(cond), result[k]))
	}
	for k = 16; k < 18; k++ { // 결과의 자리 올림·넘침 비트
		result[k] = b.make3(OR,
			b.make3(AND, op, b.comp(mod[3]), shift[k]),
			b.make5(AND, op, mod[3], b.comp(mod[2]), b.comp(mod[1]), sum[k]),
			b.make5(AND, op, mod[3], b.comp(mod[2]), mod[1], diff[k]))
	}

//line gbgates.w:613
	t5 = b.make2(AND, change, b.comp(ind)) // 목적 레지스터가 바뀌어야 하나?
	for r = 1; r < regs; r++ {
		t4 := b.make2(AND, t5, destMatch[r]) // 레지스터 |r|이 바뀌어야 하나?
		for k = 0; k < 16; k++ {
			t3 := b.make2(OR, b.make2(AND, t4, result[k]), b.make2(AND, b.comp(t4), b.at(reg[r], k)))
			latchit(t3, b.at(reg[r], k))
		}
	}

//line gbgates.w:623
	t5 = b.make4(OR,
		b.make2(AND, sign, cond),
		b.make2(AND, sign, jump),
		b.make2(AND, sign, ind),
		b.make4(AND, result[15], b.comp(cond), b.comp(jump), b.comp(ind)))
	latchit(t5, sign)
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
	latchit(t5, nonzero)
	t5 = b.make5(OR,
		b.make2(AND, overflow, cond),
		b.make2(AND, overflow, jump),
		b.make2(AND, overflow, b.comp(op)),
		b.make2(AND, overflow, ind),
		b.make5(AND, result[17], b.comp(cond), b.comp(jump), b.comp(ind), op))
	latchit(t5, overflow)
	t5 = b.make5(OR,
		b.make2(AND, carry, cond),
		b.make2(AND, carry, jump),
		b.make2(AND, carry, b.comp(op)),
		b.make2(AND, carry, ind),
		b.make5(AND, result[16], b.comp(cond), b.comp(jump), b.comp(ind), op))
	latchit(t5, carry)

//line gbgates.w:604
	for k = 0; k < 10; k++ {
		latchit(mem[k+6], b.at(prog, k))
	}
	nextra = b.make2(OR, b.make2(AND, ind, b.comp(cond)), b.make2(AND, ind, change))
	latchit(nextra, extra)
	nzs = b.make4(OR, mem[0], mem[1], mem[2], mem[3])
	nzd = b.make4(OR, dest[0], dest[1], dest[2], dest[3])

//line gbgates.w:661
	skip = b.make2(AND, cond, b.comp(change)) // 거짓 조건?
	hop = b.make2(AND, b.comp(cond), jump)    // \.{JUMP} 명령?
	normal = b.make4(OR,
		b.make2(AND, skip, b.comp(ind)),
		b.make2(AND, skip, nzs),
		b.make3(AND, b.comp(skip), ind, b.comp(nzs)),
		b.make3(AND, b.comp(skip), b.comp(hop), nzd))
	special = b.make3(AND, b.comp(skip), ind, nzs)
	for k = 0; k < 16; k++ {
		t5 = b.make4(OR,
			b.make2(AND, normal, nextLoc[k]),
			b.make4(AND, skip, ind, b.comp(nzs), nextNextLoc[k]),
			b.make3(AND, hop, b.comp(ind), source[k]),
			b.make5(AND, b.comp(skip), b.comp(hop), b.comp(ind), b.comp(nzd), result[k]))
		t4 := b.make2(OR, b.make2(AND, special, b.at(reg[0], k)), b.make2(AND, b.comp(special), t5))
		latchit(t4, b.at(reg[0], k))
		t4 = b.make2(OR, b.make2(AND, special, oldSrc[k]), b.make2(AND, b.comp(special), t5))

//line gbgates.w:684
		a := b.g.VirginArc()
		a.Tip = b.make2(AND, t4, runBit)
		a.Next = b.g.ZZ.A
		b.g.ZZ.A = a

//line gbgates.w:679
	}

//line gbgates.w:404
	if b.nextV != int(b.g.N) {
		return nil, gbgraph.Impossible // 게이트 수를 잘못 셌다
	}
	return b.g, nil
}

//line gbgates.w:702
func (b *builder) makeAdder(n int, x, y, z []*gbgraph.Vertex, carry *gbgraph.Vertex, add int64) {
	k := 0
	if carry == nil {
		z[0] = b.makeXor(x[0], y[0])
		carry = b.make2(AND, b.evenComp(add, x[0]), y[0])
		k = 1
	}
	for ; k < n; k++ {
		b.comp(x[k])
		b.comp(y[k])
		b.comp(carry) // 여 게이트를 만들어 둔다
		z[k] = b.make4(OR,
			b.make3(AND, x[k], b.comp(y[k]), b.comp(carry)),
			b.make3(AND, b.comp(x[k]), y[k], b.comp(carry)),
			b.make3(AND, b.comp(x[k]), b.comp(y[k]), carry),
			b.make3(AND, x[k], y[k], carry))
		carry = b.make3(OR,
			b.make2(AND, b.evenComp(add, x[k]), y[k]),
			b.make2(AND, b.evenComp(add, x[k]), carry),
			b.make2(AND, y[k], carry))
	}
	z[n] = carry
}

//line gbgates.w:823
func RunRisc(g *gbgraph.Graph, rom []int64, traceRegs int64, trace io.Writer) ([18]int64, int64) {
	var riscState [18]int64
	if traceRegs > 0 {

//line gbgates.w:912
		for r := int64(0); r < traceRegs; r++ {
			fmt.Fprintf(trace, " r%-2d ", r)
		}
		fmt.Fprint(trace, " P XSNKV MEM\n")

//line gbgates.w:827
	}

//line gbgates.w:853
	if _, code := GateEval(g, "0"); code < 0 {
		return riscState, code
	}
	g.Vertices[0].X.I = 1

//line gbgates.w:829
	var l int64
	for {

//line gbgates.w:862
		l = 0
		for a := g.ZZ.A; a != nil; a = a.Next {
			l = 2*l + a.Tip.X.I
		}

//line gbgates.w:832
		if traceRegs > 0 {

//line gbgates.w:918
			readAlt := func(base int64) int64 {
				v := g.Vertices[base]
				var m int64
				if v.Y.I == 'L' {
					for k := int64(0); k < 16; k++ {
						m = 2*m + g.Vertices[base-k].Z.V.X.I
					}
				}
				return m
			}
			for r := int64(0); r < traceRegs; r++ {
				fmt.Fprintf(trace, "%04x ", readAlt(16*r+47))
			}
			var pm int64
			for k := int64(0); k < 10; k++ {
				pm = 2*pm + g.Vertices[26-k].Z.V.X.I
			}
			xb := g.Vertices[31].Z.V.X.I
			sb := g.Vertices[27].Z.V.X.I
			nb := g.Vertices[28].Z.V.X.I
			cb := g.Vertices[29].Z.V.X.I
			ob := g.Vertices[30].Z.V.X.I
			fmt.Fprintf(trace, "%03x%s ", pm<<2,
				statusStr(xb, 'X')+statusStr(sb, 'S')+statusStr(nb, 'N')+statusStr(cb, 'K')+statusStr(ob, 'V'))
			if l >= int64(len(rom)) {
				fmt.Fprint(trace, "????\n")
			} else {
				fmt.Fprintf(trace, "%04x\n", rom[l])
			}

//line gbgates.w:834
		}
		if l >= int64(len(rom)) {
			break // 메모리 검사에 걸리면 멈춘다
		}

//line gbgates.w:873
		m := rom[l]
		for vi := 1; vi <= 16; vi++ {
			g.Vertices[vi].X.I = m & 1
			m >>= 1
		}
		GateEval(g, "")

//line gbgates.w:839
	}
	if traceRegs > 0 {
		fmt.Fprintf(trace, "Execution terminated with memory address %04x.\n", l)
	}

//line gbgates.w:884
	readReg := func(base int64) int64 {
		v := g.Vertices[base]
		var m int64
		if v.Y.I == 'L' {
			for k := int64(0); k < 16; k++ {
				m = 2*m + g.Vertices[base-k].Z.V.X.I
			}
		}
		return m
	}
	for r := int64(0); r < 16; r++ {
		riscState[r] = readReg(16*r + 47)
	}
	var m int64
	for k := int64(0); k < 10; k++ {
		m = 2*m + g.Vertices[26-k].Z.V.X.I // |prog|
	}
	m = 4*m + g.Vertices[31].Z.V.X.I // |extra|
	m = 2*m + g.Vertices[27].Z.V.X.I // |sign|
	m = 2*m + g.Vertices[28].Z.V.X.I // |nonzero|
	m = 2*m + g.Vertices[29].Z.V.X.I // |carry|
	m = 2*m + g.Vertices[30].Z.V.X.I // |overflow|
	riscState[16] = m
	riscState[17] = l

//line gbgates.w:844
	return riscState, 0
}

//line gbgates.w:949
func statusStr(bit int64, c byte) string {
	if bit != 0 {
		return string(c)
	}
	return "."
}

//line gbgates.w:971
func prGate(out io.Writer, v *gbgraph.Vertex) {
	fmt.Fprintf(out, "%s = ", v.Name)
	switch v.Y.I {
	case 'I':
		fmt.Fprint(out, "input")
	case 'L':
		fmt.Fprint(out, "latch")
		if v.Z.V != nil {
			fmt.Fprintf(out, "ed %s", v.Z.V.Name)
		}
	case NOT:
		fmt.Fprint(out, "~ ")
	case 'C':
		fmt.Fprintf(out, "constant %d", v.Z.I)
	case '=':
		fmt.Fprintf(out, "copy of %s", v.Z.V.Name)
	}
	for a := v.Arcs; a != nil; a = a.Next {
		if a != v.Arcs {
			fmt.Fprintf(out, " %c ", byte(v.Y.I))
		}
		fmt.Fprint(out, a.Tip.Name)
	}
	fmt.Fprintln(out)
}

func PrintGates(out io.Writer, g *gbgraph.Graph) {
	for i := int64(0); i < g.N; i++ {
		prGate(out, &g.Vertices[i])
	}
	for a := g.ZZ.A; a != nil; a = a.Next {
		if isBoolean(a.Tip) {
			fmt.Fprintf(out, "Output %d\n", theBoolean(a.Tip))
		} else {
			fmt.Fprintf(out, "Output %s\n", a.Tip.Name)
		}
	}
}

// |reverseArcs|는 호 목록을 제자리에서 뒤집어 새 머리를 준다.
//
//line gbgates.w:1033
//line gbgates.w:1034
func reverseArcs(head *gbgraph.Arc) *gbgraph.Arc {
	var prev *gbgraph.Arc
	for a := head; a != nil; {
		next := a.Next
		a.Next = prev
		prev = a
		a = next
	}
	return prev
}

//line gbgates.w:1051
func (b *builder) reduce(g *gbgraph.Graph) (*gbgraph.Graph, error) {
	if g == nil {
		return nil, gbgraph.MissingOperand
	}
	b.g = g
	sentinel := &g.Vertices[g.N]
	var n int64 // 표시된 게이트 수
	var newVerts []*gbgraph.Vertex
	newComp := func(u *gbgraph.Vertex, availArc *gbgraph.Arc) *gbgraph.Vertex {

//line gbgates.w:1347
		nv := new(gbgraph.Vertex)
		nv.Y.I = NOT
		nv.Name = u.Name + "~"
		a := b.g.VirginArc()
		a.Tip = u
		nv.Arcs = a
		nv.W.V = u
		nv.X.V = u.X.V // |foo|
		u.X.V = nv
		newVerts = append(newVerts, nv)
		return nv

//line gbgates.w:1061
	}

//line gbgates.w:1074
	for {
		var latchPtr *gbgraph.Vertex
		for i := int64(0); i < g.N; i++ {
			v := &g.Vertices[i]

//line gbgates.w:1088
			setConst := func(bit int64) { v.Z.I = bit; v.Y.I = 'C'; v.Arcs = nil }
			setEq := func(u *gbgraph.Vertex) { v.Z.V = u; v.Y.I = '='; v.Arcs = nil }
			resetBar := true // 정규 인버터만 |false|로: 새 |bar| 링크를 지키려 리셋을 건너뛴다
			switch v.Y.I {
			case 'L':
				v.V.V = latchPtr
				latchPtr = v
			case 'I', 'C':
			// 그대로 둔다
			//
//line gbgates.w:1096
//line gbgates.w:1097
			case '=':
				u := v.Z.V
				if u.Y.I == '=' {
					v.Z.V = u.Z.V
				} else if u.Y.I == 'C' {
					setConst(u.Z.I)
				}
			case NOT:

//line gbgates.w:1130
				u := v.Arcs.Tip
				if u.Y.I == '=' {
					u = u.Z.V
					v.Arcs.Tip = u
				}
				if u.Y.I == 'C' {
					setConst(1 - u.Z.I)
				} else if u.W.V != nil { // 이 여는 이미 셈했다
					setEq(u.W.V)
				} else {
					u.W.V, v.W.V = v, u
					resetBar = false // \CEE/의 |goto done|: |v.bar|을 지키려 리셋을 건너뛴다
				}

//line gbgates.w:1106
			case AND:

//line gbgates.w:1148
				{
					var aa *gbgraph.Arc
					zero := false

//line gbgates.w:1163
					for a := v.Arcs; a != nil; a = a.Next {
						u := a.Tip
						if u.Y.I == '=' {
							u = u.Z.V
							a.Tip = u
						}
						bypass := false
						if u.Y.I == 'C' {
							if u.Z.I == 0 {
								zero = true
								break
							}
							bypass = true
						} else {

//line gbgates.w:1189
							for bb := v.Arcs; bb != a; bb = bb.Next {
								if bb.Tip == u {
									bypass = true
									break
								}
								if bb.Tip == u.W.V {
									zero = true
									break
								}
							}

//line gbgates.w:1178
							if zero {
								break
							}
						}

//line gbgates.w:1204
						if bypass {
							if aa != nil {
								aa.Next = a.Next
							} else {
								v.Arcs = a.Next
							}
						} else {
							aa = a
						}

//line gbgates.w:1183
					}

//line gbgates.w:1152
					if zero {
						setConst(0)
					} else if v.Arcs == nil {
						setConst(1)
					}
				}

//line gbgates.w:1108

//line gbgates.w:1125
				if v.Arcs != nil && v.Arcs.Next == nil {
					setEq(v.Arcs.Tip)
				}

//line gbgates.w:1109
			case OR:

//line gbgates.w:1217
				{
					var aa *gbgraph.Arc
					one := false

//line gbgates.w:1232
					for a := v.Arcs; a != nil; a = a.Next {
						u := a.Tip
						if u.Y.I == '=' {
							u = u.Z.V
							a.Tip = u
						}
						bypass := false
						if u.Y.I == 'C' {
							if u.Z.I != 0 {
								one = true
								break
							}
							bypass = true
						} else {

//line gbgates.w:1257
							for bb := v.Arcs; bb != a; bb = bb.Next {
								if bb.Tip == u {
									bypass = true
									break
								}
								if bb.Tip == u.W.V {
									one = true
									break
								}
							}

//line gbgates.w:1247
							if one {
								break
							}
						}

//line gbgates.w:1204
						if bypass {
							if aa != nil {
								aa.Next = a.Next
							} else {
								v.Arcs = a.Next
							}
						} else {
							aa = a
						}

//line gbgates.w:1252
					}

//line gbgates.w:1221
					if one {
						setConst(1)
					} else if v.Arcs == nil {
						setConst(0)
					}
				}

//line gbgates.w:1111

//line gbgates.w:1125
				if v.Arcs != nil && v.Arcs.Next == nil {
					setEq(v.Arcs.Tip)
				}

//line gbgates.w:1112
			case XOR:

//line gbgates.w:1273
				{
					var cmp int64
					var aa *gbgraph.Arc

//line gbgates.w:1287
					for a := v.Arcs; a != nil; a = a.Next {
						u := a.Tip
						if u.Y.I == '=' {
							u = u.Z.V
							a.Tip = u
						}
						bypass := false
						if u.Y.I == 'C' {
							if u.Z.I != 0 {
								cmp = 1 - cmp
							}
							bypass = true
						} else {

//line gbgates.w:1309
							var bb *gbgraph.Arc
							for c := v.Arcs; c != a; c = c.Next {
								if c.Tip == u || c.Tip == u.W.V {
									if c.Tip == u.W.V {
										cmp = 1 - cmp
									}
									if bb != nil {
										bb.Next = c.Next
									} else {
										v.Arcs = c.Next
									}
									bypass = true
									break
								}
								bb = c
							}

//line gbgates.w:1301
						}

//line gbgates.w:1204
						if bypass {
							if aa != nil {
								aa.Next = a.Next
							} else {
								v.Arcs = a.Next
							}
						} else {
							aa = a
						}

//line gbgates.w:1303
					}

//line gbgates.w:1277
					if v.Arcs == nil {
						setConst(cmp)
					} else if cmp != 0 {

//line gbgates.w:1330
						{
							var a *gbgraph.Arc
							var u *gbgraph.Vertex
							for a = v.Arcs; ; a = a.Next {
								u = a.Tip
								if u.W.V != nil {
									break // 여가 이미 알려져 있다
								}
								if a.Next == nil { // 마지막 기회다
									u.W.V = newComp(u, nil)
									break
								}
							}
							a.Tip = u.W.V
						}

//line gbgates.w:1281
					}
				}

//line gbgates.w:1114

//line gbgates.w:1125
				if v.Arcs != nil && v.Arcs.Next == nil {
					setEq(v.Arcs.Tip)
				}

//line gbgates.w:1115
			}
			if resetBar {
				v.W.V = nil // 이 필드는 나중에 여를 가리킬 수 있다
			}
			v.X.V = b.at(v, 1) // |foo|: 모든 정점을 잇는다

//line gbgates.w:1079
		}

//line gbgates.w:1363
		noConstantsYet := true
		for v := latchPtr; v != nil; v = v.V.V {
			u := v.Z.V // 값이 래치될 게이트
			if u.Y.I == '=' {
				v.Z.V = u.Z.V
			} else if u.Y.I == 'C' {
				v.Y.I = 'C'
				v.Z.I = u.Z.I
				noConstantsYet = false
			}
		}
		if noConstantsYet {
			break
		}

//line gbgates.w:1081
	}

//line gbgates.w:1063

//line gbgates.w:1382
	for v := &g.Vertices[0]; v != sentinel; v = v.X.V {
		v.W.V = nil
	}
	for a := g.ZZ.A; a != nil; a = a.Next {
		v := a.Tip
		if isBoolean(v) {
			continue
		}
		if v.Y.I == '=' {
			v = v.Z.V
			a.Tip = v
		}
		if v.Y.I == 'C' { // 이 출력은 상수라 불리언으로 만든다
			a.Tip = boolGate(v.Z.I)
			continue
		}

//line gbgates.w:1406
		if v.W.V == nil {
			v.W.V = sentinel // |v|가 표시할 노드 스택의 꼭대기다

//line gbgates.w:1415
			for {
				n++
				bb := v.Arcs
				if v.Y.I == 'L' {
					u := v.Z.V
					if b.g.Index(u) < b.g.Index(v) {
						n++ // 래치될 입력값에 특별한 게이트가 생긴다
					}
					if u.W.V == nil {
						u.W.V = v.W.V
						v = u
					} else {
						v = v.W.V
					}
				} else {
					v = v.W.V
				}
				for ; bb != nil; bb = bb.Next {
					u := bb.Tip
					if u.W.V == nil {
						u.W.V = v
						v = u
					}
				}
				if v == sentinel {
					break
				}
			}

//line gbgates.w:1409
		}

//line gbgates.w:1399
	}

//line gbgates.w:1064

//line gbgates.w:1448
	newGraph := gbgraph.NewGraph(n)
	newGraph.ID = g.ID
	newGraph.UtilTypes = "ZZZIIVZZZZZZZA"
	b.g = newGraph
	b.nextV = 0
	var latchPtr *gbgraph.Vertex
	for v := &g.Vertices[0]; v != sentinel; v = v.X.V {
		if v.W.V != nil { // |v|가 표시되었다
			u := &newGraph.Vertices[b.nextV]
			b.nextV++
			v.W.V = u // 어디에 옮겼는지 적어 둔다

//line gbgates.w:1476
			u.Name = v.Name
			u.Y.I = v.Y.I
			if v.Y.I == 'L' {
				u.Z.V = latchPtr
				latchPtr = v
			}
			v.Arcs = reverseArcs(v.Arcs)
			for a := v.Arcs; a != nil; a = a.Next {
				b.g.NewArc(u, a.Tip.W.V, a.Len)
			}

//line gbgates.w:1460
		}
	}

//line gbgates.w:1491
	for latchPtr != nil {
		u := latchPtr.W.V // 래치의 사본
		v := u.Z.V
		u.Z.V = latchPtr.Z.V.W.V
		latchPtr = v
		if b.g.Index(u.Z.V) < b.g.Index(u) {

//line gbgates.w:1502
			w := u.Z.V // 래치를 위해 베낄 입력 게이트
			nv := &b.g.Vertices[b.nextV]
			b.nextV++
			nv.Name = w.Name + ">" + u.Name
			nv.Y.I = OR
			b.g.NewArc(nv, w, DELAY)
			b.g.NewArc(nv, w, DELAY)
			u.Z.V = nv

//line gbgates.w:1498
		}
	}

//line gbgates.w:1463
	g.ZZ.A = reverseArcs(g.ZZ.A)
	for a := g.ZZ.A; a != nil; a = a.Next {
		nb := newGraph.VirginArc()
		if isBoolean(a.Tip) {
			nb.Tip = a.Tip
		} else {
			nb.Tip = a.Tip.W.V
		}
		nb.Next = newGraph.ZZ.A
		newGraph.ZZ.A = nb
	}

//line gbgates.w:1065
	return newGraph, nil
}

//line gbgates.w:1565
func Prod(m, n int64) (*gbgraph.Graph, error) {
	if m < 2 {
		m = 2
	}
	if n < 2 {
		n = 2
	}
	mPlusN := m + n

//line gbgates.w:1586
	f := int64(4)
	j := int64(3)
	k := int64(5) // $j=F_f$, $k=F_{f+1}$
	for k < mPlusN {
		k += j
		j = k - j
		f++
	}

//line gbgates.w:1574
	b := &builder{g: gbgraph.NewGraph((6*m - 7 + 3*f) * mPlusN)}
	b.g.ID = fmt.Sprintf("prod(%d,%d)", m, n)
	b.g.UtilTypes = "ZZZIIVZZZZZZZA"
	longTables := make([]int64, 2*mPlusN+f)
	vertTables := make([]*gbgraph.Vertex, f*mPlusN)

//line gbgates.w:1600
	b.startPrefix("X")
	x := b.firstOf(int(m), 'I')
	b.startPrefix("Y")
	y := b.firstOf(int(n), 'I')
	aPos := func(j int64) int64 {
		if j < m {
			return j + 1
		}
		return m + 5*((j-m)>>1) + 3 + (((j - m) & 1) << 1)
	}

//line gbgates.w:1617
	for j := int64(0); j < m; j++ {
		b.numericPrefix('A', j)
		for kk := int64(0); kk < j; kk++ {
			b.newVert('C').Z.I = 0 // 상수 0 게이트
		}
		for kk := int64(0); kk < n; kk++ {
			b.make2(AND, b.at(x, j), b.at(y, kk))
		}
		for kk := j + n; kk < mPlusN; kk++ {
			b.newVert('C').Z.I = 0
		}
	}

//line gbgates.w:1633
	for j := int64(0); j < m-2; j++ {

//line gbgates.w:1642
		alpha := b.vAt(aPos(3*j) * mPlusN)
		beta := b.vAt(aPos(3*j+1) * mPlusN)
		b.numericPrefix('P', j)
		for kk := int64(0); kk < mPlusN; kk++ {
			b.make2(XOR, b.at(alpha, kk), b.at(beta, kk))
		}
		b.numericPrefix('Q', j)
		for kk := int64(0); kk < mPlusN; kk++ {
			b.make2(AND, b.at(alpha, kk), b.at(beta, kk))
		}
		alpha = b.vAt(int64(b.nextV) - 2*mPlusN)
		beta = b.vAt(aPos(3*j+2) * mPlusN)
		b.numericPrefix('A', m+2*j)
		for kk := int64(0); kk < mPlusN; kk++ {
			b.make2(XOR, b.at(alpha, kk), b.at(beta, kk))
		}

//line gbgates.w:1635

//line gbgates.w:1663
		b.numericPrefix('R', j)
		for kk := int64(0); kk < mPlusN; kk++ {
			b.make2(AND, b.at(alpha, kk), b.at(beta, kk))
		}
		alpha = b.vAt(int64(b.nextV) - 3*mPlusN)
		beta = b.vAt(int64(b.nextV) - mPlusN)
		b.numericPrefix('A', m+2*j+1)
		b.newVert('C').Z.I = 0 // $Q\lor R$을 2배 하는 또 다른 0
		for kk := int64(0); kk < mPlusN-1; kk++ {
			b.make2(OR, b.at(alpha, kk), b.at(beta, kk))
		}

//line gbgates.w:1636
	}

//line gbgates.w:1679
	alpha := b.vAt(aPos(3*m-6) * mPlusN)
	beta := b.vAt(aPos(3*m-5) * mPlusN)
	b.startPrefix("U")
	for kk := int64(0); kk < mPlusN; kk++ {
		b.make2(XOR, b.at(alpha, kk), b.at(beta, kk))
	}
	b.startPrefix("V")
	for kk := int64(0); kk < mPlusN; kk++ {
		b.make2(AND, b.at(alpha, kk), b.at(beta, kk))
	}

//line gbgates.w:1731
	w := vertTables
	c := vertTables[mPlusN:]
	flog := longTables
	down := longTables[mPlusN+1:]
	anc := longTables[2*mPlusN+1-mPlusN:] // |down| 뒤 |mPlusN|만큼; 아래에서 다시 잡는다
	_ = anc

//line gbgates.w:1744
	anc = longTables[2*mPlusN+1:] // |flog| 표(|mPlusN+1|개)와 |down| 표(|mPlusN|개) 다음
	flog[1], flog[2] = 0, 2
	down[1], down[2] = 0, 1
	{
		i, jj, kk := int64(3), int64(2), int64(3)
		for l := int64(3); l <= mPlusN; l++ {
			if l > kk {
				kk += jj
				jj = kk - jj
				i++ // $F_i=jj<l\le kk=F_{i+1}$
			}
			flog[l] = i
			down[l] = l - kk + jj
		}
	}

//line gbgates.w:1765
	vv := b.vAt(int64(b.nextV) - mPlusN)
	uu := b.vAt(int64(b.nextV) - 2*mPlusN)
	b.startPrefix("W")
	w[0] = b.newVert('C')
	w[0].Z.I = 0 // $w_0=0$
	w[1] = b.newVert('=')
	w[1].Z.V = vv // $w_1=v_0$
	for k := int64(2); k < mPlusN; k++ {

//line gbgates.w:1798
		var l int64
		{
			jj := k
			for l = 0; ; l++ {
				anc[l] = jj
				if jj == 2 {
					break
				}
				jj = down[jj]
			}
		}

//line gbgates.w:1774
		i := int64(1)
		cc := b.at(vv, k-1)
		dd := b.at(uu, k-1)
		var v *gbgraph.Vertex
		for {
			jN := anc[l] // 이제 $i=\down[jN]$

//line gbgates.w:1815
			specGate := func(a byte, kk, jj, t int64) *gbgraph.Vertex {
				g := &b.g.Vertices[b.nextV]
				b.nextV++
				g.Name = fmt.Sprintf("%c%d:%d", a, kk, jj)
				g.Y.I = t
				return g
			}
			v = specGate('B', k, jN, AND)
			b.g.NewArc(v, dd, DELAY) // 첫 인수는 $d_k^{\,i}$
			f = flog[jN-i]           // 둘째 인수 $c_{k-i}^{\,jN-i}$를 셈할 채비
			if f > 0 {
				b.g.NewArc(v, c[k-i+(f-2)*mPlusN], DELAY)
			} else {
				b.g.NewArc(v, b.at(vv, k-i-1), DELAY)
			}

//line gbgates.w:1781

//line gbgates.w:1834
			if l != 0 {
				v = specGate('C', k, jN, OR)
			} else {
				v = b.newVert(OR)
			}
			b.g.NewArc(v, cc, DELAY)                      // 첫 인수는 $c_k^{\,i}$
			b.g.NewArc(v, b.vAt(int64(b.nextV)-2), DELAY) // 둘째 인수는 $b_k^{\,jN}$

//line gbgates.w:1782
			if flog[jN] < flog[jN+1] { // $jN$이 피보나치 수다
				c[k+(flog[jN]-2)*mPlusN] = v
			}
			if l == 0 {
				break
			}
			cc = v

//line gbgates.w:1846
			v = specGate('D', k, jN, AND)
			b.g.NewArc(v, dd, DELAY) // 첫 인수는 $d_k^{\,i}$
			if f > 0 {
				b.g.NewArc(v, b.at(c[k-i+(f-2)*mPlusN], 1), DELAY)
			} else {
				b.g.NewArc(v, b.at(uu, k-i-1), DELAY)
			}

//line gbgates.w:1790
			dd = v
			i = jN
			l--
		}
		w[k] = v
	}

//line gbgates.w:1857
	b.startPrefix("Z")
	for k := int64(0); k < mPlusN; k++ {
		a := b.g.VirginArc()
		a.Tip = b.make2(XOR, b.at(uu, k), w[k])
		a.Next = b.g.ZZ.A
		b.g.ZZ.A = a
	}

//line gbgates.w:1614
	b.g.N = int64(b.nextV) // 실제로 쓴 게이트 수로 줄인다

//line gbgates.w:1580
	return b.reduce(b.g)
}

//line gbgates.w:1897
func PartialGates(g *gbgraph.Graph, r, prob, seed int64, buf *strings.Builder) (*gbgraph.Graph, error) {
	if g == nil {
		return nil, gbgraph.MissingOperand
	}
	rng := gbflip.New(seed)

//line gbgates.w:1916
loop:
	for vi := r; vi < g.N; vi++ {
		v := &g.Vertices[vi]
		switch v.Y.I {
		case 'C', '=':
			continue // 뒤에 입력이 더 올 수 있다
		case 'I':
			if (rng.Next() >> 15) >= prob {
				v.Y.I = 'C'
				v.Z.I = rng.Next() >> 30
				if buf != nil {
					buf.WriteByte(byte(v.Z.I) + '0')
				}
			} else if buf != nil {
				buf.WriteByte('*')
			}
		default:
			break loop // 입력 게이트가 더는 올 수 없다
		}
	}

//line gbgates.w:1903
	b := &builder{}
	rg, err := b.reduce(g)
	if err != nil {
		return nil, err
	}

//line gbgates.w:1940
	if rg != nil {
		id := rg.ID
		if len(id) > 54 {
			id = id[:51] + "..."
		}
		rg.ID = fmt.Sprintf("partial_gates(%s,%d,%d,%d)", id, r, prob, seed)
	}

//line gbgates.w:1909
	return rg, nil
}
