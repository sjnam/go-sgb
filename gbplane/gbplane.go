//line gbplane.w:45
package gbplane

import (
	"fmt"
	"strconv"

	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbmiles"
)

const (
	infty    = 0x10000000 // ``무한'' 길이, $2^{28}$
	maxCoord = 16384      // 좌표의 상한, $2^{14}$
)

//line gbplane.w:234
func boolInt(b bool) int64 {
	if b {
		return 1
	}
	return 0
}

//line gbplane.w:242
func intSqrt(x int64) int64 {
	if x <= 0 {
		return 0
	}
	var y, m, k int64
	q := int64(2)
	for k, m = 25, 0x20000000; x < m; k, m = k-1, m>>2 {
	}
	if x >= m+m {
		y = 1
	} else {
		y = 0
	}
	for {

//line gbplane.w:265
		if x&m != 0 {
			y += y + 1
		} else {
			y += y
		}
		m >>= 1
		if x&m != 0 {
			y += y - q + 1
		} else {
			y += y - q
		}
		q += q
		if y > q {
			y -= q
			q += 2
		} else if y <= 0 {
			q -= 2
			y += q
		}
		m >>= 1
		k--

//line gbplane.w:257
		if k == 0 {
			break
		}
	}
	return q >> 1
}

//line gbplane.w:293
func signTest(x1, x2, x3, y1, y2, y3 int64) int64 {
	var s1, s2, s3 int64
	var a, b, c int64

//line gbplane.w:303
	if x1 == 0 || y1 == 0 {
		s1 = 0
	} else if x1 > 0 {
		s1 = 1
	} else {
		x1, s1 = -x1, -1
	}
	if x2 == 0 || y2 == 0 {
		s2 = 0
	} else if x2 > 0 {
		s2 = 1
	} else {
		x2, s2 = -x2, -1
	}
	if x3 == 0 || y3 == 0 {
		s3 = 0
	} else if x3 > 0 {
		s3 = 1
	} else {
		x3, s3 = -x3, -1
	}

//line gbplane.w:297

//line gbplane.w:328
	if (s1 >= 0 && s2 >= 0 && s3 >= 0) || (s1 <= 0 && s2 <= 0 && s3 <= 0) {
		return s1 + s2 + s3
	}
	if s3 == 0 || s3 == s1 {
		s2, s3 = s3, s2
		x2, x3 = x3, x2
		y2, y3 = y3, y2
	} else if s3 == s2 {
		s1, s3 = s3, s1
		x1, x3 = x3, x1
		y1, y3 = y3, y1
	}

//line gbplane.w:298

//line gbplane.w:345
	{
		var lx, rx, ly, ry int64
		lx, rx = x1/0x4000, x1%0x4000 // 아래 14비트를 떼낸다
		ly, ry = y1/0x4000, y1%0x4000
		a, b, c = lx*ly, lx*ry+ly*rx, rx*ry
		lx, rx = x2/0x4000, x2%0x4000
		ly, ry = y2/0x4000, y2%0x4000
		a, b, c = a+lx*ly, b+lx*ry+ly*rx, c+rx*ry
		lx, rx = x3/0x4000, x3%0x4000
		ly, ry = y3/0x4000, y3%0x4000
		a, b, c = a-lx*ly, b-lx*ry-ly*rx, c-rx*ry
	}

//line gbplane.w:299

//line gbplane.w:362
	if a != 0 {
		if a < 0 {
			a, b, c, s3 = -a, -b, -c, -s3
		}
		cZero := false
		for c < 0 {
			a--
			c += 0x10000000
			if a == 0 {
				cZero = true
				break
			}
		}
		if !cZero {
			if b >= 0 {
				return -s3 // |a>0 && b>=0 && c>=0|이면 답은 분명하다
			}
			b = -b
			a -= b / 0x4000
			if a > 0 {
				return -s3
			}
			if a <= -2 {
				return s3
			}
			return -s3 * ((a*0x4000-b%0x4000)*0x4000 + c)
		}
	}
	if b >= 0x8000 {
		return -s3
	}
	if b <= -0x8000 {
		return s3
	}
	return -s3 * (b*0x4000 + c)

//line gbplane.w:300
}

//line gbplane.w:418
func ccw(u, v, w *gbgraph.Vertex) bool {
	wx, wy := w.X.I, w.Y.I
	det := (u.X.I-wx)*(v.Y.I-wy) - (u.Y.I-wy)*(v.X.I-wx)
	if det == 0 {
		det = 1
		if u.Z.I > v.Z.I {
			u, v, det = v, u, -det
		}
		if v.Z.I > w.Z.I {
			v, w, det = w, v, -det
		}
		if u.Z.I > v.Z.I {
			u, v, det = v, u, -det
		}

//line gbplane.w:438
		if u.X.I > v.X.I || (u.X.I == v.X.I && (u.Y.I > v.Y.I ||
			(u.Y.I == v.Y.I && (w.X.I > u.X.I ||
				(w.X.I == u.X.I && w.Y.I >= u.Y.I))))) {
			det = -det
		}

//line gbplane.w:433
	}
	return det > 0
}

//line gbplane.w:462
func incircle(t, u, v, w *gbgraph.Vertex) bool {
	wx, wy := w.X.I, w.Y.I
	tx, ty := t.X.I-wx, t.Y.I-wy
	ux, uy := u.X.I-wx, u.Y.I-wy
	vx, vy := v.X.I-wx, v.Y.I-wy
	det := signTest(tx*uy-ty*ux, ux*vy-uy*vx, vx*ty-vy*tx,
		vx*vx+vy*vy, tx*tx+ty*ty, ux*ux+uy*uy)
	if det == 0 {

//line gbplane.w:477
		det = 1
		if t.Z.I > u.Z.I {
			t, u, det = u, t, -det
		}
		if v.Z.I > w.Z.I {
			v, w, det = w, v, -det
		}
		if t.Z.I > v.Z.I {
			t, v, det = v, t, -det
		}
		if u.Z.I > w.Z.I {
			u, w, det = w, u, -det
		}
		if u.Z.I > v.Z.I {
			u, v, det = v, u, -det
		}

//line gbplane.w:471

//line gbplane.w:500
		for _, dd := range [...]int64{
			ff(t, u, v, w), gg(t, u, v, w),
			ff(u, t, w, v), gg(u, t, w, v),
			ff(v, w, t, u), gg(v, w, t, u),
			hh(t, u, v, w), jj(t, u, v, w),
			hh(v, t, u, w), jj(v, t, u, w),
			jj(t, w, u, v),
		} {
			if dd != 0 {
				if dd < 0 {
					det = -det
				}
				break
			}
		}

//line gbplane.w:472
	}
	return det > 0
}

//line gbplane.w:519
func ff(t, u, v, w *gbgraph.Vertex) int64 {
	wx, wy := w.X.I, w.Y.I
	tx, ty := t.X.I-wx, t.Y.I-wy
	ux, uy := u.X.I-wx, u.Y.I-wy
	vx, vy := v.X.I-wx, v.Y.I-wy
	return signTest(ux-tx, vx-ux, tx-vx, vx*vx+vy*vy, tx*tx+ty*ty, ux*ux+uy*uy)
}

func gg(t, u, v, w *gbgraph.Vertex) int64 {
	wx, wy := w.X.I, w.Y.I
	tx, ty := t.X.I-wx, t.Y.I-wy
	ux, uy := u.X.I-wx, u.Y.I-wy
	vx, vy := v.X.I-wx, v.Y.I-wy
	return signTest(uy-ty, vy-uy, ty-vy, vx*vx+vy*vy, tx*tx+ty*ty, ux*ux+uy*uy)
}

func hh(t, u, v, w *gbgraph.Vertex) int64 {
	return (u.X.I - t.X.I) * (v.Y.I - w.Y.I)
}

func jj(t, u, v, w *gbgraph.Vertex) int64 {
	vx, wy := v.X.I, w.Y.I
	return (u.X.I-vx)*(u.X.I-vx) + (u.Y.I-wy)*(u.Y.I-wy) -
		(t.X.I-vx)*(t.X.I-vx) - (t.Y.I-wy)*(t.Y.I-wy)
}

//line gbplane.w:552
type darc struct {
	idx  int             // |arcBlock| 안의 자리; 짝을 찾는 데 쓴다
	vert *gbgraph.Vertex // 이 호가 가는 정점
	next *darc           // 같은 삼각형을 공유하는 다음 호
	inst *bnode          // 삼각형이 바뀔 때 고칠 지시
}

//line gbplane.w:567
type bnode struct {
	u, v *gbgraph.Vertex // 분기 노드의 두 정점 (|u==nil|이면 끝 노드)
	l, r *bnode          // |w|가 $uv$의 왼쪽·오른쪽일 때 갈 곳
	tri  *darc           // 끝 노드: 삼각형의 한 호
}

//line gbplane.w:578
type dtri struct {
	arcBlock []darc // 모든 호
	maxIdx   int    // |arcBlock|의 마지막 자리, $6n-7$
	nextIdx  int    // 아직 안 쓴 첫 호
	root     bnode  // 삼각형을 찾기 시작하는 뿌리
}

func (dt *dtri) mate(a *darc) *darc { return &dt.arcBlock[dt.maxIdx-a.idx] }

//line gbplane.w:586
func (dt *dtri) off(a *darc, k int) *darc { return &dt.arcBlock[a.idx+k] }

//line gbplane.w:587
func (dt *dtri) terminal(a *darc) *bnode { return &bnode{tri: a} }

//line gbplane.w:593
func flip(c, d, e *darc, t, tp, tpp, p *gbgraph.Vertex, xp, xpp *bnode) {
	ep, cp := e.next, c.next
	cpp := cp.next
	e.next, c.next, cpp.next = c, cpp, e
	e.inst, c.inst, cpp.inst = xp, xp, xp
	c.vert = p
	d.next, ep.next, cp.next = ep, cp, d
	d.inst, ep.inst, cp.inst = xpp, xpp, xpp
	d.vert = tpp
}

//line gbplane.w:610
func Delaunay(g *gbgraph.Graph, f func(u, v *gbgraph.Vertex)) {
	if g.N < 2 {
		return // 정점이 둘은 있어야 간선이 있다
	}
	dt := &dtri{}
	var a, aa, b, c, d, e *darc
	var p, q, r, s, t, tp, tpp, u, v *gbgraph.Vertex
	var x, y, yp, ypp *bnode

//line gbplane.w:632
	m := 6*g.N - 6
	dt.arcBlock = make([]darc, m)
	for i := range dt.arcBlock {
		dt.arcBlock[i].idx = i
	}
	dt.maxIdx = int(m) - 1
	u = &g.Vertices[0]
	v = &g.Vertices[1]

//line gbplane.w:643
	dt.root.u, dt.root.v = u, v
	a = &dt.arcBlock[dt.nextIdx]
	x = dt.terminal(dt.off(a, 1))
	dt.root.l = x
	a.vert, a.next, a.inst = v, dt.off(a, 1), x
	dt.off(a, 1).next, dt.off(a, 1).inst = dt.off(a, 2), x // |(a+1).vert=nil|, 곧 $\infty$
	dt.off(a, 2).vert, dt.off(a, 2).next, dt.off(a, 2).inst = u, a, x
	b = dt.mate(a)
	x = dt.terminal(dt.off(b, -2))
	dt.root.r = x
	b.vert, b.next, b.inst = u, dt.off(b, -2), x
	dt.off(b, -2).next, dt.off(b, -2).inst = dt.off(b, -1), x // |(b-2).vert=nil|
	dt.off(b, -1).vert, dt.off(b, -1).next, dt.off(b, -1).inst = v, b, x
	dt.nextIdx += 3

//line gbplane.w:619
	for pi := int64(2); pi < g.N; pi++ {
		p = &g.Vertices[pi]

//line gbplane.w:662
		x = &dt.root
		for {
			if ccw(x.u, x.v, p) {
				x = x.l
			} else {
				x = x.r
			}
			if x.u == nil {
				break // 끝 노드에 이르렀다
			}
		}
		a = x.tri

//line gbplane.w:622

//line gbplane.w:680
		b = a.next
		c = b.next
		q, r, s = a.vert, b.vert, c.vert

//line gbplane.w:700
		na := &dt.arcBlock[dt.nextIdx]
		yp = dt.terminal(a)
		ypp = dt.terminal(na)
		y = dt.terminal(c)
		c.inst, a.inst, b.inst = y, yp, ypp
		e = dt.mate(na)
		a.next, b.next, c.next = e, dt.off(e, -1), dt.off(e, -2)
		na.vert, na.next, na.inst = q, b, ypp
		dt.off(na, 1).vert, dt.off(na, 1).next, dt.off(na, 1).inst = r, c, y
		dt.off(na, 2).vert, dt.off(na, 2).next, dt.off(na, 2).inst = s, a, yp
		e.vert, dt.off(e, -1).vert, dt.off(e, -2).vert = p, p, p
		e.next, dt.off(e, -1).next, dt.off(e, -2).next = dt.off(na, 2), na, dt.off(na, 1)
		e.inst, dt.off(e, -1).inst, dt.off(e, -2).inst = yp, ypp, y
		dt.nextIdx += 3

//line gbplane.w:684
		if q == nil {

//line gbplane.w:720
			xp := new(bnode)
			x.u, x.v, x.l = r, p, ypp
			xp.u, xp.v, xp.l, xp.r = s, p, y, yp
			x.r = xp
			aa = dt.mate(a)
			d = aa.next
			t = d.vert
			for t != r && ccw(p, s, t) {

//line gbplane.w:737
				xpp := dt.terminal(d)
				xp.r = d.inst
				xp = d.inst
				xp.u, xp.v, xp.l, xp.r = t, p, xpp, yp
				flip(a, aa, d, s, nil, t, p, xpp, yp)
				a = aa.next
				aa = dt.mate(a)
				d = aa.next
				s, t = t, d.vert
				yp.tri = a

//line gbplane.w:729
			}
			xp = dt.terminal(d.next)
			x = d.inst
			x.u, x.v, x.l, x.r = s, p, xp, yp
			d.inst, d.next.inst, d.next.next.inst = xp, xp, xp
			r = s // 이 |r| 값은 뒤따르는 탐색 단계를 줄여 준다

//line gbplane.w:686
		} else {
			x.u, x.v = r, p
			xp := new(bnode)
			xp.u, xp.v, xp.l, xp.r = q, p, yp, ypp // 지시 $x''$
			x.l = xp
			xp = new(bnode)
			xp.u, xp.v, xp.l, xp.r = s, p, y, yp // 지시 $x'$
			x.r = xp
		}

//line gbplane.w:623

//line gbplane.w:752
		for {
			d = dt.mate(c)
			e = d.next
			t, tp, tpp = d.vert, c.vert, e.vert
			if tpp != nil && incircle(tpp, tp, t, p) {

//line gbplane.w:768
				xp := dt.terminal(e)
				xpp := dt.terminal(d)
				x = c.inst
				x.u, x.v, x.l, x.r = tpp, p, xp, xpp
				x = d.inst
				x.u, x.v, x.l, x.r = tpp, p, xp, xpp
				flip(c, d, e, t, tp, tpp, p, xp, xpp)

//line gbplane.w:758
				c = e
			} else if tp == r {
				break
			} else {
				aa = dt.mate(c.next)
				c = aa.next
			}
		}

//line gbplane.w:624
	}

//line gbplane.w:780
	for i := 0; i < dt.nextIdx; i++ {
		ai := &dt.arcBlock[i]
		f(ai.vert, dt.mate(ai).vert)
	}

//line gbplane.w:626
}

//line gbplane.w:70
func Plane(n, xRange, yRange int64, extend bool, prob, seed int64) (*gbgraph.Graph, error) {
	rng := gbflip.New(seed)
	if xRange > maxCoord || yRange > maxCoord {
		return nil, gbgraph.BadSpecs // 범위가 너무 크다
	}
	if n < 2 {
		return nil, gbgraph.VeryBadSpecs // |n|이 너무 작다
	}
	if xRange == 0 {
		xRange = maxCoord
	}
	if yRange == 0 {
		yRange = maxCoord
	}

//line gbplane.w:98
	g := gbgraph.NewGraph(n)
	g.ID = fmt.Sprintf("plane(%d,%d,%d,%d,%d,%d)",
		n, xRange, yRange, boolInt(extend), prob, seed)
	g.UtilTypes = "ZZZIIIZZZZZZZZ"
	for k := int64(0); k < n; k++ {
		v := &g.Vertices[k]
		v.X.I = rng.Unif(xRange)
		v.Y.I = rng.Unif(yRange)
		v.Z.I = (rng.Next()/n)*n + k
		v.Name = strconv.FormatInt(k, 10)
	}
	var infVertex *gbgraph.Vertex
	if extend {
		infVertex = &g.Vertices[n]
		infVertex.Name = "INF"
		infVertex.X.I, infVertex.Y.I, infVertex.Z.I = -1, -1, -1
	}

//line gbplane.w:85

//line gbplane.w:121
	newEuclidEdge := func(u, v *gbgraph.Vertex) {
		if (rng.Next() >> 15) >= prob {
			if u != nil {
				if v != nil {
					dx := u.X.I - v.X.I
					dy := u.Y.I - v.Y.I
					g.NewEdge(u, v, intSqrt(dx*dx+dy*dy))
				} else if infVertex != nil {
					g.NewEdge(u, infVertex, infty)
				}
			} else if infVertex != nil {
				g.NewEdge(infVertex, v, infty)
			}
		}
	}
	Delaunay(g, newEuclidEdge)

//line gbplane.w:86
	if extend {
		g.N++ // ``무한'' 정점을 정식 정점으로 만든다
	}
	return g, nil
}

//line gbplane.w:802
func PlaneMiles(n, northWeight, westWeight, popWeight int64, extend bool,
	prob, seed int64, dir string) (*gbgraph.Graph, error) {
	rng := gbflip.New(seed)
	g, dist, err := gbmiles.MilesRNGDist(
		n, northWeight, westWeight, popWeight, 1, 0, seed, rng, dir)
	if err != nil {
		return nil, err // |MilesRNGDist|가 이미 사정을 알렸다
	}
	g.ID = fmt.Sprintf("plane_miles(%d,%d,%d,%d,%d,%d,%d)",
		n, northWeight, westWeight, popWeight, boolInt(extend), prob, seed)

//line gbplane.w:820
	var infVertex *gbgraph.Vertex
	if extend {
		infVertex = &g.Vertices[g.N]
		infVertex.Name = "INF"
		infVertex.X.I, infVertex.Y.I, infVertex.Z.I = -1, -1, -1
	}
	newMileEdge := func(u, v *gbgraph.Vertex) {
		if (rng.Next() >> 15) >= prob {
			if u != nil {
				if v != nil {
					g.NewEdge(u, v, dist[gbmiles.MaxN*u.Z.I+v.Z.I])
				} else if infVertex != nil {
					g.NewEdge(u, infVertex, infty)
				}
			} else if infVertex != nil {
				g.NewEdge(infVertex, v, infty)
			}
		}
	}
	Delaunay(g, newMileEdge)

//line gbplane.w:813
	if extend {
		g.N++ // ``무한'' 정점을 정식 정점으로 만든다
	}
	return g, nil
}
