//line gbmiles.w:396
package gbmiles

import (
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
)

const dataDir = "../data"

//line gbmiles.w:417
func TestPopulationOrder(t *testing.T) {
	g, err := Miles(100, 0, 0, 1, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.ID != "miles(100,0,0,1,0,99,0)" {
		t.Errorf("ID = %q", g.ID)
	}
	if g.UtilTypes != "ZZIIIIZZZZZZZZ" {
		t.Errorf("UtilTypes = %q", g.UtilTypes)
	}
	want := []struct {
		name string
		pop  int64
	}{
		{"San Diego, CA", 875538},
		{"San Antonio, TX", 786023},
		{"San Francisco, CA", 678974},
		{"Washington, DC", 638432},
	}
	for i, w := range want {
		if g.Vertices[i].Name != w.name || g.Vertices[i].W.I != w.pop {
			t.Errorf("정점 %d = %q(%d), 원함 %q(%d)",
				i, g.Vertices[i].Name, g.Vertices[i].W.I, w.name, w.pop)
		}
	}
}

//line gbmiles.w:449
func TestCompleteGraph(t *testing.T) {
	g, err := Miles(0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 128 {
		t.Fatalf("정점 수 = %d, 원함 128", g.N)
	}
	if g.M != 2*8128 {
		t.Errorf("호 수 = %d, 원함 %d", g.M, 2*8128)
	}
	for v := range g.AllVertices() {
		for a := range v.AllArcs() {
			if a.Len <= 0 {
				t.Fatalf("간선 길이 = %d", a.Len)
			}
			if a.Len != a.Partner.Len {
				t.Fatalf("짝 호 길이가 다름: %d != %d", a.Len, a.Partner.Len)
			}
		}
	}
}

//line gbmiles.w:476
func vertexNamed(g *gbgraph.Graph, name string) *gbgraph.Vertex {
	for v := range g.AllVertices() {
		if v.Name == name {
			return v
		}
	}
	return nil
}

func TestKnownDistance(t *testing.T) {
	g, err := Miles(0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	w := vertexNamed(g, "Worcester, MA")
	y := vertexNamed(g, "Youngstown, OH")
	if w == nil || y == nil {
		t.Fatal("Worcester나 Youngstown을 찾지 못함")
	}
	for a := range w.AllArcs() {
		if a.Tip == y {
			if a.Len != 604 {
				t.Errorf("Worcester-Youngstown = %d, 원함 604", a.Len)
			}
			return
		}
	}
	t.Error("Worcester-Youngstown 간선이 없다")
}

//line gbmiles.w:511
func TestMutualNearest(t *testing.T) {
	g, err := Miles(50, 0, 0, 0, 0, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.ID != "miles(50,0,0,0,0,1,0)" {
		t.Errorf("ID = %q", g.ID)
	}
	if g.M/2 >= 50 { // 성긴 그래프: 간선이 정점 수보다 적다
		t.Errorf("간선 수 = %d, 너무 많다", g.M/2)
	}
	if g.M == 0 {
		t.Error("간선이 하나도 없다")
	}
}

//line gbmiles.w:530
func TestMilesBadSpecs(t *testing.T) {
	if _, err := Miles(10, 200000, 0, 0, 0, 0, 0, dataDir); err != gbgraph.BadSpecs {
		t.Errorf("err = %v, 원함 BadSpecs", err)
	}
	if _, err := Miles(10, 0, 0, 200, 0, 0, 0, dataDir); err != gbgraph.BadSpecs {
		t.Errorf("err = %v, 원함 BadSpecs", err)
	}
}

//line gbmiles.w:544
func TestTriangleInequality(t *testing.T) {
	g, err := Miles(40, 0, 0, 1, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}

//line gbmiles.w:569
	d := make([][]int64, g.N)
	for i := range d {
		d[i] = make([]int64, g.N)
	}
	for u := int64(0); u < g.N; u++ {
		for a := range g.Vertices[u].AllArcs() {
			d[u][g.Index(a.Tip)] = a.Len
		}
	}

//line gbmiles.w:550
	for u := int64(0); u < g.N; u++ {
		for v := int64(0); v < g.N; v++ {
			for w := int64(0); w < g.N; w++ {
				if u == v || v == w || u == w {
					continue
				}
				if d[u][v]+d[v][w] < d[u][w] {
					t.Fatalf("삼각 부등식 위반: %s→%s→%s (%d+%d < %d)",
						g.Vertices[u].Name, g.Vertices[v].Name, g.Vertices[w].Name,
						d[u][v], d[v][w], d[u][w])
				}
			}
		}
	}
}

//line gbmiles.w:584
func TestCoordinateRanges(t *testing.T) {
	g, err := Miles(0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		if v.X.I < 0 || v.X.I > 5132 {
			t.Errorf("%s: x = %d, 범위 밖", v.Name, v.X.I)
		}
		if v.Y.I < 0 || v.Y.I > 3555 {
			t.Errorf("%s: y = %d, 범위 밖", v.Name, v.Y.I)
		}
		if v.Z.I < 0 || v.Z.I >= maxN {
			t.Errorf("%s: 도시 번호 = %d, 범위 밖", v.Name, v.Z.I)
		}
	}
}
