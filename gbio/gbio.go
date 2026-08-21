//line gbio.w:38
package gbio

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"path/filepath"
)

//line gbio.w:65
type IOErrors int64

const (
	CantOpenFile         IOErrors = 1 << iota // 파일 열기가 실패했다
	CantCloseFile                             // 파일 닫기가 실패했다
	BadFirstLine                              // 데이터 파일의 첫째 줄이 온당치 않다
	BadSecondLine                             // 둘째 줄이 검사를 통과하지 못했다
	BadThirdLine                              // 셋째 줄이 비뚤어져 있다
	BadFourthLine                             // 이 비트가 언제 켜지는지는 짐작에 맡긴다
	FileEndedPrematurely                      // 줄을 읽는 도중 파일이 끝났다
	MissingNewline                            // 줄이 너무 길거나 개행이 없다
	WrongNumberOfLines                        // 줄 수가 틀렸다
	WrongChecksum                             // 검사합이 틀렸다
	NoFileOpen                                // 열려 있지 않은 파일을 닫으려 했다
	BadLastLine                               // 마지막 줄의 형식이 틀렸다
)

func (e IOErrors) Error() string {
	return fmt.Sprintf("gbio: 오류 부호 %#x", int64(e))
}

//line gbio.w:93
type File struct {
	file       *os.File      // 열린 파일; 닫힌 뒤에는 |nil|
	rd         *bufio.Reader // |file|을 감싼 버퍼 입력
	name       string        // 머리글과 꼬리글 검사에 쓰는, 경로를 뗀 파일 이름
	buffer     []byte        // 현재 줄; 항상 |'\n'|으로 끝난다
	pos        int           // 지금 관심 있는 문자의 위치
	moreData   bool          // 아직 읽을 데이터가 남아 있는가?
	lineNo     int64         // 파일 안에서의 현재 줄 번호
	totLines   int64         // 데이터 줄의 총수
	magic      int64         // 현재까지의 검사합
	finalMagic int64         // 마지막에 나와야 할 검사합
	errors     IOErrors      // 지금까지 눈에 띈 이상들
}

//line gbio.w:115
func (f *File) fillBuf() {
	f.buffer = f.buffer[:0]
	for len(f.buffer) < 80 {
		c, err := f.rd.ReadByte()
		if err != nil {
			if len(f.buffer) == 0 {
				f.errors |= FileEndedPrematurely
				f.moreData = false
			}
			break
		}
		f.buffer = append(f.buffer, c)
		if c == '\n' {
			break
		}
	}
	if k := bytes.IndexByte(f.buffer, 0); k >= 0 {
		f.buffer = f.buffer[:k] // 널 문자에서 줄이 끊긴 셈 친다
	}
	if n := len(f.buffer); n == 0 || f.buffer[n-1] != '\n' {
		f.errors |= MissingNewline
	} else {
		f.buffer = f.buffer[:n-1]
	}
	for len(f.buffer) > 0 && f.buffer[len(f.buffer)-1] == ' ' {
		f.buffer = f.buffer[:len(f.buffer)-1] // 줄 끝 공백을 걷어낸다
	}
	f.buffer = append(f.buffer, '\n')
	f.pos = 0
}

//line gbio.w:163
const checksumPrime = 1<<30 - 83 // 마법의 수를 만드는 큰 소수 $p$

//line gbio.w:182
const unexpectedChar = 127 // |imap|에 없는 문자들의 내부 부호

const imap = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
	"abcdefghijklmnopqrstuvwxyz" +
	"_^~&@,;.:?!%#$+-*/|\\<=>()[]{}`'\" \n"

var icode = func() (t [256]byte) {
	for i := range t {
		t[i] = unexpectedChar
	}
	for k, c := range []byte(imap) {
		t[c] = byte(k)
	}
	return
}()

//line gbio.w:203
func ImapChr(d int64) byte {
	if d < 0 || d >= int64(len(imap)) {
		return 0
	}
	return imap[d]
}

func ImapOrd(c byte) int64 {
	return int64(icode[c])
}

//line gbio.w:218
func NewChecksum(s string, old int64) int64 {
	a := old
	for i := range len(s) {
		a = (a + a + ImapOrd(s[i])) % checksumPrime
	}
	return a
}

//line gbio.w:231
func (f *File) NextLine() {
	f.lineNo++
	if f.lineNo > f.totLines {
		f.moreData = false
	}
	if f.moreData {
		f.fillBuf()
		if f.buffer[0] != '*' {
			f.magic = NewChecksum(string(f.buffer), f.magic)
		}
	}
}

//line gbio.w:247
func (f *File) EOF() bool {
	return !f.moreData
}

//line gbio.w:259
func (f *File) Char() byte {
	if f.pos < len(f.buffer) {
		c := f.buffer[f.pos]
		f.pos++
		return c
	}
	return '\n'
}

func (f *File) Backup() {
	if f.pos > 0 {
		f.pos--
	}
}

//line gbio.w:289
func (f *File) Digit(d int64) int64 {
	if f.pos == len(f.buffer) {
		return -1
	}
	v := ImapOrd(f.buffer[f.pos])
	if v >= d {
		return -1
	}
	f.pos++
	return v
}

func (f *File) Number(d int64) int64 {
	var a int64
	for f.pos < len(f.buffer) {
		v := ImapOrd(f.buffer[f.pos])
		if v >= d {
			break
		}
		a = a*d + v
		f.pos++
	}
	return a
}

//line gbio.w:326
func (f *File) String(c byte) string {
	start := f.pos
	for f.pos < len(f.buffer) && f.buffer[f.pos] != c {
		f.pos++
	}
	return string(f.buffer[start:f.pos])
}

//line gbio.w:347
func RawOpen(name string) (*File, error) {
	baseName := filepath.Base(name)
	file, err := os.Open(name)
	if err != nil {
		file, err = os.Open(filepath.Join("/usr/local/sgb/data", baseName))
		if err != nil {
			return nil, CantOpenFile
		}
	}
	f := &File{
		file:     file,
		rd:       bufio.NewReader(file),
		name:     baseName,
		moreData: true,
		totLines: 0x7fffffff, // ``무한히 많은'' 줄을 허용
	}
	f.fillBuf()
	return f, nil
}

//line gbio.w:386
func Open(name string) (*File, error) {
	f, err := RawOpen(name)
	if err != nil {
		return nil, err
	}
	bad := func(bit IOErrors) (*File, error) {
		f.file.Close()
		f.errors |= bit
		return nil, f.errors
	}

//line gbio.w:408
	if !bytes.HasPrefix(f.buffer, []byte("* File \""+f.name+"\"")) {
		return bad(BadFirstLine)
	}

//line gbio.w:397

//line gbio.w:413
	f.fillBuf()
	if f.buffer[0] != '*' {
		return bad(BadSecondLine)
	}
	f.fillBuf()
	if f.buffer[0] != '*' {
		return bad(BadThirdLine)
	}

//line gbio.w:398

//line gbio.w:423
	f.fillBuf()
	if !bytes.HasPrefix(f.buffer, []byte("* (Checksum parameters ")) {
		return bad(BadFourthLine)
	}
	f.pos = 23
	f.totLines = f.Number(10)
	if f.Char() != ',' {
		return bad(BadFourthLine)
	}
	f.finalMagic = f.Number(10)
	if f.Char() != ')' {
		return bad(BadFourthLine)
	}

//line gbio.w:399
	f.NextLine() // 이제 첫 실제 데이터 줄이 버퍼에 있다
	return f, nil
}

//line gbio.w:447
func (f *File) Close() error {
	if f.file == nil {
		f.errors |= NoFileOpen
		return f.errors
	}
	f.fillBuf()
	if !bytes.HasPrefix(f.buffer, []byte("* End of file \""+f.name+"\"")) {
		f.errors |= BadLastLine
	}
	f.buffer = f.buffer[:0] // 이로써 입출력 루틴은 사실상 멈춘다
	f.pos = 0
	f.moreData = false
	err := f.file.Close()
	f.file = nil
	if err != nil {
		f.errors |= CantCloseFile
	} else if f.lineNo != f.totLines+1 {
		f.errors |= WrongNumberOfLines
	} else if f.magic != f.finalMagic {
		f.errors |= WrongChecksum
	}
	if f.errors != 0 {
		return f.errors
	}
	return nil
}

//line gbio.w:480
func (f *File) RawClose() int64 {
	if f.file != nil {
		f.file.Close()
		f.buffer = f.buffer[:0]
		f.pos = 0
		f.moreData = false
		f.file = nil
	}
	return f.magic
}
