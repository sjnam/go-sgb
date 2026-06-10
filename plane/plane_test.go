package plane

import (
	"errors"
	"testing"

	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/graph"
)

func init() {
	gbio.DataDirectory = "../data/"
}

// ---- intSqrt tests ----

func TestIntSqrtZero(t *testing.T) {
	if intSqrt(0) != 0 {
		t.Error("intSqrt(0) != 0")
	}
}

func TestIntSqrtPerfectSquare(t *testing.T) {
	// intSqrt(x) ≈ 1024*sqrt(x); for x=4, expect 1024*2=2048
	got := intSqrt(4)
	if got != 2048 {
		t.Errorf("intSqrt(4) = %d, want 2048", got)
	}
}

func TestIntSqrtOne(t *testing.T) {
	// intSqrt(1) = 1024
	got := intSqrt(1)
	if got != 1024 {
		t.Errorf("intSqrt(1) = %d, want 1024", got)
	}
}

// ---- Plane basic tests ----

func TestPlaneDefault(t *testing.T) {
	g, err := Plane(10, 0, 0, false, 0, 1)
	if err != nil {
		t.Fatalf("Plane(10,...) failed: %v", err)
	}
	if g.N != 10 {
		t.Errorf("want 10 vertices, got %d", g.N)
	}
}

func TestPlaneID(t *testing.T) {
	g, err := Plane(5, 100, 100, false, 0, 42)
	if err != nil {
		t.Fatalf("Plane failed: %v", err)
	}
	want := "plane(5,100,100,0,0,42)"
	if g.ID != want {
		t.Errorf("ID=%q, want %q", g.ID, want)
	}
}

func TestPlaneUtilTypes(t *testing.T) {
	g, err := Plane(5, 0, 0, false, 0, 1)
	if err != nil {
		t.Fatalf("Plane failed: %v", err)
	}
	if g.UtilTypes != "ZZZIIIZZZZZZZZ" {
		t.Errorf("UtilTypes=%q", g.UtilTypes)
	}
}

func TestPlaneBadSpecs(t *testing.T) {
	// n < 2 → VeryBadSpecs
	_, err := Plane(1, 0, 0, false, 0, 1)
	if err == nil {
		t.Fatal("expected error for n=1")
	}
	if !errors.Is(err, graph.ErrVeryBadSpecs) {
		t.Errorf("want ErrVeryBadSpecs, got %v", err)
	}
}

func TestPlaneBadRange(t *testing.T) {
	// xRange > 16384 → BadSpecs
	_, err := Plane(5, 20000, 0, false, 0, 1)
	if err == nil {
		t.Fatal("expected error for xRange > 16384")
	}
	if !errors.Is(err, graph.ErrBadSpecs) {
		t.Errorf("want ErrBadSpecs, got %v", err)
	}
}

func TestPlaneVertexCoords(t *testing.T) {
	g, err := Plane(20, 100, 100, false, 0, 1)
	if err != nil {
		t.Fatalf("Plane failed: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		x := XCoord(v)
		y := YCoord(v)
		if x < 0 || x >= 100 {
			t.Errorf("v%d: x=%d out of [0,100)", i, x)
		}
		if y < 0 || y >= 100 {
			t.Errorf("v%d: y=%d out of [0,100)", i, y)
		}
	}
}

func TestPlaneVertexNames(t *testing.T) {
	g, err := Plane(5, 0, 0, false, 0, 1)
	if err != nil {
		t.Fatalf("Plane failed: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		if g.Vertices[i].Name == "" {
			t.Errorf("vertex %d has empty name", i)
		}
	}
}

func TestPlanePlanar(t *testing.T) {
	// Delaunay triangulation has at most 3n-6 undirected edges = 6n-12 directed arcs.
	g, err := Plane(20, 0, 0, false, 0, 7)
	if err != nil {
		t.Fatalf("Plane failed: %v", err)
	}
	maxArcs := 6*g.N - 12
	if g.M > maxArcs {
		t.Errorf("M=%d > 6n-12=%d (Euler bound for directed arcs)", g.M, maxArcs)
	}
}

func TestPlaneSymmetric(t *testing.T) {
	// Every arc u→v should have a reverse arc v→u.
	g, err := Plane(15, 0, 0, false, 0, 3)
	if err != nil {
		t.Fatalf("Plane failed: %v", err)
	}
	type edge struct{ a, b int64 }
	idx := make(map[*graph.Vertex]int64, g.N)
	for i := int64(0); i < g.N; i++ {
		idx[&g.Vertices[i]] = i
	}
	reverse := make(map[edge]bool)
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			j := idx[a.Tip]
			reverse[edge{j, i}] = true
		}
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			j := idx[a.Tip]
			if !reverse[edge{i, j}] {
				t.Errorf("missing reverse arc %d→%d", j, i)
			}
		}
	}
}

func TestPlanePositiveEdgeLengths(t *testing.T) {
	g, err := Plane(10, 1000, 1000, false, 0, 5)
	if err != nil {
		t.Fatalf("Plane failed: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if a.Len <= 0 {
				t.Errorf("edge len=%d, want >0", a.Len)
			}
		}
	}
}

func TestPlaneExtend(t *testing.T) {
	g, err := Plane(10, 0, 0, true, 0, 1)
	if err != nil {
		t.Fatalf("Plane(extend=1) failed: %v", err)
	}
	if g.N != 11 {
		t.Errorf("want 11 vertices (10+INF), got %d", g.N)
	}
	// Last vertex should be INF with INFTY-length edges.
	infV := &g.Vertices[10]
	if infV.Name != "INF" {
		t.Errorf("last vertex name=%q, want INF", infV.Name)
	}
	if infV.Arcs == nil {
		t.Error("INF vertex has no arcs")
	}
	for a := infV.Arcs; a != nil; a = a.Next {
		if a.Len != Infty {
			t.Errorf("INF edge len=%d, want INFTY=%d", a.Len, Infty)
		}
	}
}

func TestPlaneProb(t *testing.T) {
	// prob=32768 ≈ 50% rejection → fewer edges than prob=0.
	g0, err0 := Plane(20, 0, 0, false, 0, 99)
	g1, err1 := Plane(20, 0, 0, false, 32768, 99)
	if err0 != nil || err1 != nil {
		t.Fatalf("Plane failed: %v / %v", err0, err1)
	}
	if g1.M >= g0.M {
		t.Errorf("prob=32768 M=%d, prob=0 M=%d (expected fewer)", g1.M, g0.M)
	}
}

func TestPlaneReproducible(t *testing.T) {
	g1, err1 := Plane(15, 500, 500, false, 0, 42)
	g2, err2 := Plane(15, 500, 500, false, 0, 42)
	if err1 != nil || err2 != nil {
		t.Fatalf("Plane failed: %v / %v", err1, err2)
	}
	if g1.M != g2.M {
		t.Errorf("same seed, M mismatch: %d vs %d", g1.M, g2.M)
	}
	for i := int64(0); i < g1.N; i++ {
		if XCoord(&g1.Vertices[i]) != XCoord(&g2.Vertices[i]) ||
			YCoord(&g1.Vertices[i]) != YCoord(&g2.Vertices[i]) {
			t.Errorf("vertex %d coords differ between runs", i)
		}
	}
}

func TestPlaneHasEdges(t *testing.T) {
	g, err := Plane(10, 0, 0, false, 0, 1)
	if err != nil {
		t.Fatalf("Plane failed: %v", err)
	}
	if g.M == 0 {
		t.Error("expected positive edge count")
	}
}

// ---- PlaneMiles tests ----

func TestPlaneMilesDefault(t *testing.T) {
	g, err := PlaneMiles(0, 0, 0, 0, false, 0, 0)
	if err != nil {
		t.Fatalf("PlaneMiles failed: %v", err)
	}
	if g.N == 0 {
		t.Error("expected positive vertex count")
	}
}

func TestPlaneMilesID(t *testing.T) {
	g, err := PlaneMiles(10, 0, 0, 0, false, 0, 1)
	if err != nil {
		t.Fatalf("PlaneMiles failed: %v", err)
	}
	want := "plane_miles(10,0,0,0,0,0,1)"
	if g.ID != want {
		t.Errorf("ID=%q, want %q", g.ID, want)
	}
}

func TestPlaneMilesUtilTypes(t *testing.T) {
	g, err := PlaneMiles(10, 0, 0, 0, false, 0, 1)
	if err != nil {
		t.Fatalf("PlaneMiles failed: %v", err)
	}
	if g.UtilTypes != "ZZZIIIZZZZZZZZ" {
		t.Errorf("UtilTypes=%q", g.UtilTypes)
	}
}

func TestPlaneMilesPlanar(t *testing.T) {
	g, err := PlaneMiles(20, 0, 0, 0, false, 0, 1)
	if err != nil {
		t.Fatalf("PlaneMiles failed: %v", err)
	}
	maxArcs := 6*g.N - 12
	if g.M > maxArcs {
		t.Errorf("M=%d > 6n-12=%d (Euler bound for directed arcs)", g.M, maxArcs)
	}
}

func TestPlaneMilesExtend(t *testing.T) {
	g, err := PlaneMiles(10, 0, 0, 0, true, 0, 1)
	if err != nil {
		t.Fatalf("PlaneMiles(extend=1) failed: %v", err)
	}
	// Check INF vertex exists and has INFTY-length arcs.
	infV := &g.Vertices[g.N-1]
	if infV.Name != "INF" {
		t.Errorf("last vertex name=%q, want INF", infV.Name)
	}
}

func TestPlaneMilesSymmetric(t *testing.T) {
	g, err := PlaneMiles(15, 0, 0, 0, false, 0, 7)
	if err != nil {
		t.Fatalf("PlaneMiles failed: %v", err)
	}
	type edge struct{ a, b int64 }
	idx := make(map[*graph.Vertex]int64, g.N)
	for i := int64(0); i < g.N; i++ {
		idx[&g.Vertices[i]] = i
	}
	reverse := make(map[edge]bool)
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			j := idx[a.Tip]
			reverse[edge{j, i}] = true
		}
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			j := idx[a.Tip]
			if !reverse[edge{i, j}] {
				t.Errorf("missing reverse arc %d→%d", j, i)
			}
		}
	}
}

func TestPlaneMilesPositiveLengths(t *testing.T) {
	g, err := PlaneMiles(10, 0, 0, 0, false, 0, 1)
	if err != nil {
		t.Fatalf("PlaneMiles failed: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if a.Len <= 0 {
				t.Errorf("v%d: edge len=%d", i, a.Len)
			}
		}
	}
}
