// Package raman implements GB_RAMAN from Stanford GraphBase.
//
// Raman constructs Ramanujan graphs based on the theory of
// Lubotzky, Phillips, and Sarnak (Combinatorica 8, 1988).
package gbraman

import (
	"fmt"

	"github.com/sjnam/go-sgb/gbgraph"
)

type quaternion struct {
	a0, a1, a2, a3 int64
	bar            int64 // index of conjugate quaternion in gen table
}

// Raman constructs a (p+1)-regular Ramanujan graph.
//
// p and q must be distinct primes; q must be odd and satisfy additional
// constraints depending on typeVal. typeVal=0 selects the largest permissible
// type (3 or 4). If reduce is true, self-loops and multi-edges are removed.
func Raman(p, q, typeVal int64, reduce bool) (*gbgraph.Graph, error) {
	if q < 3 || q > 46337 {
		return nil, gbgraph.ErrVeryBadSpecs
	}
	if p < 2 {
		return nil, gbgraph.ErrVeryBadSpecs
	}

	// ---- Arithmetic tables mod q ----
	qSqr := make([]int64, q)
	qSqrt := make([]int64, q)
	qInv := make([]int64, q)

	for a := int64(1); a < q; a++ {
		qSqrt[a] = -1
	}
	// qSqr[a] = a^2 mod q; qSqrt[aa] = smaller square root of aa; qInv marks squares
	for a, aa := int64(1), int64(1); a < q; aa, a = (aa+a+a+1)%q, a+1 {
		qSqr[a] = aa
		qSqrt[aa] = q - a // smaller root survives (last write wins as a→q-1)
		qInv[aa] = -1     // mark as non-primitive-root candidate
	}

	// Find primitive root and its inverse
	var primRoot, primInv int64
	for cand := int64(2); ; cand++ {
		if qInv[cand] != 0 {
			continue
		}
		var b, prev, k int64
		for b, k = cand, 1; b != 1 && k < q; prev, b, k = b, (cand*b)%q, k+1 {
			qInv[b] = -1
		}
		if k >= q {
			return nil, gbgraph.ErrBadSpecs // q is not prime
		}
		if k == q-1 {
			primRoot = cand
			primInv = prev // = cand^(q-2) mod q = cand^{-1}
			break
		}
	}

	// Build inverse table: pair cand^k ↔ cand^{q-1-k}
	b, bb := primRoot, primInv
	for b != bb {
		qInv[b] = bb
		qInv[bb] = b
		b = (primRoot * b) % q
		bb = (primInv * bb) % q
	}
	qInv[1] = 1
	qInv[b] = b // b == q-1 here; self-inverse
	qInv[0] = q // represents infinity

	// ---- Validate p and choose/verify typeVal ----
	if p == 2 {
		if qSqrt[13%q] < 0 || qSqrt[q-2] < 0 {
			return nil, gbgraph.ErrBadSpecs
		}
	}
	aMod := p % q
	if aMod == 0 {
		return nil, gbgraph.ErrBadSpecs
	}
	if typeVal == 0 {
		if qSqrt[aMod] > 0 {
			typeVal = 3
		} else {
			typeVal = 4
		}
	}
	nFactor := int64(0)
	if typeVal == 3 {
		nFactor = (q - 1) / 2
	} else if typeVal >= 4 {
		nFactor = q - 1
	}

	var n int64
	switch typeVal {
	case 1:
		n = q + 1
	case 2:
		n = q * (q + 1) / 2
	default:
		if (qSqrt[aMod] > 0 && typeVal != 3) || (qSqrt[aMod] < 0 && typeVal != 4) {
			return nil, gbgraph.ErrBadSpecs
		}
		if q > 1289 {
			return nil, gbgraph.ErrBadSpecs
		}
		n = nFactor * q * (q + 1)
	}
	if p >= int64(0x3fffffff)/n {
		return nil, gbgraph.ErrBadSpecs
	}

	// ---- Set up graph with n vertices ----
	newGraph := gbgraph.NewGraph(n)
	if newGraph == nil {
		return nil, gbgraph.ErrNoRoom
	}
	newGraph.ID = fmt.Sprintf("raman(%d,%d,%d,%d)", p, q, typeVal, boolInt(reduce))
	newGraph.UtilTypes = "ZZZIIZIZZZZZZZ"

	switch typeVal {
	case 1:
		// vertex.Y unused; only vertex.X stores serial number
		ut := []byte(newGraph.UtilTypes)
		ut[4] = 'Z'
		newGraph.UtilTypes = string(ut)
		for a := range q {
			v := &newGraph.Vertices[a]
			v.Name = fmt.Sprintf("%d", a)
			v.X = a
		}
		newGraph.Vertices[q].Name = "INF"
		newGraph.Vertices[q].X = q
	case 2:
		vi := int64(0)
		for a := range q {
			for aa := a + 1; aa <= q; aa++ {
				v := &newGraph.Vertices[vi]
				if aa == q {
					v.Name = fmt.Sprintf("{%d,INF}", a)
				} else {
					v.Name = fmt.Sprintf("{%d,%d}", a, aa)
				}
				v.X = a
				v.Y = aa
				vi++
			}
		}
	default:
		// vertex.Z also used (z.I = second row ratio)
		ut := []byte(newGraph.UtilTypes)
		ut[5] = 'I'
		newGraph.UtilTypes = string(ut)
		vi := int64(0)
		for c := int64(0); c <= q; c++ {
			for bv := range q {
				for ai := int64(1); ai <= nFactor; ai++ {
					v := &newGraph.Vertices[vi]
					v.Z = c
					if c == q { // second row (0,1)
						v.Y = bv
						det := ai
						if typeVal == 3 {
							det = qSqr[ai]
						}
						v.X = det
						v.Name = fmt.Sprintf("(%d,%d;0,1)", det, bv)
					} else { // second row (1,c)
						v.X = bv
						det := ai
						if typeVal == 3 {
							det = qSqr[ai]
						}
						yVal := (bv*c + q - det) % q
						v.Y = yVal
						v.Name = fmt.Sprintf("(%d,%d;1,%d)", bv, yVal, c)
					}
					vi++
				}
			}
		}
	}

	// ---- Compute p+1 generators ----
	gen := make([]quaternion, p+2)
	genCount := int64(0)
	maxGenCount := p + 1

	deposit := func(da, db, dc, dd int64) {
		if genCount >= maxGenCount {
			genCount = maxGenCount + 1
			return
		}
		gen[genCount].a0 = da
		gen[genCount+1].a0 = da
		gen[genCount].a1 = db
		gen[genCount+1].a1 = -db
		gen[genCount].a2 = dc
		gen[genCount+1].a2 = -dc
		gen[genCount].a3 = dd
		gen[genCount+1].a3 = -dd
		if da != 0 {
			gen[genCount].bar = genCount + 1
			gen[genCount+1].bar = genCount
			genCount += 2
		} else {
			gen[genCount].bar = genCount
			genCount++
		}
	}

	if p == 2 {
		s := qSqrt[q-2]
		t := (qSqrt[13%q] * s) % q
		gen[0].a0 = 1
		gen[0].a1 = 0
		gen[0].a2 = 0
		gen[0].a3 = q - 1
		gen[0].bar = 0
		gen[1].a0 = (2 + s) % q
		gen[1].a1 = t
		gen[1].a2 = t
		gen[1].a3 = (q + 2 - s) % q
		gen[1].bar = 2
		gen[2].a0 = (q + 2 - s) % q
		gen[2].a1 = q - t
		gen[2].a2 = q - t
		gen[2].a3 = (2 + s) % q
		gen[2].bar = 1
		genCount = 3
	} else {
		// Enumerate all representations of p as sum of 4 squares with canonical form.
		// pp=0: p%4=1, a0 odd; pp=1: p%4=3, a0 even.
		pp := (p >> 1) & 1
		aStart := int64(1) - pp
		for a, sa := aStart, p-aStart; sa > 0; {
			b := pp
			sb := sa - b*b        // = sa - pp (since pp in {0,1})
			bbt := sb - b*b - b*b // = sa - 3*b^2
			for bbt >= 0 {
				c := b
				cc := bbt
				for cc >= 0 {
					d := c
					daa := cc
					for daa >= 0 {
						if daa == 0 {
							deposit(a, b, c, d)
							if b != 0 {
								deposit(a, -b, c, d)
								deposit(a, -b, -c, d)
							}
							if c != 0 {
								deposit(a, b, -c, d)
							}
							if b < c {
								deposit(a, c, b, d)
								deposit(a, -c, b, d)
								deposit(a, c, d, b)
								deposit(a, -c, d, b)
								if b != 0 {
									deposit(a, c, -b, d)
									deposit(a, -c, -b, d)
									deposit(a, c, d, -b)
									deposit(a, -c, d, -b)
								}
							}
							if c < d {
								deposit(a, b, d, c)
								deposit(a, d, b, c)
								if b != 0 {
									deposit(a, -b, d, c)
									deposit(a, -b, d, -c)
									deposit(a, d, -b, c)
									deposit(a, d, -b, -c)
								}
								if c != 0 {
									deposit(a, b, d, -c)
									deposit(a, d, b, -c)
								}
								if b < c {
									deposit(a, d, c, b)
									deposit(a, d, -c, b)
									if b != 0 {
										deposit(a, d, c, -b)
										deposit(a, d, -c, -b)
									}
								}
							}
						}
						daa -= (d + 1) << 2
						d += 2
					}
					cc -= (c + 1) << 3
					c += 2
				}
				bbt -= 12 * (b + 1)
				sb -= (b + 1) << 2
				b += 2
			}
			sa -= (a + 1) << 2
			a += 2
		}

		if genCount != maxGenCount {
			newGraph.Recycle()
			return nil, gbgraph.ErrBadSpecs // p is not prime
		}

		// Convert quaternion form to 2×2 matrix form using
		// g=sqrt(k), h=sqrt(q-1-k) for largest QR k mod q.
		gv := int64(0)
		hv := int64(0)
		kk := q - 1
		for ; qSqrt[kk] < 0; kk-- {
		}
		gv = qSqrt[kk]
		if q-1-kk > 0 {
			hv = qSqrt[q-1-kk]
		}
		for k := p; k >= 0; k-- {
			a00 := (gen[k].a0 + gv*gen[k].a1 + hv*gen[k].a3) % q
			if a00 < 0 {
				a00 += q
			}
			a11 := (gen[k].a0 - gv*gen[k].a1 - hv*gen[k].a3) % q
			if a11 < 0 {
				a11 += q
			}
			a01 := (gen[k].a2 + gv*gen[k].a3 - hv*gen[k].a1) % q
			if a01 < 0 {
				a01 += q
			}
			a10 := (-gen[k].a2 + gv*gen[k].a3 - hv*gen[k].a1) % q
			if a10 < 0 {
				a10 += q
			}
			gen[k].a0 = a00
			gen[k].a1 = a01
			gen[k].a2 = a10
			gen[k].a3 = a11
		}
	}

	// Linear fractional transformation z → (a00*z + a01) / (a10*z + a11) mod q
	linFrac := func(av, k int64) int64 {
		a00 := gen[k].a0
		a01 := gen[k].a1
		a10 := gen[k].a2
		a11 := gen[k].a3
		var num, den int64
		if av == q { // av = infinity
			num = a00
			den = a10
		} else {
			num = (a00*av + a01) % q
			den = (a10*av + a11) % q
		}
		if den == 0 {
			return q // result is infinity
		}
		return (num * qInv[den]) % q
	}

	// ---- Append edges ----
	for k := p; k >= 0; k-- {
		kk := gen[k].bar
		if kk > k {
			continue
		}
		for vi := int64(0); vi < n; vi++ {
			v := &newGraph.Vertices[vi]
			var u *gbgraph.Vertex

			// Compute image u of v under generator k
			if typeVal < 3 {
				if typeVal == 1 {
					vx, _ := v.X.(int64)
					u = &newGraph.Vertices[linFrac(vx, k)]
				} else { // type 2: transform both pair elements
					vx, _ := v.X.(int64)
					vy, _ := v.Y.(int64)
					a2 := linFrac(vx, k)
					aa2 := linFrac(vy, k)
					if a2 < aa2 {
						u = &newGraph.Vertices[a2*(2*q-1-a2)/2+aa2-1]
					} else {
						u = &newGraph.Vertices[aa2*(2*q-1-aa2)/2+a2-1]
					}
				}
			} else { // type 3 or 4: matrix multiplication
				a00 := gen[k].a0
				a01 := gen[k].a1
				a10 := gen[k].a2
				a11 := gen[k].a3
				va, _ := v.X.(int64)
				vb, _ := v.Y.(int64)
				var vc, vd int64
				vz, _ := v.Z.(int64)
				if vz == q {
					vc = 0
					vd = 1
				} else {
					vc = 1
					vd = vz
				}
				// (raa,rbb;rcc,rdd) = (va,vb;vc,vd) * (a00,a01;a10,a11)
				raa := (va*a00 + vb*a10) % q
				rbb := (va*a01 + vb*a11) % q
				rcc := (vc*a00 + vd*a10) % q
				rdd := (vc*a01 + vd*a11) % q

				// Normalize second row to (0,1) or (1,x)
				var normFactor int64
				if rcc != 0 {
					normFactor = qInv[rcc]
				} else {
					normFactor = qInv[rdd]
				}
				rd := (normFactor * rdd) % q
				rc := (normFactor * rcc) % q
				rb := (normFactor * rbb) % q
				ra := (normFactor * raa) % q

				var det int64
				if rc == 0 {
					rd = q // second row is (0,1); encode INF
					det = ra
				} else {
					det = (ra*rd - rb) % q
					if det < 0 {
						det += q
					}
					rb = ra // second row is (1,rd); upper-left becomes rb=ra
				}
				lookup := det
				if typeVal == 3 {
					lookup = qSqrt[det]
				}
				u = &newGraph.Vertices[(rd*q+rb)*nFactor+lookup-1]
			}

			if u == v {
				if !reduce {
					newGraph.NewEdge(v, v, 1)
					v.Arcs.A = kk
					v.Arcs.Next.A = int64(k)
				}
			} else {
				// For self-inverse generators (kk==k), skip if already done
				if u.Arcs != nil {
					if ref, _ := u.Arcs.A.(int64); ref == kk {
						continue
					}
				}
				if reduce {
					skip := false
					for ap := v.Arcs; ap != nil; ap = ap.Next {
						if ap.Tip == u {
							skip = true
							break
						}
					}
					if skip {
						continue
					}
				}
				newGraph.NewEdge(v, u, 1)
				v.Arcs.A = int64(k)
				u.Arcs.A = kk
				// Maintain ascending ref order in v's arc list
				if ap := v.Arcs.Next; ap != nil {
					if ref, _ := ap.A.(int64); ref == kk {
						v.Arcs.Next = ap.Next
						ap.Next = v.Arcs
						v.Arcs = ap
					}
				}
			}
		}
	}

	return newGraph, nil
}

// boolInt renders a flag as 0 or 1, matching the C-style ID strings of SGB.
func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
