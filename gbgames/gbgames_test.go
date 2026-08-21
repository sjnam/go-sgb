//line gbgames.w:482
package gbgames

import "testing"

const dataDir = "../data"

//line gbgames.w:496
func TestFullGraph(t *testing.T) {
	g, err := Games(0, 0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 120 {
		t.Fatalf("N = %d, 원함 120", g.N)
	}
	if g.M != 2*638 {
		t.Errorf("M = %d, 원함 %d", g.M, 2*638)
	}
	if g.ID != "games(120,0,0,0,0,0,128,0)" {
		t.Errorf("ID = %q", g.ID)
	}
}

//line gbgames.w:515
func TestLatterHalf(t *testing.T) {
	full, err := Games(0, 0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	half, err := Games(0, 0, 0, 0, 0, 50, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if half.M >= full.M {
		t.Errorf("후반 간선이 안 줄었다: %d >= %d", half.M, full.M)
	}
	if half.ID != "games(120,0,0,0,0,50,128,0)" {
		t.Errorf("ID = %q", half.ID)
	}
}

//line gbgames.w:536
func TestSelectByVotes(t *testing.T) {
	g, err := Games(53, 1, 1, 1, 1, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 53 {
		t.Fatalf("N = %d, 원함 53", g.N)
	}
	g2, err := Games(67, -1, -1, -1, -1, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g2.N != 67 {
		t.Fatalf("N = %d, 원함 67", g2.N)
	}
}

//line gbgames.w:556
func TestVertexFields(t *testing.T) {
	g, err := Games(30, 0, 0, 1, 2, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 30 {
		t.Fatalf("N = %d, 원함 30", g.N)
	}
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		if v.Name == "" || v.X.S == "" || v.Y.S == "" {
			t.Fatalf("정점 %d의 이름/약칭/별명이 비었다", i)
		}
	}
}

//line gbgames.w:577
func TestConferencesAndNicknames(t *testing.T) {
	g, err := Games(0, 0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	confs, nicks := map[string]bool{}, map[string]bool{}
	indep := 0
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		nicks[v.Y.S] = true
		if v.Z.S == "" {
			indep++
		} else {
			confs[v.Z.S] = true
		}
	}
	if len(confs) != 11 || len(nicks) != 94 || indep != 25 {
		t.Errorf("컨퍼런스 %d(원함 11), 별명 %d(원함 94), 독립 %d(원함 25)",
			len(confs), len(nicks), indep)
	}

//line gbgames.w:601
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		if v.Name != "Stanford" {
			continue
		}
		all, same := 0, 0
		for a := range v.AllArcs() {
			all++
			if a.Tip.Z.S == v.Z.S {
				same++
			}
		}
		if v.Z.S != "Pacific Ten" || all != 11 || same != 8 {
			t.Errorf("Stanford: %q, %d경기 중 같은 컨퍼런스 %d경기", v.Z.S, all, same)
		}
	}

//line gbgames.w:598
}

//line gbgames.w:621
func TestArcsInReverseDateOrder(t *testing.T) {
	g, err := Games(0, 0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	for i := int64(0); i < g.N; i++ {
		prev := int64(maxDay + 1)
		for a := range g.Vertices[i].AllArcs() {
			if a.B.I > prev {
				t.Fatalf("정점 %d의 호가 날짜 역순이 아니다: %d 뒤에 %d",
					i, prev, a.B.I)
			}
			prev = a.B.I
		}
	}
}

//line gbgames.w:642
func TestArcFields(t *testing.T) {
	g, err := Games(0, 0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	v := &g.Vertices[0]
	for a := range v.AllArcs() {
		if a.A.I < home || a.A.I > away {
			t.Fatalf("venue = %d, 범위 밖", a.A.I)
		}
		if a.A.I+a.Partner.A.I != home+away {
			t.Errorf("짝의 venue가 어긋났다: %d, %d", a.A.I, a.Partner.A.I)
		}
		if a.B.I != a.Partner.B.I {
			t.Errorf("짝의 date가 다르다: %d, %d", a.B.I, a.Partner.B.I)
		}
	}
}
