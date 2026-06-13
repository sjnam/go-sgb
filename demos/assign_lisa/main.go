// Command assign_lisa solves the assignment problem on a matrix of Mona Lisa
// pixel brightnesses produced by GB_LISA: it chooses at most one entry from each
// row and column so as to maximize (or, with -c, minimize) the sum of the chosen
// entries, then reports how many "mems" (memory references) the computation took.
//
// The matrix has m rows and n columns; if m <= n one entry is chosen in every
// row, otherwise one in every column.  The solver is the Hungarian algorithm
// (Kuhn–Munkres) in the O(m^2 n) form of Papadimitriou and Steiglitz.
//
// Parameters are given as name=value with no spaces, where name is one of
// m, n, d, m0, m1, n0, n1, d0, d1 (see GB_LISA for their meaning).  Flags:
//
//	-s      use only Mona Lisa's 16x32 "smile"
//	-e      use only her 20x50 eyes
//	-c      complement black/white (minimize instead of maximize)
//	-h      use a heuristic that applies only when m == n
//	-v      verbose commentary about the algorithm's performance
//	-V      very verbose commentary
//	-p      print the input matrix and the solution
//	-P      write an encapsulated PostScript file lisa.eps
//	-DDIR   data directory containing lisa.dat (default "data/")
//
// This is a Go port of Knuth's ASSIGN_LISA demo from the Stanford GraphBase.
package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	gbio "github.com/sjnam/go-sgb/gb-io"
	gblisa "github.com/sjnam/go-sgb/gb-lisa"
)

// inf is "infinity (or darn near)" — the initial slack in every column.
const inf = int64(0x7fffffff)

func main() {
	var m, n, d, m0, m1, n0, n1, d0, d1 int64
	var compl, heur, printing, postScript bool
	verbose := 0
	dataDir := "data/"

	// The original scans the command line from last argument to first, so the
	// earliest occurrence of a repeated option wins.
	for i := len(os.Args) - 1; i >= 1; i-- {
		arg := os.Args[i]
		switch {
		case strings.HasPrefix(arg, "-D"):
			dataDir = arg[2:]
		case arg == "-s": // smile
			m0, m1, n0, n1 = 94, 110, 97, 129
			d1 = 100000
		case arg == "-e": // eyes
			m0, m1, n0, n1 = 61, 80, 91, 140
			d1 = 200000
		case arg == "-c":
			compl = true
		case arg == "-h":
			heur = true
		case arg == "-v":
			verbose = 1
		case arg == "-V":
			verbose = 2
		case arg == "-p":
			printing = true
		case arg == "-P":
			postScript = true
		case strings.Contains(arg, "="):
			key, val, _ := strings.Cut(arg, "=")
			p := mustParse(val)
			switch key {
			case "m":
				m = p
			case "n":
				n = p
			case "d":
				d = p
			case "m0":
				m0 = p
			case "m1":
				m1 = p
			case "n0":
				n0 = p
			case "n1":
				n1 = p
			case "d0":
				d0 = p
			case "d1":
				d1 = p
			default:
				usage()
			}
		default:
			usage()
		}
	}

	gbio.DataDirectory = dataDir
	mtx, err := gblisa.Lisa(m, n, d, m0, m1, n0, n1, d0, d1)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Sorry, can't create the matrix! (error code %v)\n", err)
		os.Exit(1)
	}

	id := lisaID(m, n, d, m0, m1, n0, n1, d0, d1)
	complNote := ""
	if compl {
		complNote = ", complemented"
	}
	fmt.Printf("Assignment problem for %s%s\n", id, complNote)

	// Recover the dimensions and pixel range that lisa actually used, after
	// default substitution (the original re-parses these from lisa_id).
	m, n, d = normalize(m, n, d, m0, m1, n0, n1)
	if m != n {
		heur = false // the square-matrix heuristic does not apply
	}

	if printing {
		displayInput(mtx, m, n, d, compl)
	}
	var eps *os.File
	if postScript {
		eps = openInputEPS(mtx, m, n, d, compl)
		if eps == nil {
			postScript = false
		}
	}

	s := &solver{mtx: mtx, m: m, n: n, verbose: verbose}
	transposed := s.solve(d, compl, heur)

	if printing {
		displaySolution(s, transposed)
	}
	if postScript {
		writeSolutionEPS(eps, s, transposed)
		eps.Close()
	}

	note := ""
	if heur {
		note = " with square-matrix heuristic"
	}
	fmt.Printf("Solved in %d mems%s.\n", s.mems, note)
}

func mustParse(s string) int64 {
	v, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		usage()
	}
	return v
}

func usage() {
	fmt.Fprintf(os.Stderr,
		"Usage: %s [name=value] [-s] [-e] [-c] [-h] [-v] [-V] [-p] [-P] [-DDIR]\n",
		os.Args[0])
	os.Exit(2)
}

// normalize applies the documented default substitutions of gblisa.Lisa to
// recover the matrix dimensions m, n and pixel range d that were actually used.
func normalize(m, n, d, m0, m1, n0, n1 int64) (int64, int64, int64) {
	if m1 == 0 || m1 > gblisa.MaxM {
		m1 = gblisa.MaxM
	}
	if n1 == 0 || n1 > gblisa.MaxN {
		n1 = gblisa.MaxN
	}
	if m == 0 {
		m = m1 - m0
	}
	if n == 0 {
		n = n1 - n0
	}
	if d == 0 {
		d = gblisa.MaxD
	}
	return m, n, d
}

// lisaID reconstructs the SGB id string "lisa(m,n,d,m0,m1,n0,n1,d0,d1)" with
// the same default substitutions that gblisa.Lisa applies internally.
func lisaID(m, n, d, m0, m1, n0, n1, d0, d1 int64) string {
	if m1 == 0 || m1 > gblisa.MaxM {
		m1 = gblisa.MaxM
	}
	if n1 == 0 || n1 > gblisa.MaxN {
		n1 = gblisa.MaxN
	}
	if m == 0 {
		m = m1 - m0
	}
	if n == 0 {
		n = n1 - n0
	}
	if d == 0 {
		d = gblisa.MaxD
	}
	if d1 == 0 {
		d1 = gblisa.MaxD * (m1 - m0) * (n1 - n0)
	}
	return fmt.Sprintf("lisa(%d,%d,%d,%d,%d,%d,%d,%d,%d)", m, n, d, m0, m1, n0, n1, d0, d1)
}

// --- The solver ---

// solver holds the matrix and the auxiliary arrays of the Hungarian algorithm,
// together with the running mem count.  The arrays follow Papadimitriou and
// Steiglitz: row k is matched with column colMate[k] (and rowMate[colMate[k]]
// == k); unchosenRow[0..t-1] are the rows of the alternating-path forest;
// rowDec[k] and colInc[l] are the implicit amounts subtracted from row k and
// added to column l; slack[l]/slackRow[l] track the minimum uncovered entry of
// each unchosen column.
type solver struct {
	mtx     []int64
	m, n    int64
	mems    int64
	verbose int

	colMate, rowMate, parentRow, unchosenRow []int64
	rowDec, colInc, slack, slackRow          []int64
	t, q, unmatched                          int64
}

// aa returns matrix entry a[k][l].
func (s *solver) aa(k, l int64) int64 { return s.mtx[k*s.n+l] }

// solve transposes the matrix if needed (the algorithm requires m <= n),
// converts maximization to minimization, optionally applies the heuristic, and
// runs the Hungarian algorithm.  It returns whether the matrix was transposed.
func (s *solver) solve(d int64, compl, heur bool) (transposed bool) {
	if s.m > s.n {
		s.transpose()
		transposed = true
	}
	s.allocate()
	if !compl {
		// Minimize d-a, i.e. maximize the original pixel brightness.
		for k := int64(0); k < s.m; k++ {
			for l := int64(0); l < s.n; l++ {
				s.mtx[k*s.n+l] = d - s.mtx[k*s.n+l]
			}
		}
	}
	if heur {
		s.subtractColumnMinima()
	}
	s.hungarian()
	return
}

func (s *solver) transpose() {
	if s.verbose >= 2 {
		fmt.Println("Temporarily transposing rows and columns...")
	}
	m, n := s.m, s.n
	tmtx := make([]int64, m*n)
	for k := range m {
		for l := range n {
			tmtx[l*m+k] = s.mtx[k*n+l]
		}
	}
	s.m, s.n = n, m
	s.mtx = tmtx
}

func (s *solver) allocate() {
	s.colMate = make([]int64, s.m)
	s.rowMate = make([]int64, s.n)
	s.parentRow = make([]int64, s.n)
	s.unchosenRow = make([]int64, s.m)
	s.rowDec = make([]int64, s.m)
	s.colInc = make([]int64, s.n)
	s.slack = make([]int64, s.n)
	s.slackRow = make([]int64, s.n)
}

// subtractColumnMinima starts the m == n case with extra zeroes by subtracting
// each column's minimum, as enabled by the -h heuristic.
func (s *solver) subtractColumnMinima() {
	for l := int64(0); l < s.n; l++ {
		s.mems++ // o,s=aa(0,l)
		col := s.aa(0, l)
		for k := int64(1); k < s.n; k++ {
			s.mems++ // o,aa(k,l)<s
			if s.aa(k, l) < col {
				col = s.aa(k, l)
			}
		}
		if col != 0 {
			for k := int64(0); k < s.n; k++ {
				s.mems += 2 // oo,aa(k,l)-=s
				s.mtx[k*s.n+l] -= col
			}
		}
	}
	if s.verbose >= 1 {
		fmt.Printf(" The heuristic has cost %d mems.\n", s.mems)
	}
}

// hungarian runs the algorithm in stages; each stage matches one more row.
func (s *solver) hungarian() {
	s.initialStage()
	if s.t == 0 {
		s.doublecheck()
		return
	}
	s.unmatched = s.t
	for {
		if s.verbose >= 1 {
			fmt.Printf(" After %d mems I've matched %d rows.\n", s.mems, s.m-s.t)
		}
		s.q = 0
		var bk, bl int64
		breakthrough := false
		for !breakthrough {
			for s.q < s.t {
				if k, l, ok := s.exploreNode(); ok {
					bk, bl, breakthrough = k, l, true
					break
				}
				s.q++
			}
			if breakthrough {
				break
			}
			if k, l, ok := s.introduceZero(); ok {
				bk, bl, breakthrough = k, l, true
			}
		}
		s.updateMatching(bk, bl)
		s.unmatched--
		if s.unmatched == 0 {
			s.doublecheck()
			return
		}
		s.getReadyForStage()
	}
}

// initialStage scans the matrix for zeroes, greedily matching rows to columns
// and recording the unmatched rows as the initial forest.
func (s *solver) initialStage() {
	s.t = 0
	for l := int64(0); l < s.n; l++ {
		s.mems++ // o,row_mate[l]=-1
		s.rowMate[l] = -1
		s.mems++ // o,parent_row[l]=-1
		s.parentRow[l] = -1
		s.mems++ // o,col_inc[l]=0
		s.colInc[l] = 0
		s.mems++ // o,slack[l]=INF
		s.slack[l] = inf
	}
rows:
	for k := int64(0); k < s.m; k++ {
		s.mems++ // o,s=aa(k,0)
		col := s.aa(k, 0)
		for l := int64(1); l < s.n; l++ {
			s.mems++ // o,aa(k,l)<s
			if s.aa(k, l) < col {
				col = s.aa(k, l)
			}
		}
		s.mems++ // o,row_dec[k]=s
		s.rowDec[k] = col
		for l := int64(0); l < s.n; l++ {
			s.mems++ // o,s==aa(k,l)
			if col == s.aa(k, l) {
				s.mems++ // o,row_mate[l]<0
				if s.rowMate[l] < 0 {
					s.mems++ // o,col_mate[k]=l
					s.colMate[k] = l
					s.mems++ // o,row_mate[l]=k
					s.rowMate[l] = k
					if s.verbose >= 2 {
						fmt.Printf(" matching col %d==row %d\n", l, k)
					}
					continue rows
				}
			}
		}
		s.mems++ // o,col_mate[k]=-1
		s.colMate[k] = -1
		if s.verbose >= 2 {
			fmt.Printf("  node %d: unmatched row %d\n", s.t, k)
		}
		s.mems++ // o,unchosen_row[t++]=k
		s.unchosenRow[s.t] = k
		s.t++
	}
}

// getReadyForStage reinitializes the forest with the currently unmatched rows.
func (s *solver) getReadyForStage() {
	s.t = 0
	for l := int64(0); l < s.n; l++ {
		s.mems++ // o,parent_row[l]=-1
		s.parentRow[l] = -1
		s.mems++ // o,slack[l]=INF
		s.slack[l] = inf
	}
	for k := int64(0); k < s.m; k++ {
		s.mems++ // o,col_mate[k]<0
		if s.colMate[k] < 0 {
			if s.verbose >= 2 {
				fmt.Printf("  node %d: unmatched row %d\n", s.t, k)
			}
			s.mems++ // o,unchosen_row[t++]=k
			s.unchosenRow[s.t] = k
			s.t++
		}
	}
}

// exploreNode explores forest node q, updating column slacks.  It returns
// ok=true (with the breakthrough row k and column l) if an unmatched column
// acquires a zero, letting the matching grow.
func (s *solver) exploreNode() (k, l int64, ok bool) {
	s.mems++ // o,k=unchosen_row[q]
	k = s.unchosenRow[s.q]
	s.mems++ // o,s=row_dec[k]
	dec := s.rowDec[k]
	for l = 0; l < s.n; l++ {
		s.mems++ // o,slack[l]
		if s.slack[l] != 0 {
			s.mems += 2 // oo,del=aa(k,l)-s+col_inc[l]
			del := s.aa(k, l) - dec + s.colInc[l]
			if del < s.slack[l] {
				if del == 0 { // a new zero
					s.mems++ // o,row_mate[l]<0
					if s.rowMate[l] < 0 {
						return k, l, true
					}
					s.mems++       // o,slack[l]=0
					s.slack[l] = 0 // this column will now be chosen
					s.mems++       // o,parent_row[l]=k
					s.parentRow[l] = k
					if s.verbose >= 2 {
						fmt.Printf("  node %d: row %d==col %d--row %d\n", s.t, s.rowMate[l], l, k)
					}
					s.mems += 2 // oo,unchosen_row[t++]=row_mate[l]
					s.unchosenRow[s.t] = s.rowMate[l]
					s.t++
				} else {
					s.mems++ // o,slack[l]=del
					s.slack[l] = del
					s.mems++ // o,slack_row[l]=k
					s.slackRow[l] = k
				}
			}
		}
	}
	return 0, 0, false
}

// introduceZero subtracts the smallest slack from the uncovered part of the
// matrix, creating at least one new zero.  It returns ok=true (with the
// breakthrough row k and column l) if that zero allows the matching to grow.
func (s *solver) introduceZero() (rk, rl int64, ok bool) {
	smallest := inf
	for l := int64(0); l < s.n; l++ {
		s.mems++ // o,slack[l]
		if s.slack[l] != 0 && s.slack[l] < smallest {
			smallest = s.slack[l]
		}
	}
	for s.q = 0; s.q < s.t; s.q++ {
		s.mems += 3 // ooo,row_dec[unchosen_row[q]]+=s
		s.rowDec[s.unchosenRow[s.q]] += smallest
	}
	for l := int64(0); l < s.n; l++ {
		s.mems++             // o,slack[l]
		if s.slack[l] != 0 { // column l is not chosen
			s.mems++ // o,slack[l]-=s
			s.slack[l] -= smallest
			if s.slack[l] == 0 {
				// Look at a new zero.
				s.mems++ // o,k=slack_row[l]
				k := s.slackRow[l]
				if s.verbose >= 2 {
					fmt.Printf(" Decreasing uncovered elements by %d produces zero at [%d,%d]\n", smallest, k, l)
				}
				s.mems++ // o,row_mate[l]<0
				if s.rowMate[l] < 0 {
					// A breakthrough; finish maintaining col_inc for the
					// remaining chosen columns before reporting it.
					for j := l + 1; j < s.n; j++ {
						s.mems++ // o,slack[j]==0
						if s.slack[j] == 0 {
							s.mems += 2 // oo,col_inc[j]+=s
							s.colInc[j] += smallest
						}
					}
					return k, l, true
				}
				// Not a breakthrough; the forest continues to grow.
				s.mems++ // o,parent_row[l]=k
				s.parentRow[l] = k
				if s.verbose >= 2 {
					fmt.Printf("  node %d: row %d==col %d--row %d\n", s.t, s.rowMate[l], l, k)
				}
				s.mems += 2 // oo,unchosen_row[t++]=row_mate[l]
				s.unchosenRow[s.t] = s.rowMate[l]
				s.t++
			}
		} else {
			s.mems += 2 // oo,col_inc[l]+=s
			s.colInc[l] += smallest
		}
	}
	return 0, 0, false
}

// updateMatching follows parent links from the breakthrough, rematching rows
// and columns so a previously unmatched row gains a mate.
func (s *solver) updateMatching(k, l int64) {
	if s.verbose >= 1 {
		fmt.Printf(" Breakthrough at node %d of %d!\n", s.q, s.t)
	}
	for {
		s.mems++ // o,j=col_mate[k]
		j := s.colMate[k]
		s.mems++ // o,col_mate[k]=l
		s.colMate[k] = l
		s.mems++ // o,row_mate[l]=k
		s.rowMate[l] = k
		if s.verbose >= 2 {
			fmt.Printf(" rematching col %d==row %d\n", l, k)
		}
		if j < 0 {
			break
		}
		s.mems++ // o,k=parent_row[j]
		k = s.parentRow[j]
		l = j
	}
}

// doublecheck verifies (without counting mems) that the solution is optimal.
// None of these failures can happen unless the hardware misbehaves.
func (s *solver) doublecheck() {
	for k := int64(0); k < s.m; k++ {
		for l := int64(0); l < s.n; l++ {
			if s.aa(k, l) < s.rowDec[k]-s.colInc[l] {
				fmt.Fprintln(os.Stderr, "Oops, I made a mistake!")
				os.Exit(6)
			}
		}
	}
	for k := int64(0); k < s.m; k++ {
		l := s.colMate[k]
		if l < 0 || s.aa(k, l) != s.rowDec[k]-s.colInc[l] {
			fmt.Fprintln(os.Stderr, "Oops, I blew it!")
			os.Exit(66)
		}
	}
	cnt := int64(0)
	for l := int64(0); l < s.n; l++ {
		if s.colInc[l] != 0 {
			cnt++
		}
	}
	if cnt > s.m {
		fmt.Fprintln(os.Stderr, "Oops, I adjusted too many columns!")
		os.Exit(99)
	}
}

// --- Printing and PostScript output ---

func displayInput(mtx []int64, m, n, d int64, compl bool) {
	for k := range m {
		for l := range n {
			v := mtx[k*n+l]
			if compl {
				v = d - v
			}
			fmt.Printf("% 4d", v)
		}
		fmt.Println()
	}
}

func displaySolution(s *solver, transposed bool) {
	fmt.Println("The following entries produce an optimum assignment:")
	for k := int64(0); k < s.m; k++ {
		if transposed {
			fmt.Printf(" [%d,%d]\n", s.colMate[k], k)
		} else {
			fmt.Printf(" [%d,%d]\n", k, s.colMate[k])
		}
	}
}

// openInputEPS writes the input image to lisa.eps as a grayscale PostScript
// "image", returning the open file (nil if it could not be created).
func openInputEPS(mtx []int64, m, n, d int64, compl bool) *os.File {
	f, err := os.Create("lisa.eps")
	if err != nil {
		fmt.Fprintln(os.Stderr, "Sorry, I can't open the file `lisa.eps'!")
		return nil
	}
	fmt.Fprintf(f, "%%!PS-Adobe-3.0 EPSF-3.0\n")
	fmt.Fprintf(f, "%%%%BoundingBox: -1 -1 %d %d\n", n+1, m+1)
	fmt.Fprintf(f, "/buffer %d string def\n", n)
	fmt.Fprintf(f, "%d %d 8 [%d 0 0 -%d 0 %d]\n", n, m, n, m, m)
	fmt.Fprintf(f, "{currentfile buffer readhexstring pop} bind\n")
	fmt.Fprintf(f, "gsave %d %d scale image\n", n, m)
	conv := 255.0 / float64(d)
	for k := range m {
		for l := range n {
			v := mtx[k*n+l]
			if compl {
				v = d - v
			}
			x := int64(conv * float64(v))
			if x > 255 {
				x = 255
			}
			fmt.Fprintf(f, "%02x", x)
			if l&0x1f == 0x1f {
				fmt.Fprintf(f, "\n")
			}
		}
		if n&0x1f != 0 {
			fmt.Fprintf(f, "\n")
		}
	}
	fmt.Fprintf(f, "grestore\n")
	return f
}

// writeSolutionEPS frames each chosen pixel in black with a white inner trim.
func writeSolutionEPS(f *os.File, s *solver, transposed bool) {
	fmt.Fprintf(f, "/bx {moveto 0 1 rlineto 1 0 rlineto 0 -1 rlineto closepath\n")
	fmt.Fprintf(f, " gsave .3 setlinewidth 1 setgray clip stroke")
	fmt.Fprintf(f, " grestore stroke} bind def\n")
	fmt.Fprintf(f, " .1 setlinewidth\n")
	for k := int64(0); k < s.m; k++ {
		var x, y int64
		if transposed {
			x, y = k, s.n-1-s.colMate[k]
		} else {
			x, y = s.colMate[k], s.m-1-k
		}
		fmt.Fprintf(f, " %d %d bx\n", x, y)
	}
}
