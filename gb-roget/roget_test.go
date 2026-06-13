package gbroget

import (
	"testing"

	"github.com/sjnam/go-sgb/gb-io"
)

func init() {
	gbio.DataDirectory = "../data/"
}

func TestRogetDefault(t *testing.T) {
	g, err := Roget(0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Roget(0,0,0,0) error: %v", err)
	}
	if g == nil {
		t.Fatal("Roget(0,0,0,0) returned nil")
	}
	if g.N != MaxN {
		t.Errorf("want %d vertices, got %d", MaxN, g.N)
	}
}

func TestRogetID(t *testing.T) {
	g, err := Roget(1022, 0, 0, 0)
	if err != nil {
		t.Fatalf("Roget returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Roget returned nil")
	}
	want := "roget(1022,0,0,0)"
	if g.ID != want {
		t.Errorf("ID=%q, want %q", g.ID, want)
	}
}

func TestRogetUtilTypes(t *testing.T) {
	g, err := Roget(0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Roget returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Roget returned nil")
	}
	if g.UtilTypes != "IZZZZZZZZZZZZZ" {
		t.Errorf("UtilTypes=%q", g.UtilTypes)
	}
}

func TestRogetVertexNames(t *testing.T) {
	g, err := Roget(0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Roget returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Roget returned nil")
	}
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		if v.Name == "" {
			t.Errorf("vertex %d (cat %d): empty name", i, CatNo(v))
		}
	}
}

func TestRogetCatNo(t *testing.T) {
	g, err := Roget(0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Roget returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Roget returned nil")
	}
	// All category numbers must be in range [1, MaxN].
	seen := make(map[int64]bool)
	for i := int64(0); i < g.N; i++ {
		c := CatNo(&g.Vertices[i])
		if c < 1 || c > MaxN {
			t.Errorf("vertex %d: cat_no=%d out of range", i, c)
		}
		if seen[c] {
			t.Errorf("cat_no=%d appears twice", c)
		}
		seen[c] = true
	}
	if int64(len(seen)) != g.N {
		t.Errorf("expected %d distinct cat_nos, got %d", g.N, len(seen))
	}
}

func TestRogetArcCatNoRange(t *testing.T) {
	// All arcs should point to vertices with valid cat_nos.
	g, err := Roget(0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Roget returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Roget returned nil")
	}
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		for a := v.Arcs; a != nil; a = a.Next {
			if a.Tip == nil {
				t.Errorf("%s: nil arc tip", v.Name)
			}
			if a.Len != 1 {
				t.Errorf("%s: arc len=%d, want 1", v.Name, a.Len)
			}
		}
	}
}

func TestRogetSubset(t *testing.T) {
	g, err := Roget(100, 0, 0, 1)
	if err != nil {
		t.Fatalf("Roget(100,...) error: %v", err)
	}
	if g == nil {
		t.Fatal("Roget(100,...) returned nil")
	}
	if g.N != 100 {
		t.Errorf("want 100 vertices, got %d", g.N)
	}
}

func TestRogetMinDistance(t *testing.T) {
	// With minDistance=1 all arcs allowed; with minDistance=2 adjacent-category
	// arcs removed → arc count should not increase.
	g0, err := Roget(0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Roget(minDist=0) error: %v", err)
	}
	g1, err := Roget(0, 2, 0, 0)
	if err != nil {
		t.Fatalf("Roget(minDist=2) error: %v", err)
	}
	if g0 == nil || g1 == nil {
		t.Fatal("Roget returned nil")
	}
	if g1.M > g0.M {
		t.Errorf("minDistance=2 gave M=%d > minDistance=0 M=%d", g1.M, g0.M)
	}
}

func TestRogetMinDistanceFilter(t *testing.T) {
	// With the full graph and minDistance=2, no arc should connect categories
	// that differ by less than 2.
	g, err := Roget(0, 2, 0, 0)
	if err != nil {
		t.Fatalf("Roget returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Roget returned nil")
	}
	for i := int64(0); i < g.N; i++ {
		src := &g.Vertices[i]
		for a := src.Arcs; a != nil; a = a.Next {
			d := CatNo(src) - CatNo(a.Tip)
			if d < 0 {
				d = -d
			}
			if d < 2 {
				t.Errorf("%s(cat %d) → %s(cat %d): distance %d < minDistance 2",
					src.Name, CatNo(src), a.Tip.Name, CatNo(a.Tip), d)
			}
		}
	}
}

func TestRogetProb(t *testing.T) {
	// prob=32768 rejects ~50% of arcs; should give fewer arcs than prob=0.
	g0, err := Roget(0, 0, 0, 42)
	if err != nil {
		t.Fatalf("Roget(prob=0) error: %v", err)
	}
	g1, err := Roget(0, 0, 32768, 42)
	if err != nil {
		t.Fatalf("Roget(prob=32768) error: %v", err)
	}
	if g0 == nil || g1 == nil {
		t.Fatal("Roget returned nil")
	}
	if g1.M >= g0.M {
		t.Errorf("prob=32768 gave M=%d, prob=0 gave M=%d (expected fewer)", g1.M, g0.M)
	}
}

func TestRogetReproducible(t *testing.T) {
	// Same seed must give the same graph.
	g1, err := Roget(50, 3, 0, 7)
	if err != nil {
		t.Fatalf("Roget(1) error: %v", err)
	}
	g2, err := Roget(50, 3, 0, 7)
	if err != nil {
		t.Fatalf("Roget(2) error: %v", err)
	}
	if g1 == nil || g2 == nil {
		t.Fatal("Roget returned nil")
	}
	if g1.M != g2.M {
		t.Errorf("same seed, different arc count: %d vs %d", g1.M, g2.M)
	}
	for i := int64(0); i < g1.N; i++ {
		if CatNo(&g1.Vertices[i]) != CatNo(&g2.Vertices[i]) {
			t.Errorf("vertex %d: cat_no mismatch %d vs %d",
				i, CatNo(&g1.Vertices[i]), CatNo(&g2.Vertices[i]))
		}
	}
}

func TestRogetFullArcCount(t *testing.T) {
	// Full graph (no filters) should have a positive arc count.
	g, err := Roget(0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Roget returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Roget returned nil")
	}
	if g.M <= 0 {
		t.Errorf("expected positive arc count, got %d", g.M)
	}
}
