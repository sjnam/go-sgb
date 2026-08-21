//line gbrand.w:527
package gbrand

import "testing"

//line gbrand.w:541
func TestBasicUndirected(t *testing.T) {
	g, err := RandomGraph(1000, 5000, 0, false, false, nil, nil, 1, 1, 0)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 1000 {
		t.Errorf("N = %d, 원함 1000", g.N)
	}
	if g.M != 10000 {
		t.Errorf("M = %d, 원함 10000", g.M)
	}
	if g.ID != "random_graph(1000,5000,0,0,0,0,0,1,1,0)" {
		t.Errorf("ID = %q", g.ID)
	}
	seen := make(map[[2]int64]bool)
	for i := int64(0); i < g.N; i++ {
		for a := range g.Vertices[i].AllArcs() {
			if a.Tip == &g.Vertices[i] {
				t.Fatalf("자기 고리가 있으면 안 된다: 정점 %d", i)
			}
			key := [2]int64{i, g.Index(a.Tip)}
			if seen[key] {
				t.Fatalf("중복 호가 있으면 안 된다: %v", key)
			}
			seen[key] = true
		}
	}
}

//line gbrand.w:573
func TestDeterministic(t *testing.T) {
	g1, err := RandomGraph(50, 100, 1, true, true, nil, nil, 1, 10, 42)
	if err != nil {
		t.Fatal(err)
	}
	g2, err := RandomGraph(50, 100, 1, true, true, nil, nil, 1, 10, 42)
	if err != nil {
		t.Fatal(err)
	}
	for i := int64(0); i < g1.N; i++ {
		a1, a2 := g1.Vertices[i].Arcs, g2.Vertices[i].Arcs
		for a1 != nil || a2 != nil {
			if a1 == nil || a2 == nil {
				t.Fatalf("정점 %d의 호 수가 다르다", i)
			}
			if g1.Index(a1.Tip) != g2.Index(a2.Tip) || a1.Len != a2.Len {
				t.Fatalf("정점 %d의 호가 다르다", i)
			}
			a1, a2 = a1.Next, a2.Next
		}
	}
}

//line gbrand.w:601
func TestDirectedSelfMulti(t *testing.T) {
	g, err := RandomGraph(2, 500, 1, true, true, nil, nil, 1, 1, 7)
	if err != nil {
		t.Fatal(err)
	}
	if g.M != 500 {
		t.Errorf("M = %d, 원함 500", g.M)
	}
	sawSelfLoop, sawDup := false, false
	for v := range g.AllVertices() {
		seen := make(map[int64]int)
		for a := range v.AllArcs() {
			if a.Tip == v {
				sawSelfLoop = true
			}
			seen[g.Index(a.Tip)]++
			if seen[g.Index(a.Tip)] > 1 {
				sawDup = true
			}
		}
	}
	if !sawSelfLoop {
		t.Error("500개 호에 자기 고리가 하나도 없다---못 믿을 우연이다")
	}
	if !sawDup {
		t.Error("500개 호에 중복이 하나도 없다---못 믿을 우연이다")
	}
}

//line gbrand.w:633
func TestNoDuplicates(t *testing.T) {
	g, err := RandomGraph(5, 15, 0, false, true, nil, nil, 1, 1, 3)
	if err != nil {
		t.Fatal(err)
	}
	for i := int64(0); i < g.N; i++ {
		seen := make(map[int64]bool)
		for a := range g.Vertices[i].AllArcs() {
			key := g.Index(a.Tip)
			if seen[key] {
				t.Fatalf("정점 %d에서 %d로 가는 호가 중복됐다", i, key)
			}
			seen[key] = true
		}
	}
}

//line gbrand.w:657
func TestNonuniformDistribution(t *testing.T) {
	const n = 8
	var distFrom, distTo [n]int64
	for k := 0; k < n; k++ {
		shift := k + 1
		if shift == n {
			shift = n - 1 // 마지막 두 자리는 무게가 같다
		}
		distFrom[k] = probUnit >> shift
	}
	for k := 0; k < n; k++ {
		distTo[k] = distFrom[n-1-k]
	}
	g, err := RandomGraph(n, 20000, 1, false, true,
		distFrom[:], distTo[:], 1, 1, 1)
	if err != nil {
		t.Fatal(err)
	}
	forward, backward := 0, 0
	for a := range g.Vertices[0].AllArcs() {
		if g.Index(a.Tip) == n-1 {
			forward++
		}
	}
	for a := range g.Vertices[n-1].AllArcs() {
		if g.Index(a.Tip) == 0 {
			backward++
		}
	}
	if forward <= backward {
		t.Errorf("0->%d(%d개)가 %d->0(%d개)보다 흔해야 한다", n-1, forward, n-1, backward)
	}
}

//line gbrand.w:696
func TestKnuthThirtyOneExample(t *testing.T) {
	d0 := make([]int64, 31)
	for k := 0; k < 30; k++ {
		d0[k] = probUnit >> (k + 1)
	}
	d0[30] = 1
	d1 := make([]int64, 31)
	for k := range d1 {
		d1[k] = d0[30-k]
	}

//line gbrand.w:715
	for _, d := range [][]int64{d0, d1} {
		var s int64
		for _, x := range d {
			s += x
		}
		if s != probUnit {
			t.Fatalf("분포의 합 = %d, 원함 %d", s, probUnit)
		}
	}

//line gbrand.w:707
	g, err := RandomGraph(31, 20000, 1, true, true, d0, d1, 0, 255, 3)
	if err != nil {
		t.Fatal(err)
	}

//line gbrand.w:726
	forward, total := 0, 0
	for i := int64(0); i < g.N; i++ {
		for a := range g.Vertices[i].AllArcs() {
			total++
			if a.Len < 0 || a.Len > 255 {
				t.Fatalf("길이 %d가 [0,255] 밖이다", a.Len)
			}
			if i == 0 && g.Index(a.Tip) == 30 {
				forward++
			}
			if i == 30 && g.Index(a.Tip) == 0 {
				t.Errorf("확률 2^-60인 30->0 호가 나타났다")
			}
		}
	}
	if r := float64(forward) / float64(total); r < 0.20 || r > 0.30 {
		t.Errorf("0->30의 비율 = %.3f, 1/4 언저리라야 한다", r)
	}

//line gbrand.w:712
}

//line gbrand.w:749
func TestWalkerTableRuns(t *testing.T) {
	dist := []int64{0x20000000, 0x10000000, 0x10000000}
	g, err := RandomGraph(3, 10, 1, true, false, nil, dist, 1, 2, 1)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 3 {
		t.Fatalf("N = %d, 원함 3", g.N)
	}
	for v := range g.AllVertices() {
		for a := range v.AllArcs() {
			if a.Len < 1 || a.Len > 2 {
				t.Errorf("길이 %d가 [1,2] 밖이다", a.Len)
			}
		}
	}
}

//line gbrand.w:771
func TestRandomBigraph(t *testing.T) {
	g, err := RandomBigraph(50, 30, 200, 1, nil, nil, 1, 5, 9)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 80 {
		t.Fatalf("N = %d, 원함 80", g.N)
	}
	if g.N1() != 50 {
		t.Errorf("N1 = %d, 원함 50", g.N1())
	}
	if g.M != 400 {
		t.Errorf("M = %d, 원함 400", g.M)
	}
	n1 := g.N1()
	for i := int64(0); i < g.N; i++ {
		left := i < n1
		for a := range g.Vertices[i].AllArcs() {
			if (g.Index(a.Tip) < n1) == left {
				t.Fatalf("간선이 두 갈래를 잇지 않는다: %d -> %d", i, g.Index(a.Tip))
			}
		}
	}
}

//line gbrand.w:800
func TestRandomLengths(t *testing.T) {
	g, err := RandomGraph(20, 40, 1, false, false, nil, nil, 1, 1, 2)
	if err != nil {
		t.Fatal(err)
	}
	if err := RandomLengths(g, false, 100, 200, nil, 5); err != nil {
		t.Fatal(err)
	}
	for u := range g.AllVertices() {
		for a := range u.AllArcs() {
			if a.Len < 100 || a.Len > 200 {
				t.Errorf("길이 %d가 [100,200] 밖이다", a.Len)
			}
			if a.Len != a.Partner.Len {
				t.Errorf("짝의 길이가 다르다: %d != %d", a.Len, a.Partner.Len)
			}
		}
	}
}
