// This is a short demonstration of how to generate and traverse graphs
// with the Stanford GraphBase. It creates a graph with 12 vertices,
// representing the cells of a 3x4 rectangular board; two
// cells are considered adjacent if you can get from one to another
// by a queen move. Then it prints a description of the vertices and
// their neighbors, on the standard output file.

// An ASCII file called queen.gb is also produced. Other programs
// can obtain a copy of the queen graph by calling gbsave.SaveGraph(g,"queen.gb").
// You might find it interesting to compare the output of QUEEN with
// the contents of queen.gb; the former is intended to be readable
// by human beings, the latter by computers.
package main

import (
	"flag"
	"fmt"
	"os"
	"slices"

	gbbasic "github.com/sjnam/go-sgb/gb-basic"
	gbsave "github.com/sjnam/go-sgb/gb-save"
)

func main() {
	pWrap := flag.Bool("w", false, "a bool")
	flag.Parse()

	wrap := int64(0)
	gbName, cylind := "queen.gb", ""

	if *pWrap {
		// we set wrap=2 because only the second coordinate wraps
		wrap = int64(2)
		gbName = "queen_wrap.gb"
		cylind = "Cylindrical "
	}

	// a graph with rook moves and wrapping if wrap=2
	g, err := gbbasic.Board(3, 4, 0, 0, -1, wrap, false)
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"Sorry, I couldn't build a board g (%v)!\n", err)
		os.Exit(1)
	}
	// a graph with bishop moves and wrapping if wrap=2
	gg, err := gbbasic.Board(3, 4, 0, 0, -2, wrap, false)
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"Sorry, I couldn't build a board gg (%v)!\n", err)
		os.Exit(1)
	}
	// a graph with queen moves
	ggg, err := gbbasic.Gunion(g, gg, false, false)
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"Sorry, I couldn't build a gunion (%v)!\n", err)
		os.Exit(1)
	}
	// generate an ASCII file for ggg
	if _, err = gbsave.SaveGraph(ggg, gbName); err != nil {
		fmt.Fprintf(os.Stderr,
			"Sorry, I couldn't save a graph (%v)!\n", err)
		os.Exit(1)
	}

	// print the vertices and edges of ggg
	fmt.Printf("Queen Moves on a %s3x4 Board\n\n", cylind)
	fmt.Printf("  The graph whose official name is\n%s\n", ggg.ID)
	fmt.Printf("  has %d vertices and %d arcs:\n\n", ggg.N, ggg.M)
	for v := range slices.Values(ggg.Vertices[:ggg.N]) {
		fmt.Printf("%s\n", v.Name)
		for a := range v.AllArcs() {
			fmt.Printf(" -> %s, length %d\n", a.Tip.Name, a.Len)
		}
	}
}
