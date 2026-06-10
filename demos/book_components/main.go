// Command book_components computes the biconnected components of character-
// encounter graphs derived from classic literature, using the Hopcroft-Tarjan
// algorithm.
//
// Usage: book_components [options]
//
//	-tTITLE  book title: anna, david, jean, huck, homer (default "anna")
//	-nN      limit to N most prominent characters (0 = all)
//	-xN      exclude N major characters
//	-fN      first chapter to include (0 = 1)
//	-lN      last chapter to include (0 = all)
//	-iN      weight for appearances in selected chapters (default 1)
//	-oN      weight for appearances outside selected chapters (default 1)
//	-sN      random seed (default 0)
//	-v       verbose: print cast of characters
//	-V       very verbose: print cast with weights
//	-gFILE   restore graph from FILE (overrides all other options)
//	-dDIR    data directory (default "data/")
//
// This is a Go port of Knuth's BOOK_COMPONENTS demo from Stanford GraphBase.
package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/sjnam/go-sgb/books"
	"github.com/sjnam/go-sgb/graph"
	gbio "github.com/sjnam/go-sgb/io"
	"github.com/sjnam/go-sgb/save"
)

var (
	verbose  int
	filename string
	dataDir  = "data/"
)

func main() {
	title := "anna"
	var n, x, f, l uint64
	inWeight, outWeight, seed := int64(1), int64(1), int64(0)

	for _, arg := range os.Args[1:] {
		switch {
		case strings.HasPrefix(arg, "-t"):
			title = arg[2:]
		case strings.HasPrefix(arg, "-n"):
			v, err := strconv.ParseUint(arg[2:], 10, 64)
			if err != nil {
				usage()
			}
			n = v
		case strings.HasPrefix(arg, "-x"):
			v, err := strconv.ParseUint(arg[2:], 10, 64)
			if err != nil {
				usage()
			}
			x = v
		case strings.HasPrefix(arg, "-f"):
			v, err := strconv.ParseUint(arg[2:], 10, 64)
			if err != nil {
				usage()
			}
			f = v
		case strings.HasPrefix(arg, "-l"):
			v, err := strconv.ParseUint(arg[2:], 10, 64)
			if err != nil {
				usage()
			}
			l = v
		case strings.HasPrefix(arg, "-i"):
			v, err := strconv.ParseInt(arg[2:], 10, 64)
			if err != nil {
				usage()
			}
			inWeight = v
		case strings.HasPrefix(arg, "-o"):
			v, err := strconv.ParseInt(arg[2:], 10, 64)
			if err != nil {
				usage()
			}
			outWeight = v
		case strings.HasPrefix(arg, "-s"):
			v, err := strconv.ParseInt(arg[2:], 10, 64)
			if err != nil {
				usage()
			}
			seed = v
		case arg == "-v":
			verbose = 1
		case arg == "-V":
			verbose = 2
		case strings.HasPrefix(arg, "-g"):
			filename = arg[2:]
		case strings.HasPrefix(arg, "-d"):
			dataDir = arg[2:]
		default:
			usage()
		}
	}
	if filename != "" {
		verbose = 0
	}
	gbio.DataDirectory = dataDir

	var g *graph.Graph
	if filename != "" {
		var err error
		g, err = save.RestoreGraph(filename)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Sorry, can't restore the graph (%v)!\n", err)
			os.Exit(1)
		}
	} else {
		var err error
		g, err = books.Book(title, int64(n), int64(x), int64(f), int64(l), inWeight, outWeight, seed)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Sorry, can't create the graph (%v)!\n", err)
			os.Exit(1)
		}
	}

	fmt.Printf("Biconnectivity analysis of %s\n\n", g.ID)

	if verbose > 0 {
		printCast(g, inWeight, outWeight)
	}

	biconnect(g)
}

// vertexName returns the two-letter short code for book graphs, or the full
// vertex name for externally restored graphs.
func vertexName(v *graph.Vertex) string {
	if filename != "" {
		return v.Name
	}
	sc := books.ShortCode(v)
	return string([]byte{gbio.ImapChr(sc / 36), gbio.ImapChr(sc % 36)})
}

func printCast(g *graph.Graph, inWeight, outWeight int64) {
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		if verbose == 1 {
			fmt.Printf("%s=%s\n", vertexName(v), v.Name)
		} else {
			fmt.Printf("%s=%s, %s [weight %d]\n",
				vertexName(v), v.Name, books.Desc(v),
				inWeight*books.InCount(v)+outWeight*books.OutCount(v))
		}
	}
	fmt.Println()
}

// biconnect runs the Hopcroft-Tarjan algorithm on g, reporting biconnected
// components, articulation points, and connected-component boundaries.
//
// All algorithm state is kept in local slices indexed by vertex position —
// none of the graph's utility fields are touched.
func biconnect(g *graph.Graph) {
	n := int(g.N)
	if n == 0 {
		return
	}

	// Map vertex pointer → slice index for O(1) arc-tip lookup.
	idx := make(map[*graph.Vertex]int, n)
	for i := range g.Vertices[:n] {
		idx[&g.Vertices[i]] = i
	}

	// Per-vertex DFS state.
	//   rank[i]     — visit order (0 = unseen)
	//   parent[i]   — index of tree parent (-1 for DFS roots)
	//   untagged[i] — next unexamined arc from i
	//   minV[i]     — lowest-rank vertex reachable via a non-tree arc (-1 = dummy)
	//   depth[i]    — position in active stack when i was pushed
	const noVertex = -1
	rank := make([]int64, n)
	parent := make([]int, n)
	untagged := make([]*graph.Arc, n)
	minV := make([]int, n)
	depth := make([]int, n)

	for i := range untagged {
		untagged[i] = g.Vertices[i].Arcs
		parent[i] = noVertex
		minV[i] = noVertex
	}

	// rankOf returns the DFS rank of vertex i, treating noVertex as rank 0
	// (the dummy ancestor that all DFS roots report as parent).
	rankOf := func(i int) int64 {
		if i < 0 {
			return 0
		}
		return rank[i]
	}

	var (
		stack   []int // active vertices, bottom-to-top order; top = last element
		articPt = noVertex
		nn      int64
	)

	// push makes vertex vi active, recording its DFS rank and stack position.
	push := func(vi, par int) {
		nn++
		rank[vi] = nn
		parent[vi] = par
		minV[vi] = par
		depth[vi] = len(stack)
		stack = append(stack, vi)
	}

	// settle pops vertex vi and its active descendants off the stack and
	// reports them as a biconnected component.  u is vi's parent (-1 if vi
	// is a DFS root, signalling the end of a connected component).
	settle := func(vi, u int) {
		pos := depth[vi]
		desc := stack[pos+1:] // descendants of vi still on the stack

		if u == noVertex {
			if articPt != noVertex {
				fmt.Printf(" and %s (this ends a connected component of the graph)\n",
					vertexName(&g.Vertices[articPt]))
			} else {
				fmt.Printf("Isolated vertex %s\n", vertexName(&g.Vertices[vi]))
			}
			stack = stack[:pos]
			articPt = noVertex
			return
		}

		if articPt != noVertex {
			fmt.Printf(" and articulation point %s\n", vertexName(&g.Vertices[articPt]))
		}

		fmt.Printf("Bicomponent %s", vertexName(&g.Vertices[vi]))
		if len(desc) == 0 {
			fmt.Println()
		} else {
			fmt.Println(" also includes:")
			// Print from highest rank (top of stack) down to lowest.
			for j := len(desc) - 1; j >= 0; j-- {
				t := desc[j]
				fmt.Printf(" %s (from %s; ..to %s)\n",
					vertexName(&g.Vertices[t]),
					vertexName(&g.Vertices[parent[t]]),
					vertexName(&g.Vertices[minV[t]]))
			}
		}

		stack = stack[:pos]
		articPt = u
	}

	for vi := 0; vi < n; vi++ {
		if rank[vi] != 0 {
			continue
		}
		push(vi, noVertex)
		cur := vi

		for cur != noVertex {
			a := untagged[cur]
			if a != nil {
				ui := idx[a.Tip]
				untagged[cur] = a.Next // tag this arc
				if rank[ui] != 0 {     // non-tree arc: maybe update min
					if rankOf(ui) < rankOf(minV[cur]) {
						minV[cur] = ui
					}
				} else { // tree arc: descend into ui
					push(ui, cur)
					cur = ui
				}
			} else {
				// All arcs from cur are tagged; cur matures, backtrack to parent.
				u := parent[cur]
				if minV[cur] == u {
					settle(cur, u)
				} else if rankOf(minV[cur]) < rankOf(minV[u]) {
					minV[u] = minV[cur]
				}
				cur = u
			}
		}
	}
}

func usage() {
	fmt.Fprintf(os.Stderr,
		"Usage: %s [-tTITLE][-nN][-xN][-fN][-lN][-iN][-oN][-sN][-v][-V][-gFILE][-dDIR]\n",
		os.Args[0])
	os.Exit(2)
}
