//line gblisa.w:608
package gblisa

import "testing"

const dataDir = "../data"

//line gblisa.w:623
func TestPlaneLisa(t *testing.T) {
	g, err := PlaneLisa(100, 100, 50, 1, 300, 1, 200, 2975050, 11900200, dataDir)
	if err != nil {
		t.Fatal(err)
	}

//line gblisa.w:633
	if g.ID != "plane_lisa(100,100,50,1,300,1,200,2975050,11900200)" {
		t.Errorf("ID = %q", g.ID)
	}
	if g.N != 2452 || g.M != 10814 {
		t.Fatalf("N=%d M=%d, 원함 N=2452 M=10814", g.N, g.M)
	}
	if g.UtilTypes != "ZZZIIIZZIIZZZZ" {
		t.Errorf("UtilTypes = %q", g.UtilTypes)
	}
	if g.UU.I != 100 || g.VV.I != 100 {
		t.Errorf("matrix_rows,cols = %d,%d, 원함 100,100", g.UU.I, g.VV.I)
	}

//line gblisa.w:629

//line gblisa.w:647
	v := &g.Vertices[1294]
	if v.Name != "1294" || v.X.I != 11 || v.Y.I != 2407 || v.Z.I != 2408 {
		t.Fatalf("정점 1294 = %q[%d][%d][%d], 원함 1294[11][2407][2408]",
			v.Name, v.X.I, v.Y.I, v.Z.I)
	}
	type arc struct {
		name             string
		pix, first, last int64
	}
	var got []arc
	for a := range v.AllArcs() {
		tip := a.Tip
		got = append(got, arc{tip.Name, tip.X.I, tip.Y.I, tip.Z.I})
	}
	want := []arc{
		{"1295", 12, 2409, 2409}, {"1256", 8, 2308, 2308},
		{"1293", 10, 2406, 2508}, {"1255", 10, 2307, 2307},
	}

//line gblisa.w:668
	if len(got) != len(want) {
		t.Fatalf("정점 1294의 호 %d개, 원함 %d개", len(got), len(want))
	}
	for i, a := range want {
		if got[i] != a {
			t.Errorf("호 %d = %v, 원함 %v", i, got[i], a)
		}
	}

//line gblisa.w:630
}

//line gblisa.w:682
func TestBiLisa(t *testing.T) {
	g, err := BiLisa(0, 0, 94, 110, 97, 129, 30000, false, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 48 || g.N1() != 16 {
		t.Fatalf("N=%d N1=%d, 원함 N=48 N1=16", g.N, g.N1())
	}

//line gblisa.w:694
	for k := int64(0); k < g.N; k++ {
		for a := range g.Vertices[k].AllArcs() {
			if a.B.I < 30000 {
				t.Fatalf("호의 B.I = %d, 문턱 30000 미만", a.B.I)
			}
		}
	}

//line gblisa.w:691
}

//line gblisa.w:708
func TestDocumentedExamples(t *testing.T) {
	full, err := Lisa(0, 0, 0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if full.M != 360 || full.N != 250 || full.D != 255 {
		t.Fatalf("기본값 = %dx%d D=%d, 원함 360x250 D=255",
			full.M, full.N, full.D)
	}
	if full.ID != "lisa(360,250,255,0,360,0,250,0,22950000)" {
		t.Errorf("ID = %q", full.ID)
	}

//line gblisa.w:725
	for i, v := range full.Pix {
		if v < 0 || v > 255 {
			t.Fatalf("픽셀 %d = %d, 범위 밖", i, v)
		}
	}

//line gblisa.w:721

//line gblisa.w:732
	big, err := Lisa(1000, 1000, 255, 0, 250, 0, 250, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if big.M != 1000 || big.N != 1000 {
		t.Fatalf("%dx%d, 원함 1000x1000", big.M, big.N)
	}
	for k := int64(0); k < 4; k++ {
		for l := int64(0); l < 4; l++ {
			if big.Pix[k*1000+l] != big.Pix[0] {
				t.Fatalf("왼쪽 위 4x4가 균일하지 않다: [%d,%d]", k, l)
			}
		}
	}

//line gblisa.w:722
}

//line gblisa.w:752
func TestNamedRegions(t *testing.T) {
	for _, c := range []struct {
		name       string
		r          Region
		rows, cols int64
	}{
		{"Smile", Smile, 16, 32},
		{"Eyes", Eyes, 19, 49},
	} {
		mx, err := Lisa(0, 0, 0, c.r.M0, c.r.M1, c.r.N0, c.r.N1, 0, 0, dataDir)
		if err != nil {
			t.Fatal(err)
		}
		if mx.M != c.rows || mx.N != c.cols {
			t.Errorf("%s = %dx%d, 원함 %dx%d",
				c.name, mx.M, mx.N, c.rows, c.cols)
		}
		if mx.M != c.r.M1-c.r.M0 || mx.N != c.r.N1-c.r.N0 {
			t.Errorf("%s가 반열린 구간 약속과 어긋난다", c.name)
		}
	}
}
