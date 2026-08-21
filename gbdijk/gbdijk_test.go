//line gbdijk.w:436
package gbdijk

import (
	"strings"
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
)

//line gbdijk.w:455
func buildGraph() *gbgraph.Graph {
	g := gbgraph.NewGraph(5)
	for i := range g.Vertices[:5] {
		g.Vertices[i].Name = string(rune('a' + i))
	}
	v := func(i int) *gbgraph.Vertex { return &g.Vertices[i] }
	g.NewArc(v(0), v(1), 4)
	g.NewArc(v(0), v(2), 1)
	g.NewArc(v(2), v(1), 2)
	g.NewArc(v(1), v(3), 1)
	g.NewArc(v(2), v(3), 5)
	return g
}

//line gbdijk.w:472
func TestShortestPath(t *testing.T) {
	for _, pq := range []struct {
		name string
		make func() PriorityQueue
	}{
		{"dlist", NewDList},
		{"list128", NewList128},
	} {
		g := buildGraph()
		d := Dijkstra(&g.Vertices[0], &g.Vertices[3], g, nil, pq.make(), nil)
		if d != 4 {
			t.Errorf("%s: 거리 = %d, 원함 4", pq.name, d)
		}
	}
}

//line gbdijk.w:492
func TestHeuristic(t *testing.T) {
	g := buildGraph()
	hval := map[string]int64{"a": 2, "b": 1, "c": 1, "d": 0, "e": 0}
	hh := func(v *gbgraph.Vertex) int64 { return hval[v.Name] }
	d := Dijkstra(&g.Vertices[0], &g.Vertices[3], g, hh, NewList128(), nil)
	if d != 4 {
		t.Errorf("어림을 쓴 거리 = %d, 원함 4", d)
	}
}

//line gbdijk.w:505
func TestUnreachable(t *testing.T) {
	g := buildGraph()
	if d := Dijkstra(&g.Vertices[0], &g.Vertices[4], g, nil, nil, nil); d != -1 {
		t.Errorf("거리 = %d, 원함 -1", d)
	}
}

//line gbdijk.w:516
func TestPrintResult(t *testing.T) {
	g := buildGraph()
	Dijkstra(&g.Vertices[0], &g.Vertices[3], g, nil, nil, nil)
	var b strings.Builder
	PrintResult(&g.Vertices[3], &b)
	want := "         0 a\n         1 c\n         3 b\n         4 d\n"
	if b.String() != want {
		t.Errorf("경로 출력 =\n%q\n원함\n%q", b.String(), want)
	}
	if g.Vertices[0].Y.V != &g.Vertices[0] {
		t.Errorf("되뒤집기 뒤 a의 backlink가 자기 자신이 아니다")
	}
}
