//line gbbooks.w:641
package gbbooks

import (
	"fmt"
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
)

const dataDir = "../data"

//line gbbooks.w:661
func TestAnnaFull(t *testing.T) {
	g, err := Book("anna", 0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 138 {
		t.Fatalf("N = %d, 원함 138", g.N)
	}
	if g.ID != `book("anna",138,0,1,239,0,0,0)` {
		t.Errorf("ID = %q", g.ID)
	}
	if g.M == 0 {
		t.Error("간선이 하나도 없다")
	}
}

//line gbbooks.w:681
func TestAnnaVertexFields(t *testing.T) {
	g, err := Book("anna", 0, 0, 0, 0, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	v := &g.Vertices[0]
	if v.Name == "" || v.Z.S == "" {
		t.Errorf("정점 이름/설명이 비었다: %q / %q", v.Name, v.Z.S)
	}
	if v.U.I <= 0 || v.U.I >= maxCode {
		t.Errorf("short_code = %d, 범위 밖", v.U.I)
	}
}

//line gbbooks.w:700
func TestAnnaKareninEntry(t *testing.T) {
	g, err := Book("anna", 0, 0, 0, 0, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	for i := range g.N {
		v := &g.Vertices[i]
		if v.U.I != 10*36+21 {
			continue
		}
		if v.Name != "Alexey Alexandrovitch Karenin" {
			t.Errorf("이름 = %q", v.Name)
		}
		if v.Z.S != "minister of state" {
			t.Errorf("설명 = %q", v.Z.S)
		}
		return
	}
	t.Fatal("코드 AL인 인물을 찾지 못했다")
}

//line gbbooks.w:725
func TestAnnaSelect(t *testing.T) {
	g, err := Book("anna", 50, 0, 0, 0, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 50 {
		t.Fatalf("N = %d, 원함 50", g.N)
	}
	sub, err := Book("anna", 50, 0, 10, 120, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if sub.N != 50 {
		t.Fatalf("N = %d, 원함 50", sub.N)
	}
	if sub.M > g.M {
		t.Errorf("장을 한정했는데 간선이 늘었다: %d > %d", sub.M, g.M)
	}
}

//line gbbooks.w:749
func TestDavidExclude(t *testing.T) {
	g, err := Book("david", 0, 1, 0, 0, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 86 {
		t.Errorf("N = %d, 원함 86", g.N)
	}
	if g.ID != `book("david",87,1,1,64,1,1,0)` {
		t.Errorf("ID = %q", g.ID)
	}
}

//line gbbooks.w:768
func TestChapterCounts(t *testing.T) {
	for _, c := range []struct {
		title        string
		chars, chaps int64
	}{
		{"anna", 138, 239},
		{"david", 87, 64},
		{"jean", 80, 356},
		{"huck", 74, 43},
		{"homer", 561, 24},
	} {

//line gbbooks.w:784
		g, err := Book(c.title, 0, 0, 0, 0, 1, 1, 0, dataDir)
		if err != nil {
			t.Fatalf("%s: %v", c.title, err)
		}
		if g.N != c.chars {
			t.Errorf("%s: N = %d, 원함 %d", c.title, g.N, c.chars)
		}
		want := fmt.Sprintf("book(%q,%d,0,1,%d,1,1,0)", c.title, c.chars, c.chaps)
		if g.ID != want {
			t.Errorf("%s: ID = %q, 원함 %q", c.title, g.ID, want)
		}

//line gbbooks.w:780
	}
}

//line gbbooks.w:800
func TestBiBookAnna(t *testing.T) {
	g, err := BiBook("anna", 50, 0, 10, 120, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 50+111 {
		t.Fatalf("N = %d, 원함 161", g.N)
	}
	if g.N1() != 50 {
		t.Errorf("N1 = %d, 원함 50", g.N1())
	}
	if !isBipartite(g) {
		t.Error("이분 그래프가 아니다")
	}
}

//line gbbooks.w:821
func TestBiBookChapterNames(t *testing.T) {
	g, err := BiBook("jean", 80, 0, 0, 0, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	first, last := &g.Vertices[g.N1()], &g.Vertices[g.N-1]
	if first.Name != "1.1.1" {
		t.Errorf("첫 장 이름 = %q, 원함 1.1.1", first.Name)
	}
	if last.Name != "5.9.6" {
		t.Errorf("끝 장 이름 = %q, 원함 5.9.6", last.Name)
	}
}

//line gbbooks.w:839
func isBipartite(g *gbgraph.Graph) bool {
	n1 := g.N1()
	for i := int64(0); i < g.N; i++ {
		left := i < n1
		for a := range g.Vertices[i].AllArcs() {
			if (g.Index(a.Tip) < n1) == left {
				return false
			}
		}
	}
	return true
}
