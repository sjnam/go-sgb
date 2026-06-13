// Command take_risc multiplies and divides small numbers the slow way: by
// simulating, one gate at a time, the RISC machine that GB_GATES builds with
// risc.  It prompts for two positive numbers m and n (each at most 0x7fff),
// loads a tiny program into the machine's read-only memory, and runs the gate
// network to compute m*n and then m/n with its remainder.
//
// Usage: take_risc [trace]
//
// Any command-line argument turns on tracing: the contents of registers 0–7 are
// printed for every machine cycle.  An empty line (or EOF) ends the session.
//
// This is a Go port of Knuth's TAKE_RISC demo from the Stanford GraphBase.
package main

import (
	"bufio"
	"fmt"
	"os"

	"github.com/sjnam/go-sgb/gb-gates"
)

// Locations within the program below, and its length.
const (
	div       = 7
	mult      = 10
	memrySize = 34
)

// memry is the read-only memory run by the RISC machine.  It computes
// x*floor(y/z) with the ternary subroutine "tri"; words 1, 3, and 5 are patched
// with m, n, and the entry point (mult or div) before each run.
var memry = []uint64{
	0x2ff0, // start: r2 = m (contents of next word)
	0x1111, //        (the value of m goes here, in memry[1])
	0x1a30, //        r1 = n (contents of next word)
	0x3333, //        (the value of n goes here, in memry[3])
	0x7f70, //        jumpto (next word), r7 = return address
	0x5555, //        (either mult or div goes here, in memry[5])
	0x0f8f, //        halt without changing any status bits
	0x3a21, // div:   r3 = r1
	0x1a01, //        r1 = 1
	0x0a12, //        goto tri  (r0 += 2)
	0x3a01, // mult:  r3 = 1
	0x4000, // tri:   r4 = 0
	0x5000, //        r5 = 0
	0x6000, //        r6 = 0
	0x2a63, //        r2 -= r3
	0x0f95, //        goto l2
	0x3063, // l1:    r3 <<= 1
	0x1061, //        r1 <<= 1
	0x6ac1, //        if (overflow) r6 = 1
	0x5fd1, //        r5++
	0x2a63, // l2:    r2 -= r3
	0x039b, //        if (>= 0) goto l1
	0x0843, //        goto l4
	0x3463, // l3:    r3 >>= 1
	0x1561, //        r1 >>= 1
	0x2863, // l4:    r2 += r3
	0x0c94, //        if (< 0) goto l5
	0x4861, //        r4 += r1
	0x6ac1, //        if (overflow) r6 = 1
	0x2a63, //        r2 -= r3
	0x5a41, // l5:    r5--
	0x0398, //        if (>= 0) goto l3
	0x6666, //        if (r6) force overflow (r6 >>= 4)
	0x0fa7, //        return (r0 = r7, preserving overflow)
}

func main() {
	traceRegs := int64(0)
	if len(os.Args) > 1 { // any argument turns on tracing of registers 0–7
		traceRegs = 8
	}

	g, err := gbgates.Risc(8)
	if err != nil {
		fmt.Printf("Sorry, I couldn't generate the graph (%v)!\n", err)
		os.Exit(1)
	}
	fmt.Println("Welcome to the world of microRISC.")

	rd := bufio.NewReader(os.Stdin)
	for {
		m, ok := readNumber(rd, "\nGimme a number: ")
		if !ok {
			break
		}
		n, ok := readNumber(rd, "OK, now gimme another: ")
		if !ok {
			break
		}

		// Compute the product m*n.
		memry[1] = uint64(m)
		memry[3] = uint64(n)
		memry[5] = mult
		state, _ := gbgates.RunRisc(os.Stdout, g, memry, memrySize, traceRegs)
		p := int64(state[4])
		overflow := state[16] & 1 // the overflow bit
		ovfNote := ""
		if overflow != 0 {
			ovfNote = " (overflow occurred)"
		}
		fmt.Printf("The product of %d and %d is %d%s.\n", m, n, p, ovfNote)

		// Compute the quotient floor(m/n) and remainder m mod n.
		memry[5] = div
		state, _ = gbgates.RunRisc(os.Stdout, g, memry, memrySize, traceRegs)
		q := int64(state[4])
		r := (int64(state[2]) + n) & 0x7fff
		fmt.Printf("The quotient is %d, and the remainder is %d.\n", q, r)
	}
}

// readNumber prompts and reads a positive number in 1..0x7fff, nagging the user
// about non-positive or oversized values.  It returns ok=false when the input
// is not a number or on EOF, which ends the session.
func readNumber(rd *bufio.Reader, firstPrompt string) (int64, bool) {
	line, ok := promptRead(rd, firstPrompt)
	if !ok {
		return 0, false
	}
	for {
		m, perr := parseLong(line)
		if perr != nil {
			return 0, false
		}
		if m <= 0 {
			line, ok = promptRead(rd, "Excuse me, I meant a positive number: ")
			if !ok {
				return 0, false
			}
			m, perr = parseLong(line)
			if perr != nil || m <= 0 {
				return 0, false
			}
		}
		if m <= 0x7fff {
			return m, true
		}
		line, ok = promptRead(rd, "That number's too big; please try again: ")
		if !ok {
			return 0, false
		}
	}
}

// promptRead prints prompt and reads one line; ok=false on EOF with no input.
func promptRead(rd *bufio.Reader, prompt string) (string, bool) {
	fmt.Print(prompt)
	line, err := rd.ReadString('\n')
	if err != nil && line == "" {
		return "", false
	}
	return line, true
}

// parseLong reads a leading decimal integer from s, like sscanf("%ld").
func parseLong(s string) (int64, error) {
	var v int64
	_, err := fmt.Sscanf(s, "%d", &v)
	return v, err
}
