package books

import (
	"testing"

	"github.com/sjnam/go-sgb/io"
)

func init() {
	io.DataDirectory = "../data/"
}

// -----------------------------------------------------------------------
// Book (encounter graph)
// -----------------------------------------------------------------------

func TestBookAnnaAll(t *testing.T) {
	g, err := Book("anna", 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Book(anna,all) returned error: %v", err)
	}
	if g == nil {
		t.Fatalf("Book(anna,all) returned nil")
	}
	// anna.dat has 138 characters
	if g.N != 138 {
		t.Errorf("N = %d, want 138", g.N)
	}
	// every vertex must have a non-empty name
	for i := int64(0); i < g.N; i++ {
		if g.Vertices[i].Name == "" {
			t.Errorf("vertex %d has empty name", i)
		}
	}
}

func TestBookAnnaTop50(t *testing.T) {
	g, err := Book("anna", 50, 0, 0, 0, 1, 1, 0)
	if err != nil {
		t.Fatalf("Book(anna,50) returned error: %v", err)
	}
	if g == nil {
		t.Fatalf("Book(anna,50) returned nil")
	}
	if g.N != 50 {
		t.Errorf("N = %d, want 50", g.N)
	}
}

func TestBookAnnaExclude1(t *testing.T) {
	// x=1 drops the single highest-weight character
	g, err := Book("anna", 50, 1, 0, 0, 1, 1, 0)
	if err != nil {
		t.Fatalf("Book(anna,50,1) returned error: %v", err)
	}
	if g == nil {
		t.Fatalf("Book(anna,50,1) returned nil")
	}
	if g.N != 49 {
		t.Errorf("N = %d, want 49", g.N)
	}
}

func TestBookAnnaChapterRange(t *testing.T) {
	// Chapters 1-50 only
	g, err := Book("anna", 0, 0, 1, 50, 1, 0, 0)
	if err != nil {
		t.Fatalf("Book(anna,chaps 1-50) returned error: %v", err)
	}
	if g == nil {
		t.Fatalf("Book(anna,chaps 1-50) returned nil")
	}
	// All 138 characters but edges only from chapters 1–50
	if g.N != 138 {
		t.Errorf("N = %d, want 138", g.N)
	}
}

func TestBookChapters(t *testing.T) {
	Book("anna", 0, 0, 0, 0, 0, 0, 0)
	if Chapters != 239 {
		t.Errorf("Chapters = %d, want 239 for anna", Chapters)
	}
	if ChapName[1] == "" {
		t.Errorf("ChapName[1] is empty")
	}
}

func TestBookDavid(t *testing.T) {
	g, err := Book("david", 0, 1, 0, 0, 1, 1, 0)
	if err != nil {
		t.Fatalf("Book(david,x=1) returned error: %v", err)
	}
	if g == nil {
		t.Fatalf("Book(david,x=1) returned nil")
	}
	// david.dat has 87 characters; x=1 → 86 vertices
	if g.N != 86 {
		t.Errorf("N = %d, want 86", g.N)
	}
}

func TestBookID(t *testing.T) {
	g, err := Book("anna", 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Book(anna) returned error: %v", err)
	}
	if g == nil {
		t.Fatal("nil graph")
	}
	if g.ID == "" {
		t.Error("ID is empty")
	}
}

func TestBookUtilFields(t *testing.T) {
	g, err := Book("anna", 0, 0, 0, 0, 1, 1, 0)
	if err != nil {
		t.Fatalf("Book(anna) returned error: %v", err)
	}
	if g == nil {
		t.Fatal("nil graph")
	}
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		if ShortCode(v) == 0 {
			t.Errorf("vertex %d: ShortCode = 0", i)
		}
		if Desc(v) == "" {
			t.Errorf("vertex %d (%s): Desc is empty", i, v.Name)
		}
	}
}

func TestBookChapNo(t *testing.T) {
	g, err := Book("anna", 0, 0, 0, 0, 1, 1, 0)
	if err != nil {
		t.Fatalf("Book(anna) returned error: %v", err)
	}
	if g == nil {
		t.Fatal("nil graph")
	}
	// Every arc should have a non-zero chapter number
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if ChapNo(a) == 0 {
				t.Errorf("arc from vertex %d has ChapNo=0", i)
			}
		}
	}
}

// -----------------------------------------------------------------------
// BiBook (bipartite graph)
// -----------------------------------------------------------------------

func TestBiBookAnna(t *testing.T) {
	// bi_book("anna",50,0,10,120,1,1,0) → 50 characters + 111 chapters
	g, err := BiBook("anna", 50, 0, 10, 120, 1, 1, 0)
	if err != nil {
		t.Fatalf("BiBook(anna,50,10,120) returned error: %v", err)
	}
	if g == nil {
		t.Fatalf("BiBook(anna,50,10,120) returned nil")
	}
	// chapter vertices: 120-10+1 = 111
	if g.N != 50+111 {
		t.Errorf("N = %d, want %d", g.N, 50+111)
	}
	if g.N1() != 50 {
		t.Errorf("N1 = %d, want 50", g.N1())
	}
}

func TestBiBookChapterNames(t *testing.T) {
	BiBook("anna", 0, 0, 0, 0, 0, 0, 0)
	if Chapters != 239 {
		t.Errorf("Chapters = %d, want 239", Chapters)
	}
}
