// Package rand implements GB_RAND from Stanford GraphBase.
//
// RandomGraph generates pseudo-random graphs with specified vertex/arc counts
// and optional nonuniform distributions. RandomBigraph generates random
// bipartite graphs. RandomLengths assigns random lengths to arcs of an
// existing graph.
package gbrand

import (
	"fmt"

	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
)

// ---- Walker's alias method for nonuniform random generation ----

type magicEntry struct {
	prob int64
	inx  int64
}

type walkerNode struct {
	key  int64
	link *walkerNode
	j    int64
}

// walker builds a Walker alias table for the given distribution.
// dist must have length n and sum exactly to 0x40000000.
// nn must be the smallest power of 2 >= n.
func walker(n, nn int64, dist []int64) []magicEntry {
	table := make([]magicEntry, nn)
	nodes := make([]walkerNode, nn)

	t := int64(0x40000000) / nn // average probability per slot (exact)
	var hi, lo *walkerNode

	// Initialize hi and lo lists.
	// Add zero-prob entries for virtual slots (indices n..nn-1).
	p := 0
	nnMut := nn
	for nnMut > n {
		nnMut--
		nodes[p].key = 0
		nodes[p].link = lo
		nodes[p].j = nnMut
		lo = &nodes[p]
		p++
	}
	// Add real entries from dist[n-1] down to dist[0].
	nMut := n
	for i := n - 1; i >= 0; i-- {
		nMut--
		nodes[p].key = dist[i]
		nodes[p].j = nMut // = i
		if dist[i] > t {
			nodes[p].link = hi
			hi = &nodes[p]
		} else {
			nodes[p].link = lo
			lo = &nodes[p]
		}
		p++
	}

	// Match hi and lo elements.
	for hi != nil {
		ph := hi
		hi = hi.link
		q := lo
		lo = lo.link
		x := t*q.j + q.key - 1
		table[q.j].prob = x + x + 1
		table[q.j].inx = ph.j
		ph.key -= t - q.key
		if ph.key > t {
			ph.link = hi
			hi = ph
		} else {
			ph.link = lo
			lo = ph
		}
	}
	// Handle remaining lo elements with key == t.
	for lo != nil {
		q := lo
		lo = lo.link
		x := t*q.j + t - 1
		table[q.j].prob = x + x + 1
	}
	return table
}

// ---- helpers ----

func distCode(d []int64) string {
	if d != nil {
		return "dist"
	}
	return "0"
}

// boolInt renders a flag as 0 or 1, matching the C-style ID strings of SGB.
func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

// multiCode normalizes the ternary multi parameter to -1, 0, or 1.
func multiCode(multi int64) int64 {
	switch {
	case multi > 0:
		return 1
	case multi < 0:
		return -1
	}
	return 0
}

func randLen(rng *gbflip.RNG, minLen, maxLen int64) int64 {
	if minLen == maxLen {
		return minLen
	}
	return minLen + rng.Unif(maxLen-minLen+1)
}

// ---- RandomGraph ----

// RandomGraph constructs a pseudo-random graph with n vertices and m arcs or
// edges. Parameters:
//
//   - multi: 0 = no duplicate arcs; 1 = allow; -1 = allow but keep minimum length
//   - self: allow self-loops
//   - directed: directed graph (arcs) instead of undirected (edges)
//   - distFrom, distTo: nonuniform distributions (nil → uniform); each must sum to 2^30
//   - minLen, maxLen: arc length range (uniform random in [minLen, maxLen])
//   - seed: random seed
func RandomGraph(n, m, multi int64, self, directed bool, distFrom, distTo []int64, minLen, maxLen, seed int64) (*gbgraph.Graph, error) {
	if n == 0 {
		return nil, gbgraph.ErrBadSpecs
	}
	if minLen > maxLen {
		return nil, gbgraph.ErrVeryBadSpecs
	}
	if uint64(maxLen)-uint64(minLen) >= 0x80000000 {
		return nil, gbgraph.ErrBadSpecs
	}

	// Validate distribution parameters.
	if distFrom != nil {
		acc := int64(0)
		for _, p := range distFrom[:n] {
			if p < 0 {
				return nil, gbgraph.ErrInvalidOperand
			}
			if p > 0x40000000-acc {
				return nil, gbgraph.ErrInvalidOperand
			}
			acc += p
		}
		if acc != 0x40000000 {
			return nil, gbgraph.ErrInvalidOperand
		}
	}
	if distTo != nil {
		acc := int64(0)
		for _, p := range distTo[:n] {
			if p < 0 {
				return nil, gbgraph.ErrInvalidOperand
			}
			if p > 0x40000000-acc {
				return nil, gbgraph.ErrInvalidOperand
			}
			acc += p
		}
		if acc != 0x40000000 {
			return nil, gbgraph.ErrInvalidOperand
		}
	}

	rng := gbflip.New(seed)

	g := gbgraph.NewGraph(n)
	for k := int64(0); k < n; k++ {
		g.Vertices[k].Name = fmt.Sprintf("%d", k)
	}

	g.ID = fmt.Sprintf("random_graph(%d,%d,%d,%d,%d,%s,%s,%d,%d,%d)",
		n, m, multiCode(multi), boolInt(self), boolInt(directed),
		distCode(distFrom), distCode(distTo), minLen, maxLen, seed)

	// Build Walker alias tables if needed.
	nn := int64(1)
	kk := int64(31)
	if distFrom != nil || distTo != nil {
		for nn < n {
			nn += nn
			kk--
		}
	}
	var fromTable, toTable []magicEntry
	if distFrom != nil {
		fromTable = walker(n, nn, distFrom)
	}
	if distTo != nil {
		toTable = walker(n, nn, distTo)
	}

	randVertex := func(table []magicEntry, uniform int64) *gbgraph.Vertex {
		if table == nil {
			return &g.Vertices[rng.Unif(uniform)]
		}
		uu := rng.Next()
		k := uu >> kk
		m := &table[k]
		if uu <= m.prob {
			return &g.Vertices[k]
		}
		return &g.Vertices[m.inx]
	}

	for mm := m; mm > 0; {
		u := randVertex(fromTable, n)
		v := randVertex(toTable, n)
		if u == v && !self {
			continue
		}
		if multi <= 0 {
			found := false
			for a := u.Arcs; a != nil; a = a.Next {
				if a.Tip == v {
					found = true
					if multi == 0 {
						break // will retry
					}
					// multi < 0: keep minimum length
					newLen := randLen(rng, minLen, maxLen)
					if newLen < a.Len {
						a.Len = newLen
						if !directed {
							a.Partner.Len = newLen
						}
					}
					break
				}
			}
			if found {
				if multi < 0 {
					mm--
				}
				// multi==0: retry (don't decrement mm)
				continue
			}
		}
		if directed {
			g.NewArc(u, v, randLen(rng, minLen, maxLen))
		} else {
			g.NewEdge(u, v, randLen(rng, minLen, maxLen))
		}
		mm--
	}

	return g, nil
}

// ---- RandomBigraph ----

// RandomBigraph constructs a pseudo-random bipartite graph with n1 vertices
// in the first part and n2 in the second, having m undirected edges.
// Parameters multi, dist1, dist2, minLen, maxLen, seed have the same meaning
// as in RandomGraph. Edges run only between the two parts.
func RandomBigraph(n1, n2, m, multi int64, dist1, dist2 []int64, minLen, maxLen, seed int64) (*gbgraph.Graph, error) {
	n := n1 + n2
	if n1 == 0 || n2 == 0 {
		return nil, gbgraph.ErrBadSpecs
	}
	if minLen > maxLen {
		return nil, gbgraph.ErrVeryBadSpecs
	}
	if uint64(maxLen)-uint64(minLen) >= 0x80000000 {
		return nil, gbgraph.ErrBadSpecs
	}

	// Build distribution vectors of length n for RandomGraph.
	distFrom := make([]int64, n)
	distTo := make([]int64, n)
	if dist1 != nil {
		copy(distFrom[:n1], dist1)
	} else {
		for k := int64(0); k < n1; k++ {
			distFrom[k] = (0x40000000 + k) / n1
		}
	}
	if dist2 != nil {
		copy(distTo[n1:], dist2)
	} else {
		for k := int64(0); k < n2; k++ {
			distTo[n1+k] = (0x40000000 + k) / n2
		}
	}

	g, err := RandomGraph(n, m, multi, false, false, distFrom, distTo, minLen, maxLen, seed)
	if err != nil {
		return nil, err
	}
	g.ID = fmt.Sprintf("random_bigraph(%d,%d,%d,%d,%s,%s,%d,%d,%d)",
		n1, n2, m, multiCode(multi),
		distCode(dist1), distCode(dist2), minLen, maxLen, seed)
	g.MarkBipartite(n1)
	return g, nil
}

// ---- RandomLengths ----

// RandomLengths assigns new random lengths to all arcs (or paired edges, if
// directed is false) of graph g. If dist is nil, lengths are uniform in
// [minLen, maxLen]; otherwise dist is a probability distribution of length
// maxLen-minLen+1 summing to 2^30.
// Returns nil on success, or an error on failure.
func RandomLengths(g *gbgraph.Graph, directed bool, minLen, maxLen int64, dist []int64, seed int64) error {
	if g == nil {
		return gbgraph.ErrMissingOperand
	}
	rng := gbflip.New(seed)
	if minLen > maxLen {
		return gbgraph.ErrVeryBadSpecs
	}
	if uint64(maxLen)-uint64(minLen) >= 0x80000000 {
		return gbgraph.ErrBadSpecs
	}

	nn := int64(1)
	kk := int64(31)
	var distTable []magicEntry
	if dist != nil {
		n := maxLen - minLen + 1
		acc := int64(0)
		for _, p := range dist[:n] {
			if p < 0 {
				return gbgraph.ErrInvalidOperand
			}
			if p > 0x40000000-acc {
				return gbgraph.ErrInvalidOperand
			}
			acc += p
		}
		if acc != 0x40000000 {
			return gbgraph.ErrInvalidOperand
		}
		for nn < n {
			nn += nn
			kk--
		}
		distTable = walker(n, nn, dist)
	}

	suffix := fmt.Sprintf(",%d,%d,%d,%s,%d)",
		boolInt(directed), minLen, maxLen, distCode(dist), seed)
	gbgraph.MakeCompoundID(g, "random_lengths(", g, suffix)

	randLenFrom := func() int64 {
		if dist == nil {
			return randLen(rng, minLen, maxLen)
		}
		uu := rng.Next()
		k := uu >> kk
		m := &distTable[k]
		if uu <= m.prob {
			return minLen + k
		}
		return minLen + m.inx
	}

	for ui := int64(0); ui < g.N; ui++ {
		u := &g.Vertices[ui]
		for a := u.Arcs; a != nil; a = a.Next {
			v := a.Tip
			if !directed && ui > gbgraph.VertexIndex(g, v) {
				a.Len = a.Partner.Len
			} else {
				newLen := randLenFrom()
				a.Len = newLen
				if !directed && u == v && a.Next == a.Partner {
					a.Next.Len = newLen
					a = a.Next // advance past companion; for-loop will advance again
				}
			}
		}
	}
	return nil
}
