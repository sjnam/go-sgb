//line gbbasic.w:2594
package gbbasic

import (
	"testing"
)

//line gbbasic.w:2607
func TestComplete(t *testing.T) {
	g, err := Complete(5)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 5 {
		t.Fatalf("N = %d, 원함 5", g.N)
	}
	if g.M != 5*4 {
		t.Errorf("M = %d, 원함 20", g.M)
	}
	if g.ID != "board(5,0,0,0,-1,0,0)" {
		t.Errorf("ID = %q", g.ID)
	}
}

func degree(v *Vertex) (d int64) {
	for range v.AllArcs() {
		d++
	}
	return
}

//line gbbasic.w:2633
func TestQueenBoard(t *testing.T) {
	g, err := Board(3, 4, 0, 0, -1, 0, false) // 룩
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 12 {
		t.Fatalf("N = %d, 원함 12", g.N)
	}
	// 3x4 판에서 각 칸의 룩 이동은 (3-1)+(4-1)=5개다.
	for v := range g.AllVertices() {
		if d := degree(v); d != 5 {
			t.Errorf("정점 %s의 룩 차수 = %d, 원함 5", v.Name, d)
		}
	}
}

//line gbbasic.w:2653
func TestSimplexTriangle(t *testing.T) {
	g, err := Simplex(3, 0, 0, 0, 0, 0, false)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 10 {
		t.Fatalf("N = %d, 원함 10", g.N)
	}
	if g.ID != "simplex(3,-2,0,0,0,0,0)" {
		t.Errorf("ID = %q", g.ID)
	}
}

//line gbbasic.w:2669
func TestPetersen(t *testing.T) {
	g, err := Petersen()
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 10 {
		t.Fatalf("N = %d, 원함 10", g.N)
	}
	if g.M/2 != 15 {
		t.Errorf("간선 수 = %d, 원함 15", g.M/2)
	}
	for v := range g.AllVertices() {
		if d := degree(v); d != 3 {
			t.Errorf("정점 %s의 차수 = %d, 원함 3", v.Name, d)
		}
	}
}

//line gbbasic.w:2690
func TestPerms(t *testing.T) {
	g, err := Perms(2, 1, 1, 0, 0, 0, false)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 12 {
		t.Errorf("N = %d, 원함 12", g.N)
	}
	g, err = AllPerms(4, false)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 24 {
		t.Errorf("AllPerms(4) N = %d, 원함 24", g.N)
	}
}

//line gbbasic.w:2710
func TestParts(t *testing.T) {
	g, err := AllParts(5, false)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 7 {
		t.Errorf("N = %d, 원함 7", g.N)
	}
	if g.ID != "parts(5,5,5,0)" {
		t.Errorf("ID = %q", g.ID)
	}
}

//line gbbasic.w:2726
func TestBinary(t *testing.T) {
	g, err := AllTrees(3, false)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 5 {
		t.Fatalf("N = %d, 원함 5", g.N)
	}
	if g.M/2 != 5 {
		t.Errorf("간선 수 = %d, 원함 5", g.M/2)
	}
	for v := range g.AllVertices() {
		if d := degree(v); d != 2 {
			t.Errorf("정점 %s의 차수 = %d, 원함 2", v.Name, d)
		}
	}
}

//line gbbasic.w:2748
func TestComplement(t *testing.T) {
	k5, _ := Complete(5)
	c, err := Complement(k5, false, false, false)
	if err != nil {
		t.Fatal(err)
	}
	if c.M != 0 {
		t.Errorf("K5 여집합의 호 = %d, 원함 0", c.M)
	}
	e5, _ := Empty(5)
	c, err = Complement(e5, false, false, false)
	if err != nil {
		t.Fatal(err)
	}
	if c.M/2 != 10 {
		t.Errorf("빈 그래프 여집합의 간선 = %d, 원함 10", c.M/2)
	}
}

//line gbbasic.w:2770
func TestGunionQueen(t *testing.T) {
	rook, _ := Board(3, 4, 0, 0, -1, 0, false)
	bishop, _ := Board(3, 4, 0, 0, -2, 0, false)
	q, err := Gunion(rook, bishop, false, false)
	if err != nil {
		t.Fatal(err)
	}
	if q.N != 12 {
		t.Fatalf("N = %d, 원함 12", q.N)
	}
	want := "gunion(board(3,4,0,0,-1,0,0),board(3,4,0,0,-2,0,0),0,0)"
	if q.ID != want {
		t.Errorf("ID = %q", q.ID)
	}
	// 모서리 칸 "0.0"의 퀸 차수는 룩 5 + 비숍 2 = 7이다.
	if d := degree(&q.Vertices[0]); d != 7 {
		t.Errorf("모서리 퀸 차수 = %d, 원함 7", d)
	}
}

//line gbbasic.w:2793
func TestIntersection(t *testing.T) {
	a, _ := Complete(5)
	b, _ := Complete(5)
	g, err := Intersection(a, b, false, false)
	if err != nil {
		t.Fatal(err)
	}
	if g.M/2 != 10 {
		t.Errorf("K5 ∩ K5의 간선 = %d, 원함 10", g.M/2)
	}
}

//line gbbasic.w:2808
func TestLinesTriangle(t *testing.T) {
	k3, _ := Complete(3)
	l, err := Lines(k3, false)
	if err != nil {
		t.Fatal(err)
	}
	if l.N != 3 || l.M/2 != 3 {
		t.Errorf("L(K3): N=%d, 간선=%d, 원함 3,3", l.N, l.M/2)
	}
	if k3.M/2 != 3 {
		t.Errorf("원본 K3이 복원되지 않았다: 간선 %d", k3.M/2)
	}
}

//line gbbasic.w:2825
func TestProductC4(t *testing.T) {
	k2a, _ := Complete(2)
	k2b, _ := Complete(2)
	p, err := Product(k2a, k2b, Cartesian, false)
	if err != nil {
		t.Fatal(err)
	}
	if p.N != 4 || p.M/2 != 4 {
		t.Errorf("K2□K2: N=%d, 간선=%d, 원함 4,4", p.N, p.M/2)
	}
	for v := range p.AllVertices() {
		if d := degree(v); d != 2 {
			t.Errorf("정점 %s의 차수 = %d, 원함 2", v.Name, d)
		}
	}
}

//line gbbasic.w:2846
func TestBiCompleteAndWheel(t *testing.T) {
	bc, err := BiComplete(2, 3, false)
	if err != nil {
		t.Fatal(err)
	}
	if bc.N != 5 || bc.M/2 != 6 {
		t.Errorf("K(2,3): N=%d, 간선=%d, 원함 5,6", bc.N, bc.M/2)
	}
	w, err := Wheel(4, 1, false)
	if err != nil {
		t.Fatal(err)
	}
	if w.N != 5 || w.M/2 != 8 {
		t.Errorf("Wheel(4,1): N=%d, 간선=%d, 원함 5,8", w.N, w.M/2)
	}
}
