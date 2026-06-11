// Command word_components computes connected components of the five-letter
// word graph, printing component statistics as each vertex is added.
//
// Usage: word_components [-dDIR]
//
//	-dDIR   data directory containing words.dat (default "data/")
//
// This is a Go port of Knuth's WORD_COMPONENTS demo from Stanford GraphBase.
package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/gbwords"
)

func main() {
	dataDir := "data/"
	for _, arg := range os.Args[1:] {
		if strings.HasPrefix(arg, "-d") {
			dataDir = arg[2:]
		} else {
			fmt.Fprintf(os.Stderr, "Usage: %s [-dDIR]\n", os.Args[0])
			os.Exit(2)
		}
	}
	gbio.DataDirectory = dataDir

	g, _, err := gbwords.Words(0, nil, 0, 0)
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"Sorry, can't build dictionary (%v)!\n", err)
		os.Exit(1)
	}

	n := int(g.N)

	// Map each vertex pointer to its slice index for O(1) arc-tip lookup.
	// This replaces the original's unsafe pointer arithmetic (a->tip > v).
	idx := make(map[*gbgraph.Vertex]int, n)
	for i := range g.Vertices[:n] {
		idx[&g.Vertices[i]] = i
	}

	// Component state stored in parallel arrays (not vertex utility fields).
	//   next[i]   = index of next vertex in i's circular component list
	//   master[i] = index of the component's representative vertex
	//   size[i]   = number of members (valid only when master[i] == i)
	next := make([]int, n)
	master := make([]int, n)
	size := make([]int64, n)

	var isol, comp, m int64
	fmt.Printf("Component analysis of %s\n", g.ID)

	for i := range n {
		v := &g.Vertices[i]

		// Initialize i as a singleton component.
		next[i], master[i], size[i] = i, i, 1
		isol++
		comp++

		fmt.Printf("%4d: %5d %s", i+1, gbwords.Weight(v), v.Name)

		// In the words graph, arcs to later vertices (higher index = lower weight)
		// appear before arcs to earlier vertices.  Skip the "future" arcs.
		a := v.Arcs
		for a != nil && idx[a.Tip] > i {
			a = a.Next
		}

		if a == nil {
			fmt.Print("[1]")
		} else {
			c := 0
			for ; a != nil; a = a.Next {
				j := idx[a.Tip]
				m++
				ui, wi := master[j], master[i]
				if ui == wi {
					continue
				}
				// Absorb the smaller component into the larger.
				if size[ui] < size[wi] {
					if c > 0 {
						sep := " with"
						if c > 1 {
							sep = ","
						}
						fmt.Printf("%s %s[%d]", sep, g.Vertices[ui].Name, size[ui])
					}
					c++
					size[wi] += size[ui]
					if size[ui] == 1 {
						isol--
					}
					for t := next[ui]; t != ui; t = next[t] {
						master[t] = wi
					}
					master[ui] = wi
				} else {
					if c > 0 {
						sep := " with"
						if c > 1 {
							sep = ","
						}
						fmt.Printf("%s %s[%d]", sep, g.Vertices[wi].Name, size[wi])
					}
					c++
					if size[ui] == 1 {
						isol--
					}
					size[ui] += size[wi]
					if size[wi] == 1 {
						isol--
					}
					for t := next[wi]; t != wi; t = next[t] {
						master[t] = ui
					}
					master[wi] = ui
				}
				// Splice the two circular lists into one.
				next[ui], next[wi] = next[wi], next[ui]
				comp--
			}
			fmt.Printf(" in %s[%d]", g.Vertices[master[i]].Name, size[master[i]])
		}

		fmt.Printf("; c=%d,i=%d,m=%d\n", comp, isol, m)
	}

	// Print all components that are neither isolated nor the giant component.
	fmt.Println("\nThe following non-isolated words didn't join the giant component:")
	for i := range n {
		if master[i] == i && size[i] > 1 && size[i]*2 < g.N {
			c := 1
			fmt.Print(g.Vertices[i].Name)
			for u := next[i]; u != i; u = next[u] {
				c++
				if c > 12 {
					fmt.Println()
					c = 1
				}
				fmt.Printf(" %s", g.Vertices[u].Name)
			}
			fmt.Println()
		}
	}
}
