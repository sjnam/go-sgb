% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 roget_components.w를 Go로 이식한다.
@i ../../gbtypes.w

\input kotexgweb
\def\title{ROGET\_\,COMPONENTS}

@* 강한 성분. 이 시연 프로그램은 Roget의 유의어 사전에서 나온 GraphBase
그래프의 강한 성분(strong component)을, Tarjan 알고리즘의 한 변형[R. E.
Tarjan, ``Depth-first search and linear graph algorithms,'' {\sl SIAM Journal
on Computing\/ \bf1} (1972), 146--160]으로 구한다. 아울러 성분들 사이의 관계도
알아낸다.

두 정점이 서로에게서 유향 경로로 닿을 수 있으면, 그리고 오직 그럴 때만, 같은
강한 성분에 든다. 우리는 강한 성분을 ``역위상 차례(reverse topological
order)''로 찍는다. 곧 |v|가 |u|에서 닿되 |u|는 |v|에서 닿지 못하면, |v|를 품은
성분을 |u|를 품은 성분보다 먼저 적는다. |roget| 그래프의 정점은 이름과 범주
번호로 함께 나타낸다.

@ \UNIX/ 방식 명령줄 옵션으로 여러 그래프를 살펴볼 수 있다. |roget(n,d,p,s)|의
매개변수를 바꾸려면 \.{-n}$\langle$수$\rangle$, \.{-d}$\langle$수$\rangle$,
\.{-p}$\langle$수$\rangle$, \.{-s}$\langle$수$\rangle$를 쓰고, 그래프 자체를
갈아 끼우려면 \.{-g}$\langle$파일$\rangle$을 쓴다.

@c
package main

import (
	"fmt"
	"os"
	"strconv"
	@#
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbroget"
	"github.com/sjnam/go-sgb/gbsave"
)

// GraphBase 타입을 짧은 이름으로 바로 쓴다.
type (
	Graph  = gbgraph.Graph
	Vertex = gbgraph.Vertex
	Arc    = gbgraph.Arc
)

@<도우미@>

func main() {
	@<명령줄 옵션을 읽는다@>
	@<그래프를 마련한다@>
	fmt.Printf("Reachability analysis of %s\n\n", g.ID)
	@<|g|에 Tarjan 알고리즘을 실행한다@>
}

@ 다섯 유틸리티 필드가 알고리즘의 현재 상태를 나타낸다: |rank|, |parent|,
|untagged|, |link|, |min|. 정점의 |cat_no|(범주 번호)는 |gbroget|이 |U.I|에
담아 두었다. 정점 하나를 ``$\langle$번호$\rangle$ $\langle$이름$\rangle$'' 꼴로
찍는 |specs|를 마련한다. 외부 그래프를 \.{-g}로 복원한 경우엔 범주 번호 대신
정점의 자리 번호(1부터)를 쓴다. 다섯 유틸리티 필드가 쓰인다: |rank|(|Z.I|),
|parent|(|Y.V|), |untagged|(|X.A|), |link|(|W.V|), |min|(|V.V|). \CEE/ 원본은
공용체 덕에 |untagged|와 마지막 단계의 |arcFrom|이 같은 필드 |x|를 나눠 썼지만,
\GO/에서는 |X.A|와 |X.V|가 서로 다른 필드라 그냥 따로 쓰면 된다.

@<도우미@>=
// |specs|는 정점 |v|를 ``번호 이름'' 꼴 문자열로 만든다.
func specs(g *Graph, v *Vertex, fromFile bool) string {
	num := v.U.I // |cat_no|
	if fromFile {
		num = g.Index(v) + 1
	}
	return fmt.Sprintf("%d %s", num, v.Name)
}

@ 각 인자의 접두어를 떼어 해당 매개변수에 넣는다. \.{-g}$\langle$파일$\rangle$은
|roget| 대신 복원할 외부 그래프를 가리킨다.

@<명령줄 옵션을 읽는다@>=
var n, d, p, s int64
var fileName string
var dir string
usage := func() {
	fmt.Fprintf(os.Stderr, "Usage: %s [-nN][-dN][-pN][-sN][-DDIR][-gFILE]\n", os.Args[0])
	os.Exit(2)
}
num := func(str string) int64 {
	x, err := strconv.ParseInt(str, 10, 64)
	if err != nil {
		usage()
	}
	return x
}
for _, arg := range os.Args[1:] {
	switch {
	case len(arg) >= 2 && arg[0] == '-' && arg[1] == 'n':
		n = num(arg[2:])
	case len(arg) >= 2 && arg[0] == '-' && arg[1] == 'd':
		d = num(arg[2:])
	case len(arg) >= 2 && arg[0] == '-' && arg[1] == 'p':
		p = num(arg[2:])
	case len(arg) >= 2 && arg[0] == '-' && arg[1] == 's':
		s = num(arg[2:])
	case len(arg) >= 2 && arg[0] == '-' && arg[1] == 'D':
		dir = arg[2:]
	case len(arg) >= 2 && arg[0] == '-' && arg[1] == 'g':
		fileName = arg[2:]
	default:
		usage()
	}
}

@ 그래프는 |roget|이 짓거나, \.{-g}가 주어졌으면 파일에서 복원한다. 데이터
디렉터리는 \.{-D}로 정하며 기본값은 |"data"|다.

@<그래프를 마련한다@>=
fromFile := fileName != ""
var g *Graph
var err error
if fromFile {
	g, err = gbsave.RestoreGraph(fileName)
} else {
	g, err = gbroget.Roget(n, d, p, s, dir)
}
if err != nil {
	fmt.Fprintf(os.Stderr, "그래프를 만들 수 없습니다 (오류 %v)\n", err)
	os.Exit(1)
}

@* Tarjan 알고리즘. 이 알고리즘은 본디 재귀적이다. 하지만 어떤 컴퓨터는 깊은
재귀에 허덕이므로, \CEE/의 실행시간 스택 대신 연결 리스트로 재귀를 손수
펼쳐 구현한다. 각 정점은 세 단계를 거친다: 처음엔 ``안 봄(unseen)'', 다음엔
``활성(active)'', 끝으로 강한 성분에 배정되면 ``정착(settled)''이다.

정수 |rank|는 안 본 정점에서 0이다. 정점이 처음 조사되어 활성이 되면 그
|rank|는 0 아닌 값이 되어 그대로 남는다. $k$번째로 활성이 된 정점이 |rank|
$k$를 받는다. 정점이 마침내 정착하면 |rank|는 무한대로 되돌아간다.

활성 정점들은 늘 유향 나무를 이루며, |v.parent==u|는 |u|에서 |v|로 가는 나무
호를 뜻한다. 뿌리만 |parent|가 |nil|이다. 정점이 정착하면 |parent|의 뜻이
바뀌어, 그 정점이 속한 강한 성분의 대표를 가리킨다. |link|는 두 스택
(활성·정착)에서 자기 바로 아래 정점을 가리킨다. |min|은 알고리즘을 돌아가게
하는 까다로운 부분으로, 활성이거나 안 본 동안에만 뜻이 있다.

@ 이 규약대로 자료구조를 시작하기는 쉽다. |untagged|를 |arcs|로, |rank|를 0으로
두고, 두 스택을 비우고, 본 정점 수 |nn|을 0으로 둔다.

@<|g|에 Tarjan 알고리즘을 실행한다@>=
var activeStack, settledStack *Vertex
var nn int64
for v := range g.AllVertices() {
	v.Z.I = 0      // |rank|
	v.X.A = v.Arcs // |untagged|
}
@<안 본 정점마다 그를 뿌리로 깊이 우선 탐색을 한다@>
@<성분 사이를 잇는 호를 대표 하나씩 찍는다@>

@ 안 본 정점이 남아 있으면 그를 뿌리로 새 깊이 우선 탐색을 시작한다. 탐색은
연결 리스트로 펼친 되재귀 고리로 돈다: 현재 정점 |v|에서 한 걸음씩 나아가며,
때로 자식으로 내려가고 때로 부모로 되올라간다.

@<안 본 정점마다 그를 뿌리로 깊이 우선 탐색을 한다@>=
for vv := range g.AllVertices() {
	if vv.Z.I != 0 { // 이미 보았다
		continue
	}
	v := vv
	v.Y.V = nil // |parent|
	@<정점 |v|를 활성으로 만든다@>
	for v != nil {
		@<현재 정점 |v|에서 한 걸음 나아간다@>
	}
}

@ @<정점 |v|를 활성으로 만든다@>=
nn++
v.Z.I = nn         // |rank|
v.W.V = activeStack // |link|
activeStack = v
v.V.V = v // |min|

@ 한 걸음은 세 경우로 갈린다: 현재 정점에 그대로 머물거나, 새 자식으로
내려가거나, 부모로 되올라간다. |v|에 아직 태그 안 붙은 호 |a|가 있으면 그것을
태그하고, 그 호가 안 본 정점으로 가면 나무 호가 되어 그리로 내려간다. 이미 본
정점으로 가면 비나무 호이므로 |v.min|만 갱신한다. 남은 호가 없으면 |v|가
성숙(mature)하여 부모로 되올라간다.

@<현재 정점 |v|에서 한 걸음 나아간다@>=
if a := v.X.A; a != nil { // |untagged|
	u := a.Tip
	v.X.A = a.Next // |v|에서 |u|로 가는 호를 태그한다
	if u.Z.I != 0 { // |u|를 이미 보았다
		if u.Z.I < v.V.V.Z.I {
			v.V.V = u // 비나무 호이니 |v.min|만 고친다
		}
	} else { // |u|는 아직 안 본 정점이다
		u.Y.V = v // |v|에서 |u|로 가는 호가 새 나무 호가 된다
		v = u     // 이제 |u|가 현재 정점이다
		@<정점 |v|를 활성으로 만든다@>
	}
} else { // |v|의 모든 호가 태그되어 |v|가 성숙한다
	u := v.Y.V // 나무를 되올라갈 채비
	if v.V.V == v {
		@<|v|와 활성 스택 위의 그 자손들을 나무에서 떼어 강한 성분으로 삼는다@>
	} else if v.V.V.Z.I < u.V.V.Z.I {
		u.V.V = v.V.V // |u|에서 |v|로 가는 호가 성숙해 |v.min|이 |u|에 보인다
	}
	v = u // |v|의 옛 부모가 새 현재 정점이 된다
}

@ |v.min==v|이면 |v|와 그 자손들이 강한 성분을 이룬다. 활성 스택 맨 위에
잇달아 놓인 그들을 정착 스택으로 옮기고, 성분의 내용을 찍는다. 무한대 |rank|는
|g.N|으로 삼는다(넉넉히 크다). 정착한 정점은 |parent|가 성분의 대표 |v|를
가리키게 된다.

@<|v|와 활성 스택 위의 그 자손들을 나무에서 떼어 강한 성분으로 삼는다@>=
t := activeStack
activeStack = v.W.V
v.W.V = settledStack
settledStack = t // 한 스택의 꼭대기를 다른 스택으로 옮겼다
fmt.Printf("Strong component `%s'", specs(g, v, fromFile))
if t == v {
	fmt.Println() // 정점 하나짜리
} else {
	fmt.Println(" also includes:")
	for t != v {
		fmt.Printf(" %s (from %s; ..to %s)\n",
			specs(g, t, fromFile), specs(g, t.Y.V, fromFile), specs(g, t.V.V, fromFile))
		t.Z.I = g.N // 이제 |t|는 정착했다
		t.Y.V = v   // 그리고 |v|가 새 강한 성분을 대표한다
		t = t.W.V
	}
}
v.Z.I = g.N // |v|도 정착했다
v.Y.V = v   // 그리고 제 강한 성분을 대표한다

@ 강한 성분을 다 찾은 뒤엔 성분 사이의 관계도, 어떤 이음도 두 번 넘게 말하지
않으면서 셈할 수 있다. 정착 스택을 바로 이 일을 정렬·검색 없이 하도록 쌓아
두었다---같은 성분의 정점들이 스택에 나란히 모여 있기 때문이다. 이 단계에서는
아까 |untagged|로 쓰던 필드 |x|를 |arcFrom|이라는 이름으로 다시 쓴다.

@<성분 사이를 잇는 호를 대표 하나씩 찍는다@>=
fmt.Println("\nLinks between components:")
for v := settledStack; v != nil; v = v.W.V {
	u := v.Y.V // |parent|, 곧 |v|의 성분 대표
	u.X.V = u  // |arcFrom|
	for a := range v.AllArcs() {
		w := a.Tip.Y.V // |a.Tip|의 성분 대표
		if w.X.V != u {
			w.X.V = u
			fmt.Printf("%s -> %s (e.g., %s -> %s)\n",
				specs(g, u, fromFile), specs(g, w, fromFile),
				specs(g, v, fromFile), specs(g, a.Tip, fromFile))
		}
	}
}

@* 찾아보기.
