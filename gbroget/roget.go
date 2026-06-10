// Package roget implements GB_ROGET from Stanford GraphBase.
//
// Roget constructs a directed graph based on cross-references in the 1879
// edition of Roget's Thesaurus. Vertices are thesaurus categories; arcs
// represent explicit or implicit references between them.
//
// Vertex utility fields (UtilTypes "IZZZZZZZZZZZZZ"):
//
//	U = cat_no (int64: original Roget category number, 1..1022)
package gbroget

import (
	"fmt"

	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
)

const MaxN = 1022 // number of categories in Roget's Thesaurus (1879 edition)

// CatNo returns the original Roget category number for vertex v.
func CatNo(v *gbgraph.Vertex) int64 { i, _ := v.U.(int64); return i }

// Module-level state.
// Roget constructs a graph of Roget's Thesaurus cross-references.
//
//   - n: number of vertices (0 → 1022).
//   - minDistance: minimum |cat_i - cat_j| required for an arc (0 → all allowed).
//   - prob: probability 65536 * P(reject arc); 0 → keep all qualifying arcs.
//   - seed: random number seed.
//
// UtilTypes = "IZZZZZZZZZZZZZ".
func Roget(n, minDistance, prob, seed int64) (*gbgraph.Graph, error) {
	var mapping [MaxN + 1]*gbgraph.Vertex // mapping[k]: vertex assigned to category k (nil if unselected)
	var cats [MaxN]int64                  // cats[0..k-1]: category numbers not yet assigned

	rng := gbflip.New(seed)

	if n == 0 || n > MaxN {
		n = MaxN
	}

	g := gbgraph.NewGraph(n)
	g.ID = fmt.Sprintf("roget(%d,%d,%d,%d)", n, minDistance, prob, seed)
	g.UtilTypes = "IZZZZZZZZZZZZZ"

	// Select n categories at random and map them to vertices.
	for k := int64(0); k < MaxN; k++ {
		cats[k] = k + 1
		mapping[k+1] = nil
	}
	remaining := int64(MaxN)
	for vi := int64(n - 1); vi >= 0; vi-- {
		j := rng.Unif(remaining)
		mapping[cats[j]] = &g.Vertices[vi]
		cats[j] = cats[remaining-1]
		remaining--
	}

	// Read roget.dat and build arcs.
	r, err := gbio.Open("roget.dat")
	if err != nil {
		return nil, gbgraph.ErrEarlyDataFault
	}
	k := int64(1)
categories:
	for ; !r.GbEof(); k++ {
		if mapping[k] != nil {
			if int64(r.GbNumber(10)) != k {
				r.RawClose()
				return nil, gbgraph.ErrSyntaxError
			}
			name := r.GbString(':')
			if r.GbChar() != ':' {
				r.RawClose()
				return nil, gbgraph.ErrSyntaxError
			}
			v := mapping[k]
			v.Name = name
			v.U = k

			// Read arc targets.
			j := int64(r.GbNumber(10))
			if j == 0 {
				r.GbNewline()
				continue
			}
			for {
				if j > MaxN {
					r.RawClose()
					return nil, gbgraph.ErrSyntaxError
				}
				dist := j - k
				if dist < 0 {
					dist = -dist
				}
				if mapping[j] != nil && dist >= minDistance &&
					(prob == 0 || rng.Next()>>15 >= prob) {
					g.NewArc(v, mapping[j], 1)
				}
				switch r.GbChar() {
				case '\\':
					r.GbNewline()
					if r.GbChar() != ' ' {
						r.RawClose()
						return nil, gbgraph.ErrSyntaxError
					}
					j = int64(r.GbNumber(10))
				case ' ':
					j = int64(r.GbNumber(10))
				case '\n':
					r.GbNewline()
					continue categories
				default:
					r.RawClose()
					return nil, gbgraph.ErrSyntaxError
				}
			}
		} else {
			// Skip this category's line(s).
			s := r.GbString('\n')
			if len(s) > 0 && s[len(s)-1] == '\\' {
				r.GbNewline() // skip continuation line
			}
			r.GbNewline()
		}
	}

	if err := r.Close(); err != nil {
		return nil, gbgraph.ErrLateDataFault
	}
	if k != MaxN+1 {
		return nil, gbgraph.ErrImpossible
	}
	return g, nil
}
