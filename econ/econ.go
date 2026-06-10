// Package econ implements GB_ECON from Stanford GraphBase.
//
// Econ constructs a directed graph based on the 1985 U.S. input/output table
// published in Survey of Current Business (1990). Each vertex represents a
// sector of the economy; each arc represents commodity flow between sectors.
//
// Vertex utility fields (UtilTypes "ZZZZIAIZZZZZZZ"):
//
//	Y = sector_total (int64: total commodity output = total commodity input)
//	Z = SIC_codes    (*Arc: linked list; each node's Len holds one SIC code)
//
// Arc utility fields:
//
//	A = flow (int64: millions of dollars from source sector to dest sector)
package econ

import (
	"fmt"

	"github.com/sjnam/go-sgb/flip"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/graph"
)

const (
	MaxN   = 81 // maximum number of vertices
	NormN  = 79 // number of normal (non-special) SIC sectors
	AdjSec = 80 // SIC code for the "Adjustments" sector
)

// Vertex utility-field accessors.
func SectorTotal(v *graph.Vertex) int64   { i, _ := v.Y.(int64); return i }
func SICCodes(v *graph.Vertex) *graph.Arc { a, _ := v.Z.(*graph.Arc); return a }

// Arc utility-field accessor.
func Flow(a *graph.Arc) int64 { i, _ := a.A.(int64); return i }

// econNode is an internal record for one tree node (micro- or macro-sector).
type econNode struct {
	idx     int
	rchild  *econNode
	title   string
	table   [MaxN + 2]int64 // [0]=leaf count (random); [1..80]=flows; [81]=row sum
	total   int64
	thresh  int64
	SIC     int64
	tag     int64
	link    *econNode
	SICList *graph.Arc
}

// econState holds all per-call working storage, making Econ reentrant.
type econState struct {
	nodeBlock [2*MaxN - 3]econNode    // 159 nodes: [0..156]=tree, [157]=Adj, [158]=Users
	nodeIndex [MaxN + 2]*econNode     // nodeIndex[1..81]: current representative node
	vertIndex [MaxN + 2]*graph.Vertex // vertIndex[1..81]: vertex assigned to SIC code
}

func (s *econState) nAt(i int) *econNode { return &s.nodeBlock[i] }

// Econ constructs an input/output graph of the U.S. economy.
//
//   - n: number of vertices (0 → MaxN-omit).
//   - omit: 0=include Users+Adjustments, 1=omit Users, 2=omit both.
//   - threshold: minimum per-65536 fraction for arc inclusion (0 → all nonzero).
//   - seed: 0=balanced largest-first, >0=random subtree.
//
// UtilTypes = "ZZZZIAIZZZZZZZ".
func Econ(n, omit, threshold, seed int64) (*graph.Graph, error) {
	rng := flip.New(seed)

	if omit > 2 {
		omit = 2
	}
	if n == 0 || n > MaxN-omit {
		n = MaxN - omit
	} else if n+omit < 3 {
		omit = 3 - n
	}
	if threshold > 65536 {
		threshold = 65536
	}

	g := graph.NewGraph(n)
	g.ID = fmt.Sprintf("econ(%d,%d,%d,%d)", n, omit, threshold, seed)
	g.UtilTypes = "ZZZZIAIZZZZZZZ"

	s := new(econState)
	for i := range s.nodeBlock {
		s.nodeBlock[i].idx = i
	}

	r, err := s.readEconDat()
	if err != nil {
		return nil, err
	}

	// Determine the n sectors to use (l = number of leaves in desired subtree).
	l := n + omit - 2
	if l == NormN {
		s.chooseAllSectors()
	} else if seed != 0 {
		s.growRandomSubtree(l, rng)
	} else {
		s.growBalancedSubtree(l)
	}

	s.putArcs(g, n, omit, threshold)

	if err := r.Close(); err != nil {
		return nil, graph.ErrLateDataFault
	}
	return g, nil
}

// readEconDat opens econ.dat, populates nodeBlock/nodeIndex with the tree
// structure and output-coefficient matrix, and returns the open reader.
// The caller is responsible for closing the reader.
func (s *econState) readEconDat() (*gbio.Reader, error) {
	r, err := gbio.Open("econ.dat")
	if err != nil {
		return nil, graph.ErrEarlyDataFault
	}

	// Part 1: read 2*NormN-1 = 157 tree nodes in preorder.
	var stk [NormN + NormN]*econNode
	stkPtr := 0
	for i := 0; i < 2*NormN-1; i++ {
		p := s.nAt(i)
		p.title = r.GbString(':')
		if len(p.title) > 43 {
			r.RawClose()
			return nil, graph.ErrSyntaxError
		}
		if r.GbChar() != ':' {
			r.RawClose()
			return nil, graph.ErrSyntaxError
		}
		c := int64(r.GbNumber(10))
		p.SIC = c
		if c == 0 {
			// Internal node: push onto stack; left child is nAt(i+1).
			stk[stkPtr] = p
			stkPtr++
		} else {
			// Leaf: record in nodeIndex; the NEXT node is the right child of the
			// most recently pushed ancestor.
			s.nodeIndex[c] = p
			if stkPtr > 0 {
				stkPtr--
				stk[stkPtr].rchild = s.nAt(i + 1)
			}
		}
		if r.GbChar() != '\n' {
			r.RawClose()
			return nil, graph.ErrSyntaxError
		}
		r.GbNewline()
	}
	if stkPtr != 0 {
		r.RawClose()
		return nil, graph.ErrSyntaxError
	}
	for k := int64(NormN); k > 0; k-- {
		if s.nodeIndex[k] == nil {
			r.RawClose()
			return nil, graph.ErrSyntaxError
		}
	}

	// Manufacture the two special sector nodes.
	adj := s.nAt(2*NormN - 1) // nodeBlock[157]
	adj.title = "Adjustments"
	adj.SIC = AdjSec
	s.nodeIndex[AdjSec] = adj

	users := s.nAt(2 * NormN) // nodeBlock[158]
	users.title = "Users"
	s.nodeIndex[MaxN] = users

	// Part 2: read the 81×80 output coefficient matrix.
	for k := int64(1); k <= MaxN; k++ {
		if r.GbChar() != '\n' {
			r.RawClose()
			return nil, graph.ErrSyntaxError
		}
		r.GbNewline()
		p := s.nodeIndex[k]
		ss := int64(0)
		for j := int64(1); j < MaxN; j++ {
			x := int64(r.GbNumber(10))
			p.table[j] = x
			ss += x
			s.nodeIndex[j].total += x
			if j%10 == 0 {
				if r.GbChar() != '\n' {
					r.RawClose()
					return nil, graph.ErrSyntaxError
				}
				r.GbNewline()
			} else {
				if r.GbChar() != ',' {
					r.RawClose()
					return nil, graph.ErrSyntaxError
				}
			}
		}
		p.table[MaxN] = ss // row sum (will be converted to final demand later)
	}
	return r, nil
}

// chooseAllSectors tags every one of the NormN leaf nodes.
func (s *econState) chooseAllSectors() {
	for k := int64(NormN); k > 0; k-- {
		s.nodeIndex[k].tag = 1
	}
}

// growBalancedSubtree tags l nodes by repeatedly splitting the sector with the
// largest total until l active sectors exist.
func (s *econState) growBalancedSubtree(l int64) {
	special := s.nodeIndex[MaxN] // Users node serves as list sentinel (total=0)

	// Bottom-up: compute total for every internal node.
	adjIdx := s.nodeIndex[AdjSec].idx
	for i := adjIdx - 1; i >= 0; i-- {
		p := s.nAt(i)
		if p.rchild != nil {
			p.total = s.nAt(i+1).total + p.rchild.total
		}
	}

	// Start list with just the root.
	special.link = s.nAt(0)
	s.nAt(0).link = special
	count := int64(1)

	for count < l {
		p := special.link     // node with greatest total
		special.link = p.link // remove from list
		if p.rchild == nil {
			p.tag = 1 // leaf: just tag it, don't increment count
		} else {
			pl := s.nAt(p.idx + 1)
			pr := p.rchild
			// Insert pl into sorted position.
			q := special
			for q.link.total > pl.total {
				q = q.link
			}
			pl.link = q.link
			q.link = pl
			// Insert pr into sorted position.
			q = special
			for q.link.total > pr.total {
				q = q.link
			}
			pr.link = q.link
			q.link = pr
			count++
		}
	}
	// Tag everything still on the list.
	for p := special.link; p != special; p = p.link {
		p.tag = 1
	}
}

// growRandomSubtree tags l nodes using a stochastic top-down subdivision.
func (s *econState) growRandomSubtree(l int64, rng *flip.RNG) {
	s.nAt(0).tag = l

	adjIdx := s.nodeIndex[AdjSec].idx

	// Bottom-up (except root): compute T(l) values for internal nodes.
	for i := adjIdx - 1; i > 0; i-- {
		p := s.nAt(i)
		if p.rchild != nil {
			s.computeTValues(p)
		}
	}

	// Top-down: distribute tags.
	for i := 0; i < adjIdx; i++ {
		p := s.nAt(i)
		if p.tag > 1 {
			li := p.tag
			pl := s.nAt(i + 1)
			pr := p.rchild
			if pl.rchild == nil {
				pl.tag = 1
				pr.tag = li - 1
			} else if pr.rchild == nil {
				pl.tag = li - 1
				pr.tag = 1
			} else {
				s.stochasticallyDivide(p, pl, pr, li, rng)
			}
		}
	}
}

// computeTValues fills p.table[0..table[0]] with the T(l) counts for the
// subtree rooted at p (used for the random subdivision).
func (s *econState) computeTValues(p *econNode) {
	pl := s.nAt(p.idx + 1)
	pr := p.rchild
	p.table[1] = 1
	p.table[2] = 1
	if pl.rchild == nil {
		if pr.rchild == nil {
			p.table[0] = 2
		} else {
			for k := int64(2); k <= pr.table[0]; k++ {
				p.table[1+k] = pr.table[k]
			}
			p.table[0] = pr.table[0] + 1
		}
	} else if pr.rchild == nil {
		for k := int64(2); k <= pl.table[0]; k++ {
			p.table[1+k] = pl.table[k]
		}
		p.table[0] = pl.table[0] + 1
	} else {
		p.table[2] = 0
		for j := pl.table[0]; j > 0; j-- {
			t := pl.table[j]
			for k := pr.table[0]; k > 0; k-- {
				p.table[j+k] += t * pr.table[k]
			}
		}
		p.table[0] = pl.table[0] + pr.table[0]
	}
}

// stochasticallyDivide picks how many leaves go to pl vs pr using rng.Unif.
func (s *econState) stochasticallyDivide(p, pl, pr *econNode, l int64, rng *flip.RNG) {
	klo := l - pr.table[0]
	if klo < 1 {
		klo = 1
	}

	var ss int64
	scaled := false

	if p == s.nAt(0) { // root node: may need scaling to avoid overflow
		ss = 0
		if l > 29 && l < 67 {
			scaled = true
			for k := klo; k <= pl.table[0] && k < l; k++ {
				ss += ((pl.table[k] + 0x3ff) >> 10) * pr.table[l-k]
			}
		} else {
			for k := klo; k <= pl.table[0] && k < l; k++ {
				ss += pl.table[k] * pr.table[l-k]
			}
		}
	} else {
		ss = p.table[l]
	}

	rr := rng.Unif(ss)
	k := klo
	acc := int64(0)
	if scaled {
		for acc <= rr {
			acc += ((pl.table[k] + 0x3ff) >> 10) * pr.table[l-k]
			k++
		}
	} else {
		for acc <= rr {
			acc += pl.table[k] * pr.table[l-k]
			k++
		}
	}
	pl.tag = k - 1
	pr.tag = l - k + 1
}

// putArcs performs the bottom-up pruning, assigns vertices, and inserts arcs.
func (s *econState) putArcs(g *graph.Graph, n, omit, threshold int64) {
	adjIdx := s.nodeIndex[AdjSec].idx // = 2*NormN-1 = 157

	// Bottom-up: form SIC lists and merge non-tagged sectors.
	for i := adjIdx; i >= 0; i-- {
		p := s.nAt(i)
		if p.SIC != 0 {
			// Original leaf: allocate a one-element SIC list.
			a := &graph.Arc{Len: p.SIC}
			p.SICList = a
		} else {
			// Internal node: check whether to merge children into p.
			pl := s.nAt(i + 1)
			pr := p.rchild
			if p.tag == 0 {
				p.tag = pl.tag + pr.tag
			}
			if p.tag <= 1 {
				s.mergePR(p, pl, pr)
			}
		}
	}

	// Handle special sectors based on omit parameter.
	switch omit {
	case 2:
		s.nodeIndex[AdjSec] = nil
		s.nodeIndex[MaxN] = nil
	case 1:
		s.nodeIndex[MaxN] = nil
	default:
		// Convert table[MAX_N] from row sum to final demand (flow to Users).
		for k := int64(AdjSec); k > 0; k-- {
			if p := s.nodeIndex[k]; p != nil {
				p.table[MaxN] = p.total - p.table[MaxN]
			}
		}
		// For Users: total = GNP (sum of value added = sum of row sums).
		users := s.nodeIndex[MaxN]
		users.total = users.table[MaxN]
		users.table[MaxN] = 0
	}

	// Compute per-sector thresholds.
	for k := int64(MaxN); k > 0; k-- {
		if p := s.nodeIndex[k]; p != nil {
			if threshold == 0 {
				p.thresh = -99999999
			} else {
				p.thresh = ((p.total >> 16) * threshold) +
					(((p.total & 0xffff) * threshold) >> 16)
			}
		}
	}

	// Assign vertices (count down: k=MAX_N gets vertices[n-1], k=1 gets vertices[0]).
	v := int64(n)
	for k := int64(MaxN); k > 0; k-- {
		if p := s.nodeIndex[k]; p != nil {
			v--
			vtx := &g.Vertices[v]
			s.vertIndex[k] = vtx
			vtx.Name = p.title
			vtx.Z = p.SICList
			vtx.Y = p.total
		}
	}

	// Insert arcs: for each source sector j, for each dest sector k with nonzero
	// flow exceeding k's threshold, create arc u→v with flow = table[j][k].
	for j := int64(MaxN); j > 0; j-- {
		pj := s.nodeIndex[j]
		if pj == nil {
			continue
		}
		u := s.vertIndex[j]
		for k := int64(MaxN); k > 0; k-- {
			if s.vertIndex[k] == nil {
				continue
			}
			flow := pj.table[k]
			if flow != 0 && flow > s.nodeIndex[k].thresh {
				vk := s.vertIndex[k]
				g.NewArc(u, vk, 1)
				u.Arcs.A = flow
			}
		}
	}
}

// mergePR merges the subtrees rooted at pl and pr into p (bottom-up pruning).
// p inherits pl's SIC code and gets a combined SIC_list and table row.
func (s *econState) mergePR(p, pl, pr *econNode) {
	jj := pl.SIC // pl's SIC code (becomes p's SIC code)
	kk := pr.SIC // pr's SIC code (eliminated)

	// Append pr's SIC list to end of pl's SIC list.
	a := pl.SICList
	for a.Next != nil {
		a = a.Next
	}
	a.Next = pr.SICList
	p.SICList = pl.SICList

	// Update all other active sectors' tables: merge column kk into column jj.
	// Also compute p's output row as pl+pr.
	for k := int64(MaxN); k > 0; k-- {
		q := s.nodeIndex[k]
		if q == nil {
			continue
		}
		if q != pl && q != pr {
			q.table[jj] += q.table[kk]
		}
		p.table[k] = pl.table[k] + pr.table[k]
	}
	p.total = pl.total + pr.total
	p.SIC = jj
	p.table[jj] += p.table[kk] // self-flow: all 4 cross-flows summed
	s.nodeIndex[jj] = p
	s.nodeIndex[kk] = nil
}
