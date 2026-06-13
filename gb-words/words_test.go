package gbwords

import (
	"testing"

	gbgraph "github.com/sjnam/go-sgb/gb-graph"
	"github.com/sjnam/go-sgb/gb-io"
)

func init() {
	gbio.DataDirectory = "../data/"
}

func TestWords2000(t *testing.T) {
	g, _, err := Words(2000, nil, 0, 0)
	if err != nil {
		t.Fatalf("Words(2000,nil,0,0) returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Words(2000,nil,0,0) returned nil")
	}
	if g.N != 2000 {
		t.Errorf("expected 2000 vertices, got %d", g.N)
	}
	if g.UtilTypes != "IZZZZZIZZZZZZZ" {
		t.Errorf("wrong util types: %q", g.UtilTypes)
	}
}

func TestWordsAllQualifying(t *testing.T) {
	g, _, err := Words(0, nil, 0, 0)
	if err != nil {
		t.Fatalf("Words(0,nil,0,0) returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Words(0,nil,0,0) returned nil")
	}
	if g.N != 5757 {
		t.Errorf("expected 5757 vertices, got %d", g.N)
	}
}

func TestWordsCommonOnly(t *testing.T) {
	// a=1, b=0, w1..w7=0 → only common words (weight=1) qualify at threshold=1.
	wt := make([]int64, 9)
	wt[0] = 1
	g, _, err := Words(0, wt, 1, 0)
	if err != nil {
		t.Fatalf("Words(common only) returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Words(common only) returned nil")
	}
	if g.N != 3300 {
		t.Errorf("expected 3300 common words, got %d", g.N)
	}
}

func TestWordsWeightSorted(t *testing.T) {
	g, _, err := Words(2000, nil, 0, 0)
	if err != nil {
		t.Fatalf("Words returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Words returned nil")
	}
	// Vertices must appear in non-increasing weight order.
	for i := 1; i < len(g.Vertices); i++ {
		w0 := Weight(&g.Vertices[i-1])
		w1 := Weight(&g.Vertices[i])
		if w0 < w1 {
			t.Errorf("vertex %d weight %d < vertex %d weight %d (not sorted)",
				i-1, w0, i, w1)
			break
		}
	}
}

func TestWordsEdgesLoc(t *testing.T) {
	g, _, err := Words(2000, nil, 0, 0)
	if err != nil {
		t.Fatalf("Words returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Words returned nil")
	}
	// Every arc must have loc in [0,4] and the two words must differ exactly there.
	for i := range g.Vertices {
		v := &g.Vertices[i]
		for a := v.Arcs; a != nil; a = a.Next {
			loc := Loc(a)
			if loc < 0 || loc > 4 {
				t.Errorf("%s→%s: invalid loc %d", v.Name, a.Tip.Name, loc)
				continue
			}
			u, w := v.Name, a.Tip.Name
			diffs := 0
			diffPos := int64(-1)
			for p := range 5 {
				if u[p] != w[p] {
					diffs++
					diffPos = int64(p)
				}
			}
			if diffs != 1 {
				t.Errorf("%s↔%s: expected 1 diff, got %d", u, w, diffs)
			} else if diffPos != loc {
				t.Errorf("%s↔%s: diff at pos %d but loc=%d", u, w, diffPos, loc)
			}
		}
	}
}

func TestWordsWordsVertex(t *testing.T) {
	g, _, err := Words(2000, nil, 0, 0)
	if err != nil {
		t.Fatalf("Words returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Words returned nil")
	}

	var wordsV *gbgraph.Vertex
	for i := range g.Vertices {
		if g.Vertices[i].Name == "words" {
			wordsV = &g.Vertices[i]
			break
		}
	}
	if wordsV == nil {
		t.Fatal(`vertex "words" not found in top-2000`)
	}

	neighbors := map[string]bool{}
	for a := wordsV.Arcs; a != nil; a = a.Next {
		neighbors[a.Tip.Name] = true
	}

	// From the CWEB documentation: words ↔ cords, wards, woods, worms, wordy.
	expected := []string{"cords", "wards", "woods", "worms", "wordy"}
	found := 0
	for _, w := range expected {
		if neighbors[w] {
			found++
		}
	}
	if found == 0 {
		t.Errorf("none of %v found as neighbors of 'words'; got %v", expected, neighbors)
	}
}

func TestFindWordExact(t *testing.T) {
	_, ix, err := Words(2000, nil, 0, 0)
	if err != nil {
		t.Fatalf("Words returned error: %v", err)
	}

	v := ix.FindWord("words", nil)
	if v == nil {
		t.Fatal(`FindWord("words") returned nil`)
	}
	if v.Name != "words" {
		t.Errorf("expected %q, got %q", "words", v.Name)
	}
}

func TestFindWordMissing(t *testing.T) {
	_, ix, err := Words(2000, nil, 0, 0)
	if err != nil {
		t.Fatalf("Words returned error: %v", err)
	}
	v := ix.FindWord("zzzzz", nil)
	if v != nil {
		t.Errorf("expected nil for absent word, got %q", v.Name)
	}
}

func TestFindWordNeighbors(t *testing.T) {
	// FindWord only calls f when the query word is NOT in the graph.
	// Use "wordz" (not a real word) so f is invoked for near-matches like "words".
	_, ix, err := Words(2000, nil, 0, 0)
	if err != nil {
		t.Fatalf("Words returned error: %v", err)
	}

	query := "wordz"
	var neighbors []string
	v := ix.FindWord(query, func(v *gbgraph.Vertex) {
		neighbors = append(neighbors, v.Name)
	})
	if v != nil {
		t.Fatalf("expected %q not in graph, but FindWord returned %q", query, v.Name)
	}
	if len(neighbors) == 0 {
		t.Fatalf("FindWord(%q) found no neighbors", query)
	}
	for _, nb := range neighbors {
		diffs := 0
		for p := range 5 {
			if nb[p] != query[p] {
				diffs++
			}
		}
		if diffs != 1 {
			t.Errorf("neighbor %q differs in %d positions from %q", nb, diffs, query)
		}
	}
}

func TestWordsID(t *testing.T) {
	g, _, err := Words(2000, nil, 0, 0)
	if err != nil {
		t.Fatalf("Words returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Words returned nil")
	}
	if g.ID != "words(2000,0,0,0)" {
		t.Errorf("unexpected ID: %q", g.ID)
	}
}

func TestWordsBadSpecs(t *testing.T) {
	wt := make([]int64, 9)
	wt[2] = 0x40000000
	g, _, err := Words(10, wt, 0, 0)
	if err == nil {
		t.Fatal("expected error for bad weight vector")
	}
	if g != nil {
		t.Fatal("expected nil graph for bad weight vector")
	}
}
