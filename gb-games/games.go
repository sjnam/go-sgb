// Package games implements GB_GAMES from Stanford GraphBase.
//
// Games constructs a graph whose vertices are college football teams and
// whose arcs represent the games played between them during the 1990 season.
// Arc lengths record the points scored by the source team.
//
// Vertex utility fields (UtilTypes "IIZSSSIIZZZZZZ"):
//
//	U = ap   (int64: (ap0<<16)+ap1, Associated Press poll scores)
//	V = upi  (int64: (upi0<<16)+upi1, UPI coaches poll scores)
//	X = abbr (string: 2-5 character abbreviation code)
//	Y = nickname (string: team mascot name)
//	Z = conference (string: conference name, "" if independent)
//
// Arc utility fields:
//
//	A = venue (int64: HOME=1 if destination is home, NEUTRAL=2, AWAY=3 if source is home)
//	B = date  (int64: days after August 26, 1990)
package gbgames

import (
	"fmt"

	gbflip "github.com/sjnam/go-sgb/gb-flip"
	gbgraph "github.com/sjnam/go-sgb/gb-graph"
	gbio "github.com/sjnam/go-sgb/gb-io"
	gbsort "github.com/sjnam/go-sgb/gb-sort"
)

const (
	MaxN      = 120
	MaxDay    = 128
	MaxWeight = 131072

	HOME    = 1
	NEUTRAL = 2
	AWAY    = 3

	hashPrime = 1009
)

// maximum poll values present in games.dat
var (
	maxA0 = int64(1451)
	maxU0 = int64(666)
	maxA1 = int64(1475)
	maxU1 = int64(847)
)

// Vertex utility-field accessors.
func Ap(v *gbgraph.Vertex) int64          { i, _ := v.U.(int64); return i }
func Upi(v *gbgraph.Vertex) int64         { i, _ := v.V.(int64); return i }
func Abbr(v *gbgraph.Vertex) string       { s, _ := v.X.(string); return s }
func Nickname(v *gbgraph.Vertex) string   { s, _ := v.Y.(string); return s }
func Conference(v *gbgraph.Vertex) string { s, _ := v.Z.(string); return s }

// Arc utility-field accessors.
func Venue(a *gbgraph.Arc) int64 { i, _ := a.A.(int64); return i }
func Date(a *gbgraph.Arc) int64  { i, _ := a.B.(int64); return i }

type teamData struct {
	name, nick, abb string
	conf            string
	a0, u0, a1, u1  int64
	hashLink        *teamNode
	vert            *gbgraph.Vertex
}

type teamNode = gbsort.Node[teamData]

func hashAbb(abb string) int64 {
	h := int64(0)
	for i := 0; i < len(abb); i++ {
		h = (2*h + int64(abb[i])) % hashPrime
	}
	return h
}

// Games constructs a graph of the 1990 college football season.
//
//   - n: number of teams to include (0 or >120 → use 120).
//   - ap0Weight, upi0Weight, ap1Weight, upi1Weight: weight coefficients
//     (each must be in [-131072, 131072]).
//   - firstDay, lastDay: day range for games to include (0 → 128 for lastDay).
//   - seed: random number seed for breaking weight ties.
//
// UtilTypes = "IIZSSSIIZZZZZZ".
func Games(n, ap0Weight, upi0Weight, ap1Weight, upi1Weight, firstDay, lastDay, seed int64) (*gbgraph.Graph, error) {
	var nodeBlock [MaxN]teamNode
	var htab [hashPrime]*teamNode

	teamLookup := func(r *gbio.Reader) *gbgraph.Vertex {
		h := int64(0)
		var buf []byte
		for r.GbDigit(10) < 0 {
			c := r.GbChar()
			h = (2*h + int64(c)) % hashPrime
			buf = append(buf, c)
		}
		r.GbBackup()
		abb := string(buf)
		for p := htab[h]; p != nil; p = p.Val.hashLink {
			if p.Val.abb == abb {
				return p.Val.vert
			}
		}
		return nil
	}

	rng := gbflip.New(seed)

	if n == 0 || n > MaxN {
		n = MaxN
	}
	if ap0Weight > MaxWeight || ap0Weight < -MaxWeight ||
		upi0Weight > MaxWeight || upi0Weight < -MaxWeight ||
		ap1Weight > MaxWeight || ap1Weight < -MaxWeight ||
		upi1Weight > MaxWeight || upi1Weight < -MaxWeight {
		return nil, gbgraph.ErrBadSpecs
	}
	if firstDay < 0 {
		firstDay = 0
	}
	if lastDay == 0 || lastDay > MaxDay {
		lastDay = MaxDay
	}

	g := gbgraph.NewGraph(n)
	g.ID = fmt.Sprintf("games(%d,%d,%d,%d,%d,%d,%d,%d)",
		n, ap0Weight, upi0Weight, ap1Weight, upi1Weight, firstDay, lastDay, seed)
	g.UtilTypes = "IIZSSSIIZZZZZZ"

	r, err := gbio.Open("games.dat")
	if err != nil {
		return nil, gbgraph.ErrEarlyDataFault
	}

	// Clear hash table.
	for i := range htab {
		htab[i] = nil
	}

	// Read the 120 team records.
	for k := range int64(MaxN) {
		p := &nodeBlock[k]
		if k > 0 {
			p.Link = &nodeBlock[k-1]
		} else {
			p.Link = nil
		}

		p.Val.abb = r.GbString(' ')
		if r.GbChar() != ' ' {
			r.RawClose()
			return nil, gbgraph.ErrSyntaxError
		}

		// Insert abbreviation into hash table.
		h := hashAbb(p.Val.abb)
		p.Val.hashLink = htab[h]
		htab[h] = p

		p.Val.name = r.GbString('(')
		if r.GbChar() != '(' {
			r.RawClose()
			return nil, gbgraph.ErrSyntaxError
		}
		p.Val.nick = r.GbString(')')
		if r.GbChar() != ')' {
			r.RawClose()
			return nil, gbgraph.ErrSyntaxError
		}

		// Conference: read until ';'. "Independent" maps to empty string.
		conf := r.GbString(';')
		if r.GbChar() != ';' {
			r.RawClose()
			return nil, gbgraph.ErrSyntaxError
		}
		if conf == "Independent" {
			p.Val.conf = ""
		} else {
			p.Val.conf = conf
		}

		// Poll scores: a0,u0;a1,u1
		p.Val.a0 = int64(r.GbNumber(10))
		if p.Val.a0 > maxA0 || r.GbChar() != ',' {
			r.RawClose()
			return nil, gbgraph.ErrSyntaxError
		}
		p.Val.u0 = int64(r.GbNumber(10))
		if p.Val.u0 > maxU0 || r.GbChar() != ';' {
			r.RawClose()
			return nil, gbgraph.ErrSyntaxError
		}
		p.Val.a1 = int64(r.GbNumber(10))
		if p.Val.a1 > maxA1 || r.GbChar() != ',' {
			r.RawClose()
			return nil, gbgraph.ErrSyntaxError
		}
		p.Val.u1 = int64(r.GbNumber(10))
		if p.Val.u1 > maxU1 || r.GbChar() != '\n' {
			r.RawClose()
			return nil, gbgraph.ErrSyntaxError
		}

		p.Key = ap0Weight*p.Val.a0 + upi0Weight*p.Val.u0 +
			ap1Weight*p.Val.a1 + upi1Weight*p.Val.u1 + 0x40000000

		r.GbNewline()
	}

	// Sort teams by weight; assign the top n to vertices.
	sorted := gbsort.LinksSort(&nodeBlock[MaxN-1], rng)
	vi := int64(0)
	for j := 127; j >= 0; j-- {
		for p := sorted[j]; p != nil; p = p.Link {
			if vi < n {
				v := &g.Vertices[vi]
				v.U = (p.Val.a0 << 16) + p.Val.a1
				v.V = (p.Val.u0 << 16) + p.Val.u1
				v.X = p.Val.abb
				v.Y = p.Val.nick
				if p.Val.conf != "" {
					v.Z = p.Val.conf
				}
				v.Name = p.Val.name
				p.Val.vert = v
				vi++
			} else {
				p.Val.abb = "" // mark as excluded
			}
		}
	}

	// Read games and build arcs.
	today := int64(0)
	for !r.GbEof() {
		c := r.GbChar()
		if c == '>' {
			// Date change line: >MonthCode##
			mc := r.GbChar()
			var base int64
			switch mc {
			case 'A':
				base = -26
			case 'S':
				base = 5
			case 'O':
				base = 35
			case 'N':
				base = 66
			case 'D':
				base = 96
			case 'J':
				base = 127
			default:
				base = 1000
			}
			d := base + int64(r.GbNumber(10))
			if d < 0 || d > MaxDay {
				r.RawClose()
				return nil, gbgraph.ErrSyntaxError
			}
			today = d
			r.GbNewline()
			continue
		}
		r.GbBackup()

		u := teamLookup(r)
		su := int64(r.GbNumber(10))
		sep := r.GbChar()
		var ven int64
		switch sep {
		case '@':
			ven = HOME
		case ',':
			ven = NEUTRAL
		default:
			r.RawClose()
			return nil, gbgraph.ErrSyntaxError
		}
		v := teamLookup(r)
		sv := int64(r.GbNumber(10))
		if r.GbChar() != '\n' {
			r.RawClose()
			return nil, gbgraph.ErrSyntaxError
		}

		if u != nil && v != nil && today >= firstDay && today <= lastDay {
			addGame(g, u, v, su, sv, ven, today)
		}

		r.GbNewline()
	}

	if err := r.Close(); err != nil {
		return nil, gbgraph.ErrLateDataFault
	}
	return g, nil
}

// addGame inserts a pair of arcs for one game between u and v.
// The arc from u to v gets length su; the arc from v to u gets length sv.
// Per SGB convention, the arc from the lower-addressed vertex is added first
// so the two arcs are always consecutive in the arc block.
func addGame(g *gbgraph.Graph, u, v *gbgraph.Vertex, su, sv, ven, today int64) {
	// Ensure u < v by pointer address (matches C convention).
	if gbgraph.VertexIndex(g, u) > gbgraph.VertexIndex(g, v) {
		u, v = v, u
		su, sv = sv, su
		ven = HOME + AWAY - ven
	}
	g.NewArc(u, v, su)
	g.NewArc(v, u, sv)
	arcU := u.Arcs
	arcV := v.Arcs
	arcU.A = ven
	arcU.B = today
	arcV.A = HOME + AWAY - ven
	arcV.B = today
}
