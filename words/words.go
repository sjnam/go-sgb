// Package words implements GB_WORDS from Stanford GraphBase.
// Words constructs a graph whose vertices are five-letter English words and
// whose edges connect words that differ in exactly one letter position.
// FindWord searches the hash tables left by the most recent Words call.
package words

import (
	"fmt"

	"github.com/sjnam/go-sgb/flip"
	"github.com/sjnam/go-sgb/graph"
	"github.com/sjnam/go-sgb/io"
	"github.com/sjnam/go-sgb/sort"
)

const hashPrime = 6997

var (
	maxC       = [7]int64{15194, 3560, 4467, 460, 6976, 756, 362}
	defaultWtV = [9]int64{100, 10, 4, 2, 2, 1, 1, 1, 1}
)

// htab holds five hash tables (one per letter position) from the last Words call.
var htab [5][hashPrime]*graph.Vertex

// Weight returns the weighted frequency stored in vertex v's U field.
func Weight(v *graph.Vertex) int64 { i, _ := v.U.(int64); return i }

// Loc returns the letter-position index (0–4) stored in arc a's A field.
func Loc(a *graph.Arc) int64 { i, _ := a.A.(int64); return i }

func flabs(x int64) float64 {
	if x >= 0 {
		return float64(x)
	}
	return float64(-x)
}

func iabs(x int64) int64 {
	if x >= 0 {
		return x
	}
	return -x
}

type (
	wordData struct{ wd [5]byte }
	wordNode = sort.Node[wordData]
)

// Words constructs a five-letter word graph.
//
//   - n: maximum number of vertices (0 means all qualifying words).
//   - wtVec: nine-element weight vector [a, b, w1…w7]; nil uses defaults {100,10,4,2,2,1,1,1,1}.
//   - wtThreshold: minimum weight required to qualify.
//   - seed: random seed for breaking ties among equal-weight words.
//
// Vertices are sorted by decreasing weight; ties are broken via seed.
// Two vertices share an edge when their words differ in exactly one letter.
// Utility types: "IZZZZZIZZZZZZZ" — U=weight(I), Arc.A=loc(I).
func Words(n int64, wtVec []int64, wtThreshold, seed int64) (*graph.Graph, error) {
	rng := flip.New(seed)

	var wt [9]int64
	usingDefault := wtVec == nil
	if usingDefault {
		wt = defaultWtV
	} else {
		copy(wt[:], wtVec)
		// Float check: reject clearly invalid vectors.
		flacc := flabs(wt[0])
		if flabs(wt[1]) > flacc {
			flacc = flabs(wt[1])
		}
		for j := range 7 {
			flacc += float64(maxC[j]) * flabs(wt[j+2])
		}
		if flacc >= float64(0x60000000) {
			return nil, graph.ErrVeryBadSpecs
		}
		// Integer check: confirm no overflow in weight computation.
		acc := max(iabs(wt[1]), iabs(wt[0]))
		for j := range 7 {
			acc += maxC[j] * iabs(wt[j+2])
		}
		if acc >= 0x40000000 {
			return nil, graph.ErrBadSpecs
		}
	}

	r, err := io.Open("words.dat")
	if err != nil {
		return nil, graph.ErrEarlyDataFault
	}

	var nn int64
	var stackPtr *wordNode

	for {
		var word [5]byte
		for j := range 5 {
			word[j] = r.GbChar()
		}

		var wordWt int64
		switch r.GbChar() {
		case '*':
			wordWt = wt[0]
		case '+':
			wordWt = wt[1]
		case ' ', '\n':
			wordWt = 0
		default:
			r.RawClose()
			return nil, graph.ErrSyntaxError
		}

		for p := 0; ; p++ {
			if p >= 7 {
				r.RawClose()
				return nil, graph.ErrSyntaxError
			}
			c := int64(r.GbNumber(10))
			if c > maxC[p] {
				r.RawClose()
				return nil, graph.ErrSyntaxError
			}
			wordWt += c * wt[p+2]
			if r.GbChar() != ',' {
				break
			}
		}

		if wordWt >= wtThreshold {
			nd := &wordNode{Key: wordWt + 0x40000000, Link: stackPtr}
			nd.Val.wd = word
			stackPtr = nd
			nn++
		}

		r.GbNewline()
		if r.GbEof() {
			break
		}
	}

	if err := r.Close(); err != nil {
		return nil, graph.ErrLateDataFault
	}

	if n == 0 || nn < n {
		n = nn
	}

	g := graph.NewGraph(n)
	g.UtilTypes = "IZZZZZIZZZZZZZ"
	if usingDefault {
		g.ID = fmt.Sprintf("words(%d,0,%d,%d)", n, wtThreshold, seed)
	} else {
		g.ID = fmt.Sprintf("words(%d,{%d,%d,%d,%d,%d,%d,%d,%d,%d},%d,%d)",
			n,
			wt[0], wt[1], wt[2], wt[3], wt[4], wt[5], wt[6], wt[7], wt[8],
			wtThreshold, seed)
	}

	// Clear hash tables from any previous call.
	for k := range 5 {
		for j := 0; j < hashPrime; j++ {
			htab[k][j] = nil
		}
	}

	if n > 0 && stackPtr != nil {
		sorted := sort.LinksSort(stackPtr, rng)
		remain := n
		curIdx := int64(0)
		for j := 127; j >= 0 && remain > 0; j-- {
			for p := sorted[j]; p != nil && remain > 0; p = p.Link {
				insertWord(g, &g.Vertices[curIdx], p.Val.wd, p.Key-0x40000000)
				curIdx++
				remain--
			}
		}
	}

	return g, nil
}

// insertWord adds curVertex to the graph with the given word and weight,
// probing all five hash tables to discover adjacent words and add edges.
func insertWord(g *graph.Graph, curVertex *graph.Vertex, word [5]byte, weight int64) {
	curVertex.Name = string(word[:])
	curVertex.U = weight

	rawHash := ((((int64(word[0])<<5+int64(word[1]))<<5+int64(word[2]))<<5+int64(word[3]))<<5 + int64(word[4]))

	// Table 0: hash ignores position 0; match positions 1,2,3,4.
	{
		h := int((rawHash - int64(word[0])<<20) % hashPrime)
		for htab[0][h] != nil {
			r := htab[0][h].Name
			if r[1] == word[1] && r[2] == word[2] && r[3] == word[3] && r[4] == word[4] {
				g.NewEdge(curVertex, htab[0][h], 1)
				curVertex.Arcs.A = int64(0)
				curVertex.Arcs.Partner.A = int64(0)
			}
			if h == 0 {
				h = hashPrime - 1
			} else {
				h--
			}
		}
		htab[0][h] = curVertex
	}

	// Table 1: hash ignores position 1; match positions 0,2,3,4.
	{
		h := int((rawHash - int64(word[1])<<15) % hashPrime)
		for htab[1][h] != nil {
			r := htab[1][h].Name
			if r[0] == word[0] && r[2] == word[2] && r[3] == word[3] && r[4] == word[4] {
				g.NewEdge(curVertex, htab[1][h], 1)
				curVertex.Arcs.A = int64(1)
				curVertex.Arcs.Partner.A = int64(1)
			}
			if h == 0 {
				h = hashPrime - 1
			} else {
				h--
			}
		}
		htab[1][h] = curVertex
	}

	// Table 2: hash ignores position 2; match positions 0,1,3,4.
	{
		h := int((rawHash - int64(word[2])<<10) % hashPrime)
		for htab[2][h] != nil {
			r := htab[2][h].Name
			if r[0] == word[0] && r[1] == word[1] && r[3] == word[3] && r[4] == word[4] {
				g.NewEdge(curVertex, htab[2][h], 1)
				curVertex.Arcs.A = int64(2)
				curVertex.Arcs.Partner.A = int64(2)
			}
			if h == 0 {
				h = hashPrime - 1
			} else {
				h--
			}
		}
		htab[2][h] = curVertex
	}

	// Table 3: hash ignores position 3; match positions 0,1,2,4.
	{
		h := int((rawHash - int64(word[3])<<5) % hashPrime)
		for htab[3][h] != nil {
			r := htab[3][h].Name
			if r[0] == word[0] && r[1] == word[1] && r[2] == word[2] && r[4] == word[4] {
				g.NewEdge(curVertex, htab[3][h], 1)
				curVertex.Arcs.A = int64(3)
				curVertex.Arcs.Partner.A = int64(3)
			}
			if h == 0 {
				h = hashPrime - 1
			} else {
				h--
			}
		}
		htab[3][h] = curVertex
	}

	// Table 4: hash ignores position 4; match positions 0,1,2,3.
	{
		h := int((rawHash - int64(word[4])) % hashPrime)
		for htab[4][h] != nil {
			r := htab[4][h].Name
			if r[0] == word[0] && r[1] == word[1] && r[2] == word[2] && r[3] == word[3] {
				g.NewEdge(curVertex, htab[4][h], 1)
				curVertex.Arcs.A = int64(4)
				curVertex.Arcs.Partner.A = int64(4)
			}
			if h == 0 {
				h = hashPrime - 1
			} else {
				h--
			}
		}
		htab[4][h] = curVertex
	}
}

// FindWord searches the hash tables from the most recent Words call for an
// exact five-letter match of q.  If found, returns the vertex; otherwise
// returns nil after calling f (if non-nil) for every vertex adjacent to q
// (words differing from q in exactly one position).
func FindWord(q string, f func(*graph.Vertex)) *graph.Vertex {
	if len(q) < 5 {
		return nil
	}

	rawHash := ((((int64(q[0])<<5+int64(q[1]))<<5+int64(q[2]))<<5+int64(q[3]))<<5 + int64(q[4]))

	// Probe table 0 for an exact match (check all 5 positions).
	for h := int((rawHash - int64(q[0])<<20) % hashPrime); htab[0][h] != nil; {
		r := htab[0][h].Name
		if r[0] == q[0] && r[1] == q[1] && r[2] == q[2] && r[3] == q[3] && r[4] == q[4] {
			return htab[0][h]
		}
		if h == 0 {
			h = hashPrime - 1
		} else {
			h--
		}
	}

	if f == nil {
		return nil
	}

	// Table 0: match positions 1,2,3,4 → differ at position 0.
	for h := int((rawHash - int64(q[0])<<20) % hashPrime); htab[0][h] != nil; {
		r := htab[0][h].Name
		if r[1] == q[1] && r[2] == q[2] && r[3] == q[3] && r[4] == q[4] {
			f(htab[0][h])
		}
		if h == 0 {
			h = hashPrime - 1
		} else {
			h--
		}
	}

	// Table 1: match positions 0,2,3,4 → differ at position 1.
	for h := int((rawHash - int64(q[1])<<15) % hashPrime); htab[1][h] != nil; {
		r := htab[1][h].Name
		if r[0] == q[0] && r[2] == q[2] && r[3] == q[3] && r[4] == q[4] {
			f(htab[1][h])
		}
		if h == 0 {
			h = hashPrime - 1
		} else {
			h--
		}
	}

	// Table 2: match positions 0,1,3,4 → differ at position 2.
	for h := int((rawHash - int64(q[2])<<10) % hashPrime); htab[2][h] != nil; {
		r := htab[2][h].Name
		if r[0] == q[0] && r[1] == q[1] && r[3] == q[3] && r[4] == q[4] {
			f(htab[2][h])
		}
		if h == 0 {
			h = hashPrime - 1
		} else {
			h--
		}
	}

	// Table 3: match positions 0,1,2,4 → differ at position 3.
	for h := int((rawHash - int64(q[3])<<5) % hashPrime); htab[3][h] != nil; {
		r := htab[3][h].Name
		if r[0] == q[0] && r[1] == q[1] && r[2] == q[2] && r[4] == q[4] {
			f(htab[3][h])
		}
		if h == 0 {
			h = hashPrime - 1
		} else {
			h--
		}
	}

	// Table 4: match positions 0,1,2,3 → differ at position 4.
	for h := int((rawHash - int64(q[4])) % hashPrime); htab[4][h] != nil; {
		r := htab[4][h].Name
		if r[0] == q[0] && r[1] == q[1] && r[2] == q[2] && r[3] == q[3] {
			f(htab[4][h])
		}
		if h == 0 {
			h = hashPrime - 1
		} else {
			h--
		}
	}

	return nil
}
