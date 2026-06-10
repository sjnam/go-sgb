package gbraman

import (
	"errors"
	"strings"
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
)

// ---- helpers ----

func checkSymmetric(t *testing.T, g *gbgraph.Graph) {
	t.Helper()
	idx := make(map[*gbgraph.Vertex]int64, g.N)
	for i := int64(0); i < g.N; i++ {
		idx[&g.Vertices[i]] = i
	}
	type edge struct{ a, b int64 }
	fwd := make(map[edge]bool)
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			j := idx[a.Tip]
			fwd[edge{i, j}] = true
		}
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			j := idx[a.Tip]
			if !fwd[edge{j, i}] {
				t.Errorf("missing reverse arc %d→%d", j, i)
				return
			}
		}
	}
}

// ---- Type 1 tests ----

func TestRamanType1N(t *testing.T) {
	// type 1 has q+1 vertices
	g, err := Raman(2, 3, 1, false)
	if err != nil {
		t.Fatalf("Raman(2,3,1,0) error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman(2,3,1,0) = nil")
	}
	if g.N != 4 {
		t.Errorf("N=%d, want 4", g.N)
	}
}

func TestRamanType1Arcs(t *testing.T) {
	// Knuth's note: p=2, q=3, type=1 has 14 arcs (not 12) due to self-inverse generators
	g, err := Raman(2, 3, 1, false)
	if err != nil {
		t.Fatalf("Raman(2,3,1,0) error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman(2,3,1,0) = nil")
	}
	if g.M != 14 {
		t.Errorf("M=%d, want 14", g.M)
	}
}

func TestRamanID(t *testing.T) {
	g, err := Raman(2, 3, 1, false)
	if err != nil {
		t.Fatalf("Raman returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman returned nil")
	}
	want := "raman(2,3,1,0)"
	if g.ID != want {
		t.Errorf("ID=%q, want %q", g.ID, want)
	}
}

func TestRamanType1UtilTypes(t *testing.T) {
	g, err := Raman(2, 3, 1, false)
	if err != nil {
		t.Fatalf("Raman returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman returned nil")
	}
	// type 1: only vertex.x used (util_types[4]='Z' clears vertex.y)
	if g.UtilTypes != "ZZZIZZIZZZZZZZ" {
		t.Errorf("UtilTypes=%q, want ZZZIZZIZZZZZZZ", g.UtilTypes)
	}
}

func TestRamanType1Symmetric(t *testing.T) {
	g, err := Raman(3, 5, 1, false)
	if err != nil {
		t.Fatalf("Raman(3,5,1,0) error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman(3,5,1,0) = nil")
	}
	checkSymmetric(t, g)
}

func TestRamanType1VertexNames(t *testing.T) {
	g, err := Raman(2, 3, 1, false)
	if err != nil {
		t.Fatalf("Raman returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman returned nil")
	}
	// type 1: vertices named 0, 1, ..., q-1, INF
	if g.Vertices[0].Name != "0" {
		t.Errorf("v[0].Name=%q, want 0", g.Vertices[0].Name)
	}
	if g.Vertices[3].Name != "INF" {
		t.Errorf("v[3].Name=%q, want INF", g.Vertices[3].Name)
	}
}

// ---- Type 2 tests ----

func TestRamanType2N(t *testing.T) {
	// type 2: q*(q+1)/2 vertices
	// p=5, q=3: n=3*4/2=6
	g, err := Raman(5, 3, 2, false)
	if err != nil {
		t.Fatalf("Raman(5,3,2,0) error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman(5,3,2,0) = nil")
	}
	if g.N != 6 {
		t.Errorf("N=%d, want 6", g.N)
	}
}

func TestRamanType2UtilTypes(t *testing.T) {
	g, err := Raman(5, 3, 2, false)
	if err != nil {
		t.Fatalf("Raman returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman returned nil")
	}
	// type 2: vertex.X and vertex.Y used
	if g.UtilTypes != "ZZZIIZIZZZZZZZ" {
		t.Errorf("UtilTypes=%q, want ZZZIIZIZZZZZZZ", g.UtilTypes)
	}
}

func TestRamanType2Symmetric(t *testing.T) {
	g, err := Raman(5, 3, 2, false)
	if err != nil {
		t.Fatalf("Raman returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman returned nil")
	}
	checkSymmetric(t, g)
}

func TestRamanType2VertexNames(t *testing.T) {
	g, err := Raman(5, 3, 2, false)
	if err != nil {
		t.Fatalf("Raman returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman returned nil")
	}
	// type 2: pairs like {0,1}, {0,2}, {0,INF}, {1,2}, {1,INF}, {2,INF}
	for i := int64(0); i < g.N; i++ {
		name := g.Vertices[i].Name
		if !strings.HasPrefix(name, "{") || !strings.HasSuffix(name, "}") {
			t.Errorf("v[%d].Name=%q: expected {..} format", i, name)
		}
	}
}

// ---- Type 3 tests ----

func TestRamanType3N(t *testing.T) {
	// p=5, q=11: 5 is a QR mod 11 (4^2=16≡5), so type 3 works
	// nFactor=(11-1)/2=5, n=5*11*12=660
	g, err := Raman(5, 11, 3, false)
	if err != nil {
		t.Fatalf("Raman(5,11,3,0) error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman(5,11,3,0) = nil")
	}
	if g.N != 660 {
		t.Errorf("N=%d, want 660", g.N)
	}
}

func TestRamanType3UtilTypes(t *testing.T) {
	g, err := Raman(5, 11, 3, false)
	if err != nil {
		t.Fatalf("Raman returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman returned nil")
	}
	// types 3/4: vertex.X, .Y, .Z all used
	if g.UtilTypes != "ZZZIIIIZZZZZZZ" {
		t.Errorf("UtilTypes=%q, want ZZZIIIIZZZZZZZ", g.UtilTypes)
	}
}

func TestRamanType3HasEdges(t *testing.T) {
	g, err := Raman(5, 11, 3, false)
	if err != nil {
		t.Fatalf("Raman returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman returned nil")
	}
	if g.M == 0 {
		t.Error("M=0, expected positive")
	}
}

// ---- Type 4 tests ----

func TestRamanType4N(t *testing.T) {
	// p=5, q=3: 5%3=2, not QR mod 3 (QR={1}), so type 4 works
	// nFactor=3-1=2, n=2*3*4=24
	g, err := Raman(5, 3, 4, false)
	if err != nil {
		t.Fatalf("Raman(5,3,4,0) error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman(5,3,4,0) = nil")
	}
	if g.N != 24 {
		t.Errorf("N=%d, want 24", g.N)
	}
}

func TestRamanType4Symmetric(t *testing.T) {
	g, err := Raman(5, 3, 4, false)
	if err != nil {
		t.Fatalf("Raman returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman returned nil")
	}
	checkSymmetric(t, g)
}

// ---- Type 0 (auto) tests ----

func TestRamanType0SelectsType4(t *testing.T) {
	// p=2, q=43: 2 is not QR mod 43 → type 4
	// but first verify p=2, q=43 is valid: q%8=3 ✓, q%13=4 ✓
	g, err := Raman(2, 43, 0, false)
	if err != nil {
		t.Fatalf("Raman(2,43,0,0) error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman(2,43,0,0) = nil")
	}
	// ID should contain type=4
	if !strings.Contains(g.ID, ",4,") {
		t.Errorf("ID=%q: expected type 4", g.ID)
	}
}

func TestRamanType0SelectsType3(t *testing.T) {
	// p=5, q=11: 5 is QR mod 11 → type 3
	g, err := Raman(5, 11, 0, false)
	if err != nil {
		t.Fatalf("Raman(5,11,0,0) error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman(5,11,0,0) = nil")
	}
	if !strings.Contains(g.ID, ",3,") {
		t.Errorf("ID=%q: expected type 3", g.ID)
	}
}

// ---- Reduce tests ----

func TestRamanReduceFewerArcs(t *testing.T) {
	// p=2, q=3, type=1: reduce removes self-loops, should give M<14
	g0, err := Raman(2, 3, 1, false)
	if err != nil {
		t.Fatalf("Raman(reduce=0) error: %v", err)
	}
	g1, err := Raman(2, 3, 1, true)
	if err != nil {
		t.Fatalf("Raman(reduce=1) error: %v", err)
	}
	if g0 == nil || g1 == nil {
		t.Fatal("Raman returned nil")
	}
	if g1.M >= g0.M {
		t.Errorf("reduce=1 M=%d >= reduce=0 M=%d", g1.M, g0.M)
	}
}

// ---- Bad specs tests ----

func TestRamanBadSpecsQTooSmall(t *testing.T) {
	g, err := Raman(2, 2, 1, false) // q must be >= 3
	if g != nil {
		t.Fatal("expected nil for q=2")
	}
	if !errors.Is(err, gbgraph.ErrVeryBadSpecs) {
		t.Errorf("want ErrVeryBadSpecs, got %v", err)
	}
}

func TestRamanBadSpecsQTooLarge(t *testing.T) {
	g, err := Raman(2, 50000, 1, false) // q > 46337
	if g != nil {
		t.Fatal("expected nil for q>46337")
	}
	if !errors.Is(err, gbgraph.ErrVeryBadSpecs) {
		t.Errorf("want ErrVeryBadSpecs, got %v", err)
	}
}

func TestRamanBadSpecsPTooSmall(t *testing.T) {
	g, err := Raman(1, 5, 1, false) // p must be >= 2
	if g != nil {
		t.Fatal("expected nil for p=1")
	}
	if !errors.Is(err, gbgraph.ErrVeryBadSpecs) {
		t.Errorf("want ErrVeryBadSpecs, got %v", err)
	}
}

func TestRamanBadSpecsP2QMod8(t *testing.T) {
	// p=2, q=5: q%8=5, not in {1,3} → bad specs
	g, err := Raman(2, 5, 1, false)
	if g != nil {
		t.Fatal("expected nil for p=2,q=5")
	}
	if !errors.Is(err, gbgraph.ErrBadSpecs) {
		t.Errorf("want ErrBadSpecs, got %v", err)
	}
}

func TestRamanBadSpecsQNotPrime(t *testing.T) {
	// q=15 is not prime
	g, err := Raman(5, 15, 1, false)
	if g != nil {
		t.Fatal("expected nil for q=15 (not prime)")
	}
	if !errors.Is(err, gbgraph.ErrBadSpecs) {
		t.Errorf("want ErrBadSpecs, got %v", err)
	}
}

func TestRamanBadSpecsWrongType3(t *testing.T) {
	// p=5, q=3: 5%3=2 is NOT QR mod 3, so type=3 should fail
	g, err := Raman(5, 3, 3, false)
	if g != nil {
		t.Fatal("expected nil: p=5 not QR mod q=3, type=3 invalid")
	}
	if !errors.Is(err, gbgraph.ErrBadSpecs) {
		t.Errorf("want ErrBadSpecs, got %v", err)
	}
}

func TestRamanBadSpecsWrongType4(t *testing.T) {
	// p=5, q=11: 5 IS QR mod 11, so type=4 should fail
	g, err := Raman(5, 11, 4, false)
	if g != nil {
		t.Fatal("expected nil: p=5 is QR mod q=11, type=4 invalid")
	}
	if !errors.Is(err, gbgraph.ErrBadSpecs) {
		t.Errorf("want ErrBadSpecs, got %v", err)
	}
}

func TestRamanBadSpecsType34QTooLarge(t *testing.T) {
	// p=2, q=1291 > 1289; p=2 special conditions pass for q=1291
	// (13 and -2 are both QR mod 1291), and 2 is not QR mod 1291 → type 4
	g, err := Raman(2, 1291, 0, false)
	if g != nil {
		t.Fatal("expected nil for q>1289 with type 3/4")
	}
	if !errors.Is(err, gbgraph.ErrBadSpecs) {
		t.Errorf("want ErrBadSpecs, got %v", err)
	}
}

// ---- Degree regularity ----

func TestRamanType1Degree(t *testing.T) {
	// p=3, q=5, type=1: N=6, degree should be p+1=4 for all vertices
	// (p=3%4=3 so pp=1; all generators are self-inverse with no fixed points for q=5)
	g, err := Raman(3, 5, 1, false)
	if err != nil {
		t.Fatalf("Raman(3,5,1,0) error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman(3,5,1,0) = nil")
	}
	for i := int64(0); i < g.N; i++ {
		deg := int64(0)
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			deg++
		}
		if deg != 4 {
			t.Errorf("v[%d] degree=%d, want 4", i, deg)
		}
	}
}

func TestRamanType2Degree(t *testing.T) {
	// p=5, q=3: N=6, degree=p+1=6
	g, err := Raman(5, 3, 2, false)
	if err != nil {
		t.Fatalf("Raman returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman returned nil")
	}
	for i := int64(0); i < g.N; i++ {
		deg := int64(0)
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			deg++
		}
		if deg != 6 {
			t.Errorf("v[%d] degree=%d, want 6", i, deg)
		}
	}
}

// ---- Edge lengths ----

func TestRamanAllLengthsOne(t *testing.T) {
	g, err := Raman(3, 5, 1, false)
	if err != nil {
		t.Fatalf("Raman returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Raman returned nil")
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if a.Len != 1 {
				t.Errorf("arc length=%d, want 1", a.Len)
			}
		}
	}
}
