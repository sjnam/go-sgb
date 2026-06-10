// Command ladders finds shortest word ladders between five-letter English words.
//
// Usage: ladders [options]
//
//	-v       verbose: print words visited during shortest-path computation
//	-a       alphabetic distance (sum of letter differences per position)
//	-f       frequency-based distance (common words are cheap)
//	-h       A*-style lower-bound heuristic to focus the search
//	-e       echo input to output (useful when reading from a file)
//	-nN      limit graph to the N most common words
//	-rN      limit graph to N randomly selected words
//	-sN      random seed N (default 0)
//	-dDIR    data directory containing words.dat (default "data/")
//
// This is a Go port of Knuth's LADDERS demo from Stanford GraphBase.
package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"unicode"

	"github.com/sjnam/go-sgb/dijk"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/graph"
	"github.com/sjnam/go-sgb/words"
)

var (
	verbose bool
	alph    bool
	freq    bool
	heur    bool
	echo    bool
	n       uint64
	randm   bool
	seed    int64
	dataDir string = "data/"
)

func main() {
	// Parse command-line arguments (C-style: flags may be in any order).
	for _, arg := range os.Args[1:] {
		switch {
		case arg == "-v":
			verbose = true
		case arg == "-a":
			alph = true
		case arg == "-f":
			freq = true
		case arg == "-h":
			heur = true
		case arg == "-e":
			echo = true
		case strings.HasPrefix(arg, "-n"):
			v, err := strconv.ParseUint(arg[2:], 10, 64)
			if err != nil {
				usage()
			}
			n, randm = v, false
		case strings.HasPrefix(arg, "-r"):
			v, err := strconv.ParseUint(arg[2:], 10, 64)
			if err != nil {
				usage()
			}
			n, randm = v, true
		case strings.HasPrefix(arg, "-s"):
			v, err := strconv.ParseInt(arg[2:], 10, 64)
			if err != nil {
				usage()
			}
			seed = v
		case strings.HasPrefix(arg, "-d"):
			dataDir = arg[2:]
		default:
			usage()
		}
	}
	if alph || randm {
		freq = false
	}
	if freq {
		heur = false
	}

	gbio.DataDirectory = dataDir

	// Build word graph.
	var wtVec []int64
	if randm {
		wtVec = make([]int64, 9) // zero_vector: ignore frequency information
	}
	g, wordIx, err := words.Words(int64(n), wtVec, 0, seed)
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"Sorry, I couldn't build a dictionary (%v)!\n", err)
		os.Exit(1)
	}

	if verbose {
		if alph {
			fmt.Println("(alphabetic distance selected)")
		}
		if freq {
			fmt.Println("(frequency-based distances selected)")
		}
		if heur {
			fmt.Println("(lowerbound heuristic will be used to focus the search)")
		}
		if randm {
			fmt.Printf("(random selection of %d words with seed %d)\n", g.N, seed)
		} else {
			fmt.Printf("(the graph has %d words)\n", g.N)
		}
	}

	// Modify edge lengths for -a or -f option.
	if alph {
		for i := int64(0); i < g.N; i++ {
			u := &g.Vertices[i]
			p := u.Name
			for a := u.Arcs; a != nil; a = a.Next {
				a.Len = alphDist(p, a.Tip.Name)
			}
		}
	} else if freq {
		for i := int64(0); i < g.N; i++ {
			u := &g.Vertices[i]
			for a := u.Arcs; a != nil; a = a.Next {
				a.Len = freqCost(a.Tip)
			}
		}
	}

	// Use the 128-bucket wheel when edge lengths are < 128.
	var q dijk.Queue
	if alph || freq || heur {
		q = dijk.NewWheelQueue()
	} else {
		q = dijk.NewDlistQueue()
	}

	reader := bufio.NewReader(os.Stdin)
	for {
		fmt.Println()

		start, ok := promptWord("Starting", reader)
		if !ok || start == "" {
			break
		}
		goal, ok := promptWord("    Goal", reader)
		if !ok {
			break
		}
		if goal == "" {
			continue
		}

		findLadder(g, wordIx, start, goal, q)
	}
}

// findLadder finds and prints the shortest word ladder from start to goal.
func findLadder(g *graph.Graph, wordIx *words.Index, start, goal string, q dijk.Queue) {
	savedN := g.N

	// Build an amplified graph gg that borrows g's vertices but has its own
	// arc storage for the temporary connections to start/goal.
	gg := graph.NewGraph(0)
	gg.Vertices = g.Vertices
	gg.N = g.N

	// plantNewEdge adds a temporary edge between the new vertex at gg.Vertices[gg.N]
	// and the existing vertex v.
	plantNewEdge := func(v *graph.Vertex) {
		u := &gg.Vertices[gg.N]
		gg.NewEdge(u, v, 1)
		if alph {
			d := alphDist(u.Name, v.Name)
			u.Arcs.Len = d
			v.Arcs.Len = d
		} else if freq {
			u.Arcs.Len = freqCost(v)
			v.Arcs.Len = 20 // entering an unknown word is expensive
		}
	}

	// Insert start word (use extra vertex slot if not already in dictionary).
	gg.Vertices[gg.N].Name = start
	uu := wordIx.FindWord(start, plantNewEdge)
	if uu == nil {
		uu = &gg.Vertices[gg.N]
		gg.N++
	}

	// Insert goal word.
	var vv *graph.Vertex
	if start == goal {
		vv = uu
	} else {
		gg.Vertices[gg.N].Name = goal
		vv = wordIx.FindWord(goal, plantNewEdge)
		if vv == nil {
			vv = &gg.Vertices[gg.N]
			gg.N++
		}
	}

	// If both words are new and adjacent, add a direct edge between them.
	if gg.N == savedN+2 && hammDist(start, goal) == 1 {
		gg.N-- // temporarily hide goal so plantNewEdge targets it
		plantNewEdge(uu)
		gg.N++
	}

	// Run Dijkstra.
	var trace io.Writer
	if verbose {
		trace = os.Stdout
	}
	var minDist int64
	switch {
	case !heur:
		minDist = dijk.Dijkstra(uu, vv, gg, nil, q, trace)
	case alph:
		minDist = dijk.Dijkstra(uu, vv, gg, func(v *graph.Vertex) int64 {
			return alphDist(v.Name, goal)
		}, q, trace)
	default:
		minDist = dijk.Dijkstra(uu, vv, gg, func(v *graph.Vertex) int64 {
			return hammDist(v.Name, goal)
		}, q, trace)
	}

	if minDist < 0 {
		fmt.Printf("Sorry, there's no ladder from %s to %s.\n", start, goal)
	} else {
		dijk.PrintDijkstraResult(os.Stdout, vv)
	}

	// Cleanup: remove back-arcs that were prepended to existing vertices,
	// then clear the temporary vertices. Process in reverse order so that
	// back-arcs are removed in LIFO order (matching the prepend order).
	for i := gg.N - 1; i >= savedN; i-- {
		u := &gg.Vertices[i]
		for a := u.Arcs; a != nil; a = a.Next {
			v := a.Tip
			v.Arcs = v.Arcs.Next // strip the front arc pointing back to u
		}
		u.Arcs = nil
	}
	gg.N = savedN
}

// promptWord displays a prompt and reads a five-lowercase-letter word from r.
// Returns ("", false) on EOF, ("", true) for blank line, (word, true) for a
// valid word.
func promptWord(prompt string, r *bufio.Reader) (string, bool) {
	for {
		fmt.Printf("%s word: ", prompt)
		line, err := r.ReadString('\n')
		if err != nil {
			return "", false // EOF
		}
		if echo {
			fmt.Print(line)
		}
		line = strings.TrimRight(line, "\r\n")
		if line == "" {
			return "", true
		}
		if len(line) == 5 && isAllLower(line) {
			return line, true
		}
		fmt.Println("(Please type five lowercase letters and RETURN.)")
	}
}

func isAllLower(s string) bool {
	for _, c := range s {
		if !unicode.IsLower(c) {
			return false
		}
	}
	return true
}

// freqCost returns the frequency cost of vertex v: 0 for very common words,
// 16 for words with zero frequency.
func freqCost(v *graph.Vertex) int64 {
	acc := words.Weight(v)
	k := int64(16)
	for acc != 0 {
		k--
		acc >>= 1
	}
	if k < 0 {
		return 0
	}
	return k
}

// alphDist returns the total alphabetic distance between two five-letter words.
func alphDist(p, q string) int64 {
	var d int64
	for i := 0; i < 5; i++ {
		diff := int64(p[i]) - int64(q[i])
		if diff < 0 {
			diff = -diff
		}
		d += diff
	}
	return d
}

// hammDist returns the Hamming distance between two five-letter words.
func hammDist(p, q string) int64 {
	var d int64
	for i := 0; i < 5; i++ {
		if p[i] != q[i] {
			d++
		}
	}
	return d
}

func usage() {
	fmt.Fprintf(os.Stderr,
		"Usage: %s [-v][-a][-f][-h][-e][-nN][-rN][-sN][-dDIR]\n",
		os.Args[0])
	os.Exit(2)
}
