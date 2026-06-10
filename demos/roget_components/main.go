// Command roget_components computes strong components of the Roget thesaurus
// graph using Tarjan's iterative depth-first-search algorithm.
//
// Vertices in the same strong component can reach each other via directed
// paths. Components are printed in reverse topological order (sinks first).
// After all components, the program prints the links between them.
//
// Usage: roget_components [-nN] [-dN] [-pN] [-sN] [-gFILE] [-DDIR]
//
//	-nN      number of categories (0 = all 1022)
//	-dN      minimum |cat_i - cat_j| required for an arc (default 0)
//	-pN      rejection probability 65536*P (default 0)
//	-sN      random seed (default 0)
//	-gFILE   load graph from FILE instead of building roget(n,d,p,s)
//	-DDIR    data directory containing roget.dat (default "data/")
//
// This is a Go port of Knuth's ROGET_COMPONENTS demo from Stanford GraphBase.
package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/gbroget"
	"github.com/sjnam/go-sgb/gbsave"
)

func main() {
	var n, d, p, s int64
	var filename string
	dataDir := "data/"

	for _, arg := range os.Args[1:] {
		switch {
		case strings.HasPrefix(arg, "-n"):
			v, err := strconv.ParseInt(arg[2:], 10, 64)
			if err != nil {
				usage()
			}
			n = v
		case strings.HasPrefix(arg, "-d"):
			v, err := strconv.ParseInt(arg[2:], 10, 64)
			if err != nil {
				usage()
			}
			d = v
		case strings.HasPrefix(arg, "-p"):
			v, err := strconv.ParseInt(arg[2:], 10, 64)
			if err != nil {
				usage()
			}
			p = v
		case strings.HasPrefix(arg, "-s"):
			v, err := strconv.ParseInt(arg[2:], 10, 64)
			if err != nil {
				usage()
			}
			s = v
		case strings.HasPrefix(arg, "-g"):
			filename = arg[2:]
		case strings.HasPrefix(arg, "-D"):
			dataDir = arg[2:]
		default:
			usage()
		}
	}

	gbio.DataDirectory = dataDir

	var g *gbgraph.Graph
	if filename != "" {
		var err error
		g, err = gbsave.RestoreGraph(filename)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Sorry, can't restore the graph (%v)!\n", err)
			os.Exit(1)
		}
	} else {
		var err error
		g, err = gbroget.Roget(n, d, p, s)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Sorry, can't create the graph! (error code %v)\n", err)
			os.Exit(1)
		}
	}

	fmt.Printf("Reachability analysis of %s\n\n", g.ID)
	analyze(g, filename != "")
}

// analyze runs Tarjan's iterative SCC algorithm on g, printing each component
// and the links between them.  useIndex selects the vertex identifier: when
// true (external graph) vertices are numbered 1..N; when false (Roget graph)
// the original category number is used.
func analyze(g *gbgraph.Graph, useIndex bool) {
	nn := int(g.N)
	if nn == 0 {
		return
	}
	infinity := int64(nn) // sentinel rank for settled vertices

	// specs returns the (id, name) pair used in output for vertex v.
	specs := func(v *gbgraph.Vertex) (int64, string) {
		if useIndex {
			return gbgraph.VertexIndex(g, v) + 1, v.Name
		}
		return gbroget.CatNo(v), v.Name
	}

	// Map vertex pointer → slice index for O(1) arc-tip lookup.
	idx := make(map[*gbgraph.Vertex]int, nn)
	for i := range g.Vertices[:nn] {
		idx[&g.Vertices[i]] = i
	}

	// Parallel arrays replacing vertex utility fields (rank, parent, untagged,
	// link, min) — keeps g's fields untouched and avoids aliasing with
	// the roget package's cat_no stored in U.
	rank := make([]int64, nn) // 0 = unseen; infinity = settled
	parent := make([]int, nn) // DFS-tree parent index; -1 = root
	untagged := make([]*gbgraph.Arc, nn)
	link := make([]int, nn)    // stack linkage; -1 = bottom
	min := make([]int, nn)     // index of min-rank reachable vertex
	arcFrom := make([]int, nn) // inter-component arc deduplication

	for i := 0; i < nn; i++ {
		untagged[i] = g.Vertices[i].Arcs
		link[i] = -1
		parent[i] = -1
		min[i] = i
		arcFrom[i] = -1
	}

	var counter int64
	activeStack := -1
	settledStack := -1

	makeActive := func(vi int) {
		counter++
		rank[vi] = counter
		link[vi] = activeStack
		activeStack = vi
		min[vi] = vi
	}

	settleComponent := func(vi int) {
		t := activeStack
		activeStack = link[vi]
		link[vi] = settledStack
		settledStack = t

		v := &g.Vertices[vi]
		id, name := specs(v)
		fmt.Printf("Strong component `%d %s'", id, name)
		if t == vi {
			fmt.Println()
		} else {
			fmt.Println(" also includes:")
			for t != vi {
				tv := &g.Vertices[t]
				pv := &g.Vertices[parent[t]]
				mv := &g.Vertices[min[t]]
				tid, tname := specs(tv)
				pid, pname := specs(pv)
				mid, mname := specs(mv)
				fmt.Printf(" %d %s (from %d %s; ..to %d %s)\n",
					tid, tname, pid, pname, mid, mname)
				rank[t] = infinity
				parent[t] = vi // vi is now the component representative
				t = link[t]
			}
		}
		rank[vi] = infinity
		parent[vi] = vi
	}

	// Tarjan's algorithm: iterative DFS over all unseen vertices.
	for vi := 0; vi < nn; vi++ {
		if rank[vi] != 0 {
			continue
		}
		parent[vi] = -1
		makeActive(vi)
		cur := vi

		for cur >= 0 {
			a := untagged[cur]
			if a != nil {
				ui := idx[a.Tip]
				untagged[cur] = a.Next // tag this arc
				if rank[ui] != 0 {     // already seen
					if rank[ui] < rank[min[cur]] {
						min[cur] = ui
					}
				} else { // unseen: tree arc, descend
					parent[ui] = cur
					cur = ui
					makeActive(ui)
				}
			} else {
				// All arcs from cur are tagged; cur matures.
				u := parent[cur]
				if min[cur] == cur {
					settleComponent(cur)
				} else if u >= 0 && rank[min[cur]] < rank[min[u]] {
					min[u] = min[cur]
				}
				cur = u
			}
		}
	}

	// Print one representative arc for each inter-component edge.
	fmt.Println("\nLinks between components:")
	for v := settledStack; v >= 0; v = link[v] {
		u := parent[v] // component representative of v
		arcFrom[u] = u
		for a := g.Vertices[v].Arcs; a != nil; a = a.Next {
			w := parent[idx[a.Tip]] // component representative of arc target
			if arcFrom[w] != u {
				arcFrom[w] = u
				uid, uname := specs(&g.Vertices[u])
				wid, wname := specs(&g.Vertices[w])
				vid, vname := specs(&g.Vertices[v])
				tid, tname := specs(a.Tip)
				fmt.Printf("%d %s -> %d %s (e.g., %d %s -> %d %s)\n",
					uid, uname, wid, wname, vid, vname, tid, tname)
			}
		}
	}
}

func usage() {
	fmt.Fprintf(os.Stderr,
		"Usage: %s [-nN][-dN][-pN][-sN][-gFILE][-DDIR]\n", os.Args[0])
	os.Exit(2)
}
