// Command girth computes the girth and diameter of Ramanujan graphs produced
// by the GB_RAMAN module.
//
// The girth of a graph is the length of its shortest cycle; the diameter is the
// maximum length of a shortest path between two vertices.  The program prompts
// interactively for two distinct primes p and q (with q > 2), builds the
// (p+1)-regular Ramanujan graph raman(p,q), prints theoretical bounds on its
// girth and diameter, and then computes the exact values by breadth-first
// search.  Because these graphs are vertex-transitive, the search may start at
// any single vertex.
//
// If p = 2, q must have the form 104k + (1,3,9,17,25,27,35,43,49,51,75,81);
// the only small feasible values are q = 3, 17, and 43.  For example,
// raman(2,43) has 79464 vertices, girth 20, and diameter 22.
//
// Usage: girth   (then answer the prompts; empty input or EOF exits)
//
// This is a Go port of Knuth's GIRTH demo from the Stanford GraphBase.
package main

import (
	"bufio"
	"fmt"
	"os"

	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbraman"
)

func main() {
	fmt.Println("This program explores the girth and diameter of Ramanujan graphs.")
	fmt.Println("The bipartite graphs have q^3-q vertices, and the non-bipartite")
	fmt.Println("graphs have half that number. Each vertex has degree p+1.")
	fmt.Println("Both p and q should be odd prime numbers;")
	fmt.Println("  or you can try p = 2 with q = 17 or 43.")

	r := bufio.NewReader(os.Stdin)
	for {
		p, ok := promptInt(r, "\nChoose a branching factor, p: ")
		if !ok {
			break
		}
		q, ok := promptInt(r, "OK, now choose the cube root of graph size, q: ")
		if !ok {
			break
		}
		g, err := gbraman.Raman(p, q, 0, false)
		if err != nil {
			fmt.Printf(" Sorry, I couldn't make that graph (%v).\n", err)
			continue
		}
		printBounds(p, q, g.N)
		computeGirthDiameter(g)
		g.Recycle()
	}
}

// promptInt prints msg and reads one integer from r, mimicking the original's
// prompt/fgets/sscanf behavior: it returns ok=false on EOF or on input that
// does not begin with a number, which ends the program.
func promptInt(r *bufio.Reader, msg string) (int64, bool) {
	fmt.Print(msg)
	line, err := r.ReadString('\n')
	if err != nil && line == "" {
		return 0, false
	}
	var v int64
	if _, e := fmt.Sscanf(line, "%d", &v); e != nil {
		return 0, false
	}
	return v, true
}

// --- Theoretical bounds ---

// printBounds prints the bounds that the theory of Ramanujan graphs predicts
// for a graph of n vertices with degree p+1.
func printBounds(p, q, n int64) {
	bipartite := n == (q+1)*q*(q-1)
	which := "not "
	if bipartite {
		which = ""
	}
	fmt.Printf("The graph has %d vertices, each of degree %d, and it is %sbipartite.\n",
		n, p+1, which)

	gu, dl := trivialBounds(p, n)
	fmt.Printf("Any such graph must have diameter >= %d and girth <= %d;\n", dl, gu)

	du := diameterUpperBound(p, n, bipartite)
	fmt.Printf("theoretical considerations tell us that this one's diameter is <= %d", du)
	if p == 2 {
		fmt.Printf(".\n")
	} else {
		gl := girthLowerBound(p, q, bipartite)
		fmt.Printf(",\nand its girth is >= %d.\n", gl)
	}
}

// trivialBounds returns an upper bound gu on the girth and a lower bound dl on
// the diameter, valid for any n-vertex regular graph of degree p+1.  A graph
// has at most (p+1)p^(k-1) vertices at distance k from a given vertex.
func trivialBounds(p, n int64) (gu, dl int64) {
	s := p + 2 // s = 1 + (p+1) + (p+1)p + ... + (p+1)p^dl
	dl = 1
	pp := p // pp = p^dl
	gu = 3
	for s < n {
		s += pp
		if s <= n {
			gu++
		}
		dl++
		pp *= p
		s += pp
		if s <= n {
			gu++
		}
	}
	return
}

// diameterUpperBound returns the bound du derived by Lubotzky, Phillips, and
// Sarnak: p^((d-1)/2) < 2n in the nonbipartite case, p^((d-2)/2) < n in the
// bipartite case.
func diameterUpperBound(p, n int64, bipartite bool) int64 {
	nn := 2 * n
	if bipartite {
		nn = n
	}
	var du, pp int64
	for du, pp = 0, 1; pp < nn; du, pp = du+2, pp*p {
	}

	// Decrease du by 1 if pp/nn >= sqrt(p).  We compare nn/pp to sqrt(p) with
	// an all-integer continued-fraction method (Euclid-like) to avoid the
	// inaccuracy of floating point.
	qq := pp / nn
	if qq*qq > p {
		du--
	} else if (qq+1)*(qq+1) > p { // qq = floor(sqrt p)
		aa, bb, parity := qq, p-qq*qq, int64(0)
		pp -= qq * nn
		for {
			x := (aa + qq) / bb
			y := nn - x*pp
			if y <= 0 {
				break
			}
			aa = bb*x - aa // now 0 < aa < sqrt p
			bb = (p - aa*aa) / bb
			nn, pp = pp, y
			parity ^= 1
		}
		if parity == 0 {
			du--
		}
	}
	if bipartite {
		du++
	}
	return du
}

// girthLowerBound returns the bound gl on the girth derived from the theory of
// integral quaternions (valid when p > 2).
func girthLowerBound(p, q int64, bipartite bool) int64 {
	var gl, pp int64
	if bipartite {
		b := q * q
		for gl, pp = 1, p; pp <= b; gl, pp = gl+1, pp*p { // until p^g > q^2
		}
		gl += gl
	} else {
		b1, b2 := 1+4*q*q, 4+3*q*q // bounds on p^g
		for gl, pp = 1, p; pp < b1; gl, pp = gl+1, pp*p {
			if pp >= b2 && gl&1 != 0 && p&2 != 0 {
				break
			}
		}
	}
	return gl
}

// --- Breadth-first search ---

// computeGirthDiameter finds the exact girth and diameter of g by a
// breadth-first search from vertex 0, counting how many vertices lie at each
// distance and detecting the shortest cycle along the way.
//
// The original stores the BFS links, distances, and back-pointers in vertex
// utility fields; here they are parallel slices indexed by vertex number, which
// is the idiomatic Go equivalent.  A vertex is "unseen" while its link is -1;
// each level's list terminates at the sentinel value n.
func computeGirthDiameter(g *gbgraph.Graph) {
	const unseen = -1
	n := g.N
	sentinel := int(n)

	link := make([]int, n)   // next vertex in this level's list (sentinel ends it)
	dist := make([]int64, n) // distance from the start vertex
	back := make([]int, n)   // a vertex one step closer (-1 if none)
	for i := range link {
		link[i] = unseen
		back[i] = -1
	}

	girth := int64(999) // length of smallest cycle found, initially "infinite"
	k := int64(0)       // current distance being generated
	link[0] = sentinel  // vertex 0 is the only one seen so far
	uHead := 0          // head of the list for the next distance
	c := int64(1)       // how many vertices are at the current distance

	fmt.Println("Starting at any given vertex, there are")
	for c != 0 {
		vIdx := uHead
		uHead = sentinel
		c = 0
		k++
		for vIdx != sentinel {
			v := &g.Vertices[vIdx]
			for a := v.Arcs; a != nil; a = a.Next {
				wIdx := int(gbgraph.VertexIndex(g, a.Tip))
				if link[wIdx] == unseen {
					link[wIdx] = uHead
					dist[wIdx] = k
					back[wIdx] = vIdx
					uHead = wIdx
					c++
				} else if dist[wIdx]+k < girth && wIdx != back[vIdx] {
					girth = dist[wIdx] + k
				}
			}
			vIdx = link[vIdx]
		}
		sep := "."
		if c > 0 {
			sep = ","
		}
		fmt.Printf("%8d vertices at distance %d%s\n", c, k, sep)
	}
	fmt.Printf("So the diameter is %d, and the girth is %d.\n", k-1, girth)
}
