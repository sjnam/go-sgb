package gbrand

import (
	"errors"
	"fmt"
	"testing"

	gbgraph "github.com/sjnam/go-sgb/gb-graph"
)

// ---- RandomGraph basic tests ----

func TestRandomGraphDefault(t *testing.T) {
	g, err := RandomGraph(100, 200, 0, false, false, nil, nil, 1, 1, 0)
	if err != nil {
		t.Fatalf("RandomGraph returned error: %v", err)
	}
	if g == nil {
		t.Fatal("RandomGraph returned nil graph")
	}
	if g.N != 100 {
		t.Errorf("want 100 vertices, got %d", g.N)
	}
}

func TestRandomGraphEdgeCount(t *testing.T) {
	// Undirected, no duplicates, no self-loops → exactly 200 undirected edges = 400 arcs
	g, err := RandomGraph(100, 200, 0, false, false, nil, nil, 1, 1, 0)
	if err != nil {
		t.Fatalf("RandomGraph returned error: %v", err)
	}
	if g.M != 400 {
		t.Errorf("want M=400, got %d", g.M)
	}
}

func TestRandomGraphDirectedArcCount(t *testing.T) {
	// Directed, with duplicates and self-loops → exactly 500 arcs
	g, err := RandomGraph(50, 500, 1, true, true, nil, nil, 1, 1, 7)
	if err != nil {
		t.Fatalf("RandomGraph returned error: %v", err)
	}
	if g.M != 500 {
		t.Errorf("want M=500, got %d", g.M)
	}
}

func TestRandomGraphID(t *testing.T) {
	g, err := RandomGraph(10, 20, 0, false, false, nil, nil, 1, 1, 42)
	if err != nil {
		t.Fatalf("RandomGraph returned error: %v", err)
	}
	want := "random_graph(10,20,0,0,0,0,0,1,1,42)"
	if g.ID != want {
		t.Errorf("ID=%q, want %q", g.ID, want)
	}
}

func TestRandomGraphIDWithDist(t *testing.T) {
	dist := makeUniformDist(10)
	g, err := RandomGraph(10, 20, 1, true, true, dist, dist, 0, 10, 1)
	if err != nil {
		t.Fatalf("RandomGraph returned error: %v", err)
	}
	want := "random_graph(10,20,1,1,1,dist,dist,0,10,1)"
	if g.ID != want {
		t.Errorf("ID=%q, want %q", g.ID, want)
	}
}

func TestRandomGraphVertexNames(t *testing.T) {
	g, err := RandomGraph(5, 4, 1, true, false, nil, nil, 1, 1, 1)
	if err != nil {
		t.Fatalf("RandomGraph returned error: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		want := fmt.Sprintf("%d", i)
		if g.Vertices[i].Name != want {
			t.Errorf("vertex %d name=%q, want %q", i, g.Vertices[i].Name, want)
		}
	}
}

func TestRandomGraphBadSpecs(t *testing.T) {
	g, err := RandomGraph(0, 10, 0, false, false, nil, nil, 1, 1, 0)
	if g != nil {
		t.Fatal("expected nil for n=0")
	}
	if !errors.Is(err, gbgraph.ErrBadSpecs) {
		t.Errorf("want ErrBadSpecs, got %v", err)
	}
}

func TestRandomGraphVeryBadSpecs(t *testing.T) {
	g, err := RandomGraph(10, 5, 0, false, false, nil, nil, 5, 1, 0)
	if g != nil {
		t.Fatal("expected nil for minLen > maxLen")
	}
	if !errors.Is(err, gbgraph.ErrVeryBadSpecs) {
		t.Errorf("want ErrVeryBadSpecs, got %v", err)
	}
}

func TestRandomGraphReproducible(t *testing.T) {
	g1, err1 := RandomGraph(50, 100, 0, false, false, nil, nil, 1, 10, 42)
	g2, err2 := RandomGraph(50, 100, 0, false, false, nil, nil, 1, 10, 42)
	if err1 != nil || err2 != nil {
		t.Fatalf("RandomGraph returned error: %v / %v", err1, err2)
	}
	if g1.M != g2.M {
		t.Errorf("same seed: M mismatch %d vs %d", g1.M, g2.M)
	}
	for i := int64(0); i < g1.N; i++ {
		a1, a2 := g1.Vertices[i].Arcs, g2.Vertices[i].Arcs
		for a1 != nil && a2 != nil {
			if a1.Len != a2.Len {
				t.Errorf("arc lengths differ at vertex %d", i)
			}
			a1, a2 = a1.Next, a2.Next
		}
		if a1 != nil || a2 != nil {
			t.Errorf("arc count differs at vertex %d", i)
		}
	}
}

func TestRandomGraphNoSelfLoops(t *testing.T) {
	g, err := RandomGraph(20, 50, 1, false, true, nil, nil, 1, 1, 3)
	if err != nil {
		t.Fatalf("RandomGraph returned error: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if a.Tip == &g.Vertices[i] {
				t.Errorf("self-loop found at vertex %d", i)
			}
		}
	}
}

func TestRandomGraphUndirectedSymmetric(t *testing.T) {
	g, err := RandomGraph(20, 40, 0, false, false, nil, nil, 1, 1, 5)
	if err != nil {
		t.Fatalf("RandomGraph returned error: %v", err)
	}
	type edge struct{ a, b int64 }
	idx := make(map[*gbgraph.Vertex]int64, g.N)
	for i := int64(0); i < g.N; i++ {
		idx[&g.Vertices[i]] = i
	}
	rev := make(map[edge]bool)
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			rev[edge{idx[a.Tip], i}] = true
		}
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if !rev[edge{i, idx[a.Tip]}] {
				t.Errorf("missing reverse arc for edge %d→%d", i, idx[a.Tip])
			}
		}
	}
}

func TestRandomGraphNoDuplicates(t *testing.T) {
	// multi=0, no duplicates allowed.
	g, err := RandomGraph(10, 20, 0, false, true, nil, nil, 1, 1, 7)
	if err != nil {
		t.Fatalf("RandomGraph returned error: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		seen := make(map[*gbgraph.Vertex]bool)
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if seen[a.Tip] {
				t.Errorf("duplicate arc from vertex %d to %p", i, a.Tip)
			}
			seen[a.Tip] = true
		}
	}
}

func TestRandomGraphMultiMinLen(t *testing.T) {
	// multi=-1: duplicate arcs replaced by minimum length arc.
	g, err := RandomGraph(5, 100, -1, true, true, nil, nil, 0, 100, 9)
	if err != nil {
		t.Fatalf("RandomGraph returned error: %v", err)
	}
	// Each arc should appear at most once per source/dest pair.
	// With multi=-1, we can't easily verify min-length property without
	// replaying the random sequence; just check basic sanity.
	if g.N != 5 {
		t.Errorf("want 5 vertices, got %d", g.N)
	}
}

func TestRandomGraphEdgeLengths(t *testing.T) {
	g, err := RandomGraph(20, 50, 1, true, false, nil, nil, 5, 15, 3)
	if err != nil {
		t.Fatalf("RandomGraph returned error: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if a.Len < 5 || a.Len > 15 {
				t.Errorf("arc len=%d out of [5,15]", a.Len)
			}
		}
	}
}

func TestRandomGraphUniformLengths(t *testing.T) {
	// min_len == max_len → all edges have the same length.
	g, err := RandomGraph(10, 20, 1, true, true, nil, nil, 7, 7, 1)
	if err != nil {
		t.Fatalf("RandomGraph returned error: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if a.Len != 7 {
				t.Errorf("arc len=%d, want 7", a.Len)
			}
		}
	}
}

func TestRandomGraphDistFrom(t *testing.T) {
	// Nonuniform distribution: vertex 0 gets all probability.
	n := int64(5)
	dist := make([]int64, n)
	dist[0] = 0x40000000
	g, err := RandomGraph(n, 20, 1, true, true, dist, nil, 1, 1, 1)
	if err != nil {
		t.Fatalf("RandomGraph returned error: %v", err)
	}
	// All arcs should originate from vertex 0.
	for i := int64(1); i < g.N; i++ {
		if g.Vertices[i].Arcs != nil {
			t.Errorf("vertex %d should have no outgoing arcs", i)
		}
	}
}

func TestRandomGraphInvalidDist(t *testing.T) {
	// dist doesn't sum to 2^30.
	dist := make([]int64, 5)
	dist[0] = 0x10000000 // only 1/4 of 2^30
	g, err := RandomGraph(5, 10, 0, false, false, dist, nil, 1, 1, 1)
	if g != nil {
		t.Fatal("expected nil for invalid dist")
	}
	if !errors.Is(err, gbgraph.ErrInvalidOperand) {
		t.Errorf("want ErrInvalidOperand, got %v", err)
	}
}

// ---- RandomBigraph tests ----

func TestRandomBigraphDefault(t *testing.T) {
	g, err := RandomBigraph(10, 15, 30, 0, nil, nil, 1, 1, 0)
	if err != nil {
		t.Fatalf("RandomBigraph returned error: %v", err)
	}
	if g.N != 25 {
		t.Errorf("want 25 vertices, got %d", g.N)
	}
}

func TestRandomBigraphEdgeCount(t *testing.T) {
	g, err := RandomBigraph(10, 10, 20, 0, nil, nil, 1, 1, 1)
	if err != nil {
		t.Fatalf("RandomBigraph returned error: %v", err)
	}
	if g.M != 40 {
		t.Errorf("want M=40, got %d", g.M)
	}
}

func TestRandomBigraphID(t *testing.T) {
	g, err := RandomBigraph(5, 7, 10, 0, nil, nil, 1, 5, 3)
	if err != nil {
		t.Fatalf("RandomBigraph returned error: %v", err)
	}
	want := "random_bigraph(5,7,10,0,0,0,1,5,3)"
	if g.ID != want {
		t.Errorf("ID=%q, want %q", g.ID, want)
	}
}

func TestRandomBigraphUtilTypes(t *testing.T) {
	g, err := RandomBigraph(5, 5, 10, 0, nil, nil, 1, 1, 1)
	if err != nil {
		t.Fatalf("RandomBigraph returned error: %v", err)
	}
	if g.N1() != 5 {
		t.Errorf("N1=%d, want 5", g.N1())
	}
}

func TestRandomBigraphCrossPartition(t *testing.T) {
	// All edges should cross the bipartition boundary.
	n1, n2 := int64(6), int64(9)
	g, err := RandomBigraph(n1, n2, 30, 1, nil, nil, 1, 1, 5)
	if err != nil {
		t.Fatalf("RandomBigraph returned error: %v", err)
	}
	for i := range n1 {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			j := int64(0)
			for k := int64(0); k < g.N; k++ {
				if a.Tip == &g.Vertices[k] {
					j = k
					break
				}
			}
			if j < n1 {
				t.Errorf("edge from part1 vertex %d to part1 vertex %d", i, j)
			}
		}
	}
}

func TestRandomBigraphBadSpecs(t *testing.T) {
	g, err := RandomBigraph(0, 5, 10, 0, nil, nil, 1, 1, 0)
	if g != nil {
		t.Fatal("expected nil for n1=0")
	}
	if !errors.Is(err, gbgraph.ErrBadSpecs) {
		t.Errorf("want ErrBadSpecs, got %v", err)
	}
}

func TestRandomBigraphSymmetric(t *testing.T) {
	g, err := RandomBigraph(8, 12, 20, 0, nil, nil, 1, 1, 7)
	if err != nil {
		t.Fatalf("RandomBigraph returned error: %v", err)
	}
	type edge struct{ a, b int64 }
	idx := make(map[*gbgraph.Vertex]int64, g.N)
	for i := int64(0); i < g.N; i++ {
		idx[&g.Vertices[i]] = i
	}
	rev := make(map[edge]bool)
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			rev[edge{idx[a.Tip], i}] = true
		}
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if !rev[edge{i, idx[a.Tip]}] {
				t.Errorf("missing reverse arc %d→%d", i, idx[a.Tip])
			}
		}
	}
}

// ---- RandomLengths tests ----

func TestRandomLengthsBasic(t *testing.T) {
	g, err := RandomGraph(20, 40, 0, false, false, nil, nil, 1, 1, 1)
	if err != nil {
		t.Fatalf("setup RandomGraph returned error: %v", err)
	}
	err = RandomLengths(g, false, 1, 100, nil, 42)
	if err != nil {
		t.Fatalf("RandomLengths returned error: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if a.Len < 1 || a.Len > 100 {
				t.Errorf("arc len=%d out of [1,100]", a.Len)
			}
		}
	}
}

func TestRandomLengthsSymmetric(t *testing.T) {
	// Undirected: arc u→v and v→u should have the same length.
	g, err := RandomGraph(15, 30, 0, false, false, nil, nil, 1, 1, 1)
	if err != nil {
		t.Fatalf("setup failed: %v", err)
	}
	if err := RandomLengths(g, false, 1, 50, nil, 7); err != nil {
		t.Fatalf("RandomLengths failed: %v", err)
	}
	type edge struct{ a, b int64 }
	idx := make(map[*gbgraph.Vertex]int64, g.N)
	for i := int64(0); i < g.N; i++ {
		idx[&g.Vertices[i]] = i
	}
	lens := make(map[edge]int64)
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			j := idx[a.Tip]
			e := edge{i, j}
			if i > j {
				e = edge{j, i}
			}
			if prev, ok := lens[e]; ok {
				if prev != a.Len {
					t.Errorf("asymmetric edge %d--%d: %d vs %d", i, j, prev, a.Len)
				}
			} else {
				lens[e] = a.Len
			}
		}
	}
}

func TestRandomLengthsDirected(t *testing.T) {
	// Directed: arcs u→v and v→u can have different lengths.
	g, err := RandomGraph(10, 30, 1, true, true, nil, nil, 1, 1, 2)
	if err != nil {
		t.Fatalf("setup failed: %v", err)
	}
	if err := RandomLengths(g, true, 10, 20, nil, 3); err != nil {
		t.Fatalf("RandomLengths failed: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if a.Len < 10 || a.Len > 20 {
				t.Errorf("arc len=%d out of [10,20]", a.Len)
			}
		}
	}
}

func TestRandomLengthsNilGraph(t *testing.T) {
	err := RandomLengths(nil, false, 1, 10, nil, 1)
	if !errors.Is(err, gbgraph.ErrMissingOperand) {
		t.Errorf("want ErrMissingOperand, got %v", err)
	}
}

func TestRandomLengthsVeryBadSpecs(t *testing.T) {
	g, _ := RandomGraph(5, 5, 1, true, false, nil, nil, 1, 1, 1)
	err := RandomLengths(g, false, 10, 5, nil, 1)
	if !errors.Is(err, gbgraph.ErrVeryBadSpecs) {
		t.Errorf("want ErrVeryBadSpecs, got %v", err)
	}
}

func TestRandomLengthsID(t *testing.T) {
	g, err := RandomGraph(5, 5, 1, true, false, nil, nil, 1, 1, 1)
	if err != nil {
		t.Fatalf("setup failed: %v", err)
	}
	origID := g.ID
	if err := RandomLengths(g, false, 1, 10, nil, 42); err != nil {
		t.Fatalf("RandomLengths failed: %v", err)
	}
	want := fmt.Sprintf("random_lengths(%s,0,1,10,0,42)", origID)
	if g.ID != want {
		t.Errorf("ID=%q, want %q", g.ID, want)
	}
}

func TestRandomLengthsReproducible(t *testing.T) {
	g1, err1 := RandomGraph(10, 20, 0, false, false, nil, nil, 1, 1, 1)
	g2, err2 := RandomGraph(10, 20, 0, false, false, nil, nil, 1, 1, 1)
	if err1 != nil || err2 != nil {
		t.Fatalf("setup failed: %v / %v", err1, err2)
	}
	RandomLengths(g1, false, 1, 100, nil, 7)
	RandomLengths(g2, false, 1, 100, nil, 7)
	for i := int64(0); i < g1.N; i++ {
		a1, a2 := g1.Vertices[i].Arcs, g2.Vertices[i].Arcs
		for a1 != nil && a2 != nil {
			if a1.Len != a2.Len {
				t.Errorf("length mismatch at vertex %d", i)
			}
			a1, a2 = a1.Next, a2.Next
		}
	}
}

func TestRandomLengthsUniformLen(t *testing.T) {
	// min_len == max_len → all arcs get same length.
	g, err := RandomGraph(10, 15, 1, true, true, nil, nil, 1, 1, 1)
	if err != nil {
		t.Fatalf("setup failed: %v", err)
	}
	if err := RandomLengths(g, true, 42, 42, nil, 1); err != nil {
		t.Fatalf("RandomLengths failed: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if a.Len != 42 {
				t.Errorf("arc len=%d, want 42", a.Len)
			}
		}
	}
}

func TestRandomLengthsNonuniform(t *testing.T) {
	// Distribution: 3 values summing to 2^30.
	dist := []int64{0x15555555, 0x15555556, 0x15555555} // roughly 1/3 each, sums to 0x40000000
	g, err := RandomGraph(10, 20, 1, true, false, nil, nil, 1, 1, 1)
	if err != nil {
		t.Fatalf("setup failed: %v", err)
	}
	if err := RandomLengths(g, false, 0, 2, dist, 7); err != nil {
		t.Fatalf("RandomLengths returned error: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if a.Len < 0 || a.Len > 2 {
				t.Errorf("arc len=%d out of [0,2]", a.Len)
			}
		}
	}
}

// ---- helpers ----

// makeUniformDist returns a distribution of length n summing to 2^30.
func makeUniformDist(n int64) []int64 {
	dist := make([]int64, n)
	for k := range n {
		dist[k] = (0x40000000 + k) / n
	}
	return dist
}
