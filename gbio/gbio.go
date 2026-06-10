// Package gbio implements the GB_IO input module from Stanford GraphBase.
// It provides system-independent file I/O with checksum validation for
// GraphBase data files.
package gbio

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"strings"
)

// DataDirectory, if set, is prepended to the file name when the file
// cannot be opened directly.
var DataDirectory string

// imap: character imap[k] has internal code k.
const imap = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_^~&@,;.:?!%#$+-*/|\\<=>()[]{}`'\" \n"

var icode [256]byte

func init() {
	for k := range icode {
		icode[k] = UnexpectedChar
	}
	for k := 0; k < len(imap); k++ {
		icode[imap[k]] = byte(k)
	}
}

const (
	UnexpectedChar       = 127
	checksumPrime  int64 = 1<<30 - 83
)

// ImapChr returns the character whose internal code is d, or '\0' if out of range.
func ImapChr(d int64) byte {
	if d < 0 || d >= int64(len(imap)) {
		return 0
	}
	return imap[d]
}

// ImapOrd returns the internal code of character c.
func ImapOrd(c byte) byte { return icode[c] }

// NewChecksum updates old with the characters of s and returns the new value.
// This is a pure function; it does not require an open Reader.
func NewChecksum(s string, old int64) int64 {
	for i := 0; i < len(s); i++ {
		old = (old + old + int64(icode[s[i]])) % checksumPrime
	}
	return old
}

// Reader holds all state for one open GraphBase data file.
type Reader struct {
	buffer     [81]byte
	curPos     int
	file       *os.File
	bufReader  *bufio.Reader
	fileName   string
	magic      int64
	lineNo     int64
	finalMagic int64
	totLines   int64
	moreData   bool
}

func tryOpen(path string) *os.File {
	if f, err := os.Open(path); err == nil {
		return f
	}
	if DataDirectory != "" {
		if f, err := os.Open(DataDirectory + path); err == nil {
			return f
		}
	}
	return nil
}

// RawOpen opens path without validating any header.
// Returns a ready-to-use Reader, or an error if the file cannot be opened.
func RawOpen(path string) (*Reader, error) {
	f := tryOpen(path)
	if f == nil {
		return nil, fmt.Errorf("io: cannot open %q", path)
	}
	r := &Reader{
		file:      f,
		bufReader: bufio.NewReader(f),
		moreData:  true,
		totLines:  0x7fffffff,
	}
	r.fillBuf()
	return r, nil
}

// Open opens a standard GraphBase data file and validates its four-line header.
// Returns a Reader positioned at the first data line, or an error.
func Open(path string) (*Reader, error) {
	r, err := RawOpen(path)
	if err != nil {
		return nil, err
	}
	r.fileName = path

	// Line 1: * File "path"
	if !strings.HasPrefix(r.bufStr(), fmt.Sprintf("* File \"%s\"", path)) {
		r.file.Close()
		return nil, fmt.Errorf("io: bad first line in %q", path)
	}
	// Lines 2 and 3: must start with '*'
	r.fillBuf()
	if r.buffer[0] != '*' {
		r.file.Close()
		return nil, fmt.Errorf("io: bad second line in %q", path)
	}
	r.fillBuf()
	if r.buffer[0] != '*' {
		r.file.Close()
		return nil, fmt.Errorf("io: bad third line in %q", path)
	}
	// Line 4: * (Checksum parameters N,M)
	const csPrefix = "* (Checksum parameters "
	r.fillBuf()
	if !strings.HasPrefix(r.bufStr(), csPrefix) {
		r.file.Close()
		return nil, fmt.Errorf("io: bad fourth line in %q", path)
	}
	r.curPos = len(csPrefix)
	r.totLines = int64(r.GbNumber(10))
	if r.GbChar() != ',' {
		r.file.Close()
		return nil, fmt.Errorf("io: bad checksum parameters in %q", path)
	}
	r.finalMagic = int64(r.GbNumber(10))
	if r.GbChar() != ')' {
		r.file.Close()
		return nil, fmt.Errorf("io: bad checksum parameters in %q", path)
	}
	r.GbNewline() // advance to first real data line
	return r, nil
}

// Close validates the end-of-file marker, line count, and checksum.
// It always closes the underlying file.
func (r *Reader) Close() error {
	defer func() {
		r.file.Close()
		r.moreData = false
		r.buffer[0] = 0
	}()
	r.fillBuf()
	if !strings.HasPrefix(r.bufStr(), fmt.Sprintf("* End of file \"%s\"", r.fileName)) {
		return fmt.Errorf("io: bad last line in %q", r.fileName)
	}
	if r.lineNo != r.totLines+1 {
		return fmt.Errorf("io: wrong number of lines in %q (got %d, want %d)",
			r.fileName, r.lineNo, r.totLines+1)
	}
	if r.magic != r.finalMagic {
		return fmt.Errorf("io: wrong checksum in %q (got %d, want %d)",
			r.fileName, r.magic, r.finalMagic)
	}
	return nil
}

// RawClose closes the file and returns the accumulated checksum.
func (r *Reader) RawClose() int64 {
	r.file.Close()
	r.moreData = false
	r.buffer[0] = 0
	r.curPos = 0
	return r.magic
}

// GbNewline advances to the next data line and folds the new line into the
// checksum (skipping lines that start with '*').
func (r *Reader) GbNewline() {
	r.lineNo++
	if r.lineNo > r.totLines {
		r.moreData = false
	}
	if r.moreData {
		r.fillBuf()
		if r.buffer[0] != '*' {
			for i := 0; r.buffer[i] != 0; i++ {
				r.magic = (r.magic + r.magic + int64(icode[r.buffer[i]])) % checksumPrime
			}
		}
	}
}

// GbEof reports whether all data lines have been consumed.
func (r *Reader) GbEof() bool { return !r.moreData }

// GbChar returns the next character from the current line,
// or '\n' when at or past the end of the line.
func (r *Reader) GbChar() byte {
	if r.buffer[r.curPos] != 0 {
		c := r.buffer[r.curPos]
		r.curPos++
		return c
	}
	return '\n'
}

// GbBackup moves the read position one step back.
func (r *Reader) GbBackup() {
	if r.curPos > 0 {
		r.curPos--
	}
}

// GbDigit reads one base-d digit at the current position.
// Returns -1 if the current character is not a valid digit in base d.
func (r *Reader) GbDigit(d byte) int64 {
	c := r.buffer[r.curPos]
	if c == 0 || icode[c] >= d {
		return -1
	}
	r.curPos++
	return int64(icode[c])
}

// GbNumber reads a base-d unsigned integer from the current position.
func (r *Reader) GbNumber(d byte) uint64 {
	var a uint64
	for r.buffer[r.curPos] != 0 {
		v := icode[r.buffer[r.curPos]]
		if v >= d {
			break
		}
		a = a*uint64(d) + uint64(v)
		r.curPos++
	}
	return a
}

// GbString reads characters up to (but not including) delim.
// Use '\n' as delim to read to end of line.
func (r *Reader) GbString(delim byte) string {
	var sb strings.Builder
	for r.buffer[r.curPos] != 0 && r.buffer[r.curPos] != delim {
		sb.WriteByte(r.buffer[r.curPos])
		r.curPos++
	}
	return sb.String()
}

// fillBuf reads the next line into r.buffer, strips trailing spaces,
// and terminates with '\n' followed by '\0'.
func (r *Reader) fillBuf() {
	line, err := r.bufReader.ReadBytes('\n')
	if err != nil && len(line) == 0 {
		r.buffer[0] = 0
		r.moreData = false
		r.curPos = 0
		return
	}
	n := len(line)
	if n > 0 && line[n-1] == '\n' {
		n--
	}
	if n > 79 {
		n = 79
	}
	copy(r.buffer[:n], line[:n])
	for n > 0 && r.buffer[n-1] == ' ' {
		n--
	}
	r.buffer[n] = '\n'
	r.buffer[n+1] = 0
	r.curPos = 0
}

func (r *Reader) bufStr() string {
	n := bytes.IndexByte(r.buffer[:], 0)
	if n < 0 {
		n = len(r.buffer)
	}
	return string(r.buffer[:n])
}
