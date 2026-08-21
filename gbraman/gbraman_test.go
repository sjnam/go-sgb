//line gbraman.w:812
package gbraman

import "testing"

func TestRamanBasic(t *testing.T) {
	cases := []struct {
		p, q, typ, reduce int64
		n, m              int64
		id                string
	}{
		{2, 3, 1, 0, 4, 14, "raman(2,3,1,0)"},
		{2, 3, 0, 0, 24, 72, "raman(2,3,4,0)"},
		{3, 5, 1, 0, 6, 24, "raman(3,5,1,0)"},
		{3, 5, 0, 0, 120, 480, "raman(3,5,4,0)"},
		{5, 13, 0, 0, 2184, 13104, "raman(5,13,4,0)"},
		{2, 17, 0, 0, 2448, 7344, "raman(2,17,3,0)"},
		{3, 5, 0, 1, 120, 480, "raman(3,5,4,1)"},
		{31, 3, 0, 4, 12, 96, "raman(31,3,3,4)"},
	}
	for _, c := range cases {
		g, err := Raman(c.p, c.q, c.typ, c.reduce)
		if err != nil {
			t.Errorf("Raman(%d,%d,%d,%d) 오류: %v", c.p, c.q, c.typ, c.reduce, err)
			continue
		}
		if g.N != c.n || g.M != c.m || g.ID != c.id {
			t.Errorf("Raman(%d,%d,%d,%d) = N=%d M=%d id=%q; 기대 N=%d M=%d id=%q",
				c.p, c.q, c.typ, c.reduce, g.N, g.M, g.ID, c.n, c.m, c.id)
		}
	}
}

func TestRamanBadSpecs(t *testing.T) {
	if _, err := Raman(2, 5, 2, 0); err == nil {
		t.Error("Raman(2,5,2,0)는 오류를 돌려줘야 한다")
	}
}

//line gbraman.w:855
func TestRamanTypeZeroExample(t *testing.T) {
	g, err := Raman(2, 43, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if g.ID != "raman(2,43,4,0)" {
		t.Errorf("ID = %q, type 4를 골라야 한다", g.ID)
	}
	if g.N != 44*43*42 {
		t.Errorf("N = %d, 원함 %d", g.N, 44*43*42)
	}

//line gbraman.w:872
	for i := int64(0); i < g.N; i++ {
		d := 0
		for range g.Vertices[i].AllArcs() {
			d++
		}
		if d != 3 {
			t.Fatalf("정점 %d의 차수 = %d, 원함 3", i, d)
		}
	}

//line gbraman.w:867
}

//line gbraman.w:887
func TestVertexCountFormulas(t *testing.T) {
	const q = 13
	for _, c := range []struct {
		p, typ, want int64
	}{
		{3, 1, q + 1},
		{3, 2, q * (q + 1) / 2},
		{3, 3, (q - 1) * q * (q + 1) / 2},
		{5, 4, (q - 1) * q * (q + 1)},
	} {
		g, err := Raman(c.p, q, c.typ, 0)
		if err != nil {
			t.Errorf("Raman(%d,%d,%d,0): %v", c.p, q, c.typ, err)
			continue
		}
		if g.N != c.want {
			t.Errorf("type %d: N = %d, 원함 %d", c.typ, g.N, c.want)
		}
	}
}

//line gbraman.w:913
func TestGeneratorCount(t *testing.T) {
	for _, c := range []struct{ p, q, deg int64 }{
		{3, 13, 4},
		{5, 13, 6},
	} {
		g, err := Raman(c.p, c.q, 1, 0)
		if err != nil {
			t.Fatal(err)
		}
		d := 0
		for range g.Vertices[0].AllArcs() {
			d++
		}
		if int64(d) != c.deg {
			t.Errorf("p=%d일 때 차수 = %d, 원함 %d", c.p, d, c.deg)
		}
	}
}
