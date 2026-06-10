package dijk

import (
	"testing"

	"github.com/sjnam/go-sgb/graph"
	"github.com/sjnam/go-sgb/io"
	"github.com/sjnam/go-sgb/miles"
)

func init() {
	io.DataDirectory = "../data/"
}

// smallGraph builds a hand-crafted directed graph for unit tests:
//
//	A -1→ B -2→ C
//	A -5→ C
//	B -4→ D
//	C -1→ D
//
// Shortest A→D = A→B(1)→C(2)→D(1) = 4.
func smallGraph() *graph.Graph {
	g := graph.NewGraph(4)
	a, b, c, d := &g.Vertices[0], &g.Vertices[1], &g.Vertices[2], &g.Vertices[3]
	a.Name, b.Name, c.Name, d.Name = "A", "B", "C", "D"
	g.NewArc(a, b, 1)
	g.NewArc(b, c, 2)
	g.NewArc(a, c, 5)
	g.NewArc(b, d, 4)
	g.NewArc(c, d, 1)
	return g
}

func TestDijkstraBasic(t *testing.T) {
	g := smallGraph()
	a, d := &g.Vertices[0], &g.Vertices[3]
	dist := Dijkstra(a, d, g, nil, nil, false)
	if dist != 4 {
		t.Errorf("A→D: want 4, got %d", dist)
	}
}

func TestDijkstraBacklinks(t *testing.T) {
	g := smallGraph()
	a, d := &g.Vertices[0], &g.Vertices[3]
	Dijkstra(a, d, g, nil, nil, false)

	// Expected path: A→B→C→D
	path := []string{}
	for v := d; v != nil; v = Backlink(v) {
		path = append([]string{v.Name}, path...)
		if v == a {
			break
		}
	}
	want := []string{"A", "B", "C", "D"}
	if len(path) != len(want) {
		t.Fatalf("path length %d, want %d: %v", len(path), len(want), path)
	}
	for i, s := range want {
		if path[i] != s {
			t.Errorf("path[%d]=%q, want %q", i, path[i], s)
		}
	}
}

func TestDijkstraUnreachable(t *testing.T) {
	g := smallGraph()
	b, a := &g.Vertices[1], &g.Vertices[0] // no arc B→A
	dist := Dijkstra(b, a, g, nil, nil, false)
	if dist != -1 {
		t.Errorf("B→A: want -1 (unreachable), got %d", dist)
	}
}

func TestDijkstraSelfLoop(t *testing.T) {
	g := smallGraph()
	a := &g.Vertices[0]
	dist := Dijkstra(a, a, g, nil, nil, false)
	if dist != 0 {
		t.Errorf("A→A: want 0, got %d", dist)
	}
}

func TestDijkstraHeuristic(t *testing.T) {
	g := smallGraph()
	a, d := &g.Vertices[0], &g.Vertices[3]
	// Use a trivial admissible heuristic: always 0 except target = 0.
	hh := func(v *graph.Vertex) int64 {
		if v == d {
			return 0
		}
		return 0
	}
	dist := Dijkstra(a, d, g, hh, nil, false)
	if dist != 4 {
		t.Errorf("A→D with heuristic: want 4, got %d", dist)
	}
}

func TestDijkstra128Queue(t *testing.T) {
	// Use the 128-bucket wheel (valid since all arc lengths ≤ 5 < 128).
	g := smallGraph()
	a, d := &g.Vertices[0], &g.Vertices[3]
	dist := Dijkstra(a, d, g, nil, NewWheelQueue(), false)
	if dist != 4 {
		t.Errorf("128-queue A→D: want 4, got %d", dist)
	}
}

func TestDijkstraMilesShortPath(t *testing.T) {
	g, err := miles.Miles(128, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("miles.Miles returned error: %v", err)
	}
	if g == nil {
		t.Fatal("miles.Miles returned nil")
	}
	// Run from vertex 0 to vertex 127 (arbitrary endpoints).
	uu := &g.Vertices[0]
	vv := &g.Vertices[127]
	dist := Dijkstra(uu, vv, g, nil, nil, false)
	if dist <= 0 {
		t.Errorf("miles Dijkstra: want positive distance, got %d", dist)
	}
	// Verify the result using the backlink chain.
	total := int64(0)
	v := vv
	for Backlink(v) != uu {
		prev := Backlink(v)
		// Find arc from prev to v.
		found := false
		for a := prev.Arcs; a != nil; a = a.Next {
			if a.Tip == v {
				total += a.Len
				found = true
				break
			}
		}
		if !found {
			t.Fatalf("no arc from %s to %s on backlink path", prev.Name, v.Name)
		}
		v = prev
	}
	// Add the first arc (uu → v).
	for a := uu.Arcs; a != nil; a = a.Next {
		if a.Tip == v {
			total += a.Len
			break
		}
	}
	if total != dist {
		t.Errorf("backlink path total=%d, Dijkstra returned %d", total, dist)
	}
}

func TestDijkstraMilesHeuristic(t *testing.T) {
	// With a consistent heuristic based on x-coord distance,
	// result should match plain Dijkstra.
	g, err := miles.Miles(128, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("miles.Miles returned error: %v", err)
	}
	if g == nil {
		t.Fatal("miles.Miles returned nil")
	}
	uu, vv := &g.Vertices[0], &g.Vertices[127]

	plain := Dijkstra(uu, vv, g, nil, nil, false)

	// Admissible heuristic: 0 for all vertices.
	withHH := Dijkstra(uu, vv, g, func(v *graph.Vertex) int64 { return 0 }, nil, false)
	if plain != withHH {
		t.Errorf("heuristic=0 should match plain: plain=%d, hh=%d", plain, withHH)
	}
}

func TestPrintDijkstraResult(t *testing.T) {
	g := smallGraph()
	a, d := &g.Vertices[0], &g.Vertices[3]
	Dijkstra(a, d, g, nil, nil, false)
	// Just check it doesn't panic; output goes to stdout.
	PrintDijkstraResult(d)
}

func TestPrintDijkstraUnreachable(t *testing.T) {
	g := smallGraph()
	b, a := &g.Vertices[1], &g.Vertices[0]
	Dijkstra(b, a, g, nil, nil, false) // returns -1
	PrintDijkstraResult(a)             // should print "unreachable"
}

func TestDijkstraDistFields(t *testing.T) {
	// After Dijkstra from A, dist(B)=1, dist(C)=3, dist(D)=4.
	g := smallGraph()
	a, d := &g.Vertices[0], &g.Vertices[3]
	b, c := &g.Vertices[1], &g.Vertices[2]
	Dijkstra(a, d, g, nil, nil, false)
	if Dist(b) != 1 {
		t.Errorf("dist(B)=%d, want 1", Dist(b))
	}
	if Dist(c) != 3 {
		t.Errorf("dist(C)=%d, want 3", Dist(c))
	}
	if Dist(d) != 4 {
		t.Errorf("dist(D)=%d, want 4", Dist(d))
	}
}
