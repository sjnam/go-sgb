//line gbraman.w:57
package gbraman

import (
	"errors"
	"fmt"
	"strconv"

	"github.com/sjnam/go-sgb/gbgraph"
)

//line gbraman.w:77
var (
	ErrQRange    = errors.New("q is out of range")
	ErrPRange    = errors.New("p is out of range")
	ErrQNotPrime = errors.New("q is not prime")
	ErrQIncompat = errors.New("q is not compatible with p=2")
	ErrPMultQ    = errors.New("p is a multiple of q")
	ErrWrongType = errors.New("wrong type for p modulo q")
	ErrQTooBig   = errors.New("q is too big")
	ErrPTooBig   = errors.New("p is too big")
	ErrPNotPrime = errors.New("p is not prime")

//line gbraman.w:87
)

//line gbraman.w:94
type builder struct {
	q                 int64
	qSqr, qSqrt, qInv []int64
	gen               []quaternion
	genCount, maxGen  int64
}

type quaternion struct {
	a0, a1, a2, a3 int64 // 사원수 계수
	bar            int64 // 켤레(역원) 사원수의 인덱스
}

//line gbraman.w:110
func Raman(p, q, typ, reduce int64) (*gbgraph.Graph, error) {
	bd := &builder{q: q}
	if err := bd.prepareTables(p); err != nil {
		return nil, err
	}
	typ, n, nFactor, err := bd.chooseType(p, typ)
	if err != nil {
		return nil, err
	}
	g := gbgraph.NewGraph(n)
	g.ID = fmt.Sprintf("raman(%d,%d,%d,%d)", p, q, typ, reduce)
	g.UtilTypes = "ZZZIIZIZZZZZZZ"
	bd.assignLabels(g, typ, nFactor)
	if err := bd.computeGenerators(p); err != nil {
		return nil, err
	}
	bd.appendEdges(g, p, typ, nFactor, reduce)
	return g, nil
}

//line gbraman.w:140
func (bd *builder) prepareTables(p int64) error {
	q := bd.q
	if q < 3 || q > 46337 {
		return ErrQRange // |q|가 너무 작거나 크다
	}
	if p < 2 {
		return ErrPRange // |p|가 너무 작다
	}
	bd.qSqr = make([]int64, q)
	bd.qSqrt = make([]int64, q)
	bd.qInv = make([]int64, q)

//line gbraman.w:158
	for a := int64(1); a < q; a++ {
		bd.qSqrt[a] = -1
	}
	sq := int64(1)
	for a := int64(1); a < q; a++ {
		bd.qSqr[a] = sq
		bd.qSqrt[sq] = q - a // 더 작은 제곱근이 살아남는다
		bd.qInv[sq] = -1     // |sq|가 원시근이 될 수 없음을 표시
		sq = (sq + a + a + 1) % q
	}

//line gbraman.w:152

//line gbraman.w:173
	var a, aa int64
FindRoot:
	for a = 2; ; a++ {
		if bd.qInv[a] == 0 {
			b, k := a, int64(1)
			for b != 1 && k < q {
				bd.qInv[b] = -1
				aa = b
				b = (a * b) % q
				k++
			}
			if k >= q {
				return ErrQNotPrime
			}
			if k == q-1 {
				break FindRoot // |a|가 찾던 원시근이다
			}
		}
	}

//line gbraman.w:153

//line gbraman.w:197
	b, bb := a, aa
	for b != bb {
		bd.qInv[b] = bb
		bd.qInv[bb] = b
		b = (a * b) % q
		bb = (aa * bb) % q
	}
	bd.qInv[1] = 1
	bd.qInv[b] = b // 이 자리에서 |b|는 |q-1|이라야 한다
	bd.qInv[0] = q

//line gbraman.w:154
	return nil
}

//line gbraman.w:213
func (bd *builder) chooseType(p, typ int64) (t, n, nFactor int64, err error) {
	q := bd.q
	if p == 2 {
		if bd.qSqrt[13%q] < 0 || bd.qSqrt[q-2] < 0 {
			return 0, 0, 0, ErrQIncompat
		}
	}
	pModQ := p % q
	if pModQ == 0 {
		return 0, 0, 0, ErrPMultQ
	}
	if typ == 0 {
		if bd.qSqrt[pModQ] > 0 {
			typ = 3
		} else {
			typ = 4
		}
	}
	if typ == 3 {
		nFactor = (q - 1) / 2
	} else {
		nFactor = q - 1
	}

//line gbraman.w:244
	switch typ {
	case 1:
		n = q + 1
	case 2:
		n = q * (q + 1) / 2
	default:
		if (bd.qSqrt[pModQ] > 0 && typ != 3) || (bd.qSqrt[pModQ] < 0 && typ != 4) {
			return 0, 0, 0, ErrWrongType
		}
		if q > 1289 {
			return 0, 0, 0, ErrQTooBig // type 3, 4에는 너무 크다
		}
		n = nFactor * q * (q + 1)
	}

//line gbraman.w:237
	if p >= 0x3fffffff/n { // $(p+1)n\ge2^{30}$
		return 0, 0, 0, ErrPTooBig
	}
	return typ, n, nFactor, nil
}

//line gbraman.w:293
func (bd *builder) assignLabels(g *gbgraph.Graph, typ, nFactor int64) {
	q := bd.q
	switch typ {
	case 1:

//line gbraman.w:309
		g.SetUtilType(4, 'Z')
		for a := int64(0); a < q; a++ {
			g.Vertices[a].Name = strconv.FormatInt(a, 10)
			g.Vertices[a].X.I = a
		}
		g.Vertices[q].Name = "INF"
		g.Vertices[q].X.I = q

//line gbraman.w:298
	case 2:

//line gbraman.w:321
		vi := int64(0)
		for a := int64(0); a < q; a++ {
			for aa := a + 1; aa <= q; aa++ {
				if aa == q {
					g.Vertices[vi].Name = fmt.Sprintf("{%d,INF}", a)
				} else {
					g.Vertices[vi].Name = fmt.Sprintf("{%d,%d}", a, aa)
				}
				g.Vertices[vi].X.I = a
				g.Vertices[vi].Y.I = aa
				vi++
			}
		}

//line gbraman.w:300
	default:

//line gbraman.w:341
		g.SetUtilType(5, 'I')
		vi := int64(0)
		for c := int64(0); c <= q; c++ {
			for b := int64(0); b < q; b++ {
				for a := int64(1); a <= nFactor; a++ {
					v := &g.Vertices[vi]
					v.Z.I = c

//line gbraman.w:357
					var det int64
					if typ == 3 {
						det = bd.qSqr[a]
					} else {
						det = a
					}
					if c == q { // 둘째 행이 $(0,1)$
						v.Y.I = b
						v.X.I = det
						v.Name = fmt.Sprintf("(%d,%d;0,1)", det, b)
					} else { // 둘째 행이 $(1,c)$
						v.X.I = b
						v.Y.I = (b*c + q - det) % q
						v.Name = fmt.Sprintf("(%d,%d;1,%d)", b, v.Y.I, c)
					}

//line gbraman.w:349
					vi++
				}
			}
		}

//line gbraman.w:302
	}
}

//line gbraman.w:450
func (bd *builder) computeGenerators(p int64) error {
	bd.gen = make([]quaternion, p+2)
	bd.genCount = 0
	bd.maxGen = p + 1
	if p == 2 {
		bd.specialGenerators()
	} else {
		bd.quaternionGenerators(p)
	}
	if bd.genCount != bd.maxGen {
		return ErrPNotPrime
	}
	return nil
}

//line gbraman.w:483
func (bd *builder) quaternionGenerators(p int64) {
	pp := (p >> 1) & 1 // $p\bmod4=1$이면 0, $p\bmod4=3$이면 1
	for a, sa := 1-pp, p-(1-pp); sa > 0; sa, a = sa-((a+1)<<2), a+2 {
		for b, bb := pp, sa-3*pp; bb >= 0; bb, b = bb-12*(b+1), b+2 {
			for c, cc := b, bb; cc >= 0; cc, c = cc-((c+1)<<3), c+2 {
				for d, aa := c, cc; aa >= 0; aa, d = aa-((d+1)<<2), d+2 {
					if aa == 0 {

//line gbraman.w:533
						bd.deposit(a, b, c, d)
						if b != 0 {
							bd.deposit(a, -b, c, d)
							bd.deposit(a, -b, -c, d)
						}
						if c != 0 {
							bd.deposit(a, b, -c, d)
						}

//line gbraman.w:547
						if b < c {
							bd.deposit(a, c, b, d)
							bd.deposit(a, -c, b, d)
							bd.deposit(a, c, d, b)
							bd.deposit(a, -c, d, b)
							if b != 0 {
								bd.deposit(a, c, -b, d)
								bd.deposit(a, -c, -b, d)
								bd.deposit(a, c, d, -b)
								bd.deposit(a, -c, d, -b)
							}
						}

//line gbraman.w:563
						if c < d {
							bd.deposit(a, b, d, c)
							bd.deposit(a, d, b, c)
							if b != 0 {
								bd.deposit(a, -b, d, c)
								bd.deposit(a, -b, d, -c)
								bd.deposit(a, d, -b, c)
								bd.deposit(a, d, -b, -c)
							}
							if c != 0 {
								bd.deposit(a, b, d, -c)
								bd.deposit(a, d, b, -c)
							}
							if b < c {
								bd.deposit(a, d, c, b)
								bd.deposit(a, d, -c, b)
								if b != 0 {
									bd.deposit(a, d, c, -b)
									bd.deposit(a, d, -c, -b)
								}
							}
						}

//line gbraman.w:491
					}
				}
			}
		}
	}

//line gbraman.w:597
	q := bd.q
	var kk int64
	for kk = q - 1; bd.qSqrt[kk] < 0; kk-- {
	}
	gg := bd.qSqrt[kk]
	hh := bd.qSqrt[q-1-kk]
	for k := p; k >= 0; k-- {
		a0, a1, a2, a3 := bd.gen[k].a0, bd.gen[k].a1, bd.gen[k].a2, bd.gen[k].a3

//line gbraman.w:609
		a00 := (a0 + gg*a1 + hh*a3) % q
		if a00 < 0 {
			a00 += q
		}
		a11 := (a0 - gg*a1 - hh*a3) % q
		if a11 < 0 {
			a11 += q
		}
		a01 := (a2 + gg*a3 - hh*a1) % q
		if a01 < 0 {
			a01 += q
		}
		a10 := (-a2 + gg*a3 - hh*a1) % q
		if a10 < 0 {
			a10 += q
		}
		bd.gen[k].a0, bd.gen[k].a1, bd.gen[k].a2, bd.gen[k].a3 = a00, a01, a10, a11

//line gbraman.w:606
	}

//line gbraman.w:497
}

//line gbraman.w:509
func (bd *builder) deposit(a, b, c, d int64) {
	if bd.genCount >= bd.maxGen { // |p+1|개를 이미 찾았다---|p|가 소수가 아니다
		bd.genCount = bd.maxGen + 1
		return
	}
	i := bd.genCount
	bd.gen[i].a0, bd.gen[i+1].a0 = a, a
	bd.gen[i].a1, bd.gen[i+1].a1 = b, -b
	bd.gen[i].a2, bd.gen[i+1].a2 = c, -c
	bd.gen[i].a3, bd.gen[i+1].a3 = d, -d
	if a != 0 {
		bd.gen[i].bar = i + 1
		bd.gen[i+1].bar = i
		bd.genCount += 2
	} else {
		bd.gen[i].bar = i
		bd.genCount++
	}
}

//line gbraman.w:640
func (bd *builder) specialGenerators() {
	q := bd.q
	s := bd.qSqrt[q-2]
	t := (bd.qSqrt[13%q] * s) % q
	bd.gen[0].a0, bd.gen[0].a1, bd.gen[0].a2, bd.gen[0].a3 = 1, 0, 0, q-1
	bd.gen[0].bar = 0
	bd.gen[1].a0, bd.gen[2].a3 = (2+s)%q, (2+s)%q
	bd.gen[1].a1, bd.gen[1].a2 = t, t
	bd.gen[2].a1, bd.gen[2].a2 = q-t, q-t
	bd.gen[1].a3, bd.gen[2].a0 = (q+2-s)%q, (q+2-s)%q
	bd.gen[1].bar, bd.gen[2].bar = 2, 1
	bd.genCount = 3
}

//line gbraman.w:663
func (bd *builder) appendEdges(g *gbgraph.Graph, p, typ, nFactor, reduce int64) {
	n := g.N
	for k := p; k >= 0; k-- {
		kk := bd.gen[k].bar
		if kk > k { // |kk=k|이거나 |kk=k-1|이라 본다
			continue
		}
		for i := int64(0); i < n; i++ {
			v := &g.Vertices[i]
			u := bd.image(g, v, k, typ, nFactor)
			if u == v {
				if reduce == 0 {
					g.NewEdge(v, v, 1)
					v.Arcs.A.I = kk
					v.Arcs.Next.A.I = k
				}
			} else {

//line gbraman.w:690
				if u.Arcs != nil && u.Arcs.A.I == kk {
					continue // |kk=k|이고 이 2-사이클은 이미 했다
				}
				if reduce != 0 {
					dup := false
					for ap := v.Arcs; ap != nil; ap = ap.Next {
						if ap.Tip == u {
							dup = true
							break
						}
					}
					if dup {
						continue // |u|와 |v| 사이에 이미 간선이 있다
					}
				}
				g.NewEdge(v, u, 1)
				v.Arcs.A.I = k
				u.Arcs.A.I = kk
				if ap := v.Arcs.Next; ap != nil && ap.A.I == kk {
					v.Arcs.Next = ap.Next // 이제 |v|의 호 목록이 |ref| 순서로 돌아왔다
					ap.Next = v.Arcs
					v.Arcs = ap
				}

//line gbraman.w:681
			}
		}
	}
}

//line gbraman.w:717
func (bd *builder) image(g *gbgraph.Graph, v *gbgraph.Vertex, k, typ, nFactor int64) *gbgraph.Vertex {
	q := bd.q
	if typ < 3 {

//line gbraman.w:799
		if typ == 1 {
			return &g.Vertices[bd.linFrac(v.X.I, k)]
		}
		a := bd.linFrac(v.X.I, k)
		aa := bd.linFrac(v.Y.I, k)
		if a < aa {
			return &g.Vertices[a*(2*q-1-a)/2+aa-1]
		}
		return &g.Vertices[aa*(2*q-1-aa)/2+a-1]

//line gbraman.w:721
	}
	a00, a01, a10, a11 := bd.gen[k].a0, bd.gen[k].a1, bd.gen[k].a2, bd.gen[k].a3
	a, b := v.X.I, v.Y.I
	var c, d int64
	if v.Z.I == q {
		c, d = 0, 1
	} else {
		c, d = 1, v.Z.I
	}

//line gbraman.w:735
	aa := (a*a00 + b*a10) % q
	bb := (a*a01 + b*a11) % q
	cc := (c*a00 + d*a10) % q
	dd := (c*a01 + d*a11) % q
	var norm int64
	if cc != 0 {
		norm = bd.qInv[cc]
	} else {
		norm = bd.qInv[dd]
	}
	d = (norm * dd) % q
	c = (norm * cc) % q
	b = (norm * bb) % q
	a = (norm * aa) % q

//line gbraman.w:731

//line gbraman.w:753
	if c == 0 {
		d = q
		aa = a
	} else {
		aa = (a*d - b) % q
		if aa < 0 {
			aa += q
		}
		b = a
	}
	det := aa
	if typ == 3 {
		det = bd.qSqrt[aa]
	}
	return &g.Vertices[(d*q+b)*nFactor+det-1]

//line gbraman.w:732
}

//line gbraman.w:779
func (bd *builder) linFrac(a, k int64) int64 {
	q := bd.qInv[0] // 법; |qInv[0]=q|
	a00, a01, a10, a11 := bd.gen[k].a0, bd.gen[k].a1, bd.gen[k].a2, bd.gen[k].a3
	var num, den int64
	if a == q {
		num, den = a00, a10
	} else {
		num = (a00*a + a01) % q
		den = (a10*a + a11) % q
	}
	if den == 0 {
		return q
	}
	return (num * bd.qInv[den]) % q
}
