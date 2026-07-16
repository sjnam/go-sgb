% 이 문서는 Stanford GraphBase의 gb_io.w((c) 1993 Stanford University)를
% 한글 GWEB(Go)로 옮긴 것으로, Stanford GraphBase의 일부가 아니다.
@i ../types.w

\input kotexgweb
\def\title{GB\_\,IO}

@* 들어가며. 이것은 {\sc GB\_\,IO}, 곧 모든 GraphBase 루틴이 데이터 파일에
접근할 때 쓰는 입출력 모듈이다. 실제로는 출력을 전혀 하지 않지만, 어쩐지
``입출력''이 그냥 ``입력''보다는 쓸모 있는 제목으로 들린다---이 능청은
Knuth의 것이므로 그대로 두기로 한다.

GraphBase 데이터 파일은 존재하는 거의 모든 컴퓨터와 운영체제에서 동일한
결과를 내도록 설계되었다. 모든 줄은 79자를 넘지 않고, 문자는 공백, 숫자,
로마자 대소문자, 표준 문장부호뿐이다. 줄 끝의 공백들은 ``보이지 않는다''---%
즉 아무 효과도 없다. 그래서 모든 줄을 공백으로 채워 저장하는 레코드 지향
시스템에서도 같은 결과가 나온다. 데이터에는 검사합(checksum)이 꼼꼼히 걸려
있어서, 흠 있는 입력 파일이 받아들여질 가능성은 거의 없다.

패키지가 내놓는 것은 파일을 여는 |gbio.Open|(넉 줄의 머리글을 검증한다)과
|gbio.RawOpen|(아무 파일이나 연다), 그리고 |File|의 메서드들---줄 단위로
나아가는 |NextLine|·|EOF|, 줄 안을 파싱하는 |Char|·|Backup|·|Digit|·
|Number|·|String|, 끝맺는 |Close|·|RawClose|---이 전부다. 검사합을 직접
쓰고 싶은 사용자를 위해 |NewChecksum|과 |ImapChr|·|ImapOrd|도 내보낸다.

원본의 상태는 모조리 \CEE/ 전역 변수였다---한 번에 파일 하나만 읽을 수 있다는
뜻이다. 여기서는 그 일습을 |File| 구조체에 거두어들였으므로, 여러 파일을
동시에 읽어도 서로 방해하지 않는다. 원본이 함께 뽑아내던 검증 프로그램
\.{test\_io.c}는 \GO/ 시험 파일 \.{gbio\_test.go}가 되어 마지막 절에서
같은 검사를 수행한다.
@c
package gbio

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"path/filepath"
)

@<입출력 오류@>
@<파일 상태@>
@<줄 읽기@>
@<검사합@>
@<줄 파싱@>
@<파일 열기@>
@<파일 닫기@>

@ 무언가 이상이 감지되면 |IOErrors| 비트 집합에 기록된다. GraphBase
프로그램을 정상적으로 쓰는 동안에는 오류가 일어나지 않으므로, 0이 아닌
값들을 사용자 친화적으로 풀이해 주려는 노력은 하지 않았다. 정보는 그저
이진수로 모일 뿐이니, 문제를 좀 파헤쳐야 할 시스템 도사라면 큰 고통 없이
해독할 수 있을 것이다.

\CEE/에서는 전역 |long| 하나에 비트를 세웠지만, 여기서는 |error|를 구현하는
타입으로 만들어 |Open|과 |Close|가 직접 돌려주게 한다.
@<입출력 오류@>=
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
@#
func (e IOErrors) Error() string {
	return fmt.Sprintf("gbio: 오류 부호 %#x", int64(e))
}

@* 한 줄 읽어들이기. 입력은 늘 |buffer|를 거친다. 원본은 이 배열을 81자로
잡았다---데이터가 한 줄에 최대 79자, 그 뒤에 개행과 널이 오기 때문이다.
\GO/의 슬라이스는 길이를 스스로 알므로 널 종결자는 필요 없지만, 버퍼가
항상 개행으로 끝난다는 원본의 불변식은 그대로 지킨다. 그 덕에 줄 끝을
지나 읽으려는 사용자는 언제까지고 개행 문자만 받게 된다.
검사합·줄 번호 따위의 필드는 아래 절들에서 차차 뜻을 밝힌다.
@<파일 상태@>=
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

@ 버퍼 |buffer|를 채우는 기본 루틴이다. 눈여겨볼 것은 줄 끝 공백의 제거다.
79자 뒤에 개행이 오는 줄은 버퍼에 꼭 맞아 아무 오류도 내지 않는다. 80자
줄은 — \CEE/의 |fgets|가 그랬듯 한 번에 최대 80자만 읽으므로---두 줄로
쪼개지며 |MissingNewline|이 기록된다. 파일이 줄 중간에서 끝나거나 줄 안에
널 문자가 있어도 같은 오류가 난다. 원본은 |fgets|의 명세에 기대었지만
\GO/에는 그런 함수가 없으니, 한 바이트씩 읽어 그 행동을 흉내낸다.

@<줄 읽기@>=
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

@* 검사합. 데이터 파일마다 ``마법의 수(magic number)''가 하나씩 있는데,
그 정의는
$$\biggl(\sum_l 2^l c_l\biggr) \bmod p$$
이다. 여기서 $p$는 큰 소수이고, $c_l$은 뒤에서 $l$번째로 읽힌 데이터
문자(개행은 포함, 널은 제외)의 내부 부호다.

내부 부호 $c_l$은 시스템에 무관하게 계산된다. 실제 인코딩이 무엇이든 각
문자에는 모든 시스템에서 같은 값인 내부 부호가 붙는다. 예컨대 문자
|'0'|의 내부 부호는, ASCII든 EBCDIC이든 다른 무엇이든, 늘 0이다. (현대의
모든 컴퓨터 시스템은 공백을 포함해 적어도 95가지 문자를 찍을 수 있다고
가정한다.)

줄 수가 정확하고 마지막에 올바른 마법의 수가 나오면, 그 데이터 파일은
오류가 없다고 받아들인다. $p$는 검사합 갱신식 $2a+c$가 32비트로도 넘치지
않도록 고른, $2^{30}$보다 작은 가장 큰 소수다.

@<검사합@>=
const checksumPrime = 1<<30 - 83 // 마법의 수를 만드는 큰 소수 $p$

@ 내부 부호는 문자열 |imap| 하나로 정의된다: 문자 |imap[k]|의 내부 부호가
바로 $k$다. |imap|에는 96개 문자---눈에 보이는 표준 ASCII 문자 94개에
공백과 개행---가 들어 있다. (EBCDIC을 쓴다면 왼쪽 홑따옴표 자리에 센트
기호를, 물결표 자리에 또 다른 글자를 놓으라던 시절의 당부가 원본에 남아
있는데, 그 시절을 추억하는 뜻에서 적어 둔다.)

|imap|에 없는 문자들은 모두 같은 내부 부호 |unexpectedChar|를 받는다.
그런 문자는 GraphBase 파일에서 가급적 피해야 한다. |icode| 표는 이중의
소임을 맡는다. 부호 0--15가 |"0123456789ABCDEF"|에서 나오도록 꾸며 두었기
때문에, 십진수와 십육진수---원한다면 그보다 높은 진법까지---의 변환에도
그대로 쓰인다.

\CEE/는 ``|icode['1']|이 아직 0인가?''라는 게으른 초기화 검사를 곳곳에
심어야 했지만, \GO/에서는 패키지가 적재될 때 한 번 계산하면 그만이고,
그 뒤로 이 표는 사실상 상수다.

@<검사합@>=
const unexpectedChar = 127 // |imap|에 없는 문자들의 내부 부호

const imap = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
	"abcdefghijklmnopqrstuvwxyz" +
	"_^~&@@,;.:?!%#$+-*/|\\<=>()[]{}`'\" \n"

var icode = func() (t [256]byte) {
	for i := range t {
		t[i] = unexpectedChar
	}
	for k, c := range []byte(imap) {
		t[c] = byte(k)
	}
	return
}()

@ 사용자는 |imap|을 들여다볼 수는 있지만 바꿀 수는 없다---\CEE/에서는
포인터를 감추어 이를 지켰고, 여기서는 소문자 상수와 두 함수가 자연스럽게
같은 일을 한다.

@<검사합@>=
// |ImapChr|는 내부 부호 |d|에 대응하는 문자를 준다(범위 밖이면 0).
func ImapChr(d int64) byte {
	if d < 0 || d >= int64(len(imap)) {
		return 0
	}
	return imap[d]
}

// |ImapOrd|는 문자 |c|의 내부 부호를 준다.
func ImapOrd(c byte) int64 {
	return int64(icode[c])
}

@ 사용자도 |NextLine|이 하듯 검사합을 계산할 수 있다. 다만 |File| 내부의
|magic| 값을 바꿀 수는 없다.

@<검사합@>=
// |NewChecksum|은 문자열 |s|의 문자들로 검사합 |old|를 갱신한 값을 준다.
func NewChecksum(s string, old int64) int64 {
	a := old
	for i := range len(s) {
		a = (a + a + ImapOrd(s[i])) % checksumPrime
	}
	return a
}

@ |NextLine|은 데이터의 다음 줄을 버퍼로 읽어들이고 마법의 수를 그에 맞게
갱신한다. 단, `\.*'로 시작하는 줄은 검사합에 영향을 주지 않는다---주석
줄이 마법을 깨지 않도록 한 배려다.

@<검사합@>=
// |NextLine|은 데이터 파일의 다음 줄로 나아간다.
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

@ 데이터를 다 읽었는지는 |EOF|로 알아본다.

@<검사합@>=
// |EOF|는 데이터를 다 읽었으면 참이다.
func (f *File) EOF() bool {
	return !f.moreData
}

@* 줄 파싱. 버퍼의 문자는 여러 방법으로 읽을 수 있다. 우선 문자 하나를
돌려주는 기본 루틴 |Char|가 있다. 줄의 마지막 문자를 이미 읽었다면 |'\n'|이
나오고, |NextLine|을 부를 때까지 계속 |'\n'|이 나온다.

|Char|를 부르면 줄 안의 현재 위치 |pos|가 전진한다---이미 줄 끝에
있었다면 그대로다. 반대로 |Backup|은 |pos|를 한 자리 왼쪽으로 옮긴다---%
이미 줄 머리에 있었다면 그대로다.
@<줄 파싱@>=
// |Char|는 현재 줄의 다음 문자를 준다. 줄이 끝났으면 |'\n'|을 준다.
func (f *File) Char() byte {
	if f.pos < len(f.buffer) {
		c := f.buffer[f.pos]
		f.pos++
		return c
	}
	return '\n'
}

// |Backup|은 문자 하나를 다시 읽을 수 있게 물러선다.
func (f *File) Backup() {
	if f.pos > 0 {
		f.pos--
	}
}

@ 수치 데이터를 읽는 방법은 두 가지다. 첫째 |Digit(d)|는 |d|진법 숫자
한 자를 기대한다. 9보다 큰 숫자는 내부 부호로 나타내므로, 예컨대 |'A'|는
십진수 10에 해당하는 십육진 숫자다. 다음 문자가 유효한 |d|진 숫자면
|pos|가 전진하며 그 값이, 아니면 |pos|는 그대로인 채 $-1$이 반환된다.

둘째 |Number(d)|는 숫자 아닌 문자를 만날 때까지 부호 없는 |d|진수를
읽어들인다. 숫자가 하나도 없었으면 0이다. 원본은 ``|unsigned long|
산술이므로 어떤 오류도 나지 않는다''고 자신했는데, \GO/의 |int64|도
넘치면 조용히 감길 뿐 멈추지는 않으니 그 정신은 살아 있다.

원본은 줄 끝의 널 문자가 숫자로 읽히지 않도록 |icode[0]=d|라는 파수꾼
트릭을 썼다. 우리 버퍼에는 널이 아예 없으므로 경계 검사가 그 자리를
대신한다. 진법 |d|는 개행의 내부 부호인 95 이하라야 안전한데, 실제로
쓰이는 진법은 물론 10과 16이다.
@<줄 파싱@>=
// |Digit|은 0과 |d-1| 사이의 숫자 한 자를 읽는다(숫자가 아니면 $-1$).
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

// |Number|는 |d|진법의 부호 없는 수를 읽는다(숫자가 없으면 0).
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

@ 데이터를 가져오는 마지막 루틴 |String(c)|는 |pos|에서 시작해 문자 |c|가
처음 나타나기 직전까지의 문자열을 준다. |c|가 |'\n'|이면 줄 끝까지다.
|c|가 나타나지 않으면 줄 끝에 늘 놓여 있는 개행이 문자열의 마지막 문자가
되고, 줄을 이미 다 읽은 뒤라면 빈 문자열이 나온다. 복사가 끝나면 |pos|는
문자열 너머로 — 단 |c| 앞까지만 — 전진한다.

원본의 |gb_string(p,c)|는 결과를 받을 81바이트짜리 안전지대 |str_buf|를
따로 마련해 두고, 이어 쓰기 좋도록 저장된 문자열 바로 뒤의 위치를
돌려주는 규약까지 두었다. \GO/의 |string| 반환 앞에서 그 모든 조심성은
연기처럼 사라진다.

@<줄 파싱@>=
// |String|은 문자 |c| 직전까지의 문자열을 읽는다.
func (f *File) String(c byte) string {
	start := f.pos
	for f.pos < len(f.buffer) && f.buffer[f.pos] != c {
		f.pos++
	}
	return string(f.buffer[start:f.pos])
}

@* 파일 열기. |RawOpen("foo")|는 파일 \.{foo}를 열고 검사합 계산을
준비한다. 파일이 열리지 않으면 |CantOpenFile|을 오류로 돌려준다.

원본은 파일이 안 열리면 컴파일 때 정한 \.{DATA\_DIRECTORY}를 접두어로 붙여
한 번 더 시도했다. 우리는 그 스위치를 없앴다---경로는 호출자가 다루는
것이 \GO/답고, 이 저장소의 데이터 파일은 관례상 \.{data/} 밑에 있다.

옛 링커 중에는 외부 이름을 몇 자로 싹둑 잘라 버리는 것들이 있어서, 원본은
|gb_raw_open|을 |gb_r_open|이라는 별칭으로도 내보냈다---프로크루스테스의
침대에 눕힌 ``외부 연결(Procrustean external linkage)''이라는 농담과 함께.
\GO/의 링커는 이름을 자르지 않으므로 침대는 치웠다.

@<파일 열기@>=
// |RawOpen|은 아무 파일이나 열어 GraphBase 입력을 준비한다.
func RawOpen(name string) (*File, error) {
	file, err := os.Open(name)
	if err != nil {
		return nil, CantOpenFile
	}
	f := &File{
		file:     file,
		rd:       bufio.NewReader(file),
		name:     filepath.Base(name),
		moreData: true,
		totLines: 0x7fffffff, // ``무한히 많은'' 줄을 허용
	}
	f.fillBuf()
	return f, nil
}

@ |Open("foo")|은 |RawOpen|의 좀 더 억센 판본으로, \.{words.dat} 같은
표준 GraphBase 데이터 파일이 조금도 손상되지 않았음을 거듭 확인하는 데
쓰인다. 전형적인 데이터 파일의 처음 넉 줄은 이렇게 생겼다:
$$\vbox{\halign{\quad\.{#}\hfill\cr
* File "words.dat" from the Stanford GraphBase (C) 1993 Stanford University\cr
* A database of English five-letter words\cr
* This file may be freely copied but please do not change it in any way!\cr
* (Checksum parameters 5757,526296596)\cr}}$$
실제로 검증하는 것은: 첫째 줄이 |"* File "|와 따옴표에 싸인 파일 이름으로
시작하는가, 둘째·셋째 줄이 \.*로 시작하는가, 넷째 줄이 두 십진수 $l$,~$m$을
담은 검사합 매개변수 줄인가---이 넷이다. $l$과 $m$은 |totLines|와
|finalMagic|에 갈무리되었다가 파일 끝에서 대조된다.

머리글 넉 줄은 |fillBuf|로 직접 읽는다. |NextLine|을 거치지 않으므로 줄
번호에도, 마법의 수에도 셈해지지 않는다. \CEE/는 검사 절마다 |io_errors|에
비트를 세워 곧장 반환하는 문장을 되풀이했는데, 여기서는 실패의 뒤처리---%
파일을 도로 닫고 오류를 돌려주는---를 작은 클로저 |bad|에 맡긴다.

@<파일 열기@>=
// |Open|은 GraphBase 데이터 파일을 열고 머리글 넉 줄을 검증한다.
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
	@<첫째 줄을 검사한다@>
	@<둘째, 셋째 줄을 검사한다@>
	@<넷째 줄을 검사한다@>
	f.NextLine() // 이제 첫 실제 데이터 줄이 버퍼에 있다
	return f, nil
}

@ 첫째 줄은 |RawOpen|의 |fillBuf|가 이미 버퍼에 담아 두었다. 호출자가
경로를 붙여 열었어도 파일 속 이름은 맨 이름이므로, |f.name|에는 경로를
뗀 이름이 들어 있다.

@<첫째 줄을 검사한다@>=
if !bytes.HasPrefix(f.buffer, []byte("* File \""+f.name+"\"")) {
	return bad(BadFirstLine)
}

@ @<둘째, 셋째 줄을 검사한다@>=
f.fillBuf()
if f.buffer[0] != '*' {
	return bad(BadSecondLine)
}
f.fillBuf()
if f.buffer[0] != '*' {
	return bad(BadThirdLine)
}

@ @<넷째 줄을 검사한다@>=
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

@* 파일 닫기. 데이터를 다 읽었으면---혹은 다 읽었어야 하는 시점이면---%
파일이 정말 열려 있었는지, 줄 수와 마법의 수가 맞는지, 마지막 줄이
올바른지 확인한다. |Close|는 문제가 하나라도 눈에 띄었으면 그 |IOErrors|를,
아니면 |nil|을 돌려준다.

@<파일 닫기@>=
// |Close|는 GraphBase 데이터 파일을 닫으며 줄 수와 검사합을 대조한다.
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

@ 덜 의심 많은 |RawClose|도 있다. 사용자가 만든 파일을 닫을 때 쓰는
것으로, 그저 파일을 닫고 |magic| 검사합을 돌려준다. 나중에 {\sc GB\_\,SAVE}의
그래프 복원 루틴이 |RawOpen|과 |RawClose|로---표준 데이터 파일 읽기에
버금가게 든든한---시스템 독립 입력을 꾸리는 것을 보게 될 것이다.

@<파일 닫기@>=
// |RawClose|는 파일을 닫고 검사합을 돌려준다.
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

@* 시험. 원본의 \.{test\_io}가 하던 검사를 그대로 옮긴다. 시험 데이터
\.{test.dat}의 첫째 줄은 0이 64개 나온 뒤 \.{123456789ABCDEF}로 끝나는
79자다. 둘째 줄은 완전히 비어 있고, 셋째이자 마지막 줄은
\.{Oops:(intentional mistake)}라고 말한다.

십진수 읽기는 0들을 지나 123456789에서 멈추어야 하고(그다음 \.A는 십진
숫자가 아니다), 그 \.A는 십육진 숫자 10으로 읽혀야 한다. 두 번 물러서서
\.{9A}부터 십육진수로 다시 읽으면 |0x9ABCDEF|다. 빈 줄에서는 어디를
읽어도 개행뿐이고, 수는 0이고, 문자열은 비어 있다. 마지막 줄에서 |':'|
직전까지 읽은 문자열은 \.{Oops}다. 그러고 나서 |Digit|이 |':'|를 숫자로
착각하지 않는지, 파일 끝이 너무 이르지도 늦지도 않게 오는지, |Close|의
검사합 대조가 통과하는지 본다.

@(gbio_test.go@>=
package gbio

import "testing"

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
	@<빈 줄과 마지막 줄을 검사한다@>
	@<파일의 끝을 검사한다@>
}

@ @<빈 줄과 마지막 줄을 검사한다@>=
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

@ @<파일의 끝을 검사한다@>=
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

@* 찾아보기.
