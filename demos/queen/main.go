package main

import (
	"flag"
	"fmt"
	"os"
	"slices"

	"github.com/sjnam/go-sgb/gbbasic"
	"github.com/sjnam/go-sgb/gbsave"
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

	g, err := gbbasic.Board(3, 4, 0, 0, -1, wrap, false)
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"Sorry, I couldn't build a board g (%v)!\n", err)
		os.Exit(1)
	}
	gg, err := gbbasic.Board(3, 4, 0, 0, -2, wrap, false)
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"Sorry, I couldn't build a board gg (%v)!\n", err)
		os.Exit(1)
	}
	ggg, err := gbbasic.Gunion(g, gg, false, false)
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"Sorry, I couldn't build a gunion (%v)!\n", err)
		os.Exit(1)
	}
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
