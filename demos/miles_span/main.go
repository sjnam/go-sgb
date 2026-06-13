// Command miles_span finds minimum spanning trees of the highway-distance
// graphs produced by GB_MILES, using four classic algorithms, and reports how
// many "mems" (memory references) each one consumes.  Mem counting is the whole
// point of the program: it is a machine-independent way to compare the
// practical efficiency of competing algorithms, so this program is meant to be
// read, not merely run.
//
// The four algorithms are:
//
//   - Kruskal's algorithm with a radix sort and union/find ("two nearest
//     fragments", Graham & Hell's Algorithm 1);
//   - Jarník/Prim with a binary heap ("nearest neighbor", Algorithm 2);
//   - Jarník/Prim with a Fibonacci heap;
//   - Cheriton/Tarjan/Karp with binomial queues ("all nearest fragments",
//     Algorithm 3).
//
// Usage: miles_span [-nN][-dN][-rN][-sN][-NN][-WN][-PN][-v][-gFILE][-DDIR]
//
//	-nN     number of cities/vertices (default 100, max 128)
//	-NN     north_weight (default 0)
//	-WN     west_weight  (default 0)
//	-PN     pop_weight   (default 0)
//	-dN     max_degree   (default 10)
//	-rN     investigate N graphs with consecutive seeds (default 1)
//	-sN     random seed  (default 0)
//	-v      verbose: report each edge of each spanning tree
//	-gFILE  restore an external graph from FILE instead of calling miles
//	-DDIR   data directory containing miles.dat (default "data/")
//
// This is a Go port of Knuth's MILES_SPAN demo from the Stanford GraphBase.
package main

import (
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"

	gbgraph "github.com/sjnam/go-sgb/gb-graph"
	gbio "github.com/sjnam/go-sgb/gb-io"
	gbmiles "github.com/sjnam/go-sgb/gb-miles"
	gbsave "github.com/sjnam/go-sgb/gb-save"
)

// infinity is returned by an algorithm when the graph has no spanning tree.
const infinity = int64(^uint64(0) >> 1)

// ctkINF is an upper bound on every edge length, used by cher_tar_kar.
const ctkINF = 30000

// knownMark is the sentinel stored in a vertex's backlink once it has entered
// the current spanning-tree fragment (the KNOWN marker of the original).
var knownMark = &gbgraph.Vertex{}

func main() {
	n := int64(100)
	nWeight, wWeight, pWeight := int64(0), int64(0), int64(0)
	d := int64(10)
	seed := int64(0)
	reps := int64(1)
	verbose := false
	dataDir := "data/"
	var fileName string

	for _, arg := range os.Args[1:] {
		switch {
		case strings.HasPrefix(arg, "-n"):
			n = parseArg(arg)
		case strings.HasPrefix(arg, "-N"):
			nWeight = parseArg(arg)
		case strings.HasPrefix(arg, "-W"):
			wWeight = parseArg(arg)
		case strings.HasPrefix(arg, "-P"):
			pWeight = parseArg(arg)
		case strings.HasPrefix(arg, "-d"):
			d = parseArg(arg)
		case strings.HasPrefix(arg, "-r"):
			reps = parseArg(arg)
		case strings.HasPrefix(arg, "-s"):
			seed = parseArg(arg)
		case arg == "-v":
			verbose = true
		case strings.HasPrefix(arg, "-g"):
			fileName = arg[2:]
		case strings.HasPrefix(arg, "-D"):
			dataDir = arg[2:]
		default:
			usage()
		}
	}
	if fileName != "" {
		reps = 1
	}
	gbio.DataDirectory = dataDir

	var trace io.Writer
	if verbose {
		trace = os.Stdout
	}

	for ; reps > 0; reps-- {
		var g *gbgraph.Graph
		var err error
		if fileName != "" {
			g, err = gbsave.RestoreGraph(fileName)
		} else {
			g, _, err = gbmiles.Miles(n, nWeight, wWeight, pWeight, 0, d, seed)
		}
		if err != nil || g == nil || g.N <= 1 {
			fmt.Fprintf(os.Stderr,
				"Sorry, can't create the graph! (error code %v)\n", err)
			os.Exit(1)
		}
		report(g, trace)
		g.Recycle()
		seed++ // increase the seed value
	}
}

func parseArg(arg string) int64 {
	v, err := strconv.ParseInt(arg[2:], 10, 64)
	if err != nil {
		usage()
	}
	return v
}

func usage() {
	fmt.Fprintf(os.Stderr,
		"Usage: %s [-nN][-dN][-rN][-sN][-NN][-WN][-PN][-v][-gFILE][-DDIR]\n",
		os.Args[0])
	os.Exit(2)
}

// report runs all four algorithms on g and prints their mem counts.
func report(g *gbgraph.Graph, trace io.Writer) {
	s := &solver{g: g, trace: trace}

	fmt.Printf("The graph %s has %d edges,\n", g.ID, g.M/2)
	spLength := s.krusk()
	if spLength == infinity {
		fmt.Printf("  and it isn't connected.\n")
	} else {
		fmt.Printf("  and its minimum spanning tree has length %d.\n", spLength)
	}
	fmt.Printf(" The Kruskal/radix-sort algorithm takes %d mems;\n", s.mems)

	if spLength != s.jarPr(&binaryHeap{s: s, elt: make([]*gbgraph.Vertex, g.N+1)}) {
		bug()
	}
	fmt.Printf(" the Jarnik/Prim/binary-heap algorithm takes %d mems;\n", s.mems)

	if spLength != s.jarPr(&fibHeap{s: s, newRoots: make([]*gbgraph.Vertex, 46)}) {
		bug()
	}
	fmt.Printf(" the Jarnik/Prim/Fibonacci-heap algorithm takes %d mems;\n", s.mems)

	if spLength != s.cherTarKar() {
		bug()
	}
	fmt.Printf(" the Cheriton/Tarjan/Karp algorithm takes %d mems.\n\n", s.mems)
}

func bug() {
	fmt.Println(" ...oops, I've got a bug, please fix fix fix")
	os.Exit(1)
}

// --- shared state and mem instrumentation ---

// vinfo holds the per-vertex working fields used by the algorithms.  The
// original C program packs these into the six utility fields of a Vertex (and
// borrows an auxiliary Arc record for the Fibonacci heap, since six fields are
// not enough); a parallel struct array is the idiomatic Go equivalent and
// keeps the mem charges at exactly the same logical points.
type vinfo struct {
	dist      int64           // key field for the priority queue
	backlink  *gbgraph.Vertex // nil=unseen, knownMark=known, else predecessor
	heapIndex int64           // position within the binary heap

	// Fibonacci-heap links.
	parent  *gbgraph.Vertex
	child   *gbgraph.Vertex
	lsib    *gbgraph.Vertex
	rsib    *gbgraph.Vertex
	rankTag int64 // rank*2 + tag

	// Kruskal union/find and cher_tar_kar fragment links.
	clink  *gbgraph.Vertex
	comp   *gbgraph.Vertex
	csize  int64
	findex int64        // reuses csize's role in stage 2 of cher_tar_kar
	pq     *gbgraph.Arc // binomial-queue header for this fragment
}

// solver carries a graph, the running mem count, and the per-vertex working
// storage shared between an algorithm and its priority queue.
type solver struct {
	g     *gbgraph.Graph
	trace io.Writer // non-nil in verbose mode
	mems  int64     // memory references counted so far
	info  []vinfo
}

// vi returns the working record for vertex v.
func (s *solver) vi(v *gbgraph.Vertex) *vinfo {
	return &s.info[gbgraph.VertexIndex(s.g, v)]
}

// report prints one edge of a spanning tree in verbose mode.
func (s *solver) report(u, v *gbgraph.Vertex, l int64) {
	fmt.Fprintf(s.trace, "  %d miles between %s and %s [%d mems]\n",
		l, u.Name, v.Name, s.mems)
}

// --- Kruskal's algorithm ---

// Arc utility-field accessors for Kruskal: from = source vertex (Arc.A),
// klink = next longer edge (Arc.B).
func arcFrom(a *gbgraph.Arc) *gbgraph.Vertex       { v, _ := a.A.(*gbgraph.Vertex); return v }
func setArcFrom(a *gbgraph.Arc, v *gbgraph.Vertex) { a.A = v }
func klink(a *gbgraph.Arc) *gbgraph.Arc            { k, _ := a.B.(*gbgraph.Arc); return k }
func setKlink(a, k *gbgraph.Arc)                   { a.B = k }

func (s *solver) krusk() int64 {
	s.mems = 0
	n := s.g.N
	s.info = make([]vinfo, n)
	var aucket, bucket [64]*gbgraph.Arc

	// Put all the edges into bucket[0..63] with a two-pass radix sort on the
	// low and high 6 bits of each length (lengths are < 2^12).
	s.mems++ // o,n=g->n
	for l := range 64 {
		aucket[l], bucket[l] = nil, nil
		s.mems += 2
	}
	s.mems++ // o, v=g->vertices (first fetch)
	for vi := range n {
		v := &s.g.Vertices[vi]
		a := v.Arcs
		s.mems++ // o,a=v->arcs
		for a != nil {
			s.mems++ // o,a->tip
			if gbgraph.VertexIndex(s.g, a.Tip) <= vi {
				break // consider each undirected edge only once
			}
			setArcFrom(a, v)
			s.mems++ // o,a->from=v
			l := a.Len & 0x3f
			s.mems++ // o,l=a->len&0x3f
			setKlink(a, aucket[l])
			s.mems += 2 // oo,a->klink=aucket[l]
			aucket[l] = a
			s.mems++ // o,aucket[l]=a
			a = a.Next
			s.mems++ // o,a=a->next
		}
	}
	for l := 63; l >= 0; l-- {
		a := aucket[l]
		s.mems++ // o,a=aucket[l]
		for a != nil {
			aa := a
			a = klink(aa)
			s.mems++ // o,a=a->klink
			ll := aa.Len >> 6
			s.mems++ // o,ll=aa->len>>6
			setKlink(aa, bucket[ll])
			s.mems += 2 // oo,aa->klink=bucket[ll]
			bucket[ll] = aa
			s.mems++ // o,bucket[ll]=aa
		}
	}
	if s.trace != nil {
		fmt.Fprintf(s.trace, "   [%d mems to sort the edges into buckets]\n", s.mems)
	}

	// Put all the vertices into components by themselves.
	for vi := range n {
		v := &s.g.Vertices[vi]
		iv := s.vi(v)
		iv.clink, iv.comp = v, v
		s.mems += 2 // oo,v->clink=v->comp=v
		iv.csize = 1
		s.mems++ // o,v->csize=1
	}
	components := n

	var totLen int64
	for l := range 64 {
		a := bucket[l]
		s.mems++ // o,a=bucket[l]
		for a != nil {
			u := arcFrom(a)
			s.mems++ // o,u=a->from
			v := a.Tip
			s.mems++    // o,v=a->tip
			s.mems += 2 // oo,u->comp==v->comp
			if s.vi(u).comp == s.vi(v).comp {
				a = klink(a)
				s.mems++ // o,a=a->klink
				continue
			}
			if s.trace != nil {
				s.report(arcFrom(a), a.Tip, a.Len)
			}
			totLen += a.Len
			s.mems++ // o,tot_len+=a->len
			components--
			if components == 1 {
				return totLen
			}
			s.mergeComp(u, v)
			a = klink(a)
			s.mems++ // o,a=a->klink
		}
	}
	return infinity // the graph wasn't connected
}

// mergeComp merges the components containing u and v (union/find).
func (s *solver) mergeComp(u, v *gbgraph.Vertex) {
	u = s.vi(u).comp // already fetched
	v = s.vi(v).comp // ditto
	s.mems += 2      // oo,u->csize<v->csize
	if s.vi(u).csize < s.vi(v).csize {
		u, v = v, u // keep v's component the smaller
	}
	s.vi(u).csize += s.vi(v).csize
	s.mems++ // o,u->csize+=v->csize
	w := s.vi(v).clink
	s.mems++ // o,w=v->clink
	s.vi(v).clink = s.vi(u).clink
	s.mems += 2 // oo,v->clink=u->clink
	s.vi(u).clink = w
	s.mems++ // o,u->clink=w
	for {
		s.vi(w).comp = u
		s.mems++ // o,w->comp=u
		if w == v {
			break
		}
		w = s.vi(w).clink
		s.mems++ // o,w=w->clink
	}
}

// --- Jarník and Prim's algorithm ---

// pqueue abstracts the priority-queue operations described in GB_DIJK, so that
// either a binary heap or a Fibonacci heap can be plugged into jar_pr.
type pqueue interface {
	initQueue()
	enqueue(v *gbgraph.Vertex, d int64)
	requeue(v *gbgraph.Vertex, d int64)
	delMin() *gbgraph.Vertex
}

func (s *solver) jarPr(q pqueue) int64 {
	s.mems = 0
	n := s.g.N
	s.info = make([]vinfo, n)

	// Make t=g->vertices[0] the only vertex seen; also make it known.
	s.mems += 2 // oo,t=g->vertices+g->n-1
	for ti := n - 1; ti > 0; ti-- {
		s.info[ti].backlink = nil
		s.mems++ // o,t->backlink=NULL
	}
	t := &s.g.Vertices[0]
	s.vi(t).backlink = knownMark
	s.mems++ // o,t->backlink=KNOWN
	fragmentSize := int64(1)
	q.initQueue()

	var totLen int64
	for fragmentSize < n {
		// Put all unseen vertices adjacent to t into the queue, and update
		// the distances of the others.
		a := t.Arcs
		s.mems++ // o,a=t->arcs
		for a != nil {
			v := a.Tip
			s.mems++ // o,v=a->tip
			bl := s.vi(v).backlink
			s.mems++ // o,v->backlink
			if bl != nil {
				if bl != knownMark { // v is seen but still in the queue
					s.mems += 2 // oo,a->len<v->dist
					if a.Len < s.vi(v).dist {
						s.vi(v).backlink = t
						s.mems++ // o,v->backlink=t
						q.requeue(v, a.Len)
					}
				}
			} else { // v hasn't been seen before
				s.vi(v).backlink = t
				s.mems++ // o,v->backlink=t
				s.mems++ // o,(*enqueue)
				q.enqueue(v, a.Len)
			}
			a = a.Next
			s.mems++ // o,a=a->next
		}
		t = q.delMin()
		if t == nil {
			return infinity // the graph is disconnected
		}
		if s.trace != nil {
			s.report(s.vi(t).backlink, t, s.vi(t).dist)
		}
		totLen += s.vi(t).dist
		s.mems++ // o,tot_len+=t->dist
		s.vi(t).backlink = knownMark
		s.mems++ // o,t->backlink=KNOWN
		fragmentSize++
	}
	return totLen
}

// --- Binary heaps ---

type binaryHeap struct {
	s    *solver
	elt  []*gbgraph.Vertex // 1-indexed heap array
	size int64
}

func (h *binaryHeap) initQueue() { h.size = 0 }

func (h *binaryHeap) enqueue(v *gbgraph.Vertex, d int64) {
	s := h.s
	s.vi(v).dist = d
	s.mems++ // o,v->dist=d
	h.size++
	k := h.size
	j := k >> 1
	for j > 0 {
		u := h.elt[j]
		s.mems += 2 // oo,(u=heap_elt(j))->dist>d
		if !(s.vi(u).dist > d) {
			break
		}
		h.elt[k] = u
		s.mems++ // o,heap_elt(k)=u
		s.vi(u).heapIndex = k
		s.mems++ // o,u->heap_index=k
		k = j
		j = k >> 1
	}
	h.elt[k] = v
	s.mems++ // o,heap_elt(k)=v
	s.vi(v).heapIndex = k
	s.mems++ // o,v->heap_index=k
}

func (h *binaryHeap) requeue(v *gbgraph.Vertex, d int64) {
	s := h.s
	s.vi(v).dist = d
	s.mems++ // o,v->dist=d
	k := s.vi(v).heapIndex
	s.mems++ // o,k=v->heap_index
	j := k >> 1
	if j > 0 {
		u := h.elt[j]
		s.mems += 2 // oo,(u=heap_elt(j))->dist>d
		if s.vi(u).dist > d {
			for {
				h.elt[k] = u
				s.mems++ // o,heap_elt(k)=u
				s.vi(u).heapIndex = k
				s.mems++ // o,u->heap_index=k
				k = j
				j = k >> 1
				if j <= 0 {
					break
				}
				u = h.elt[j]
				s.mems += 2 // oo,(u=heap_elt(j))->dist>d
				if !(s.vi(u).dist > d) {
					break
				}
			}
			h.elt[k] = v
			s.mems++ // o,heap_elt(k)=v
			s.vi(v).heapIndex = k
			s.mems++ // o,v->heap_index=k
		}
	}
}

func (h *binaryHeap) delMin() *gbgraph.Vertex {
	s := h.s
	if h.size == 0 {
		return nil
	}
	v := h.elt[1]
	s.mems++ // o,v=heap_elt(1)
	u := h.elt[h.size]
	s.mems++ // o,u=heap_elt(hsize--)
	h.size--
	d := s.vi(u).dist
	s.mems++ // o,d=u->dist
	k := int64(1)
	j := int64(2)
	for j <= h.size {
		s.mems += 4 // oooo,heap_elt(j)->dist>heap_elt(j+1)->dist
		if s.vi(h.elt[j]).dist > s.vi(h.elt[j+1]).dist {
			j++
		}
		if s.vi(h.elt[j]).dist >= d {
			break
		}
		h.elt[k] = h.elt[j]
		s.mems++ // o,heap_elt(k)=heap_elt(j)
		s.vi(h.elt[k]).heapIndex = k
		s.mems++ // o,heap_elt(k)->heap_index=k
		k = j
		j = k << 1
	}
	h.elt[k] = u
	s.mems++ // o,heap_elt(k)=u
	s.vi(u).heapIndex = k
	s.mems++ // o,u->heap_index=k
	return v
}

// --- Fibonacci heaps ---

type fibHeap struct {
	s        *solver
	fHeap    *gbgraph.Vertex // a node with smallest key, or nil
	newRoots []*gbgraph.Vertex
}

func (f *fibHeap) initQueue() { f.fHeap = nil }

func (f *fibHeap) enqueue(v *gbgraph.Vertex, d int64) {
	s := f.s
	iv := s.vi(v)
	iv.dist = d
	s.mems++ // o,v->dist=d
	iv.parent = nil
	s.mems++ // o,v->parent=NULL
	iv.rankTag = 0
	s.mems++ // o,v->rank_tag=0
	if f.fHeap == nil {
		iv.lsib, iv.rsib = v, v
		f.fHeap = v
		s.mems += 2 // oo,F_heap=v->lsib=v->rsib=v
	} else {
		u := s.vi(f.fHeap).lsib
		s.mems++ // o,u=F_heap->lsib
		iv.lsib = u
		s.mems++ // o,v->lsib=u
		iv.rsib = f.fHeap
		s.mems++ // o,v->rsib=F_heap
		s.vi(f.fHeap).lsib = v
		s.vi(u).rsib = v
		s.mems += 2 // oo,F_heap->lsib=u->rsib=v
		if s.vi(f.fHeap).dist > d {
			f.fHeap = v
		}
	}
}

func (f *fibHeap) requeue(v *gbgraph.Vertex, d int64) {
	s := f.s
	s.vi(v).dist = d
	s.mems++ // o,v->dist=d
	p := s.vi(v).parent
	s.mems++ // o,p=v->parent
	if p == nil {
		if s.vi(f.fHeap).dist > d {
			f.fHeap = v
		}
		return
	}
	s.mems++ // o,p->dist>d
	if !(s.vi(p).dist > d) {
		return
	}
	for {
		r := s.vi(p).rankTag
		s.mems++    // o,r=p->rank_tag
		if r >= 4 { // v is not an only child: remove v from its family
			iv := s.vi(v)
			u := iv.lsib
			s.mems++ // o,u=v->lsib
			w := iv.rsib
			s.mems++ // o,w=v->rsib
			s.vi(u).rsib = w
			s.mems++ // o,u->rsib=w
			s.vi(w).lsib = u
			s.mems++ // o,w->lsib=u
			s.mems++ // o,p->child==v
			if s.vi(p).child == v {
				s.vi(p).child = w
				s.mems++ // o,p->child=w
			}
		}
		// Insert v into the forest.
		s.vi(v).parent = nil
		s.mems++ // o,v->parent=NULL
		u := s.vi(f.fHeap).lsib
		s.mems++ // o,u=F_heap->lsib
		s.vi(v).lsib = u
		s.mems++ // o,v->lsib=u
		s.vi(v).rsib = f.fHeap
		s.mems++ // o,v->rsib=F_heap
		s.vi(f.fHeap).lsib = v
		s.vi(u).rsib = v
		s.mems += 2 // oo,F_heap->lsib=u->rsib=v
		if s.vi(f.fHeap).dist > d {
			f.fHeap = v
		}
		pp := s.vi(p).parent
		s.mems++       // o,pp=p->parent
		if pp == nil { // the parent of v is a root
			s.vi(p).rankTag = r - 2
			s.mems++ // o,p->rank_tag=r-2
			break
		}
		if r&1 == 0 { // the parent of v is untagged
			s.vi(p).rankTag = r - 1
			s.mems++ // o,p->rank_tag=r-1
			break
		}
		s.vi(p).rankTag = r - 2
		s.mems++ // o,p->rank_tag=r-2
		v, p = p, pp
	}
}

func (f *fibHeap) delMin() *gbgraph.Vertex {
	s := f.s
	finalV := f.fHeap
	h := -1
	if f.fHeap != nil {
		fh := f.fHeap
		var v *gbgraph.Vertex
		s.mems++ // o,F_heap->rank_tag<2
		if s.vi(fh).rankTag < 2 {
			v = s.vi(fh).rsib
			s.mems++ // o,v=F_heap->rsib
		} else {
			w := s.vi(fh).child
			s.mems++ // o,w=F_heap->child
			v = s.vi(w).rsib
			s.mems++ // o,v=w->rsib
			s.vi(w).rsib = s.vi(fh).rsib
			s.mems += 2 // oo,w->rsib=F_heap->rsib
			for w = v; w != s.vi(fh).rsib; {
				s.vi(w).parent = nil
				s.mems++ // o,w->parent=NULL
				w = s.vi(w).rsib
				s.mems++ // o,w=w->rsib
			}
		}
		for v != fh {
			w := s.vi(v).rsib
			s.mems++ // o,w=v->rsib
			f.putTree(v, &h)
			v = w
		}
		f.rebuild(h)
	}
	return finalV
}

// putTree puts the tree rooted at v into the new_roots forest, combining trees
// of equal rank.  h tracks the highest rank present.
func (f *fibHeap) putTree(v *gbgraph.Vertex, h *int) {
	s := f.s
	r := s.vi(v).rankTag >> 1
	s.mems++ // o,r=v->rank_tag>>1
	for {
		if int64(*h) < r {
			for {
				*h++
				if int64(*h) == r {
					f.newRoots[*h] = v
				} else {
					f.newRoots[*h] = nil
				}
				s.mems++ // o,new_roots[h]=...
				if !(int64(*h) < r) {
					break
				}
			}
			break
		}
		s.mems++ // o,new_roots[r]==NULL
		if f.newRoots[r] == nil {
			f.newRoots[r] = v
			s.mems++ // o,new_roots[r]=v
			break
		}
		u := f.newRoots[r]
		f.newRoots[r] = nil
		s.mems++    // o,new_roots[r]=NULL
		s.mems += 2 // oo,u->dist<v->dist
		if s.vi(u).dist < s.vi(v).dist {
			s.vi(v).rankTag = r << 1
			s.mems++ // o,v->rank_tag=r<<1
			u, v = v, u
		}
		f.makeChild(u, v, r)
		r++
	}
	s.vi(v).rankTag = r << 1
	s.mems++ // o,v->rank_tag=r<<1
}

// makeChild makes u (rank r, untagged) a child of v.
func (f *fibHeap) makeChild(u, v *gbgraph.Vertex, r int64) {
	s := f.s
	if r == 0 {
		s.vi(v).child = u
		s.mems++ // o,v->child=u
		s.vi(u).lsib, s.vi(u).rsib = u, u
		s.mems += 2 // oo,u->lsib=u->rsib=u
	} else {
		t := s.vi(v).child
		s.mems++ // o,t=v->child
		s.vi(u).rsib = s.vi(t).rsib
		s.mems += 2 // oo,u->rsib=t->rsib
		s.vi(u).lsib = t
		s.mems++ // o,u->lsib=t
		s.vi(s.vi(u).rsib).lsib = u
		s.vi(t).rsib = u
		s.mems += 2 // oo,u->rsib->lsib=t->rsib=u
	}
	s.vi(u).parent = v
	s.mems++ // o,u->parent=v
}

// rebuild reconstructs F_heap from the new_roots forest.
func (f *fibHeap) rebuild(h int) {
	s := f.s
	if h < 0 {
		f.fHeap = nil
		return
	}
	u := f.newRoots[h]
	v := u
	s.mems++ // o,u=v=new_roots[h]
	d := s.vi(u).dist
	s.mems++ // o,d=u->dist
	f.fHeap = u
	for h--; h >= 0; h-- {
		s.mems++ // o,new_roots[h]
		if f.newRoots[h] != nil {
			w := f.newRoots[h]
			s.vi(w).lsib = v
			s.mems++ // o,w->lsib=v
			s.vi(v).rsib = w
			s.mems++ // o,v->rsib=w
			s.mems++ // o,w->dist<d
			if s.vi(w).dist < d {
				f.fHeap = w
				d = s.vi(w).dist
			}
			v = w
		}
	}
	s.vi(v).rsib = u
	s.mems++ // o,v->rsib=u
	s.vi(u).lsib = v
	s.mems++ // o,u->lsib=v
}

// --- Binomial queues (for Cheriton/Tarjan/Karp) ---

// Arc utility-field accessors for binomial queues: qchild = largest child
// (Arc.A), qsib = next sibling (Arc.B).  In a header node, qcount (the node
// total) takes the place of qchild in Arc.A.
func qchild(a *gbgraph.Arc) *gbgraph.Arc { c, _ := a.A.(*gbgraph.Arc); return c }
func setQchild(a, c *gbgraph.Arc)        { a.A = c }
func qsib(a *gbgraph.Arc) *gbgraph.Arc   { sb, _ := a.B.(*gbgraph.Arc); return sb }
func setQsib(a, sb *gbgraph.Arc)         { a.B = sb }
func qcount(a *gbgraph.Arc) int64        { n, _ := a.A.(int64); return n }
func setQcount(a *gbgraph.Arc, n int64)  { a.A = n }

// qunite merges a forest of m nodes starting at q with a forest of mm nodes
// starting at qq, putting the resulting forest of m+mm nodes into h->qsib.
func (s *solver) qunite(m int64, q *gbgraph.Arc, mm int64, qq *gbgraph.Arc, h *gbgraph.Arc) {
	p := h
	k := int64(1)
	for m != 0 {
		switch {
		case m&k == 0:
			if mm&k != 0 { // qq goes into the merged list
				setQsib(p, qq)
				s.mems++ // o,p->qsib=qq
				p = qq
				mm -= k
				if mm != 0 {
					qq = qsib(qq)
					s.mems++ // o,qq=qq->qsib
				}
			}
		case mm&k == 0: // q goes into the merged list
			setQsib(p, q)
			s.mems++ // o,p->qsib=q
			p = q
			m -= k
			if m != 0 {
				q = qsib(q)
				s.mems++ // o,q=q->qsib
			}
		default:
			// Combine q and qq into a "carry" tree, and keep merging until the
			// carry no longer propagates.
			var r, rr *gbgraph.Arc
			m -= k
			if m != 0 {
				r = qsib(q)
				s.mems++ // o,r=q->qsib
			}
			mm -= k
			if mm != 0 {
				rr = qsib(qq)
				s.mems++ // o,rr=qq->qsib
			}
			// Set c to the combination of q and qq.
			var c *gbgraph.Arc
			var key int64
			s.mems += 2 // oo,q->len<qq->len
			if q.Len < qq.Len {
				c, key = q, q.Len
				q = qq
			} else {
				c, key = qq, qq.Len
			}
			if k == 1 {
				setQchild(c, q)
				s.mems++ // o,c->qchild=q
			} else {
				qq = qchild(c)
				s.mems++ // o,qq=c->qchild
				setQchild(c, q)
				s.mems++ // o,c->qchild=q
				if k == 2 {
					setQsib(q, qq)
					s.mems++ // o,q->qsib=qq
				} else {
					setQsib(q, qsib(qq))
					s.mems += 2 // oo,q->qsib=qq->qsib
				}
				setQsib(qq, q)
				s.mems++ // o,qq->qsib=q
			}
			k <<= 1
			q, qq = r, rr
			for (m|mm)&k != 0 {
				if m&k == 0 {
					// Merge qq into c and advance qq.
					mm -= k
					if mm != 0 {
						rr = qsib(qq)
						s.mems++ // o,rr=qq->qsib
					}
					s.mems++ // o,qq->len<key
					if qq.Len < key {
						r, c, key, qq = c, qq, qq.Len, c
					}
					r = qchild(c)
					s.mems++ // o,r=c->qchild
					setQchild(c, qq)
					s.mems++ // o,c->qchild=qq
					if k == 2 {
						setQsib(qq, r)
						s.mems++ // o,qq->qsib=r
					} else {
						setQsib(qq, qsib(r))
						s.mems += 2 // oo,qq->qsib=r->qsib
					}
					setQsib(r, qq)
					s.mems++ // o,r->qsib=qq
					qq = rr
				} else {
					// Merge q into c and advance q.
					m -= k
					if m != 0 {
						r = qsib(q)
						s.mems++ // o,r=q->qsib
					}
					s.mems++ // o,q->len<key
					if q.Len < key {
						rr, c, key, q = c, q, q.Len, c
					}
					rr = qchild(c)
					s.mems++ // o,rr=c->qchild
					setQchild(c, q)
					s.mems++ // o,c->qchild=q
					if k == 2 {
						setQsib(q, rr)
						s.mems++ // o,q->qsib=rr
					} else {
						setQsib(q, qsib(rr))
						s.mems += 2 // oo,q->qsib=rr->qsib
					}
					setQsib(rr, q)
					s.mems++ // o,rr->qsib=q
					q = r
					if mm&k != 0 {
						setQsib(p, qq)
						s.mems++ // o,p->qsib=qq
						p = qq
						mm -= k
						if mm != 0 {
							qq = qsib(qq)
							s.mems++ // o,qq=qq->qsib
						}
					}
				}
				k <<= 1
			}
			setQsib(p, c)
			s.mems++ // o,p->qsib=c
			p = c
		}
		k <<= 1
	}
	if mm != 0 {
		setQsib(p, qq)
		s.mems++ // o,p->qsib=qq
	}
}

// qenque inserts arc a into the binomial queue with header h.
func (s *solver) qenque(h, a *gbgraph.Arc) {
	m := qcount(h)
	s.mems++ // o,m=h->qcount
	setQcount(h, m+1)
	s.mems++ // o,h->qcount=m+1
	if m == 0 {
		setQsib(h, a)
		s.mems++ // o,h->qsib=a
	} else {
		s.mems++ // o,h->qsib
		s.qunite(1, a, m, qsib(h), h)
	}
}

// qmerge merges binomial queue hh into binomial queue h.
func (s *solver) qmerge(h, hh *gbgraph.Arc) {
	mm := qcount(hh)
	s.mems++ // o,mm=hh->qcount
	if mm == 0 {
		return
	}
	m := qcount(h)
	s.mems++ // o,m=h->qcount
	setQcount(h, m+mm)
	s.mems++ // o,h->qcount=m+mm
	switch {
	case m >= mm:
		s.mems += 2 // oo,hh->qsib & h->qsib
		s.qunite(mm, qsib(hh), m, qsib(h), h)
	case m == 0:
		setQsib(h, qsib(hh))
		s.mems += 2 // oo,h->qsib=hh->qsib
	default:
		s.mems += 2 // oo
		s.qunite(m, qsib(h), mm, qsib(hh), h)
	}
}

// qdelMin removes and returns the node with the smallest key from queue h.
func (s *solver) qdelMin(h *gbgraph.Arc) *gbgraph.Arc {
	m := qcount(h)
	s.mems++ // o,m=h->qcount
	if m == 0 {
		return nil
	}
	setQcount(h, m-1)
	s.mems++ // o,h->qcount=m-1

	// Find and remove a tree whose root q has the smallest key.
	mm := m & (m - 1)
	q := qsib(h)
	s.mems++ // o,q=h->qsib
	k := m - mm
	if mm != 0 { // there's more than one tree
		p := q
		qq := h
		key := q.Len
		s.mems++ // o,key=q->len
		for {
			t := mm & (mm - 1)
			pp := p
			p = qsib(p)
			s.mems++ // o,p=p->qsib
			s.mems++ // o,p->len<=key
			if p.Len <= key {
				q, qq, k, key = p, pp, mm-t, p.Len
			}
			mm = t
			if mm == 0 {
				break
			}
		}
		if k+k <= m {
			setQsib(qq, qsib(q))
			s.mems += 2 // oo,qq->qsib=q->qsib
		}
	}

	switch {
	case k > 2:
		if k+k <= m {
			s.mems += 2 // oo,q->qchild->qsib
			s.qunite(k-1, qsib(qchild(q)), m-k, qsib(h), h)
		} else {
			s.mems += 2 // oo
			s.qunite(m-k, qsib(h), k-1, qsib(qchild(q)), h)
		}
	case k == 2:
		s.mems++ // o,q->qchild
		s.qunite(1, qchild(q), m-k, qsib(h), h)
	}
	return q
}

// qtraverse visits each node of binomial queue h exactly once, destroying the
// queue as it goes.
func (s *solver) qtraverse(h *gbgraph.Arc, visit func(*gbgraph.Arc)) {
	m := qcount(h)
	s.mems++ // o,m=h->qcount
	p := h
	for m != 0 {
		p = qsib(p)
		s.mems++ // o,p=p->qsib
		visit(p)
		if m&1 != 0 {
			m--
		} else {
			q := qchild(p)
			s.mems++ // o,q=p->qchild
			if m&2 != 0 {
				visit(q)
			} else {
				r := qsib(q)
				s.mems++ // o,r=q->qsib
				if m&(m-1) != 0 {
					setQsib(q, qsib(p))
					s.mems += 2 // oo,q->qsib=p->qsib
				}
				visit(r)
				p = r
			}
			m -= 2
		}
	}
}

// --- Cheriton, Tarjan, and Karp's algorithm ---

// ctk holds the working state of cher_tar_kar.
type ctk struct {
	s         *solver
	small     *gbgraph.Vertex // beginning of the small-fragment list
	tail      *gbgraph.Vertex // end of the small-fragment list
	largeList *gbgraph.Vertex // beginning of the large-fragment list
	frags     int64           // current number of fragments
	loSqrt    int64           // floor(sqrt(n))
	hiSqrt    int64           // floor(sqrt(n+1)+1/2)
	kk        int64           // current fragment index in stage 2
	totLen    int64           // total length of all edges in fragments
	matx      []int64         // loSqrt×loSqrt reduced distance matrix
	matxArc   []*gbgraph.Arc  // arcs corresponding to matx, for verbose mode
}

func (s *solver) cherTarKar() int64 {
	s.mems = 0
	n := s.g.N
	s.info = make([]vinfo, n)

	// Each fragment owns a binomial-queue header; the original borrows an Arc
	// record per vertex for this (newarc).
	headers := make([]gbgraph.Arc, n)
	for i := range n {
		s.info[i].pq = &headers[i]
	}

	c := &ctk{s: s}
	if !c.stage1() {
		return infinity // the graph isn't connected
	}
	if s.trace != nil {
		fmt.Fprintf(s.trace, "    [Stage 1 has used %d mems]\n", s.mems)
	}
	return c.stage2()
}

// stage1 builds small fragments until only loSqrt of them remain.  It returns
// false if the graph turns out to be disconnected.
func (c *ctk) stage1() bool {
	s := c.s
	c.frags = s.g.N
	s.mems++ // o,frags=g->n
	for c.hiSqrt = 1; c.hiSqrt*(c.hiSqrt+1) <= c.frags; c.hiSqrt++ {
	}
	if c.hiSqrt*c.hiSqrt <= c.frags {
		c.loSqrt = c.hiSqrt
	} else {
		c.loSqrt = c.hiSqrt - 1
	}
	c.largeList = nil

	// Create the small list: n single-vertex fragments.
	c.small = &s.g.Vertices[0]
	s.mems++ // o,s=g->vertices
	var v *gbgraph.Vertex
	for vi := int64(0); vi < c.frags; vi++ {
		v = &s.g.Vertices[vi]
		iv := s.vi(v)
		if vi > 0 {
			iv.lsib = &s.g.Vertices[vi-1]
			s.mems++ // o,v->lsib=v-1
			s.vi(&s.g.Vertices[vi-1]).rsib = v
			s.mems++ // o,(v-1)->rsib=v
		}
		iv.comp = nil
		s.mems++ // o,v->comp=NULL
		iv.csize = 1
		s.mems++ // o,v->csize=1
		setQcount(iv.pq, 0)
		s.mems++ // o,v->pq->qcount=0
		a := v.Arcs
		s.mems++ // o,a=v->arcs
		for a != nil {
			s.qenque(iv.pq, a)
			a = a.Next
			s.mems++ // o,a=a->next
		}
	}
	c.tail = v // t = v-1, the last fragment created

	for c.frags > c.loSqrt {
		if !c.combine() {
			return false
		}
		c.frags--
	}
	return true
}

// combine merges the first fragment on the small list with its nearest
// neighbor.  It returns false if no neighbor exists (disconnected graph).
func (c *ctk) combine() bool {
	s := c.s
	v := c.small
	c.small = s.vi(c.small).rsib
	s.mems++ // o,s=s->rsib (remove v from small list)

	var a *gbgraph.Arc
	var u *gbgraph.Vertex
	for {
		a = s.qdelMin(s.vi(v).pq)
		if a == nil {
			return false
		}
		u = a.Tip
		s.mems++ // o,u=a->tip
		for {
			s.mems++ // o,u->comp
			if s.vi(u).comp == nil {
				break
			}
			u = s.vi(u).comp
		}
		if u != v {
			break
		}
	}
	if s.trace != nil {
		c.reportEdge(a)
	}
	c.totLen += a.Len
	s.mems++ // o,tot_len+=a->len
	s.vi(v).comp = u
	s.mems++ // o,v->comp=u
	s.qmerge(s.vi(u).pq, s.vi(v).pq)
	oldSize := s.vi(u).csize
	s.mems++ // o,old_size=u->csize
	newSize := oldSize + s.vi(v).csize
	s.mems++ // o,new_size=old_size+v->csize
	s.vi(u).csize = newSize
	s.mems++ // o,u->csize=new_size
	c.moveU(u, v, oldSize, newSize)
	return true
}

// reportEdge prints the new edge in verbose mode.  The mate of arc a (whose
// tip is the other endpoint) is its Partner.
func (c *ctk) reportEdge(a *gbgraph.Arc) {
	c.s.report(a.Partner.Tip, a.Tip, a.Len)
}

// moveU repositions fragment u after small fragment v has merged into it.
func (c *ctk) moveU(u, v *gbgraph.Vertex, oldSize, newSize int64) {
	s := c.s
	switch {
	case oldSize >= c.hiSqrt: // u was already large
		if c.tail == v {
			c.small = nil // small list just became empty
		}
	case newSize < c.hiSqrt: // u was and still is small
		if u == c.tail {
			return // u is already where we want it
		}
		if u == c.small {
			c.small = s.vi(u).rsib
			s.mems++ // o,s=u->rsib
		} else {
			s.vi(s.vi(u).rsib).lsib = s.vi(u).lsib
			s.mems += 3 // ooo,u->rsib->lsib=u->lsib
			s.vi(s.vi(u).lsib).rsib = s.vi(u).rsib
			s.mems++ // o,u->lsib->rsib=u->rsib
		}
		s.vi(c.tail).rsib = u
		s.mems++ // o,t->rsib=u
		s.vi(u).lsib = c.tail
		s.mems++ // o,u->lsib=t
		c.tail = u
	default: // u has just become large
		switch u {
		case c.tail:
			if u == c.small {
				return // keep it small, we're done anyway
			}
			c.tail = s.vi(u).lsib
			s.mems++ // o,t=u->lsib
		case c.small:
			c.small = s.vi(u).rsib
			s.mems++ // o,s=u->rsib
		default:
			s.vi(s.vi(u).rsib).lsib = s.vi(u).lsib
			s.mems += 3 // ooo,u->rsib->lsib=u->lsib
			s.vi(s.vi(u).lsib).rsib = s.vi(u).rsib
			s.mems++ // o,u->lsib->rsib=u->rsib
		}
		s.vi(u).rsib = c.largeList
		s.mems++ // o,u->rsib=large_list
		c.largeList = u
	}
}

// stage2 reduces the remaining loSqrt fragments to a dense matrix problem and
// finishes with Prim's algorithm.
func (c *ctk) stage2() int64 {
	s := c.s

	// Map all vertices to their index numbers.
	if c.small == nil {
		c.small = c.largeList
	} else {
		s.vi(c.tail).rsib = c.largeList
		s.mems++ // o,t->rsib=large_list
	}
	k := int64(0)
	for v := c.small; v != nil; {
		s.vi(v).findex = k
		s.mems++ // o,v->findex=k
		v = s.vi(v).rsib
		s.mems++ // o,v=v->rsib
		k++
	}
	n := s.g.N
	for vi := range n {
		v := &s.g.Vertices[vi]
		s.mems++ // o,v->comp
		if s.vi(v).comp != nil {
			t := s.vi(v).comp
			for {
				s.mems++ // o,t->comp
				if s.vi(t).comp == nil {
					break
				}
				t = s.vi(t).comp
			}
			fidx := s.vi(t).findex
			s.mems++ // o,k=t->findex
			for t := v; ; {
				u := s.vi(t).comp
				s.mems++ // o,u=t->comp
				if u == nil {
					break
				}
				s.vi(t).comp = nil
				s.mems++ // o,t->comp=NULL
				s.vi(t).findex = fidx
				s.mems++ // o,t->findex=k
				t = u
			}
		}
	}

	// Create the reduced matrix by running through all remaining edges.
	c.matx = make([]int64, c.loSqrt*c.loSqrt)
	c.matxArc = make([]*gbgraph.Arc, c.loSqrt*c.loSqrt)
	for j := int64(0); j < c.loSqrt; j++ {
		for k := int64(0); k < c.loSqrt; k++ {
			c.matx[j*c.loSqrt+k] = ctkINF
			s.mems++ // o,matx(j,k)=INF
		}
	}
	c.kk = 0
	for c.small != nil {
		s.qtraverse(s.vi(c.small).pq, c.noteEdge)
		c.small = s.vi(c.small).rsib
		s.mems++ // o,s=s->rsib
		c.kk++
	}

	return c.prim()
}

// noteEdge records edge a in the reduced matrix during stage 2.
func (c *ctk) noteEdge(a *gbgraph.Arc) {
	s := c.s
	k := s.vi(a.Tip).findex
	s.mems += 2 // oo,k=a->tip->findex
	if k == c.kk {
		return
	}
	s.mems += 2 // oo,a->len<matx(kk,k)
	if a.Len < c.matx[c.kk*c.loSqrt+k] {
		c.matx[c.kk*c.loSqrt+k] = a.Len
		s.mems++ // o,matx(kk,k)=a->len
		c.matx[k*c.loSqrt+c.kk] = a.Len
		s.mems++ // o,matx(k,kk)=a->len
		c.matxArc[c.kk*c.loSqrt+k] = a
		c.matxArc[k*c.loSqrt+c.kk] = a
	}
}

// prim runs Prim's algorithm on the reduced loSqrt×loSqrt matrix.
func (c *ctk) prim() int64 {
	s := c.s
	distance := make([]int64, c.loSqrt)
	distArc := make([]*gbgraph.Arc, c.loSqrt)

	distance[0] = -1
	s.mems++ // o,distance[0]=-1
	d := int64(ctkINF)
	var j int64
	for k := int64(1); k < c.loSqrt; k++ {
		distance[k] = c.matx[k] // matx(0,k)
		s.mems++                // o,distance[k]=matx(0,k)
		distArc[k] = c.matxArc[k]
		if distance[k] < d {
			d, j = distance[k], k
		}
	}
	for c.frags > 1 {
		if d == ctkINF {
			return infinity // the graph isn't connected
		}
		distance[j] = -1
		s.mems++ // o,distance[j]=-1
		c.totLen += d
		if s.trace != nil {
			c.reportEdge(distArc[j])
		}
		c.frags--
		d = ctkINF
		for k := int64(1); k < c.loSqrt; k++ {
			s.mems++ // o,distance[k]>=0
			if distance[k] >= 0 {
				s.mems++ // o,matx(j,k)<distance[k]
				if c.matx[j*c.loSqrt+k] < distance[k] {
					distance[k] = c.matx[j*c.loSqrt+k]
					s.mems++ // o,distance[k]=matx(j,k)
					distArc[k] = c.matxArc[j*c.loSqrt+k]
				}
				if distance[k] < d {
					d, c.kk = distance[k], k
				}
			}
		}
		j = c.kk
	}
	return c.totLen
}
