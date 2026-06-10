// Package words implements GB_WORDS from Stanford GraphBase.
// Words constructs a graph whose vertices are five-letter English words and
// whose edges connect words that differ in exactly one letter position.
// It also returns an Index whose FindWord method searches those words.
package words

import (
	"fmt"

	"github.com/sjnam/go-sgb/flip"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/graph"
	"github.com/sjnam/go-sgb/sort"
)

const hashPrime = 6997

var (
	maxC       = [7]int64{15194, 3560, 4467, 460, 6976, 756, 362}
	defaultWtV = [9]int64{100, 10, 4, 2, 2, 1, 1, 1, 1}
)

// Index holds five hash tables (one per letter position) for the vertices of
// a graph built by Words. Its FindWord method locates words and their
// one-letter-different neighbours.
type Index struct {
	htab [5][hashPrime]*graph.Vertex
}

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
//
// The returned Index locates words of the new graph; see Index.FindWord.
func Words(n int64, wtVec []int64, wtThreshold, seed int64) (*graph.Graph, *Index, error) {
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
			return nil, nil, graph.ErrVeryBadSpecs
		}
		// Integer check: confirm no overflow in weight computation.
		acc := max(iabs(wt[1]), iabs(wt[0]))
		for j := range 7 {
			acc += maxC[j] * iabs(wt[j+2])
		}
		if acc >= 0x40000000 {
			return nil, nil, graph.ErrBadSpecs
		}
	}

	r, err := gbio.Open("words.dat")
	if err != nil {
		return nil, nil, graph.ErrEarlyDataFault
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
			return nil, nil, graph.ErrSyntaxError
		}

		for p := 0; ; p++ {
			if p >= 7 {
				r.RawClose()
				return nil, nil, graph.ErrSyntaxError
			}
			c := int64(r.GbNumber(10))
			if c > maxC[p] {
				r.RawClose()
				return nil, nil, graph.ErrSyntaxError
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
		return nil, nil, graph.ErrLateDataFault
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

	ix := &Index{}
	if n > 0 && stackPtr != nil {
		sorted := sort.LinksSort(stackPtr, rng)
		remain := n
		curIdx := int64(0)
		for j := 127; j >= 0 && remain > 0; j-- {
			for p := sorted[j]; p != nil && remain > 0; p = p.Link {
				ix.insertWord(g, &g.Vertices[curIdx], p.Val.wd, p.Key-0x40000000)
				curIdx++
				remain--
			}
		}
	}

	return g, ix, nil
}

// wordHash packs the five letters of word into a 25-bit integer.
func wordHash(word [5]byte) int64 {
	return ((((int64(word[0])<<5+int64(word[1]))<<5+int64(word[2]))<<5+int64(word[3]))<<5 +
		int64(word[4]))
}

// matchExcept reports whether name agrees with word in every letter position
// other than t.
func matchExcept(name string, word [5]byte, t int) bool {
	for j := 0; j < 5; j++ {
		if j != t && name[j] != word[j] {
			return false
		}
	}
	return true
}

// insertWord adds curVertex to the graph with the given word and weight,
// probing all five hash tables to discover adjacent words and add edges.
// Table t hashes the word with position t ignored, so its probe chain holds
// every word that could differ from this one only at position t.
func (ix *Index) insertWord(g *graph.Graph, curVertex *graph.Vertex, word [5]byte, weight int64) {
	curVertex.Name = string(word[:])
	curVertex.U = weight

	rawHash := wordHash(word)
	for t := 0; t < 5; t++ {
		h := int((rawHash - int64(word[t])<<(20-5*t)) % hashPrime)
		for ix.htab[t][h] != nil {
			if matchExcept(ix.htab[t][h].Name, word, t) {
				g.NewEdge(curVertex, ix.htab[t][h], 1)
				curVertex.Arcs.A = int64(t)
				curVertex.Arcs.Partner.A = int64(t)
			}
			if h == 0 {
				h = hashPrime - 1
			} else {
				h--
			}
		}
		ix.htab[t][h] = curVertex
	}
}

// FindWord searches the index for an exact five-letter match of q.
// If found, returns the vertex; otherwise returns nil after calling f
// (if non-nil) for every vertex adjacent to q (words differing from q in
// exactly one position).
func (ix *Index) FindWord(q string, f func(*graph.Vertex)) *graph.Vertex {
	if len(q) < 5 {
		return nil
	}
	var word [5]byte
	copy(word[:], q)
	rawHash := wordHash(word)

	// Probe table 0 for an exact match (check all 5 positions).
	for h := int((rawHash - int64(word[0])<<20) % hashPrime); ix.htab[0][h] != nil; {
		if ix.htab[0][h].Name == string(word[:]) {
			return ix.htab[0][h]
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

	// Table t: match all positions except t → words differing at position t.
	for t := 0; t < 5; t++ {
		for h := int((rawHash - int64(word[t])<<(20-5*t)) % hashPrime); ix.htab[t][h] != nil; {
			if matchExcept(ix.htab[t][h].Name, word, t) {
				f(ix.htab[t][h])
			}
			if h == 0 {
				h = hashPrime - 1
			} else {
				h--
			}
		}
	}

	return nil
}
