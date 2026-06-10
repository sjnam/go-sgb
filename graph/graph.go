// Package graph implements the GB_GRAPH data structures from Stanford
// GraphBase: Vertex, Arc, and Graph, together with the routines for
// creating and searching graphs.
package graph

import (
	"errors"
	"fmt"
)

// Sentinel errors returned by graph generators.
// Use errors.Is to test for a specific condition.
var (
	ErrNoRoom         = errors.New("graph: no room")
	ErrEarlyDataFault = errors.New("graph: early data fault")
	ErrLateDataFault  = errors.New("graph: late data fault")
	ErrSyntaxError    = errors.New("graph: syntax error in data")
	ErrBadSpecs       = errors.New("graph: bad specifications")
	ErrVeryBadSpecs   = errors.New("graph: very bad specifications")
	ErrMissingOperand = errors.New("graph: missing operand")
	ErrInvalidOperand = errors.New("graph: invalid operand")
	ErrImpossible     = errors.New("graph: impossible")
)

// Util is a multipurpose union field. It holds exactly one of:
// *Vertex, *Arc, *Graph, string, or int64.
// Use a type assertion to read the stored value.
type Util = any

// Vertex is a graph vertex with two standard fields and six utility fields.
type Vertex struct {
	Arcs             *Arc   // linked list of outgoing arcs (nil if none)
	Name             string // symbolic identifier
	U, V, W, X, Y, Z Util   // multipurpose fields (see Graph.UtilTypes)

	idx int64 // position within the owning Graph's Vertices (set by NewGraph)
}

// Arc is a directed arc with three standard fields, two utility fields, and
// a Partner pointer.  For arcs created by NewEdge, Partner points to the
// reverse arc of the same undirected edge.  For arcs created by NewArc,
// Partner is nil.
type Arc struct {
	Tip     *Vertex // destination vertex
	Next    *Arc    // next arc from the same source (nil if last)
	Len     int64   // arc length
	A, B    Util    // multipurpose fields
	Partner *Arc    // reverse arc of undirected edge (nil for directed arcs)
}

const (
	IDFieldSize  = 161
	ExtraN       = 4 // shadow vertices silently added by NewGraph
	arcsPerBlock = 102
)

// Graph is a directed graph.
type Graph struct {
	Vertices               []Vertex // contiguous vertex array; indices 0..N-1 are "real"
	N                      int64    // number of real vertices
	M                      int64    // number of arcs
	ID                     string   // human-readable generation parameters
	UtilTypes              string   // 14-char descriptor for utility-field usage
	UU, VV, WW, XX, YY, ZZ Util

	arcBlock []Arc // current slab of pre-allocated Arc records
	nextArc  int   // index of next free slot in arcBlock
}

// NewGraph allocates a Graph with n real vertices (plus ExtraN shadow
// vertices) and returns a pointer to it.
func NewGraph(n int64) *Graph {
	g := &Graph{
		Vertices:  make([]Vertex, n+ExtraN),
		N:         n,
		ID:        fmt.Sprintf("gb_new_graph(%d)", n),
		UtilTypes: "ZZZZZZZZZZZZZZ",
		arcBlock:  make([]Arc, arcsPerBlock),
	}
	for i := range g.Vertices {
		g.Vertices[i].idx = int64(i)
	}
	return g
}

// Recycle is a no-op; Go's garbage collector reclaims the graph automatically.
func (g *Graph) Recycle() {}

// SaveString returns s unchanged. In Go, strings are immutable values and
// need no additional storage management.
func (g *Graph) SaveString(s string) string { return s }

// --- Arc allocation ---

// virginArc returns a pointer to the next available Arc in the current block,
// allocating a fresh block of arcsPerBlock arcs when the current one is full.
func (g *Graph) virginArc() *Arc {
	if g.nextArc >= len(g.arcBlock) {
		g.arcBlock = make([]Arc, arcsPerBlock)
		g.nextArc = 0
	}
	a := &g.arcBlock[g.nextArc]
	g.nextArc++
	return a
}

// NewArc appends a directed arc of length len from u to v.
func (g *Graph) NewArc(u, v *Vertex, length int64) {
	a := g.virginArc()
	a.Tip = v
	a.Next = u.Arcs
	a.Len = length
	u.Arcs = a
	g.M++
}

// NewEdge appends an undirected edge (two paired arcs) of length len between
// u and v.  a0 (u→v) is prepended to u.Arcs and a1 (v→u) to v.Arcs;
// a0.Partner = a1 and a1.Partner = a0.
func (g *Graph) NewEdge(u, v *Vertex, length int64) {
	if g.nextArc+1 >= len(g.arcBlock) {
		g.arcBlock = make([]Arc, arcsPerBlock)
		g.nextArc = 0
	}
	a0 := &g.arcBlock[g.nextArc]
	a1 := &g.arcBlock[g.nextArc+1]
	g.nextArc += 2

	a0.Tip = v
	a0.Len = length
	a0.Next = u.Arcs
	a0.Partner = a1
	a1.Tip = u
	a1.Len = length
	a1.Next = v.Arcs
	a1.Partner = a0
	u.Arcs = a0
	v.Arcs = a1
	g.M += 2
}

// --- Vertex index helpers ---

// VertexIndex returns the 0-based index of v within the vertex array it was
// allocated in. v must come from a Graph's Vertices; results are meaningless
// for vertices constructed directly.
func VertexIndex(g *Graph, v *Vertex) int64 {
	return v.idx
}

// VertexIn reports whether v is an element of slice, which must be a prefix
// of some Graph's Vertices array.
func VertexIn(v *Vertex, slice []Vertex) bool {
	return v.idx >= 0 && v.idx < int64(len(slice)) && &slice[v.idx] == v
}

// --- ID helpers ---

// MakeCompoundID sets g.ID to s1+gg.ID+s2, truncating gg.ID if the result
// would exceed IDFieldSize.
func MakeCompoundID(g *Graph, s1 string, gg *Graph, s2 string) {
	avail := IDFieldSize - len(s1) - len(s2)
	id := gg.ID
	if len(id) < avail {
		g.ID = s1 + id + s2
	} else if avail > 5 {
		g.ID = fmt.Sprintf("%s%s...)%s", s1, id[:avail-5], s2)
	} else {
		g.ID = s1 + s2
	}
}

// MakeDoubleCompoundID sets g.ID from s1+gg.ID+s2+ggg.ID+s3.
func MakeDoubleCompoundID(g *Graph, s1 string, gg *Graph, s2 string, ggg *Graph, s3 string) {
	avail := IDFieldSize - len(s1) - len(s2) - len(s3)
	if len(gg.ID)+len(ggg.ID) < avail {
		g.ID = s1 + gg.ID + s2 + ggg.ID + s3
		return
	}
	h1 := avail/2 - 5
	h2 := (avail - 9) / 2
	id1, id2 := gg.ID, ggg.ID
	if h1 > 0 && len(id1) > h1 {
		id1 = id1[:h1]
	}
	if h2 > 0 && len(id2) > h2 {
		id2 = id2[:h2]
	}
	g.ID = fmt.Sprintf("%s%s...)%s%s...)%s", s1, id1, s2, id2, s3)
}

// --- Hash table (uses Vertex.U as hash_link, Vertex.V as hash_head) ---

const (
	hashMult  int64 = 314159
	hashPrime int64 = 516595003
)

// hashCode returns the hash bucket index for name in a graph with n vertices.
func hashCode(name string, n int64) int64 {
	var h int64
	for i := 0; i < len(name); i++ {
		h += (h ^ (h >> 1)) + hashMult*int64(name[i])
		for h >= hashPrime {
			h -= hashPrime
		}
	}
	return h % n
}

// HashIn inserts v into g's hash table.
// Vertex.U (hash_link) and Vertex.V (hash_head) are consumed.
func (g *Graph) HashIn(v *Vertex) {
	u := &g.Vertices[hashCode(v.Name, g.N)]
	v.U = u.V // link into existing chain
	u.V = v   // new head of chain
}

// HashOut returns the vertex named s in g's hash table, or nil.
func (g *Graph) HashOut(s string) *Vertex {
	u := &g.Vertices[hashCode(s, g.N)]
	v, _ := u.V.(*Vertex)
	for v != nil {
		if v.Name == s {
			return v
		}
		v, _ = v.U.(*Vertex)
	}
	return nil
}

// HashSetup builds a fresh hash table for all real vertices in g.
// It marks UtilTypes[0] and UtilTypes[1] as 'V'.
func (g *Graph) HashSetup() {
	if g == nil || g.N <= 0 {
		return
	}
	for i := int64(0); i < g.N; i++ {
		g.Vertices[i].V = nil // clear hash_head
	}
	for i := int64(0); i < g.N; i++ {
		g.HashIn(&g.Vertices[i])
	}
	if len(g.UtilTypes) >= 2 {
		ut := []byte(g.UtilTypes)
		ut[0] = 'V'
		ut[1] = 'V'
		g.UtilTypes = string(ut)
	}
}

// HashLookup finds the vertex named s in graph g.
func (g *Graph) HashLookup(s string) *Vertex {
	if g == nil || g.N <= 0 {
		return nil
	}
	return g.HashOut(s)
}

// --- Bipartite graph helpers ---

// N1 returns the size of the first part of a bipartite graph
// (stored in utility field UU as int64).
func (g *Graph) N1() int64 {
	v, _ := g.UU.(int64)
	return v
}

// MarkBipartite records n1 as the size of the first part and updates UtilTypes.
func (g *Graph) MarkBipartite(n1 int64) {
	g.UU = n1
	if len(g.UtilTypes) >= 9 {
		ut := []byte(g.UtilTypes)
		ut[8] = 'I'
		g.UtilTypes = string(ut)
	}
}
