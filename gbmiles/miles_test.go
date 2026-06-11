package gbmiles

import (
	"errors"
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
)

func init() {
	gbio.DataDirectory = "../data/"
}

func TestMiles128(t *testing.T) {
	g, _, err := Miles(128, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Miles(128,...) failed: %v", err)
	}
	if g.N != 128 {
		t.Errorf("expected 128 vertices, got %d", g.N)
	}
	if g.UtilTypes != "ZZIIIIZZZZZZZZ" {
		t.Errorf("wrong util types: %q", g.UtilTypes)
	}
}

func TestMilesDefault(t *testing.T) {
	// n=0 → defaults to 128
	g, _, err := Miles(0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Miles(0,...) failed: %v", err)
	}
	if g.N != 128 {
		t.Errorf("expected 128 vertices, got %d", g.N)
	}
}

func TestMiles100PopWeight(t *testing.T) {
	// 100 most populous cities
	g, _, err := Miles(100, 0, 0, 1, 0, 0, 0)
	if err != nil {
		t.Fatalf("Miles(100,pop) failed: %v", err)
	}
	if g.N != 100 {
		t.Errorf("expected 100 vertices, got %d", g.N)
	}
	// San Diego is documented as the most populous city in miles.dat.
	if g.Vertices[0].Name != "San Diego, CA" {
		t.Errorf("expected first city 'San Diego, CA', got %q", g.Vertices[0].Name)
	}
}

func TestMilesVertexFields(t *testing.T) {
	g, _, err := Miles(128, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Miles failed: %v", err)
	}
	// Every vertex must have valid coordinate and population fields.
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		idx := IndexNo(v)
		if idx < 0 || idx >= MaxN {
			t.Errorf("vertex %d: index_no=%d out of range", i, idx)
		}
		if People(v) <= 0 {
			t.Errorf("vertex %d (%s): non-positive population", i, v.Name)
		}
		if XCoord(v) < 0 || YCoord(v) < 0 {
			t.Errorf("vertex %d (%s): negative coordinate", i, v.Name)
		}
	}
}

func TestMilesTriangleInequality(t *testing.T) {
	// The CWEB docs say miles.dat satisfies the triangle inequality.
	g, dm, err := Miles(128, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Miles failed: %v", err)
	}
	n := g.N
	for i := range n {
		u := &g.Vertices[i]
		for j := range n {
			v := &g.Vertices[j]
			for k := range n {
				w := &g.Vertices[k]
				duv := dm.Distance(u, v)
				dvw := dm.Distance(v, w)
				duw := dm.Distance(u, w)
				if duv > 0 && dvw > 0 && duw > 0 {
					if duv+dvw < duw {
						t.Errorf("triangle inequality violated: %s-%s=%d, %s-%s=%d, %s-%s=%d",
							u.Name, v.Name, duv,
							v.Name, w.Name, dvw,
							u.Name, w.Name, duw)
					}
				}
			}
		}
	}
}

func TestMilesEdgeLengths(t *testing.T) {
	g, dm, err := Miles(128, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Miles failed: %v", err)
	}
	// Every arc length must match MilesDistance.
	for i := int64(0); i < g.N; i++ {
		u := &g.Vertices[i]
		for a := u.Arcs; a != nil; a = a.Next {
			v := a.Tip
			expected := dm.Distance(u, v)
			if a.Len != expected {
				t.Errorf("%s→%s: arc len=%d but MilesDistance=%d",
					u.Name, v.Name, a.Len, expected)
			}
		}
	}
}

func TestMilesMaxDistance(t *testing.T) {
	const limit = 500
	g, _, err := Miles(128, 0, 0, 0, limit, 0, 0)
	if err != nil {
		t.Fatalf("Miles(maxDist=%d) failed: %v", limit, err)
	}
	for i := int64(0); i < g.N; i++ {
		u := &g.Vertices[i]
		for a := u.Arcs; a != nil; a = a.Next {
			if a.Len > limit {
				t.Errorf("%s→%s: arc len %d exceeds max_distance %d",
					u.Name, a.Tip.Name, a.Len, limit)
			}
		}
	}
}

func TestMilesMaxDegree(t *testing.T) {
	const deg = 3
	g, _, err := Miles(128, 0, 0, 0, 0, deg, 0)
	if err != nil {
		t.Fatalf("Miles(maxDeg=%d) failed: %v", deg, err)
	}
	// Each vertex has at most deg edges (undirected: count arcs / 2 ≤ deg).
	// Actually max_degree limits OUTGOING edges for each city's constraint,
	// and an edge appears only when BOTH cities kept it, so degree ≤ deg.
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		cnt := 0
		for a := v.Arcs; a != nil; a = a.Next {
			cnt++
		}
		if int64(cnt) > deg {
			t.Errorf("%s has degree %d > max_degree %d", v.Name, cnt, deg)
		}
	}
}

func TestMilesID(t *testing.T) {
	g, _, err := Miles(100, 0, 0, 1, 0, 0, 0)
	if err != nil {
		t.Fatalf("Miles failed: %v", err)
	}
	if g.ID != "miles(100,0,0,1,0,0,0)" {
		t.Errorf("unexpected ID: %q", g.ID)
	}
}

func TestMilesBadSpecs(t *testing.T) {
	_, _, err := Miles(10, 200000, 0, 0, 0, 0, 0)
	if err == nil {
		t.Fatal("expected error for bad north_weight")
	}
	if !errors.Is(err, gbgraph.ErrBadSpecs) {
		t.Errorf("expected ErrBadSpecs, got %v", err)
	}
}

func TestMilesDistance(t *testing.T) {
	g, dm, err := Miles(128, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Miles failed: %v", err)
	}
	// MilesDistance should be symmetric and positive for all pairs.
	for i := int64(0); i < g.N; i++ {
		u := &g.Vertices[i]
		for j := i + 1; j < g.N; j++ {
			v := &g.Vertices[j]
			duv := dm.Distance(u, v)
			dvu := dm.Distance(v, u)
			if duv != dvu {
				t.Errorf("%s↔%s: asymmetric (%d vs %d)", u.Name, v.Name, duv, dvu)
			}
			if duv <= 0 {
				t.Errorf("%s↔%s: non-positive distance %d", u.Name, v.Name, duv)
			}
		}
	}
}
