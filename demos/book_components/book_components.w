% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 book_components.w를 Go로 이식한다.
@i ../../types.w

\input kotexgweb
\def\title{BOOK\_\,COMPONENTS}
\def\<#1>{\hbox{$\langle$\rm#1$\rangle$}}

@s solver int

@* 이중 성분. 이 시연 프로그램은 세계 문학에서 뽑은 GraphBase 그래프의 이중연결
성분(biconnected component, 줄여서 ``bicomponent'')을, Hopcroft와 Tarjan의
알고리즘[R.~E. Tarjan, ``Depth-first search and linear graph algorithms,''
{\sl SIAM Journal on Computing\/ \bf1} (1972), 146--160]의 변형으로 헤아린다.
분리점(articulation point)과 보통의 연결 성분도 덤으로 얻는다.

두 간선이 같거나 함께 하나의 단순 순환에 놓이면, 그 둘은 같은 이중연결 성분에
속한다. 연결 그래프의 이중 성분들은 자유 트리(free tree)를 이루는데, 공통
정점을 가진 두 이중 성분을 이웃으로 본다. 그 공통 정점이 분리점이다. 한 이중
성분을 뿌리로 삼으면, 나머지는 정점 목록으로 --- 뿌리 쪽으로 이끄는 분리점을
맨 끝에 두어 --- 나타낼 수 있다. 이 프로그램은 이중 성분을 바로 그렇게 찍는다.

@ 명령줄 옵션으로 여러 그래프를 살필 수 있다: |-t|\<title>, |-n|\<수>,
|-x|\<수>, |-f|\<수>, |-l|\<수>, |-i|\<수>, |-o|\<수>, |-s|\<수>는
|Book(t,n,x,f,l,i,o,s)|의 매개변수를 바꾼다. |-v|나 |-V|는 인물 코드 설명을
먼저 찍는데, |-V|는 무게까지 더 자세히 보인다. 특별한 |-g|\<파일명>은 다른 모든
옵션을 제치고, |SaveGraph|로 저장해 둔 외부 그래프를 대신 쓴다.

@c
package main

@<내포하는 패키지들@>

@<자료 구조@>@;
@<이름 짓기와 인물 소개@>@;
@<Hopcroft-Tarjan 알고리즘@>@;

func main() {
	@<명령줄 옵션을 읽는다@>@;
	@<그래프를 마련한다@>@;
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	s := &solver{g: g, book: fileName == "", out: out}
	fmt.Fprintf(out, "Biconnectivity analysis of %s\n\n", g.ID)
	if verbose > 0 {
		s.printCast(verbose, inWeight, outWeight)
	}
	s.hopcroftTarjan()
}

@ @<내포하는...@>=
import (
	"bufio"
	"fmt"
	"io"
	"log"
	"os"
	"strconv"
	"strings"

	"github.com/sjnam/go-sgb/gbbooks"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/gbsave"
)

@ 알고리즘 상태를 |solver|에 담는다. \CEE/ 원본은 전역 |nn|·|active_stack|·
|dummy|·|artic_pt|에 기댔지만, 우리는 이들을 구조체에 모아 패키지 수준 가변
상태를 피한다. |book|은 |Book| 그래프인지(2글자 코드가 있는지) 여부다.

@<자료 구조@>=
type solver struct {
	g           *gbgraph.Graph
	book        bool
	nn          int64          // 지금까지 본 정점의 수
	activeStack *gbgraph.Vertex // 활성 정점 스택의 꼭대기
	dummy       *gbgraph.Vertex // 뿌리의 가상 부모
	articPt     *gbgraph.Vertex // 나중에 찍을 분리점
	out         io.Writer
}

@ |-g|가 있으면 그 파일을 복원하고, 없으면 |Book|으로 그래프를 짓는다.

@<그래프를 마련한다@>=
var g *gbgraph.Graph
var err error
if fileName != "" {
	g, err = gbsave.RestoreGraph(fileName)
} else {
	g, err = gbbooks.Book(title, n, x, first, last, inWeight, outWeight, seed, dir)
}
if err != nil {
	log.Fatalf("그래프를 만들 수 없습니다: %v", err)
}

@ 명령줄 옵션 훑기다. \.{-tN} 꼴이라 접두어를 떼어 파싱한다. |-g|가 있으면
|verbose|는 꺼진다(복원된 그래프에는 인물 코드가 없다).

@<명령줄 옵션을 읽는다@>=
title := "anna"
dir := "data"
var n, x, first, last int64
inWeight, outWeight, seed := int64(1), int64(1), int64(0)
var verbose int
var fileName string
num := func(s string) int64 {
	v, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		log.Fatalf("잘못된 수: %q", s)
	}
	return v
}
@<인자들을 훑어 옵션을 정한다@>@;
if fileName != "" {
	verbose = 0
}

@ @<인자들을 훑어 옵션을 정한다@>=
for _, arg := range os.Args[1:] {
	switch {
	case strings.HasPrefix(arg, "-t"):
		title = arg[2:]
	case strings.HasPrefix(arg, "-n"):
		n = num(arg[2:])
	case strings.HasPrefix(arg, "-x"):
		x = num(arg[2:])
	case strings.HasPrefix(arg, "-f"):
		first = num(arg[2:])
	case strings.HasPrefix(arg, "-l"):
		last = num(arg[2:])
	case strings.HasPrefix(arg, "-i"):
		inWeight = num(arg[2:])
	case strings.HasPrefix(arg, "-o"):
		outWeight = num(arg[2:])
	case strings.HasPrefix(arg, "-s"):
		seed = num(arg[2:])
	case arg == "-v":
		verbose = 1
	case arg == "-V":
		verbose = 2
	case strings.HasPrefix(arg, "-g"):
		fileName = arg[2:]
	case strings.HasPrefix(arg, "-D"):
		dir = arg[2:]
	default:
		log.Fatalf("사용법: %s [-ttitle][-nN][-xN][-fN][-lN][-iN][-oN][-sN][-v][-V][-gfoo]", os.Args[0])
	}
}

@ 이중 성분을 찍을 때 각 인물은 자료 파일의 2글자 코드로 표시한다. 복원된
그래프(|book|이 아님)에서는 정점 이름을 그대로 쓴다.

@<이름 짓기와 인물 소개@>=
func (s *solver) name(v *gbgraph.Vertex) string {
	if !s.book {
		return v.Name
	}
	code := v.U.I // |short_code|
	return string([]byte{gbio.ImapChr(code / 36), gbio.ImapChr(code % 36)})
}

@ |-v|/|-V|일 때, 고른 인물들의 명단을 먼저 찍는다. |-V|는 설명과 가중
등장 횟수까지 보인다.

@<이름 짓기와 인물 소개@>=
func (s *solver) printCast(verbose int, inWeight, outWeight int64) {
	for i := int64(0); i < s.g.N; i++ {
		v := &s.g.Vertices[i]
		if verbose == 1 {
			fmt.Fprintf(s.out, "%s=%s\n", s.name(v), v.Name)
		} else {
			fmt.Fprintf(s.out, "%s=%s, %s [weight %d]\n", s.name(v), v.Name,
				v.Z.S, inWeight*v.Y.I+outWeight*v.X.I)
		}
	}
	fmt.Fprintln(s.out)
}

@*알고리즘. Hopcroft-Tarjan 알고리즘은 본디 재귀적이지만, 깊은 재귀에 약한
시스템도 있어 우리는 연결 리스트로 재귀를 명시적으로 편다. 각 정점은 세 단계를
거친다: 처음엔 ``안 본''(unseen), 다음엔 ``활성''(active), 끝으로 이중 성분에
배정되면 ``정착''(settled)이다.

상태는 정점의 유틸리티 필드 다섯 개로 나타낸다. \CEE/의 공용체와 달리 Go의
필드는 서로 독립이라, |Book| 그래프의 필드(|Z.S|, |Y.I|, \dots)와 겹치지 않고
나란히 쓸 수 있다 --- 그래서 명단을 먼저 찍은 뒤 알고리즘을 돌려도 안전하다.
|rank=Z.I|(안 본 정점은 0), |parent=Y.V|, |untagged=X.A|, |link=W.V|,
|min=V.V|이다.

@<Hopcroft-Tarjan 알고리즘@>=
func (s *solver) hopcroftTarjan() {
	s.dummy = new(gbgraph.Vertex) // rank 0
	@<모든 정점을 안 본 상태로, 모든 호를 태그 안 됨으로 둔다@>@;
	for i := int64(0); i < s.g.N; i++ {
		vv := &s.g.Vertices[i]
		if vv.Z.I == 0 { // 아직 안 봤다
			s.dfs(vv)
		}
	}
}

@ @<모든 정점을 안 본 상태로, 모든 호를 태그 안 됨으로 둔다@>=
for i := int64(0); i < s.g.N; i++ {
	v := &s.g.Vertices[i]
	v.Z.I = 0    // rank
	v.X.A = v.Arcs // untagged
}
s.nn = 0
s.activeStack = nil

@ |vv|를 뿌리로 하는 깊이 우선 탐색이다. |v|가 현재 정점이며, |dummy|로
되짚어 올라올 때까지 한 걸음씩 탐색한다.

@<Hopcroft-Tarjan 알고리즘@>=
func (s *solver) dfs(vv *gbgraph.Vertex) {
	v := vv
	v.Y.V = s.dummy // parent
	s.makeActive(v)
	for {
		v = s.explore(v)
		if v == s.dummy {
			break
		}
	}
}

@ 정점 |v|를 활성으로 만든다: 새 rank를 주고, 활성 스택에 얹고, |min|을
자기 부모로 둔다.

@<Hopcroft-Tarjan 알고리즘@>=
func (s *solver) makeActive(v *gbgraph.Vertex) {
	s.nn++
	v.Z.I = s.nn        // rank
	v.W.V = s.activeStack // link
	s.activeStack = v
	v.V.V = v.Y.V // min = parent
}

@ 현재 정점에서 한 걸음 탐색한다. 정점이 제자리에 머물거나, 새 자식으로
내려가거나, 부모로 되짚어 올라가는 세 경우가 있다. 새 현재 정점을 돌려준다.

@<Hopcroft-Tarjan 알고리즘@>=
func (s *solver) explore(v *gbgraph.Vertex) *gbgraph.Vertex {
	a := v.X.A // v의 첫 태그 안 된 호
	if a != nil {
		@<호 |a|를 태그하고 따라간다@>@;
		return v
	}
	@<|v|가 성숙했으니 부모로 되짚어 올라간다@>@;
	return v
}

@ 태그 안 된 호 |a|가 있으면, |v|에서 |u=a.tip|으로 가는 호를 태그한다. |u|를
이미 봤으면 비트리 호이니 |v.min|만 갱신하고, 못 봤으면 트리 호이니 |u|가 새
현재 정점이 된다.

@<호 |a|를 태그하고 따라간다@>=
u := a.Tip
v.X.A = a.Next // 호를 태그한다
if u.Z.I != 0 {
	// 이미 본 |u|: 비트리 호
	if u.Z.I < v.V.V.Z.I {
		v.V.V = u // min을 갱신
	}
} else {
	// 아직 안 본 |u|: 새 트리 호
	u.Y.V = v // parent
	v = u
	s.makeActive(v)
}

@ |v|의 모든 호가 태그됐으면 |v|는 성숙한다. |v.min==v.parent|이면 |v|와 그
자손들이 |u=v.parent|와 함께 이중 성분을 이룬다. 아니면 |u|에서 |v.min|이
보이게 됐으니 |u.min|을 갱신한다.

@<|v|가 성숙했으니 부모로 되짚어 올라간다@>=
u := v.Y.V // 되짚어 올라갈 부모
if v.V.V == u {
	s.reportBicomponent(v, u)
} else if v.V.V.Z.I < u.V.V.Z.I {
	u.V.V = v.V.V // u.min = v.min
}
v = u

@ 활성 스택 꼭대기의 |v|와 그 자손들을 떼어 내, |u|와 함께 이중 성분으로
알린다. 스택의 정점들은 rank 순으로 놓이고, |v|의 자손들은 언제나 스택
꼭대기에 잇달아 나타난다.

@<Hopcroft-Tarjan 알고리즘@>=
func (s *solver) reportBicomponent(v, u *gbgraph.Vertex) {
	if u == s.dummy {
		@<외딴 정점이거나 연결 성분의 끝을 알린다@>@;
		return
	}
	@<이중 성분과 그 정점들을 찍는다@>@;
}

@ |u|가 |dummy|이면 |v|는 한 연결 성분의 마지막 이중 성분(또는 외딴 정점)이다.

@<외딴 정점이거나 연결 성분의 끝을 알린다@>=
if s.articPt != nil {
	fmt.Fprintf(s.out, " and %s (this ends a connected component of the graph)\n",
		s.name(s.articPt))
} else {
	fmt.Fprintf(s.out, "Isolated vertex %s\n", s.name(v))
}
s.activeStack = nil
s.articPt = nil

@ 그렇지 않으면 |u|는 뒤이을 이중 성분에도 나타날 분리점이다. |v|부터 스택을
훑어 이중 성분의 정점들을 찍고, |u|를 다음 출력을 위해 |articPt|에 남긴다.

@<이중 성분과 그 정점들을 찍는다@>=
if s.articPt != nil {
	fmt.Fprintf(s.out, " and articulation point %s\n", s.name(s.articPt))
}
t := s.activeStack
s.activeStack = v.W.V // v.link
fmt.Fprintf(s.out, "Bicomponent %s", s.name(v))
if t == v {
	fmt.Fprintln(s.out) // 정점 하나
} else {
	@<이중 성분의 나머지 정점들을 찍는다@>@;
}
s.articPt = u

@ @<이중 성분의 나머지 정점들을 찍는다@>=
fmt.Fprintln(s.out, " also includes:")
for t != v {
	fmt.Fprintf(s.out, " %s (from %s; ..to %s)\n",
		s.name(t), s.name(t.Y.V), s.name(t.V.V))
	t = t.W.V // t.link
}

@* 시험. |Book("anna",...)|의 이중연결 분석을 돌려, 출력이 올바른 얼개를
갖추는지 살핀다.

@(book_components_test.go@>=
package main

import (
	"strings"
	"testing"

	"github.com/sjnam/go-sgb/gbbooks"
)

@<anna 이중 성분 시험@>@;

@ 전체 |anna| 그래프에 알고리즘을 돌리면, 한 연결 성분의 끝을 알리는 줄과
이중 성분 줄들이 나와야 한다. 인물 이름 대신 2글자 코드가 쓰이는지도 본다.

@<anna 이중 성분 시험@>=
func TestAnnaBicomponents(t *testing.T) {
	g, err := gbbooks.Book("anna", 0, 0, 0, 0, 1, 1, 0, "../../data")
	if err != nil {
		t.Fatal(err)
	}
	var sb strings.Builder
	s := &solver{g: g, book: true, out: &sb}
	s.hopcroftTarjan()
	out := sb.String()
	if !strings.Contains(out, "Bicomponent") {
		t.Errorf("이중 성분 줄이 없다:\n%s", out)
	}
	if !strings.Contains(out, "connected component of the graph") {
		t.Errorf("연결 성분 끝 줄이 없다")
	}
}

@ 모든 인물이 어떤 성분에든 배정돼, 알고리즘이 정점을 빠뜨리지 않는지 확인한다.
활성 스택은 끝에 비어 있어야 한다.

@<anna 이중 성분 시험@>=
func TestAllSettled(t *testing.T) {
	g, err := gbbooks.Book("anna", 30, 1, 0, 0, 1, 1, 0, "../../data")
	if err != nil {
		t.Fatal(err)
	}
	var sb strings.Builder
	s := &solver{g: g, book: true, out: &sb}
	s.hopcroftTarjan()
	for i := int64(0); i < g.N; i++ {
		if g.Vertices[i].Z.I == 0 {
			t.Fatalf("정점 %d가 안 본 채로 남았다", i)
		}
	}
	if s.activeStack != nil {
		t.Error("활성 스택이 비지 않았다")
	}
}

@* 찾아보기.
