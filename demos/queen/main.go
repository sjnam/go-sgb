package main

import (
	"fmt"
	"os"

	"github.com/sjnam/go-sgb/gbbasic"
)

func main() {
	g, err := gbbasic.Board(3, 4, 0, 0, -1, 0, false)
	if err != nil {
		panic(err)
	}
	gg, err := gbbasic.Board(3, 4, 0, 0, -2, 0, false)
	if err != nil {
		panic(err)
	}
	ggg, err := gbbasic.Gunion(g, gg, false, false)
	if err != nil {
		panic(err)
	}

	if ggg == nil {
		fmt.Fprintf(os.Stderr, "Something went wrong %s", err)
		return
	}

	fmt.Print("Queen Moves on a 3x4 Board\n\n")
	fmt.Printf("  The graph whose official name is\n%s\n", ggg.ID)
	fmt.Printf("  has %d vertices and %d arcs:\n\n", ggg.N, ggg.M)

	for _, v := range ggg.Vertices[:ggg.N] {
		fmt.Printf("%s\n", v.Name)
		for a := range v.AllArcs() {
			fmt.Printf(" -> %s, length %d\n", a.Tip.Name, a.Len)
		}
	}
}
