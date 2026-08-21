//line gbgraph.w:29
package gbgraph

import (
	"fmt"
	"iter"
	"unsafe"
)

//line gbgraph.w:57
type PanicCode int64

const (
	AllocFault     PanicCode = -1 // 이전의 메모리 요청이 실패했었다
	NoRoom         PanicCode = 1  // 지금의 메모리 요청이 실패했다
	EarlyDataFault PanicCode = 10 // \.{.dat} 파일 첫머리에서 오류가 감지됐다
	LateDataFault  PanicCode = 11 // \.{.dat} 파일 끝에서 오류가 감지됐다
	SyntaxError    PanicCode = 20 // \.{.dat} 파일을 읽는 중 오류가 감지됐다
	BadSpecs       PanicCode = 30 // 매개변수가 범위 밖이거나 허용되지 않는다
	VeryBadSpecs   PanicCode = 40 // 매개변수가 한참 벗어났거나 어리석다
	MissingOperand PanicCode = 50 // 그래프 매개변수가 |nil|이다
	InvalidOperand PanicCode = 60 // 그래프 매개변수가 가정을 어긴다
	Impossible     PanicCode = 90 // ``이런 일은 있을 수 없다''
)

func (p PanicCode) Error() string {
	return fmt.Sprintf("gbgraph: 패닉 부호 %d", int64(p))
}

//line gbgraph.w:91
type Util struct {
	V *Vertex // 정점을 가리킬 때
	A *Arc    // 호를 가리킬 때
	G *Graph  // 그래프를 가리킬 때
	S string  // 문자열일 때
	I int64   // 정수일 때
}

//line gbgraph.w:108
type Vertex struct {
	Arcs             *Arc   // 이 정점에서 나가는 호들의 연결 리스트
	Name             string // 이 정점을 상징적으로 식별하는 문자열
	U, V, W, X, Y, Z Util   // 다목적 필드들
}

//line gbgraph.w:123
type Arc struct {
	Tip     *Vertex // 호가 가리키는 정점
	Next    *Arc    // 같은 정점에서 나가는 다른 호
	Len     int64   // 이 호의 길이
	Partner *Arc    // 간선의 반대쪽 호; 홑호라면 |nil|
	A, B    Util    // 다목적 필드들
}

//line gbgraph.w:177
type Graph struct {
	Vertices               []Vertex // 정점 배열; 길이는 |N+extraN|, 순회는 |g.Vertices[:g.N]|
	N                      int64    // 정점의 총수
	M                      int64    // 호의 총수
	ID                     string   // GraphBase 표식
	UtilTypes              string   // 유틸리티 필드들의 쓰임새
	UU, VV, WW, XX, YY, ZZ Util     // 다목적 필드들
	arcs                   []*Arc   // 할당 순서의 호 레코드; SGB 호환 저장을 위해서만 쓴다
}

//line gbgraph.w:204
func (g *Graph) SetUtilType(k int, c byte) {
	t := []byte(g.UtilTypes)
	t[k] = c
	g.UtilTypes = string(t)
}

//line gbgraph.w:216
func (g *Graph) N1() int64 {
	return g.UU.I
}

func (g *Graph) MarkBipartite(n1 int64) {
	g.UU.I = n1
	g.SetUtilType(8, 'I')
}

//line gbgraph.w:236
const extraN = 4 // |NewGraph|가 여분으로 마련하는 그림자 정점의 수

func NewGraph(n int64) *Graph {
	return &Graph{
		Vertices:  make([]Vertex, n+extraN, n+2*extraN),
		N:         n,
		ID:        fmt.Sprintf("gb_new_graph(%d)", n),
		UtilTypes: "ZZZZZZZZZZZZZZ",
	}
}

//line gbgraph.w:253
func (g *Graph) AllocVertex(name string) *Vertex {
	g.Vertices = append(g.Vertices, Vertex{Name: name})
	return &g.Vertices[len(g.Vertices)-1]
}

//line gbgraph.w:263
const idFieldSize = 161 // \CEE/의 |ID| 배열 크기; 문자로는 160자까지

func (g *Graph) MakeCompoundID(s1 string, gg *Graph, s2 string) {
	avail := idFieldSize - len(s1) - len(s2)
	if len(gg.ID) < avail {
		g.ID = s1 + gg.ID + s2
	} else {
		g.ID = s1 + gg.ID[:avail-5] + "...)" + s2
	}
}

//line gbgraph.w:276
func (g *Graph) MakeDoubleCompoundID(s1 string, gg *Graph, s2 string,
	ggg *Graph, s3 string) {
	avail := idFieldSize - len(s1) - len(s2) - len(s3)
	if len(gg.ID)+len(ggg.ID) < avail {
		g.ID = s1 + gg.ID + s2 + ggg.ID + s3
	} else {
		g.ID = s1 + gg.ID[:avail/2-5] + "...)" + s2 +
			ggg.ID[:(avail-9)/2] + "...)" + s3
	}
}

//line gbgraph.w:299
func (g *Graph) VirginArc() *Arc {
	a := new(Arc)
	g.arcs = append(g.arcs, a)
	return a
}

//line gbgraph.w:311
func (g *Graph) NewArc(u, v *Vertex, len int64) {
	a := g.VirginArc()
	a.Tip, a.Next, a.Len = v, u.Arcs, len
	u.Arcs = a
	g.M++
}

//line gbgraph.w:353
func (g *Graph) NewEdge(u, v *Vertex, len int64) {
	a, b := g.VirginArc(), g.VirginArc() // |a|가 앞 번호, |b|가 뒤 번호
	a.Partner, b.Partner = b, a
	a.Len, b.Len = len, len
	if g.Index(u) < g.Index(v) {
		a.Tip, a.Next = v, u.Arcs
		b.Tip, b.Next = u, v.Arcs
		u.Arcs, v.Arcs = a, b
	} else { // |u>=v|; 자기 고리도 이 갈래다
		b.Tip, b.Next = v, u.Arcs
		u.Arcs = b // |u==v|일 때를 대비해 먼저 해 둔다
		a.Tip, a.Next = u, v.Arcs
		v.Arcs = a
	}
	g.M += 2
}

//line gbgraph.w:382
func (g *Graph) Index(v *Vertex) int64 {
	base := uintptr(unsafe.Pointer(&g.Vertices[0]))
	off := uintptr(unsafe.Pointer(v)) - base
	return int64(off / unsafe.Sizeof(Vertex{}))
}

//line gbgraph.w:394
const arcsPerBlock = 102 // \CEE/ |gb_virgin_arc|의 블록 크기

func (g *Graph) ArcRecords() []*Arc {
	total := len(g.arcs)
	if r := total % arcsPerBlock; r != 0 {
		total += arcsPerBlock - r
	}
	records := make([]*Arc, total)
	copy(records, g.arcs)
	return records
}

//line gbgraph.w:409
func (g *Graph) SetArcStore(arcs []*Arc) {
	g.arcs = arcs
}

//line gbgraph.w:421
func (v *Vertex) AllArcs() iter.Seq[*Arc] {
	return func(yield func(*Arc) bool) {
		for a := v.Arcs; a != nil; a = a.Next {
			if !yield(a) {
				return
			}
		}
	}
}

func (g *Graph) AllVertices() iter.Seq[*Vertex] {
	return func(yield func(*Vertex) bool) {
		for i := range g.Vertices[:g.N] {
			if !yield(&g.Vertices[i]) {
				return
			}
		}
	}
}

//line gbgraph.w:457
const (
	hashMult  = 314159    // 무작위 곱수; 이 양반 파이($\pi$)를 참 좋아하는군.
	hashPrime = 516595003 // 27182818번째 소수; $2^{29}$보다 작다
)

//line gbgraph.w:484
func (g *Graph) hashVertex(t string) *Vertex {
	var h int64
	for i := range len(t) {
		h += (h ^ (h >> 1)) + hashMult*int64(t[i])
		for h >= hashPrime {
			h -= hashPrime
		}
	}
	return &g.Vertices[h%g.N]
}

//line gbgraph.w:497
func (g *Graph) HashIn(v *Vertex) {
	u := g.hashVertex(v.Name)
	v.U.V = u.V.V // v의 링크가 사슬의 옛 머리를 잇고
	u.V.V = v     // v가 새 머리가 된다
}

//line gbgraph.w:508
func (g *Graph) HashLookup(s string) *Vertex {
	if g == nil || g.N <= 0 {
		return nil
	}
	for u := g.hashVertex(s).V.V; u != nil; u = u.U.V {
		if u.Name == s {
			return u
		}
	}
	return nil
}

//line gbgraph.w:522
func (g *Graph) HashSetup() {
	if g == nil || g.N <= 0 {
		return
	}
	verts := g.Vertices[:g.N]
	for i := range verts {
		verts[i].V.V = nil
	}
	for i := range verts {
		g.HashIn(&verts[i])
	}
	g.SetUtilType(0, 'V') // 해시 링크와
	g.SetUtilType(1, 'V') // 해시 머리의 사용을 표시
}
