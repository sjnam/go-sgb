//line gbgraph.w:547
package gbgraph

import "testing"

func TestGraph(t *testing.T) {
	g := NewGraph(2)
	u, v := &g.Vertices[0], &g.Vertices[1]
	u.Name = "vertex 0"
	v.Name = "vertex 1"
	g.NewEdge(v, u, -1)
	g.NewEdge(u, u, 1)
	g.NewArc(v, u, -1)
	if int64(v.Name[7])+g.N != int64(v.Arcs.Next.Tip.Name[7])+g.M-2 {
		t.Fatal("그래프 자료구조가 아직 제대로 돌지 않는다")
	}
}

//line gbgraph.w:573
func TestMixedArcAndEdge(t *testing.T) {
	g := NewGraph(4)
	v := func(i int) *Vertex { return &g.Vertices[i] }
	g.NewArc(v(0), v(1), 1) // 홀수 번째 호 할당
	g.NewEdge(v(1), v(2), 2)
	g.NewEdge(v(2), v(3), 3)
	g.NewArc(v(3), v(0), 4)
	g.NewEdge(v(0), v(2), 5)
	edges := 0
	for i := 0; i < 4; i++ {
		for a := range v(i).AllArcs() {
			if a.Partner == nil {
				continue // |NewArc|로 만든 호는 짝이 없다
			}
			edges++

//line gbgraph.w:600
			if a.Partner.Partner != a {
				t.Fatalf("짝의 짝이 자기가 아니다")
			}
			if a.Partner.Len != a.Len {
				t.Errorf("짝의 길이가 다르다: %d, %d", a.Len, a.Partner.Len)
			}
			if a.Partner.Tip != v(i) {
				t.Errorf("짝의 Tip이 출발점이 아니다")
			}

//line gbgraph.w:589
		}
	}
	if edges != 6 { // 간선 세 개 = 호 여섯 개
		t.Errorf("짝 있는 호 = %d, 원함 6", edges)
	}
}

//line gbgraph.w:611
func TestPartner(t *testing.T) {
	g := NewGraph(2)
	u, v := &g.Vertices[0], &g.Vertices[1]
	g.NewEdge(u, v, 3)
	g.NewArc(u, v, 4)
	if a := u.Arcs; a.Partner != nil {
		t.Fatal("홑호에 짝이 생겼다")
	}
	e := u.Arcs.Next // 간선의 |u|쪽 호
	if e.Partner == nil || e.Partner.Partner != e ||
		e.Partner.Tip != u || e.Partner != v.Arcs {
		t.Fatal("간선의 두 호가 짝을 이루지 못했다")
	}
	if e.Len != 3 || e.Partner.Len != 3 || g.M != 3 {
		t.Fatal("간선의 길이나 호 수가 틀렸다")
	}
	g.NewEdge(v, v, 7) // 자기 고리
	if s := v.Arcs; s.Tip != v || s.Next != s.Partner || s.Next.Tip != v {
		t.Fatal("자기 고리가 C의 모양대로 놓이지 않았다")
	}
}

//line gbgraph.w:636
func TestHashAndIndex(t *testing.T) {
	g := NewGraph(5)
	names := []string{"aargh", "abaca", "abaci", "aback", "abaft"}
	for i := range g.Vertices[:g.N] {
		g.Vertices[i].Name = names[i]
	}
	g.HashSetup()
	if g.UtilTypes[:2] != "VV" || g.UtilTypes[2:] != "ZZZZZZZZZZZZ" {
		t.Fatalf("UtilTypes가 바르게 갱신되지 않았다 (%s)", g.UtilTypes)
	}
	for i, s := range names {
		v := g.HashLookup(s)
		if v == nil {
			t.Fatalf("%s를 찾지 못했다", s)
		}
		if g.Index(v) != int64(i) {
			t.Fatalf("%s의 번호가 %d로 나왔다", s, g.Index(v))
		}
	}
	if g.HashLookup("zzzzz") != nil {
		t.Fatal("없는 이름이 찾아졌다")
	}
}

//line gbgraph.w:664
func TestIterators(t *testing.T) {
	g := NewGraph(3)
	u := &g.Vertices[0]
	g.NewEdge(u, &g.Vertices[1], 1)
	g.NewArc(u, &g.Vertices[2], 2)
	var got []int64
	for x := range g.AllVertices() {
		got = append(got, g.Index(x))
	}
	if len(got) != 3 || got[0] != 0 || got[1] != 1 || got[2] != 2 {
		t.Fatalf("AllVertices가 %v를 내줬다", got)
	}
	n := 0
	for range u.AllArcs() {
		n++
	}
	if n != 2 {
		t.Fatalf("u의 호 수가 %d로 나왔다", n)
	}
	n = 0
	for range u.AllArcs() {
		n++
		break
	}
	if n != 1 {
		t.Fatal("AllArcs가 break를 존중하지 않았다")
	}
}
