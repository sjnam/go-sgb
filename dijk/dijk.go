// Package dijk implements GB_DIJK from Stanford GraphBase.
//
// Dijkstra finds a shortest path from vertex uu to vertex vv in graph gg,
// optionally guided by a heuristic function hh.  PrintDijkstraResult prints
// the path found.
//
// Vertex utility fields used internally:
//
//	Z = dist     (int64: modified distance from uu)
//	Y = backlink (*Vertex: previous vertex on shortest path, non-nil ↔ seen)
//	X = hh_val   (int64: cached value of hh(v))
//	V = llink    (*Vertex: left/larger neighbour in priority queue)
//	W = rlink    (*Vertex: right/smaller neighbour in priority queue)
package dijk

import (
	"fmt"

	"github.com/sjnam/go-sgb/graph"
)

// ---- Vertex utility-field accessors ----

func Dist(v *graph.Vertex) int64             { i, _ := v.Z.(int64); return i }
func Backlink(v *graph.Vertex) *graph.Vertex { p, _ := v.Y.(*graph.Vertex); return p }
func HhVal(v *graph.Vertex) int64            { i, _ := v.X.(int64); return i }
func Llink(v *graph.Vertex) *graph.Vertex    { p, _ := v.V.(*graph.Vertex); return p }
func Rlink(v *graph.Vertex) *graph.Vertex    { p, _ := v.W.(*graph.Vertex); return p }

func setDist(v *graph.Vertex, d int64)  { v.Z = d }
func setBacklink(v, u *graph.Vertex)    { v.Y = u }
func setHhVal(v *graph.Vertex, h int64) { v.X = h }
func setLlink(v, u *graph.Vertex)       { v.V = u }
func setRlink(v, u *graph.Vertex)       { v.W = u }

// ---- Priority queue interface ----

// Queue is the priority-queue interface used by Dijkstra.
// Two implementations are provided: NewDlistQueue (default) and NewWheelQueue.
type Queue interface {
	Init(d int64)
	Enqueue(v *graph.Vertex, d int64)
	Requeue(v *graph.Vertex, d int64)
	DelMin() *graph.Vertex
}

// ---- Dlist queue (doubly-linked list sorted by dist) ----

type dlistQueue struct {
	head graph.Vertex // sentinel node
}

// NewDlistQueue returns a doubly-linked list priority queue.
// It works for any arc lengths and is the default used by Dijkstra.
func NewDlistQueue() Queue { return &dlistQueue{} }

func (q *dlistQueue) Init(d int64) {
	setLlink(&q.head, &q.head)
	setRlink(&q.head, &q.head)
	setDist(&q.head, d-1) // sentinel: smaller than any real key
}

// Enqueue inserts v with key d. New elements tend to land near the end
// (large side) so we scan from there.
func (q *dlistQueue) Enqueue(v *graph.Vertex, d int64) {
	t := Llink(&q.head) // start at the largest element
	setDist(v, d)
	for d < Dist(t) {
		t = Llink(t)
	}
	setLlink(v, t)
	r := Rlink(t)
	setRlink(v, r)
	setLlink(r, v)
	setRlink(t, v)
}

// Requeue moves v to a new (smaller) key d.
func (q *dlistQueue) Requeue(v *graph.Vertex, d int64) {
	t := Llink(v)
	r := Rlink(v)
	setRlink(t, r)
	setLlink(r, t)
	setDist(v, d)
	for d < Dist(t) {
		t = Llink(t)
	}
	setLlink(v, t)
	r = Rlink(t)
	setRlink(v, r)
	setLlink(r, v)
	setRlink(t, v)
}

// DelMin removes and returns the vertex with the smallest key, or nil if empty.
func (q *dlistQueue) DelMin() *graph.Vertex {
	t := Rlink(&q.head)
	if t == &q.head {
		return nil
	}
	r := Rlink(t)
	setRlink(&q.head, r)
	setLlink(r, &q.head)
	return t
}

// ---- Wheel queue (128-bucket circular wheel) ----

type wheelQueue struct {
	head      [128]graph.Vertex
	masterKey int64
}

// NewWheelQueue returns a 128-bucket wheel priority queue.
// It is more efficient than the dlist when all arc lengths are < 128.
func NewWheelQueue() Queue { return &wheelQueue{} }

func (q *wheelQueue) Init(d int64) {
	q.masterKey = d
	for i := range q.head {
		setLlink(&q.head[i], &q.head[i])
		setRlink(&q.head[i], &q.head[i])
	}
}

func (q *wheelQueue) Enqueue(v *graph.Vertex, d int64) {
	u := &q.head[d&0x7f]
	setDist(v, d)
	l := Llink(u)
	setLlink(v, l)
	setRlink(l, v)
	setRlink(v, u)
	setLlink(u, v)
}

func (q *wheelQueue) Requeue(v *graph.Vertex, d int64) {
	l := Llink(v)
	r := Rlink(v)
	setRlink(l, r)
	setLlink(r, l)
	u := &q.head[d&0x7f]
	setDist(v, d)
	l = Llink(u)
	setLlink(v, l)
	setRlink(l, v)
	setRlink(v, u)
	setLlink(u, v)
	if d < q.masterKey {
		q.masterKey = d
	}
}

func (q *wheelQueue) DelMin() *graph.Vertex {
	for d := q.masterKey; d < q.masterKey+128; d++ {
		u := &q.head[d&0x7f]
		t := Rlink(u)
		if t != u {
			q.masterKey = d
			r := Rlink(t)
			setRlink(u, r)
			setLlink(r, u)
			return t
		}
	}
	return nil
}

// ---- Dijkstra's algorithm ----

// Dijkstra finds a shortest path from uu to vv in graph gg.
//
// hh is an optional heuristic: a function satisfying d(u,v) >= hh(u)-hh(v)
// for every arc of length d.  If nil, the zero heuristic is used (plain Dijkstra).
//
// q selects the priority queue implementation; pass nil to use the default
// doubly-linked list queue.  Pass NewWheelQueue() when all arc lengths are < 128.
//
// Returns the length of the shortest path, or -1 if vv is unreachable.
// After returning, v.Z (Dist) holds the shortest modified distance for every
// vertex v reachable from uu; the true distance is Dist(v) - HhVal(v) + HhVal(uu).
// Backlink(v) (v.Y) holds the previous vertex on the shortest path tree.
func Dijkstra(uu, vv *graph.Vertex, gg *graph.Graph, hh func(*graph.Vertex) int64, q Queue, verbose bool) int64 {
	if q == nil {
		q = NewDlistQueue()
	}
	if hh == nil {
		hh = func(*graph.Vertex) int64 { return 0 }
	}

	// Initialise: clear all backlinks.
	for i := int64(0); i < gg.N; i++ {
		setBacklink(&gg.Vertices[i], nil)
	}
	setBacklink(uu, uu)
	setDist(uu, 0)
	setHhVal(uu, hh(uu))
	q.Init(0)

	if verbose {
		fmt.Printf("Distances from %s [%d]:\n", uu.Name, HhVal(uu))
	}

	t := uu
	for t != vv {
		// Relax all arcs from t.
		d := Dist(t) - HhVal(t)
		for a := t.Arcs; a != nil; a = a.Next {
			v := a.Tip
			dd := d + a.Len + hh(v)
			if Backlink(v) != nil {
				// v has been seen; possibly improve.
				if dd < Dist(v) {
					setBacklink(v, t)
					setHhVal(v, hh(v))
					q.Requeue(v, dd)
				}
			} else {
				// v is newly seen.
				setHhVal(v, hh(v))
				setBacklink(v, t)
				q.Enqueue(v, dd)
			}
		}
		t = q.DelMin()
		if t == nil {
			return -1 // vv unreachable
		}
		if verbose {
			fmt.Printf(" %d to %s via %s\n",
				Dist(t)-HhVal(t)+HhVal(uu), t.Name, Backlink(t).Name)
		}
	}
	return Dist(vv) - HhVal(vv) + HhVal(uu)
}

// PrintDijkstraResult prints the shortest path to vv found by the most recent
// Dijkstra call.  If vv is unreachable it prints a sorry message.
// The backlinks are temporarily reversed to print in forward order, then restored.
func PrintDijkstraResult(vv *graph.Vertex) {
	p := vv
	if Backlink(p) == nil {
		fmt.Printf("Sorry, %s is unreachable.\n", p.Name)
		return
	}

	// Reverse the backlink chain from vv back to uu.
	var t *graph.Vertex
	for {
		q := Backlink(p)
		setBacklink(p, t)
		t = p
		p = q
		if t == p { // reached uu (whose backlink points to itself)
			break
		}
	}
	// Now t = uu, backlinks form a forward chain.
	uu := t
	for t != nil {
		fmt.Printf("%10d %s\n", Dist(t)-HhVal(t)+HhVal(uu), t.Name)
		t = Backlink(t)
	}

	// Restore the backlinks (reverse the forward chain back to backlinks).
	t = uu
	for {
		q := Backlink(t)
		setBacklink(t, p)
		p = t
		t = q
		if p == vv {
			break
		}
	}
}
