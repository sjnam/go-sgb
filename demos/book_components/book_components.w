% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 book_components.w를 Go로 이식한다.
@i ../../gbtypes.w

\input kotexgweb
\def\title{BOOK\_\,COMPONENTS}
\def\<#1>{\hbox{$\langle$\rm#1$\rangle$}}
\def\dash{\mathrel-\joinrel\joinrel\mathrel-} % 간선

@* 이중 성분. 이 시연 프로그램은 세계 문학에서 뽑은 GraphBase 그래프의 이중연결
성분(biconnected component, 줄여서 ``bicomponent'')을, Hopcroft와 Tarjan의
@^Hopcroft, John Edward@>
@^Tarjan, Robert Endre@>
알고리즘[R.~E. Tarjan, ``Depth-first search and linear graph algorithms,''
{\sl SIAM Journal on Computing\/ \bf1} (1972), 146--160]의 변형으로 헤아린다.
분리점(articulation point)과 보통의 연결 성분도 덤으로 얻는다.

두 간선이 같거나 둘 다 하나의 단순 순환에 놓이면, 그리고 그때만, 그 둘은 같은
이중연결 성분에 속한다. 이는 간선들 위의 동치 관계를 정한다(정말 그런지는 이
프로그램 끝에서 증명한다). 연결 그래프의 이중 성분들은 자유 트리(free tree)를
이루는데, 두 이중 성분이 공통 정점을 가질 때---곧 두 이중 성분 저마다의 간선
적어도 하나에 함께 드는 정점이 있을 때---이웃이라고 하기로 하면 그렇다. 그런
정점을 {\sl 분리점\/}이라 부른다. 이웃한 두 이중 성분 사이의 분리점은 오직
하나뿐이다. 이중 성분 하나를 자유 트리의 ``뿌리''로 삼으면, 나머지 이중 성분은
정점 목록으로---뿌리 쪽으로 이끄는 분리점을 맨 끝에 두어---깔끔하게 나타낼 수
있다. 이 프로그램은 이중 성분을 바로 그렇게 찍는다.

@ 명령줄 옵션으로 여러 그래프를 살필 수 있다: `\.{-t}\<제목>', `\.{-n}\<수>',
`\.{-x}\<수>', `\.{-f}\<수>', `\.{-l}\<수>', `\.{-i}\<수>',
`\.{-o}\<수>', `\.{-s}\<수>'는 |Book(t,n,x,f,l,i,o,s)|의 매개변수를 바꾼다.
\.{-v}나 \.{-V}는 인물 코드 설명을 먼저 찍는데, \.{-V}는 무게까지 더 자세히 보인다.
특별한 \.{-g}\<파일명>은 다른 모든 옵션을 제치고, |SaveGraph|로 저장해 둔 외부 그래프를
대신 쓴다.
@c
package main

@<내포하는 패키지들@>

@<자료 구조@>
@<이름 짓기와 인물 소개@>
@<Hopcroft-Tarjan 알고리즘@>

func main() {
	@<명령줄 옵션을 읽는다@>
	@<그래프를 마련한다@>
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	s := &solver{g: g, book: fileName == "", out: out}
	fmt.Fprintf(out, "Biconnectivity analysis of %s\n\n", g.ID)
	if verbose > 0 {
		@<선택된 인물들의 명단을 찍는다@>
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

@ \.{-g}가 있으면 그 파일을 복원하고, 없으면 |Book|으로 그래프를 짓는다.

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

@ 명령줄 옵션 훑기다. \.{-tN} 꼴이라 접두어를 떼어 파싱한다. \.{-g}가 있으면
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
@<인자들을 훑어 옵션을 정한다@>
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

@ \.{-v}/\.{-V}일 때, 고른 인물들의 명단을 먼저 찍는다. \.{-V}는 설명과 가중
등장 횟수까지 보인다.

@<선택된 인물들의 명단을 찍는다@>=
for v := range s.g.AllVertices() {
	if verbose == 1 {
		fmt.Fprintf(s.out, "%s=%s\n", s.name(v), v.Name)
	} else {
		fmt.Fprintf(s.out, "%s=%s, %s [weight %d]\n", s.name(v), v.Name,
			v.Z.S, inWeight*v.Y.I+outWeight*v.X.I)
	}
}
fmt.Fprintln(s.out)

@*알고리즘. Hopcroft-Tarjan 알고리즘은 본디 재귀적이다. 그러나 깊이 겹친 재귀
앞에서 굼떠지는 시스템도 있으므로, 우리는 \GO/의 실행 시간 스택에 기대는 대신
연결 리스트로 재귀를 겉으로 드러내 편다.

각 정점은 알고리즘이 도는 동안 세 단계를 거친다. 처음엔 ``안 본''(unseen)
상태고, 다음엔 ``활성''(active)이 되며, 끝으로 어느 이중 성분에 배정되면
``정착''(settled)한다.

알고리즘의 현재 상태를 나타내는 자료 구조는 정점마다 유틸리티 필드 다섯 개를
써서 만든다: |rank|, |parent|, |untagged|, |link|, |min|. 하나씩 차례로 보자.
\CEE/의 공용체와 달리 \GO/의 필드는 서로 독립이라, |Book| 그래프가 이미 쓰고
있는 필드(|Z.S|, |Y.I| 따위)와 겹치지 않고 나란히 놓인다---그래서 인물 명단을
먼저 찍은 뒤 알고리즘을 돌려도 안전하다.

@ 첫째는 정수 |rank| 필드로, 안 본 정점에서는 $0$이다. 정점을 처음 살펴보는
순간 그 정점은 활성이 되고 |rank|는 $0$이 아닌 값이 되어 그대로 남는다. 정확히
말하면, $k$번째로 활성이 되는 정점이 rank~$k$를 받는다.

Hopcroft-Tarjan 알고리즘은 동굴의 방을 모두 탐험하려는 간단한 모험 게임이라
생각하면 편하다. 방과 방 사이의 통로는 양쪽으로 오갈 수 있다. 어떤 방에 처음
들어가면 그 방에 새 번호를 매기는데, 그것이 rank다. 나중에 같은 방에 다시 들어
오게 되면 rank가 $0$이 아닌 것을 보고 ``여긴 벌써 와 봤군'' 하면서 얼른 빠져나
올 수 있다. (물리쳐야 할 용 따위, 컴퓨터 게임에 딸린 복잡한 것들은 나오지
않는다.)

|rank|는 유틸리티 필드 |Z.I|에 둔다.

@ 활성 정점들은 늘 방향 있는 트리를 이루며, 그 호는 원래 그래프의 호 가운데
일부다. |u|에서 |v|로 가는 트리 호는 |v.parent=u|로 나타낸다. 활성 정점은
모두 부모를 가지는데, 그 부모도 보통 활성 정점이다. 딱 하나 예외가 트리의
뿌리로, 그 |parent|는 |dummy|라 부르는 가짜 정점이다. 가짜 정점의 rank는 $0$
이다.

동굴에 빗대면, 방 |v|의 ``부모''란 |v|에 처음 들어가기 바로 전에 있던 방이다.
부모 포인터를 따라가면 언제든 동굴 밖으로 나올 수 있다.

|parent|는 유틸리티 필드 |Y.V|에 둔다.

@ 원래의 무향 그래프의 모든 간선은 깊이 우선 탐색 동안 빠짐없이 살펴진다.
간선을 살펴볼 때마다 우리는 그 간선에 태그를 붙여, 두 번 살피지 않게 한다.
동굴이라면 방과 방 사이의 통로를 한번 지나가 보고 나서 표시해 두는 셈이다.

GraphBase 그래프에서 무향 간선은 방향 있는 호 한 쌍으로 나타난다. 그 두 호가
저마다 살펴지고 끝내는 태그된다.

알고리즘이 |Arc| 레코드에 정말로 태그를 붙이지는 않는다. 그 대신 정점 |v|마다
포인터 |v.untagged|를 두어, |v|에서 나가는 아직 탐험하지 않은 호들을 가리키게
한다. 리스트에서 |v.arcs|와 |v.untagged| 사이에 놓인 호들이 이미 살펴본
것들이다.

|untagged|는 유틸리티 필드 |X.A|에 두며, |Arc|를 가리키거나 |nil|이다.

@ 알고리즘은 활성 스택(|activeStack|)이라는 특별한 스택을 지니는데, 여기에는
지금 활성인 정점이 모두 들어 있다. 정점마다 |link| 필드가 있어 스택에서 바로
아래에 있는 정점을 가리키고, 맨 밑이면 |nil|이다. 활성 스택의 정점들은 밑에서
위로 갈수록 rank가 커지는 차례로 늘 놓인다.

|link|는 유틸리티 필드 |W.V|에 둔다.

@ 마지막이 |min| 필드인데, 이것이 모든 것을 돌아가게 하는 까다로운 대목이다.
정점 |v|가 안 본 상태거나 정착했으면 그 |min| 필드는 아무 뜻이 없다. 그렇지
않으면 |v.min|은 다음 성질을 가진 활성 정점 |u| 가운데 rank가 가장 작은 것을
가리킨다: |v|에서 |u|로 가는, 성숙한 트리 호 $0$개 이상에 이어 비트리 호
하나로 끝나는 방향 있는 경로가 있다.

트리 호가 무엇이냐고? 성숙한 호는 또 무엇이냐고? 좋은 질문이다. 그래프의 호에
태그를 붙이는 그 순간, 우리는 그것을 트리 호(활성 노드의 트리에서 새 |parent|
링크에 해당하면)이거나 비트리 호(그밖에)로 가른다. 그러니까 트리 호란 우리를
새 땅으로 이끈 통로에 해당한다. 트리 호는 지금 탐험 중인 정점에서 뿌리까지의
경로 위에 더는 놓이지 않게 될 때 {\sl 성숙\/}한다. 정점도 마찬가지로 그 경로
위에 더는 놓이지 않게 될 때 성숙한다고 말한다. 성숙한 정점에서 나가는 호는
모두 태그되어 있다.

@ 앞서 정점은 저마다 처음엔 안 본 상태, 다음엔 활성, 끝으로 정착이라고 했다.
새 정의를 얹으면 호도 마찬가지임을 알 수 있다. 호는 태그 안 된 상태로 시작해서
비트리 호가 되거나 트리 호가 된다. 뒤엣것이면 처음엔 덜 성숙한 트리 호였다가
끝내는 성숙한다.

가짜 정점은 활성인 것으로 치고, 뿌리 정점에서 |dummy|로 돌아가는 비트리 호가
있다고 여긴다. 그러면 모든 |v|에 대해 |v|에서 |v.parent|로 가는 비트리 호가
있는 셈이고, 따라서 |v.min|이 가리키는 정점의 rank는 늘 |v.parent|의 rank
이하다. 나중에 밝혀지듯 |v.min|은 언제나 |v|의 조상이다.

지금은 이 정의들을 그냥 믿어 두자. 곧 다 환해질 것이다. |min|은 유틸리티 필드
|V.V|에 둔다.

@ 깊이 우선 탐색은 정점을 하나하나 찾아가 그것이 어디로 이어지는지 보면서
그래프를 훑는다. 말했듯 Hopcroft-Tarjan 알고리즘에서 활성 정점들은 방향 있는
트리를 이루며, 그 가운데 하나를 현재 정점이라 부른다.

현재 정점에 아직 태그 안 된 호가 남아 있으면 그런 호 하나에 태그를 붙이는데,
여기서 두 경우가 갈린다. 그 호가 안 본 정점으로 이끄느냐 아니냐다. 그렇다면
그 호는 트리 호가 되고, 여태 안 본 정점이던 그것이 활성이 되면서 새 현재
정점이 된다. 그렇지 않고 이미 본 정점으로 이끈다면 그 호는 비트리 호가 되고
현재 정점은 그대로다.

@ 마침내 현재 정점 |v|에 태그 안 된 호가 하나도 남지 않는 때가 온다. 이때
알고리즘은 |v|와 그 자손 모두가 |v.parent|와 함께 이중 성분을 이룬다고 판단할
수 있다. 정말로 그 조건은 |v.min==v.parent|일 때, 그리고 그때만 참이다(증명은
아래에 있다). 그렇다면 |v|와 그 자손 모두가 정착해 트리를 떠난다. 그렇지 않으면
|v|의 부모 |u|에서 |v|로 가는 트리 호가 이제 성숙한 것이므로, |v.min|의 값으로
|u.min|의 값을 고친다. 어느 쪽이든 |v|는 성숙하고 |v|의 부모가 새 현재 정점이
된다. |u|에서 |v|로 가는 호가 성숙할 때 고쳐야 하는 것은 |u.min| 하나뿐임을
눈여겨보라. 다른 어떤 |w.min|도 그대로인데, 갓 성숙한 호에는 성숙한 선행자가
없기 때문이다.

동굴 비유가 상황을 밝혀 준다. 방 |u|에서 방 |v|로 들어왔다고 하자. |v|에서
시작하는 곁동굴을 빠져나오려면 |u|를 거쳐 되돌아올 수밖에 없고, 게다가 |v|의
모든 자손에서 |v|를 지나지 않고 |u|에 이를 수 있다면, 방 |v|와 그 자손들은
|u|와 함께 이중 성분을 이룬다. 그런 이중 성분을 하나 알아내면 우리는 그것을
닫아 걸고 그 곁동굴은 더 탐험하지 않는다.

@ |v|가 트리의 뿌리이면 늘 |v.min==dummy|이므로, 성숙하는 순간 언제나 새 이중
성분을 정한다. 그러면 |v|에게 진짜 부모가 없으니 깊이 우선 탐색이 끝난다.
그러나 Hopcroft-Tarjan 알고리즘은 굴하지 않고 아직 안 본 정점 |u|를 찾아
나선다. 그런 정점이 있으면 |u|를 뿌리로 삼아 새 깊이 우선 탐색이 시작된다.
이 과정은 마침내 모든 정점이 행복하게 정착할 때까지 이어진다.

이 알고리즘의 아름다움은, 다음처럼 짜기만 하면 이 모든 것이 아주 효율적으로
돌아간다는 데 있다.

@<Hopcroft-Tarjan 알고리즘@>=
func (s *solver) hopcroftTarjan() {
	s.dummy = new(gbgraph.Vertex) // rank 0
	@<모든 정점을 안 본 상태로, 모든 호를 태그 안 됨으로 둔다@>
	for vv := range s.g.AllVertices() {
		if vv.Z.I == 0 { // 아직 안 봤다
			s.dfs(vv)
		}
	}
}

@ @<모든 정점을 안 본 상태로, 모든 호를 태그 안 됨으로 둔다@>=
for v := range s.g.AllVertices() {
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

@ 이제 재미있어진다. 하지만 우리가 하는 일은 잘 훈련된 동굴 탐험가라면 침착하게
동굴을 살피며 할 법한 바로 그것일 뿐이다. 현재 정점이 제자리에 머무느냐, 새
자식으로 내려가느냐, 부모로 되짚어 올라가느냐에 따라 크게 세 경우가 있다. 새
현재 정점을 돌려준다.

@<Hopcroft-Tarjan 알고리즘@>=
func (s *solver) explore(v *gbgraph.Vertex) *gbgraph.Vertex {
	a := v.X.A // v의 첫 태그 안 된 호
	if a != nil {
		@<호 |a|를 태그하고 따라간다@>
		return v
	}
	@<|v|가 성숙했으니 부모로 되짚어 올라간다@>
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

@ 활성 스택의 원소들은 늘 rank 순으로 놓이고, 트리에서 정점 |v|의 자식들은
모두 |v|보다 rank가 크다. Hopcroft-Tarjan 알고리즘은 그 역에 해당하는 성질에
기댄다: {\sl 현재 정점 |v|보다 rank가 큰 활성 노드는 모두 |v|의 자손이다.\/}
알고리즘이 전위 순서(preorder), 곧 ``왕위 계승 순서''로 rank를 매기며 트리를
지었기 때문에 이 성질이 성립한다. 맏이와 그 자손이 먼저 오고, 그다음이 둘째,
이런 식이다. 따라서 현재 정점의 자손들은 언제나 스택 꼭대기에 잇달아 나타난다.

@ |v|가 성숙한 활성 정점이고 |v.min==v.parent|이며 |u=v.parent|라 하자. |v|와
그 자손들이 |u|와 함께, 그리고 이 정점들 사이의 모든 간선과 함께 이중연결
그래프를 이룬다는 것을 증명하고자 한다. 이 부분그래프를 $H$라 부르자. 부모
링크는 |u|를 뿌리로 하는 $H$의 부분트리를 정하며, |u|를 부모로 가지는 정점은
|v|뿐이다(다른 정점은 모두 |v|의 자손이므로). |x|를 $H$의 정점 가운데 |u|와도
|v|와도 다른 것이라 하자. 그러면 |x|에서 |x.min|으로 가면서 |x.parent|를 건드리지
않는 경로가 있고, |x.min|은 |x.parent|의 진짜 조상이다. 이 성질이면 $H$가
이중연결임을 세우기에 넉넉하다(증명은 이 프로그램 끝에 있다).

게다가 이중연결성을 잃지 않고서는 $H$에 정점을 더 보탤 수 없다. |w|가 또 다른
정점이라면, |w|는 앞선 이중연결 성분의 비분리점으로 이미 출력되었거나, 아니면
|w|에서 |v|로 가면서 정점 |u|를 피하는 경로가 없음을 증명할 수 있다.

@ 그러므로 |v|와 그 활성 자손들을 지금 정착시키는 것이 옳다. 그들을 활성 정점의
트리에서 떼어 내더라도, |u|의 rank보다 작은 rank를 가진 정점으로 가는 경로가
있는 정점이 함께 떨어져 나가지는 않는다. 따라서 그들을 떼어 내는 일은 아직
활성으로 남은 어떤 정점 |w|의 |w.min| 값의 정당성도 해치지 않는다.

|v|의 부모인 정점 |u|가 지금 이중 성분에 드느냐 마느냐에는 자잘한 기술적 문제가
하나 있다. |u|가 가짜 정점이면, |v|가 외딴 정점이었던 경우가 아닌 한, 우리는
원래 그래프의 어느 연결 성분의 마지막 이중 성분을 이미 찍은 것이다. 그렇지
않으면 |u|는 뒤이을 이중 성분들에도 나타날 분리점이다---다만 새 이중 성분이 그
연결 성분의 마지막 이중 성분인 경우는 빼고. (알고리즘에서 아마 가장 미묘한
대목이 이것이다. 보기를 한둘 짚어 보면 다 환해질 것이다.)

읽는 이가 이중연결성을 손쉽게 확인할 수 있을 만큼은 정보를 찍어 준다.

@<Hopcroft-Tarjan 알고리즘@>=
func (s *solver) reportBicomponent(v, u *gbgraph.Vertex) {
	if u == s.dummy {
		@<외딴 정점이거나 연결 성분의 끝을 알린다@>
		return
	}
	@<이중 성분과 그 정점들을 찍는다@>
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
	@<이중 성분의 나머지 정점들을 찍는다@>
}
s.articPt = u

@ @<이중 성분의 나머지 정점들을 찍는다@>=
fmt.Fprintln(s.out, " also includes:")
for t != v {
	fmt.Fprintf(s.out, " %s (from %s; ..to %s)\n",
		s.name(t), s.name(t.Y.V), s.name(t.V.V))
	t = t.W.V // t.link
}

@* 증명. 프로그램은 다 됐다. 그러나 그것이 정말 돌아가는지는 아직 증명해야 한다.
먼저 들어가며에서 말한 간선 사이의 순환 관계가 참으로 동치 관계임을 확인해,
그 어림한 정의를 또렷이 해 두자.

$u\dash v$와 $w\dash x$가 단순 순환 $C$의 간선이고, $w\dash x$와 $y\dash z$가
단순 순환 $D$의 간선이라 하자. 우리는 $u\dash v$와 $y\dash z$를 함께 담은 단순
순환이 있음을 보이려 한다. $C$의 정점 $a$와 $b$를 잡아
$a\dash^\ast y\dash z\dash^\ast b$가 $D$의 부분경로이면서 $a$와 $b$ 말고는 $C$의
정점을 담지 않게 할 수 있다. 이 부분경로를, $C$ 안에서 $b$부터 $a$까지 간선
$u\dash v$를 거쳐 가는 부분경로에 이어 붙이면 된다.

따라서 간선 사이의 그 관계는 추이적이며, 동치 관계다. 그래프가 {\sl 이중연결\/}
이라 함은 정점이 하나뿐이거나, 아니면 모든 정점이 적어도 하나의 다른 정점과
이웃하면서 어느 두 간선이나 서로 동치일 때를 말한다.

@ 다음으로 널리 알려진 사실 하나를 증명한다. 그래프가 이중연결일 필요충분조건은
그것이 연결이면서, 서로 다른 정점 $x$, $y$, $z$를 아무렇게나 잡아도 $z$를
건드리지 않고 $x$에서 $y$로 가는 경로를 담는 것이다. 뒤엣것을 성질~P라 부르자.

$G$가 이중연결이고 $x$, $y$가 $G$의 서로 다른 정점이라 하자. 그러면 간선
$u\dash x$와 $v\dash y$가 있는데, 이 둘은 같거나($x$와 $y$가 이웃인 경우) 어느
단순 순환의 일부다(이때는 $x$에서 $y$로 가는, 다른 정점을 함께 쓰지 않는 경로가
둘 있다). 그러므로 $G$는 성질~P를 가진다.

거꾸로 $G$가 성질~P를 가지고, $u\dash v$와 $w\dash x$가 $G$의 서로 다른
간선이라 하자. 이 두 간선이 어떤 단순 순환에 함께 든다는 것을 보이려 한다.
증명은 $k=\min\bigl(d(u,w),d(u,x),\allowbreak d(v,w),d(v,x)\bigr)$에 대한
귀납법으로 한다. 여기서 $d$는 거리다. $k=0$이면 성질~P가 결과를 곧바로 준다.
$k>0$이면 대칭성에 따라 $k=d(u,w)$라 해도 된다. 그러면 $u\dash y$이면서
$d(y,w)=k-1$인 정점 $y$가 있다. 성질~P로 $u\dash v$는 $u\dash y$와 동치이고,
귀납 가정으로 $u\dash y$는 $w\dash x$와 동치이므로, 추이성에 따라 $u\dash v$는
$w\dash x$와 동치다.

@ 끝으로, $G$가 다음 성질들을 가지면 성질~P를 채운다는 것을 증명한다.
(1)~두드러진 정점 $u$와 $v$가 있다. (2)~$G$의 간선 가운데 일부가 $u$를 뿌리로
하는 부분트리를 이루며, 이 트리에서 부모가 $u$인 정점은 $v$뿐이다. (3)~$u$나
$v$가 아닌 모든 정점 $x$에는 제 부모를 지나지 않고 조부모로 가는 경로가 있다.

성질~P가 성립하지 않는다면, 서로 다른 정점 $x$, $y$, $z$가 있어 $x$에서 $y$로
가는 모든 경로가 $z$를 지난다. 특히 $z$는 부분트리 안에서 $x$와 $y$를 잇는
유일한 경로 $\pi$ 위에서 둘 사이에 놓여야 한다. 그러니 $z\ne u$는 그 경로 위
어떤 노드 $z'$의 부모이고, 따라서 $z'\ne u$이고 $z'\ne v$다. 그런데 $z'$에서
$z'$의 조부모로 가면 $z$를 피할 수 있다. 그 조부모 또한 경로 $\pi$의 일부다---
다만 $z$가 $\pi$ 위의 또 다른 노드 $z''$의 부모이기도 한 경우는 빼고. 뒤엣
경우라도 $z'$에서 $z'$의 조부모로 가고 거기서 $z''$로 가면 $z$를 피할 수 있는데,
$z'$과 $z''$은 조부모가 같기 때문이다.

@* 찾아보기.
