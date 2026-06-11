// Package books implements GB_BOOKS from Stanford GraphBase:
// Book constructs character-encounter graphs from classic literature, and
// BiBook constructs the corresponding bipartite character×chapter graphs.
//
// The data files (anna.dat, david.dat, jean.dat, huck.dat, homer.dat) must be
// reachable via gb_io.DataDirectory or the working directory.
package gbbooks

import (
	"fmt"
	"strings"

	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/gbsort"
)

const (
	MaxChaps = 360
	maxChars = 600
	maxCode  = 1296 // 36×36
)

// charData holds per-character statistics accumulated during the first pass.
type charData struct {
	code int64
	in   int64           // appearances inside [firstChap, lastChap]
	out  int64           // appearances outside that interval
	chap int64           // most-recently-seen chapter (dedup sentinel)
	vert *gbgraph.Vertex // assigned vertex (nil if not selected)
}

type charNode = gbsort.Node[charData]

// ---- Utility-field accessors ------------------------------------------------
// Vertex utility fields:   U=short_code(I), X=out_count(I), Y=in_count(I), Z=desc(S)
// Arc    utility field:    A=chap_no(I)

func Desc(v *gbgraph.Vertex) string     { s, _ := v.Z.(string); return s }
func InCount(v *gbgraph.Vertex) int64   { i, _ := v.Y.(int64); return i }
func OutCount(v *gbgraph.Vertex) int64  { i, _ := v.X.(int64); return i }
func ShortCode(v *gbgraph.Vertex) int64 { i, _ := v.U.(int64); return i }
func ChapNo(a *gbgraph.Arc) int64       { i, _ := a.A.(int64); return i }

// Book creates an undirected character-encounter graph.
//
// The returned slice holds the structured chapter-number strings of the book:
// chapNames[0] is always "" and chapNames[k] is the label of chapter k, so the
// book has len(chapNames)-1 chapters.
func Book(title string, n, x, firstChap, lastChap, inWeight, outWeight, seed int64) (*gbgraph.Graph, []string, error) {
	return bgraph(false, title, n, x, firstChap, lastChap, inWeight, outWeight, seed)
}

// BiBook creates a bipartite character×chapter graph.
// The returned chapter-name slice has the same form as for Book.
func BiBook(title string, n, x, firstChap, lastChap, inWeight, outWeight, seed int64) (*gbgraph.Graph, []string, error) {
	return bgraph(true, title, n, x, firstChap, lastChap, inWeight, outWeight, seed)
}

func bgraph(bipartite bool, title string, n, x, firstChap, lastChap, inWeight, outWeight, seed int64) (*gbgraph.Graph, []string, error) {
	var nodeBlock [maxChars]charNode
	var xnode [maxCode]*charNode

	rng := gbflip.New(seed)

	if n == 0 {
		n = maxChars
	}
	if firstChap == 0 {
		firstChap = 1
	}
	if lastChap == 0 {
		lastChap = MaxChaps
	}
	if inWeight > 1_000_000 || inWeight < -1_000_000 ||
		outWeight > 1_000_000 || outWeight < -1_000_000 {
		return nil, nil, gbgraph.ErrBadSpecs
	}

	fileName := fmt.Sprintf("%.6s.dat", title)
	r1, err := gbio.Open(fileName)
	if err != nil {
		return nil, nil, gbgraph.ErrEarlyDataFault
	}

	// =========================================================
	// First pass: skim the data file
	// =========================================================

	// Reset the code→node table.
	for k := range maxCode {
		xnode[k] = nil
	}

	// Read the cast of characters (lines like "AL Alexey...\n").
	var characters int64
	{
		p := 0 // nodeBlock index
		for {
			c := int64(r1.GbNumber(36))
			if c == 0 {
				break // blank line terminates the cast
			}
			if c >= maxCode || r1.GbChar() != ' ' {
				r1.RawClose()
				return nil, nil, gbgraph.ErrSyntaxError
			}
			if p >= maxChars {
				r1.RawClose()
				return nil, nil, gbgraph.ErrSyntaxError
			}
			nd := &nodeBlock[p]
			if p == 0 {
				nd.Link = nil
			} else {
				nd.Link = &nodeBlock[p-1]
			}
			nd.Val.code = c
			xnode[c] = nd
			nd.Val.in, nd.Val.out, nd.Val.chap = 0, 0, 0
			nd.Val.vert = nil
			p++
			r1.GbNewline()
		}
		characters = int64(p)
		r1.GbNewline() // skip blank separator line
	}

	// Skim chapter data, tallying per-character chapter counts.
	var chapters int64
	{
		k := int64(1)
		for ; k < MaxChaps && !r1.GbEof(); k++ {
			chapStr := r1.GbString(':')
			if len(chapStr) > 0 && chapStr[0] == '&' {
				k-- // continuation line: same chapter number
			}
			for r1.GbChar() != '\n' {
				c := int64(r1.GbNumber(36))
				if c >= maxCode {
					r1.RawClose()
					return nil, nil, gbgraph.ErrSyntaxError
				}
				p := xnode[c]
				if p == nil {
					r1.RawClose()
					return nil, nil, gbgraph.ErrSyntaxError
				}
				if p.Val.chap != k {
					p.Val.chap = k
					if k >= firstChap && k <= lastChap {
						p.Val.in++
					} else {
						p.Val.out++
					}
				}
			}
			r1.GbNewline()
		}
		if k == MaxChaps {
			r1.RawClose()
			return nil, nil, gbgraph.ErrSyntaxError
		}
		chapters = k - 1
	}
	chapName := make([]string, chapters+1) // chapName[0] stays ""

	if err := r1.Close(); err != nil {
		return nil, nil, gbgraph.ErrLateDataFault
	}

	// =========================================================
	// Build the graph skeleton
	// =========================================================

	if n > characters {
		n = characters
	}
	if x > n {
		x = n
	}
	if lastChap > chapters {
		lastChap = chapters
	}
	if firstChap > lastChap {
		firstChap = lastChap + 1
	}

	var nVerts int64
	if bipartite {
		nVerts = (n - x) + (lastChap - firstChap + 1)
	} else {
		nVerts = n - x
	}
	g := gbgraph.NewGraph(nVerts)
	g.UtilTypes = "IZZIISIZZZZZZZ"
	{
		prefix := ""
		if bipartite {
			prefix = "bi_"
		}
		g.ID = fmt.Sprintf("%sbook(\"%s\",%d,%d,%d,%d,%d,%d,%d)",
			prefix, title, n, x, firstChap, lastChap, inWeight, outWeight, seed)
	}

	// chapBase: g.Vertices[chapBase+k] is the vertex for chapter k (bipartite only).
	chapBase := int64(0)
	if bipartite {
		g.MarkBipartite(n - x)
		chapBase = (n - x) - firstChap
	}

	// Compute sort keys and rank-order the characters.
	for i := int64(0); i < characters; i++ {
		nodeBlock[i].Key = inWeight*nodeBlock[i].Val.in +
			outWeight*nodeBlock[i].Val.out + 0x40000000
	}
	sorted := gbsort.LinksSort(&nodeBlock[characters-1], rng)

	// Walk the sorted buckets highest→lowest, assigning vertices.
	{
		vi := int64(0)
		xLeft := x // top-x nodes to skip
		nLeft := n // total nodes to consider
	outer:
		for j := 127; j >= 0; j-- {
			for p := sorted[j]; p != nil; p = p.Link {
				if xLeft > 0 {
					xLeft--
				} else {
					p.Val.vert = &g.Vertices[vi]
					vi++
				}
				nLeft--
				if nLeft == 0 {
					break outer
				}
			}
		}
	}

	// =========================================================
	// Second pass: read names/descriptions, then build edges
	// =========================================================

	r2, err := gbio.Open(fileName)
	if err != nil {
		return nil, nil, gbgraph.ErrImpossible
	}

	// Re-read character definitions to fill in vertex names and descriptions.
	for {
		c := int64(r2.GbNumber(36))
		if c == 0 {
			break
		}
		v := xnode[c].Val.vert
		if v != nil {
			if r2.GbChar() != ' ' {
				r2.RawClose()
				return nil, nil, gbgraph.ErrImpossible
			}
			v.Name = r2.GbString(',')
			if r2.GbChar() != ',' {
				r2.RawClose()
				return nil, nil, gbgraph.ErrSyntaxError
			}
			if r2.GbChar() != ' ' {
				r2.RawClose()
				return nil, nil, gbgraph.ErrSyntaxError
			}
			v.Z = r2.GbString('\n')
			v.Y = xnode[c].Val.in
			v.X = xnode[c].Val.out
			v.U = c
		}
		r2.GbNewline()
	}
	r2.GbNewline() // skip blank separator line

	// Reset the chap dedup sentinel for the second pass.
	for i := int64(0); i < characters; i++ {
		nodeBlock[i].Val.chap = 0
	}

	if bipartite {
		// Build bipartite edges: character↔chapter.
		for k := int64(1); !r2.GbEof(); k++ {
			chapStr := r2.GbString(':')
			isCont := len(chapStr) > 0 && chapStr[0] == '&'
			if isCont {
				k--
			} else {
				chapName[k] = strings.TrimSuffix(chapStr, "\n")
			}
			if k >= firstChap && k <= lastChap {
				u := &g.Vertices[chapBase+k]
				if !isCont {
					u.Name = chapName[k]
					u.Z = ""
					u.Y = int64(0)
					u.X = int64(0)
				}
				for r2.GbChar() != '\n' {
					c := int64(r2.GbNumber(36))
					p := xnode[c]
					if p.Val.chap != k {
						p.Val.chap = k
						if p.Val.vert != nil {
							g.NewEdge(p.Val.vert, u, 1)
							inC, _ := u.Y.(int64)
							u.Y = inC + 1
						} else {
							outC, _ := u.X.(int64)
							u.X = outC + 1
						}
					}
				}
			}
			r2.GbNewline()
		}
	} else {
		// Build encounter edges: make clique members pairwise adjacent.
		clique := make([]*gbgraph.Vertex, 30)
		for k := int64(1); !r2.GbEof(); k++ {
			chapStr := r2.GbString(':')
			if len(chapStr) > 0 && chapStr[0] == '&' {
				k--
			} else {
				chapName[k] = strings.TrimSuffix(chapStr, "\n")
			}
			if k >= firstChap && k <= lastChap {
				c := r2.GbChar() // consume ':' (or get '\n' for empty chapter)
				for c != '\n' {
					pp := 0 // number of selected vertices in this clique
					for {
						code := int64(r2.GbNumber(36))
						if xnode[code] != nil && xnode[code].Val.vert != nil {
							clique[pp] = xnode[code].Val.vert
							pp++
						}
						c = r2.GbChar() // ',' within clique, ';' or '\n' between cliques
						if c != ',' {
							break
						}
					}
					// Make every pair in this clique adjacent (if not already).
					for qi := 0; qi < pp-1; qi++ {
						for ri := qi + 1; ri < pp; ri++ {
							u, v := clique[qi], clique[ri]
							found := false
							for a := range u.AllArcs() {
								if a.Tip == v {
									found = true
									break
								}
							}
							if !found {
								g.NewEdge(u, v, 1)
								// Set chap_no on both arcs of the new edge.
								u.Arcs.A = k
								u.Arcs.Partner.A = k
							}
						}
					}
				}
			}
			r2.GbNewline()
		}
	}

	if err := r2.Close(); err != nil {
		return nil, nil, gbgraph.ErrImpossible
	}
	return g, chapName, nil
}
