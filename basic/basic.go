// Package basic implements GB_BASIC from Stanford GraphBase:
// six graph generators (board, simplex, subsets, perms, parts, binary)
// and six graph transformers (complement, gunion, intersection, lines,
// product, induced), plus the bi_complete and wheel applications.
package basic

import (
	"fmt"
	"strings"

	"github.com/sjnam/go-sgb/graph"
)

// Product-graph type constants.
const (
	Cartesian = int64(0)
	Direct    = int64(1)
	Strong    = int64(2)
)

// IndGraph: induction codes ≥ IndGraph trigger graph substitution in Induced.
const IndGraph = int64(1_000_000_000)

const (
	maxD   = 91
	bufSz  = 4096
	maxNNN = 1_000_000_000.0
)

// Private arrays shared across generation routines (mirrors C static globals).
// basicState holds per-call working storage shared by Board, Simplex, Subsets,
// Perms, Parts, and Binary. Keeping it per-call makes those functions reentrant.
type basicState struct {
	nn  [maxD + 2]int64
	wr  [maxD + 2]int64
	del [maxD + 2]int64
	sig [maxD + 3]int64
	xx  [maxD + 2]int64
	yy  [maxD + 2]int64
}

const shortImap = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_^~&@,;.:?!%#$+-*/|<=>()[]{}`'"

// boolInt renders a flag as 0 or 1, matching the C-style ID strings of SGB.
func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

// vIdx returns the index of vertex v within g's vertex slice.
func vIdx(g *graph.Graph, v *graph.Vertex) int64 {
	return graph.VertexIndex(g, v)
}

// vMap maps vertex v (belonging to src) to the corresponding vertex in dst.
// Returns nil if the index falls outside dst.
func vMap(v *graph.Vertex, src, dst *graph.Graph) *graph.Vertex {
	i := vIdx(src, v)
	if i < 0 || i >= int64(len(dst.Vertices)) {
		return nil
	}
	return &dst.Vertices[i]
}

// inVertexSlice reports whether v points into the given slice.
func inVertexSlice(v *graph.Vertex, vertices []graph.Vertex) bool {
	return graph.VertexIn(v, vertices)
}

// --- Utility-field helpers ------------------------------------------------
// tmp   ≡ u.V   (*Vertex)
// tlen  ≡ z.A   (*Arc)
// mult  ≡ v.I   (int64)
// minlen≡ w.I   (int64)
// vmap  ≡ z.V   (*Vertex)  used in lines, induced
// ind   ≡ z.I   (int64)    set by caller of Induced
// subst ≡ y.G   (*Graph)   set by caller of Induced
// (tlen and vmap both live in Z; they're never live at the same time)

func getTmp(v *graph.Vertex) *graph.Vertex  { p, _ := v.U.(*graph.Vertex); return p }
func setTmp(v, u *graph.Vertex)             { v.U = u }
func getTlen(v *graph.Vertex) *graph.Arc    { p, _ := v.Z.(*graph.Arc); return p }
func setTlen(v *graph.Vertex, a *graph.Arc) { v.Z = a }
func getMult(v *graph.Vertex) int64         { i, _ := v.V.(int64); return i }
func setMult(v *graph.Vertex, i int64)      { v.V = i }
func getMinlen(v *graph.Vertex) int64       { i, _ := v.W.(int64); return i }
func setMinlen(v *graph.Vertex, i int64)    { v.W = i }
func getVmap(v *graph.Vertex) *graph.Vertex { p, _ := v.Z.(*graph.Vertex); return p }
func setVmap(v, u *graph.Vertex)            { v.Z = u }
func getInd(v *graph.Vertex) int64          { i, _ := v.Z.(int64); return i }
func setInd(v *graph.Vertex, i int64)       { v.Z = i }
func getSubst(v *graph.Vertex) *graph.Graph { g, _ := v.Y.(*graph.Graph); return g }

// SetInd sets the induction code for v (utility field z.I).  Callers of
// Induced use this to configure the graph before calling Induced.
func SetInd(v *graph.Vertex, i int64) { setInd(v, i) }

// SetSubst sets the substitution graph for v (utility field y.G).
func SetSubst(v *graph.Vertex, g *graph.Graph) { v.Y = g }

// =========================================================================
// Board
// =========================================================================

// Board constructs a graph based on moves of a generalized chesspiece on a
// d-dimensional rectangular board.
func Board(n1, n2, n3, n4, piece, wrap int64, directed bool) (*graph.Graph, error) {
	var st basicState
	if piece == 0 {
		piece = 1
	}
	if n1 <= 0 {
		n1, n2, n3 = 8, 8, 0
	}
	st.nn[1] = n1
	var d, k int64
	periodic := false
	if n2 <= 0 {
		k, d, n3, n4 = 2, -n2, 0, 0
		if d == 0 {
			d = k - 1
		} else {
			periodic = true
		}
	} else {
		st.nn[2] = n2
		if n3 <= 0 {
			k, d, n4 = 3, -n3, 0
			if d == 0 {
				d = k - 1
			} else {
				periodic = true
			}
		} else {
			st.nn[3] = n3
			if n4 <= 0 {
				k, d = 4, -n4
				if d == 0 {
					d = k - 1
				} else {
					periodic = true
				}
			} else {
				st.nn[4], d = n4, 4
			}
		}
	}
	if periodic {
		if d > maxD {
			return nil, graph.ErrBadSpecs
		}
		for j := int64(1); k <= d; j, k = j+1, k+1 {
			st.nn[k] = st.nn[j]
		}
	}

	// count vertices
	nnn := 1.0
	n := int64(1)
	for j := int64(1); j <= d; j++ {
		nnn *= float64(st.nn[j])
		if nnn > maxNNN {
			return nil, graph.ErrVeryBadSpecs
		}
		n *= st.nn[j]
	}
	g := graph.NewGraph(n)
	if g == nil {
		return nil, graph.ErrNoRoom
	}
	g.ID = fmt.Sprintf("board(%d,%d,%d,%d,%d,%d,%d)", n1, n2, n3, n4, piece, wrap, boolInt(directed))
	g.UtilTypes = "ZZZIIIZZZZZZZZ"

	// name vertices with mixed-radix counter st.xx[1..d]
	for k := int64(0); k <= d; k++ {
		st.xx[k] = 0
	}
	for vi := int64(0); vi < n; vi++ {
		v := &g.Vertices[vi]
		var buf strings.Builder
		for k := int64(1); k <= d; k++ {
			fmt.Fprintf(&buf, ".%d", st.xx[k])
		}
		s := buf.String()
		v.Name = s[1:]
		v.X = st.xx[1]
		v.Y = st.xx[2]
		v.Z = st.xx[3]
		for k := d; k >= 1; k-- {
			if st.xx[k]+1 < st.nn[k] {
				st.xx[k]++
				break
			}
			st.xx[k] = 0
		}
	}

	// initialise wr, sig, del tables
	{
		w := wrap
		for k := int64(1); k <= d; k++ {
			st.wr[k] = w & 1
			w >>= 1
			st.del[k] = 0
			st.sig[k] = 0
		}
		st.del[0] = 0
		st.sig[0] = 0
		st.sig[d+1] = 0
	}

	p := piece
	if p < 0 {
		p = -p
	}

	// outer loop: enumerate nonnegative del vectors summing to p
	for {
		var k int64
		for k = d; st.sig[k]+(st.del[k]+1)*(st.del[k]+1) > p; k-- {
			st.del[k] = 0
		}
		if k == 0 {
			break
		}
		st.del[k]++
		st.sig[k+1] = st.sig[k] + st.del[k]*st.del[k]
		for k++; k <= d; k++ {
			st.sig[k+1] = st.sig[k]
		}
		if st.sig[d+1] < p {
			continue
		}

		// inner loop: enumerate sign patterns for current |del|
		for {
			// generate moves for current del
			for k := int64(1); k <= d; k++ {
				st.xx[k] = 0
			}
			for vi := int64(0); vi < n; vi++ {
				v := &g.Vertices[vi]
				for k := int64(1); k <= d; k++ {
					st.yy[k] = st.xx[k] + st.del[k]
				}
				for l := int64(1); ; l++ {
					offBoard := false
					for k := int64(1); k <= d; k++ {
						for st.yy[k] < 0 {
							if st.wr[k] == 0 {
								offBoard = true
								break
							}
							st.yy[k] += st.nn[k]
						}
						if offBoard {
							break
						}
						for st.yy[k] >= st.nn[k] {
							if st.wr[k] == 0 {
								offBoard = true
								break
							}
							st.yy[k] -= st.nn[k]
						}
						if offBoard {
							break
						}
					}
					if offBoard {
						break
					}
					if piece < 0 {
						eq := true
						for k := int64(1); k <= d; k++ {
							if st.yy[k] != st.xx[k] {
								eq = false
								break
							}
						}
						if eq {
							break
						}
					}
					j := st.yy[1]
					for k := int64(2); k <= d; k++ {
						j = st.nn[k]*j + st.yy[k]
					}
					if directed {
						g.NewArc(v, &g.Vertices[j], l)
					} else {
						g.NewEdge(v, &g.Vertices[j], l)
					}
					if piece > 0 {
						break
					}
					for k := int64(1); k <= d; k++ {
						st.yy[k] += st.del[k]
					}
				}
				// advance mixed-radix counter
				for k := d; k >= 1; k-- {
					if st.xx[k]+1 < st.nn[k] {
						st.xx[k]++
						break
					}
					st.xx[k] = 0
				}
			}

			// advance to next sign pattern
			var k int64
			for k = d; st.del[k] <= 0; k-- {
				st.del[k] = -st.del[k]
			}
			if st.sig[k] == 0 {
				break
			}
			st.del[k] = -st.del[k]
		}
	}
	return g, nil
}

// =========================================================================
// Simplex
// =========================================================================

// normalizeSimplex fills st.nn[0..d] and sets d from the (n0..n4,0) sequence.
// n is the coordinate sum. Returns (d, periodic, k) where k is used for
// periodic expansion if periodic==true.
func (st *basicState) normalizeSimplex(n, n0, n1, n2, n3, n4 int64) (d, k int64, ok bool) {
	if n0 == 0 {
		n0 = -2
	}
	if n0 < 0 {
		k, d = 2, -n0
		st.nn[0] = n
		st.nn[k-1] = st.nn[0] // seed for periodic expansion: st.nn[1] = st.nn[0]
		return d, k, true
	}
	if n0 > n {
		n0 = n
	}
	st.nn[0] = n0
	if n1 <= 0 {
		k, d = 2, -n1
		if d == 0 {
			d = k - 2
			return d, k, false
		}
		st.nn[k-1] = st.nn[0]
		return d, k, true
	}
	if n1 > n {
		n1 = n
	}
	st.nn[1] = n1
	if n2 <= 0 {
		k, d = 3, -n2
		if d == 0 {
			d = k - 2
			return d, k, false
		}
		st.nn[k-1] = st.nn[0]
		return d, k, true
	}
	if n2 > n {
		n2 = n
	}
	st.nn[2] = n2
	if n3 <= 0 {
		k, d = 4, -n3
		if d == 0 {
			d = k - 2
			return d, k, false
		}
		st.nn[k-1] = st.nn[0]
		return d, k, true
	}
	if n3 > n {
		n3 = n
	}
	st.nn[3] = n3
	if n4 <= 0 {
		k, d = 5, -n4
		if d == 0 {
			d = k - 2
			return d, k, false
		}
		st.nn[k-1] = st.nn[0]
		return d, k, true
	}
	if n4 > n {
		n4 = n
	}
	st.nn[4] = n4
	d = 4
	return d, k, false
}

// countSimplexVerts computes the number of vertices for Simplex/Subsets.
func (st *basicState) countSimplexVerts(n, d int64) (int64, bool) {
	coef := make([]int64, n+1)
	for k := int64(0); k <= st.nn[0]; k++ {
		coef[k] = 1
	}
	var s int64
	for j := int64(1); j <= d; j++ {
		for k, i := n, n-st.nn[j]-1; i >= 0; k, i = k-1, i-1 {
			coef[k] -= coef[i]
		}
		s = 1
		for k := int64(1); k <= n; k++ {
			s += coef[k]
			if s > 1_000_000_000 {
				return 0, false
			}
			coef[k] = s
		}
	}
	return coef[n], true
}

// completeSimplex fills st.xx[k+1..d] to the lex-smallest completion.
// C: for(s=st.sig[k]-st.xx[k],k++;k<=d;s-=st.xx[k],k++){st.sig[k]=s;choose st.xx[k];}
func (st *basicState) completeSimplex(k, d int64) bool {
	s := st.sig[k] - st.xx[k]
	for k++; k <= d; k++ {
		st.sig[k] = s
		if s <= st.yy[k+1] {
			st.xx[k] = 0
		} else {
			st.xx[k] = s - st.yy[k+1]
		}
		s -= st.xx[k] // subtract newly chosen st.xx[k] (matches C's for-post)
	}
	return s == 0
}

// Simplex creates a graph based on generalized triangular configurations.
func Simplex(n, n0, n1, n2, n3, n4 int64, directed bool) (*graph.Graph, error) {
	var st basicState
	d, k, periodic := st.normalizeSimplex(n, n0, n1, n2, n3, n4)
	if periodic {
		if d > maxD {
			return nil, graph.ErrBadSpecs
		}
		for j := int64(1); k <= d; j, k = j+1, k+1 {
			st.nn[k] = st.nn[j]
		}
	}

	nverts, ok := st.countSimplexVerts(n, d)
	if !ok {
		return nil, graph.ErrVeryBadSpecs
	}
	g := graph.NewGraph(nverts)
	if g == nil {
		return nil, graph.ErrNoRoom
	}
	g.ID = fmt.Sprintf("simplex(%d,%d,%d,%d,%d,%d,%d)", n, n0, n1, n2, n3, n4, boolInt(directed))
	g.UtilTypes = "VVZIIIZZZZZZZZ"
	g.HashSetup()
	// clear hash heads (HashSetup sets them; we'll redo via HashIn)
	for i := int64(0); i < g.N; i++ {
		g.Vertices[i].V = nil
	}

	st.yy[d+1] = 0
	st.sig[0] = n
	for k2 := d; k2 >= 0; k2-- {
		st.yy[k2] = st.yy[k2+1] + st.nn[k2]
	}

	vi := int64(0)
	if st.yy[0] >= n {
		k2 := int64(0)
		if st.yy[1] >= n {
			st.xx[0] = 0
		} else {
			st.xx[0] = n - st.yy[1]
		}
	loop:
		for {
			st.completeSimplex(k2, d)
			// assign name
			v := &g.Vertices[vi]
			var buf strings.Builder
			for k3 := int64(0); k3 <= d; k3++ {
				fmt.Fprintf(&buf, ".%d", st.xx[k3])
			}
			s := buf.String()
			v.Name = s[1:]
			v.X = st.xx[0]
			v.Y = st.xx[1]
			v.Z = st.xx[2]
			g.HashIn(v)

			// arcs from previous vertices
			for j := int64(0); j < d; j++ {
				if st.xx[j] == 0 {
					continue
				}
				st.xx[j]--
				for k3 := j + 1; k3 <= d; k3++ {
					if st.xx[k3] < st.nn[k3] {
						st.xx[k3]++
						var buf2 strings.Builder
						for i := int64(0); i <= d; i++ {
							fmt.Fprintf(&buf2, ".%d", st.xx[i])
						}
						s2 := buf2.String()
						u := g.HashOut(s2[1:])
						if u == nil {
							g.Recycle()
							return nil, graph.ErrImpossible
						}
						if directed {
							g.NewArc(u, v, 1)
						} else {
							g.NewEdge(u, v, 1)
						}
						st.xx[k3]--
					}
				}
				st.xx[j]++
			}

			vi++
			// advance
			k2 = d - 1
			for {
				if st.xx[k2] < st.sig[k2] && st.xx[k2] < st.nn[k2] {
					st.xx[k2]++
					break
				}
				if k2 == 0 {
					break loop
				}
				k2--
			}
		}
	}
	if vi != g.N {
		return nil, graph.ErrImpossible
	}
	return g, nil
}

// =========================================================================
// Subsets
// =========================================================================

// Subsets creates a graph with the same vertices as Simplex but with
// adjacency defined by intersection size matching sizeBits.
func Subsets(n, n0, n1, n2, n3, n4, sizeBits int64, directed bool) (*graph.Graph, error) {
	var st basicState
	d, k, periodic := st.normalizeSimplex(n, n0, n1, n2, n3, n4)
	if periodic {
		if d > maxD {
			return nil, graph.ErrBadSpecs
		}
		for j := int64(1); k <= d; j, k = j+1, k+1 {
			st.nn[k] = st.nn[j]
		}
	}

	nverts, ok := st.countSimplexVerts(n, d)
	if !ok {
		return nil, graph.ErrVeryBadSpecs
	}
	g := graph.NewGraph(nverts)
	if g == nil {
		return nil, graph.ErrNoRoom
	}
	g.ID = fmt.Sprintf("subsets(%d,%d,%d,%d,%d,%d,0x%x,%d)", n, n0, n1, n2, n3, n4, sizeBits, boolInt(directed))
	g.UtilTypes = "ZZZIIIZZZZZZZZ"

	st.yy[d+1] = 0
	st.sig[0] = n
	for k2 := d; k2 >= 0; k2-- {
		st.yy[k2] = st.yy[k2+1] + st.nn[k2]
	}

	vi := int64(0)
	if st.yy[0] >= n {
		k2 := int64(0)
		if st.yy[1] >= n {
			st.xx[0] = 0
		} else {
			st.xx[0] = n - st.yy[1]
		}
	loop:
		for {
			st.completeSimplex(k2, d)
			v := &g.Vertices[vi]
			var buf strings.Builder
			for k3 := int64(0); k3 <= d; k3++ {
				fmt.Fprintf(&buf, ".%d", st.xx[k3])
			}
			s := buf.String()
			v.Name = s[1:]
			v.X = st.xx[0]
			v.Y = st.xx[1]
			v.Z = st.xx[2]

			// adjacency by intersection size
			for ui := int64(0); ui <= vi; ui++ {
				u := &g.Vertices[ui]
				ss := int64(0)
				p := u.Name
				for j := int64(0); j <= d; j++ {
					// parse next integer from p (format: "a.b.c...")
					var sv int64
					for len(p) > 0 && p[0] >= '0' && p[0] <= '9' {
						sv = sv*10 + int64(p[0]-'0')
						p = p[1:]
					}
					if len(p) > 0 && p[0] == '.' {
						p = p[1:]
					}
					if st.xx[j] < sv {
						ss += st.xx[j]
					} else {
						ss += sv
					}
				}
				if ss < 64 && (sizeBits>>uint(ss))&1 != 0 {
					if directed {
						g.NewArc(u, v, 1)
					} else {
						g.NewEdge(u, v, 1)
					}
				}
			}

			vi++
			k2 = d - 1
			for {
				if st.xx[k2] < st.sig[k2] && st.xx[k2] < st.nn[k2] {
					st.xx[k2]++
					break
				}
				if k2 == 0 {
					break loop
				}
				k2--
			}
		}
	}
	if vi != g.N {
		return nil, graph.ErrImpossible
	}
	return g, nil
}

// =========================================================================
// Perms
// =========================================================================

// Perms creates a graph whose vertices are permutations of a multiset with
// at most maxInv inversions; edges connect permutations that differ by one
// adjacent transposition.
func Perms(n0, n1, n2, n3, n4, maxInv int64, directed bool) (*graph.Graph, error) {
	var st basicState
	if n0 == 0 {
		n0 = 1
		n1 = 0
	} else if n0 < 0 {
		n1 = n0
		n0 = 1
	}
	// borrow simplex normalize with large n to avoid clamping
	d, k, periodic := st.normalizeSimplex(int64(bufSz), n0, n1, n2, n3, n4)
	if periodic {
		if d > maxD {
			return nil, graph.ErrBadSpecs
		}
		for j := int64(1); k <= d; j, k = j+1, k+1 {
			st.nn[k] = st.nn[j]
		}
	}
	// compute n (total elements) and maxInv
	var n, ss int64
	for k2, s := int64(0), int64(0); k2 <= d; k2++ {
		if st.nn[k2] >= bufSz {
			return nil, graph.ErrBadSpecs
		}
		ss += s * st.nn[k2]
		s += st.nn[k2]
		n = s
	}
	if n >= bufSz {
		return nil, graph.ErrBadSpecs
	}
	if maxInv == 0 || maxInv > ss {
		maxInv = ss
	}

	// compute number of vertices via z-multinomial coefficient
	coef := make([]int64, maxInv+1)
	coef[0] = 1
	s := st.nn[0]
	for j := int64(1); j <= d; j++ {
		for k2 := int64(1); k2 <= st.nn[j]; k2++ {
			for i, ii := maxInv, maxInv-k2-s; ii >= 0; i, ii = i-1, ii-1 {
				coef[i] -= coef[ii]
			}
			for i, ii := k2, int64(0); i <= maxInv; i, ii = i+1, ii+1 {
				coef[i] += coef[ii]
				if coef[i] > 1_000_000_000 {
					return nil, graph.ErrVeryBadSpecs
				}
			}
		}
		s += st.nn[j]
	}
	nverts := int64(1)
	for k2 := int64(1); k2 <= maxInv; k2++ {
		nverts += coef[k2]
		if nverts > 1_000_000_000 {
			return nil, graph.ErrVeryBadSpecs
		}
	}

	g := graph.NewGraph(nverts)
	if g == nil {
		return nil, graph.ErrNoRoom
	}
	g.ID = fmt.Sprintf("perms(%d,%d,%d,%d,%d,%d,%d)", n0, n1, n2, n3, n4, maxInv, boolInt(directed))
	g.UtilTypes = "VVZZZZZZZZZZZZ"
	for i := int64(0); i < g.N; i++ {
		g.Vertices[i].V = nil
	}

	xtab := make([]int64, 3*n+3)
	ytab := xtab[n+1:]
	ztab := ytab[n+1:]
	// initialize ztab (initial permutation) and xtab
	j2 := int64(0)
	for k2, s2 := int64(1), st.nn[0]; ; k2++ {
		xtab[k2] = j2
		ztab[k2] = j2
		if k2 == s2 {
			j2++
			if j2 > d {
				break
			}
			s2 += st.nn[j2]
		}
	}
	m := int64(0) // current inversion count

	vi := int64(0)
	buf := make([]byte, n)
	for {
		// assign name
		v := &g.Vertices[vi]
		for p, q := int64(n-1), int64(n); q > 0; p, q = p-1, q-1 {
			buf[p] = shortImap[xtab[q]]
		}
		v.Name = string(buf[:n])
		g.HashIn(v)

		// arcs from previous permutations (adjacent transpositions with one more inversion)
		for j2 := int64(1); j2 < n; j2++ {
			if xtab[j2] > xtab[j2+1] {
				buf[j2-1] = shortImap[xtab[j2+1]]
				buf[j2] = shortImap[xtab[j2]]
				u := g.HashOut(string(buf[:n]))
				if u == nil {
					g.Recycle()
					return nil, graph.ErrImpossible
				}
				if directed {
					g.NewArc(u, v, 1)
				} else {
					g.NewEdge(u, v, 1)
				}
				buf[j2-1] = shortImap[xtab[j2]]
				buf[j2] = shortImap[xtab[j2+1]]
			}
		}
		vi++

		// advance to next permutation
		advanced := false
		for k2 := n; k2 > 0; k2-- {
			if m < maxInv && ytab[k2] < k2-1 {
				if ytab[k2] < ytab[k2-1] || ztab[k2] > ztab[k2-1] {
					j3 := k2 - ytab[k2]
					xtab[j3] = xtab[j3-1]
					xtab[j3-1] = ztab[k2]
					ytab[k2]++
					m++
					advanced = true
					break
				}
			}
			if ytab[k2] != 0 {
				for j3 := k2 - ytab[k2]; j3 < k2; j3++ {
					xtab[j3] = xtab[j3+1]
				}
				m -= ytab[k2]
				ytab[k2] = 0
				xtab[k2] = ztab[k2]
			}
		}
		if !advanced {
			break
		}
	}
	if vi != g.N {
		return nil, graph.ErrImpossible
	}
	return g, nil
}

// =========================================================================
// Parts
// =========================================================================

// Parts creates a graph whose vertices are partitions of n into at most
// maxParts parts of size at most maxSize.
func Parts(n, maxParts, maxSize int64, directed bool) (*graph.Graph, error) {
	var st basicState
	if maxParts == 0 || maxParts > n {
		maxParts = n
	}
	if maxSize == 0 || maxSize > n {
		maxSize = n
	}
	if maxParts > maxD {
		return nil, graph.ErrBadSpecs
	}

	// count vertices: coefficient of z^n in z-binomial (maxParts+maxSize choose maxParts)_z
	coef := make([]int64, n+1)
	coef[0] = 1
	for k := int64(1); k <= maxParts; k++ {
		for j, i := n, n-k-maxSize; i >= 0; j, i = j-1, i-1 {
			coef[j] -= coef[i]
		}
		for j, i := k, int64(0); j <= n; j, i = j+1, i+1 {
			coef[j] += coef[i]
			if coef[j] > 1_000_000_000 {
				return nil, graph.ErrVeryBadSpecs
			}
		}
	}
	nverts := coef[n]

	g := graph.NewGraph(nverts)
	if g == nil {
		return nil, graph.ErrNoRoom
	}
	g.ID = fmt.Sprintf("parts(%d,%d,%d,%d)", n, maxParts, maxSize, boolInt(directed))
	g.UtilTypes = "VVZZZZZZZZZZZZ"
	for i := int64(0); i < g.N; i++ {
		g.Vertices[i].V = nil
	}

	// st.yy[k] = maxParts+1-k (minimum number of remaining parts)
	st.xx[0] = maxSize
	st.sig[1] = n
	for k, s := maxParts, int64(1); k > 0; k, s = k-1, s+1 {
		st.yy[k] = s
	}

	vi := int64(0)
	if maxSize*maxParts >= n {
		st.xx[1] = (n-1)/maxParts + 1
		k := int64(1)
		var d int64
	loop:
		for {
			// complete partial solution
			s := st.sig[k] - st.xx[k]
			for k2 := k + 1; s > 0; k2++ {
				st.sig[k2] = s
				st.xx[k2] = (s-1)/st.yy[k2] + 1
				s -= st.xx[k2]
			}
			// find d (last part index)
			d = k
			for d <= maxParts && st.xx[d] > 0 {
				d++
			}
			d--
			// also track using sig: find last nonzero xx
			d2 := k
			sRemain := st.sig[k] - st.xx[k]
			for sRemain > 0 {
				sRemain -= st.xx[d2+1]
				d2++
			}
			d = d2

			// assign name
			v := &g.Vertices[vi]
			var buf strings.Builder
			for k2 := int64(1); k2 <= d; k2++ {
				fmt.Fprintf(&buf, "+%d", st.xx[k2])
			}
			s2 := buf.String()
			v.Name = s2[1:]
			g.HashIn(v)

			// arcs to previous partitions (splitting a part)
			if d < maxParts {
				st.xx[d+1] = 0
				for j := int64(1); j <= d; j++ {
					if st.xx[j] != st.xx[j+1] {
						st.nn[j] = st.xx[j] // copy prefix before split
						for b, a := st.xx[j]/2, st.xx[j]-st.xx[j]/2; b > 0; a, b = a+1, b-1 {
							// split st.xx[j] into a+b; insert into sorted position
							var buf2 strings.Builder
							p2 := j + 1
							for st.xx[p2] > a {
								st.nn[p2-1] = st.xx[p2]
								p2++
							}
							st.nn[p2-1] = a
							for st.xx[p2] > b {
								st.nn[p2] = st.xx[p2]
								p2++
							}
							st.nn[p2] = b
							for ; p2 <= d; p2++ {
								st.nn[p2+1] = st.xx[p2]
							}
							for k2 := int64(1); k2 <= d+1; k2++ {
								fmt.Fprintf(&buf2, "+%d", st.nn[k2])
							}
							s3 := buf2.String()
							u := g.HashOut(s3[1:])
							if u == nil {
								g.Recycle()
								return nil, graph.ErrImpossible
							}
							if directed {
								g.NewArc(v, u, 1)
							} else {
								g.NewEdge(v, u, 1)
							}
						}
					}
					st.nn[j] = st.xx[j]
				}
			}

			vi++
			// advance
			if d == 1 {
				break loop
			}
			for k = d - 1; ; k-- {
				if st.xx[k] < st.sig[k] && st.xx[k] < st.xx[k-1] {
					st.xx[k]++
					break
				}
				if k == 1 {
					break loop
				}
			}
		}
	}
	if vi != g.N {
		return nil, graph.ErrImpossible
	}
	return g, nil
}

// =========================================================================
// Binary
// =========================================================================

// Binary creates a graph whose vertices are binary trees with n internal
// nodes and all leaves at height ≤ maxHeight.
func Binary(n, maxHeight int64, directed bool) (*graph.Graph, error) {
	var st basicState
	if 2*n+2 > bufSz {
		return nil, graph.ErrBadSpecs
	}
	if maxHeight == 0 || maxHeight > n {
		maxHeight = n
	}
	if maxHeight > 30 {
		return nil, graph.ErrVeryBadSpecs
	}

	var nverts int64
	if n >= 20 && maxHeight >= 6 {
		d := (int64(1) << uint(maxHeight)) - 1 - n
		if d > 8 {
			return nil, graph.ErrBadSpecs
		}
		if d < 0 {
			nverts = 0
		} else {
			st.nn[0] = 1
			st.nn[1] = 1
			for k := int64(2); k <= d; k++ {
				st.nn[k] = 0
			}
			for j := int64(2); j <= maxHeight; j++ {
				for k := d; k > 0; k-- {
					var ss float64
					for i := k; i >= 0; i-- {
						ss += float64(st.nn[i]) * float64(st.nn[k-i])
					}
					if ss > maxNNN {
						return nil, graph.ErrVeryBadSpecs
					}
					var s int64
					for i := k; i >= 0; i-- {
						s += st.nn[i] * st.nn[k-i]
					}
					st.nn[k] = s
				}
				i := (int64(1) << uint(j)) - 1
				if i <= d {
					st.nn[i]++
				}
			}
			nverts = st.nn[d]
		}
	} else {
		st.nn[0] = 1
		st.nn[1] = 1
		for k := int64(2); k <= n; k++ {
			st.nn[k] = 0
		}
		for j := int64(2); j <= maxHeight; j++ {
			for k := n - 1; k > 0; k-- {
				var s int64
				for i := k; i >= 0; i-- {
					s += st.nn[i] * st.nn[k-i]
				}
				st.nn[k+1] = s
			}
		}
		nverts = st.nn[n]
	}

	g := graph.NewGraph(nverts)
	if g == nil {
		return nil, graph.ErrNoRoom
	}
	g.ID = fmt.Sprintf("binary(%d,%d,%d)", n, maxHeight, boolInt(directed))
	g.UtilTypes = "VVZZZZZZZZZZZZ"
	for i := int64(0); i < g.N; i++ {
		g.Vertices[i].V = nil
	}

	d := 2 * n
	xtab := make([]int64, d+2)
	ytab := make([]int64, d+2)
	ltab := make([]int64, d+2)
	stab := make([]int64, d+2)

	ltab[0] = int64(1) << uint(maxHeight)
	stab[0] = n

	vi := int64(0)
	if ltab[0] > n {
		k := int64(0)
		if n != 0 {
			xtab[0] = 1
		}
	binaryLoop:
		for {
			// complete partial tree
			for j := k + 1; j <= d; j++ {
				if xtab[j-1] != 0 {
					ltab[j] = ltab[j-1] >> 1
					ytab[j] = ytab[j-1] + ltab[j]
					stab[j] = stab[j-1]
				} else {
					ytab[j] = ytab[j-1] & (ytab[j-1] - 1)
					ltab[j] = ytab[j-1] - ytab[j]
					stab[j] = stab[j-1] - 1
				}
				if stab[j] <= ytab[j] {
					xtab[j] = 0
				} else {
					xtab[j] = 1
				}
			}

			// assign Polish prefix code name
			v := &g.Vertices[vi]
			nameBuf := make([]byte, d+1)
			for k2 := int64(0); k2 <= d; k2++ {
				if xtab[k2] != 0 {
					nameBuf[k2] = '.'
				} else {
					nameBuf[k2] = 'x'
				}
			}
			v.Name = string(nameBuf)
			g.HashIn(v)

			// arcs via associativity rotations
			for j := int64(0); j < d; j++ {
				if xtab[j] == 1 && xtab[j+1] == 1 {
					// apply rotation: shift one position
					// sv update uses the pre-increment i (matches C's for-post)
					i := j + 1
					sv := int64(0)
					for sv >= 0 {
						sv += (xtab[i+1] << 1) - 1
						xtab[i] = xtab[i+1]
						i++
					}
					xtab[i] = 1
					// build rotated name
					rotBuf := make([]byte, d+1)
					for k2 := int64(0); k2 <= d; k2++ {
						if xtab[k2] != 0 {
							rotBuf[k2] = '.'
						} else {
							rotBuf[k2] = 'x'
						}
					}
					u := g.HashOut(string(rotBuf))
					if u != nil {
						if directed {
							g.NewArc(v, u, 1)
						} else {
							g.NewEdge(v, u, 1)
						}
					}
					// restore xtab
					for i--; i > j; i-- {
						xtab[i+1] = xtab[i]
					}
					xtab[i+1] = 1
				}
			}

			vi++

			// advance to next tree
			k = d - 1
			for {
				if k <= 0 {
					break binaryLoop
				}
				if xtab[k] != 0 {
					break
				}
				k--
			}
			k--
			for {
				if xtab[k] == 0 && ltab[k] > 1 {
					break
				}
				if k == 0 {
					break binaryLoop
				}
				k--
			}
			xtab[k]++
		}
	}
	if vi != g.N {
		return nil, graph.ErrImpossible
	}
	return g, nil
}

// =========================================================================
// Complement
// =========================================================================

// Complement creates the complement of g. If copy is true it makes a copy
// instead. self allows self-loops; directed selects arcs over edges.
func Complement(g *graph.Graph, copy, self, directed bool) (*graph.Graph, error) {
	if g == nil {
		return nil, graph.ErrMissingOperand
	}
	n := g.N
	newG := graph.NewGraph(n)
	if newG == nil {
		return nil, graph.ErrNoRoom
	}
	for i := int64(0); i < n; i++ {
		newG.Vertices[i].Name = g.Vertices[i].Name
	}
	graph.MakeCompoundID(newG, "complement(", g,
		fmt.Sprintf(",%d,%d,%d)", boolInt(copy), boolInt(self), boolInt(directed)))

	for vi := int64(0); vi < n; vi++ {
		v := &g.Vertices[vi]
		u := vMap(v, g, newG)
		// stamp tmp of every neighbour of v in old graph
		for a := v.Arcs; a != nil; a = a.Next {
			setTmp(vMap(a.Tip, g, newG), u)
		}
		if directed {
			for vvi := int64(0); vvi < n; vvi++ {
				vv := &newG.Vertices[vvi]
				if (getTmp(vv) == u && copy) || (getTmp(vv) != u && !copy) {
					if vv != u || self {
						newG.NewArc(u, vv, 1)
					}
				}
			}
		} else {
			start := int64(0)
			if self {
				start = vi
			} else {
				start = vi + 1
			}
			for vvi := start; vvi < n; vvi++ {
				vv := &newG.Vertices[vvi]
				if (getTmp(vv) == u && copy) || (getTmp(vv) != u && !copy) {
					newG.NewEdge(u, vv, 1)
				}
			}
		}
	}
	for i := int64(0); i < n; i++ {
		setTmp(&newG.Vertices[i], nil)
	}
	return newG, nil
}

// =========================================================================
// Gunion
// =========================================================================

// Gunion creates the union of graphs g and gg.
func Gunion(g, gg *graph.Graph, multi, directed bool) (*graph.Graph, error) {
	if g == nil || gg == nil {
		return nil, graph.ErrMissingOperand
	}
	n := g.N
	newG := graph.NewGraph(n)
	if newG == nil {
		return nil, graph.ErrNoRoom
	}
	for i := int64(0); i < n; i++ {
		newG.Vertices[i].Name = g.Vertices[i].Name
	}
	graph.MakeDoubleCompoundID(newG, "gunion(", g, ",", gg,
		fmt.Sprintf(",%d,%d)", boolInt(multi), boolInt(directed)))

	for vi := int64(0); vi < n; vi++ {
		v := &g.Vertices[vi]
		vv := vMap(v, g, newG)
		// corresponding vertex in gg (if within gg.N)
		var vvv *graph.Vertex
		if vi < gg.N {
			vvv = &gg.Vertices[vi]
		}

		insertUnion := func(src *graph.Vertex, a *graph.Arc) {
			var u *graph.Vertex
			if src == v { // arc from g
				u = vMap(a.Tip, g, newG)
			} else { // arc from gg
				if !inVertexSlice(a.Tip, gg.Vertices) {
					return
				}
				idx := vIdx(gg, a.Tip)
				if idx < 0 || idx >= n {
					return
				}
				u = &newG.Vertices[idx]
			}
			if u == nil || vIdx(newG, u) >= n {
				return
			}
			if directed {
				if multi || getTmp(u) != vv {
					newG.NewArc(vv, u, a.Len)
				} else {
					b := getTlen(u)
					if b != nil && a.Len < b.Len {
						b.Len = a.Len
					}
				}
				setTmp(u, vv)
				setTlen(u, vv.Arcs)
			} else {
				if vIdx(newG, u) < vIdx(newG, vv) {
					return
				}
				if multi || getTmp(u) != vv {
					newG.NewEdge(vv, u, a.Len)
				} else {
					b := getTlen(u)
					if b != nil && a.Len < b.Len {
						b.Len = a.Len
						b.Partner.Len = a.Len
					}
				}
				setTmp(u, vv)
				setTlen(u, vv.Arcs)
				if u == vv {
					// skip self-loop partner
				}
			}
		}

		for a := v.Arcs; a != nil; a = a.Next {
			insertUnion(v, a)
		}
		if vvv != nil {
			for a := vvv.Arcs; a != nil; a = a.Next {
				insertUnion(vvv, a)
			}
		}
	}
	for i := int64(0); i < n; i++ {
		setTmp(&newG.Vertices[i], nil)
		setTlen(&newG.Vertices[i], nil)
	}
	return newG, nil
}

// =========================================================================
// Intersection
// =========================================================================

// Intersection creates the intersection of graphs g and gg.
func Intersection(g, gg *graph.Graph, multi, directed bool) (*graph.Graph, error) {
	if g == nil || gg == nil {
		return nil, graph.ErrMissingOperand
	}
	n := g.N
	newG := graph.NewGraph(n)
	if newG == nil {
		return nil, graph.ErrNoRoom
	}
	for i := int64(0); i < n; i++ {
		newG.Vertices[i].Name = g.Vertices[i].Name
	}
	graph.MakeDoubleCompoundID(newG, "intersection(", g, ",", gg,
		fmt.Sprintf(",%d,%d)", boolInt(multi), boolInt(directed)))

	for vi := int64(0); vi < n; vi++ {
		v := &g.Vertices[vi]
		vv := vMap(v, g, newG)
		if vi >= gg.N {
			continue
		}
		vvv := &gg.Vertices[vi]

		// note all arcs from v in g
		for a := v.Arcs; a != nil; a = a.Next {
			u := vMap(a.Tip, g, newG)
			if getTmp(u) == vv {
				setMult(u, getMult(u)+1)
				if a.Len < getMinlen(u) {
					setMinlen(u, a.Len)
				}
			} else {
				setTmp(u, vv)
				setMult(u, 0)
				setMinlen(u, a.Len)
			}
			// skip self-loop partner in undirected
			if u == vv && !directed && a.Next == a.Partner {
				a = a.Next
			}
		}

		// for each arc in gg, emit intersection arc
		for a := vvv.Arcs; a != nil; a = a.Next {
			tipIdx := vIdx(gg, a.Tip)
			if tipIdx < 0 || tipIdx >= n {
				continue
			}
			u := &newG.Vertices[tipIdx]
			if getTmp(u) != vv {
				continue
			}
			l := getMinlen(u)
			if a.Len > l {
				l = a.Len
			}
			mult := getMult(u)
			if mult < 0 {
				// update minimum of multiple maxima
				b := getTlen(u)
				if b != nil && l < b.Len {
					b.Len = l
					if !directed {
						b.Partner.Len = l
					}
				}
			} else {
				// generate new arc/edge
				if directed {
					newG.NewArc(vv, u, l)
				} else {
					if vIdx(newG, vv) <= vIdx(newG, u) {
						newG.NewEdge(vv, u, l)
					}
					if vv == u && a.Next == a.Partner {
						a = a.Next
					}
				}
				if !multi {
					setTlen(u, vv.Arcs)
					setMult(u, -1)
				} else if mult == 0 {
					setTmp(u, nil)
				} else {
					setMult(u, mult-1)
				}
			}
		}
	}
	// clear temp fields
	for i := int64(0); i < n; i++ {
		setTmp(&newG.Vertices[i], nil)
		setTlen(&newG.Vertices[i], nil)
		setMult(&newG.Vertices[i], 0)
		setMinlen(&newG.Vertices[i], 0)
	}
	return newG, nil
}

// =========================================================================
// Lines
// =========================================================================

// Lines creates the line graph of g.
func Lines(g *graph.Graph, directed bool) (*graph.Graph, error) {
	if g == nil {
		return nil, graph.ErrMissingOperand
	}
	var m int64
	if directed {
		m = g.M
	} else {
		m = g.M / 2
	}
	newG := graph.NewGraph(m)
	if newG == nil {
		return nil, graph.ErrNoRoom
	}
	graph.MakeCompoundID(newG, "lines(", g, fmt.Sprintf(",%d)", boolInt(directed)))

	// build line-graph vertices: one per arc (directed) or edge (undirected)
	ui := int64(0)
	// panicRestore partially undoes the changes to g up to index ui, recycles
	// newG, and returns the invariant error. Captures ui, newG, directed.
	panicRestore := func() (*graph.Graph, error) {
		var vOrig *graph.Vertex
		for i := int64(0); i < ui; i++ {
			u := &newG.Vertices[i]
			uuV, _ := u.U.(*graph.Vertex)
			if uuV != vOrig {
				vOrig = uuV
				vOrig.Z = u.Z
				u.Z = nil
			}
			if !directed {
				uwA, _ := u.W.(*graph.Arc)
				if uwA != nil {
					uwA.Partner.Tip = vOrig
				}
			}
		}
		newG.Recycle()
		return nil, graph.ErrInvalidOperand
	}

	for vi := g.N - 1; vi >= 0; vi-- {
		v := &g.Vertices[vi]
		mapped := false
		for a := v.Arcs; a != nil; a = a.Next {
			vv := a.Tip
			if !directed {
				if vIdx(g, vv) < vi {
					continue
				}
				if vIdx(g, vv) >= g.N {
					return panicRestore()
				}
			}
			if ui >= m {
				return panicRestore()
			}
			u := &newG.Vertices[ui]
			u.U = v  // u.U.V = first vertex of the line
			u.V = vv // u.V.V = second vertex
			u.W = a  // u.W.A = arc from v to vv

			if !directed {
				if ui >= m || a.Partner.Tip != v {
					return panicRestore()
				}
				if v == vv && a.Next == a.Partner {
					a = a.Partner
				} else {
					a.Partner.Tip = u // temporarily overwrite partner tip
				}
			}

			// vertex name: "v--vv" (undirected) or "v->vv" (directed)
			sep := "--"
			if directed {
				sep = "->"
			}
			vName := v.Name
			vvName := vv.Name
			half := (bufSz - 3) / 2
			if len(vName) > half {
				vName = vName[:half]
			}
			if len(vvName) > bufSz/2-1 {
				vvName = vvName[:bufSz/2-1]
			}
			u.Name = vName + sep + vvName

			if !mapped {
				// save old v.Z in u.Z, set v.Z = u
				u.Z = v.Z
				v.Z = u
				mapped = true
			}
			ui++
		}
	}
	if ui != m {
		return panicRestore()
	}

	// insert arcs/edges of line graph
	if directed {
		for i := int64(0); i < m; i++ {
			u := &newG.Vertices[i]
			v, _ := u.V.(*graph.Vertex) // second endpoint in g
			if v == nil || v.Arcs == nil {
				continue
			}
			w := getVmap(v) // first line-graph vertex with first endpoint = v
			if w == nil {
				continue
			}
			for wi := vIdx(newG, w); wi < m; wi++ {
				w2 := &newG.Vertices[wi]
				w2v, _ := w2.U.(*graph.Vertex)
				if w2v != v {
					break
				}
				newG.NewArc(u, w2, 1)
			}
		}
	} else {
		for i := int64(0); i < m; i++ {
			u := &newG.Vertices[i]
			v, _ := u.U.(*graph.Vertex) // first endpoint
			// edges with earlier lines sharing the same first endpoint
			if w := getVmap(v); w != nil {
				for wi := vIdx(newG, w); wi < i; wi++ {
					newG.NewEdge(u, &newG.Vertices[wi], 1)
				}
			}
			// edges via the second endpoint
			v2, _ := u.V.(*graph.Vertex)
			mapped := false
			for a := v2.Arcs; a != nil; a = a.Next {
				vv := a.Tip
				if inVertexSlice(vv, newG.Vertices[:m]) {
					// vv is a line-graph vertex (temporarily written there)
					if vIdx(newG, vv) < i {
						newG.NewEdge(u, vv, 1)
					}
				} else if inVertexSlice(vv, g.Vertices[:g.N]) {
					if vIdx(g, vv) >= vIdx(g, v2) {
						mapped = true
					}
				}
			}
			if mapped && vIdx(g, v2) > vIdx(g, v) {
				if w := getVmap(v2); w != nil {
					for wi := vIdx(newG, w); wi < m; wi++ {
						w2 := &newG.Vertices[wi]
						wv, _ := w2.U.(*graph.Vertex)
						if wv != v2 {
							break
						}
						newG.NewEdge(u, w2, 1)
					}
				}
			}
		}
	}

	// restore g
	{
		var vOrig *graph.Vertex
		for i := int64(0); i < m; i++ {
			u := &newG.Vertices[i]
			uuV, _ := u.U.(*graph.Vertex)
			if uuV != vOrig {
				vOrig = uuV
				vOrig.Z = u.Z // restore original Z
				u.Z = nil
			}
			if !directed {
				uwA, _ := u.W.(*graph.Arc)
				if uwA != nil {
					uwA.Partner.Tip = vOrig
				}
			}
		}
	}
	return newG, nil
}

// =========================================================================
// Product
// =========================================================================

// Product creates the Cartesian (type=0), direct (type=1), or strong (type=2)
// product of g and gg.
func Product(g, gg *graph.Graph, typ int64, directed bool) (*graph.Graph, error) {
	if g == nil || gg == nil {
		return nil, graph.ErrMissingOperand
	}
	if float64(g.N)*float64(gg.N) > maxNNN {
		return nil, graph.ErrVeryBadSpecs
	}
	n := g.N * gg.N
	newG := graph.NewGraph(n)
	if newG == nil {
		return nil, graph.ErrNoRoom
	}

	// name vertices
	vi := int64(0)
	vv := int64(0)
	half := bufSz/2 - 1
	for vi < n {
		u := &newG.Vertices[vi]
		gName := g.Vertices[vv/gg.N].Name
		ggName := gg.Vertices[vv%gg.N].Name
		if len(gName) > half {
			gName = gName[:half]
		}
		if len(ggName) > (bufSz-1)/2 {
			ggName = ggName[:(bufSz-1)/2]
		}
		u.Name = gName + "," + ggName
		vi++
		vv++
	}
	typStr := (typ&2 - (typ & 1))
	graph.MakeDoubleCompoundID(newG, "product(", g, ",", gg,
		fmt.Sprintf(",%d,%d)", typStr, boolInt(directed)))

	// Cartesian product arcs
	if typ&1 == 0 {
		// arcs from gg dimension
		for ui := int64(0); ui < gg.N; ui++ {
			u := &gg.Vertices[ui]
			for a := u.Arcs; a != nil; a = a.Next {
				v2 := a.Tip
				v2i := vIdx(gg, v2)
				if !directed {
					if ui > v2i {
						continue
					}
					if ui == v2i && a.Next == a.Partner {
						a = a.Partner
					}
				}
				// connect all pairs (w, ui) with (w, v2i) for each w in g
				for wi := int64(0); wi < g.N; wi++ {
					src := &newG.Vertices[wi*gg.N+ui]
					dst := &newG.Vertices[wi*gg.N+int64(v2i)]
					if directed {
						newG.NewArc(src, dst, a.Len)
					} else {
						newG.NewEdge(src, dst, a.Len)
					}
				}
			}
		}
		// arcs from g dimension
		for ui := int64(0); ui < g.N; ui++ {
			u := &g.Vertices[ui]
			for a := u.Arcs; a != nil; a = a.Next {
				v2 := a.Tip
				v2i := vIdx(g, v2)
				if !directed {
					if ui > int64(v2i) {
						continue
					}
					if ui == int64(v2i) && a.Next == a.Partner {
						a = a.Partner
					}
				}
				// connect (ui, wi) with (v2i, wi) for each wi in gg
				for wi := int64(0); wi < gg.N; wi++ {
					src := &newG.Vertices[ui*gg.N+wi]
					dst := &newG.Vertices[int64(v2i)*gg.N+wi]
					if directed {
						newG.NewArc(src, dst, a.Len)
					} else {
						newG.NewEdge(src, dst, a.Len)
					}
				}
			}
		}
	}

	// Direct product arcs
	if typ != 0 {
		for ui := int64(0); ui < g.N; ui++ {
			uu := &g.Vertices[ui]
			for a := uu.Arcs; a != nil; a = a.Next {
				vvv := a.Tip
				vvi := vIdx(g, vvv)
				if !directed {
					if ui > int64(vvi) {
						continue
					}
					if ui == int64(vvi) && a.Next == a.Partner {
						a = a.Partner
					}
				}
				for wi := int64(0); wi < gg.N; wi++ {
					ww := &gg.Vertices[wi]
					for aa := ww.Arcs; aa != nil; aa = aa.Next {
						length := a.Len
						if aa.Len < length {
							length = aa.Len
						}
						wwv := aa.Tip
						wwi := vIdx(gg, wwv)
						src := &newG.Vertices[ui*gg.N+wi]
						dst := &newG.Vertices[int64(vvi)*gg.N+int64(wwi)]
						if directed {
							newG.NewArc(src, dst, length)
						} else {
							newG.NewEdge(src, dst, length)
						}
					}
				}
			}
		}
	}
	return newG, nil
}

// =========================================================================
// Induced
// =========================================================================

// Induced builds the graph induced from g according to the ind (z.I) field
// of each vertex.  Call SetInd / SetSubst on g's vertices before calling Induced.
func Induced(g *graph.Graph, description string, self, multi, directed bool) (*graph.Graph, error) {
	if g == nil {
		return nil, graph.ErrMissingOperand
	}

	// determine n (total new vertices) and nn (number of negative vertices)
	var n, negN int64
	for vi := int64(0); vi < g.N; vi++ {
		v := &g.Vertices[vi]
		k := getInd(v)
		if k > 0 {
			if n > IndGraph {
				return nil, graph.ErrVeryBadSpecs
			}
			if k >= IndGraph {
				sub := getSubst(v)
				if sub == nil {
					return nil, graph.ErrMissingOperand
				}
				n += sub.N
			} else {
				n += k
			}
		} else if k < 0 && -k > negN {
			negN = -k
		}
	}
	if n > IndGraph || negN > IndGraph {
		return nil, graph.ErrVeryBadSpecs
	}
	n += negN

	newG := graph.NewGraph(n)
	if newG == nil {
		return nil, graph.ErrNoRoom
	}

	desc := description
	if desc == "" {
		desc = ""
	}
	graph.MakeCompoundID(newG, "induced(", g,
		fmt.Sprintf(",%s,%d,%d,%d)", desc, boolInt(self), boolInt(multi), boolInt(directed)))

	// assign names and build g→newG map
	ui := int64(0)
	// negative vertices first
	for k := int64(1); k <= negN; k++ {
		u := &newG.Vertices[ui]
		setMult(u, -k)
		u.Name = fmt.Sprintf("%d", -k)
		ui++
	}
	for vi := int64(0); vi < g.N; vi++ {
		v := &g.Vertices[vi]
		k := getInd(v)
		if k < 0 {
			setVmap(v, &newG.Vertices[-k-1])
		} else if k > 0 {
			u := &newG.Vertices[ui]
			setMult(u, k)
			setVmap(v, u)
			if k < IndGraph {
				switch k {
				case 1:
					u.Name = v.Name
					ui++
				case 2:
					u.Name = v.Name
					ui++
					u2 := &newG.Vertices[ui]
					u2.Name = v.Name + "'"
					ui++
				default:
					for j := int64(0); j < k; j++ {
						newG.Vertices[ui].Name = fmt.Sprintf("%s:%d", v.Name, j)
						ui++
					}
				}
			} else {
				sub := getSubst(v)
				// copy sub's vertices as clones of v
				for j := int64(0); j < sub.N; j++ {
					newG.Vertices[ui].Name = fmt.Sprintf("%s:%s", v.Name, sub.Vertices[j].Name)
					// copy internal sub edges
					for a := sub.Vertices[j].Arcs; a != nil; a = a.Next {
						tipJ := vIdx(sub, a.Tip)
						uu := &newG.Vertices[ui]
						dst := &newG.Vertices[newG.Vertices[vi].U.(int64)+int64(tipJ)]
						_ = uu
						_ = dst
					}
					ui++
				}
				// insert internal sub arcs/edges
				subBase := vIdx(newG, getVmap(v))
				for j := int64(0); j < sub.N; j++ {
					uu := &newG.Vertices[int64(subBase)+j]
					for a := sub.Vertices[j].Arcs; a != nil; a = a.Next {
						tipJ := vIdx(sub, a.Tip)
						dst := &newG.Vertices[int64(subBase)+int64(tipJ)]
						if uu == dst && !self {
							continue
						}
						if !directed {
							if j > tipJ {
								continue
							}
							if j == tipJ && a.Next == a.Partner {
								a = a.Partner
							}
							if getTmp(dst) == uu && !multi {
								b := getTlen(dst)
								if b != nil && a.Len < b.Len {
									b.Len = a.Len
									b.Partner.Len = a.Len
								}
								continue
							}
							newG.NewEdge(uu, dst, a.Len)
						} else {
							if getTmp(dst) == uu && !multi {
								b := getTlen(dst)
								if b != nil && a.Len < b.Len {
									b.Len = a.Len
								}
								continue
							}
							newG.NewArc(uu, dst, a.Len)
						}
						setTmp(dst, uu)
						setTlen(dst, uu.Arcs)
					}
				}
			}
		}
	}

	// insert arcs/edges for non-substitution induced vertices
	for vi := int64(0); vi < g.N; vi++ {
		v := &g.Vertices[vi]
		u := getVmap(v)
		if u == nil {
			continue
		}
		k := getMult(u)
		if k < 0 {
			k = 1
		} else if k >= IndGraph {
			continue // handled above
		}
		for clone := int64(0); clone < k; clone++ {
			uu := &newG.Vertices[int64(vIdx(newG, u))+clone]
			if !multi {
				// note existing edges touching uu
				for a := uu.Arcs; a != nil; a = a.Next {
					setTmp(a.Tip, uu)
					uuIdx := vIdx(newG, uu)
					tipIdx := vIdx(newG, a.Tip)
					if directed || tipIdx > uuIdx || a.Next == a.Partner {
						setTlen(a.Tip, a)
					} else {
						setTlen(a.Tip, a.Partner)
					}
				}
			}
			for a := v.Arcs; a != nil; a = a.Next {
				vv := a.Tip
				uu2 := getVmap(vv)
				if uu2 == nil {
					continue
				}
				j := getMult(uu2)
				if j < 0 {
					j = 1
				} else if j >= IndGraph {
					j = getSubst(vv).N
				}
				if !directed {
					if vIdx(g, vv) < vi {
						continue
					}
					if vIdx(g, vv) == vi {
						if a.Next == a.Partner {
							a = a.Partner
						}
						j = k - clone
						uu2 = &newG.Vertices[int64(vIdx(newG, u))+clone]
					}
				}
				for ji := int64(0); ji < j; ji++ {
					dst := &newG.Vertices[int64(vIdx(newG, uu2))+ji]
					if uu == dst && !self {
						continue
					}
					if getTmp(dst) == uu && !multi {
						b := getTlen(dst)
						if b != nil && a.Len < b.Len {
							b.Len = a.Len
							if !directed {
								b.Partner.Len = a.Len
							}
						}
						continue
					}
					if directed {
						newG.NewArc(uu, dst, a.Len)
					} else {
						newG.NewEdge(uu, dst, a.Len)
					}
					setTmp(dst, uu)
					if directed || vIdx(newG, uu) <= vIdx(newG, dst) {
						setTlen(dst, uu.Arcs)
					} else {
						setTlen(dst, dst.Arcs)
					}
				}
			}
		}
	}

	// restore g and clear temp fields
	for vi := int64(0); vi < g.N; vi++ {
		v := &g.Vertices[vi]
		m := getVmap(v)
		if m != nil {
			setInd(v, getMult(m))
		}
	}
	for i := int64(0); i < n; i++ {
		newG.Vertices[i].U = nil
		newG.Vertices[i].V = nil
		newG.Vertices[i].Z = nil
	}
	return newG, nil
}

// =========================================================================
// Applications
// =========================================================================

// BiComplete creates a complete bipartite graph K_{n1,n2}.
func BiComplete(n1, n2 int64, directed bool) (*graph.Graph, error) {
	g, err := Board(2, 0, 0, 0, 1, 0, directed)
	if err != nil {
		return nil, err
	}
	setInd(&g.Vertices[0], n1)
	setInd(&g.Vertices[1], n2)
	result, err := Induced(g, "", false, false, directed)
	if err != nil {
		return nil, err
	}
	result.ID = fmt.Sprintf("bi_complete(%d,%d,%d)", n1, n2, boolInt(directed))
	result.MarkBipartite(n1)
	return result, nil
}

// Wheel creates a wheel with n rim vertices and n1 center points.
func Wheel(n, n1 int64, directed bool) (*graph.Graph, error) {
	g, err := Board(2, 0, 0, 0, 1, 0, directed)
	if err != nil {
		return nil, err
	}
	setInd(&g.Vertices[0], n1)
	setInd(&g.Vertices[1], IndGraph)
	rim, err := Board(n, 0, 0, 0, 1, 1, directed)
	if err != nil {
		return nil, err
	}
	g.Vertices[1].Y = rim
	result, err := Induced(g, "", false, false, directed)
	if err != nil {
		return nil, err
	}
	result.ID = fmt.Sprintf("wheel(%d,%d,%d)", n, n1, boolInt(directed))
	return result, nil
}
