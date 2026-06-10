package basic

import (
	"strings"
	"testing"

	"github.com/sjnam/go-sgb/graph"
)

// -----------------------------------------------------------------------
// Board
// -----------------------------------------------------------------------

func TestBoardDefaultChessboard(t *testing.T) {
	// board(0,0,0,0,0,0,0) → default 8×8 wazir (piece=1)
	g := Board(0, 0, 0, 0, 0, 0, 0)
	if g == nil {
		t.Fatal("Board returned nil")
	}
	if g.N != 64 {
		t.Errorf("N = %d, want 64", g.N)
	}
	// every interior square has 4 wazir neighbours; total edges = 2*(7*8+8*7)/2 = 112
	if g.M != 224 { // M counts arcs, 112 edges × 2
		t.Errorf("M = %d, want 224", g.M)
	}
}

func TestBoardCompletePath(t *testing.T) {
	// board(5,0,0,0,-1,0,0) → complete graph K5 (piece=-1 = rook on 1D)
	g := Board(5, 0, 0, 0, -1, 0, 0)
	if g == nil {
		t.Fatal("Board returned nil")
	}
	if g.N != 5 {
		t.Errorf("N = %d, want 5", g.N)
	}
	// K5 has 10 edges = 20 arcs
	if g.M != 20 {
		t.Errorf("M = %d, want 20 (K5)", g.M)
	}
}

func TestBoardCircuit(t *testing.T) {
	// board(6,0,0,0,1,1,0) → undirected circuit of length 6
	g := Board(6, 0, 0, 0, 1, 1, 0)
	if g == nil {
		t.Fatal("Board returned nil")
	}
	if g.N != 6 {
		t.Errorf("N = %d, want 6", g.N)
	}
	if g.M != 12 {
		t.Errorf("M = %d, want 12 (6-circuit)", g.M)
	}
	// every vertex has degree 2
	for i := int64(0); i < g.N; i++ {
		deg := 0
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			deg++
		}
		if deg != 2 {
			t.Errorf("vertex %d degree = %d, want 2", i, deg)
		}
	}
}

func TestBoardKnightMoves(t *testing.T) {
	// board(8,8,0,0,5,0,0) → 8×8 knight graph
	g := Board(8, 8, 0, 0, 5, 0, 0)
	if g == nil {
		t.Fatal("Board returned nil")
	}
	if g.N != 64 {
		t.Errorf("N = %d, want 64", g.N)
	}
	// Corner squares have 2 knight moves each; well-known total = 168 edges = 336 arcs
	if g.M != 336 {
		t.Errorf("M = %d, want 336 (knight graph)", g.M)
	}
}

func TestBoardID(t *testing.T) {
	g := Board(4, 4, 0, 0, 1, 0, 0)
	if !strings.HasPrefix(g.ID, "board(") {
		t.Errorf("ID = %q, want board(...)", g.ID)
	}
}

// -----------------------------------------------------------------------
// Simplex
// -----------------------------------------------------------------------

func TestSimplexTriangle(t *testing.T) {
	// simplex(1,-2,0,0,0,0,0) → d=2, triangle (3 vertices, 3 edges)
	// n=1, n0=-2 → d=2, nn[0]=nn[1]=nn[2]=1
	// vertices: (1,0,0),(0,1,0),(0,0,1)
	g, err := Simplex(1, -2, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if g == nil {
		t.Fatal("Simplex returned nil")
	}
	if g.N != 3 {
		t.Errorf("N = %d, want 3", g.N)
	}
	if g.M != 6 {
		t.Errorf("M = %d, want 6 (triangle)", g.M)
	}
}

func TestSimplexTetrahedral(t *testing.T) {
	// simplex(3,-2,0,0,0,0,0) → n=3,d=2, triangular array with 10 vertices
	g, err := Simplex(3, -2, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if g == nil {
		t.Fatal("Simplex returned nil")
	}
	if g.N != 10 {
		t.Errorf("N = %d, want 10", g.N)
	}
}

// -----------------------------------------------------------------------
// Parts
// -----------------------------------------------------------------------

func TestPartsOf5(t *testing.T) {
	// all_parts(5,0) → 7 partitions of 5
	g, err := Parts(5, 0, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if g == nil {
		t.Fatal("Parts returned nil")
	}
	if g.N != 7 {
		t.Errorf("N = %d, want 7 (partitions of 5)", g.N)
	}
}

func TestPartsVertexNames(t *testing.T) {
	g, err := Parts(4, 0, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if g == nil {
		t.Fatal("Parts returned nil")
	}
	// partitions of 4: 4, 3+1, 2+2, 2+1+1, 1+1+1+1 → 5 vertices
	if g.N != 5 {
		t.Errorf("N = %d, want 5", g.N)
	}
	// vertex names should all be non-empty and contain digits/plusses
	for i := int64(0); i < g.N; i++ {
		name := g.Vertices[i].Name
		if name == "" {
			t.Errorf("vertex %d has empty name", i)
		}
	}
}

// -----------------------------------------------------------------------
// Binary
// -----------------------------------------------------------------------

func TestBinaryN3(t *testing.T) {
	// binary(3,0,0) → all binary trees with 3 internal nodes → Catalan(3)=5
	g, err := Binary(3, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if g == nil {
		t.Fatal("Binary returned nil")
	}
	if g.N != 5 {
		t.Errorf("N = %d, want 5", g.N)
	}
	// The 5 trees form a circuit: each has exactly 2 neighbours
	for i := int64(0); i < g.N; i++ {
		deg := 0
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			deg++
		}
		if deg != 2 {
			t.Errorf("tree %d degree = %d, want 2", i, deg)
		}
	}
}

func TestBinaryN1(t *testing.T) {
	// binary(1,0,0) → single tree (root only) → 1 vertex, 0 edges
	g, err := Binary(1, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if g == nil {
		t.Fatal("Binary returned nil")
	}
	if g.N != 1 {
		t.Errorf("N = %d, want 1", g.N)
	}
}

// -----------------------------------------------------------------------
// Complement
// -----------------------------------------------------------------------

func TestComplementK3(t *testing.T) {
	// complement of triangle (K3) with no self-loops, undirected
	// K3 has 3 edges; complement of K3 on 3 vertices (no self-loops) has 0 edges
	tri := Board(3, 0, 0, 0, -1, 0, 0) // K3
	if tri == nil {
		t.Fatal("Board(K3) nil")
	}
	comp, err := Complement(tri, 0, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if comp == nil {
		t.Fatal("Complement returned nil")
	}
	if comp.N != 3 {
		t.Errorf("N = %d, want 3", comp.N)
	}
	if comp.M != 0 {
		t.Errorf("M = %d, want 0 (complement of K3)", comp.M)
	}
}

func TestComplementCopy(t *testing.T) {
	// copy=1 → double complement = copy without duplicate arcs
	g := Board(4, 0, 0, 0, -1, 0, 0) // K4
	cp, err := Complement(g, 1, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if cp == nil {
		t.Fatal("Complement(copy) nil")
	}
	if cp.N != g.N {
		t.Errorf("N %d != %d", cp.N, g.N)
	}
	// K4 copy: same edges, no duplicates → same M
	if cp.M != g.M {
		t.Errorf("M %d != %d after copy", cp.M, g.M)
	}
}

// -----------------------------------------------------------------------
// Gunion
// -----------------------------------------------------------------------

func TestGunionPath(t *testing.T) {
	// union of wazir (piece=1) and fers (piece=2) on 3×3 board = king moves
	wazir := Board(3, 3, 0, 0, 1, 0, 0)
	fers := Board(3, 3, 0, 0, 2, 0, 0)
	king, err := Gunion(wazir, fers, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if king == nil {
		t.Fatal("Gunion returned nil")
	}
	if king.N != 9 {
		t.Errorf("N = %d, want 9", king.N)
	}
	// center has 8 king neighbours
	var maxDeg int64
	for i := int64(0); i < king.N; i++ {
		var deg int64
		for a := king.Vertices[i].Arcs; a != nil; a = a.Next {
			deg++
		}
		if deg > maxDeg {
			maxDeg = deg
		}
	}
	if maxDeg != 8 {
		t.Errorf("max degree = %d, want 8 (center of 3×3 king)", maxDeg)
	}
}

// -----------------------------------------------------------------------
// Product
// -----------------------------------------------------------------------

func TestProductCartesian(t *testing.T) {
	// Cartesian product of P2 × P3  (path of 2 × path of 3)
	// = grid 2×3 = 6 vertices
	p2 := Board(2, 0, 0, 0, 1, 0, 0)
	p3 := Board(3, 0, 0, 0, 1, 0, 0)
	grid, err := Product(p2, p3, Cartesian, 0)
	if err != nil {
		t.Fatal(err)
	}
	if grid == nil {
		t.Fatal("Product returned nil")
	}
	if grid.N != 6 {
		t.Errorf("N = %d, want 6", grid.N)
	}
	// Cartesian product P2 □ P3 has 2*2 + 3*1 = 7 edges = 14 arcs
	if grid.M != 14 {
		t.Errorf("M = %d, want 14", grid.M)
	}
}

// -----------------------------------------------------------------------
// BiComplete
// -----------------------------------------------------------------------

func TestBiComplete(t *testing.T) {
	g, err := BiComplete(3, 4, 0)
	if err != nil {
		t.Fatal(err)
	}
	if g == nil {
		t.Fatal("BiComplete returned nil")
	}
	if g.N != 7 {
		t.Errorf("N = %d, want 7", g.N)
	}
	// K_{3,4} has 3*4=12 edges = 24 arcs
	if g.M != 24 {
		t.Errorf("M = %d, want 24", g.M)
	}
	if g.N1() != 3 {
		t.Errorf("N1 = %d, want 3", g.N1())
	}
}

// keep graph import used
var _ = graph.ErrBadSpecs
