//line gbio.w:505
package gbio

import (
	"os"
	"path/filepath"
	"testing"
)

func TestIO(t *testing.T) {
	f, err := Open("../data/test.dat")
	if err != nil {
		t.Fatalf("test.dat를 열 수 없다: %v", err)
	}
	if v := f.Number(10); v != 123456789 {
		t.Fatalf("십진수 읽기가 고장났다 (%d)", v)
	}
	if v := f.Digit(16); v != 10 {
		t.Fatalf("십진수 뒤의 A를 놓쳤다 (%d)", v)
	}
	f.Backup()
	f.Backup() // 9A부터 다시 읽을 채비
	if v := f.Number(16); v != 0x9ABCDEF {
		t.Fatalf("십육진수 읽기가 고장났다 (%#x)", v)
	}

//line gbio.w:534
	f.NextLine() // 이제 빈 줄을 훑고 있어야 한다
	if f.Char() != '\n' {
		t.Fatal("줄 끝에 개행이 없다")
	}
	if f.Char() != '\n' {
		t.Fatal("줄 끝을 지나도 개행이 나와야 한다")
	}
	if f.Number(60) != 0 {
		t.Fatal("수는 줄 끝에서 멈춰야 한다")
	}
	if s := f.String('\n'); s != "" {
		t.Fatalf("줄 끝을 지난 문자열은 비어야 한다 (%q)", s)
	}
	f.NextLine()
	if s := f.String(':'); s != "Oops" {
		t.Fatalf("문자열이 제대로 읽히지 않았다 (%q)", s)
	}

//line gbio.w:530

//line gbio.w:553
	if f.Digit(10) != -1 {
		t.Fatal("숫자 아님이 감지되지 않았다")
	}
	if f.Char() != ':' {
		t.Fatal("String과 Digit 뒤에 자리를 잃었다")
	}
	if f.EOF() {
		t.Fatal("파일 끝 신호가 너무 이르다")
	}
	f.NextLine()
	if !f.EOF() {
		t.Fatal("파일 끝 신호가 너무 늦다")
	}
	if err := f.Close(); err != nil {
		t.Fatalf("검사합이 틀렸거나 파일을 닫지 못했다: %v", err)
	}

//line gbio.w:531
}

//line gbio.w:576
func TestOpenChecksHeader(t *testing.T) {
	good, err := os.ReadFile("../data/test.dat")
	if err != nil {
		t.Fatal(err)
	}
	cases := []struct {
		name string
		line int
		want IOErrors
	}{
		{"첫째 줄", 0, BadFirstLine},
		{"둘째 줄", 1, BadSecondLine},
		{"셋째 줄", 2, BadThirdLine},
		{"넷째 줄", 3, BadFourthLine},
	}
	for _, c := range cases {

//line gbio.w:601
		lines := splitLines(good)
		lines[c.line] = "x"
		dir := t.TempDir()
		path := filepath.Join(dir, "test.dat")
		if err := os.WriteFile(path, joinLines(lines), 0o644); err != nil {
			t.Fatal(err)
		}
		_, err := Open(path)
		ioe, ok := err.(IOErrors)
		if !ok || ioe&c.want == 0 {
			t.Errorf("%s를 망가뜨렸는데 오류가 %v다", c.name, err)
		}

//line gbio.w:593
	}

//line gbio.w:618
	if _, err := Open(filepath.Join(t.TempDir(), "없는파일.dat")); err == nil {
		t.Error("없는 파일을 열었는데 오류가 없다")
	}
	lines := splitLines(good)
	lines[4] = "1" + lines[4][1:] // 첫 데이터 줄의 한 글자를 0에서 1로 바꾼다
	dir := t.TempDir()
	path := filepath.Join(dir, "test.dat")
	if err := os.WriteFile(path, joinLines(lines), 0o644); err != nil {
		t.Fatal(err)
	}
	f, err := Open(path)
	if err != nil {
		t.Fatalf("머리글은 멀쩡한데 열지 못했다: %v", err)
	}
	for !f.EOF() {
		f.NextLine()
	}
	if err := f.Close(); err == nil {
		t.Error("검사합이 어긋났는데 Close가 통과했다")
	}

//line gbio.w:595
}

//line gbio.w:643
func splitLines(b []byte) []string {
	var out []string
	start := 0
	for i, c := range b {
		if c == '\n' {
			out = append(out, string(b[start:i]))
			start = i + 1
		}
	}
	return out
}

func joinLines(lines []string) []byte {
	var out []byte
	for _, l := range lines {
		out = append(out, l...)
		out = append(out, '\n')
	}
	return out
}
