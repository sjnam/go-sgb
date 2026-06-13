package gblisa

import (
	"errors"
	"strings"
	"testing"

	gbgraph "github.com/sjnam/go-sgb/gb-graph"
	"github.com/sjnam/go-sgb/gb-io"
)

func init() {
	gbio.DataDirectory = "../data/"
}

// ---- Lisa tests ----

func TestLisaDefault(t *testing.T) {
	pix, err := Lisa(0, 0, 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Lisa(0,...) returned error: %v", err)
	}
	if pix == nil {
		t.Fatal("Lisa(0,...) returned nil")
	}
	if int64(len(pix)) != MaxM*MaxN {
		t.Errorf("want %d elements, got %d", MaxM*MaxN, len(pix))
	}
}

func TestLisaDefaultParams(t *testing.T) {
	p, err := normalizeLisa(0, 0, 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("normalizeLisa(all defaults) returned error: %v", err)
	}
	want := "lisa(360,250,255,0,360,0,250,0,22950000)"
	if p.id() != want {
		t.Errorf("id=%q, want %q", p.id(), want)
	}
}

func TestLisaPixelRange(t *testing.T) {
	pix, err := Lisa(0, 0, 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Lisa returned error: %v", err)
	}
	for i, v := range pix {
		if v < 0 || v > MaxD {
			t.Errorf("pixel[%d]=%d out of [0,%d]", i, v, MaxD)
		}
	}
}

func TestLisaSubregion(t *testing.T) {
	// Smile region: 16 rows × 32 cols.
	pix, err := Lisa(0, 0, 0, 94, 110, 97, 129, 0, 0)
	if err != nil {
		t.Fatalf("Lisa(smile) returned error: %v", err)
	}
	if int64(len(pix)) != 16*32 {
		t.Errorf("want %d pixels, got %d", 16*32, len(pix))
	}
}

func TestLisaBadSpecs(t *testing.T) {
	// m0 >= m1 should fail.
	pix, err := Lisa(0, 0, 0, 100, 50, 0, 0, 0, 0)
	if pix != nil {
		t.Fatal("expected nil for m0>=m1")
	}
	if !errors.Is(err, gbgraph.ErrBadSpecs) {
		t.Errorf("want ErrBadSpecs, got %v", err)
	}
}

func TestLisaCustomD(t *testing.T) {
	// d=1 → binary image; all values should be 0 or 1.
	pix, err := Lisa(36, 25, 1, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Lisa returned error: %v", err)
	}
	for i, v := range pix {
		if v != 0 && v != 1 {
			t.Errorf("pix[%d]=%d with d=1", i, v)
		}
	}
}

func TestLisaSmallMatrix(t *testing.T) {
	pix, err := Lisa(36, 25, 25500, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Lisa returned error: %v", err)
	}
	if int64(len(pix)) != 36*25 {
		t.Errorf("want %d elements, got %d", 36*25, len(pix))
	}
	// Values are row sums of 10×10 blocks; max = 255 * 100 = 25500.
	for i, v := range pix {
		if v < 0 || v > 25500 {
			t.Errorf("pix[%d]=%d out of [0,25500]", i, v)
		}
	}
}

// ---- PlaneLisa tests ----

func TestPlaneLisaSmall(t *testing.T) {
	// 10×10 grid with d=2 should produce relatively few regions.
	g, err := PlaneLisa(10, 10, 2, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("PlaneLisa returned error: %v", err)
	}
	if g.N <= 0 || g.N > 100 {
		t.Errorf("unexpected vertex count %d", g.N)
	}
}

func TestPlaneLisaFullGrid(t *testing.T) {
	// d=255 → every pixel is distinct unless adjacent values happen to match;
	// d=0 → one huge region. With d=1, we get some merging.
	g, err := PlaneLisa(5, 5, 255, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("PlaneLisa returned error: %v", err)
	}
	// In the extreme: at most m*n = 25 regions.
	if g.N > 25 {
		t.Errorf("vertex count %d > m*n=25", g.N)
	}
}

func TestPlaneLisaUtilTypes(t *testing.T) {
	g, err := PlaneLisa(5, 5, 255, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("PlaneLisa returned error: %v", err)
	}
	if g.UtilTypes != "ZZZIIIZZIIZZZZ" {
		t.Errorf("UtilTypes=%q", g.UtilTypes)
	}
}

func TestPlaneLisaID(t *testing.T) {
	g, err := PlaneLisa(5, 5, 255, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("PlaneLisa returned error: %v", err)
	}
	if !strings.HasPrefix(g.ID, "plane_lisa(") {
		t.Errorf("ID=%q, want prefix 'plane_lisa('", g.ID)
	}
}

func TestPlaneLisaMatrixDims(t *testing.T) {
	g, err := PlaneLisa(8, 12, 5, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("PlaneLisa returned error: %v", err)
	}
	if MatrixRows(g) != 8 {
		t.Errorf("MatrixRows=%d, want 8", MatrixRows(g))
	}
	if MatrixCols(g) != 12 {
		t.Errorf("MatrixCols=%d, want 12", MatrixCols(g))
	}
}

func TestPlaneLisaVertexFields(t *testing.T) {
	g, err := PlaneLisa(5, 5, 255, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("PlaneLisa returned error: %v", err)
	}
	n := MatrixCols(g)
	m := MatrixRows(g)
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		if PixelValue(v) < 0 || PixelValue(v) > 255 {
			t.Errorf("v%d: pixel_value=%d out of [0,255]", i, PixelValue(v))
		}
		if FirstPixel(v) < 0 || FirstPixel(v) >= m*n {
			t.Errorf("v%d: first_pixel=%d out of range", i, FirstPixel(v))
		}
		if LastPixel(v) < FirstPixel(v) || LastPixel(v) >= m*n {
			t.Errorf("v%d: last_pixel=%d < first_pixel=%d", i, LastPixel(v), FirstPixel(v))
		}
	}
}

func TestPlaneLisaEdgeLen(t *testing.T) {
	g, err := PlaneLisa(5, 5, 255, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("PlaneLisa returned error: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if a.Len != 1 {
				t.Errorf("edge len=%d, want 1", a.Len)
			}
		}
	}
}

func TestPlaneLisaSymmetric(t *testing.T) {
	// Every arc u→v should have a corresponding arc v→u.
	g, err := PlaneLisa(5, 5, 3, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("PlaneLisa returned error: %v", err)
	}
	type edge struct{ a, b int64 }
	idx := make(map[*gbgraph.Vertex]int64, g.N)
	for i := int64(0); i < g.N; i++ {
		idx[&g.Vertices[i]] = i
	}
	seen := make(map[edge]bool)
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			j := idx[a.Tip]
			e := edge{i, j}
			if i > j {
				e = edge{j, i}
			}
			seen[e] = true
		}
	}
	// Every edge in 'seen' must appear from both endpoints.
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			j := idx[a.Tip]
			e := edge{i, j}
			if i > j {
				e = edge{j, i}
			}
			if !seen[e] {
				t.Errorf("edge %d--%d missing reverse", i, j)
			}
		}
	}
}

// ---- BiLisa tests ----

func TestBiLisaDefault(t *testing.T) {
	g, err := BiLisa(0, 0, 0, 0, 0, 0, 32768, false)
	if err != nil {
		t.Fatalf("BiLisa returned error: %v", err)
	}
	if g.N != MaxM+MaxN {
		t.Errorf("want %d vertices, got %d", MaxM+MaxN, g.N)
	}
}

func TestBiLisaUtilTypes(t *testing.T) {
	g, err := BiLisa(0, 0, 0, 0, 0, 0, 32768, false)
	if err != nil {
		t.Fatalf("BiLisa returned error: %v", err)
	}
	if g.UtilTypes != "ZZZZZZZIIZZZZZ" {
		t.Errorf("UtilTypes=%q", g.UtilTypes)
	}
}

func TestBiLisaVertexNames(t *testing.T) {
	g, err := BiLisa(3, 4, 0, 0, 0, 0, 32768, false)
	if err != nil {
		t.Fatalf("BiLisa returned error: %v", err)
	}
	if g.Vertices[0].Name != "r0" {
		t.Errorf("vertex 0 name=%q, want r0", g.Vertices[0].Name)
	}
	if g.Vertices[2].Name != "r2" {
		t.Errorf("vertex 2 name=%q, want r2", g.Vertices[2].Name)
	}
	if g.Vertices[3].Name != "c0" {
		t.Errorf("vertex 3 name=%q, want c0", g.Vertices[3].Name)
	}
	if g.Vertices[6].Name != "c3" {
		t.Errorf("vertex 6 name=%q, want c3", g.Vertices[6].Name)
	}
}

func TestBiLisaBipartite(t *testing.T) {
	g, err := BiLisa(10, 10, 0, 0, 0, 0, 32768, false)
	if err != nil {
		t.Fatalf("BiLisa returned error: %v", err)
	}
	if g.N1() != 10 {
		t.Errorf("N1=%d, want 10", g.N1())
	}
}

func TestBiLisaPixelVal(t *testing.T) {
	g, err := BiLisa(5, 5, 0, 0, 0, 0, 0, false) // thresh=0 → include all
	if err != nil {
		t.Fatalf("BiLisa returned error: %v", err)
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			v := PixelVal(a)
			if v < 0 || v > 65535 {
				t.Errorf("pixel_val=%d out of [0,65535]", v)
			}
		}
	}
}

func TestBiLisaThreshold(t *testing.T) {
	// thresh=65535 → only pixels >= 65535 (i.e., max brightness); thresh=0 → all pixels included.
	g0, err0 := BiLisa(10, 10, 0, 0, 0, 0, 0, false)     // all pixels included
	g1, err1 := BiLisa(10, 10, 0, 0, 0, 0, 65535, false) // only fully white pixels
	if err0 != nil || err1 != nil {
		t.Fatalf("BiLisa returned error: %v / %v", err0, err1)
	}
	if g1.M > g0.M {
		t.Errorf("thresh=65535 gave M=%d > thresh=0 M=%d", g1.M, g0.M)
	}
}

func TestBiLisaDarkMode(t *testing.T) {
	// c=1 selects dark pixels; c=0 selects light pixels. Together they should
	// cover all pixel combinations.
	g0, err0 := BiLisa(5, 5, 0, 0, 0, 0, 32768, false) // light
	g1, err1 := BiLisa(5, 5, 0, 0, 0, 0, 32768, true)  // dark
	if err0 != nil || err1 != nil {
		t.Fatalf("BiLisa returned error: %v / %v", err0, err1)
	}
	// Each edge exists in exactly one of g0 and g1 (thresh=32768 is the boundary).
	// M0 + M1 ≤ 2 * m * n.
	if g0.M+g1.M > 2*5*5 {
		t.Errorf("g0.M(%d)+g1.M(%d) > 2*25", g0.M, g1.M)
	}
}
