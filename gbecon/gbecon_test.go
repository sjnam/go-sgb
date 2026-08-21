//line gbecon.w:731
package gbecon

import (
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
)

const dataDir = "../data"

func TestEconDefaults(t *testing.T) {
	for _, c := range []struct {
		n, omit, want int64
	}{
		{0, 0, 81}, {81, 0, 81}, {0, 2, 79}, {79, 2, 79}, {0, 1, 80},
	} {
		g, err := Econ(c.n, c.omit, 0, 0, dataDir)
		if err != nil {
			t.Fatal(err)
		}
		if g.N != c.want {
			t.Errorf("Econ(%d,%d,0,0).N = %d, 원함 %d", c.n, c.omit, g.N, c.want)
		}
	}
}

//line gbecon.w:763
func TestEconSample(t *testing.T) {
	g, err := Econ(40, 0, 400, -111, dataDir)
	if err != nil {
		t.Fatal(err)
	}

//line gbecon.w:774
	if g.ID != "econ(40,0,400,-111)" {
		t.Errorf("ID = %q", g.ID)
	}
	if g.N != 40 || g.M != 512 {
		t.Fatalf("N=%d M=%d, 원함 N=40 M=512", g.N, g.M)
	}
	if g.UtilTypes != "ZZZZIAIZZZZZZZ" {
		t.Errorf("UtilTypes = %q", g.UtilTypes)
	}

//line gbecon.w:769

//line gbecon.w:785
	v := &g.Vertices[11]
	if v.Name != "Printing and publishing" || v.Y.I != 69451 {
		t.Fatalf("정점 11 = %q[%d], 원함 Printing and publishing[69451]",
			v.Name, v.Y.I)
	}
	type arc struct {
		name        string
		total, flow int64
	}
	var got []arc
	for a := range v.AllArcs() {
		got = append(got, arc{a.Tip.Name, a.Tip.Y.I, a.A.I})
	}
	want := []arc{
		{"Food, liquor, and candy", 300724, 1863},
		{"Cigarettes, cigars, tobacco", 24445, 195},
		{"Printing and publishing", 69451, 6089},
		{"Business support services", 463594, 8369},
		{"Personal services", 827615, 9073},
		{"Users", 3999362, 30676},
	}

//line gbecon.w:809
	if len(got) != len(want) {
		t.Fatalf("정점 11의 호 %d개, 원함 %d개", len(got), len(want))
	}
	for i, a := range want {
		if got[i] != a {
			t.Errorf("호 %d = %v, 원함 %v", i, got[i], a)
		}
	}

//line gbecon.w:770

//line gbecon.w:821
	users := &g.Vertices[g.N-1]
	if users.Name != "Users" {
		t.Fatalf("마지막 정점 = %q, 원함 Users", users.Name)
	}
	if users.Z.A != nil {
		t.Errorf("Users의 SIC_codes가 비어 있지 않다")
	}
	if v.Z.A == nil {
		t.Errorf("정점 11의 SIC_codes가 비어 있다")
	}

//line gbecon.w:771
}

//line gbecon.w:839
func find(g *gbgraph.Graph, name string) *gbgraph.Vertex {
	for i := int64(0); i < g.N; i++ {
		if g.Vertices[i].Name == name {
			return &g.Vertices[i]
		}
	}
	return nil
}

func flowTo(u *gbgraph.Vertex, name string) (int64, bool) {
	for a := range u.AllArcs() {
		if a.Tip.Name == name {
			return a.A.I, true
		}
	}
	return 0, false
}

//line gbecon.w:858
func TestApparelExample(t *testing.T) {
	g, err := Econ(0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	ap, users := find(g, "Apparel"), find(g, "Users")
	if ap == nil || users == nil {
		t.Fatal("Apparel이나 Users 정점이 없다")
	}
	if ap.Y.I != 54031 {
		t.Errorf("Apparel 총액 = %d, 원함 54031", ap.Y.I)
	}

//line gbecon.w:883
	for _, c := range []struct {
		to   string
		want int64
	}{
		{"Apparel", 9259},
		{"Household furniture", 44},
		{"Users", 42172},
	} {
		if f, ok := flowTo(ap, c.to); !ok || f != c.want {
			t.Errorf("Apparel->%s = %d, 원함 %d", c.to, f, c.want)
		}
	}

//line gbecon.w:871
	if f, ok := flowTo(users, "Apparel"); !ok || f != 19409 {
		t.Errorf("Users->Apparel = %d, 원함 19409", f)
	}
	if users.Y.I != 3999362 {
		t.Errorf("GNP = %d, 원함 3999362", users.Y.I)
	}
	if adj := find(g, "Adjustments"); adj.Y.I != 457090 {
		t.Errorf("Adjustments = %d, 원함 457090", adj.Y.I)
	}
}

//line gbecon.w:901
func TestNegativeFlowsAndTotal(t *testing.T) {
	g, err := Econ(0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}

//line gbecon.w:920
	var neg, sum int64
	for i := int64(0); i < g.N; i++ {
		for a := range g.Vertices[i].AllArcs() {
			sum += a.A.I
			if a.A.I < 0 {
				neg++
				if a.Tip.Name != "Users" {
					t.Errorf("음의 호가 %q로 간다", a.Tip.Name)
				}
			}
		}
	}
	if f, _ := flowTo(find(g, "Petroleum and natural gas production"),
		"Users"); f != -27032 {
		t.Errorf("석유·천연가스 -> Users = %d, 원함 -27032", f)
	}

//line gbecon.w:907
	if neg != 10 {
		t.Errorf("음의 호 = %d개, 원함 10개", neg)
	}
	if sum != 11198209 {
		t.Errorf("전체 호 흐름 = %d, 원함 11198209", sum)
	}
	if sum-g.Vertices[g.N-1].Y.I != 7198847 {
		t.Errorf("Users 나가는 호를 뺀 합 = %d, 원함 7198847",
			sum-g.Vertices[g.N-1].Y.I)
	}
}

//line gbecon.w:942
func TestThresholdAndPruning(t *testing.T) {
	for _, c := range []struct{ thresh, want int64 }{
		{0, 4602}, {1, 4473}, {6000, 72},
	} {
		g, err := Econ(79, 2, c.thresh, 0, dataDir)
		if err != nil {
			t.Fatal(err)
		}
		if g.M != c.want {
			t.Errorf("Econ(79,2,%d,0).M = %d, 원함 %d", c.thresh, g.M, c.want)
		}
	}

//line gbecon.w:961
	for _, c := range []struct {
		n     int64
		names []string
	}{
		{2, []string{"Goods", "Services"}},
		{3, []string{"Goods", "Indirect services", "Direct services"}},
	} {
		g, err := Econ(c.n, 2, 0, 0, dataDir)
		if err != nil {
			t.Fatal(err)
		}
		for i, want := range c.names {
			if got := g.Vertices[i].Name; got != want {
				t.Errorf("Econ(%d,2,0,0) 정점 %d = %q, 원함 %q", c.n, i, got, want)
			}
		}
	}

//line gbecon.w:955
}

//line gbecon.w:983
func TestSICLists(t *testing.T) {
	g, err := Econ(80, 1, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	for i := int64(0); i < g.N; i++ {
		a := g.Vertices[i].Z.A
		if a == nil || a.Next != nil {
			t.Fatalf("정점 %d(%q)의 SIC 목록 길이가 1이 아니다",
				i, g.Vertices[i].Name)
		}
		if a.Len < 1 || a.Len > 80 {
			t.Errorf("SIC 부호 %d가 범위 밖이다", a.Len)
		}
	}
	for name, want := range map[string]int64{
		"Paper products, except containers": 24,
		"Paperboard containers and boxes":   25,
	} {
		if v := find(g, name); v == nil || v.Z.A.Len != want {
			t.Errorf("%q의 SIC 부호가 %d가 아니다", name, want)
		}
	}
}
