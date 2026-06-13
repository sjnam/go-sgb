package gbgates

import (
	"fmt"
	"io"
	"strings"
	"testing"

	gbgraph "github.com/sjnam/go-sgb/gb-graph"
)

// TestRiscVertexCount verifies that Risc(regs) produces a non-nil graph with
// at least the minimum number of inputs and latches: 1 + 16 + 10 + 5 + 16*regs.
func TestRiscVertexCount(t *testing.T) {
	for _, regs := range []int64{2, 8, 16} {
		g, err := Risc(regs)
		if err != nil {
			t.Fatalf("Risc(%d) returned error: %v", regs, err)
		}
		if g == nil {
			t.Fatalf("Risc(%d) returned nil", regs)
		}
		minN := int64(1 + 16 + 10 + 5 + 16*regs)
		if g.N < minN {
			t.Errorf("Risc(%d): N=%d, want >= %d", regs, g.N, minN)
		}
	}
}

// TestRiscDefault verifies values outside 2..16 are replaced with 16.
func TestRiscDefault(t *testing.T) {
	g16, err := Risc(16)
	if err != nil {
		t.Fatalf("Risc(16) error: %v", err)
	}
	g0, err := Risc(0)
	if err != nil {
		t.Fatalf("Risc(0) error: %v", err)
	}
	if g16 == nil || g0 == nil {
		t.Fatalf("Risc(0 or 16) returned nil")
	}
	if g0.N != g16.N {
		t.Errorf("Risc(0).N=%d != Risc(16).N=%d", g0.N, g16.N)
	}
}

// TestRiscUtilTypes verifies the utility types string.
func TestRiscUtilTypes(t *testing.T) {
	g, err := Risc(16)
	if err != nil {
		t.Fatalf("Risc(16) error: %v", err)
	}
	if g == nil {
		t.Fatalf("Risc(16) returned nil")
	}
	if g.UtilTypes != "ZZZIIVZZZZZZZA" {
		t.Errorf("UtilTypes=%q, want %q", g.UtilTypes, "ZZZIIVZZZZZZZA")
	}
}

// TestRiscID checks the graph ID.
func TestRiscID(t *testing.T) {
	g, err := Risc(8)
	if err != nil {
		t.Fatalf("Risc(8) error: %v", err)
	}
	if g == nil {
		t.Fatalf("Risc(8) returned nil")
	}
	if g.ID != "risc(8)" {
		t.Errorf("ID=%q, want %q", g.ID, "risc(8)")
	}
}

// TestRiscInputs verifies the first 17 vertices are inputs (RUN + M0..M15).
func TestRiscInputs(t *testing.T) {
	g, err := Risc(16)
	if err != nil {
		t.Fatalf("Risc(16) error: %v", err)
	}
	if g == nil {
		t.Fatalf("Risc(16) returned nil")
	}
	if g.Vertices[0].Name != "RUN" {
		t.Errorf("vertex 0 name=%q, want RUN", g.Vertices[0].Name)
	}
	if Typ(&g.Vertices[0]) != INP {
		t.Errorf("vertex 0 type=%d, want INP=%d", Typ(&g.Vertices[0]), INP)
	}
	for k := int64(1); k <= 16; k++ {
		if Typ(&g.Vertices[k]) != INP {
			t.Errorf("vertex %d (M%d) is not INP", k, k-1)
		}
	}
}

// TestRiscLatches verifies the prog and flag latch vertices.
func TestRiscLatches(t *testing.T) {
	g, err := Risc(16)
	if err != nil {
		t.Fatalf("Risc(16) error: %v", err)
	}
	if g == nil {
		t.Fatalf("Risc(16) returned nil")
	}
	// P0..P9 at 17..26
	for k := range int64(10) {
		v := &g.Vertices[17+k]
		want := fmt.Sprintf("P%d", k)
		if v.Name != want {
			t.Errorf("vertex %d: name=%q, want %q", 17+k, v.Name, want)
		}
		if Typ(v) != LAT {
			t.Errorf("vertex %d (%s) is not LAT", 17+k, v.Name)
		}
	}
	// Flags S,N,K,V,X at 27..31
	flags := []struct {
		idx  int64
		name string
	}{{27, "S"}, {28, "N"}, {29, "K"}, {30, "V"}, {31, "X"}}
	for _, f := range flags {
		v := &g.Vertices[f.idx]
		if v.Name != f.name {
			t.Errorf("vertex %d: name=%q, want %q", f.idx, v.Name, f.name)
		}
		if Typ(v) != LAT {
			t.Errorf("vertex %d (%s) is not LAT", f.idx, v.Name)
		}
	}
}

// TestRiscOutputs checks that the graph has exactly 16 output arcs.
func TestRiscOutputs(t *testing.T) {
	g, err := Risc(16)
	if err != nil {
		t.Fatalf("Risc(16) error: %v", err)
	}
	if g == nil {
		t.Fatalf("Risc(16) returned nil")
	}
	count := 0
	for a := Outs(g); a != nil; a = a.Next {
		count++
	}
	if count != 16 {
		t.Errorf("Outs count=%d, want 16", count)
	}
}

// TestGateEvalSimple evaluates a tiny hand-built AND gate network.
func TestGateEvalSimple(t *testing.T) {
	g := gbgraph.NewGraph(3)
	// v0 = input, v1 = input, v2 = AND(v0,v1)
	g.Vertices[0].Name = "a"
	g.Vertices[0].Y = int64(INP)
	g.Vertices[1].Name = "b"
	g.Vertices[1].Y = int64(INP)
	g.Vertices[2].Name = "and"
	g.Vertices[2].Y = int64(AND)
	g.NewArc(&g.Vertices[2], &g.Vertices[0], DELAY)
	g.NewArc(&g.Vertices[2], &g.Vertices[1], DELAY)

	tests := []struct {
		in  string
		out byte
	}{
		{"00", '0'},
		{"01", '0'},
		{"10", '0'},
		{"11", '1'},
	}
	for _, tt := range tests {
		out := make([]byte, 2)
		// attach output arc
		a := &gbgraph.Arc{Tip: &g.Vertices[2]}
		g.ZZ = a
		GateEval(g, tt.in, out)
		if out[0] != tt.out {
			t.Errorf("AND(%s)=%c, want %c", tt.in, out[0], tt.out)
		}
	}
}

// TestProdSmall verifies that Prod(2,2) produces a non-nil graph with outs.
func TestProdSmall(t *testing.T) {
	g, err := Prod(2, 2)
	if err != nil {
		t.Fatalf("Prod(2,2) returned error: %v", err)
	}
	if g == nil {
		t.Fatalf("Prod(2,2) returned nil")
	}
	if g.N <= 0 {
		t.Errorf("Prod(2,2): N=%d, want >0", g.N)
	}
	if Outs(g) == nil {
		t.Error("Prod(2,2): no output arcs")
	}
	if g.UtilTypes != "ZZZIIVZZZZZZZA" {
		t.Errorf("UtilTypes=%q, want %q", g.UtilTypes, "ZZZIIVZZZZZZZA")
	}
}

// TestProdID checks the graph ID.
func TestProdID(t *testing.T) {
	g, err := Prod(3, 3)
	if err != nil {
		t.Fatalf("Prod(3,3) error: %v", err)
	}
	if g == nil {
		t.Fatalf("Prod(3,3) returned nil")
	}
	if g.ID != "prod(3,3)" {
		t.Errorf("ID=%q, want %q", g.ID, "prod(3,3)")
	}
}

// TestProdOutputCount checks that Prod(m,n) has m+n output arcs.
func TestProdOutputCount(t *testing.T) {
	for _, tc := range []struct{ m, n int64 }{{2, 2}, {3, 4}, {4, 4}} {
		g, err := Prod(tc.m, tc.n)
		if err != nil {
			t.Fatalf("Prod(%d,%d) error: %v", tc.m, tc.n, err)
		}
		if g == nil {
			t.Fatalf("Prod(%d,%d) returned nil", tc.m, tc.n)
		}
		count := 0
		for a := Outs(g); a != nil; a = a.Next {
			count++
		}
		want := int(tc.m + tc.n)
		if count != want {
			t.Errorf("Prod(%d,%d): %d outputs, want %d", tc.m, tc.n, count, want)
		}
	}
}

// TestPrintGates checks that PrintGates produces non-empty output (smoke test).
func TestPrintGates(t *testing.T) {
	g, err := Prod(2, 2)
	if err != nil {
		t.Skip("Prod(2,2) error:", err)
	}
	if g == nil {
		t.Skip("Prod(2,2) returned nil")
	}
	var buf strings.Builder
	PrintGates(&buf, g)
	if !strings.Contains(buf.String(), "Output") {
		t.Errorf("PrintGates output missing output lines: %q", buf.String())
	}
}

// TestPartialGatesReduces verifies PartialGates returns a smaller or equal graph.
func TestPartialGatesReduces(t *testing.T) {
	g, err := Prod(4, 4)
	if err != nil {
		t.Fatalf("Prod(4,4) error: %v", err)
	}
	if g == nil {
		t.Fatalf("Prod(4,4) returned nil")
	}
	orig := g.N
	g2, err := PartialGates(g, 0, 0, 1, nil) // fix all inputs as constants
	if err != nil {
		t.Fatalf("PartialGates returned error: %v", err)
	}
	if g2 == nil {
		t.Fatalf("PartialGates returned nil")
	}
	if g2.N > orig {
		t.Errorf("PartialGates: N=%d grew from %d", g2.N, orig)
	}
	if !strings.HasPrefix(g2.ID, "partial_gates(") {
		t.Errorf("ID=%q doesn't start with partial_gates(", g2.ID)
	}
}

// TestGateEvalRiscReset verifies GateEval with all-zero inputs doesn't panic.
func TestGateEvalRiscReset(t *testing.T) {
	g, err := Risc(2)
	if err != nil {
		t.Fatalf("Risc(2) error: %v", err)
	}
	if g == nil {
		t.Fatalf("Risc(2) returned nil")
	}
	zeros := strings.Repeat("0", 17)
	ret := GateEval(g, zeros, nil)
	if ret != 0 {
		t.Errorf("GateEval returned %d, want 0", ret)
	}
}

// riscProgram is the multiply/divide program from the TAKE_RISC demo: it runs
// the ternary subroutine x*floor(y/z) with x in r1, y in r2, z in r3.
var riscProgram = []uint64{
	0x2ff0, 0x1111, 0x1a30, 0x3333, 0x7f70, 0x5555, 0x0f8f,
	0x3a21, 0x1a01, 0x0a12, 0x3a01, 0x4000, 0x5000, 0x6000, 0x2a63, 0x0f95,
	0x3063, 0x1061, 0x6ac1, 0x5fd1, 0x2a63, 0x039b, 0x0843, 0x3463, 0x1561,
	0x2863, 0x0c94, 0x4861, 0x6ac1, 0x2a63, 0x5a41, 0x0398, 0x6666, 0x0fa7,
}

// TestRunRiscMultiplyDivide drives the simulated RISC machine end to end and
// checks that it actually computes products, quotients, and remainders.  This
// exercises register loads, the source mux, and the adder — paths that an
// inverted even_comp once left dead while the machine still appeared to "run".
func TestRunRiscMultiplyDivide(t *testing.T) {
	g, err := Risc(8)
	if err != nil {
		t.Fatalf("Risc(8) error: %v", err)
	}
	cases := []struct{ m, n, prod, quot, rem int64 }{
		{100, 7, 700, 14, 2},
		{1000, 3, 3000, 333, 1},
		{255, 255, 65025 & 0xffff, 1, 0},
		{12, 4, 48, 3, 0},
	}
	for _, c := range cases {
		rom := append([]uint64(nil), riscProgram...)
		rom[1], rom[3] = uint64(c.m), uint64(c.n)

		rom[5] = 10 // mult
		st, _ := RunRisc(io.Discard, g, rom, int64(len(rom)), 0)
		if got := int64(st[4]); got != c.prod {
			t.Errorf("%d * %d: r4=%d, want %d", c.m, c.n, got, c.prod)
		}

		rom[5] = 7 // div
		st, _ = RunRisc(io.Discard, g, rom, int64(len(rom)), 0)
		if got := int64(st[4]); got != c.quot {
			t.Errorf("%d / %d: quotient=%d, want %d", c.m, c.n, got, c.quot)
		}
		if got := (int64(st[2]) + c.n) & 0x7fff; got != c.rem {
			t.Errorf("%d %% %d: remainder=%d, want %d", c.m, c.n, got, c.rem)
		}
	}
}

// TestProdMultiplies builds prod(m,n) circuits and checks that simulating them
// yields correct products, including sizes (e.g. 6x6) whose reduce step once
// crashed on a nil arc tip.
func TestProdMultiplies(t *testing.T) {
	cases := []struct{ m, n, a, b int64 }{
		{4, 4, 13, 11}, {6, 6, 50, 47}, {8, 8, 200, 201}, {5, 7, 31, 100},
	}
	for _, c := range cases {
		g, err := Prod(c.m, c.n)
		if err != nil {
			t.Errorf("Prod(%d,%d) error: %v", c.m, c.n, err)
			continue
		}
		in := make([]byte, c.m+c.n)
		for i := int64(0); i < c.m; i++ {
			in[i] = byte('0' + (c.a>>uint(i))&1)
		}
		for i := int64(0); i < c.n; i++ {
			in[c.m+i] = byte('0' + (c.b>>uint(i))&1)
		}
		out := make([]byte, c.m+c.n+1)
		if GateEval(g, string(in), out) < 0 {
			t.Errorf("Prod(%d,%d) GateEval failed", c.m, c.n)
			continue
		}
		var got int64
		for i := int64(0); i < c.m+c.n; i++ { // big-endian
			got = got<<1 + int64(out[i]-'0')
		}
		if got != c.a*c.b {
			t.Errorf("prod(%d,%d): %d*%d=%d, want %d", c.m, c.n, c.a, c.b, got, c.a*c.b)
		}
	}
}
