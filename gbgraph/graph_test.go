package gbgraph

import (
	"strings"
	"testing"
)

// TestNewGraph mirrors the "Create a small graph" section of test_graph.c.
func TestNewGraph(t *testing.T) {
	g := NewGraph(2)
	if g == nil {
		t.Fatal("NewGraph(2) returned nil")
	}
	if g.N != 2 {
		t.Errorf("N = %d, want 2", g.N)
	}
	if len(g.Vertices) != 2+ExtraN {
		t.Errorf("len(Vertices) = %d, want %d", len(g.Vertices), 2+ExtraN)
	}
	if g.UtilTypes != "ZZZZZZZZZZZZZZ" {
		t.Errorf("UtilTypes = %q, want all-Z", g.UtilTypes)
	}
}

// TestEdgesAndArcs mirrors "Check that the small graph is still there" in
// test_graph.c:
//
//	gb_new_edge(v, u, -1)
//	gb_new_edge(u, u, 1)
//	gb_new_arc(v, u, -1)
//
// The final assertion in C is:
//
//	v->name[7] + g->n  ==  v->arcs->next->tip->name[7] + g->m - 2
//	'1' + 2            ==  '0'           + 5            - 2
//	51  + 2  = 53      ==  48            + 5 - 2 = 51   → FAIL in C too?
//
// Re-reading: after gb_new_edge(v,u,-1), gb_new_edge(u,u,1), gb_new_arc(v,u,-1):
//
//	m = 2 + 2 + 1 = 5
//	v->arcs chain: arc(v→u,-1) from gb_new_arc  →  arc(u→v? no...)
//
// Let's just verify the counts and structure directly.
func TestEdgesAndArcs(t *testing.T) {
	g := NewGraph(2)
	u := &g.Vertices[0]
	v := &g.Vertices[1]
	u.Name = g.SaveString("vertex 0")
	v.Name = g.SaveString("vertex 1")

	// Both names start with "vertex " (7 chars equal).
	if !strings.HasPrefix(u.Name, "vertex ") || !strings.HasPrefix(v.Name, "vertex ") {
		t.Error("SaveString corrupted names")
	}
	if u.Name[:7] != v.Name[:7] {
		t.Error("first 7 chars of names differ")
	}

	// gb_new_edge(v, u, -1)  →  m = 2
	g.NewEdge(v, u, -1)
	if g.M != 2 {
		t.Errorf("after NewEdge: M = %d, want 2", g.M)
	}

	// gb_new_edge(u, u, 1)   →  m = 4  (self-loop, two arcs)
	g.NewEdge(u, u, 1)
	if g.M != 4 {
		t.Errorf("after second NewEdge: M = %d, want 4", g.M)
	}

	// gb_new_arc(v, u, -1)   →  m = 5
	g.NewArc(v, u, -1)
	if g.M != 5 {
		t.Errorf("after NewArc: M = %d, want 5", g.M)
	}
	if g.N != 2 {
		t.Errorf("N changed to %d, want 2", g.N)
	}

	// The original C test:
	//   v->name[7] + g->n  ==  v->arcs->next->tip->name[7] + g->m - 2
	//   i.e. '1'+2 == tip->name[7]+5-2   →   53 == tip->name[7]+3
	//   tip->name[7] must be '0' (50) → 50+3=53 ✓
	//
	// v->arcs is the most recently prepended arc: gb_new_arc(v,u,-1).
	// v->arcs->next is the arc from the first gb_new_edge(v,u,-1).
	// Its tip (with u<v? depends on layout) should be u ("vertex 0").
	vArc := v.Arcs
	if vArc == nil {
		t.Fatal("v.Arcs is nil")
	}
	if vArc.Next == nil {
		t.Fatal("v.Arcs.Next is nil")
	}
	tip := vArc.Next.Tip
	if tip == nil {
		t.Fatal("v.Arcs.Next.Tip is nil")
	}

	lhs := int(v.Name[7]) + int(g.N)       // '1' + 2 = 53
	rhs := int(tip.Name[7]) + int(g.M) - 2 // tip.name[7] + 5 - 2
	if lhs != rhs {
		t.Errorf("structural check failed: v.Name[7]+N=%d, tip.Name[7]+M-2=%d",
			lhs, rhs)
	}
}

// TestHashTable verifies hash_setup and hash_lookup.
func TestHashTable(t *testing.T) {
	g := NewGraph(4)
	names := []string{"alice", "bob", "carol", "dave"}
	for i, name := range names {
		g.Vertices[i].Name = name
	}

	g.HashSetup()

	for _, name := range names {
		v := g.HashLookup(name)
		if v == nil {
			t.Errorf("HashLookup(%q) returned nil", name)
			continue
		}
		if v.Name != name {
			t.Errorf("HashLookup(%q) returned vertex %q", name, v.Name)
		}
	}

	if v := g.HashLookup("nobody"); v != nil {
		t.Errorf("HashLookup(\"nobody\") returned %v, want nil", v)
	}

	if g.UtilTypes[:2] != "VV" {
		t.Errorf("UtilTypes[:2] = %q after HashSetup, want \"VV\"", g.UtilTypes[:2])
	}
}

// TestMakeCompoundID checks the ID truncation logic.
func TestMakeCompoundID(t *testing.T) {
	g := NewGraph(1)
	gg := NewGraph(1)
	gg.ID = "inner"

	MakeCompoundID(g, "prefix(", gg, ")")
	if g.ID != "prefix(inner)" {
		t.Errorf("ID = %q, want %q", g.ID, "prefix(inner)")
	}

	// Force truncation: make gg.ID very long.
	gg.ID = strings.Repeat("x", IDFieldSize)
	MakeCompoundID(g, "a(", gg, ")")
	if len(g.ID) >= IDFieldSize {
		t.Errorf("ID length %d not truncated below %d", len(g.ID), IDFieldSize)
	}
	if !strings.Contains(g.ID, "...)") {
		t.Errorf("truncated ID %q missing ellipsis", g.ID)
	}
}

// TestEdgeTrick verifies the adjacency invariant for NewEdge.
// When u < v (by address), u.Arcs and u.Arcs+1 should be the pair.
func TestEdgeTrick(t *testing.T) {
	g := NewGraph(2)
	u := &g.Vertices[0]
	v := &g.Vertices[1]
	g.NewEdge(u, v, 7)

	a := u.Arcs
	b := v.Arcs
	if a == nil || b == nil {
		t.Fatal("arcs are nil after NewEdge")
	}
	if a.Tip != v {
		t.Errorf("u.Arcs.Tip = %v, want v", a.Tip)
	}
	if b.Tip != u {
		t.Errorf("v.Arcs.Tip = %v, want u", b.Tip)
	}
	if a.Len != 7 || b.Len != 7 {
		t.Errorf("arc lengths %d, %d, want both 7", a.Len, b.Len)
	}
}
