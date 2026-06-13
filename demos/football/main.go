// Command football finds long score-differential chains between college
// football teams, using data from the 1990 season.
//
// The program prompts for a starting team and another team, then finds a
// chain showing one might outrank the other by accumulated score difference.
// Width=0 uses a simple greedy algorithm; larger widths use a stratified
// heuristic that tends to find better (longer) chains.
//
// Usage: football [searchwidth]
//
// This is a Go port of Knuth's FOOTBALL demo from Stanford GraphBase.
package main

import (
	"bufio"
	"fmt"
	"math/rand"
	"os"
	"strconv"
	"strings"

	gbgames "github.com/sjnam/go-sgb/gb-games"
	gbgraph "github.com/sjnam/go-sgb/gb-graph"
	"github.com/sjnam/go-sgb/gb-io"
)

// node represents one step in a chain from start to goal.
type node struct {
	game   *gbgraph.Arc
	totLen int64
	prev   *node
	next   *node // list link within a stratum
	vid    int64 // packed ID (mm<<8)+m, set when popped in verbose mode
}

func main() {
	width := int64(0)
	verbose := false

	args := os.Args[1:]
	if len(args) >= 2 && args[len(args)-1] == "-v" {
		verbose = true
		args = args[:len(args)-1]
	}
	switch len(args) {
	case 0:
	case 1:
		v, err := strconv.ParseInt(args[0], 10, 64)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Usage: %s [searchwidth]\n", os.Args[0])
			os.Exit(2)
		}
		if v < 0 {
			v = -v
		}
		width = v
	default:
		fmt.Fprintf(os.Stderr, "Usage: %s [searchwidth]\n", os.Args[0])
		os.Exit(2)
	}

	gbio.DataDirectory = "data/"
	g, err := gbgames.Games(0, 0, 0, 0, 0, 0, 0, 0)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Sorry, can't create the graph! (error code %v)\n", err)
		os.Exit(1)
	}

	del := computeDel(g)
	rng := rand.New(rand.NewSource(1))
	reader := bufio.NewReader(os.Stdin)

	for {
		fmt.Println()
		start, goal := promptPair(g, reader, rng)
		if start == nil {
			break
		}
		var curNode *node
		if width == 0 {
			curNode = greedyChain(g, del, start, goal)
		} else {
			curNode = stratifiedChain(g, del, start, goal, width, verbose)
		}
		printChain(start, goal, curNode, del)
	}
}

// computeDel builds a map from arc pointer to score differential.
// del[a] = a.Len - mate.Len, where mate is the reverse arc for the same game.
func computeDel(g *gbgraph.Graph) map[*gbgraph.Arc]int64 {
	del := make(map[*gbgraph.Arc]int64)
	for i := int64(0); i < g.N; i++ {
		u := &g.Vertices[i]
		for a := range u.AllArcs() {
			j := gbgraph.VertexIndex(g, a.Tip)
			if j > i {
				date := gbgames.Date(a)
				for b := range a.Tip.AllArcs() {
					if b.Tip == u && gbgames.Date(b) == date {
						del[a] = a.Len - b.Len
						del[b] = b.Len - a.Len
						break
					}
				}
			}
		}
	}
	return del
}

// promptPair prompts for start then goal, re-asking "Starting" only on empty
// "Other" or identical teams (matching original goto-restart logic).
func promptPair(g *gbgraph.Graph, r *bufio.Reader, rng *rand.Rand) (start, goal *gbgraph.Vertex) {
	for {
		start = promptForTeam("Starting", g, r, rng)
		if start == nil {
			return nil, nil
		}
		goal = promptForTeam("   Other", g, r, rng)
		if goal == nil {
			continue
		}
		if start == goal {
			fmt.Println(" (Um, please give me the names of two DISTINCT teams.)")
			continue
		}
		return start, goal
	}
}

// promptForTeam displays prompt and reads an exact team name.
// Returns nil when the user enters an empty line.
func promptForTeam(prompt string, g *gbgraph.Graph, r *bufio.Reader, rng *rand.Rand) *gbgraph.Vertex {
	for {
		fmt.Printf("%s team: ", prompt)
		line, err := r.ReadString('\n')
		if err != nil {
			return nil
		}
		name := strings.TrimRight(line, "\r\n")
		if len(name) > 29 {
			name = name[:29]
		}
		if name == "" {
			return nil
		}
		for i := int64(0); i < g.N; i++ {
			if g.Vertices[i].Name == name {
				return &g.Vertices[i]
			}
		}
		fmt.Println(" (Sorry, I don't know any team by that name.)")
		fmt.Printf(" (One team I do know is %s...)\n", g.Vertices[rng.Int63n(g.N)].Name)
	}
}

// greedyChain finds a long chain from start to goal using a greedy algorithm:
// at each step pick the arc with maximum del that still allows reaching goal.
func greedyChain(g *gbgraph.Graph, del map[*gbgraph.Arc]int64, start, goal *gbgraph.Vertex) *node {
	nn := int(g.N)
	idx := makeIdx(g, nn)
	blocked := make([]bool, nn)
	// valid[i] == cookie (cur vertex pointer) means vertex i can reach goal.
	valid := make([]*gbgraph.Vertex, nn)

	var curNode *node
	cur := start
	for cur != goal {
		blocked[idx[cur]] = true

		// Mark all non-blocked vertices reachable from goal via DFS.
		// The games graph has both arc directions for each game, so
		// "reachable from goal" = "can reach goal".
		cookie := cur
		stack := []*gbgraph.Vertex{goal}
		valid[idx[goal]] = cookie
		for len(stack) > 0 {
			u := stack[len(stack)-1]
			stack = stack[:len(stack)-1]
			for a := range u.AllArcs() {
				ti := idx[a.Tip]
				if !blocked[ti] && valid[ti] != cookie {
					valid[ti] = cookie
					stack = append(stack, a.Tip)
				}
			}
		}

		const sentinel = int64(-10000)
		d := sentinel
		var bestArc, lastArc *gbgraph.Arc
		for a := range cur.AllArcs() {
			if valid[idx[a.Tip]] != cookie {
				continue
			}
			if a.Tip == goal {
				lastArc = a
			} else if del[a] > d {
				bestArc = a
				d = del[a]
			}
		}

		chosen := bestArc
		if d == sentinel {
			chosen = lastArc
		}
		if chosen == nil {
			break
		}

		prevTot := int64(0)
		if curNode != nil {
			prevTot = curNode.totLen
		}
		curNode = &node{game: chosen, totLen: prevTot + del[chosen], prev: curNode}
		cur = chosen.Tip
	}
	return curNode
}

// stratifiedChain finds a longer chain using a stratified heuristic.
// It maintains up to `width` nodes per stratum, where h(x) counts vertices
// on simple paths between x's current position and goal (via bicomponents).
func stratifiedChain(g *gbgraph.Graph, del map[*gbgraph.Arc]int64, start, goal *gbgraph.Vertex, width int64, verbose bool) *node {
	nn := int(g.N)
	idx := makeIdx(g, nn)

	list := make([]*node, nn)
	size := make([]int64, nn)
	var mm int64 // verbose counter

	placeNode := func(x *node, h int64) {
		if h == 0 {
			if size[0] > 0 {
				if x.totLen <= list[0].totLen {
					return
				}
				list[0] = list[0].next
			} else {
				size[0]++
			}
		} else if size[h] == width {
			if x.totLen <= list[h].totLen {
				return
			}
			list[h] = list[h].next
		} else {
			size[h]++
		}
		var p, q *node
		for p = list[h]; p != nil && x.totLen > p.totLen; q, p = p, p.next {
		}
		x.next = p
		if q != nil {
			q.next = x
		} else {
			list[h] = x
		}
	}

	// bicompH computes h(u) for each vertex: the number of vertices on simple
	// paths between u and goal, excluding already-used vertices.
	// Returns a slice where hVal[i] = h value for vertex i, and
	// visited[i] = true if vertex i was reached in the DFS from goal.
	bicompH := func(curNode *node) (hVal []int64, visited []bool) {
		hVal = make([]int64, nn)
		visited = make([]bool, nn)

		// Bicomp DFS state.
		dfsRank := make([]int64, nn)
		dfsParent := make([]int, nn) // index; -1 = dummy (root parent)
		dfsMinV := make([]int, nn)   // index; -1 = dummy
		dfsLink := make([]int, nn)   // stack link; -1 = empty
		dfsUntagged := make([]*gbgraph.Arc, nn)

		for i := range dfsRank {
			dfsParent[i] = -1
			dfsMinV[i] = -1
			dfsLink[i] = -1
			dfsUntagged[i] = g.Vertices[i].Arcs
		}

		// Block already-used vertices.
		for x := curNode; x != nil; x = x.prev {
			dfsRank[idx[x.game.Tip]] = int64(nn)
		}
		dfsRank[idx[start]] = int64(nn)

		goalIdx := idx[goal]

		rankOf := func(vi int) int64 {
			if vi < 0 {
				return 0 // dummy rank = 0
			}
			return dfsRank[vi]
		}

		var activeStack, settledStack int = -1, -1
		var counter int64

		makeActive := func(vi, par int) {
			counter++
			dfsRank[vi] = counter
			dfsLink[vi] = activeStack
			activeStack = vi
			dfsParent[vi] = par
			dfsMinV[vi] = par // min starts as parent
		}

		makeActive(goalIdx, -1) // goal's parent is dummy (-1)
		cur := goalIdx

		for cur >= 0 {
			a := dfsUntagged[cur]
			if a != nil {
				ui := idx[a.Tip]
				dfsUntagged[cur] = a.Next
				if dfsRank[ui] != 0 {
					if rankOf(ui) < rankOf(dfsMinV[cur]) {
						dfsMinV[cur] = ui
					}
				} else {
					dfsParent[ui] = cur
					cur = ui
					makeActive(ui, dfsParent[ui])
				}
			} else {
				u := dfsParent[cur]
				if dfsMinV[cur] == u { // bicomponent found
					if cur != goalIdx {
						c := int64(0)
						t := activeStack
						for t != cur {
							c++
							dfsParent[t] = cur // t's rep is cur
							t = dfsLink[t]
						}
						activeStack = dfsLink[cur]
						dfsParent[cur] = cur         // self = representative
						dfsRank[cur] = c + int64(nn) // encode size
						dfsLink[cur] = settledStack
						settledStack = cur
					}
				} else {
					if rankOf(dfsMinV[cur]) < rankOf(dfsMinV[u]) {
						dfsMinV[u] = dfsMinV[cur]
					}
				}
				cur = u
			}
		}

		// rankAcc[vi] = accumulated reachability count for bicomp rep vi.
		rankAcc := make([]int64, nn)
		// dummy (-1) contributes 0.

		for v := settledStack; v >= 0; v = dfsLink[v] {
			// dfsMinV[v] = articulation point u linking this bicomp to its parent.
			u := dfsMinV[v]
			// bicomp rep of u:
			repU := -1
			if u >= 0 {
				repU = dfsParent[u]
			}
			parentAcc := int64(0)
			if repU >= 0 {
				parentAcc = rankAcc[repU]
			}
			c := dfsRank[v] - int64(nn) // non-rep members count
			rankAcc[v] = c + 1 + parentAcc
		}

		// h(u) = rankAcc of u's bicomp representative.
		// visited[u] = true iff the DFS consumed all of u's arcs (the
		// original's untagged==NULL test). Blocked and unreached vertices
		// keep at least one untagged arc. dfsRank can't be used here: a
		// blocked vertex and the representative of a two-vertex bicomponent
		// both end up with dfsRank == nn.
		for i := range hVal {
			if dfsUntagged[i] != nil {
				continue
			}
			visited[i] = true
			rep := dfsParent[i]
			if rep < 0 {
				hVal[i] = 0 // goal itself
			} else if rep == i {
				hVal[i] = rankAcc[i]
			} else {
				hVal[i] = rankAcc[rep]
			}
		}
		return hVal, visited
	}

	var curNode *node
	m := int64(nn) - 1

	for {
		hVal, visited := bicompH(curNode)

		var curV *gbgraph.Vertex
		if curNode == nil {
			curV = start
		} else {
			curV = curNode.game.Tip
		}

		prevTot := int64(0)
		if curNode != nil {
			prevTot = curNode.totLen
		}

		for a := range curV.AllArcs() {
			ui := idx[a.Tip]
			if !visited[ui] {
				continue
			}
			x := &node{
				game:   a,
				totLen: prevTot + del[a],
				prev:   curNode,
			}
			placeNode(x, hVal[ui])
		}

		// Advance m to highest non-empty stratum, reversing each empty list.
		for m > 0 && list[m] == nil {
			m--
			// Reverse list[m] for better ordering.
			var r *node
			s := list[m]
			for s != nil {
				t := s.next
				s.next = r
				r = s
				s = t
			}
			list[m] = r
			mm = 0
		}

		if list[m] == nil {
			break
		}

		curNode = list[m]
		list[m] = curNode.next

		if verbose {
			mm++
			curNode.vid = mm<<8 + m
			var pm, pmm int64
			if curNode.prev != nil {
				pm = curNode.prev.vid & 0xff
				pmm = curNode.prev.vid >> 8
			}
			fmt.Printf("[%d,%d]=[%d,%d]&%s (%+d)\n",
				m, mm, pm, pmm, curNode.game.Tip.Name, curNode.totLen)
		}

		if m == 0 {
			break
		}
	}

	return curNode
}

// makeIdx builds a vertex-pointer→slice-index map.
func makeIdx(g *gbgraph.Graph, nn int) map[*gbgraph.Vertex]int {
	idx := make(map[*gbgraph.Vertex]int, nn)
	for i := range g.Vertices[:nn] {
		idx[&g.Vertices[i]] = i
	}
	return idx
}

// printChain reverses the node chain and prints each game in the path.
func printChain(start, goal *gbgraph.Vertex, curNode *node, del map[*gbgraph.Arc]int64) {
	// Reverse chain by re-stacking.
	var top *node
	for x := curNode; x != nil; x = x.prev {
		top = &node{game: x.game, totLen: x.totLen, prev: top}
	}
	v := start
	for top != nil && v != goal {
		a := top.game
		u := a.Tip
		fmt.Printf("%s: %s %s %d, %s %s %d (%+d)\n",
			formatDate(gbgames.Date(a)),
			v.Name, gbgames.Nickname(v), a.Len,
			u.Name, gbgames.Nickname(u), a.Len-del[a],
			top.totLen)
		v = u
		top = top.prev
	}
}

func formatDate(d int64) string {
	switch {
	case d <= 5:
		return fmt.Sprintf(" Aug %02d", d+26)
	case d <= 35:
		return fmt.Sprintf(" Sep %02d", d-5)
	case d <= 66:
		return fmt.Sprintf(" Oct %02d", d-35)
	case d <= 96:
		return fmt.Sprintf(" Nov %02d", d-66)
	case d <= 127:
		return fmt.Sprintf(" Dec %02d", d-96)
	default:
		return " Jan 01"
	}
}
