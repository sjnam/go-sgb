// Command econ_order permutes the sectors of a GB_ECON input/output matrix into
// a near-triangular order: early sectors tend to be primary-material producers,
// late sectors tend to be final-product industries.
//
// It minimizes the sum of the below-diagonal entries (the "feed-forward") with
// a local-search heuristic — starting from a random permutation and repeatedly
// moving a single sector to the position that best improves the score, keeping
// the relative order of the others. By default it uses A. M. Gleason's cautious
// descent (the least positive improvement each step); -g switches to greedy
// steepest descent (the largest improvement).
//
// Usage: econ_order [-nN] [-rN] [-sN] [-tN] [-g] [-v] [-V] [-DDIR]
//
//	-nN     number of sectors (default 79, the maximum)
//	-rN     try N random starting permutations (default 1)
//	-sN     seed for econ's sector combination (default 0)
//	-tN     seed for the random initial permutations (default 0)
//	-g      greedy/steepest descent instead of cautious descent
//	-v      verbose: report the score after every step
//	-V      very verbose: also show each permutation and move
//	-DDIR   data directory containing econ.dat (default "data/")
//
// This is a Go port of Knuth's ECON_ORDER demo from the Stanford GraphBase.
package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	gbecon "github.com/sjnam/go-sgb/gb-econ"
	gbflip "github.com/sjnam/go-sgb/gb-flip"
	gbgraph "github.com/sjnam/go-sgb/gb-graph"
	gbio "github.com/sjnam/go-sgb/gb-io"
)

// inf stands in for "infinity (or darn near)".
const inf = int64(0x7fffffff)

// maxN is the largest number of sectors econ(n,2,...) can return (79).
const maxN = 79

func main() {
	n := int64(79)
	r := int64(1)
	var s, t int64
	greedy := false
	verbose := 0
	dataDir := "data/"

	for _, arg := range os.Args[1:] {
		switch {
		case strings.HasPrefix(arg, "-n"):
			n = parseArg(arg)
		case strings.HasPrefix(arg, "-r"):
			r = parseArg(arg)
		case strings.HasPrefix(arg, "-s"):
			s = parseArg(arg)
		case strings.HasPrefix(arg, "-t"):
			t = parseArg(arg)
		case arg == "-v":
			verbose = 1
		case arg == "-V":
			verbose = 2
		case arg == "-g":
			greedy = true
		case strings.HasPrefix(arg, "-D"):
			dataDir = arg[2:]
		default:
			usage()
		}
	}

	gbio.DataDirectory = dataDir
	g, err := gbecon.Econ(n, 2, 0, s)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Sorry, can't create the matrix! (error code %v)\n", err)
		os.Exit(1)
	}
	n = g.N

	fmt.Printf("Ordering the sectors of %s, using seed %d:\n", g.ID, t)
	method := "Cautious"
	if greedy {
		method = "Steepest"
	}
	fmt.Printf(" (%s descent method)\n", method)

	// Put the graph data into matrix form.  mat[j][k] is the product flow from
	// sector j to sector k; del[j][k] = mat[j][k] - mat[k][j] is all the descent
	// actually needs (subtracting a constant from mat[j][k] and mat[k][j] leaves
	// the optimum permutation unchanged).
	var mat, del [maxN][maxN]int64
	for vi := range n {
		v := &g.Vertices[vi]
		for a := v.Arcs; a != nil; a = a.Next {
			mat[vi][gbgraph.VertexIndex(g, a.Tip)] = gbecon.Flow(a)
		}
	}
	for j := range n {
		for k := range n {
			del[j][k] = mat[j][k] - mat[k][j]
		}
	}

	// An obvious lower bound from the constraints x[j][k] + x[k][j] = 1.
	var sum int64
	for j := int64(1); j < n; j++ {
		for k := range j {
			if mat[j][k] <= mat[k][j] {
				sum += mat[j][k]
			} else {
				sum += mat[k][j]
			}
		}
	}
	fmt.Printf("(The amount of feed-forward must be at least %d.)\n", sum)

	rng := gbflip.New(t)
	bestScore := inf
	for ; r > 0; r-- {
		bestScore = descend(g, n, &mat, &del, rng, greedy, verbose, bestScore)
	}
}

// descend runs one local search from a fresh random permutation and reports the
// resulting locally optimal feed-forward.  It returns the best score seen so far
// across repetitions (used to label later runs and to decide when to print the
// ordering).
func descend(g *gbgraph.Graph, n int64, mat, del *[maxN][maxN]int64,
	rng *gbflip.RNG, greedy bool, verbose int, bestScore int64) int64 {

	// The sector in row/column k is g.Vertices[mapping[k]].
	var mapping [maxN]int64
	var score, steps int64

	// Initialize mapping to a random permutation (inside-out Fisher–Yates).
	for k := range n {
		j := rng.Unif(k + 1)
		mapping[k] = mapping[j]
		mapping[j] = k
	}
	for j := int64(1); j < n; j++ {
		for k := range j {
			score += mat[mapping[j]][mapping[k]]
		}
	}
	if verbose > 1 {
		fmt.Println("\nInitial permutation:")
		for k := range n {
			fmt.Printf(" %s\n", g.Vertices[mapping[k]].Name)
		}
	}

	for {
		// Find the move (shift sector best_k to position best_j) that improves
		// the score by the least positive amount (cautious) or the most
		// (greedy).  There are (n-1)^2 possible moves.
		bestD := inf
		if greedy {
			bestD = 0
		}
		bestK := int64(-1)
		var bestJ int64
		for k := range n {
			d := int64(0)
			for j := k - 1; j >= 0; j-- {
				d += del[mapping[k]][mapping[j]]
				if d > 0 && (greedy && d > bestD || !greedy && d < bestD) {
					bestK, bestJ, bestD = k, j, d
				}
			}
			d = 0
			for j := k + 1; j < n; j++ {
				d += del[mapping[j]][mapping[k]]
				if d > 0 && (greedy && d > bestD || !greedy && d < bestD) {
					bestK, bestJ, bestD = k, j, d
				}
			}
		}
		if bestK < 0 {
			break // local optimum
		}

		if verbose >= 1 {
			fmt.Printf("%8d after step %d\n", score, steps)
		} else if steps%1000 == 0 && steps > 0 {
			fmt.Print(".") // progress report
		}

		// Take the step: slide mapping[best_k] to position best_j, shifting the
		// intervening entries by one.
		if verbose > 1 {
			dir := "right"
			if bestJ < bestK {
				dir = "left"
			}
			fmt.Printf("Now move %s to the %s, past\n", g.Vertices[mapping[bestK]].Name, dir)
		}
		j := bestK
		k := mapping[j]
		for {
			if bestJ < bestK {
				mapping[j] = mapping[j-1]
				j--
			} else {
				mapping[j] = mapping[j+1]
				j++
			}
			if verbose > 1 {
				var dv int64
				if bestJ < bestK {
					dv = del[mapping[j+1]][k]
				} else {
					dv = del[k][mapping[j-1]]
				}
				fmt.Printf("    %s (%d)\n", g.Vertices[mapping[j]].Name, dv)
			}
			if j == bestJ {
				break
			}
		}
		mapping[j] = k
		score -= bestD
		steps++
	}

	label := "Local minimum feed-forward"
	if bestScore != inf {
		label = "Another local minimum"
	}
	plural := "s"
	if steps == 1 {
		plural = ""
	}
	fmt.Printf("\n%s is %d, found after %d step%s.\n", label, score, steps, plural)
	if verbose >= 1 || score < bestScore {
		fmt.Println("The corresponding economic order is:")
		for k := range n {
			fmt.Printf(" %s\n", g.Vertices[mapping[k]].Name)
		}
		if score < bestScore {
			bestScore = score
		}
	}
	return bestScore
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
		"Usage: %s [-nN][-rN][-sN][-tN][-g][-v][-V][-DDIR]\n", os.Args[0])
	os.Exit(2)
}
