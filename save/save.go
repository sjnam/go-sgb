// Package save implements GB_SAVE from Stanford GraphBase.
// SaveGraph serializes a graph to a .gb file; RestoreGraph deserializes it.
package save

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/graph"
)

// Anomaly bit flags returned by SaveGraph.
const (
	BadTypeCode       int64 = 0x01 // illegal util_types char, changed to 'Z'
	StringTooLong     int64 = 0x02 // string truncated
	AddrNotInDataArea int64 = 0x04 // pointer out of range, changed to 0
	BadStringChar     int64 = 0x10 // illegal string char, changed to '?'
	IgnoredData       int64 = 0x20 // nonzero value in a 'Z' field
)

const maxSvString = 4095

// SaveGraph writes graph g to the named file in GraphBase format.
// It returns a bitmask of anomaly flags (0 if the graph was saved verbatim;
// nonzero if it was saved with corrections) and an error if g is nil or the
// file could not be written.
func SaveGraph(g *graph.Graph, filename string) (int64, error) {
	if g == nil || g.Vertices == nil {
		return 0, graph.ErrMissingOperand
	}

	f, err := os.OpenFile(filename, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o644)
	if err != nil {
		return 0, fmt.Errorf("save: cannot create %q: %w", filename, err)
	}
	defer f.Close()

	// Map vertices 0..N-1 to their indices.
	vidx := make(map[*graph.Vertex]int64, g.N)
	for i := int64(0); i < g.N; i++ {
		vidx[&g.Vertices[i]] = i
	}

	// Enumerate all arcs by traversing vertex arc lists.
	var arcList []*graph.Arc
	aidx := make(map[*graph.Arc]int64)
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if _, seen := aidx[a]; !seen {
				aidx[a] = int64(len(arcList))
				arcList = append(arcList, a)
			}
		}
	}
	n := g.N
	m := int64(len(arcList))

	// Sanitize util_types to 14 valid characters.
	ut := make([]byte, 14)
	copy(ut, g.UtilTypes)
	for i := len(g.UtilTypes); i < 14; i++ {
		ut[i] = 'Z'
	}
	var anomalies int64
	for i := range ut {
		switch ut[i] {
		case 'Z', 'I', 'V', 'S', 'A':
		default:
			ut[i] = 'Z'
			anomalies |= BadTypeCode
		}
	}
	utStr := string(ut)

	w := bufio.NewWriter(f)
	var magic int64

	// writeLine checksums and writes a data line (not starting with '*').
	writeLine := func(s string) {
		line := s + "\n"
		magic = gbio.NewChecksum(line, magic)
		w.WriteString(line)
	}
	// writeComment writes a '*'-prefixed line without checksumming.
	writeComment := func(s string) { w.WriteString(s + "\n") }

	// Header line (comment).
	writeComment(fmt.Sprintf("* GraphBase graph (util_types %s,%dV,%dA)", utStr, n, m))

	// Graph record: "id",N,M[,util fields 8-13]
	var rec strings.Builder
	appendQuotedStr(&rec, g.ID, &anomalies)
	fmt.Fprintf(&rec, ",%d,%d", g.N, g.M)
	for i := 0; i < 6; i++ {
		typ := ut[8+i]
		if typ == 'Z' {
			checkIgnored(graphUtil(g, i), &anomalies)
			continue
		}
		rec.WriteByte(',')
		appendField(&rec, graphUtil(g, i), typ, vidx, aidx, &anomalies)
	}
	writeLine(rec.String())

	// Vertex records.
	writeComment("* Vertices")
	for i := int64(0); i < n; i++ {
		v := &g.Vertices[i]
		var vr strings.Builder
		appendQuotedStr(&vr, v.Name, &anomalies)
		vr.WriteByte(',')
		appendArcPtr(&vr, v.Arcs, aidx, &anomalies)
		for j := 0; j < 6; j++ {
			typ := ut[j]
			if typ == 'Z' {
				checkIgnored(vertexUtil(v, j), &anomalies)
				continue
			}
			vr.WriteByte(',')
			appendField(&vr, vertexUtil(v, j), typ, vidx, aidx, &anomalies)
		}
		writeLine(vr.String())
	}

	// Arc records.
	writeComment("* Arcs")
	for _, a := range arcList {
		var ar strings.Builder
		appendVertexPtr(&ar, a.Tip, vidx, &anomalies)
		ar.WriteByte(',')
		appendArcPtr(&ar, a.Next, aidx, &anomalies)
		fmt.Fprintf(&ar, ",%d", a.Len)
		for i := 0; i < 2; i++ {
			typ := ut[6+i]
			if typ == 'Z' {
				checkIgnored(arcUtil(a, i), &anomalies)
				continue
			}
			ar.WriteByte(',')
			appendField(&ar, arcUtil(a, i), typ, vidx, aidx, &anomalies)
		}
		writeLine(ar.String())
	}

	writeComment(fmt.Sprintf("* Checksum %d", magic))

	if anomalies != 0 {
		w.WriteString("> WARNING: I had trouble making this file from the given graph!\n")
		if anomalies&BadTypeCode != 0 {
			w.WriteString(">> The original util_types had to be corrected.\n")
		}
		if anomalies&IgnoredData != 0 {
			w.WriteString(">> Some data suppressed by Z format was actually nonzero.\n")
		}
		if anomalies&StringTooLong != 0 {
			w.WriteString(">> At least one long string had to be truncated.\n")
		}
		if anomalies&BadStringChar != 0 {
			w.WriteString(">> At least one string character had to be changed to '?'.\n")
		}
		if anomalies&AddrNotInDataArea != 0 {
			w.WriteString(">> At least one pointer led out of the data area.\n")
		}
	}

	if err := w.Flush(); err != nil {
		return anomalies, fmt.Errorf("save: cannot write %q: %w", filename, err)
	}
	return anomalies, nil
}

// RestoreGraph reads a graph from the named GraphBase-format file.
// Returns the graph and nil error on success, or nil and an error on failure.
func RestoreGraph(filename string) (*graph.Graph, error) {
	r, err := gbio.RawOpen(filename)
	if err != nil {
		return nil, graph.ErrEarlyDataFault
	}

	// Skip leading comment lines; find the header.
	var utStr string
	var fileN, fileM int64
	for {
		line := r.GbString('\n')
		if ok, ut, nv, ma := parseHeader(line); ok {
			utStr, fileN, fileM = ut, nv, ma
			break
		}
		if len(line) == 0 || line[0] != '*' {
			r.RawClose()
			return nil, graph.ErrSyntaxError
		}
		r.GbNewline()
	}
	r.GbNewline() // advance to graph record line (checksums it)

	// Allocate graph with fileN vertices and fileM arc slots.
	g := graph.NewGraph(fileN)
	g.UtilTypes = utStr
	vertices := g.Vertices[:fileN]
	arcs := make([]graph.Arc, fileM)

	// Graph record: "id",n,m[,util fields 8-13]
	g.ID = readQuotedStr(r)
	if g.ID == "\x00" {
		r.RawClose()
		return nil, graph.ErrSyntaxError
	}
	var ok bool
	if g.N, ok = readCommaInt(r); !ok {
		r.RawClose()
		return nil, graph.ErrSyntaxError
	}
	if g.M, ok = readCommaInt(r); !ok {
		r.RawClose()
		return nil, graph.ErrSyntaxError
	}
	for i := 0; i < 6; i++ {
		if utStr[8+i] == 'Z' {
			continue
		}
		val, err := readCommaField(r, utStr[8+i], vertices, arcs)
		if err != nil {
			r.RawClose()
			return nil, err
		}
		setGraphUtil(g, i, val)
	}
	if r.GbChar() != '\n' {
		r.RawClose()
		return nil, graph.ErrSyntaxError
	}
	r.GbNewline() // advance to "* Vertices" (not checksummed)

	if r.GbString('\n') != "* Vertices" {
		r.RawClose()
		return nil, graph.ErrSyntaxError
	}
	r.GbNewline() // advance to first vertex record

	for i := int64(0); i < fileN; i++ {
		v := &vertices[i]
		v.Name = readQuotedStr(r)
		if v.Name == "\x00" {
			r.RawClose()
			return nil, graph.ErrSyntaxError
		}
		var aptr *graph.Arc
		if aptr, ok = readCommaArcPtr(r, arcs); !ok {
			r.RawClose()
			return nil, graph.ErrSyntaxError
		}
		v.Arcs = aptr
		for j := 0; j < 6; j++ {
			if utStr[j] == 'Z' {
				continue
			}
			val, err := readCommaField(r, utStr[j], vertices, arcs)
			if err != nil {
				r.RawClose()
				return nil, err
			}
			setVertexUtil(v, j, val)
		}
		if r.GbChar() != '\n' {
			r.RawClose()
			return nil, graph.ErrSyntaxError
		}
		r.GbNewline()
	}

	if r.GbString('\n') != "* Arcs" {
		r.RawClose()
		return nil, graph.ErrSyntaxError
	}
	r.GbNewline()

	for i := int64(0); i < fileM; i++ {
		a := &arcs[i]
		var vtip *graph.Vertex
		if vtip, ok = readVertexPtr(r, vertices); !ok {
			r.RawClose()
			return nil, graph.ErrSyntaxError
		}
		a.Tip = vtip
		var anext *graph.Arc
		if anext, ok = readCommaArcPtr(r, arcs); !ok {
			r.RawClose()
			return nil, graph.ErrSyntaxError
		}
		a.Next = anext
		var alen int64
		if alen, ok = readCommaInt(r); !ok {
			r.RawClose()
			return nil, graph.ErrSyntaxError
		}
		a.Len = alen
		for j := 0; j < 2; j++ {
			if utStr[6+j] == 'Z' {
				continue
			}
			val, err := readCommaField(r, utStr[6+j], vertices, arcs)
			if err != nil {
				r.RawClose()
				return nil, err
			}
			setArcUtil(a, j, val)
		}
		if r.GbChar() != '\n' {
			r.RawClose()
			return nil, graph.ErrSyntaxError
		}
		r.GbNewline()
	}

	// Checksum line.
	csLine := r.GbString('\n')
	var savedChecksum int64
	if cnt, _ := fmt.Sscanf(csLine, "* Checksum %d", &savedChecksum); cnt != 1 {
		r.RawClose()
		return nil, graph.ErrSyntaxError
	}
	gotChecksum := r.RawClose()
	if savedChecksum >= 0 && gotChecksum != savedChecksum {
		return nil, graph.ErrLateDataFault
	}

	return g, nil
}

// --- header parsing ---

func parseHeader(line string) (matched bool, utStr string, n, m int64) {
	const prefix = "* GraphBase graph (util_types "
	if !strings.HasPrefix(line, prefix) {
		return
	}
	rest := line[len(prefix):]
	if len(rest) < 14 {
		return
	}
	ut := rest[:14]
	if !isValidUtilTypes(ut) {
		return
	}
	var nv, ma int64
	if cnt, _ := fmt.Sscanf(rest[14:], ",%dV,%dA)", &nv, &ma); cnt != 2 {
		return
	}
	return true, ut, nv, ma
}

func isValidUtilTypes(s string) bool {
	for i := 0; i < len(s); i++ {
		switch s[i] {
		case 'Z', 'I', 'V', 'S', 'A':
		default:
			return false
		}
	}
	return true
}

// --- reading helpers ---

// readQuotedStr reads a "..." quoted string from the current buffer position.
// Returns "\x00" on parse error.
func readQuotedStr(r *gbio.Reader) string {
	if r.GbChar() != '"' {
		return "\x00"
	}
	s := r.GbString('"')
	if r.GbChar() != '"' {
		return "\x00"
	}
	return s
}

// readCommaInt reads "," then a signed decimal integer.
func readCommaInt(r *gbio.Reader) (int64, bool) {
	if r.GbChar() != ',' {
		return 0, false
	}
	c := r.GbChar()
	if c == '-' {
		return -int64(r.GbNumber(10)), true
	}
	r.GbBackup()
	return int64(r.GbNumber(10)), true
}

// readVertexPtr reads a vertex pointer (V<n>, 0, or 1) from current position.
func readVertexPtr(r *gbio.Reader, vertices []graph.Vertex) (*graph.Vertex, bool) {
	c := r.GbChar()
	switch c {
	case 'V':
		idx := int64(r.GbNumber(10))
		if idx < 0 || idx >= int64(len(vertices)) {
			return nil, false
		}
		return &vertices[idx], true
	case '0', '1':
		return nil, true // 0=NULL, 1=special gb_gates value (treated as nil)
	}
	return nil, false
}

// readArcPtr reads an arc pointer (A<n> or 0) from current position.
func readArcPtr(r *gbio.Reader, arcs []graph.Arc) (*graph.Arc, bool) {
	c := r.GbChar()
	switch c {
	case 'A':
		idx := int64(r.GbNumber(10))
		if idx < 0 || idx >= int64(len(arcs)) {
			return nil, false
		}
		return &arcs[idx], true
	case '0':
		return nil, true
	}
	return nil, false
}

// readCommaArcPtr reads "," then an arc pointer.
func readCommaArcPtr(r *gbio.Reader, arcs []graph.Arc) (*graph.Arc, bool) {
	if r.GbChar() != ',' {
		return nil, false
	}
	return readArcPtr(r, arcs)
}

// readCommaField reads "," then a field of the given type.
// Returns the value and nil, or nil and an error.
func readCommaField(r *gbio.Reader, typ byte, vertices []graph.Vertex, arcs []graph.Arc) (any, error) {
	if r.GbChar() != ',' {
		return nil, graph.ErrSyntaxError
	}
	switch typ {
	case 'I':
		c := r.GbChar()
		if c == '-' {
			return -int64(r.GbNumber(10)), nil
		}
		r.GbBackup()
		return int64(r.GbNumber(10)), nil
	case 'S':
		s := readQuotedStr(r)
		if s == "\x00" {
			return nil, graph.ErrSyntaxError
		}
		return s, nil
	case 'V':
		v, ok := readVertexPtr(r, vertices)
		if !ok {
			return nil, graph.ErrSyntaxError
		}
		return v, nil
	case 'A':
		a, ok := readArcPtr(r, arcs)
		if !ok {
			return nil, graph.ErrSyntaxError
		}
		return a, nil
	}
	return nil, graph.ErrSyntaxError
}

// --- writing helpers ---

func appendQuotedStr(b *strings.Builder, s string, anomalies *int64) {
	b.WriteByte('"')
	count := 0
	for i := 0; i < len(s); i++ {
		if count >= maxSvString {
			*anomalies |= StringTooLong
			break
		}
		c := s[i]
		if c == '"' || c == '\n' || c == '\\' || gbio.ImapOrd(c) == gbio.UnexpectedChar {
			*anomalies |= BadStringChar
			b.WriteByte('?')
		} else {
			b.WriteByte(c)
		}
		count++
	}
	b.WriteByte('"')
}

func appendVertexPtr(b *strings.Builder, v *graph.Vertex, vidx map[*graph.Vertex]int64, anomalies *int64) {
	if v == nil {
		b.WriteByte('0')
		return
	}
	idx, ok := vidx[v]
	if !ok {
		*anomalies |= AddrNotInDataArea
		b.WriteByte('0')
		return
	}
	fmt.Fprintf(b, "V%d", idx)
}

func appendArcPtr(b *strings.Builder, a *graph.Arc, aidx map[*graph.Arc]int64, anomalies *int64) {
	if a == nil {
		b.WriteByte('0')
		return
	}
	idx, ok := aidx[a]
	if !ok {
		*anomalies |= AddrNotInDataArea
		b.WriteByte('0')
		return
	}
	fmt.Fprintf(b, "A%d", idx)
}

func appendField(b *strings.Builder, val any, typ byte, vidx map[*graph.Vertex]int64, aidx map[*graph.Arc]int64, anomalies *int64) {
	switch typ {
	case 'I':
		v, _ := val.(int64)
		fmt.Fprintf(b, "%d", v)
	case 'S':
		s, _ := val.(string)
		appendQuotedStr(b, s, anomalies)
	case 'V':
		v, _ := val.(*graph.Vertex)
		appendVertexPtr(b, v, vidx, anomalies)
	case 'A':
		a, _ := val.(*graph.Arc)
		appendArcPtr(b, a, aidx, anomalies)
	}
}

func checkIgnored(val any, anomalies *int64) {
	switch v := val.(type) {
	case int64:
		if v != 0 {
			*anomalies |= IgnoredData
		}
	case *graph.Vertex:
		if v != nil {
			*anomalies |= IgnoredData
		}
	case *graph.Arc:
		if v != nil {
			*anomalies |= IgnoredData
		}
	case string:
		if v != "" {
			*anomalies |= IgnoredData
		}
	}
}

// --- graph utility field accessors ---

func graphUtil(g *graph.Graph, i int) any {
	switch i {
	case 0:
		return g.UU
	case 1:
		return g.VV
	case 2:
		return g.WW
	case 3:
		return g.XX
	case 4:
		return g.YY
	case 5:
		return g.ZZ
	}
	return nil
}

func setGraphUtil(g *graph.Graph, i int, val any) {
	switch i {
	case 0:
		g.UU = val
	case 1:
		g.VV = val
	case 2:
		g.WW = val
	case 3:
		g.XX = val
	case 4:
		g.YY = val
	case 5:
		g.ZZ = val
	}
}

func vertexUtil(v *graph.Vertex, j int) any {
	switch j {
	case 0:
		return v.U
	case 1:
		return v.V
	case 2:
		return v.W
	case 3:
		return v.X
	case 4:
		return v.Y
	case 5:
		return v.Z
	}
	return nil
}

func setVertexUtil(v *graph.Vertex, j int, val any) {
	switch j {
	case 0:
		v.U = val
	case 1:
		v.V = val
	case 2:
		v.W = val
	case 3:
		v.X = val
	case 4:
		v.Y = val
	case 5:
		v.Z = val
	}
}

func arcUtil(a *graph.Arc, i int) any {
	if i == 0 {
		return a.A
	}
	return a.B
}

func setArcUtil(a *graph.Arc, i int, val any) {
	if i == 0 {
		a.A = val
	} else {
		a.B = val
	}
}
