% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_save.w를 Go로 이식한다.
@i ../types.w

\input kotexgweb
\def\title{GB\_\,SAVE}

@* 들어가며. 이 모듈은 두 유틸리티 |SaveGraph|와 |RestoreGraph|를 담는다.
그래프를 {\sc GB\_GRAPH}이 설명한 내부 표현과, 사람과 기계가 함께 읽을 수 있는
기호적 파일 형식 사이에서 오가게 한다. 연구자는 이 둘로 그래프를 기계와 무관하게
컴퓨터 사이에 옮기거나, 같은 형식을 지원하는 다른 그래프 소프트웨어와 주고받을
수 있다.

\CEE/ 원본은 온갖 포인터가 원시 메모리 블록의 어디에 있는지 손수 분류하는
정교한 기계(``block\_rep'')를 갖춰야 했다. 그러나 \GO/에서는 무엇이 정점이고
무엇이 호이며 무엇이 문자열인지 타입이 이미 말해 주므로, 그 기계 전체가 필요
없다. 정점은 |g.Vertices|에 있고, 호는 정점의 |Arcs| 리스트를 훑어 모으며,
문자열은 그냥 |string|이다. 그래서 우리 |SaveGraph|는 원본보다 훨씬 단출하다.

제약: 문자열에는 표준 인쇄 가능 문자만 담기며(\.\\나 \."나 줄바꿈은 안 됨),
|g.ID|는 154자 이하여야 한다. \.G(그래프 속 그래프) 유틸리티 타입은 허용하지
않는다.

@ 파일 형식은 다음 예가 잘 보여 준다.
$$\vbox{\halign{\.{#}\hfil\cr
* GraphBase graph (util\_types IZAZZZZVZZZZSZ,3V,4A)\cr
"pi",1,3,"pi"\cr
* Vertices\cr
"look",A0,15,A1\cr
"feel",0,-9,A1\cr
* Arcs\cr
V0,A2,3,V1\cr
V1,0,5,0\cr
* Checksum 271828\cr}}$$
첫 줄은 |util_types| 14자와 정점·호 레코드 총수를 준다. 다음 줄(들)은 |Graph|
레코드의 |ID|·|N|·|M|과 무시되지 않는 그래프 유틸리티 필드를 준다. 그 뒤
`\.{* Vertices}' 다음에 각 정점의 |Name|·|Arcs|와 유틸리티 필드가, `\.{* Arcs}'
다음에 각 호의 |Tip|·|Next|·|Len|과 유틸리티 필드가 온다. 정점 포인터는
|V|〈번호〉, 호 포인터는 |A|〈번호〉, |nil|은 |0|으로 쓴다(정점 포인터는 특별한
값 |1|도 가질 수 있다). 필드는 쉼표로 나뉘고, 줄이 쉼표로 끝나면 다음 줄에 같은
레코드의 필드가 이어진다. 문자열은 줄 끝을 \.\\로 맺어 여러 줄로 나눌 수 있다.
`\.{* Checksum}' 줄이 자료의 검사합을 확인한다.

@ 프로그램의 뼈대다. |gbio|의 입출력 관례로 파일을 읽고, 표준 라이브러리로
쓴다. |util_types|의 각 자리가 어느 유틸리티 필드를 가리키는지 짚어 주는 세
도우미(정점·호·그래프)를 먼저 둔다.

@c
package gbsave

import (
	"bufio"
	"os"
	"strconv"
	"strings"
	@#
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
)

const (
	maxSvID        = 154 // |ID|의 최대 길이
	unexpectedChar = 127 // |imap|에 없는 문자
)

@<유틸리티 필드 도우미@>
@<그래프를 되살리는 |RestoreGraph|@>
@<그래프를 저장하는 |SaveGraph|@>

@ |util_types|의 자리 0--5는 정점의 |U|--|Z|, 6--7은 호의 |A|--|B|, 8--13은
그래프의 |UU|--|ZZ|에 대응한다. 각 도우미는 그 자리의 유틸리티 필드를 가리키는
포인터를 준다.

@<유틸리티 필드 도우미@>=
func vertUtil(v *gbgraph.Vertex, pos int) *gbgraph.Util {
	switch pos {
	case 0:
		return &v.U
	case 1:
		return &v.V
	case 2:
		return &v.W
	case 3:
		return &v.X
	case 4:
		return &v.Y
	default:
		return &v.Z
	}
}

@ @<유틸리티 필드 도우미@>=
func arcUtil(a *gbgraph.Arc, pos int) *gbgraph.Util {
	if pos == 6 {
		return &a.A
	}
	return &a.B
}

func graphUtil(g *gbgraph.Graph, pos int) *gbgraph.Util {
	switch pos {
	case 8:
		return &g.UU
	case 9:
		return &g.VV
	case 10:
		return &g.WW
	case 11:
		return &g.XX
	case 12:
		return &g.YY
	default:
		return &g.ZZ
	}
}

@* 그래프 되살리기. |RestoreGraph("foo.gb")|는 파일 |"foo.gb"|에 정의된 그래프를
가리키는 포인터를 준다. 파일을 읽을 수 없거나 형식이 틀리면 오류다.

읽기 상태(파일, 만들 그래프, 호 배열, 쉼표 기대 여부)를 |reader| 구조체에 담는다.
\CEE/ 원본이 전역 변수로 하던 일을, 우리는 구조체로 또렷이 한다.

@<그래프를 되살리는 |RestoreGraph|@>=
type reader struct {
	f             *gbio.File
	g             *gbgraph.Graph
	arcs          []gbgraph.Arc
	commaExpected bool
}

// |RestoreGraph|는 |.gb| 파일을 읽어 그래프를 되살린다.
func RestoreGraph(filename string) (*gbgraph.Graph, error) {
	f, err := gbio.RawOpen(filename)
	if err != nil {
		return nil, gbgraph.EarlyDataFault
	}
	r := &reader{f: f}
	utilTypes, nV, mA, err := r.parseHeader()
	if err != nil {
		f.RawClose()
		return nil, err
	}
	r.g = &gbgraph.Graph{Vertices: make([]gbgraph.Vertex, nV), UtilTypes: utilTypes}
	r.arcs = make([]gbgraph.Arc, mA)
	@<그래프·정점·호 레코드를 읽는다@>
	@<짝 호를 잇고 검사합을 확인한다@>
	return r.g, nil
}

@ 첫 줄에서 |util_types|(14자)와 정점 수 |nV|, 호 수 |mA|를 뽑는다. \.* 로
시작하는 앞선 주석 줄들은 건너뛴다.

@<그래프를 되살리는 |RestoreGraph|@>=
func (r *reader) parseHeader() (string, int64, int64, error) {
	for {
		line := r.f.String(')')
		if idx := strings.Index(line, "(util_types "); idx >= 0 {
			rest := line[idx+len("(util_types "):]
			parts := strings.Split(rest, ",")
			if len(parts) == 3 && len(parts[0]) == 14 {
				n, e1 := strconv.ParseInt(strings.TrimSuffix(parts[1], "V"), 10, 64)
				m, e2 := strconv.ParseInt(strings.TrimSuffix(parts[2], "A"), 10, 64)
				if e1 == nil && e2 == nil {
					r.f.NextLine()
					return parts[0], n, m, nil
				}
			}
		}
		if len(line) == 0 || line[0] != '*' {
			return "", 0, 0, gbgraph.SyntaxError
		}
		r.f.NextLine()
	}
}

@ 그래프 레코드는 |ID| 문자열로 시작해 |N|·|M|과 그래프 유틸리티 필드가 잇는다.
그다음 `\.{* Vertices}'와 정점들, `\.{* Arcs}'와 호들이 온다.

@<그래프를 되살리는 |RestoreGraph|@>=
func (r *reader) parseGraphRecord() error {
	if r.f.Char() != '"' {
		return gbgraph.SyntaxError
	}
	id, ok := r.readString()
	if !ok {
		return gbgraph.SyntaxError
	}
	r.g.ID = id
	r.commaExpected = true
	var n, m gbgraph.Util
	if err := r.field(&n, 'I'); err != nil {
		return err
	}
	if err := r.field(&m, 'I'); err != nil {
		return err
	}
	r.g.N, r.g.M = n.I, m.I
	for pos := 8; pos <= 13; pos++ {
		if err := r.field(graphUtil(r.g, pos), r.g.UtilTypes[pos]); err != nil {
			return err
		}
	}
	return r.finishRecord()
}

@ @<그래프·정점·호 레코드를 읽는다@>=
if err := r.parseGraphRecord(); err != nil {
	f.RawClose()
	return nil, err
}
if r.f.String('\n') != "* Vertices" {
	f.RawClose()
	return nil, gbgraph.SyntaxError
}
r.f.NextLine()
for i := range r.g.Vertices {
	v := &r.g.Vertices[i]
	if err := r.parseVertex(v); err != nil {
		f.RawClose()
		return nil, err
	}
}
if r.f.String('\n') != "* Arcs" {
	f.RawClose()
	return nil, gbgraph.SyntaxError
}
r.f.NextLine()
for i := range r.arcs {
	if err := r.parseArc(&r.arcs[i]); err != nil {
		f.RawClose()
		return nil, err
	}
}

@ 정점 레코드는 |Name|·|Arcs|와 여섯 유틸리티 필드로, 호 레코드는 |Tip|·|Next|·
|Len|과 두 유틸리티 필드로 이루어진다.

@<그래프를 되살리는 |RestoreGraph|@>=
func (r *reader) parseVertex(v *gbgraph.Vertex) error {
	r.commaExpected = false
	var name, arcs gbgraph.Util
	if err := r.field(&name, 'S'); err != nil {
		return err
	}
	if err := r.field(&arcs, 'A'); err != nil {
		return err
	}
	v.Name, v.Arcs = name.S, arcs.A
	for pos := 0; pos <= 5; pos++ {
		if err := r.field(vertUtil(v, pos), r.g.UtilTypes[pos]); err != nil {
			return err
		}
	}
	return r.finishRecord()
}

func (r *reader) parseArc(a *gbgraph.Arc) error {
	r.commaExpected = false
	var tip, next, length gbgraph.Util
	if err := r.field(&tip, 'V'); err != nil {
		return err
	}
	if err := r.field(&next, 'A'); err != nil {
		return err
	}
	if err := r.field(&length, 'I'); err != nil {
		return err
	}
	a.Tip, a.Next, a.Len = tip.V, next.A, length.I
	for pos := 6; pos <= 7; pos++ {
		if err := r.field(arcUtil(a, pos), r.g.UtilTypes[pos]); err != nil {
			return err
		}
	}
	return r.finishRecord()
}

@ |field|는 한 필드를 그 타입 부호에 따라 채운다. 첫 필드가 아니면 앞에 쉼표를
기다린다. 줄이 쉼표로 끝났으면 다음 줄로 넘어간다.

@<그래프를 되살리는 |RestoreGraph|@>=
func (r *reader) field(u *gbgraph.Util, t byte) error {
	if t != 'Z' && r.commaExpected {
		if r.f.Char() != ',' {
			return gbgraph.SyntaxError
		}
		if r.f.Char() == '\n' {
			r.f.NextLine()
		} else {
			r.f.Backup()
		}
	}
	r.commaExpected = true
	if t == 'Z' {
		return nil
	}
	c := r.f.Char()
	switch t {
	case 'I':
		@<수치 필드를 채운다@>
	case 'V':
		@<정점 포인터를 채운다@>
	case 'A':
		@<호 포인터를 채운다@>
	case 'S':
		@<문자열 포인터를 채운다@>
	}
	return nil
}

@ @<수치 필드를 채운다@>=
if c == '-' {
	u.I = -r.f.Number(10)
} else {
	r.f.Backup()
	u.I = r.f.Number(10)
}

@ 정점 포인터는 |V|〈번호〉이거나, |nil|을 뜻하는 |0|, 특별한 값 |1|이다.

@<정점 포인터를 채운다@>=
switch {
case c == 'V':
	k := r.f.Number(10)
	if k < 0 || k >= int64(len(r.g.Vertices)) {
		return gbgraph.SyntaxError
	}
	u.V = &r.g.Vertices[k]
case c == '1':
	u.I = 1 // {\sc GB\_GATES}의 특별한 값
case c == '0':
	// |nil|; 이미 0이다
default:
	return gbgraph.SyntaxError
}

@ @<호 포인터를 채운다@>=
switch {
case c == 'A':
	k := r.f.Number(10)
	if k < 0 || k >= int64(len(r.arcs)) {
		return gbgraph.SyntaxError
	}
	u.A = &r.arcs[k]
case c == '0':
	// |nil|
default:
	return gbgraph.SyntaxError
}

@ 문자열은 여는 따옴표로 시작한다. |readString|이 줄을 이어 붙여 닫는 따옴표까지
읽는다.

@<문자열 포인터를 채운다@>=
if c != '"' {
	return gbgraph.SyntaxError
}
s, ok := r.readString()
if !ok {
	return gbgraph.SyntaxError
}
u.S = s

@ |readString|은 여는 따옴표를 이미 읽었다고 보고, 닫는 따옴표까지의 내용을
준다. 줄 끝이 \.\\로 맺어졌으면 다음 줄과 이어 붙인다.

@<그래프를 되살리는 |RestoreGraph|@>=
func (r *reader) readString() (string, bool) {
	var sb strings.Builder
	for {
		chunk := r.f.String('"')
		switch {
		case strings.HasSuffix(chunk, "\\\n"):
			sb.WriteString(chunk[:len(chunk)-2])
			r.f.NextLine()
		case strings.HasSuffix(chunk, "\n"):
			return "", false // 닫히지 않은 문자열
		default:
			sb.WriteString(chunk)
			r.f.Char() // 닫는 따옴표를 삼킨다
			return sb.String(), true
		}
	}
}

func (r *reader) finishRecord() error {
	if r.f.Char() != '\n' {
		return gbgraph.SyntaxError
	}
	r.f.NextLine()
	r.commaExpected = false
	return nil
}

@ 마지막으로 짝 호를 잇는다. |save_graph|가 짝을 이웃하게 뽑아 두므로, 되살린
호 배열에서 이웃한 둘($2k$, $2k+1$)이 서로의 짝이다(\CEE/의 |edge_trick|을
흉내 낸다). 그래야 무향 그래프 연산이 |Partner|를 따라갈 수 있다. 되살린 호를
파일 순서 그대로 |g|의 저장고에 등록하면, 이 그래프를 다시 저장했을 때 원본과
글자까지 같은 파일이 나온다. 그다음 검사합을 확인한다.

@<짝 호를 잇고 검사합을 확인한다@>=
for i := 0; i+1 < len(r.arcs); i += 2 {
	r.arcs[i].Partner = &r.arcs[i+1]
	r.arcs[i+1].Partner = &r.arcs[i]
}
store := make([]*gbgraph.Arc, len(r.arcs))
for i := range r.arcs {
	store[i] = &r.arcs[i]
}
r.g.SetArcStore(store)
line := r.f.String('\n')
magic := r.f.RawClose()
var sum int64
if _, err := parseChecksum(line, &sum); err != nil {
	return nil, gbgraph.SyntaxError
}
if sum >= 0 && magic != sum {
	return nil, gbgraph.LateDataFault
}

@ 검사합 줄 `\.{* Checksum }〈수〉'에서 수를 뽑는 소박한 도우미다.

@<그래프를 되살리는 |RestoreGraph|@>=
func parseChecksum(line string, sum *int64) (int, error) {
	const prefix = "* Checksum "
	if !strings.HasPrefix(line, prefix) {
		return 0, strconv.ErrSyntax
	}
	v, err := strconv.ParseInt(strings.TrimSpace(line[len(prefix):]), 10, 64)
	if err != nil {
		return 0, err
	}
	*sum = v
	return 1, nil
}

@* 그래프 저장하기. |SaveGraph(g, "foo.gb")|는 |RestoreGraph("foo.gb")|로
|g|와 동등한 그래프를 되살릴 수 있는 파일을 만든다. |g|가 |nil|이거나 파일을
열 수 없으면 오류다.

쓰기 상태를 |writer| 구조체에 담는다. 물리적 줄 하나를 |buf|에 쌓다가 79자를
넘기기 전에 흘려보내며, 그때마다 검사합 |magic|을 갱신한다. \.* 로 시작하는
표시 줄은 검사합에서 빠지므로 곧장 쓴다.

@<그래프를 저장하는 |SaveGraph|@>=
type writer struct {
	out           *bufio.Writer
	buf           []byte
	magic         int64
	commaExpected bool
}

func (w *writer) flushLine() {
	w.buf = append(w.buf, '\n')
	w.magic = gbio.NewChecksum(string(w.buf), w.magic)
	w.out.Write(w.buf)
	w.buf = w.buf[:0]
}

@ |moveItem|은 항목을 현재 줄에 이어 붙이되, 79자를 넘으면 새 줄로 넘긴다.
항목 자체가 너무 길면(긴 문자열뿐이다) \.\\로 여러 줄에 나눈다.

@<그래프를 저장하는 |SaveGraph|@>=
func (w *writer) moveItem(item string) {
	if len(w.buf)+len(item) <= 78 {
		w.buf = append(w.buf, item...)
		return
	}
	if len(item) <= 78 {
		w.flushLine()
		w.buf = append(w.buf, item...)
		return
	}
	if len(w.buf) > 77 {
		w.flushLine()
	}
	rem := item
	for len(w.buf)+len(rem) > 78 {
		n := 78 - len(w.buf)
		w.buf = append(w.buf, rem[:n]...)
		w.buf = append(w.buf, '\\')
		w.flushLine()
		rem = rem[n:]
	}
	w.buf = append(w.buf, rem...)
}

@ |SaveGraph|는 먼저 호마다 번호를 매긴다. 정점을 차례로 훑으며 아직 번호 없는
호와 그 짝을 나란히 번호 매기면, 짝이 이웃해 되살릴 때 |Partner|를 세울 수 있다.

@<그래프를 저장하는 |SaveGraph|@>=
// |SaveGraph|는 그래프 |g|를 |.gb| 파일로 저장한다.
func SaveGraph(g *gbgraph.Graph, filename string) error {
	if g == nil || g.Vertices == nil {
		return gbgraph.MissingOperand
	}
	arcRecords := g.ArcRecords()
	arcIndex := make(map[*gbgraph.Arc]int64, len(arcRecords))
	for i, a := range arcRecords {
		if a != nil {
			arcIndex[a] = int64(i)
		}
	}
	file, err := os.Create(filename)
	if err != nil {
		return gbgraph.EarlyDataFault
	}
	defer file.Close()
	w := &writer{out: bufio.NewWriter(file)}
	@<그래프를 외부 형식으로 옮긴다@>
	return w.out.Flush()
}

@ 첫 줄과 표시 줄은 곧장 쓰고, 레코드들은 |field|를 거쳐 검사합에 든다.
머리글의 정점 수와 호 수는 SGB처럼 {\it 블록 전체\/}의 크기다---정점은
그림자까지 포함한 |len(g.Vertices)|, 호는 102의 배수로 채운 |arcRecords|의
길이. (그래프 레코드 줄에 적히는 |g.N|·|g.M|과는 다르다.)

@<그래프를 외부 형식으로 옮긴다@>=
w.out.WriteString("* GraphBase graph (util_types ")
for i := 0; i < 14; i++ {
	switch c := g.UtilTypes[i]; c {
	case 'Z', 'I', 'V', 'S', 'A':
		w.out.WriteByte(c)
	default:
		w.out.WriteByte('Z')
	}
}
w.out.WriteString(",")
w.out.WriteString(strconv.FormatInt(int64(len(g.Vertices)), 10))
w.out.WriteString("V,")
w.out.WriteString(strconv.FormatInt(int64(len(arcRecords)), 10))
w.out.WriteString("A)\n")
@<그래프 레코드를 옮긴다@>
@<정점 레코드를 옮긴다@>
@<호 레코드를 옮긴다@>
w.out.WriteString("* Checksum ")
w.out.WriteString(strconv.FormatInt(w.magic, 10))
w.out.WriteString("\n")

@ |field|는 한 필드를 기호 형식으로 내보낸다. 첫 필드가 아니면 앞에 쉼표를 둔다.
|Z| 타입은 아무것도 내보내지 않는다.

@<그래프를 저장하는 |SaveGraph|@>=
func (w *writer) field(item string, t byte) {
	if t == 'Z' {
		return
	}
	if w.commaExpected {
		w.buf = append(w.buf, ',')
	}
	w.commaExpected = true
	w.moveItem(item)
}

@ 정점·호·그래프 유틸리티 필드를 그 타입에 따라 문자열로 바꾸는 |encode|다.
정점 포인터는 |V|〈번호〉, 호 포인터는 |A|〈번호〉, |nil|은 |0|이다.

@<그래프를 저장하는 |SaveGraph|@>=
func encodeUtil(u *gbgraph.Util, t byte, g *gbgraph.Graph, arcIndex map[*gbgraph.Arc]int64) string {
	switch t {
	case 'I':
		return strconv.FormatInt(u.I, 10)
	case 'S':
		return quote(u.S)
	case 'V':
		if u.V != nil {
			return "V" + strconv.FormatInt(g.Index(u.V), 10)
		}
		if u.I == 1 {
			return "1"
		}
		return "0"
	case 'A':
		if u.A != nil {
			return "A" + strconv.FormatInt(arcIndex[u.A], 10)
		}
		return "0"
	}
	return ""
}

@ |quote|는 문자열을 따옴표로 감싸며, 따옴표·역슬래시·줄바꿈·인쇄 불가 문자를
\.? 로 바꾼다.

@<그래프를 저장하는 |SaveGraph|@>=
func quote(s string) string {
	var sb strings.Builder
	sb.WriteByte('"')
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == '"' || c == '\n' || c == '\\' || gbio.ImapOrd(c) == unexpectedChar {
			sb.WriteByte('?')
		} else {
			sb.WriteByte(c)
		}
	}
	sb.WriteByte('"')
	return sb.String()
}

@ @<그래프 레코드를 옮긴다@>=
w.commaExpected = false
w.field(quote(g.ID), 'S')
w.field(strconv.FormatInt(g.N, 10), 'I')
w.field(strconv.FormatInt(g.M, 10), 'I')
for pos := 8; pos <= 13; pos++ {
	w.field(encodeUtil(graphUtil(g, pos), g.UtilTypes[pos], g, arcIndex), g.UtilTypes[pos])
}
w.flushLine()

@ 정점 레코드는 그림자 정점까지 블록 전체를 내보낸다. 안 쓰인 그림자 정점은
이름이 빈 문자열, 호가 |nil|이라 저절로 `\.{"",0}'으로 나온다.

@<정점 레코드를 옮긴다@>=
w.out.WriteString("* Vertices\n")
for i := range g.Vertices {
	v := &g.Vertices[i]
	w.commaExpected = false
	w.field(quote(v.Name), 'S')
	if v.Arcs != nil {
		w.field("A"+strconv.FormatInt(arcIndex[v.Arcs], 10), 'A')
	} else {
		w.field("0", 'A')
	}
	for pos := 0; pos <= 5; pos++ {
		w.field(encodeUtil(vertUtil(v, pos), g.UtilTypes[pos], g, arcIndex), g.UtilTypes[pos])
	}
	w.flushLine()
}

@ 호 레코드는 |arcRecords|(할당 순서, 102의 배수로 채운 것)를 그대로 훑는다.
빈 자리(|nil|)는 필드가 모두 0인 호로 다루어 `\.{0,0,0}'으로 나온다.

@<호 레코드를 옮긴다@>=
w.out.WriteString("* Arcs\n")
for _, a := range arcRecords {
	w.commaExpected = false
	if a == nil {
		a = &gbgraph.Arc{} // 안 쓰인 슬롯: 모든 필드가 0
	}
	if a.Tip != nil {
		w.field("V"+strconv.FormatInt(g.Index(a.Tip), 10), 'V')
	} else {
		w.field("0", 'V')
	}
	if a.Next != nil {
		w.field("A"+strconv.FormatInt(arcIndex[a.Next], 10), 'A')
	} else {
		w.field("0", 'A')
	}
	w.field(strconv.FormatInt(a.Len, 10), 'I')
	for pos := 6; pos <= 7; pos++ {
		w.field(encodeUtil(arcUtil(a, pos), g.UtilTypes[pos], g, arcIndex), g.UtilTypes[pos])
	}
	w.flushLine()
}

@* 시험. |gbmiles|로 지은 그래프를 저장했다 되살려, 원본과 동등한지 본다.
정점 수·호 수·표식·유틸리티 쓰임새, 각 정점의 이름과 좌표·인구, 그리고 인접
구조(이웃과 거리)가 모두 같아야 한다. |Partner|도 제대로 이어져야 한다.

@(gbsave_test.go@>=
package gbsave

import (
	"path/filepath"
	"testing"

	"github.com/sjnam/go-sgb/gbmiles"
)

func TestRoundTrip(t *testing.T) {
	g, err := gbmiles.Miles(50, 0, 0, 0, 0, 10, 0, "../data")
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "test.gb")
	if err := SaveGraph(g, path); err != nil {
		t.Fatalf("SaveGraph: %v", err)
	}
	g2, err := RestoreGraph(path)
	if err != nil {
		t.Fatalf("RestoreGraph: %v", err)
	}
	@<되살린 그래프가 원본과 같은지 확인한다@>
}

@ @<되살린 그래프가 원본과 같은지 확인한다@>=
if g2.N != g.N || g2.M != g.M {
	t.Fatalf("N/M = %d/%d, 원함 %d/%d", g2.N, g2.M, g.N, g.M)
}
if g2.ID != g.ID {
	t.Errorf("ID = %q, 원함 %q", g2.ID, g.ID)
}
if g2.UtilTypes != g.UtilTypes {
	t.Errorf("UtilTypes = %q, 원함 %q", g2.UtilTypes, g.UtilTypes)
}
for i := int64(0); i < g.N; i++ {
	v, v2 := &g.Vertices[i], &g2.Vertices[i]
	if v2.Name != v.Name || v2.W.I != v.W.I || v2.X.I != v.X.I ||
		v2.Y.I != v.Y.I || v2.Z.I != v.Z.I {
		t.Fatalf("정점 %d 불일치: %q %v vs %q %v", i, v.Name, v, v2.Name, v2)
	}
	@<정점 |i|의 인접 구조를 견준다@>
}

@ 두 인접 리스트를 나란히 훑어, 이웃의 번호와 간선 길이가 같은지 본다. 첫 호의
짝이 이 정점을 도로 가리키는지도 확인한다.

@<정점 |i|의 인접 구조를 견준다@>=
a, a2 := v.Arcs, v2.Arcs
for a != nil && a2 != nil {
	if g.Index(a.Tip) != g2.Index(a2.Tip) || a.Len != a2.Len {
		t.Fatalf("정점 %d 인접 불일치", i)
	}
	if a2.Partner == nil || g2.Index(a2.Partner.Tip) != i {
		t.Fatalf("정점 %d 호의 짝이 잘못됨", i)
	}
	a, a2 = a.Next, a2.Next
}
if a != nil || a2 != nil {
	t.Fatalf("정점 %d 인접 리스트 길이 불일치", i)
}

@* 찾아보기.
