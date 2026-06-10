package gbgames

import (
	"errors"
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
)

func init() {
	gbio.DataDirectory = "../data/"
}

func TestGames120(t *testing.T) {
	g, err := Games(120, 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Games(120,...) error: %v", err)
	}
	if g == nil {
		t.Fatal("Games(120,...) returned nil")
	}
	if g.N != 120 {
		t.Errorf("expected 120 vertices, got %d", g.N)
	}
	if g.UtilTypes != "IIZSSSIIZZZZZZ" {
		t.Errorf("wrong util types: %q", g.UtilTypes)
	}
}

func TestGamesDefault(t *testing.T) {
	g, err := Games(0, 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Games(0,...) error: %v", err)
	}
	if g == nil {
		t.Fatal("Games(0,...) returned nil")
	}
	if g.N != 120 {
		t.Errorf("expected 120 vertices, got %d", g.N)
	}
}

func TestGamesID(t *testing.T) {
	g, err := Games(120, 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Games returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Games returned nil")
	}
	want := "games(120,0,0,0,0,0,128,0)"
	if g.ID != want {
		t.Errorf("ID=%q, want %q", g.ID, want)
	}
}

func TestGamesBadSpecs(t *testing.T) {
	g, err := Games(10, 200000, 0, 0, 0, 0, 0, 0)
	if g != nil {
		t.Fatal("expected nil for out-of-range weight")
	}
	if !errors.Is(err, gbgraph.ErrBadSpecs) {
		t.Errorf("expected ErrBadSpecs, got %v", err)
	}
}

func TestGamesVertexFields(t *testing.T) {
	g, err := Games(120, 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Games returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Games returned nil")
	}
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		if v.Name == "" {
			t.Errorf("vertex %d: empty name", i)
		}
		if Abbr(v) == "" {
			t.Errorf("vertex %d (%s): empty abbr", i, v.Name)
		}
		if Nickname(v) == "" {
			t.Errorf("vertex %d (%s): empty nickname", i, v.Name)
		}
	}
}

func TestGamesArcFields(t *testing.T) {
	g, err := Games(120, 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Games returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Games returned nil")
	}
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		for a := v.Arcs; a != nil; a = a.Next {
			ven := Venue(a)
			if ven != HOME && ven != NEUTRAL && ven != AWAY {
				t.Errorf("%s: invalid venue %d", v.Name, ven)
			}
			d := Date(a)
			if d < 0 || d > MaxDay {
				t.Errorf("%s: invalid date %d", v.Name, d)
			}
			if a.Len < 0 {
				t.Errorf("%s: negative score %d", v.Name, a.Len)
			}
		}
	}
}

func TestGamesSymmetric(t *testing.T) {
	// Every arc u→v should have a matching arc v→u with complementary venue.
	g, err := Games(120, 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Games returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Games returned nil")
	}
	// Build vertex-pointer → index map.
	vIdx := make(map[*gbgraph.Vertex]int64, g.N)
	for i := int64(0); i < g.N; i++ {
		vIdx[&g.Vertices[i]] = i
	}
	// Build adjacency map.
	type key struct{ u, v int64 }
	arcMap := make(map[key]int64) // key → venue
	for i := int64(0); i < g.N; i++ {
		u := &g.Vertices[i]
		for a := u.Arcs; a != nil; a = a.Next {
			arcMap[key{i, vIdx[a.Tip]}] = Venue(a)
		}
	}
	// Verify each arc has a reverse with complementary venue.
	for k, ven := range arcMap {
		rev, ok := arcMap[key{k.v, k.u}]
		if !ok {
			t.Errorf("arc %d→%d has no reverse", k.u, k.v)
			continue
		}
		if ven+rev != HOME+AWAY {
			t.Errorf("arc %d→%d: venue=%d, reverse venue=%d (should sum to %d)",
				k.u, k.v, ven, rev, HOME+AWAY)
		}
	}
}

func TestGamesDateFilter(t *testing.T) {
	// lastDay=50 should give fewer arcs than the full season.
	gFull, err := Games(120, 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Games(full) error: %v", err)
	}
	gHalf, err := Games(120, 0, 0, 0, 0, 0, 50, 0)
	if err != nil {
		t.Fatalf("Games(half) error: %v", err)
	}
	if gFull == nil || gHalf == nil {
		t.Fatal("Games returned nil")
	}
	mFull, mHalf := gFull.M, gHalf.M
	if mHalf >= mFull {
		t.Errorf("lastDay=50 gave M=%d, full season M=%d (expected fewer arcs)",
			mHalf, mFull)
	}
}

func TestGamesSubset(t *testing.T) {
	// Select 30 teams by ap1+upi1 weight (end-of-season polls).
	g, err := Games(30, 0, 0, 1, 1, 0, 0, 0)
	if err != nil {
		t.Fatalf("Games(30,poll) error: %v", err)
	}
	if g == nil {
		t.Fatal("Games(30,poll) returned nil")
	}
	if g.N != 30 {
		t.Errorf("expected 30 vertices, got %d", g.N)
	}
}

func TestGamesArcCount(t *testing.T) {
	// Full graph (120 teams, all games) has 638 games = 1276 arcs.
	g, err := Games(120, 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Games returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Games returned nil")
	}
	if g.M != 1276 {
		t.Errorf("expected 1276 arcs (638 games×2), got %d", g.M)
	}
}

func TestGamesConference(t *testing.T) {
	g, err := Games(120, 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Games returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Games returned nil")
	}
	// Count teams with a conference vs independents.
	withConf := 0
	for i := int64(0); i < g.N; i++ {
		if Conference(&g.Vertices[i]) != "" {
			withConf++
		}
	}
	// games.dat has 25 independent teams; the remaining 95 have conferences.
	if withConf != 95 {
		t.Errorf("expected 95 teams with conference, got %d", withConf)
	}
}

func TestGamesFirstGame(t *testing.T) {
	// Only the very first game (day 0: Colorado vs Tennessee).
	g, err := Games(120, 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		t.Fatalf("Games returned error: %v", err)
	}
	if g == nil {
		t.Fatal("Games returned nil")
	}
	// Find Colorado and Tennessee by abbreviation.
	var colo, tenn *gbgraph.Vertex
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		switch Abbr(v) {
		case "COLO":
			colo = v
		case "TENN":
			tenn = v
		}
	}
	if colo == nil || tenn == nil {
		t.Skip("COLO or TENN not in graph")
	}
	// There must be an arc between them with date=0.
	found := false
	for a := colo.Arcs; a != nil; a = a.Next {
		if a.Tip == tenn && Date(a) == 0 {
			found = true
			break
		}
	}
	if !found {
		t.Error("COLO→TENN arc with date=0 not found")
	}
}
