package save

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/sjnam/go-sgb/graph"
)

// makeSimpleGraph builds a small directed graph for round-trip tests.
//
//	3 vertices (A, B, C), 4 arcs: A→B(1), B→A(1), B→C(2), C→B(2)
func makeSimpleGraph() *graph.Graph {
	g := graph.NewGraph(3)
	g.ID = "simple_test_graph"
	g.Vertices[0].Name = "A"
	g.Vertices[1].Name = "B"
	g.Vertices[2].Name = "C"
	g.NewEdge(&g.Vertices[0], &g.Vertices[1], 1)
	g.NewEdge(&g.Vertices[1], &g.Vertices[2], 2)
	return g
}

func tmpFile(t *testing.T) string {
	t.Helper()
	return filepath.Join(t.TempDir(), "test.gb")
}

// ---- SaveGraph tests ----

func TestSaveGraphNilReturnsNeg1(t *testing.T) {
	if got := SaveGraph(nil, "/tmp/never.gb"); got != -1 {
		t.Errorf("SaveGraph(nil,...) = %d, want -1", got)
	}
}

func TestSaveGraphBadPathReturnsNeg2(t *testing.T) {
	g := makeSimpleGraph()
	if got := SaveGraph(g, "/no/such/directory/x.gb"); got != -2 {
		t.Errorf("SaveGraph(bad path) = %d, want -2", got)
	}
}

func TestSaveGraphCreatesFile(t *testing.T) {
	g := makeSimpleGraph()
	path := tmpFile(t)
	if ret := SaveGraph(g, path); ret != 0 {
		t.Fatalf("SaveGraph returned %d", ret)
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("file not created: %v", err)
	}
}

func TestSaveGraphFileHasHeader(t *testing.T) {
	g := makeSimpleGraph()
	path := tmpFile(t)
	SaveGraph(g, path)
	data, _ := os.ReadFile(path)
	content := string(data)
	if len(content) < 30 || content[:30] != "* GraphBase graph (util_types " {
		t.Errorf("header missing or wrong: %q", content[:min(60, len(content))])
	}
}

func TestSaveGraphReturnsZeroOnSuccess(t *testing.T) {
	g := makeSimpleGraph()
	path := tmpFile(t)
	if ret := SaveGraph(g, path); ret != 0 {
		t.Errorf("SaveGraph returned anomaly %d, want 0", ret)
	}
}

// ---- RestoreGraph tests ----

func TestRoundTripN(t *testing.T) {
	g := makeSimpleGraph()
	path := tmpFile(t)
	SaveGraph(g, path)
	g2, err := RestoreGraph(path)
	if err != nil {
		t.Fatalf("RestoreGraph failed: %v", err)
	}
	if g2.N != g.N {
		t.Errorf("N=%d, want %d", g2.N, g.N)
	}
}

func TestRoundTripM(t *testing.T) {
	g := makeSimpleGraph()
	path := tmpFile(t)
	SaveGraph(g, path)
	g2, err := RestoreGraph(path)
	if err != nil {
		t.Fatalf("RestoreGraph failed: %v", err)
	}
	if g2.M != g.M {
		t.Errorf("M=%d, want %d", g2.M, g.M)
	}
}

func TestRoundTripID(t *testing.T) {
	g := makeSimpleGraph()
	path := tmpFile(t)
	SaveGraph(g, path)
	g2, err := RestoreGraph(path)
	if err != nil {
		t.Fatalf("RestoreGraph failed: %v", err)
	}
	if g2.ID != g.ID {
		t.Errorf("ID=%q, want %q", g2.ID, g.ID)
	}
}

func TestRoundTripUtilTypes(t *testing.T) {
	g := makeSimpleGraph()
	path := tmpFile(t)
	SaveGraph(g, path)
	g2, err := RestoreGraph(path)
	if err != nil {
		t.Fatalf("RestoreGraph failed: %v", err)
	}
	if g2.UtilTypes != g.UtilTypes {
		t.Errorf("UtilTypes=%q, want %q", g2.UtilTypes, g.UtilTypes)
	}
}

func TestRoundTripVertexNames(t *testing.T) {
	g := makeSimpleGraph()
	path := tmpFile(t)
	SaveGraph(g, path)
	g2, err := RestoreGraph(path)
	if err != nil {
		t.Fatalf("RestoreGraph failed: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		if g2.Vertices[i].Name != g.Vertices[i].Name {
			t.Errorf("v[%d].Name=%q, want %q", i, g2.Vertices[i].Name, g.Vertices[i].Name)
		}
	}
}

func TestRoundTripArcLengths(t *testing.T) {
	g := makeSimpleGraph()
	path := tmpFile(t)
	SaveGraph(g, path)
	g2, err := RestoreGraph(path)
	if err != nil {
		t.Fatalf("RestoreGraph failed: %v", err)
	}
	// Collect lengths from both graphs for comparison.
	lenSet := func(gg *graph.Graph) map[int64]int {
		counts := make(map[int64]int)
		for i := int64(0); i < gg.N; i++ {
			for a := gg.Vertices[i].Arcs; a != nil; a = a.Next {
				counts[a.Len]++
			}
		}
		return counts
	}
	orig := lenSet(g)
	got := lenSet(g2)
	for l, cnt := range orig {
		if got[l] != cnt {
			t.Errorf("arc length %d: count %d, want %d", l, got[l], cnt)
		}
	}
}

func TestRoundTripArcTips(t *testing.T) {
	g := makeSimpleGraph()
	path := tmpFile(t)
	SaveGraph(g, path)
	g2, err := RestoreGraph(path)
	if err != nil {
		t.Fatalf("RestoreGraph failed: %v", err)
	}
	// Build adjacency sets for both graphs (by name pairs).
	edges := func(gg *graph.Graph) map[[2]string]bool {
		m := make(map[[2]string]bool)
		for i := int64(0); i < gg.N; i++ {
			for a := gg.Vertices[i].Arcs; a != nil; a = a.Next {
				if a.Tip != nil {
					m[[2]string{gg.Vertices[i].Name, a.Tip.Name}] = true
				}
			}
		}
		return m
	}
	orig := edges(g)
	got := edges(g2)
	for e := range orig {
		if !got[e] {
			t.Errorf("missing edge %v→%v in restored graph", e[0], e[1])
		}
	}
	for e := range got {
		if !orig[e] {
			t.Errorf("extra edge %v→%v in restored graph", e[0], e[1])
		}
	}
}

func TestRestoreGraphBadFile(t *testing.T) {
	_, err := RestoreGraph("/no/such/file.gb")
	if err == nil {
		t.Fatal("expected error for nonexistent file")
	}
	if !errors.Is(err, graph.ErrEarlyDataFault) {
		t.Errorf("want ErrEarlyDataFault, got %v", err)
	}
}

func TestRestoreGraphBadChecksum(t *testing.T) {
	g := makeSimpleGraph()
	path := tmpFile(t)
	SaveGraph(g, path)
	// Corrupt one byte in the data (not in comment lines).
	data, _ := os.ReadFile(path)
	// Find the graph record line (second line, not starting with *).
	for i, b := range data {
		if b == '\n' && i+1 < len(data) && data[i+1] != '*' {
			data[i+2] ^= 1 // flip a bit
			break
		}
	}
	os.WriteFile(path, data, 0o644)
	_, err := RestoreGraph(path)
	if err == nil {
		t.Error("expected error for corrupted file")
	}
}

// ---- Utility field round-trip tests ----

func TestRoundTripIntUtilField(t *testing.T) {
	g := graph.NewGraph(2)
	g.ID = "util_int_test"
	g.Vertices[0].Name = "x"
	g.Vertices[1].Name = "y"
	g.NewArc(&g.Vertices[0], &g.Vertices[1], 5)
	// Use vertex X as int field.
	ut := []byte(g.UtilTypes)
	ut[3] = 'I'
	g.UtilTypes = string(ut)
	g.Vertices[0].X = int64(42)
	g.Vertices[1].X = int64(-7)

	path := tmpFile(t)
	if ret := SaveGraph(g, path); ret != 0 {
		t.Fatalf("SaveGraph returned anomaly %d", ret)
	}
	g2, err := RestoreGraph(path)
	if err != nil {
		t.Fatalf("RestoreGraph failed: %v", err)
	}
	if v, _ := g2.Vertices[0].X.(int64); v != 42 {
		t.Errorf("Vertices[0].X=%v, want 42", g2.Vertices[0].X)
	}
	if v, _ := g2.Vertices[1].X.(int64); v != -7 {
		t.Errorf("Vertices[1].X=%v, want -7", g2.Vertices[1].X)
	}
}

func TestRoundTripStringUtilField(t *testing.T) {
	g := graph.NewGraph(1)
	g.ID = "util_str_test"
	g.Vertices[0].Name = "root"
	ut := []byte(g.UtilTypes)
	ut[0] = 'S'
	g.UtilTypes = string(ut)
	g.Vertices[0].U = "hello world"

	path := tmpFile(t)
	SaveGraph(g, path)
	g2, err := RestoreGraph(path)
	if err != nil {
		t.Fatalf("RestoreGraph failed: %v", err)
	}
	if s, _ := g2.Vertices[0].U.(string); s != "hello world" {
		t.Errorf("U=%q, want %q", s, "hello world")
	}
}

func TestRoundTripGraphUtilInt(t *testing.T) {
	g := graph.NewGraph(1)
	g.ID = "graph_util_int"
	g.Vertices[0].Name = "v"
	ut := []byte(g.UtilTypes)
	ut[8] = 'I'
	g.UtilTypes = string(ut)
	g.UU = int64(999)

	path := tmpFile(t)
	SaveGraph(g, path)
	g2, err := RestoreGraph(path)
	if err != nil {
		t.Fatalf("RestoreGraph failed: %v", err)
	}
	if v, _ := g2.UU.(int64); v != 999 {
		t.Errorf("UU=%v, want 999", g2.UU)
	}
}

func TestRoundTripEmptyGraph(t *testing.T) {
	g := graph.NewGraph(0)
	g.ID = "empty"
	path := tmpFile(t)
	if ret := SaveGraph(g, path); ret != 0 {
		t.Fatalf("SaveGraph(empty) = %d", ret)
	}
	g2, err := RestoreGraph(path)
	if err != nil {
		t.Fatalf("RestoreGraph failed: %v", err)
	}
	if g2.N != 0 {
		t.Errorf("N=%d, want 0", g2.N)
	}
	if g2.M != 0 {
		t.Errorf("M=%d, want 0", g2.M)
	}
}

// TestSaveGraphAnomalyBadTypeCode verifies that an invalid util_types char
// triggers BadTypeCode and that the file is still readable.
func TestSaveGraphAnomalyBadTypeCode(t *testing.T) {
	g := graph.NewGraph(1)
	g.ID = "bad_type"
	g.Vertices[0].Name = "v"
	g.UtilTypes = "XXXXXXXXXXXXXX" // all invalid

	path := tmpFile(t)
	ret := SaveGraph(g, path)
	if ret&BadTypeCode == 0 {
		t.Errorf("expected BadTypeCode anomaly, got %d", ret)
	}
	// File should still be readable.
	g2, err := RestoreGraph(path)
	if err != nil {
		t.Errorf("RestoreGraph returned error after bad-type-code save: %v", err)
	}
	_ = g2
}
