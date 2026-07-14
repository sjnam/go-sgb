% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 football.w를 Go로 이식한다.
@i ../../types.w

\input kotexgweb
\def\title{FOOTBALL}
\def\<#1>{\hbox{$\langle$\rm#1$\rangle$}}

@* 들어가며. 이 시연 프로그램은 {\sc GB\_GAMES}가 지은 그래프로, 한 팀이 다른
팀보다 터무니없이 큰 차로 앞선다고 ``증명''하는 긴 점수 사슬을 찾는다. 이를테면
스탠퍼드에서 하버드로 이어지는 사슬을 찾으면 다음처럼 나온다:
$$\vbox{\halign{\tt#\hfil\cr
 Oct 06: Stanford Cardinal 36, Notre Dame Fighting Irish 31 (+5)\cr
 Oct 20: Notre Dame Fighting Irish 29, Miami Hurricanes 20 (+14)\cr
\omit\qquad\vdots\cr
 Sep 15: Columbia Lions 6, Harvard Crimson 9 (+2185)\cr}}$$
사슬 위 각 경기는 앞 팀이 뒤 팀을 이긴 점수 차를 |del|로 삼아 이어지고, 괄호 안은
사슬을 따라 쌓인 점수 차의 합이다.

@ 프로그램은 시작 팀과 목표 팀을 묻는다. 시작 팀 물음에 그냥 \<return>을 치면
끝나고, 목표 팀 물음에 그냥 \<return>을 치면 시작 팀을 다시 묻는다. 팀 이름은
\.{games.dat}에 적힌 그대로여야 한다(예: |"Berkeley"|가 아니라 |"California"|).

두 갈래가 있다. 그냥 |football|로 부르면 단순한 ``탐욕 알고리즘''으로 사슬을 찾고,
|football| \<수>로 부르면 그 \<수>를 계층 너비로 삼아 더 열심히 찾는다. 너비가
클수록 셈은 늘지만 대개 더 나은 사슬을 낸다. 비밀 옵션 \.{-v}는 계층 탐색의 진행을
보이고, \.{-D}\<디렉터리>는 자료 파일이 놓인 곳을 바꾼다(기본값 \.{data}).

@ 프로그램의 뼈대다. \CEE/ 원본은 전역 |g|·|width|·|next_node| 따위에 기대지만,
우리는 그래프 상태를 |chainer| 구조체에 담아 패키지 수준 가변 상태를 피한다.

@c
package main

@<내포하는 패키지들@>

@<자료 구조@>@;
@<탐욕 알고리즘@>@;
@<계층 탐욕 알고리즘@>@;
@<이중 성분 계산@>@;
@<사슬 찍기@>@;
@<터미널 상호작용@>@;

func main() {
	@<명령줄 옵션을 읽는다@>@;
	@<그래프 마련하기@>@;
	c := &chainer{g: g, width: width, verbose: verbose,
		rng: gbflip.New(0), out: os.Stdout}
	c.run()
}

@ @<내포하는 패키지들@>=
import (
	"bufio"
	"fmt"
	"io"
	"log"
	"os"
	"strconv"
	"strings"
	@#
	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgames"
	"github.com/sjnam/go-sgb/gbgraph"
)

@ 명령줄을 훑는다. 수 인자는 계층 너비, \.{-v}는 진행 표시, \.{-D}\<경로>는 자료
디렉터리다. 음수 너비는 절댓값을 쓴다(하이픈을 쓴 사용자를 위해).

@<명령줄 옵션을 읽는다@>=
var dir string
var width int64
verbose := false
for _, arg := range os.Args[1:] {
	switch {
	case arg == "-v":
		verbose = true
	case strings.HasPrefix(arg, "-D"):
		dir = arg[2:]
	default:
		w, err := strconv.ParseInt(arg, 10, 64)
		if err != nil {
			log.Fatalf("사용법: %s [탐색너비][-v][-D디렉터리]", os.Args[0])
		}
		if w < 0 {
			w = -w
		}
		width = w
	}
}

@ 백트래킹 나무의 각 노드는 어느 팀에서 다음 팀으로 가는 한 경기를 담는다.
|game|은 그 경기 호, |totLen|은 |start|에서 여기까지 쌓인 점수 차, |prev|는 지금
팀을 알려 준 노드다. |next|는 같은 계층의 노드를 잇는다(계층 탐욕에서 쓴다). \CEE/ 원본은 \.{-v}용
계층·순번 표를 |next| 포인터에 억지로 채워 넣지만, 우리는 |stratum|·|order|
필드를 따로 둔다.

@<자료 구조@>=
type node struct {
	game    *gbgraph.Arc
	totLen  int64
	prev    *node
	next    *node
	stratum int64 // \.{-v}: 이 노드가 놓인 계층
	order   int64 // \.{-v}: 그 계층 안 순번
}

@ |chainer|는 그래프와 탐색 상태를 한데 묶는다. 이중 성분 계산에 쓰는
|activeStack|·|settledStack|·|nn|·|dummy|와, 계층별 노드 리스트 |list|·|size|,
그리고 \.{-v} 진행 표시용 |mm|을 담는다.

@<자료 구조@>=
type chainer struct {
	g       *gbgraph.Graph
	width   int64
	verbose bool
	rng     *gbflip.RNG
	out     io.Writer

	activeStack  *gbgraph.Vertex // 활성 정점 스택의 꼭대기
	settledStack *gbgraph.Vertex // 찾은 이중 성분들의 스택
	nn           int64           // 지금까지 본 정점의 수
	dummy        *gbgraph.Vertex // |goal|의 가상 부모

	list []*node // 계층별 최선 노드 리스트
	size []int64 // 각 리스트의 노드 수
	mm   int64   // \.{-v}용 계수기
}

@* 그래프 마련. |Games(0,...)|로 1990년 시즌 전체 그래프를 짓는다. |Games|가 준
호에는 |u|가 낸 점수가 |Len|으로 실려 있다. 우리는 그 호에 |del| 필드를 더
얹는데, |del|은 |u|와 |v|의 점수 차다. 게임 그래프에서 |venue|였던 |A.I| 자리를
이제 |del|로 다시 쓴다.

@<그래프 마련하기@>=
g, err := gbgames.Games(0, 0, 0, 0, 0, 0, 0, 0, dir)
if err != nil {
	log.Fatalf("그래프를 만들 수 없습니다: %v", err)
}
for i := int64(0); i < g.N; i++ {
	v := &g.Vertices[i]
	for a := v.Arcs; a != nil; a = a.Next {
		if g.Index(a.Tip) > g.Index(v) { // 짝마다 한 번만
			a.A.I = a.Len - a.Partner.Len // |del|
			a.Partner.A.I = -a.A.I
		}
	}
}

@* 탐욕. 우리의 으뜸 과제는 |del|을 호 길이로 삼아 |start|에서 |goal|로 가는 가장
긴 단순 경로를 찾는 것이다. 이는 \\{NP}-완전 문제라, 이 프로그램은 셈하기 쉬운
어림짐작으로 만족한다. 가장 먼저 떠오르는 것은 매 걸음에서 |goal|에 못 가게 막지
않는 한 가장 큰 |del|을 고르는 ``탐욕'' 방식이다.

정점의 유틸리티 필드를 이렇게 쓴다: |blocked=U.I|(경로에 이미 쓴 정점),
|valid=V.V|(|goal|로 가는 정점의 표), |link=W.V|(표시 스택). \CEE/의 공용체와
달리 Go 필드는 서로 독립이라 게임 그래프의 필드와 겹치지 않는다.

@<탐욕 알고리즘@>=
func (c *chainer) greedy(start, goal *gbgraph.Vertex) *node {
	for i := int64(0); i < c.g.N; i++ {
		v := &c.g.Vertices[i]
		v.U.I = 0   // |blocked|
		v.V.V = nil // |valid|
	}
	var curNode *node
	for v := start; v != goal; v = curNode.game.Tip {
		v.U.I = 1 // |blocked|
		curNode = newNode(curNode, 0)
		c.markReachable(v, goal)
		@<|v|에서 갈 수 있는 최선의 호를 골라 |curNode.game|으로 삼는다@>@;
	}
	return curNode
}

@ |v|의 호 가운데, 상대가 |goal|로 가는 표(|valid==v|)를 지녔고 |del|이 가장 큰
것을 고른다. 다만 |goal|로 바로 가는 호는 마지막 수단(|lastArc|)으로 미룬다 ---
그러지 않으면 사슬이 한 경기로 끝나 버린다.

@<|v|에서 갈 수 있는 최선의 호를 골라 |curNode.game|으로 삼는다@>=
d := int64(-10000)
var bestArc, lastArc *gbgraph.Arc
for a := v.Arcs; a != nil; a = a.Next {
	if a.A.I > d && a.Tip.V.V == v {
		if a.Tip == goal {
			lastArc = a
		} else {
			bestArc = a
			d = a.A.I
		}
	}
}
if d == -10000 {
	curNode.game = lastArc // 마지막 수단
} else {
	curNode.game = bestArc
}
curNode.totLen += curNode.game.A.I // |del|

@ |newNode|는 낡은 노드 |x|를 |prev|로 삼는 새 노드를 만든다. Go의 GC 덕에 노드를
낱개로 할당해도 포인터가 그대로 유효하므로, \CEE/의 블록 할당은 필요 없다.

@<탐욕 알고리즘@>=
func newNode(x *node, d int64) *node {
	var tot int64
	if x != nil {
		tot = x.totLen
	}
	return &node{prev: x, totLen: tot + d}
}

@ 표준적인 표시 알고리즘으로 마지막 빠진 고리를 채운다: |goal|에서 거꾸로,
막히지 않은(|blocked==0|) 정점들을 훑어 |valid=v|로 표시한다. |goal|에서 그
정점까지 |v|를 건드리지 않고 닿을 수 있다는 뜻이다.

@<탐욕 알고리즘@>=
func (c *chainer) markReachable(v, goal *gbgraph.Vertex) {
	u := goal
	u.W.V = nil // |link|
	u.V.V = v   // |valid|
	for u != nil {
		a := u.Arcs
		u = u.W.V // 스택에서 꺼낸다
		@<|a|의 이웃 가운데 새로 닿는 것을 표시해 스택에 얹는다@>@;
	}
}

@ @<|a|의 이웃 가운데 새로 닿는 것을 표시해 스택에 얹는다@>=
for ; a != nil; a = a.Next {
	t := a.Tip
	if t.U.I == 0 && t.V.V != v { // 안 막혔고 아직 표 안 됨
		t.V.V = v
		t.W.V = u
		u = t // 스택에 얹는다
	}
}

@* 계층 탐욕. 더 나은 사슬을 얻는 한 방법은 Pang Chen의 착상[Ph.D. thesis,
Stanford University, 1989]을 본뜬 계층 알고리즘이다. 백트래킹 나무의 노드를 함수
$h$로 몇 개의 계층으로 나누되, $h(\hbox{자식})<h(\hbox{부모})$이고
$h(\hbox{goal})=0$이게 한다. 그리고 각 계층에서 |tot_len|이 큰 위 |width|개
노드만 남긴다. 탐욕 알고리즘은 |width=1|이고 $h(x)=-(\hbox{사슬 길이})$인 특수한
경우다. 여기서는 $h(x)$를 |u(x)|와 |goal| 사이의 단순 경로에 놓일 수 있는 정점의
수로 삼는다.

@ 계층 탐욕의 맨 위 얼개다. 계층마다, 곧 $h$의 값마다 노드 리스트를 둔다.
아직 다 살피지 않은 가장 높은 계층 |m|부터 하나씩 노드를 꺼내 그 자식들을 다시
알맞은 계층에 넣는다.

@<계층 탐욕 알고리즘@>=
func (c *chainer) stratified(start, goal *gbgraph.Vertex) *node {
	c.list = make([]*node, c.g.N)
	c.size = make([]int64, c.g.N)
	var curNode *node // |nil|은 나무의 뿌리
	m := c.g.N - 1    // 아직 다 살피지 않은 가장 높은 계층
	for {
		c.placeChildren(curNode, start, goal)
		for c.list[m] == nil {
			@<|m|을 낮추고 다른 리스트를 살필 채비를 한다@>@;
		}
		curNode = c.list[m]
		c.list[m] = curNode.next // 가장 높은 계층에서 노드 하나를 뺀다
		if c.verbose {
			@<|cur_node|의 진행 정보를 찍는다@>@;
		}
		if m == 0 { // 오직 |list[0]|에 노드 하나가 남는다
			break
		}
	}
	return curNode
}

@ 리스트는 |tot_len| 오름차순으로 두어, 머리(가장 작은 것)를 쉽게 뺀다. |h=0|일
때는 답이 하나뿐이므로 |width|개가 아니라 한 노드만 남긴다.

@<계층 탐욕 알고리즘@>=
func (c *chainer) placeNode(x *node, h int64) {
	@<리스트가 꽉 찼으면 가장 작은 노드를 밀어낸다@>@;
	@<노드 |x|를 |tot_len| 차례에 맞게 끼운다@>@;
}

@ 계층이 꽉 찼으면(|h>0|이며 |width|개이거나, |h==0|이며 이미 하나 있으면), |x|가
머리보다 작으면 버리고, 아니면 머리를 밀어낸다.

@<리스트가 꽉 찼으면 가장 작은 노드를 밀어낸다@>=
if (h > 0 && c.size[h] == c.width) || (h == 0 && c.size[0] > 0) {
	if x.totLen <= c.list[h].totLen {
		return // |x|를 버린다
	}
	c.list[h] = c.list[h].next // 노드 하나를 밀어낸다
} else {
	c.size[h]++
}

@ @<노드 |x|를 |tot_len| 차례에 맞게 끼운다@>=
var q *node
p := c.list[h]
for p != nil {
	if x.totLen <= p.totLen {
		break
	}
	q = p
	p = p.next
}
x.next = p
if q != nil {
	q.next = x
} else {
	c.list[h] = x
}

@ 큰 항목이 먼저 들어가도록 리스트를 뒤집는다.

@<|m|을 낮추고 다른 리스트를 살필 채비를 한다@>=
m--
var r *node
s := c.list[m]
for s != nil {
	t := s.next
	s.next = r
	r = s
	s = t
}
c.list[m] = r
c.mm = 0 // \.{-v} 찍기용 색인

@ \.{-v} 진행 정보다. 노드마다 계층 |m|과 그 안 순번 |mm|을 담은 표를 |next|
자리에 슬쩍 실어, 부모의 표까지 곁들여 찍는다.

@<|cur_node|의 진행 정보를 찍는다@>=
c.mm++
tip := "start"
if curNode.game != nil {
	tip = curNode.game.Tip.Name
}
pm, pmm := int64(0), int64(0)
if curNode.prev != nil {
	pm, pmm = curNode.prev.stratum, curNode.prev.order
}
curNode.stratum, curNode.order = m, c.mm
fmt.Fprintf(c.out, "[%d,%d]=[%d,%d]&%s (%+d)\n",
	m, c.mm, pm, pmm, tip, curNode.totLen)

@* 이중 성분 계산. $h$ 함수를 셈하려면, 이은 그래프 $G$와 두 정점 $u$·$v$에 대해
$u$에서 $v$로 가는 단순 경로에 놓일 수 있는 정점의 수를 세야 한다. 이는 $G$에
$v$에만 이웃한 가상 정점 $o$를 더한 $G^+$의 이중 성분을 $o$에서 깊이 우선 탐색으로
구해 푼다. 이 프로그램은 {\sc BOOK\_COMPONENTS}의 알고리즘을 거의 그대로 옮긴
것이라, 자세한 설명은 그곳에 미룬다. 한 가지 차이는 탐색을 |goal|에서 시작한다는
점이다.

정점의 유틸리티 필드를 이렇게 쓴다: |rank=Z.I|(언제 처음 봤나), |parent=U.V|(누가
알려 줬나), |untagged=X.A|(첫 태그 안 된 호), |min=V.V|(성숙한 자손에서 얼마나
낮이 뛸 수 있나).

@<이중 성분 계산@>=
func (c *chainer) placeChildren(curNode *node, start, goal *gbgraph.Vertex) {
	@<모든 정점을 안 봄으로, 모든 호를 태그 안 됨으로 둔다@>@;
	c.bicomponentDFS(goal)
	@<자식마다 새 노드를 만들어 알맞은 계층에 넣는다@>@;
}

@ 정점의 |rank|를 무한대로 두는 것은 그 정점을 그래프에서 뺀 것과 같다. |cur_node|로
이끄는 걸음에 이미 쓴 정점과 |start|를 그렇게 빼 둔다.

@<모든 정점을 안 봄으로, 모든 호를 태그 안 됨으로 둔다@>=
for i := int64(0); i < c.g.N; i++ {
	v := &c.g.Vertices[i]
	v.Z.I = 0      // |rank|
	v.X.A = v.Arcs // |untagged|
}
for x := curNode; x != nil; x = x.prev {
	x.game.Tip.Z.I = c.g.N // 무한대에 가까운 |rank|
}
start.Z.I = c.g.N
c.nn = 0
c.activeStack = nil
c.settledStack = nil

@ 탐색을 마치면, |cur_node|가 이끈 팀(뿌리면 |start|)의 이웃 가운데 |goal|에 닿는
것마다 자식 노드를 만들어 계층 $h$에 넣는다. |untagged==nil|이면 그 정점에서
|goal|에 닿는다는 뜻이고, $h$는 그 정점의 |parent.rank|다.

@<자식마다 새 노드를 만들어 알맞은 계층에 넣는다@>=
base := start
if curNode != nil {
	base = curNode.game.Tip
}
for a := base.Arcs; a != nil; a = a.Next {
	u := a.Tip
	if u.X.A == nil { // |goal|에 닿는다
		x := newNode(curNode, a.A.I) // |del|
		x.game = a
		c.placeNode(x, u.U.V.Z.I) // $h=$ |parent.rank|
	}
}

@ |settled_stack|은 이중 성분을 발견한 것과 반대 차례로 담긴다. 이것이 나중에
$h$ 값을 셈할 때 필요한 차례다. 탐색은 |goal|에서 시작해 |dummy|로 되짚어
올라올 때까지 한 걸음씩 나아간다.

@<이중 성분 계산@>=
func (c *chainer) bicomponentDFS(goal *gbgraph.Vertex) {
	v := goal
	v.U.V = c.dummy // |parent|
	c.makeActive(v)
	for v != c.dummy {
		v = c.explore(v)
	}
	@<|settled_stack|으로 각 정점의 상호 도달 수를 셈한다@>@;
}

@ @<|settled_stack|으로 각 정점의 상호 도달 수를 셈한다@>=
for c.settledStack != nil {
	v := c.settledStack
	c.settledStack = v.W.V         // |link|
	v.Z.I += v.V.V.U.V.Z.I + 1 - c.g.N // |rank += min.parent.rank + 1 - n|
}

@ 정점 |v|를 활성으로 만든다: 새 |rank|를 주고, 활성 스택에 얹고, |min|을 자기
부모로 둔다.

@<이중 성분 계산@>=
func (c *chainer) makeActive(v *gbgraph.Vertex) {
	c.nn++
	v.Z.I = c.nn          // |rank|
	v.W.V = c.activeStack // |link|
	c.activeStack = v
	v.V.V = v.U.V // |min = parent|
}

@ 현재 정점에서 한 걸음 탐색해 새 현재 정점을 준다. 태그 안 된 호가 있으면 그리로
가고, 없으면 |v|가 성숙해 부모로 되짚어 올라간다.

@<이중 성분 계산@>=
func (c *chainer) explore(v *gbgraph.Vertex) *gbgraph.Vertex {
	a := v.X.A // 첫 태그 안 된 호
	if a != nil {
		@<호 |a|를 태그하고 따라간다@>@;
		return v
	}
	@<|v|가 성숙했으니 부모로 되짚어 올라간다@>@;
	return v
}

@ |u=a.tip|을 이미 봤으면 비트리 호이니 |v.min|만 갱신하고, 못 봤으면 트리 호이니
|u|가 새 현재 정점이 된다.

@<호 |a|를 태그하고 따라간다@>=
u := a.Tip
v.X.A = a.Next // 호를 태그한다
if u.Z.I != 0 {
	if u.Z.I < v.V.V.Z.I {
		v.V.V = u // |min|을 갱신
	}
} else {
	u.U.V = v // |parent|
	v = u
	c.makeActive(v)
}

@ |v.min==v.parent|이면 |v|와 그 자손들이 |u=v.parent|와 함께 이중 성분을 이룬다.
아니면 |u|에서 |v.min|이 보이게 됐으니 |u.min|을 갱신한다.

@<|v|가 성숙했으니 부모로 되짚어 올라간다@>=
u := v.U.V // |parent|
if v.V.V == u {
	c.reportBicomponent(v, u)
} else if v.V.V.Z.I < u.V.V.Z.I {
	u.V.V = v.V.V // |u.min = v.min|
}
v = u

@ 이중 성분을 찾으면 그 정점들의 |parent|를 |v|로 다시 매겨, 나중에 같은
|parent|를 지닌 정점들이 한 이중 성분에 속하게 한다. |v|를 그 대표로 삼아
|settled_stack|에 얹고, |v.rank|를 성분 크기에 큰 상수를 더한 값으로 둔다. |u|가
|dummy|이면 |v|는 |goal|이라 아무 일도 하지 않는다 --- 자명한 뿌리 성분은 언제나
맨 끝에 나온다.

@<이중 성분 계산@>=
func (c *chainer) reportBicomponent(v, u *gbgraph.Vertex) {
	if u == c.dummy {
		return // 자명한 뿌리 성분 (|goal|, |dummy|)
	}
	@<활성 스택에서 |v|와 그 자손들을 떼어 이중 성분으로 정착시킨다@>@;
}

@ @<활성 스택에서 |v|와 그 자손들을 떼어 이중 성분으로 정착시킨다@>=
var cnt int64 // 떼어 낸 정점 수
t := c.activeStack
for t != v {
	cnt++
	t.U.V = v // |parent|
	t = t.W.V // |link|
}
c.activeStack = v.W.V // |v.link|
v.U.V = v             // |parent|
v.Z.I = cnt + c.g.N   // 참된 성분 크기는 |cnt+1|
v.W.V = c.settledStack
c.settledStack = v

@* 사슬 찍기. 다 끝나면 |cur_node.game.tip|이 |goal|이고, |prev| 고리를 따라
|start|까지 되짚을 수 있다. 보기 좋게 |start|에서 |goal| 차례로 찍으려고, 리스트를
스택처럼 뒤집는다. \CEE/처럼 |next| 자리를 임시 스택 꼭대기로 쓴다.

@<사슬 찍기@>=
func (c *chainer) printChain(curNode *node, start, goal *gbgraph.Vertex) {
	var top *node
	for curNode != nil {
		t := curNode
		curNode = t.prev
		t.prev = top // 꺼내서
		top = t      // 다시 얹는다(뒤집힌 차례)
	}
	for v := start; v != goal; {
		a := top.game
		u := a.Tip
		c.printScore(a, v, u)
		fmt.Fprintf(c.out, " (%+d)\n", top.totLen)
		v, top = u, top.prev
	}
}

@ 경기 하나의 점수를 찍는다. |date|(|B.I|)를 달-날로 옮기고, 두 팀의 이름·별명과
점수를 적는다. |u|의 점수는 |a.len - a.del|이다.

@<사슬 찍기@>=
func (c *chainer) printScore(a *gbgraph.Arc, v, u *gbgraph.Vertex) {
	@<경기 날짜를 달과 날로 찍는다@>@;
	fmt.Fprintf(c.out, ": %s %s %d, %s %s %d",
		v.Name, v.Y.S, a.Len, u.Name, u.Y.S, a.Len-a.A.I)
}

@ 0일은 8월 26일이다. 날짜 |d|를 달 이름과 그달의 날로 옮긴다.

@<경기 날짜를 달과 날로 찍는다@>=
d := a.B.I // |date|
var mon string
var day int64
switch {
case d <= 5:
	mon, day = "Aug", d+26
case d <= 35:
	mon, day = "Sep", d-5
case d <= 66:
	mon, day = "Oct", d-35
case d <= 96:
	mon, day = "Nov", d-66
case d <= 127:
	mon, day = "Dec", d-96
default:
	mon, day = "Jan", 1 // |d=128|
}
fmt.Fprintf(c.out, " %s %02d", mon, day)

@* 터미널 상호작용. 프로그램과 사용자가 주고받는 간단한 대화다. |dummy|를 한 번
마련하고, 시작 팀과 목표 팀을 물어 사슬을 찾아 찍기를 되풀이한다.

@<터미널 상호작용@>=
func (c *chainer) run() {
	c.dummy = new(gbgraph.Vertex)
	sc := bufio.NewScanner(os.Stdin)
	for {
		fmt.Fprintln(c.out) // 눈에 띄게 빈 줄 하나
		if !c.oneRound(sc) {
			break
		}
	}
}

@ 한 판이다. 시작 팀을 물어 없으면 끝(거짓)을 알리고, 목표 팀을 물어 없거나 시작과
같으면 다시 묻는다. 둘이 다르면 사슬을 찾아 찍는다.

@<터미널 상호작용@>=
func (c *chainer) oneRound(sc *bufio.Scanner) bool {
	for {
		start := c.promptForTeam(sc, "Starting")
		if start == nil {
			return false
		}
		goal := c.promptForTeam(sc, "   Other")
		if goal == nil {
			return true
		}
		if start == goal {
			fmt.Fprintln(c.out, " (Um, please give me the names of two DISTINCT teams.)")
			continue
		}
		@<너비가 0이면 탐욕 알고리즘을, 아니면 계층 탐욕을 써서 사슬을 찾아 찍는다@>@;
		return true
	}
}

@ 너비 |c.width|가 0이면 탐욕 알고리즘을, 아니면 계층 탐욕을 써서 |start|에서
|goal|로 가는 사슬을 찾는다.

@<너비가 0이면 탐욕 알고리즘을, 아니면 계층 탐욕을 써서 사슬을 찾아 찍는다@>=
var chain *node
if c.width == 0 {
	chain = c.greedy(start, goal)
} else {
	chain = c.stratified(start, goal)
}
c.printChain(chain, start, goal)

@ 사용자는 팀 이름을 |games.dat|의 표기 그대로 쳐야 한다. 빈 줄이면 |nil|을
준다. 이름을 못 찾으면 아는 팀 하나를 무작위로 귀띔한다.

@<터미널 상호작용@>=
func (c *chainer) promptForTeam(sc *bufio.Scanner, prompt string) *gbgraph.Vertex {
	for {
		fmt.Fprintf(c.out, "%s team: ", prompt)
		if !sc.Scan() || sc.Text() == "" {
			return nil
		}
		name := sc.Text()
		for i := int64(0); i < c.g.N; i++ {
			if c.g.Vertices[i].Name == name {
				return &c.g.Vertices[i]
			}
		}
		fmt.Fprintln(c.out, " (Sorry, I don't know any team by that name.)")
		fmt.Fprintf(c.out, " (One team I do know is %s...)\n",
			c.g.Vertices[c.rng.Unif(c.g.N)].Name)
	}
}

@* 찾아보기.
