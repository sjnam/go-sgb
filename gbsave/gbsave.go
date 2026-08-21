//line gbsave.w:103
package gbsave

import (
	"bufio"
	"os"
	"strconv"
	"strings"

	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
)

const (
	maxSvID        = 154 // |ID|의 최대 길이
	unexpectedChar = 127 // |imap|에 없는 문자
)

//line gbsave.w:129
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

//line gbsave.w:147
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

//line gbsave.w:178
type reader struct {
	f             *gbio.File
	g             *gbgraph.Graph
	arcs          []gbgraph.Arc
	commaExpected bool
}

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

//line gbsave.w:260
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

//line gbsave.w:199

//line gbsave.w:455
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

//line gbsave.w:200
	return r.g, nil
}

//line gbsave.w:207
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

//line gbsave.w:233
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

//line gbsave.w:292
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

//line gbsave.w:335
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

//line gbsave.w:365
		if c == '-' {
			u.I = -r.f.Number(10)
		} else {
			r.f.Backup()
			u.I = r.f.Number(10)
		}

//line gbsave.w:354
	case 'V':

//line gbsave.w:375
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
		//
//line gbsave.w:385
//line gbsave.w:386
		default:
			return gbgraph.SyntaxError
		}

//line gbsave.w:356
	case 'A':

//line gbsave.w:391
		switch {
		case c == 'A':
			k := r.f.Number(10)
			if k < 0 || k >= int64(len(r.arcs)) {
				return gbgraph.SyntaxError
			}
			u.A = &r.arcs[k]
		case c == '0':
		// |nil|
		//
//line gbsave.w:399
//line gbsave.w:400
		default:
			return gbgraph.SyntaxError
		}

//line gbsave.w:358
	case 'S':

//line gbsave.w:408
		if c != '"' {
			return gbgraph.SyntaxError
		}
		s, ok := r.readString()
		if !ok {
			return gbgraph.SyntaxError
		}
		u.S = s

//line gbsave.w:360
	}
	return nil
}

//line gbsave.w:421
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

//line gbsave.w:477
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

//line gbsave.w:523
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

//line gbsave.w:541
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

//line gbsave.w:569
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

//line gbsave.w:596
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

//line gbsave.w:679
	w.commaExpected = false
	w.field(quote(g.ID), 'S')
	w.field(strconv.FormatInt(g.N, 10), 'I')
	w.field(strconv.FormatInt(g.M, 10), 'I')
	for pos := 8; pos <= 13; pos++ {
		w.field(encodeUtil(graphUtil(g, pos), g.UtilTypes[pos], g, arcIndex), g.UtilTypes[pos])
	}
	w.flushLine()

//line gbsave.w:692
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

//line gbsave.w:712
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

//line gbsave.w:613
	w.out.WriteString("* Checksum ")
	w.out.WriteString(strconv.FormatInt(w.magic, 10))
	w.out.WriteString("\n")

//line gbsave.w:587
	return w.out.Flush()
}

//line gbsave.w:621
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

//line gbsave.w:636
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

//line gbsave.w:663
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
