package io

import "testing"

// TestIO mirrors test_io.c from gb_io.w exactly.
// test.dat layout (after the 4-line header):
//
//	line 1 (79 chars): 64×'0' + "123456789ABCDEF"
//	line 2            : " " (blank after space-stripping → just \n)
//	line 3            : "Oops:(intentional mistake)"
//
// Checksum parameters: 3,1008816584
func TestIO(t *testing.T) {
	DataDirectory = "../data/"
	r, err := Open("test.dat")
	if err != nil {
		t.Fatalf("Open failed: %v", err)
	}

	// --- sample data line 1: 64 zeros + "123456789ABCDEF" ---

	// GbNumber(10) reads the decimal prefix "000...000123456789"
	if v := r.GbNumber(10); v != 123456789 {
		t.Errorf("GbNumber(10) = %d, want 123456789", v)
	}

	// GbDigit(16) reads 'A' (hex 10)
	if v := r.GbDigit(16); v != 10 {
		t.Errorf("GbDigit(16) = %d, want 10", v)
	}

	// back up twice to re-read "9A"
	r.GbBackup()
	r.GbBackup()

	// GbNumber(16) reads "9ABCDEF"
	if v := r.GbNumber(16); v != 0x9ABCDEF {
		t.Errorf("GbNumber(16) = 0x%x, want 0x9ABCDEF", v)
	}

	// --- blank line (line 2) ---
	r.GbNewline()

	if c := r.GbChar(); c != '\n' {
		t.Errorf("GbChar() on blank line = %q, want '\\n'", c)
	}
	if c := r.GbChar(); c != '\n' {
		t.Errorf("second GbChar() past end = %q, want '\\n'", c)
	}

	// GbNumber on empty buffer always returns 0
	if v := r.GbNumber(60); v != 0 {
		t.Errorf("GbNumber(60) at null = %d, want 0", v)
	}

	// GbString on exhausted line returns ""
	if s := r.GbString('\n'); s != "" {
		t.Errorf("GbString at end-of-line = %q, want empty", s)
	}

	// --- line 3: "Oops:(intentional mistake)" ---
	r.GbNewline()

	if s := r.GbString(':'); s != "Oops" {
		t.Errorf("GbString(':') = %q, want \"Oops\"", s)
	}

	if v := r.GbDigit(10); v != -1 {
		t.Errorf("GbDigit on ':' = %d, want -1", v)
	}
	if c := r.GbChar(); c != ':' {
		t.Errorf("GbChar() after GbDigit = %q, want ':'", c)
	}

	if r.GbEof() {
		t.Error("GbEof() true before final GbNewline, want false")
	}

	r.GbNewline() // advance past last data line → more_data = false

	if !r.GbEof() {
		t.Error("GbEof() false after all lines consumed, want true")
	}

	// --- close and verify checksum ---
	if err := r.Close(); err != nil {
		t.Errorf("Close failed: %v", err)
	}
}

// TestImapOrd verifies a few known icode values.
func TestImapOrd(t *testing.T) {
	cases := []struct {
		c    byte
		want byte
	}{
		{'0', 0},
		{'9', 9},
		{'A', 10},
		{'F', 15},
		{'a', 36},
		{' ', 94},
		{'\n', 95},
	}
	for _, c := range cases {
		if got := ImapOrd(c.c); got != c.want {
			t.Errorf("ImapOrd(%q) = %d, want %d", c.c, got, c.want)
		}
	}
}

// TestImapChr is the inverse of TestImapOrd.
func TestImapChr(t *testing.T) {
	cases := []struct {
		d    int64
		want byte
	}{
		{0, '0'},
		{10, 'A'},
		{36, 'a'},
		{94, ' '},
		{95, '\n'},
	}
	for _, c := range cases {
		if got := ImapChr(c.d); got != c.want {
			t.Errorf("ImapChr(%d) = %q, want %q", c.d, got, c.want)
		}
	}
}

// TestNewChecksum spot-checks the checksum formula.
func TestNewChecksum(t *testing.T) {
	// NewChecksum("", 0) == 0 (empty string changes nothing)
	if v := NewChecksum("", 0); v != 0 {
		t.Errorf("NewChecksum(\"\", 0) = %d, want 0", v)
	}
	// NewChecksum("\n", 0): a = (0+0+95) % prime = 95
	if v := NewChecksum("\n", 0); v != 95 {
		t.Errorf("NewChecksum(\"\\n\", 0) = %d, want 95", v)
	}
}
