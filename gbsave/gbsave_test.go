//line gbsave.w:740
package gbsave

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbmiles"
)

func TestRoundTrip(t *testing.T) {
	g, err := gbmiles.Miles(50, 0, 0, 0, 0, 10, 0, "../data")
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "test.gb")
	if err := SaveGraph(g, path); err != nil {
		t.Fatalf("SaveGraph: %v", err)
	}
	g2, err := RestoreGraph(path)
	if err != nil {
		t.Fatalf("RestoreGraph: %v", err)
	}

//line gbsave.w:770
	if g2.N != g.N || g2.M != g.M {
		t.Fatalf("N/M = %d/%d, 원함 %d/%d", g2.N, g2.M, g.N, g.M)
	}
	if g2.ID != g.ID {
		t.Errorf("ID = %q, 원함 %q", g2.ID, g.ID)
	}
	if g2.UtilTypes != g.UtilTypes {
		t.Errorf("UtilTypes = %q, 원함 %q", g2.UtilTypes, g.UtilTypes)
	}
	for i := int64(0); i < g.N; i++ {
		v, v2 := &g.Vertices[i], &g2.Vertices[i]
		if v2.Name != v.Name || v2.W.I != v.W.I || v2.X.I != v.X.I ||
			v2.Y.I != v.Y.I || v2.Z.I != v.Z.I {
			t.Fatalf("정점 %d 불일치: %q %v vs %q %v", i, v.Name, v, v2.Name, v2)
		}

//line gbsave.w:792
		a, a2 := v.Arcs, v2.Arcs
		for a != nil && a2 != nil {
			if g.Index(a.Tip) != g2.Index(a2.Tip) || a.Len != a2.Len {
				t.Fatalf("정점 %d 인접 불일치", i)
			}
			if a2.Partner == nil || g2.Index(a2.Partner.Tip) != i {
				t.Fatalf("정점 %d 호의 짝이 잘못됨", i)
			}
			a, a2 = a.Next, a2.Next
		}
		if a != nil || a2 != nil {
			t.Fatalf("정점 %d 인접 리스트 길이 불일치", i)
		}

//line gbsave.w:786
	}

//line gbsave.w:767
}

//line gbsave.w:811
func TestFileFormat(t *testing.T) {
	g, err := gbmiles.Miles(20, 0, 0, 0, 0, 5, 0, "../data")
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "fmt.gb")
	if err := SaveGraph(g, path); err != nil {
		t.Fatal(err)
	}
	lines := readLines(t, path)

//line gbsave.w:830
	const pre = "* GraphBase graph (util_types "
	body, ok := strings.CutPrefix(lines[0], pre)
	if !ok {
		t.Fatalf("첫 줄 = %q", lines[0])
	}
	body, ok = strings.CutSuffix(body, ")")
	if !ok {
		t.Fatalf("첫 줄이 %q로 끝나지 않는다", ")")
	}
	parts := strings.Split(body, ",")
	if len(parts) != 3 {
		t.Fatalf("첫 줄의 항목이 %d개다: %q", len(parts), lines[0])
	}
	if parts[0] != g.UtilTypes {
		t.Errorf("util_types = %q, 원함 %q", parts[0], g.UtilTypes)
	}
	gotV := mustCount(t, parts[1], "V")
	gotA := mustCount(t, parts[2], "A")
	if gotV != int64(len(g.Vertices)) {
		t.Errorf("정점 수 = %d, 원함 %d(그림자 포함)", gotV, len(g.Vertices))
	}
	if gotA%102 != 0 || gotA < g.M {
		t.Errorf("호 수 = %d, 102의 배수이면서 %d 이상이라야 한다", gotA, g.M)
	}
	for i, l := range lines {
		if len(l) > 79 {
			t.Errorf("%d번째 줄이 %d자다(79자 넘음): %q", i, len(l), l)
		}
	}
	if !strings.HasPrefix(lines[len(lines)-1], "* Checksum ") {
		t.Errorf("마지막 줄 = %q, 검사합 줄이라야 한다", lines[len(lines)-1])
	}

//line gbsave.w:822
}

//line gbsave.w:868
func TestChecksumConventions(t *testing.T) {
	g, err := gbmiles.Miles(20, 0, 0, 0, 0, 5, 0, "../data")
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	base := filepath.Join(dir, "base.gb")
	if err := SaveGraph(g, base); err != nil {
		t.Fatal(err)
	}
	orig := readLines(t, base)

//line gbsave.w:883
	neg := append([]string(nil), orig...)
	neg[len(neg)-1] = "* Checksum -1"
	if _, err := restoreLines(t, dir, "neg.gb", neg); err != nil {
		t.Errorf("음수 검사합인데 실패했다: %v", err)
	}
	cmt := append([]string{"* 주석 줄", "* 또 하나"}, orig...)
	if _, err := restoreLines(t, dir, "cmt.gb", cmt); err != nil {
		t.Errorf("머리 주석 줄 때문에 실패했다: %v", err)
	}
	bad := append([]string(nil), orig...)
	bad[len(bad)-2] = strings.Replace(bad[len(bad)-2], "0", "9", 1)
	if _, err := restoreLines(t, dir, "bad.gb", bad); err == nil {
		t.Error("자료를 망가뜨렸는데 검사합이 통과했다")
	}

//line gbsave.w:880
}

//line gbsave.w:902
func mustCount(t *testing.T, s, suffix string) int64 {
	t.Helper()
	body, ok := strings.CutSuffix(s, suffix)
	if !ok {
		t.Fatalf("%q가 %q로 끝나지 않는다", s, suffix)
	}
	n, err := strconv.ParseInt(body, 10, 64)
	if err != nil {
		t.Fatalf("%q를 수로 읽을 수 없다", s)
	}
	return n
}

func readLines(t *testing.T, path string) []string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return strings.Split(strings.TrimSuffix(string(b), "\n"), "\n")
}

func restoreLines(t *testing.T, dir, name string,
	lines []string) (*gbgraph.Graph, error) {
	t.Helper()
	path := filepath.Join(dir, name)
	body := strings.Join(lines, "\n") + "\n"
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	return RestoreGraph(path)
}
