//line gbbooks.w:92
package gbbooks

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/gbsort"
)

//line gbbooks.w:114
const (
	maxChaps   = 360     // 어떤 책도 이만큼 장이 많지 않다
	maxChars   = 600     // 인물도 이만큼 많지 않다
	maxCode    = 1296    // $36\times36$, 36진법 두 자리 코드의 수
	weightBias = 1 << 30 // 무게를 음이 아닌 정렬 키로 만드는 치우침
	cliqueMax  = 30      // 한 클릭에 담기는 정점 수의 상한
	maxWeight  = 1000000 // 무게 계수의 절댓값 상한
)

//line gbbooks.w:129
type bookBuilder struct {
	g                                                    *gbgraph.Graph
	rng                                                  *gbflip.RNG
	bipartite                                            bool
	fileName                                             string
	nodes                                                []gbsort.Node[charInfo]
	xnode                                                map[int64]*gbsort.Node[charInfo]
	characters                                           int64
	chapters                                             int64
	chapName                                             []string // 1번부터 쓰는 장 이름 배열
	chapBase                                             int64    // 이분 그래프에서 장 정점의 색인 치우침
	seed                                                 int64    // 표식에 쓸 난수 씨앗
	n, x, firstChapter, lastChapter, inWeight, outWeight int64
}

//line gbbooks.w:242
type charInfo struct {
	code    int64
	in, out int64
	chap    int64
	vert    *gbgraph.Vertex
}

// |Book|은 책의 인물 마주침을 무향 그래프로 짓는다.
//
//line gbbooks.w:147
//line gbbooks.w:148
func Book(title string, n, x, firstChapter, lastChapter, inWeight, outWeight, seed int64,
	dir string) (*gbgraph.Graph, error) {
	b := newBuilder(false)
	return b.bgraph(title, n, x, firstChapter, lastChapter, inWeight, outWeight, seed, dir)
}

// |BiBook|은 인물과 장 사이의 이분 그래프를 짓는다.
//
//line gbbooks.w:154
//line gbbooks.w:155
func BiBook(title string, n, x, firstChapter, lastChapter, inWeight, outWeight, seed int64,
	dir string) (*gbgraph.Graph, error) {
	b := newBuilder(true)
	return b.bgraph(title, n, x, firstChapter, lastChapter, inWeight, outWeight, seed, dir)
}

//line gbbooks.w:162
func newBuilder(bipartite bool) *bookBuilder {
	return &bookBuilder{
		bipartite: bipartite,
		nodes:     make([]gbsort.Node[charInfo], 0, maxChars),
		xnode:     make(map[int64]*gbsort.Node[charInfo]),
		chapName:  make([]string, maxChaps),
	}
}

//line gbbooks.w:175
func (b *bookBuilder) bgraph(title string, n, x, firstChapter, lastChapter,
	inWeight, outWeight, seed int64, dir string) (*gbgraph.Graph, error) {
	b.rng = gbflip.New(seed)
	b.seed = seed
	b.n, b.x = n, x
	b.firstChapter, b.lastChapter = firstChapter, lastChapter
	b.inWeight, b.outWeight = inWeight, outWeight

//line gbbooks.w:198
	if b.n == 0 {
		b.n = maxChars
	}
	if b.firstChapter == 0 {
		b.firstChapter = 1
	}
	if b.lastChapter == 0 {
		b.lastChapter = maxChaps
	}
	if b.inWeight > maxWeight || b.inWeight < -maxWeight ||
		b.outWeight > maxWeight || b.outWeight < -maxWeight {
		return nil, gbgraph.BadSpecs // 무게가 너무 크다
	}
	t := title
	if len(t) > 6 {
		t = t[:6]
	}
	b.fileName = filepath.Join(dir, t+".dat")

//line gbbooks.w:183
	if err := b.skim(); err != nil {
		return nil, err
	}

//line gbbooks.w:547
	if b.n > b.characters {
		b.n = b.characters
	}
	if b.x > b.n {
		b.x = b.n
	}
	if b.lastChapter > b.chapters {
		b.lastChapter = b.chapters
	}
	if b.firstChapter > b.lastChapter {
		b.firstChapter = b.lastChapter + 1
	}

//line gbbooks.w:566
	size := b.n - b.x
	if b.bipartite {
		size += b.lastChapter - b.firstChapter + 1
	}
	b.g = gbgraph.NewGraph(size)
	b.g.UtilTypes = "IZZIISIZZZZZZZ"
	prefix := ""
	if b.bipartite {
		prefix = "bi_"
	}
	b.g.ID = fmt.Sprintf("%sbook(%q,%d,%d,%d,%d,%d,%d,%d)", prefix, b.title(),
		b.n, b.x, b.firstChapter, b.lastChapter, b.inWeight, b.outWeight, b.seed)
	if b.bipartite {
		b.g.MarkBipartite(b.n - b.x)
		b.chapBase = b.g.N1() - b.firstChapter
	}

//line gbbooks.w:593
	for i := int64(0); i < b.characters; i++ {
		d := &b.nodes[i].Data
		b.nodes[i].Key = b.inWeight*d.in + b.outWeight*d.out + weightBias
		if i == 0 {
			b.nodes[i].Link = nil
		} else {
			b.nodes[i].Link = &b.nodes[i-1]
		}
	}
	buckets := gbsort.LinkSort(&b.nodes[b.characters-1], b.rng)

//line gbbooks.w:610
	vi := int64(0)
	skip := b.x  // 이만큼은 뺀다
	count := b.n // 이만큼의 노드를 본다
Outer:
	for j := 127; j >= 0; j-- {
		for p := buckets[j]; p != nil; p = p.Link {
			if skip > 0 {
				skip-- // 이 노드는 뺀다
			} else {
				p.Data.vert = &b.g.Vertices[vi] // 이 노드를 고른다
				vi++
			}
			count--
			if count == 0 {
				break Outer
			}
		}
	}

//line gbbooks.w:187
	if err := b.fill(); err != nil {
		return nil, err
	}
	return b.g, nil
}

//line gbbooks.w:258
func (b *bookBuilder) skim() error {
	f, err := gbio.Open(b.fileName)
	if err != nil {
		return gbgraph.EarlyDataFault // 파일을 열 수 없다
	}

//line gbbooks.w:275
	for c := f.Number(36); c != 0; c = f.Number(36) {
		if c >= maxCode || f.Char() != ' ' {
			return gbgraph.SyntaxError // 읽을 수 없는 줄
		}
		if int64(len(b.nodes)) >= maxChars {
			return gbgraph.SyntaxError + 1 // 인물이 너무 많다
		}
		b.nodes = append(b.nodes, gbsort.Node[charInfo]{Data: charInfo{code: c}})
		b.xnode[c] = &b.nodes[len(b.nodes)-1]
		f.NextLine()
	}
	b.characters = int64(len(b.nodes))
	f.NextLine() // 인물 자료를 끝맺는 빈 줄을 건너뛴다

//line gbbooks.w:264

//line gbbooks.w:384
	k := int64(1)
	for ; k < maxChaps && !f.EOF(); k++ {
		s := f.String(':') // 장 번호를 지나쳐 읽는다
		if len(s) > 0 && s[0] == '&' {
			k-- // 앞 장의 이어짐
		}

//line gbbooks.w:402
		for f.Char() != '\n' {
			c := f.Number(36)
			if c >= maxCode {
				return gbgraph.SyntaxError + 4 // 인물 사이 구두점이 없다
			}
			p := b.xnode[c]
			if p == nil {
				return gbgraph.SyntaxError + 5 // 모르는 인물
			}
			if p.Data.chap != k {
				p.Data.chap = k
				if k >= b.firstChapter && k <= b.lastChapter {
					p.Data.in++
				} else {
					p.Data.out++
				}
			}
		}

//line gbbooks.w:391
		f.NextLine()
	}
	if k == maxChaps {
		return gbgraph.SyntaxError + 6 // 장이 너무 많다
	}
	b.chapters = k - 1

//line gbbooks.w:265
	if f.Close() != nil {
		return gbgraph.LateDataFault // 검사합 등 실패
	}
	return nil
}

//line gbbooks.w:312
func (b *bookBuilder) fill() error {
	f, err := gbio.Open(b.fileName)
	if err != nil {
		return gbgraph.Impossible + 1 // 앞서 성공했으니 있을 수 없다
	}

//line gbbooks.w:333
	for c := f.Number(36); c != 0; c = f.Number(36) {
		p := b.xnode[c]
		if v := p.Data.vert; v != nil {
			if f.Char() != ' ' {
				return gbgraph.Impossible
			}
			v.Name = f.String(',') // 이름 부분
			if f.Char() != ',' {
				return gbgraph.SyntaxError + 2 // 이름 뒤 콤마가 없다
			}
			if f.Char() != ' ' {
				return gbgraph.SyntaxError + 3 // 콤마 뒤 빈칸이 없다
			}
			v.Z.S = f.String('\n') // 설명 부분(|desc|)
			v.Y.I = p.Data.in      // |in_count|
			v.X.I = p.Data.out     // |out_count|
			v.U.I = c              // |short_code|
		}
		f.NextLine()
	}
	f.NextLine()

//line gbbooks.w:318
	if b.bipartite {

//line gbbooks.w:502
		for i := int64(0); i < b.characters; i++ {
			b.nodes[i].Data.chap = 0
		}
		for k := int64(1); !f.EOF(); k++ {
			cont := b.noteChapter(k, f.String(':'))
			if cont {
				k--
			}
			if k >= b.firstChapter && k <= b.lastChapter {

//line gbbooks.w:519
				u := &b.g.Vertices[b.chapBase+k]
				if !cont {
					u.Name = b.chapName[k]
					u.Z.S = "" // 설명은 빈 문자열
					u.Y.I, u.X.I = 0, 0
				}
				for f.Char() != '\n' {
					p := b.xnode[f.Number(36)]
					if p.Data.chap != k {
						p.Data.chap = k
						if v := p.Data.vert; v != nil {
							b.g.NewEdge(v, u, 1)
							u.Y.I++ // |in_count|
						} else {
							u.X.I++ // |out_count|
						}
					}
				}

//line gbbooks.w:512
			}
			f.NextLine()
		}

//line gbbooks.w:320
	} else {

//line gbbooks.w:438
		clique := make([]*gbgraph.Vertex, 0, cliqueMax)
		for k := int64(1); !f.EOF(); k++ {
			if b.noteChapter(k, f.String(':')) {
				k--
			}
			if k >= b.firstChapter && k <= b.lastChapter {

//line gbbooks.w:454
				c := f.Char() // 장 번호 뒤의 |':'|
				for c != '\n' {
					clique = clique[:0]
					for {
						if v := b.xnode[f.Number(36)].Data.vert; v != nil {
							clique = append(clique, v)
						}
						c = f.Char()
						if c != ',' {
							break
						}
					}

//line gbbooks.w:470
					for qi := 0; qi+1 < len(clique); qi++ {
						for ri := qi + 1; ri < len(clique); ri++ {
							b.makeAdjacent(clique[qi], clique[ri], k)
						}
					}

//line gbbooks.w:467
				}

//line gbbooks.w:445
			}
			f.NextLine()
		}

//line gbbooks.w:322
	}
	if f.Close() != nil {
		return gbgraph.Impossible + 2
	}
	return nil
}

//line gbbooks.w:425
func (b *bookBuilder) noteChapter(k int64, s string) (cont bool) {
	if len(s) > 0 && s[0] == '&' {
		return true
	}
	b.chapName[k] = strings.TrimSuffix(s, "\n")
	return false
}

//line gbbooks.w:482
func (b *bookBuilder) makeAdjacent(u, v *gbgraph.Vertex, k int64) {
	for a := range u.AllArcs() {
		if a.Tip == v {
			return // 이미 이웃이다
		}
	}
	b.g.NewEdge(u, v, 1)
	a := u.Arcs // 방금 만든 호와 그 짝
	a.A.I, a.Partner.A.I = k, k
}

//line gbbooks.w:633
func (b *bookBuilder) title() string {
	return strings.TrimSuffix(filepath.Base(b.fileName), ".dat")
}
