//line gbplane.w:846
package gbplane

import "testing"

const dataDir = "../data"

//line gbplane.w:859
func TestPlaneMiles(t *testing.T) {
	g, err := PlaneMiles(50, 500, -100, 1, true, 40000, 271818, dataDir)
	if err != nil {
		t.Fatal(err)
	}

//line gbplane.w:869
	if g.ID != "plane_miles(50,500,-100,1,1,40000,271818)" {
		t.Errorf("ID = %q", g.ID)
	}
	if g.N != 51 || g.M != 96 {
		t.Fatalf("N=%d M=%d, 원함 N=51 M=96", g.N, g.M)
	}
	if g.UtilTypes != "ZZIIIIZZZZZZZZ" {
		t.Errorf("UtilTypes = %q", g.UtilTypes)
	}

//line gbplane.w:865

//line gbplane.w:880
	v := &g.Vertices[14]
	if v.Name != "Saint Louis, MO" || v.W.I != 453085 ||
		v.X.I != 3293 || v.Y.I != 1785 || v.Z.I != 24 {
		t.Fatalf("정점 14 = %q[%d][%d][%d][%d]", v.Name, v.W.I, v.X.I, v.Y.I, v.Z.I)
	}
	type arc struct {
		name string
		len  int64
	}
	var got []arc
	for a := range v.AllArcs() {
		got = append(got, arc{a.Tip.Name, a.Len})
	}
	want := []arc{
		{"Waterloo, IA", 373}, {"South Bend, IN", 358}, {"San Diego, CA", 1875},
	}

//line gbplane.w:899
	if len(got) != len(want) {
		t.Fatalf("정점 14의 호 %d개, 원함 %d개", len(got), len(want))
	}
	for i, a := range want {
		if got[i] != a {
			t.Errorf("호 %d = %v, 원함 %v", i, got[i], a)
		}
	}

//line gbplane.w:866
}

//line gbplane.w:913
func TestPlaneFullTriangulation(t *testing.T) {
	const n = 20
	g, err := Plane(n, 1000, 1000, true, 0, 12345)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != n+1 {
		t.Fatalf("N=%d, 원함 %d", g.N, n+1)
	}
	if g.M != 6*(n-1) {
		t.Fatalf("M=%d, 원함 %d (호 $6(n-1)$개)", g.M, 6*(n-1))
	}

//line gbplane.w:932
	avg := float64(g.M) / float64(g.N)
	if want := 6 * float64(n-1) / float64(n+1); avg != want {
		t.Errorf("평균 차수 = %.4f, 원함 %.4f", avg, want)
	}
	if avg >= 6 {
		t.Errorf("평균 차수 %.4f는 6보다 작아야 한다", avg)
	}

//line gbplane.w:926
}

//line gbplane.w:944
func TestPlaneHalfDiscarded(t *testing.T) {
	const n = 400
	g, err := Plane(n, 4000, 4000, true, 32768, 271828)
	if err != nil {
		t.Fatal(err)
	}
	full, err := Plane(n, 4000, 4000, true, 0, 271828)
	if err != nil {
		t.Fatal(err)
	}
	if r := float64(g.M) / float64(full.M); r < 0.4 || r > 0.6 {
		t.Errorf("남은 간선의 비율 = %.3f, 절반 언저리라야 한다", r)
	}
	if avg := float64(g.M) / float64(g.N); avg < 2.4 || avg > 3.6 {
		t.Errorf("평균 차수 = %.3f, 3 언저리라야 한다", avg)
	}
}
