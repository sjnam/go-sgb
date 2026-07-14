% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_books.w를 Go로 이식한다.
@i ../types.w

\input kotexgweb
\def\title{GB\_\,BOOKS}
\def\<#1>{\hbox{$\langle$\rm#1$\rangle$}}

@* 들어가며. 이 모듈은 고전 문학 작품에 바탕한 무향 그래프 집안을 짓는 |Book|
서브루틴과, 그와 짝을 이루는 이분 그래프를 짓는 |BiBook| 서브루틴을 담는다.
쓰임새는 {\sc BOOK\_COMPONENTS} 데모에서 볼 수 있다.

|Book(title, n, x, firstChapter, lastChapter, inWeight, outWeight, seed, dir)|은
\<title>\/\.{.dat}의 정보로 그래프를 짓는다. \<title>\/은 |"anna"|({\sl Anna
Karenina\/}), |"david"|({\sl David Copperfield\/}), |"jean"|({\sl Les
Mis\'erables\/}), |"huck"|({\sl Huckleberry Finn\/}), |"homer"|({\sl The
Iliad\/}) 가운데 하나다. 각 정점은 그 책의 한 등장인물이고, 두 정점 사이의
간선은 그 인물들의 마주침(encounter)을 뜻한다. 간선 길이는 모두 1이다.

@ |firstChapter|과 |lastChapter| 사이의 장(chapter)으로 간선 자료를 한정할 수
있다. 그래프는 $\min(n,N)-x$개의 정점을 갖는데, $N$은 그 책의 전체 인물 수다.
|n|이 0이면 $N$으로, |n|이 $N$보다 작으면 각 인물에 무게를 매겨 가장 무거운
|n|명을 고른 뒤, 그중 가장 무거운 |x|명을 다시 뺀다. 무게는
$$|inWeight|\cdot\\{chaptersIn}+|outWeight|\cdot\\{chaptersOut}$$
로 셈하는데, \\{chaptersIn}은 그 인물이 선택된 장 구간에서 나오는 장 수,
\\{chaptersOut}은 그 밖의 장에서 나오는 장 수다. 두 무게 계수는 절댓값이
1,000,000 이하여야 한다.

|x|는 대개 0이나 1이다. {\sl David Copperfield\/}나 {\sl Huckleberry Finn\/}은
주인공이 화자라 거의 모두와 마주치므로, |x=1|로 주인공을 빼면 연결 구조가 더
흥미로워진다.

@ |BiBook|은 |Book|과 같은 인물 정점에다 선택된 장들을 둘째 갈래로 두는 이분
그래프를 낳는다. 각 인물과, 그 인물이 나오는 장 사이에 간선이 생긴다.

@ 프로그램의 뼈대다. \CEE/ 원본은 정적 전역 |node_block|·|xnode|·|chap_name|과
외부 변수 |chapters|를 두지만, 우리는 패키지 수준 가변 상태를 피해 이들을
|bookBuilder| 구조체에 담는다. |Book|과 |BiBook|은 안쪽 |bgraph|를 부르는데,
|bgraph|가 두 루틴의 일을 겸한다.
@d DataInputDirectory
@c
package gbbooks

import (
	"fmt"
	"path/filepath"
	"strings"
	@#
	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/gbsort"
)

@<상수 정의@>@;
@<자료 구조@>@;
@<|Book|과 |BiBook|@>@;
@<|bgraph|와 그 도우미@>@;

@ 어떤 책도 이만큼 많지는 않을 상한들이다.

@<상수 정의@>=
const (
	DataInputDirectory = "/usr/local/sgb/data"
	maxChaps   = 360        // 어떤 책도 이만큼 장이 많지 않다
	maxChars   = 600        // 인물도 이만큼 많지 않다
	maxCode    = 1296       // $36\times36$, 36진법 두 자리 코드의 수
	weightBias = 1 << 30    // 무게를 음이 아닌 정렬 키로 만드는 치우침
	cliqueMax  = 30         // 한 클릭에 담기는 정점 수의 상한
	maxWeight  = 1000000    // 무게 계수의 절댓값 상한
)

@ 인물 하나를 |charInfo|로 나타낸다. 이것을 |gbsort.Node|의 딸림 데이터로 실어
무게순 정렬에 부친다. |code|는 36진법 두 자리 코드, |in|·|out|은 선택 구간
안팎의 등장 장 수, |chap|은 가장 최근에 본 장(중복 방지), |vert|는 이 인물에
배정된 정점이다.

@<자료 구조@>=
type charInfo struct {
	code    int64
	in, out int64
	chap    int64
	vert    *gbgraph.Vertex
}

@ |bookBuilder|는 짓고 있는 그래프와 작업 상태를 한데 묶는다. |nodes|는 용량을
|maxChars|로 미리 잡아, 뒤에 원소를 더해도 재할당되지 않게 한다 --- 그래야
|xnode|가 담은 포인터가 그대로 유효하다.

@<자료 구조@>=
type bookBuilder struct {
	g          *gbgraph.Graph
	rng        *gbflip.RNG
	bipartite  bool
	fileName   string
	nodes      []gbsort.Node[charInfo]
	xnode      map[int64]*gbsort.Node[charInfo]
	characters int64
	chapters   int64
	chapName   []string // 1번부터 쓰는 장 이름 배열
	chapBase   int64    // 이분 그래프에서 장 정점의 색인 치우침
	seed       int64    // 표식에 쓸 난수 씨앗
	n, x, firstChapter, lastChapter, inWeight, outWeight int64
}

@ |Book|과 |BiBook|은 그저 |bgraph|를 |bipartite| 깃발만 달리해 부른다.

@<|Book|과 |BiBook|@>=
// |Book|은 책의 인물 마주침을 무향 그래프로 짓는다.
func Book(title string, n, x, firstChapter, lastChapter, inWeight, outWeight, seed int64,
	dir string) (*gbgraph.Graph, error) {
	if dir == "" {
		dir = DataInputDirectory
	}
	b := newBuilder(false)
	return b.bgraph(title, n, x, firstChapter, lastChapter, inWeight, outWeight, seed, dir)
}

// |BiBook|은 인물과 장 사이의 이분 그래프를 짓는다.
func BiBook(title string, n, x, firstChapter, lastChapter, inWeight, outWeight, seed int64,
	dir string) (*gbgraph.Graph, error) {
	if dir == "" {
		dir = DataInputDirectory
	}
	b := newBuilder(true)
	return b.bgraph(title, n, x, firstChapter, lastChapter, inWeight, outWeight, seed, dir)
}

@ @<|Book|과 |BiBook|@>=
func newBuilder(bipartite bool) *bookBuilder {
	return &bookBuilder{
		bipartite: bipartite,
		nodes:     make([]gbsort.Node[charInfo], 0, maxChars),
		xnode:     make(map[int64]*gbsort.Node[charInfo]),
		chapName:  make([]string, maxChaps),
	}
}

@ |bgraph|는 씨앗으로 난수 스트림을 열고, 매개변수를 다듬고, 자료 파일을 두 번
읽는다: 한 번은 빠르게(통계 수집), 한 번은 꼼꼼히(정점 이름과 간선).

@<|bgraph|와 그 도우미@>=
func (b *bookBuilder) bgraph(title string, n, x, firstChapter, lastChapter,
	inWeight, outWeight, seed int64, dir string) (*gbgraph.Graph, error) {
	b.rng = gbflip.New(seed)
	b.seed = seed
	b.n, b.x = n, x
	b.firstChapter, b.lastChapter = firstChapter, lastChapter
	b.inWeight, b.outWeight = inWeight, outWeight
	@<매개변수가 올바른지 확인한다@>@;
	if err := b.skim(); err != nil {
		return nil, err
	}
	@<정점을 골라 빈 그래프에 넣는다@>@;
	if err := b.fill(); err != nil {
		return nil, err
	}
	return b.g, nil
}

@ |n==0|은 최대치로, |firstChapter==0|은 1로, |lastChapter==0|은 최대치로 바꾼다.
파일 이름은 제목의 앞 여섯 글자에 \.{.dat}을 붙인 것이다.

@<매개변수가 올바른지 확인한다@>=
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

@ 첫 번째 읽기(빠른 훑기)다. 인물 코드로 노드를 만들고, 각 인물이 몇 장에서
나오는지 센 뒤 파일을 닫는다.

@<|bgraph|와 그 도우미@>=
func (b *bookBuilder) skim() error {
	f, err := gbio.Open(b.fileName)
	if err != nil {
		return gbgraph.EarlyDataFault // 파일을 열 수 없다
	}
	@<파일 첫머리의 인물 코드를 읽어 노드를 만든다@>@;
	@<장 정보를 훑어 각 인물의 등장 장 수를 센다@>@;
	if f.Close() != nil {
		return gbgraph.LateDataFault // 검사합 등 실패
	}
	return nil
}

@ 각 인물은 36진법 두 자리 코드로 식별된다. 코드 |00|은 쓰이지 않으므로, 코드가
0이면 인물 목록의 끝이다. 코드 다음에는 빈칸 하나가 온다.

@<파일 첫머리의 인물 코드를 읽어 노드를 만든다@>=
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

@ 자료의 둘째 부분은 장마다 ``마주침의 클릭(clique)''들을 담은 줄이다. 여기서는
콤마와 세미콜론을 구별하지 않고, 누가 어느 장에 나오는지만 센다. |'&'|로
시작하는 줄은 앞 장의 이어짐이다.

@<장 정보를 훑어 각 인물의 등장 장 수를 센다@>=
k := int64(1)
for ; k < maxChaps && !f.EOF(); k++ {
	s := f.String(':') // 장 번호를 지나쳐 읽는다
	if len(s) > 0 && s[0] == '&' {
		k-- // 앞 장의 이어짐
	}
	@<이 장에 나오는 인물들의 등장 수를 센다@>@;
	f.NextLine()
}
if k == maxChaps {
	return gbgraph.SyntaxError + 6 // 장이 너무 많다
}
b.chapters = k - 1

@ 줄 끝(|'\n'|)까지, 구분자와 코드를 번갈아 읽는다. 한 인물을 한 장에서 처음
볼 때만 센다.

@<이 장에 나오는 인물들의 등장 수를 센다@>=
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

@ 그래프를 만들 차례다. 정점 수를 정하고, |UtilTypes|를 못박고, 표식을 짓는다.
|"IZZIISIZZZZZZZ"|는 정점의 |U.I|에 |short_code|, |X.I|에 |out_count|, |Y.I|에
|in_count|, |Z.S|에 |desc|를, 호의 |A.I|에 |chap_no|를 둔다는 뜻이다.

@<정점을 골라 빈 그래프에 넣는다@>=
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
@<빈 그래프를 마련하고 표식을 짓는다@>@;
@<무게를 셈해 고른 노드에 정점을 배정한다@>@;

@ @<빈 그래프를 마련하고 표식을 짓는다@>=
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

@ 무게를 매겨 노드들을 |gbsort.LinkSort|로 정렬하고, 무게가 큰 차례로 |n|개를
훑어 앞 |x|개를 뺀 나머지에 정점을 배정한다. 정렬 리스트는 \CEE/처럼 마지막
노드가 머리이고 |Link|가 앞 노드를 가리키게 엮는다.

@<무게를 셈해 고른 노드에 정점을 배정한다@>=
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
@<정렬된 노드에서 정점을 골라 배정한다@>@;

@ @<정렬된 노드에서 정점을 골라 배정한다@>=
vi := int64(0)
skip := b.x    // 이만큼은 뺀다
count := b.n   // 이만큼의 노드를 본다
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

@ 두 번째 읽기(꼼꼼한 읽기)다. 파일을 다시 열어, 고른 인물의 이름과 설명을
적고, 그래프의 간선을 만든다.

@<|bgraph|와 그 도우미@>=
func (b *bookBuilder) fill() error {
	f, err := gbio.Open(b.fileName)
	if err != nil {
		return gbgraph.Impossible + 1 // 앞서 성공했으니 있을 수 없다
	}
	@<인물 자료를 다시 읽어 정점 이름과 설명을 적는다@>@;
	if b.bipartite {
		@<장 정보를 다시 읽어 이분 간선을 만든다@>@;
	} else {
		@<장 정보를 다시 읽어 마주침 간선을 만든다@>@;
	}
	if f.Close() != nil {
		return gbgraph.Impossible + 2
	}
	return nil
}

@ 고른 인물(|vert|이 |nil|이 아닌)에만 이름·설명과 통계를 적는다.

@<인물 자료를 다시 읽어 정점 이름과 설명을 적는다@>=
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
		v.Z.S = f.String('\n')  // 설명 부분(|desc|)
		v.Y.I = p.Data.in       // |in_count|
		v.X.I = p.Data.out      // |out_count|
		v.U.I = c               // |short_code|
	}
	f.NextLine()
}
f.NextLine()

@ 장 이름의 |'\n'|을 떼어 저장하는 잔심부름이다. |'&'| 이어짐 줄이면 저장하지
않는다.

@<|bgraph|와 그 도우미@>=
func (b *bookBuilder) noteChapter(k int64, s string) (cont bool) {
	if len(s) > 0 && s[0] == '&' {
		return true
	}
	b.chapName[k] = strings.TrimSuffix(s, "\n")
	return false
}

@ 무향 그래프일 때, 각 장의 클릭들을 읽어 클릭 안 모든 정점 쌍을 잇는다. 호의
|chap_no|(|A.I|)에는 그 간선을 처음 낳은 장 번호를 적는다.

@<장 정보를 다시 읽어 마주침 간선을 만든다@>=
clique := make([]*gbgraph.Vertex, 0, cliqueMax)
for k := int64(1); !f.EOF(); k++ {
	if b.noteChapter(k, f.String(':')) {
		k--
	}
	if k >= b.firstChapter && k <= b.lastChapter {
		@<이 장의 클릭들을 읽어 정점 쌍을 잇는다@>@;
	}
	f.NextLine()
}

@ 클릭은 콤마로 이어진 코드들이고, 세미콜론이나 줄 끝으로 끝난다. 클릭 하나를
다 읽으면 그 안의 모든 쌍을 인접하게 만든다.

@<이 장의 클릭들을 읽어 정점 쌍을 잇는다@>=
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
	@<클릭 안 모든 쌍을 잇는다@>@;
}

@ @<클릭 안 모든 쌍을 잇는다@>=
for qi := 0; qi+1 < len(clique); qi++ {
	for ri := qi + 1; ri < len(clique); ri++ {
		b.makeAdjacent(clique[qi], clique[ri], k)
	}
}

@ 두 정점이 아직 이웃이 아니면 간선을 만들고, 간선을 이루는 두 호의 |chap_no|를
현재 장 번호로 적는다.

@<|bgraph|와 그 도우미@>=
func (b *bookBuilder) makeAdjacent(u, v *gbgraph.Vertex, k int64) {
	for a := u.Arcs; a != nil; a = a.Next {
		if a.Tip == v {
			return // 이미 이웃이다
		}
	}
	b.g.NewEdge(u, v, 1)
	a := u.Arcs // 방금 만든 호와 그 짝
	a.A.I, a.Partner.A.I = k, k
}

@ 이분 그래프일 때는, 선택된 장마다 그 장 정점과 그 장에 나오는 선택된 인물
사이에 간선을 놓는다. 장 정점 |u|의 |in_count|는 차수(그 장에 나온 선택된
인물 수), |out_count|는 빠진 인물 수다.

@<장 정보를 다시 읽어 이분 간선을 만든다@>=
for i := int64(0); i < b.characters; i++ {
	b.nodes[i].Data.chap = 0
}
for k := int64(1); !f.EOF(); k++ {
	cont := b.noteChapter(k, f.String(':'))
	if cont {
		k--
	}
	if k >= b.firstChapter && k <= b.lastChapter {
		@<이 장의 이분 간선을 만든다@>@;
	}
	f.NextLine()
}

@ @<이 장의 이분 간선을 만든다@>=
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

@ 표식에 쓰는 제목은 파일 이름에서 되찾는다. |bgraph|가 이미 |title|을 갖고
있지 않으므로, 파일 이름의 바탕(basename)에서 확장자를 떼어 쓴다.

@<|bgraph|와 그 도우미@>=
func (b *bookBuilder) title() string {
	return strings.TrimSuffix(filepath.Base(b.fileName), ".dat")
}

@* 시험. 기본 |Book("anna",...)|은 톨스토이의 {\sl Anna Karenina\/} 138개
인물을 모두 담는다. Knuth의 발표값과 대조한다.

@(gbbooks_test.go@>=
package gbbooks

import (
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
)

const dataDir = "../data"

@<기본 anna 그래프 시험@>@;
@<가중 선택과 장 한정 시험@>@;
@<이분 그래프 시험@>@;

@ |Book("anna",0,0,0,0,0,0,0)|은 정점 138개짜리 그래프를 짓는다. 표식과
정점 수, 그리고 한 인물의 코드·이름을 확인한다.

@<기본 anna 그래프 시험@>=
func TestAnnaFull(t *testing.T) {
	g, err := Book("anna", 0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 138 {
		t.Fatalf("N = %d, 원함 138", g.N)
	}
	if g.ID != `book("anna",138,0,1,239,0,0,0)` {
		t.Errorf("ID = %q", g.ID)
	}
	if g.M == 0 {
		t.Error("간선이 하나도 없다")
	}
}

@ 첫 정점은 무게가 가장 큰 인물이다. 코드(|U.I|)를 두 글자로 되살려 확인하고,
이름·설명이 채워졌는지 본다.

@<기본 anna 그래프 시험@>=
func TestAnnaVertexFields(t *testing.T) {
	g, err := Book("anna", 0, 0, 0, 0, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	v := &g.Vertices[0]
	if v.Name == "" || v.Z.S == "" {
		t.Errorf("정점 이름/설명이 비었다: %q / %q", v.Name, v.Z.S)
	}
	if v.U.I <= 0 || v.U.I >= maxCode {
		t.Errorf("short_code = %d, 범위 밖", v.U.I)
	}
}

@ |Book("anna",50,0,0,0,1,1,0)|은 가장 자주 나오는 50명으로 한정한다.
장 구간을 좁히면(|10..120|) 정점은 그대로되 간선이 줄어든다.

@<가중 선택과 장 한정 시험@>=
func TestAnnaSelect(t *testing.T) {
	g, err := Book("anna", 50, 0, 0, 0, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 50 {
		t.Fatalf("N = %d, 원함 50", g.N)
	}
	sub, err := Book("anna", 50, 0, 10, 120, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if sub.N != 50 {
		t.Fatalf("N = %d, 원함 50", sub.N)
	}
	if sub.M > g.M {
		t.Errorf("장을 한정했는데 간선이 늘었다: %d > %d", sub.M, g.M)
	}
}

@ |x=1|은 무게가 가장 큰 인물 하나를 뺀다. {\sl David Copperfield\/}는 인물이
87명이라, |x=1|이면 정점이 86개가 된다.

@<가중 선택과 장 한정 시험@>=
func TestDavidExclude(t *testing.T) {
	g, err := Book("david", 0, 1, 0, 0, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 86 {
		t.Errorf("N = %d, 원함 86", g.N)
	}
	if g.ID != `book("david",87,1,1,64,1,1,0)` {
		t.Errorf("ID = %q", g.ID)
	}
}

@ |BiBook("anna",50,0,10,120,1,1,0)|은 $50+111$개 정점의 이분 그래프를 짓는다.
첫 갈래는 인물 50명, 둘째 갈래는 10장부터 120장까지의 111개 장이다.

@<이분 그래프 시험@>=
func TestBiBookAnna(t *testing.T) {
	g, err := BiBook("anna", 50, 0, 10, 120, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 50+111 {
		t.Fatalf("N = %d, 원함 161", g.N)
	}
	if g.N1() != 50 {
		t.Errorf("N1 = %d, 원함 50", g.N1())
	}
	if !isBipartite(g) {
		t.Error("이분 그래프가 아니다")
	}
}

@ 이분성 검사: 모든 간선이 두 갈래를 잇는지(양 끝이 |N1| 경계의 반대쪽인지)
확인한다.

@<이분 그래프 시험@>=
func isBipartite(g *gbgraph.Graph) bool {
	n1 := g.N1()
	for i := int64(0); i < g.N; i++ {
		left := i < n1
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if (g.Index(a.Tip) < n1) == left {
				return false
			}
		}
	}
	return true
}

@* 찾아보기.
