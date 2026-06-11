// Command multiply multiplies (and effectively divides) numbers the slow way:
// by simulating a logic circuit one gate at a time.  The circuit is the
// multiplication network produced by the GB_GATES prod routine.
//
// Usage: multiply m n [seed]
//
// m and n are the operand sizes in bits.  With no seed the program prompts for
// two numbers and multiplies them.  When a seed is given, prod's network is
// specialized by partial_gates into a circuit that multiplies any m-bit number
// by one fixed n-bit constant chosen at random from the seed; the program then
// prompts for a single number each round.
//
// An empty line (or EOF) ends the session.
//
// This is a Go port of Knuth's MULTIPLY demo from the Stanford GraphBase.  The
// original juggles high-precision decimals as strings; here math/big handles
// the decimal<->binary conversions, leaving the gate simulation as the point.
package main

import (
	"bufio"
	"fmt"
	"math/big"
	"os"
	"strconv"
	"strings"

	"github.com/sjnam/go-sgb/gbgates"
	"github.com/sjnam/go-sgb/gbgraph"
)

func main() {
	args := os.Args[1:]
	if len(args) < 2 || len(args) > 3 {
		fmt.Fprintf(os.Stderr, "Usage: %s m n [seed]\n", os.Args[0])
		os.Exit(2)
	}
	m, err1 := strconv.ParseInt(args[0], 10, 64)
	n, err2 := strconv.ParseInt(args[1], 10, 64)
	if err1 != nil || err2 != nil {
		fmt.Fprintf(os.Stderr, "Usage: %s m n [seed]\n", os.Args[0])
		os.Exit(2)
	}
	if m < 0 { // maybe the user attached '-' to the argument
		m = -m
	}
	if n < 0 {
		n = -n
	}
	seed := int64(-1)
	if len(args) == 3 {
		if sv, err := strconv.ParseInt(args[2], 10, 64); err == nil {
			if sv < 0 {
				sv = -sv
			}
			seed = sv
		}
	}

	if m < 2 {
		m = 2
	}
	if n < 2 {
		n = 2
	}
	if m > 999 || n > 999 {
		fmt.Println("Sorry, I'm set up only for precision less than 1000 bits.")
		os.Exit(1)
	}
	g, err := gbgates.Prod(m, n)
	if err != nil {
		fmt.Printf("Sorry, I couldn't generate the graph (%v)!\n", err)
		os.Exit(1)
	}

	var konst string // decimal value of the fixed constant, in seed mode
	if seed < 0 {
		fmt.Printf("Here I am, ready to multiply %d-bit numbers by %d-bit numbers.\n", m, n)
	} else {
		buf := make([]byte, 2000)
		g, err = gbgates.PartialGates(g, m, 0, seed, buf)
		if err != nil {
			fmt.Printf("Sorry, I couldn't process the graph (%v)!\n", err)
			os.Exit(1)
		}
		konst = constantDecimal(buf)
		if konst == "0" {
			fmt.Printf("Please try another seed value; %d makes the answer zero!\n", seed)
			os.Exit(1)
		}
		fmt.Printf("OK, I'm ready to multiply any %d-bit number by %s.\n", m, konst)
	}
	fmt.Printf("(I'm simulating a logic circuit with %d gates, depth %d.)\n", g.N, depth(g))

	r := bufio.NewReader(os.Stdin)
	for {
		x, ok := readNumber(r, "\nNumber, please? ")
		if !ok {
			break
		}
		y := konst
		if seed < 0 {
			y, ok = readNumber(r, "Another? ")
			if !ok {
				break
			}
		}

		z, msg := product(g, x, y, m, n, seed)
		if msg != "" {
			fmt.Println(msg)
			continue
		}
		// Insert a line break before the result when the operands are long.
		sep := ""
		if len(x)+len(y) > 35 {
			sep = "\n "
		}
		fmt.Printf("%sx%s=%s%s.\n", x, y, sep, z)
	}
}

// readNumber prints prompt and reads a nonnegative decimal integer, retrying on
// bad input.  It returns ok=false on EOF or an empty line, which ends the run.
func readNumber(r *bufio.Reader, prompt string) (string, bool) {
	for {
		fmt.Print(prompt)
		line, err := r.ReadString('\n')
		if err != nil && line == "" {
			return "", false
		}
		line = strings.TrimRight(line, "\r\n")

		i := 0
		for i < len(line) && line[i] == '0' { // bypass leading zeroes
			i++
		}
		s := line[i:]
		if s == "" {
			if i > 0 {
				return "0", true // a bare zero is acceptable
			}
			return "", false // empty input terminates the run
		}
		valid := true
		for j := 0; j < len(s); j++ {
			if s[j] < '0' || s[j] > '9' {
				valid = false
				break
			}
		}
		if !valid {
			fmt.Print("Excuse me... I'm looking for a nonnegative sequence of decimal digits.")
			continue
		}
		if len(s) > 301 {
			fmt.Print("Sorry, that's too big.")
			continue
		}
		return s, true
	}
}

// product runs the gate network on operands x and (unless in seed mode) y, both
// decimal strings, and returns their product as a decimal string.  A non-empty
// msg means the operand did not fit and the round should be skipped.
func product(g *gbgraph.Graph, x, y string, m, n, seed int64) (z, msg string) {
	// The inputs are the first m bits (operand x, little-endian) followed, in
	// non-seed mode, by the next n bits (operand y).
	in := make([]byte, m+n)
	xi, _ := new(big.Int).SetString(x, 10)
	if int64(xi.BitLen()) > m {
		return "", fmt.Sprintf("(Sorry, %s has more than %d bits.)", x, m)
	}
	putBits(in[:m], xi)
	inLen := m
	if seed < 0 {
		yi, _ := new(big.Int).SetString(y, 10)
		if int64(yi.BitLen()) > n {
			return "", fmt.Sprintf("(Sorry, %s has more than %d bits.)", y, n)
		}
		putBits(in[m:m+n], yi)
		inLen = m + n
	}

	out := make([]byte, m+n+1)
	if gbgates.GateEval(g, string(in[:inLen]), out) < 0 {
		return "", "??? An internal error occurred!" // this can't happen
	}

	// The output bits are big-endian (out[0] is the most significant).
	end := 0
	for end < len(out) && out[end] != 0 {
		end++
	}
	zi, _ := new(big.Int).SetString(string(out[:end]), 2)
	return zi.String(), ""
}

// putBits fills dst with the little-endian bits of v as '0'/'1' characters.
func putBits(dst []byte, v *big.Int) {
	for i := range dst {
		dst[i] = byte('0' + v.Bit(i))
	}
}

// constantDecimal converts the little-endian bit string written by partial_gates
// (terminated by a zero byte) into a decimal string.
func constantDecimal(buf []byte) string {
	end := 0
	for end < len(buf) && buf[end] != 0 {
		end++
	}
	v := new(big.Int)
	one := big.NewInt(1)
	for i := end - 1; i >= 0; i-- { // buf[end-1] is the most significant bit
		v.Lsh(v, 1)
		if buf[i] == '1' {
			v.Or(v, one)
		}
	}
	return v.String()
}

// depth returns the depth of gate network g: an input, latch, or constant has
// depth 0, and every other gate has depth one more than its deepest operand.
// The result is the deepest non-constant output.  Utility field u.I in the
// original; a parallel slice here.
func depth(g *gbgraph.Graph) int64 {
	if g == nil {
		return -1
	}
	dp := make([]int64, g.N)
	for vi := int64(0); vi < g.N; vi++ {
		v := &g.Vertices[vi]
		switch gbgates.Typ(v) {
		case gbgates.INP, gbgates.LAT, gbgates.CON:
			dp[vi] = 0
		default:
			d := int64(0)
			for a := v.Arcs; a != nil; a = a.Next {
				if td := dp[gbgraph.VertexIndex(g, a.Tip)]; td > d {
					d = td
				}
			}
			dp[vi] = 1 + d
		}
	}
	// A nil output tip is a boolean constant (is_boolean in the original).
	d := int64(0)
	for a := gbgates.Outs(g); a != nil; a = a.Next {
		if a.Tip == nil {
			continue
		}
		if td := dp[gbgraph.VertexIndex(g, a.Tip)]; td > d {
			d = td
		}
	}
	return d
}
