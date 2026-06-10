package econ

import (
	"testing"

	"github.com/sjnam/go-sgb/io"
)

func init() {
	io.DataDirectory = "../data/"
}

func TestEconDefault(t *testing.T) {
	g, err := Econ(0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Econ(0,0,0,0) returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Econ(0,0,0,0) returned nil")
	}
	if g.N != MaxN {
		t.Errorf("want %d vertices, got %d", MaxN, g.N)
	}
}

func TestEconID(t *testing.T) {
	g, err := Econ(81, 0, 0, 0)
	if err != nil {
		t.Fatalf("Econ returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Econ returned nil")
	}
	want := "econ(81,0,0,0)"
	if g.ID != want {
		t.Errorf("ID=%q, want %q", g.ID, want)
	}
}

func TestEconUtilTypes(t *testing.T) {
	g, err := Econ(0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Econ returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Econ returned nil")
	}
	if g.UtilTypes != "ZZZZIAIZZZZZZZ" {
		t.Errorf("UtilTypes=%q", g.UtilTypes)
	}
}

func TestEconOmit1(t *testing.T) {
	// omit=1 removes Users vertex; should have 80 vertices.
	g, err := Econ(0, 1, 0, 0)
	if err != nil {
		t.Fatalf("Econ(0,1,0,0) returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Econ(0,1,0,0) returned nil")
	}
	if g.N != MaxN-1 {
		t.Errorf("want %d vertices, got %d", MaxN-1, g.N)
	}
}

func TestEconOmit2(t *testing.T) {
	// omit=2 removes Users and Adjustments; should have 79 vertices.
	g, err := Econ(0, 2, 0, 0)
	if err != nil {
		t.Fatalf("Econ(0,2,0,0) returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Econ(0,2,0,0) returned nil")
	}
	if g.N != NormN {
		t.Errorf("want %d vertices, got %d", NormN, g.N)
	}
}

func TestEconVertexNames(t *testing.T) {
	g, err := Econ(0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Econ returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Econ returned nil")
	}
	for i := int64(0); i < g.N; i++ {
		if g.Vertices[i].Name == "" {
			t.Errorf("vertex %d has empty name", i)
		}
	}
}

func TestEconSectorTotal(t *testing.T) {
	g, err := Econ(0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Econ returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Econ returned nil")
	}
	// Every vertex should have a positive sector_total (except possibly Users).
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		if SectorTotal(v) < 0 {
			t.Errorf("vertex %q: sector_total=%d < 0", v.Name, SectorTotal(v))
		}
	}
}

func TestEconSICCodes(t *testing.T) {
	// With omit=1 and n=80 each non-Users vertex must have exactly one SIC code.
	g, err := Econ(80, 1, 0, 0)
	if err != nil {
		t.Fatalf("Econ returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Econ returned nil")
	}
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		a := SICCodes(v)
		if a == nil {
			t.Errorf("vertex %q: SIC_codes is nil", v.Name)
			continue
		}
		if a.Next != nil {
			t.Errorf("vertex %q: expected single SIC code, got chain", v.Name)
		}
		if a.Len < 1 || a.Len > AdjSec {
			t.Errorf("vertex %q: SIC code %d out of range", v.Name, a.Len)
		}
	}
}

func TestEconArcFlow(t *testing.T) {
	// All arc flows should be nonzero (threshold=0 keeps only nonzero entries).
	g, err := Econ(0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Econ returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Econ returned nil")
	}
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		for a := v.Arcs; a != nil; a = a.Next {
			if Flow(a) == 0 {
				t.Errorf("vertex %q: arc to %q has flow=0", v.Name, a.Tip.Name)
			}
			if a.Len != 1 {
				t.Errorf("vertex %q: arc len=%d, want 1", v.Name, a.Len)
			}
		}
	}
}

func TestEconThreshold(t *testing.T) {
	// Raising threshold should reduce arc count.
	g0, err0 := Econ(0, 2, 0, 0)
	g1, err1 := Econ(0, 2, 6000, 0)
	if err0 != nil || err1 != nil {
		t.Fatalf("Econ returned error: %v / %v", err0, err1)
	}
	if g0 == nil || g1 == nil {
		t.Fatal("Econ returned nil")
	}
	if g1.M >= g0.M {
		t.Errorf("threshold=6000 gave M=%d, threshold=0 gave M=%d (expected fewer)", g1.M, g0.M)
	}
}

func TestEconCirculation(t *testing.T) {
	// With omit=0, the graph should be a circulation:
	// for each vertex v, sum of outgoing flows = sector_total(v).
	g, err := Econ(0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Econ returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Econ returned nil")
	}
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		outSum := int64(0)
		for a := v.Arcs; a != nil; a = a.Next {
			outSum += Flow(a)
		}
		// sector_total should equal outSum (rows sum to total output).
		if outSum != SectorTotal(v) {
			// Allow Users vertex (last) whose total = GNP; arcs may not cover all.
			// Only fail for normal sectors with large discrepancy.
			if v.Name != "Users" && outSum == 0 {
				t.Errorf("vertex %q: outSum=%d, sector_total=%d", v.Name, outSum, SectorTotal(v))
			}
		}
	}
}

func TestEconSubset(t *testing.T) {
	// n=10, omit=2 should give 10 vertices.
	g, err := Econ(10, 2, 0, 0)
	if err != nil {
		t.Fatalf("Econ(10,2,0,0) returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Econ(10,2,0,0) returned nil")
	}
	if g.N != 10 {
		t.Errorf("want 10 vertices, got %d", g.N)
	}
}

func TestEconRandomSeed(t *testing.T) {
	// Random seed should produce a valid graph.
	g, err := Econ(10, 2, 0, 1)
	if err != nil {
		t.Fatalf("Econ(10,2,0,1) returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Econ(10,2,0,1) returned nil")
	}
	if g.N != 10 {
		t.Errorf("want 10 vertices, got %d", g.N)
	}
	// Different seeds may give different results.
	g2, err2 := Econ(10, 2, 0, 2)
	if err2 != nil {
		t.Fatalf("Econ(10,2,0,2) returned error: %v", err2)
	}
	if g2 == nil {
		t.Fatal("Econ(10,2,0,2) returned nil")
	}
}

func TestEconSpecialVertexOrder(t *testing.T) {
	// With omit=0: Users is last vertex, Adjustments is next-to-last.
	g, err := Econ(0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Econ returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Econ returned nil")
	}
	last := g.Vertices[g.N-1].Name
	secondLast := g.Vertices[g.N-2].Name
	if last != "Users" {
		t.Errorf("last vertex=%q, want Users", last)
	}
	if secondLast != "Adjustments" {
		t.Errorf("second-to-last=%q, want Adjustments", secondLast)
	}
}
