// Package plane implements GB_PLANE from Stanford GraphBase.
//
// Plane constructs an undirected planar graph using the Delaunay triangulation
// of uniformly distributed random points in a rectangle. PlaneMiles constructs
// a planar graph from the city coordinates in miles.dat. Both use the general-
// purpose Delaunay function.
//
// Vertex utility fields (UtilTypes "ZZZIIIZZZZZZZZ"):
//
//	X = x_coord (int64: x coordinate)
//	Y = y_coord (int64: y coordinate)
//	Z = z_coord (int64: unique ID for tie-breaking)
package plane

import (
	"fmt"

	"github.com/sjnam/go-sgb/flip"
	"github.com/sjnam/go-sgb/graph"
	"github.com/sjnam/go-sgb/miles"
)

// Infty is the length assigned to edges connecting a finite vertex to infinity.
const Infty = int64(0x10000000)

// dlArc is an internal Delaunay arc (edge with direction).
type dlArc struct {
	idx  int
	vert *graph.Vertex
	next *dlArc
	inst *dlNode
}

// dlNode is a branch or terminal node in the Delaunay search DAG.
// When u == nil the node is terminal and arc holds the triangle's bounding arc.
type dlNode struct {
	u    *graph.Vertex
	v    *graph.Vertex
	arc  *dlArc
	l, r *dlNode
}

// ---- Arithmetic helpers ----

// intSqrt returns floor(2^10 * sqrt(x) + 1/2).
func intSqrt(x int64) int64 {
	if x <= 0 {
		return 0
	}
	k := int64(25)
	m := int64(0x20000000)
	for x < m {
		k--
		m >>= 2
	}
	var y int64
	if x >= m+m {
		y = 1
	}
	q := int64(2)
	for k > 0 {
		if x&m != 0 {
			y = y + y + 1
		} else {
			y = y + y
		}
		m >>= 1
		if x&m != 0 {
			y = y + y - q + 1
		} else {
			y = y + y - q
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
	}
	return q >> 1
}

// signTest returns the sign of x1*y1 + x2*y2 + x3*y3, computed exactly
// when -2^29 < xi < 2^29 and 0 <= yi < 2^29.
func signTest(x1, x2, x3, y1, y2, y3 int64) int64 {
	var s1, s2, s3 int64
	if x1 == 0 || y1 == 0 {
		s1 = 0
	} else if x1 > 0 {
		s1 = 1
	} else {
		x1 = -x1
		s1 = -1
	}
	if x2 == 0 || y2 == 0 {
		s2 = 0
	} else if x2 > 0 {
		s2 = 1
	} else {
		x2 = -x2
		s2 = -1
	}
	if x3 == 0 || y3 == 0 {
		s3 = 0
	} else if x3 > 0 {
		s3 = 1
	} else {
		x3 = -x3
		s3 = -1
	}
	if (s1 >= 0 && s2 >= 0 && s3 >= 0) || (s1 <= 0 && s2 <= 0 && s3 <= 0) {
		return s1 + s2 + s3
	}
	switch s3 {
	case 0, s1:
		s3, s2 = s2, s3
		x3, x2 = x2, x3
		y3, y2 = y2, y3
	case s2:
		s3, s1 = s1, s3
		x3, x1 = x1, x3
		y3, y1 = y1, y3
	}
	// Redundant representation 2^28*a + 2^14*b + c, multiplied by -s3.
	lx := x1 / 0x4000
	rx := x1 % 0x4000
	ly := y1 / 0x4000
	ry := y1 % 0x4000
	a := lx * ly
	b := lx*ry + ly*rx
	c := rx * ry
	lx = x2 / 0x4000
	rx = x2 % 0x4000
	ly = y2 / 0x4000
	ry = y2 % 0x4000
	a += lx * ly
	b += lx*ry + ly*rx
	c += rx * ry
	lx = x3 / 0x4000
	rx = x3 % 0x4000
	ly = y3 / 0x4000
	ry = y3 % 0x4000
	a -= lx * ly
	b -= lx*ry + ly*rx
	c -= rx * ry

	ez := false
	if a != 0 {
		if a < 0 {
			a = -a
			b = -b
			c = -c
			s3 = -s3
		}
		for c < 0 {
			a--
			c += 0x10000000
			if a == 0 {
				ez = true
				break
			}
		}
		if !ez {
			if b >= 0 {
				return -s3
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
}

// ---- Vertex coordinate accessors ----

func xCoord(v *graph.Vertex) int64 { i, _ := v.X.(int64); return i }
func yCoord(v *graph.Vertex) int64 { i, _ := v.Y.(int64); return i }
func zCoord(v *graph.Vertex) int64 { i, _ := v.Z.(int64); return i }

// XCoord returns the x coordinate stored in vertex v.
func XCoord(v *graph.Vertex) int64 { return xCoord(v) }

// YCoord returns the y coordinate stored in vertex v.
func YCoord(v *graph.Vertex) int64 { return yCoord(v) }

// ZCoord returns the z coordinate (unique ID) stored in vertex v.
func ZCoord(v *graph.Vertex) int64 { return zCoord(v) }

// ---- Geometric predicates ----

// ccw returns true iff the triple (u, v, w) is in counterclockwise order.
// Ties are broken deterministically using z_coord.
func ccw(u, v, w *graph.Vertex) bool {
	wx := xCoord(w)
	wy := yCoord(w)
	det := (xCoord(u)-wx)*(yCoord(v)-wy) - (yCoord(u)-wy)*(xCoord(v)-wx)
	if det == 0 {
		det = 1
		if zCoord(u) > zCoord(v) {
			u, v = v, u
			det = -det
		}
		if zCoord(v) > zCoord(w) {
			v, w = w, v
			det = -det
		}
		if zCoord(u) > zCoord(v) {
			u, v = v, u
			det = -det
		}
		ux, uy := xCoord(u), yCoord(u)
		vx, vy := xCoord(v), yCoord(v)
		wx2, wy2 := xCoord(w), yCoord(w)
		if ux > vx || (ux == vx && (uy > vy || (uy == vy &&
			(wx2 > ux || (wx2 == ux && wy2 >= uy))))) {
			det = -det
		}
	}
	return det > 0
}

func ffFunc(t, u, v, w *graph.Vertex) int64 {
	wx, wy := xCoord(w), yCoord(w)
	tx, ty := xCoord(t)-wx, yCoord(t)-wy
	ux, uy := xCoord(u)-wx, yCoord(u)-wy
	vx, vy := xCoord(v)-wx, yCoord(v)-wy
	return signTest(ux-tx, vx-ux, tx-vx, vx*vx+vy*vy, tx*tx+ty*ty, ux*ux+uy*uy)
}

func ggFunc(t, u, v, w *graph.Vertex) int64 {
	wx, wy := xCoord(w), yCoord(w)
	tx, ty := xCoord(t)-wx, yCoord(t)-wy
	ux, uy := xCoord(u)-wx, yCoord(u)-wy
	vx, vy := xCoord(v)-wx, yCoord(v)-wy
	return signTest(uy-ty, vy-uy, ty-vy, vx*vx+vy*vy, tx*tx+ty*ty, ux*ux+uy*uy)
}

func hhFunc(t, u, v, w *graph.Vertex) int64 {
	return (xCoord(u) - xCoord(t)) * (yCoord(v) - yCoord(w))
}

func jjFunc(t, u, v, w *graph.Vertex) int64 {
	vx, wy := xCoord(v), yCoord(w)
	udx := xCoord(u) - vx
	udy := yCoord(u) - wy
	tdx := xCoord(t) - vx
	tdy := yCoord(t) - wy
	return udx*udx + udy*udy - tdx*tdx - tdy*tdy
}

// incircle returns true iff t lies outside the circumcircle of (u,v,w),
// assuming ccw(u,v,w). Degeneracies are resolved via a canonical 12-step test.
func incircle(t, u, v, w *graph.Vertex) bool {
	wx, wy := xCoord(w), yCoord(w)
	tx, ty := xCoord(t)-wx, yCoord(t)-wy
	ux, uy := xCoord(u)-wx, yCoord(u)-wy
	vx, vy := xCoord(v)-wx, yCoord(v)-wy
	det := signTest(tx*uy-ty*ux, ux*vy-uy*vx, vx*ty-vy*tx,
		vx*vx+vy*vy, tx*tx+ty*ty, ux*ux+uy*uy)
	if det == 0 {
		det = 1
		if zCoord(t) > zCoord(u) {
			t, u = u, t
			det = -det
		}
		if zCoord(v) > zCoord(w) {
			v, w = w, v
			det = -det
		}
		if zCoord(t) > zCoord(v) {
			t, v = v, t
			det = -det
		}
		if zCoord(u) > zCoord(w) {
			u, w = w, u
			det = -det
		}
		if zCoord(u) > zCoord(v) {
			u, v = v, u
			det = -det
		}
		var dd int64
		if dd = ffFunc(t, u, v, w); dd < 0 ||
			(dd == 0 && func() bool { dd = ggFunc(t, u, v, w); return dd < 0 }()) ||
			(dd == 0 && func() bool { dd = ffFunc(u, t, w, v); return dd < 0 }()) ||
			(dd == 0 && func() bool { dd = ggFunc(u, t, w, v); return dd < 0 }()) ||
			(dd == 0 && func() bool { dd = ffFunc(v, w, t, u); return dd < 0 }()) ||
			(dd == 0 && func() bool { dd = ggFunc(v, w, t, u); return dd < 0 }()) ||
			(dd == 0 && func() bool { dd = hhFunc(t, u, v, w); return dd < 0 }()) ||
			(dd == 0 && func() bool { dd = jjFunc(t, u, v, w); return dd < 0 }()) ||
			(dd == 0 && func() bool { dd = hhFunc(v, t, u, w); return dd < 0 }()) ||
			(dd == 0 && func() bool { dd = jjFunc(v, t, u, w); return dd < 0 }()) ||
			(dd == 0 && jjFunc(t, w, u, v) < 0) {
			det = -det
		}
	}
	return det > 0
}

// ---- Edge flip operation ----

// dlFlip replaces the edge c/d with a new edge, updating arc and node links.
// tpp becomes the new destination of d; p becomes the new destination of c.
func dlFlip(c, d, e *dlArc, tpp, p *graph.Vertex, xp, xpp *dlNode) {
	ep := e.next
	cp := c.next
	cpp := cp.next
	e.next = c
	c.next = cpp
	cpp.next = e
	e.inst = xp
	c.inst = xp
	cpp.inst = xp
	c.vert = p
	d.next = ep
	ep.next = cp
	cp.next = d
	d.inst = xpp
	ep.inst = xpp
	cp.inst = xpp
	d.vert = tpp
}

// ---- Delaunay triangulation ----

// Delaunay computes the Delaunay triangulation of the vertices in g and calls
// f(u, v) for every edge u-v in the triangulation. Either u or v may be nil,
// denoting the vertex at infinity (representing convex hull edges).
//
// The coordinates of each vertex must be stored as int64 in fields X, Y, Z
// (x_coord, y_coord, z_coord), with X and Y in [0, 16383] and Z unique per vertex.
func Delaunay(g *graph.Graph, f func(*graph.Vertex, *graph.Vertex)) {
	if g.N < 2 {
		return
	}
	arcCount := int(6*g.N - 6)
	arcBlock := make([]dlArc, arcCount)
	for i := range arcBlock {
		arcBlock[i].idx = i
	}
	nextArcIdx := 0

	arcAt := func(i int) *dlArc { return &arcBlock[i] }
	arcIdx := func(a *dlArc) int { return a.idx }
	mateOf := func(a *dlArc) *dlArc {
		return arcAt(arcCount - 1 - arcIdx(a))
	}
	termNode := func(p *dlArc) *dlNode {
		return &dlNode{arc: p}
	}

	// Initialize: two "triangles" for vertices 0 and 1, sharing edge with infinity.
	u0 := &g.Vertices[0]
	v0 := &g.Vertices[1]
	rootNode := &dlNode{u: u0, v: v0}

	// Left triangle: u0 → v0 → ∞ (CCW)
	x1 := termNode(arcAt(1))
	rootNode.l = x1
	arcAt(0).vert = v0
	arcAt(0).next = arcAt(1)
	arcAt(0).inst = x1
	arcAt(1).next = arcAt(2) // vert=nil (∞)
	arcAt(1).inst = x1
	arcAt(2).vert = u0
	arcAt(2).next = arcAt(0)
	arcAt(2).inst = x1

	// Right triangle: v0 → u0 → ∞ (CCW), arcs from back of block
	last := arcCount - 1
	x2 := termNode(arcAt(last - 2))
	rootNode.r = x2
	arcAt(last).vert = u0
	arcAt(last).next = arcAt(last - 2)
	arcAt(last).inst = x2
	arcAt(last - 2).next = arcAt(last - 1) // vert=nil (∞)
	arcAt(last - 2).inst = x2
	arcAt(last - 1).vert = v0
	arcAt(last - 1).next = arcAt(last)
	arcAt(last - 1).inst = x2
	nextArcIdx = 3

	// Insert vertices 2..n-1 one at a time.
	for vi := int64(2); vi < g.N; vi++ {
		p := &g.Vertices[vi]

		// Locate the triangle containing p via the search DAG.
		xn := rootNode
		for xn.u != nil {
			if ccw(xn.u, xn.v, p) {
				xn = xn.l
			} else {
				xn = xn.r
			}
		}
		a := xn.arc // arc on boundary of triangle containing p

		// Split the triangle into three triangles around p.
		b := a.next
		c := b.next
		q := a.vert
		r := b.vert
		s := c.vert

		yp := termNode(a)
		nai := nextArcIdx
		ypp := termNode(arcAt(nai))
		y := termNode(c)
		c.inst = y
		a.inst = yp
		b.inst = ypp

		ei := arcCount - 1 - nai // index of e = mate(next_arc)
		a.next = arcAt(ei)
		b.next = arcAt(ei - 1)
		c.next = arcAt(ei - 2)

		arcAt(nai).vert = q
		arcAt(nai).next = b
		arcAt(nai).inst = ypp
		arcAt(nai + 1).vert = r
		arcAt(nai + 1).next = c
		arcAt(nai + 1).inst = y
		arcAt(nai + 2).vert = s
		arcAt(nai + 2).next = a
		arcAt(nai + 2).inst = yp

		arcAt(ei).vert = p
		arcAt(ei - 1).vert = p
		arcAt(ei - 2).vert = p
		arcAt(ei).next = arcAt(nai + 2)
		arcAt(ei - 1).next = arcAt(nai)
		arcAt(ei - 2).next = arcAt(nai + 1)
		arcAt(ei).inst = yp
		arcAt(ei - 1).inst = ypp
		arcAt(ei - 2).inst = y
		nextArcIdx += 3

		if q == nil {
			// Convex hull update: p is outside the current hull edge (a.vert was ∞).
			xp := &dlNode{u: s, v: p, l: y, r: yp}
			xn.u = r
			xn.v = p
			xn.l = ypp
			xn.r = xp
			aa := mateOf(a)
			d := aa.next
			t := d.vert
			for t != r && ccw(p, s, t) {
				xpp := termNode(d)
				xp.r = d.inst
				xp = d.inst
				xp.u = t
				xp.v = p
				xp.l = xpp
				xp.r = yp
				dlFlip(a, aa, d, t, p, xpp, yp)
				a = aa.next
				aa = mateOf(a)
				d = aa.next
				s = t
				t = d.vert
				yp.arc = a
			}
			xpTerm := termNode(d.next)
			xn2 := d.inst
			xn2.u = s
			xn2.v = p
			xn2.l = xpTerm
			xn2.r = yp
			d.inst = xpTerm
			d.next.inst = xpTerm
			d.next.next.inst = xpTerm
			r = s
		} else {
			// Regular subdivision: upgrade the terminal node to a branch node.
			xppNode := &dlNode{u: q, v: p, l: yp, r: ypp}
			xpNode := &dlNode{u: s, v: p, l: y, r: yp}
			xn.u = r
			xn.v = p
			xn.l = xppNode
			xn.r = xpNode
		}

		// Walk around p, flipping edges that violate the Delaunay condition.
		for {
			d := mateOf(c)
			e := d.next
			tp := c.vert
			tpp := e.vert
			if tpp != nil && incircle(tpp, tp, d.vert, p) {
				xp := termNode(e)
				xpp := termNode(d)
				ci := c.inst
				ci.u = tpp
				ci.v = p
				ci.l = xp
				ci.r = xpp
				di := d.inst
				di.u = tpp
				di.v = p
				di.l = xp
				di.r = xpp
				dlFlip(c, d, e, tpp, p, xp, xpp)
				c = e
			} else if tp == r {
				break
			} else {
				aa := mateOf(c.next)
				c = aa.next
			}
		}
	}

	// Emit each Delaunay edge by iterating over mate pairs in arc block.
	for i := 0; i < nextArcIdx; i++ {
		f(arcBlock[i].vert, arcBlock[arcCount-1-i].vert)
	}
}

// ---- Plane ----

// Plane constructs a planar graph with n vertices uniformly distributed in
// [0,xRange) × [0,yRange), connected by their Delaunay triangulation.
// Each edge is retained with probability 1 - prob/65536. If extend is true,
// an extra vertex representing infinity is included, connected by INFTY-length
// edges to all convex hull vertices. UtilTypes = "ZZZIIIZZZZZZZZ".
func Plane(n, xRange, yRange int64, extend bool, prob, seed int64) (*graph.Graph, error) {
	rng := flip.New(seed)
	if xRange > 16384 || yRange > 16384 {
		return nil, graph.ErrBadSpecs
	}
	if n < 2 {
		return nil, graph.ErrVeryBadSpecs
	}
	if xRange == 0 {
		xRange = 16384
	}
	if yRange == 0 {
		yRange = 16384
	}

	g := graph.NewGraph(n)
	g.ID = fmt.Sprintf("plane(%d,%d,%d,%d,%d,%d)", n, xRange, yRange, boolInt(extend), prob, seed)
	g.UtilTypes = "ZZZIIIZZZZZZZZ"

	for k := int64(0); k < n; k++ {
		v := &g.Vertices[k]
		v.X = rng.Unif(xRange)
		v.Y = rng.Unif(yRange)
		v.Z = (rng.Next()/n)*n + k
		v.Name = fmt.Sprintf("%d", k)
	}

	var infVertex *graph.Vertex
	if extend {
		infVertex = &g.Vertices[n]
		infVertex.Name = "INF"
		infVertex.X = int64(-1)
		infVertex.Y = int64(-1)
		infVertex.Z = int64(-1)
	}

	Delaunay(g, func(u, v *graph.Vertex) {
		if rng.Next()>>15 >= prob {
			if u != nil {
				if v != nil {
					dx := xCoord(u) - xCoord(v)
					dy := yCoord(u) - yCoord(v)
					g.NewEdge(u, v, intSqrt(dx*dx+dy*dy))
				} else if infVertex != nil {
					g.NewEdge(u, infVertex, Infty)
				}
			} else if infVertex != nil {
				g.NewEdge(infVertex, v, Infty)
			}
		}
	})

	if extend {
		g.N++
	}
	return g, nil
}

// ---- PlaneMiles ----

// PlaneMiles constructs a planar graph using the Delaunay triangulation of
// up to n cities from miles.dat. Vertices and coordinates are the same as
// those produced by miles.Miles with max_distance=1 (no edges). Edge lengths
// are highway distances in miles. UtilTypes = "ZZZIIIZZZZZZZZ".
func PlaneMiles(n, northWeight, westWeight, popWeight int64, extend bool, prob, seed int64) (*graph.Graph, error) {
	if n == 0 || n > miles.MaxN {
		n = miles.MaxN
	}
	g, dm, err := miles.Miles(n, northWeight, westWeight, popWeight, 1, 0, seed)
	if err != nil {
		return nil, err
	}
	rng := flip.New(seed)
	g.ID = fmt.Sprintf("plane_miles(%d,%d,%d,%d,%d,%d,%d)",
		n, northWeight, westWeight, popWeight, boolInt(extend), prob, seed)
	g.UtilTypes = "ZZZIIIZZZZZZZZ"

	var infVertex *graph.Vertex
	if extend {
		infVertex = &g.Vertices[g.N]
		infVertex.Name = "INF"
		infVertex.X = int64(-1)
		infVertex.Y = int64(-1)
		infVertex.Z = int64(-1)
	}

	Delaunay(g, func(u, v *graph.Vertex) {
		if rng.Next()>>15 >= prob {
			if u != nil {
				if v != nil {
					g.NewEdge(u, v, -dm.Distance(u, v))
				} else if infVertex != nil {
					g.NewEdge(u, infVertex, Infty)
				}
			} else if infVertex != nil {
				g.NewEdge(infVertex, v, Infty)
			}
		}
	})

	if extend {
		g.N++
	}
	return g, nil
}

// boolInt renders a flag as 0 or 1, matching the C-style ID strings of SGB.
func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
