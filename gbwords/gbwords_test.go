//line gbwords.w:549
package gbwords

import (
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
)

const dataDir = "../data"

//line gbwords.w:570
func TestWordCounts(t *testing.T) {
	cases := []struct {
		name      string
		wt        []int64
		threshold int64
		want      int64
	}{
		{"흔함", []int64{1, 0, 0, 0, 0, 0, 0, 0, 0}, 1, 3300},
		{"흔함+고급", []int64{1, 1, 0, 0, 0, 0, 0, 0, 0}, 1, 4494},
		{"모두", nil, 0, 5757},
	}
	for _, c := range cases {
		g, err := Words(0, c.wt, c.threshold, 0, dataDir)
		if err != nil {
			t.Fatalf("%s: Words 실패: %v", c.name, err)
		}
		if g.N != c.want {
			t.Errorf("%s: 정점 수 = %d, 원함 %d", c.name, g.N, c.want)
		}
	}
}

//line gbwords.w:667
func TestDocumentedExamples(t *testing.T) {
	cases := []struct {
		name string
		w    []int64
		th   int64
		want int64
	}{
		{"흔함", []int64{1}, 1, 3300},
		{"드묾 아님", []int64{1, 1}, 1, 4494},
		{"모두", make([]int64, 9), 0, 5757},
	}
	for _, c := range cases {
		g, err := Words(0, c.w, c.th, 0, dataDir)
		if err != nil {
			t.Fatalf("%s: %v", c.name, err)
		}
		if g.N != c.want {
			t.Errorf("%s: 정점 수 = %d, 원함 %d", c.name, g.N, c.want)
		}
	}
}

//line gbwords.w:693
func TestLeastCommon(t *testing.T) {
	neg := []int64{-1, -1, -1, -1, -1, -1, -1, -1, -1}
	rare, err := Words(10, neg, -0x7fffffff, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if rare.N != 10 {
		t.Fatalf("정점 수 = %d, 원함 10", rare.N)
	}
	common, err := Words(2000, nil, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	for i := int64(0); i < rare.N; i++ {
		if FindWord(common, rare.Vertices[i].Name, nil) != nil {
			t.Errorf("%q가 흔한 2000개에도 있다", rare.Vertices[i].Name)
		}
	}
}

//line gbwords.w:597
func TestWordStructure(t *testing.T) {
	g, err := Words(2000, nil, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.ID != "words(2000,0,0,0)" {
		t.Errorf("ID = %q", g.ID)
	}
	if g.UtilTypes != "IZZZZZIZZZZZZZ" {
		t.Errorf("UtilTypes = %q", g.UtilTypes)
	}
	if g.N != 2000 {
		t.Fatalf("정점 수 = %d, 원함 2000", g.N)
	}
	for i := int64(1); i < g.N; i++ {
		if g.Vertices[i-1].U.I < g.Vertices[i].U.I {
			t.Fatalf("무게가 오름: 정점 %d(%d) < 정점 %d(%d)",
				i-1, g.Vertices[i-1].U.I, i, g.Vertices[i].U.I)
		}
	}

//line gbwords.w:621
	for v := range g.AllVertices() {
		for a := range v.AllArcs() {
			if a.Len != 1 {
				t.Fatalf("호 길이 = %d, 원함 1", a.Len)
			}
			k := a.A.I
			if k < 0 || k > 4 {
				t.Fatalf("차이 자리 = %d, 범위 밖", k)
			}
			diff := 0
			for p := 0; p < 5; p++ {
				if v.Name[p] != a.Tip.Name[p] {
					diff++
				}
			}
			if diff != 1 || v.Name[k] == a.Tip.Name[k] {
				t.Fatalf("%q와 %q는 자리 %d에서 한 글자만 다르지 않다",
					v.Name, a.Tip.Name, k)
			}
		}
	}

//line gbwords.w:618
}

//line gbwords.w:647
func TestWordDeterminism(t *testing.T) {
	g1, err := Words(500, nil, 0, 7, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	g2, err := Words(500, nil, 0, 7, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	for i := int64(0); i < g1.N; i++ {
		if g1.Vertices[i].Name != g2.Vertices[i].Name {
			t.Fatalf("정점 %d: %q != %q", i, g1.Vertices[i].Name, g2.Vertices[i].Name)
		}
	}
}

//line gbwords.w:718
func TestFindWord(t *testing.T) {
	g, err := Words(2000, nil, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	top := g.Vertices[0].Name
	if v := FindWord(g, top, nil); v != &g.Vertices[0] {
		t.Fatalf("FindWord(%q) = %v, 원함 첫 정점", top, v)
	}
	if v := FindWord(g, "22222", nil); v != nil {
		t.Errorf("FindWord(\"22222\") = %v, 원함 nil", v)
	}
	var neighbors []*Vertex
	FindWord(g, top, func(v *Vertex) { neighbors = append(neighbors, v) })
	for _, v := range neighbors {
		diff := 0
		for p := 0; p < 5; p++ {
			if top[p] != v.Name[p] {
				diff++
			}
		}
		if diff != 1 {
			t.Errorf("이웃 %q는 %q와 한 글자만 다르지 않다", v.Name, top)
		}
	}
}

//line gbwords.w:749
func TestWordBadSpecs(t *testing.T) {
	if _, err := Words(10, []int64{0, 0, 100000, 0, 0, 0, 0, 0, 0}, 0, 0, dataDir); err != gbgraph.BadSpecs {
		t.Errorf("err = %v, 원함 BadSpecs", err)
	}
	if _, err := Words(10, []int64{0, 0, 200000, 0, 0, 0, 0, 0, 0}, 0, 0, dataDir); err != gbgraph.VeryBadSpecs {
		t.Errorf("err = %v, 원함 VeryBadSpecs", err)
	}
}
