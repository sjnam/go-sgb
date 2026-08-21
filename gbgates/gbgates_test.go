//line gbgates.w:1953
package gbgates

import (
	"strings"
	"testing"
)

func TestRiscSize(t *testing.T) {
	g, err := Risc(16)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 3240 {
		t.Fatalf("Risc(16).N = %d, 원함 3240", g.N)
	}
	if g.ID != "risc(16)" {
		t.Errorf("ID = %q", g.ID)
	}
}

//line gbgates.w:1974
func TestPartialGates(t *testing.T) {
	g, err := Risc(16)
	if err != nil {
		t.Fatal(err)
	}
	pg, err := PartialGates(g, 1, 43210, 98765, nil)
	if err != nil {
		t.Fatal(err)
	}
	if pg.ID != "partial_gates(risc(16),1,43210,98765)" {
		t.Errorf("ID = %q", pg.ID)
	}
	if pg.N != 1702 || pg.M != 3796 {
		t.Fatalf("N=%d M=%d, 원함 N=1702 M=3796", pg.N, pg.M)
	}
	v := &pg.Vertices[79]
	if v.Name != "R10:10" || v.Y.I != 'L' {
		t.Fatalf("정점 79 = %q, 종류 %c, 원함 R10:10 종류 L", v.Name, byte(v.Y.I))
	}
}

//line gbgates.w:1999
func TestProdMultiplies(t *testing.T) {
	const m, n = 8, 8
	g, err := Prod(m, n)
	if err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct{ x, y int64 }{{0, 0}, {1, 1}, {12, 12}, {255, 255}, {13, 19}} {
		var sb strings.Builder
		for i := 0; i < m; i++ {
			sb.WriteByte(byte('0' + (c.x>>i)&1))
		}
		for i := 0; i < n; i++ {
			sb.WriteByte(byte('0' + (c.y>>i)&1))
		}
		out, code := GateEval(g, sb.String())
		if code != 0 {
			t.Fatalf("GateEval 코드 %d", code)
		}
		var got int64
		for i := 0; i < len(out); i++ {
			got = 2*got + int64(out[i]-'0')
		}
		if got != c.x*c.y {
			t.Errorf("%d*%d = %d, 원함 %d", c.x, c.y, got, c.x*c.y)
		}
	}
}
