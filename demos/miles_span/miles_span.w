% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 miles_span.w를 Go로 이식한다.
@i ../../gbtypes.w

\input kotexgweb
\def\title{MILES\_\,SPAN}
\def\<#1>{$\langle${\rm#1}$\rangle$}

@* 최소 신장 트리. 그래프의 최소 길이 신장 트리를 찾는 알고리즘의 역사를 다룬
R.~L. Graham과 Pavol Hell의 고전적 논문[{\sl Annals of the History of
@^Graham, Ronald Lewis@>
@^Hell, Pavol@>
Computing\/ \bf 7\/} (1985), 43--57]은 세 갈래 접근을 소개한다. 알고리즘 1
``두 가장 가까운 조각''은 여태 이어지지 않은 두 조각을 잇는 가장 짧은 간선을
거듭 더한다. 이 알고리즘은 J.~B. Kruskal이 1956년에 처음 발표했다.
@^Kruskal, Joseph Bernard@>
알고리즘 2 ``가장 가까운 이웃''은 어느 한 조각을 그 조각에 없는 정점에 잇는
가장 짧은 간선을 거듭 더한다. 이것은 V. Jarn\'\i k이 1930년에 처음 발표했다.
@^Jarn{\'\i}k, Vojt\u ech@>
알고리즘 3 ``모든 가장 가까운 조각''은 있는 조각마다 그것을 다른 조각에 잇는
가장 짧은 간선을 한꺼번에 더한다. 개념으로 보면 가장 세련되어 보이는 이 방법이
알고 보면 가장 오래되어, Otakar Bor\accent23uvka가 1926년에 처음 발표했다.
@^Bor{\accent23u}vka, Otakar@>

이 프로그램은 세 접근을 모두 소박하게 구현해, ``현실적인'' 자료에서 그들이
어떻게 움직이는지 실제로 견주어 보려 한다. 이 프로그램의 큰 목표 하나는,
메모리 참조 곧 ``mem''을 세어 \CEE/로(여기서는 \GO/로) 쓴 프로그램을 기계와
무관하게 견주는 간단한 길을 보이는 것이다. 다시 말해, {\sl 이 프로그램은
실행하라고 쓴 것이 아니라 읽으라고 쓴 것이다.\/}

@ 저자는 mem 세기가 실용적인 문제에서 서로 겨루는 알고리즘의 상대적 효율을
가리는 데 적잖은 빛을 던져 준다고 믿는다. 그는 다른 연구자들도, 여기서 다루는
크기의 문제에서 여기 실린 알고리즘들보다 눈에 띄게 적은 mem으로 최소 신장
트리를 찾아내는 알고리즘을 궁리하는 이 도전을 즐겨 주기를 바란다.

사실 mem 세기는 온갖 조합 알고리즘에 두루 뜻이 있을 법하다. Stanford
GraphBase의 표준 그래프들 덕분에, 여태 점근적으로만 연구되어 온 알고리즘들의
실제 효율에 관해 기계와 무관한 실험을 아주 많이 해 볼 수 있게 되었다.

@ 우리가 다룰 그래프는 {\sc GB\_MILES} 모듈의 |Miles| 서브루틴이 짓는다. 거기
설명된 대로 서브루틴 호출
$$|Miles(n,northWeight,westWeight,popWeight,0,maxDegree,seed)|$$
는 북아메리카 도시들 사이의 운전 거리를 바탕으로 정점 $n\le128$개짜리 그래프를
만든다. 기본으로 $n=100$, |northWeight| $=$ |westWeight| $=$ |popWeight| $=0$,
|maxDegree| $=10$을 쓴다. 씨앗이 다르면 대개 $\,128\,\choose100$ 가지
부분그래프 가운데 다른 하나가 뽑히므로, 이것만으로도 서로 다른 성긴 그래프를
수십억 가지 얻는다.

명령줄 옵션 \.{-n}\<수>, \.{-N}\<수>, \.{-W}\<수>, \.{-P}\<수>, \.{-d}\<수>,
\.{-s}\<수>로 각각 |n|, |northWeight|, |westWeight|, |popWeight|, |maxDegree|,
|seed|의 기본값을 바꾼다. 이를테면 |n|을 올리거나 내릴 수도 있고 그래프를 더
성기게 또는 더 빽빽하게 할 수도 있다. |northWeight|·|westWeight|·|popWeight|에
$0$ 아닌 값을 주면 도시를 인구나 위치로 매겨 뽑기를 기울일 수도 있다.

@ \.{-r}\<수> 옵션을 주면---이를테면 `\.{miles\_span} \.{-r10}'이라 하면---씨앗
값이 잇따르는 그래프 열 개의 신장 트리를 차례로 살핀다. 이 옵션은
|northWeight| $=$ |westWeight| $=$ |popWeight| $=0$일 때만 뜻이 있다.
|Miles|는 무게가 큰 |n|개 도시를 뽑는데, 무게가 $0$이 아니면 도시들의 무게가
꼭 같은 일이 드물어 난수로 동점을 가릴 일이 거의 없기 때문이다.

특별한 옵션 \.{-g}\<파일명>은 다른 모든 옵션을 제친다. |SaveGraph|로 예전에
갈무리해 둔 외부 그래프를 |Miles|가 짓는 그래프 대신 쓴다. 그러면 이 프로그램이
만들지 않은 그래프---다른 생성기가 빚었거나 손으로 다듬은 그래프---의 최소 신장
트리도 잴 수 있다. \.{-v}는 고른 간선을 낱낱이 찍는다.

@ 우리는 문헌에서 두드러지게 다뤄진 네 가지 기본 알고리즘을 시험한다. Graham과
Hell의 알고리즘 1은 |krusk| 프로시저가 맡는데, 간선을 기수 정렬로 길이순으로
늘어놓은 뒤 Kruskal의 방법을 쓴다. 알고리즘 2는 |jarPr| 프로시저가 맡는데, 이는
우선순위 큐 구조를 품고 있어 그것을 두 가지로---단순한 이진 힙으로도, 피보나치
힙으로도---구현한다. 알고리즘 3은 |cherTarKar| 프로시저가 맡는데, 이는
Bor\accent23uvka의 방법과 비슷한 것을 Cheriton과 Tarjan이 따로 찾아냈고 뒤에
Karp와 Tarjan이 간추리고 다듬은 것이다.
@^Cheriton, David Ross@>
@^Tarjan, Robert Endre@>
@^Karp, Richard Manning@>

@ 프로그램의 뼈대다. 옵션을 읽어 |solver|를 꾸리고, |seed|를 늘려 가며 각
그래프의 최소 신장 트리를 여러 알고리즘으로 셈해, 저마다 든 mem 수를 알린다.

@c
package main

import (
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	@#
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbmiles"
	"github.com/sjnam/go-sgb/gbsave"
)

const infinity = int64(1) << 50 // 신장 트리가 없을 때 돌려주는 값

@<보고 함수@>
@<Kruskal 알고리즘@>
@<Jarn\'\i k/Prim 알고리즘@>
@<이진 힙@>
@<피보나치 힙@>
@<이항 큐@>
@<Cheriton/Tarjan/Karp 알고리즘@>

func main() {
	@<명령줄 옵션을 읽는다@>
	s := &solver{verbose: verbose, out: os.Stdout}
	for ; r > 0; r-- {
		@<이 반복에 쓸 그래프를 |g|에 만든다@>
		if err != nil || g.N <= 1 {
			fmt.Fprintf(os.Stderr, "Sorry, can't create the graph! (%v)\n", err)
			os.Exit(1)
		}
		s.g = g
		@<이 그래프의 최소 신장 트리 mem 수를 알린다@>
		seed++
	}
}

@ 여느 때는 |Miles|가 그래프를 새로 만든다. 하지만 \.{-g}$\langle\,$파일명%
$\,\rangle$ 옵션이 있으면, 그 값이 다른 모든 옵션을 제친다: |gbsave.RestoreGraph|가
예전에 |SaveGraph|로 저장해 둔 외부 그래프를 대신 읽어 온다. 그러면 우리는 이
프로그램이 만들지 않은 그래프—이를테면 |Miles| 아닌 다른 생성기가 빚은 그래프나,
손으로 다듬은 그래프—의 최소 신장 트리도 잴 수 있다.

@<이 반복에 쓸 그래프를 |g|에 만든다@>=
var g *gbgraph.Graph
var err error
if fileName != "" {
	g, err = gbsave.RestoreGraph(fileName)
} else {
	g, err = gbmiles.Miles(n, nWeight, wWeight, pWeight, 0, d, seed, dir)
}

@ |solver|는 그래프와 mem 계수기, 그리고 진단 출력 설정을 한데 묶는다. \CEE/
원본은 전역 |mems|·|verbose|·|g|에 기댔지만, 우리는 이들을 구조체에 담는다.

@<Kruskal 알고리즘@>=
type solver struct {
	g       *gbgraph.Graph
	mems    int64 // 센 메모리 참조의 수
	verbose bool
	out     io.Writer
}

@ 명령줄 옵션 훑기다. \.{-nN} 꼴이라 |flag| 대신 접두어를 떼어 파싱한다.

@<명령줄 옵션을 읽는다@>=
var (
	n       int64 = 100
	nWeight int64
	wWeight int64
	pWeight int64
	d       int64 = 10
	seed    int64
	r        int64 = 1
	verbose  bool
	dir            = "data"
	fileName string // \.{-g}로 복원할 외부 그래프
)
usage := func() {
	fmt.Fprintf(os.Stderr,
		"Usage: %s [-nN][-dN][-rN][-sN][-NN][-WN][-PN][-v][-DDIR][-gFILE]\n", os.Args[0])
	os.Exit(2)
}
num := func(s string) int64 {
	v, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		usage()
	}
	return v
}

@ 각 인자의 접두어를 떼어 해당 매개변수에 넣는다. \.{-g}$\langle$파일$\rangle$은
뒤에서 다른 옵션을 제치고 외부 그래프를 복원하는 데 쓰인다.

@<명령줄 옵션을 읽는다@>=
for _, arg := range os.Args[1:] {
	switch {
	case arg == "-v":
		verbose = true
	case strings.HasPrefix(arg, "-n"):
		n = num(arg[2:])
	case strings.HasPrefix(arg, "-N"):
		nWeight = num(arg[2:])
	case strings.HasPrefix(arg, "-W"):
		wWeight = num(arg[2:])
	case strings.HasPrefix(arg, "-P"):
		pWeight = num(arg[2:])
	case strings.HasPrefix(arg, "-d"):
		d = num(arg[2:])
	case strings.HasPrefix(arg, "-r"):
		r = num(arg[2:])
	case strings.HasPrefix(arg, "-s"):
		seed = num(arg[2:])
	case strings.HasPrefix(arg, "-D"):
		dir = arg[2:]
	case strings.HasPrefix(arg, "-g"):
		fileName = arg[2:]
	default:
		usage()
	}
}

@ 각 알고리즘의 결과 길이는 모두 같아야 하고(그렇지 않으면 버그다), 저마다 든
mem 수를 알린다.

@<이 그래프의 최소 신장 트리 mem 수를 알린다@>=
fmt.Fprintf(s.out, "The graph %s has %d edges,\n", g.ID, g.M/2)
spLength := s.krusk()
if spLength == infinity {
	fmt.Fprintln(s.out, "  and it isn't connected.")
} else {
	fmt.Fprintf(s.out, "  and its minimum spanning tree has length %d.\n", spLength)
}
fmt.Fprintf(s.out, " The Kruskal/radix-sort algorithm takes %d mems;\n", s.mems)
@<이진 힙으로 |jarPr(g)|를 실행한다@>
fmt.Fprintf(s.out, " the Jarnik/Prim/binary-heap algorithm takes %d mems;\n", s.mems)
@<피보나치 힙으로 |jarPr(g)|를 실행한다@>
fmt.Fprintf(s.out, " the Jarnik/Prim/Fibonacci-heap algorithm takes %d mems;\n", s.mems)
if spLength != s.cherTarKar() {
	fmt.Fprintln(s.out, " ...oops, I've got a bug, please fix fix fix")
	os.Exit(3)
}
fmt.Fprintf(s.out, " the Cheriton/Tarjan/Karp algorithm takes %d mems.\n\n", s.mems)

@ |verbose|일 때, 여러 알고리즘이 찾은 간선을 |report|가 알린다.

@<보고 함수@>=
func (s *solver) report(u, v *gbgraph.Vertex, l int64) {
	fmt.Fprintf(s.out, "  %d miles between %s and %s [%d mems]\n", l, u.Name, v.Name, s.mems)
}

@* 전략과 규칙. {\sl 조각\/}(fragment)이란 최소 신장 트리의 부분 트리다. 우리가
구현하는 세 알고리즘 모두 R.~C. Prim이 1957년에 온전히 밝힌 기본 원리에 기댄다:
@^Prim, Robert Clay@>
``조각 $F$가 모든 정점을 담지 않고, $e$가 $F$를 $F$ 밖 정점에 잇는 가장 짧은
간선이면, $F\cup e$도 조각이다.''

증명은 이렇다. $T$를 $F$는 담되 $e$는 담지 않는 최소 신장 트리라 하자. $T$에
$e$를 더하면 회로가 하나 생기는데, 그 회로에는 $e$가 아닌 간선 $e'$이 있어
$F$ 안의 정점에서 $F$ 밖의 정점으로 간다. $T\cup e$에서 $e'$을 빼면 총길이가
$T$보다 크지 않은 신장 트리 $T'$이 나온다. 그러므로 $T'$은 $F\cup e$를 담는
최소 신장 트리다. 증명 끝.

@ |Miles|가 짓는 그래프에는 특별한 성질이 있고, 그것을 이용할 수 있다면 이용해도
반칙이 아니다.

첫째, 각 간선의 길이는 $2^{12}$보다 작은 양의 정수다.

둘째, 그래프의 $k$번째 정점 $v_k$는 |g.Vertices[k]|다. 무게를 매겼다면 정점들이
무게순으로 놓인다. 이를테면 |northWeight| $=1$이고
|westWeight| $=$ |popWeight| $=0$이면 $v_0$은 가장 북쪽 도시, $v_{n-1}$은 가장
남쪽 도시다.

셋째, 정점 |v|에서 닿을 수 있는 간선들은 |v.Arcs|에서 시작하는 연결 리스트에
놓인다. 이 리스트에서 |v|에서 $v_j$로 가는 간선이 |v|에서 $v_k$로 가는 간선보다
앞서는 것은 $j>k$일 때, 그리고 그때뿐이다.

@ 넷째, 정점에는 좌표 |v.X.I|와 |v.Y.I|가 있고 이것이 간선 길이와 상관관계가
있다. 두 정점의 좌표 사이의 유클리드 거리가 작으면 대개 그 둘을 잇는 간선도
비교적 짧다. (다만 이는 경향일 뿐 확실한 것은 아니다. 이를테면 체서피크 만
언저리의 어떤 도시들은 까마귀가 날아가듯 재면 꽤 가깝지만 차로 쉽게 오갈 수
있는 거리는 아니다.)

다섯째, 간선 길이는 삼각부등식을 만족한다. 간선 셋이 순환을 이룰 때마다, 가장
긴 것은 나머지 둘의 길이 합보다 길지 않다. (삼각부등식이 최소 신장 트리를 찾는
데 아무 쓸모가 없다는 것은 증명할 수 있다. 여기 적어 둔 것은 그저 |Miles|가
내놓는 자료가 무작위가 아님을 보여 주는 또 하나의 방식이기 때문이다.)

우리의 Kruskal 구현은 첫째 성질을 쓰고, 셋째 성질의 일부도 써서 간선을 두 번
보지 않게 한다. 나머지 성질은 쓰지 않는다. 그러나 이 그래프들의 최소 신장
트리를 더 적은 mem으로 찾는 알고리즘을 설계하고 싶은 독자는 도움이 되는
어떤 착상이든 자유롭게 써도 좋다.

@ mem 이야기가 나온 김에, 메모리 참조를 세는 데 쓰는 간단한 계량 장치를 보자.
\CEE/ 원본은 매크로 |o|, |oo|, |ooo|, |oooo|를 썼다. 그래서 Jon Bentley는 이것을
@^Bentley, Jon Louis@>
``작은 오(little oh) 분석''이라 불렀다. mem을 세려는 구현자는 메모리를 두 번
건드리는 대입문이나 불리언 식 바로 앞에 이를테면 `|oo|,'라고 적어 두면 되고,
\CEE/ 전처리기가 그것을 그 문장이나 식이 값매김될 때 |mems|를 2만큼 늘리는
문장으로 바꿔 준다.

\CEE/의 의미론에 따르면 `|a&&(o,a->len>10)|' 같은 식은 포인터 변수 |a|가
널이 아닐 때에만 |mems|를 늘린다. 주의: 이 예에서 괄호가 아주 중요하다. \CEE/의
연산자 \.{\&\&}가 쉼표보다 우선순위가 높기 때문이다.

@ 앞 예의 |a| 같은 중요한 변수의 값은 ``레지스터''에 있다고 보아, 레지스터끼리만
셈하는 산술에는 값을 물리지 않는다. 다만 어떤 구현에서든 레지스터의 총수는
유한하고 붙박이여야 하며, 문제 크기와 무관해야 한다.
@^\\{mems} 이야기@>

\CEE/는 선언문 안에 |o| 매크로를 넣을 수 없으므로, mem을 셀 때는 \CEE/의 초기화
기능을 온전히 쓰지 못한다. 그러나 선언을 마친 뒤에 따로 문장을 두어 변수를
초기화하기는 쉽다.

\GO/에는 매크로가 없으니, 그 자리에 |s.mems|를 직접 늘린다---|o|는 |s.mems++|,
|oo|는 |s.mems += 2|, 이런 식이다. 그래서 이 프로그램은 원본과 같은 자리에 같은
수의 mem을 물려, Knuth가 발표한 mem 수를 그대로 낸다.

@ 이런 mem 세기 관례의 보기가 아래 프로그램 곳곳에 나온다. 자동으로 mem을 세는
멋진 시스템을 만들 수도 있을 텐데 왜 손으로 매크로를 끼우라고 권하느냐고 묻는
이가 틀림없이 있을 것이다. 저자는 프로그래머가 |o|와 |oo| 따위를 손수 넣는 편이
가장 낫다고 믿으며, 그 까닭은 여럿이다. (1)~편집기로 매크로를 쉽고 빠르게 넣을
수 있다. (2)~적당한 최적화 컴파일러나 \CEE/ 원문을 조금 더 복잡하게 만드는
것으로 피할 수 있었을 mem까지 구현이 뒤집어쓸 까닭이 없다. 그러니 지은이는
지나치게 손으로 최적화한 코드보다 읽기 좋은 프로그램을 지킬 수 있도록 제 판단을
쓸 수 있다. (3)~프로그래머가 mem이 어디서 물리는지 정확히 볼 수 있어 병목을
없애는 데 도움이 된다. |o|와 |oo|가 놓인 자리가 프로그램 본문을 어지럽히지
않으면서 그것을 또렷이 보여 준다. (4)~진단 출력만을 위한 mem이나, 시험 중에
``증명된'' 단언을 다시 확인하려고 중복 계산을 하는 mem을 구현이 뒤집어쓸 까닭이
없다.
@^\\{mems} 이야기@>

@ 요즘 컴퓨터 구조는 프로그램의 정확한 실행 시간이 파이프라인 회로와 메모리
계층 속 캐시 매핑의 동적 성질 사이의 복잡한 상호작용에 달리는 쪽으로 빠르게
수렴하고 있다. 컴파일러와 운영체제의 영향은 말할 것도 없다. 그러나 계산의 양이
레지스터와 주기억장치 사이 메모리 버스의 활동에 비례한다고 보면 대개 실행 시간에
꽤 좋은 근삿값을 얻는다. 이 근사는 앞으로 더 좋아질 듯한데, RISC 컴퓨터가
메모리 장치에 견주어 점점 더 빨라지고 있기 때문이다.

mem이라는 잣대가 완벽과는 거리가 멀지만, 훨씬 많은 품을 들이지 않고 얻을 수 있는
어떤 측정값보다도 눈에 띄게 덜 일그러져 보인다. 적은 mem을 쓰도록 설계된 구현은
오늘날의 순차 컴퓨터에서도, 가까운 앞날에 지어질 순차 컴퓨터에서도 거의 틀림없이
효율적일 것이다. 그리고 그 역은 더욱 참이다: 빨리 도는 알고리즘은 mem을 많이 쓸
리 없다.

물론 지은이들은 최소 mem 상을 놓고 겨룰 때 온당하고 공정해야 한다. 공평한
심판의 검사에 제 프로그램을 내놓을 채비가 되어 있어야 한다. 좋은 알고리즘이라면
현실적인 mem 세기의 정신을 어길 일이 없을 것이다.

mem은 경험적으로만이 아니라 이론적으로도 분석할 수 있다. 그러니 언제나
$O$ 표기에 기대는 대신, 실행 시간 어림에 상수를 붙일 수 있다는 뜻이다.

@* Kruskal 알고리즘. 가장 단순한 첫 알고리즘이다. 간선을 길이가 줄지 않는
차례로 하나씩 보며, 앞서 고른 간선들과 회로를 이루지 않는 간선을 고른다.

간선 길이가 $2^{12}$보다 작으므로, $2^6$개들이 버킷 기수 정렬(radix sort)
두 번으로 정렬할 수 있다. 간선들을 |Arc| 레코드의 링크드 리스트로 버킷에
담는데, |Arc|의 두 유틸리티 필드를 |from|(|A.V|)과 |klink|(|B.A|)로 쓴다.

@<Kruskal 알고리즘@>=
// |krusk|는 Kruskal의 알고리즘(간선을 기수 정렬한 뒤 union-find)으로 최소
// 신장 트리 길이를 셈한다. 그래프가 이어져 있지 않으면 |infinity|를 준다.
func (s *solver) krusk() int64 {
	s.mems = 0
	var aucket, bucket [64]*gbgraph.Arc
	@<간선을 낮은 6비트로 |aucket|에 담는다@>
	@<|aucket|을 높은 6비트로 |bucket|에 옮긴다@>
	if s.verbose {
		fmt.Fprintf(s.out, "   [%d mems to sort the edges into buckets]\n", s.mems)
	}
	@<모든 정점을 저마다의 성분에 넣는다@>
	var totLen int64
	for l := 0; l < 64; l++ {
		s.mems++ // |o,a=bucket[l]|
		for a := bucket[l]; a != nil; {
			@<간선 |a|를 보아, 새 성분을 이으면 더한다@>
			s.mems++ // |o,a=a->klink| (\CEE/ |for|의 증가식 자리)
			a = a.B.A
		}
	}
	return infinity // 그래프가 이어져 있지 않았다
}

@ 기수 정렬 첫 패스다. 각 간선의 길이 낮은 6비트로 |aucket|에 담는다.
|a->tip>v|는 |tip|이 |v|보다 나중 정점일 때 참으로, 간선을 한 번만(작은 쪽
끝점에서) 보게 한다.

@<간선을 낮은 6비트로 |aucket|에 담는다@>=
s.mems++ // |o,n=g->n|
n := s.g.N
for l := 0; l < 64; l++ {
	s.mems += 2 // |oo,aucket[l]=bucket[l]=NULL|
	aucket[l], bucket[l] = nil, nil
}
s.mems++ // |o,v=g->vertices| (\CEE/ 바깥 |for|의 초기식)
for i := int64(0); i < n; i++ {
	v := &s.g.Vertices[i]
	s.mems++ // |o,a=v->arcs|
	a := v.Arcs
	for a != nil {
		s.mems++ // |o,a->tip>v|
		if s.g.Index(a.Tip) <= i {
			break
		}
		s.mems++ // |o,a->from=v|
		a.A.V = v
		s.mems++ // |o,l=a->len&0x3f|
		l := a.Len & 0x3f
		s.mems += 2 // |oo,a->klink=aucket[l]|
		a.B.A = aucket[l]
		s.mems++ // |o,aucket[l]=a|
		aucket[l] = a
		s.mems++ // |o,a=a->next|
		a = a.Next
	}
}

@ 둘째 패스다. 길이 높은 6비트로 |aucket|을 |bucket|에 옮기면, 간선들이 길이순
으로 |bucket[0]|부터 |bucket[63]|까지에 놓인다.

@<|aucket|을 높은 6비트로 |bucket|에 옮긴다@>=
for l := 63; l >= 0; l-- {
	s.mems++ // |o,a=aucket[l]|
	for a := aucket[l]; a != nil; {
		aa := a
		s.mems++ // |o,a=a->klink|
		a = a.B.A
		s.mems++ // |o,ll=aa->len>>6|
		ll := aa.Len >> 6
		s.mems += 2 // |oo,aa->klink=bucket[ll]|
		aa.B.A = bucket[ll]
		s.mems++ // |o,bucket[ll]=aa|
		bucket[ll] = aa
	}
}

@ |krusk|가 할 나머지 일은 ``동치 알고리즘'' 또는 ``합집합/찾기(union/find)''
자료 구조의 응용임을 쉽게 알아볼 수 있다. 우리는 무작위 그래프에서 평균 실행
시간이 선형임을 Knuth와 Sch\"onhage가 보인 단순한 방식을 쓴다[{\sl Theoretical
@^Knuth, Donald Ervin@>
@^Sch\"onhage, Arnold@>
Computer Science\/ \bf 6\/} (1978), 281--315].

각 성분(곧 여태 고른 간선들이 정하는 이어진 조각)의 정점들은 |clink|(|Z.V|)
포인터로 순환하며 이어진다. 정점마다 |comp|(|Y.V|) 필드도 있어 제 성분을
대표하는 유일한 정점을 가리킨다. 성분 대표에는 |csize|(|X.I|) 필드가 있어 그
성분에 정점이 몇 개인지 알려 준다.

@<모든 정점을 저마다의 성분에 넣는다@>=
components := s.g.N
for v := range s.g.AllVertices() {
	s.mems += 2 // |oo,v->clink=v->comp=v|
	v.Z.V, v.Y.V = v, v
	s.mems++ // |o,v->csize=1|
	v.X.I = 1
}

@ 간선 |a|의 두 끝점이 이미 같은 성분이면 건너뛴다. 아니면 트리에 더하고, 남은
성분이 하나가 되면 끝이다.

@<간선 |a|를 보아, 새 성분을 이으면 더한다@>=
s.mems++ // |o,u=a->from|
u := a.A.V
s.mems++ // |o,v=a->tip|
v := a.Tip
s.mems += 2 // |oo,u->comp==v->comp|
if u.Y.V != v.Y.V {
	if s.verbose {
		s.report(a.A.V, a.Tip, a.Len)
	}
	s.mems++ // |o,tot_len+=a->len|
	totLen += a.Len
	components--
	if components == 1 {
		return totLen
	}
	@<|u|와 |v|의 성분을 합친다@>
}

@ 두 성분을 합치는 일은 |clink| 포인터 둘, |csize| 필드 하나, 그리고 작은 쪽
성분의 정점마다 있는 |comp| 필드를 고치는 것이다.

여기서 첫 |if| 검사에 2 mem을 물리는데, |u.csize|와 |v.csize|를 메모리에서
읽어 오기 때문이다. 그러나 |u.csize|를 갱신할 때는 1 mem만 물린다. 더할 값들을
이미 읽어 두었기 때문이다. 그 사이에 |u|와 |v|가 뒤바뀌었을 수도 있는데
|u.csize+v.csize|를 그냥 더해도 안전하다는 것을 알아채려면 컴파일러가
똑똑해야 하는 게 사실이다. 하지만 우리는 컴파일러가 아주 영리하다고 가정한다.
(안 그러면 컴파일러를 못 믿을 때마다 프로그램을 어지럽혀야 한다. 결국 mem을
세는 프로그램은 무엇보다 {\sl 읽히려고\/} 있는 것이지 실전용이 아니다.)
@^\\{mems} 이야기@>

여담이지만 원본 소스의 바로 이 자리에는 조판되지 않는 \TEX/ 주석으로
``\.{Prim-arily?}''라는 말장난이 숨어 있다.

@<|u|와 |v|의 성분을 합친다@>=
u = u.Y.V // |u->comp|은 이미 읽었다
v = v.Y.V
if s.mems += 2; u.X.I < v.X.I { // |oo,u->csize<v->csize|
	u, v = v, u
}
s.mems++ // |o,u->csize+=v->csize|
u.X.I += v.X.I
s.mems++ // |o,w=v->clink|
w := v.Z.V
s.mems += 2 // |oo,v->clink=u->clink|
v.Z.V = u.Z.V
s.mems++ // |o,u->clink=w|
u.Z.V = w
for {
	s.mems++ // |o,w->comp=u|
	w.Y.V = u
	if w == v {
		break
	}
	s.mems++ // 반복마다 |o,w=w->clink|
	w = w.Z.V
}

@* Jarn\'\i k와 Prim의 알고리즘. 최소 신장 트리에 다가가는 두 번째 길도 꽤
단순하다. 다만 기술적으로 한 가지 성가신 점이 있다: 서로 다른 우선순위 큐
알고리즘을 갈아 끼울 수 있을 만큼 일반적으로 써야 한다는 것이다. 기본 착상은
임의의 정점 $v_0$에서 시작해 가장 가까운 이웃 $v_1$에 잇고, 그 조각을 다시 가장
가까운 이웃 $v_2$에 잇고, 이렇게 나아가는 것이다. 우선순위 큐가 지금 조각에
이웃하되 아직 조각에 들지 않은 정점들을 모두 담으며, 각 정점과 함께 저장되는
키 값은 그 정점에서 지금 조각까지의 거리다.

큐를 갈아 끼울 수 있도록, {\sc GB\_DIJK}에서 설명한 네 연산 |initQueue|,
|enqueue|, |requeue|, |delMin|을 인터페이스로 감싼다. 거기 나오는 Dijkstra의
최단 경로 알고리즘은 Jarn\'\i k과 Prim의 최소 신장 트리 알고리즘과 놀랍도록
닮았다. 실제로 Dijkstra는 최단 경로 절차를 떠올린 바로 그때 뒤엣것도 따로
발견했다.
@^Dijkstra, Edsger Wybe@>

정점의 키는 |dist|(|Z.I|)에, 그 거리만큼 떨어진 상대는 |backlink|(|Y.V|)에
둔다.

@<Jarn\'\i k/Prim 알고리즘@>=
type pqueue interface {
	initQueue(d int64)
	enqueue(v *gbgraph.Vertex, d int64)
	requeue(v *gbgraph.Vertex, d int64)
	delMin() *gbgraph.Vertex
}

@ 정점은 처음엔 ``못 봄''(unseen)이다. 큐에 들면 ``봄''(seen)이 되고, 큐를
떠나 조각에 들면 ``앎''(known)이 된다. 아는 정점의 |backlink|에는 특별한 표식
|known|을 둔다. |backlink|가 |nil|이면 못 본 것이다. \CEE/는 포인터 대소로
세 상태를 갈랐지만(|NULL|<|KNOWN|<진짜 정점), \GO/에서는 포인터를 견줄 수
없으니 표식과 |nil|을 또렷이 비교한다.

@<Jarn\'\i k/Prim 알고리즘@>=
var known = new(gbgraph.Vertex) // 아는 정점의 |backlink| 표식

func (s *solver) jarPr(pq pqueue) int64 {
	s.mems = 0
	var totLen int64
	@<정점 0만 보고 알게 한다@>
	for fragmentSize < s.g.N {
		@<|t|에 이웃한 못 본 정점을 큐에 넣고, 나머지 거리를 고친다@>
		t = pq.delMin()
		if t == nil {
			return infinity // 그래프가 이어져 있지 않다
		}
		if s.verbose {
			s.report(t.Y.V, t, t.Z.I)
		}
		s.mems++ // |o,tot_len+=t->dist|
		totLen += t.Z.I
		s.mems++ // |o,t->backlink=KNOWN|
		t.Y.V = known
		fragmentSize++
	}
	return totLen
}

@ |initQueue|를 부르는 데는 mem을 물리지 않았음을 눈여겨보라---그 안에서 세는
mem은 따로다. mem을 셀 때 서브루틴 호출에는 대체로 무엇을 물려야 할까?
서브루틴의 매개변수는 대개 레지스터로 가고 레지스터는 ``공짜''다. 게다가
컴파일러가 프로시저를 인라인으로 펼쳐 부대 비용을 아예 없앨 수도 있다. 그래서
서브루틴에 대해 권하는 mem 부과 방식은 이렇다: 서브루틴이 재귀적이지 않으면
아무것도 물리지 않고, 재귀적이면 실행 시간 스택에 저장해야 하는 것의 개수의
두 배를 물린다(복귀 주소도 저장해야 하는 것 가운데 하나다).
@^\\{mems} 이야기@>

@ 정점 $n-1$부터 1까지의 |backlink|를 지우고, 정점 0을 아는 정점으로 삼는다.

@<정점 0만 보고 알게 한다@>=
s.mems += 2 // |oo,t=g->vertices+g->n-1| (초기식)
for i := s.g.N - 1; i > 0; i-- {
	s.mems++ // |o,t->backlink=NULL|
	s.g.Vertices[i].Y.V = nil
}
t := &s.g.Vertices[0]
s.mems++ // |o,t->backlink=KNOWN|
t.Y.V = known
fragmentSize := int64(1)
pq.initQueue(0)

@ |t|의 이웃을 훑는다. 이미 본(그러나 아직 모르는) 이웃은 더 짧은 길을 찾았을
때만 다시 큐에 넣고, 처음 본 이웃은 큐에 넣는다. 못 본 가지에서 큐에 넣을 때는
|a->len|을 처음 읽으므로 1 mem을 더 문다(다시 넣기 가지는 앞서 견줄 때 이미
읽었다).

@<|t|에 이웃한 못 본 정점을 큐에 넣고, 나머지 거리를 고친다@>=
s.mems++ // |o,a=t->arcs|
for a := t.Arcs; a != nil; {
	s.mems++ // |o,v=a->tip|
	v := a.Tip
	s.mems++ // |o,v->backlink| (봄 여부)
	if v.Y.V != nil { // 이미 보았다
		if v.Y.V != known { // 보았으되 아직 모른다
			s.mems += 2 // |oo,a->len<v->dist|
			if a.Len < v.Z.I {
				s.mems++ // |o,v->backlink=t|
				v.Y.V = t
				pq.requeue(v, a.Len) // 더 나은 길을 찾았다
			}
		}
	} else { // 처음 본다
		s.mems++ // |o,v->backlink=t|
		v.Y.V = t
		s.mems++ // |o,| enqueue에 넘길 |a->len|을 읽는다
		pq.enqueue(v, a.Len)
	}
	s.mems++ // |o,a=a->next|
	a = a.Next
}

@* 이진 힙. |jarPr|를 마치려면 네 우선순위 큐 함수를 채워야 한다. Jarn\'\i k은
컴퓨터라는 것이 알려지기도 전에 제 논문을 썼고, Prim과 Dijkstra는 효율적인
우선순위 큐 알고리즘이 알려지기 전에 썼다. 그래서 그들의 원래 알고리즘은
$\Theta(n^2)$ 걸음이 든다. 이진 힙으로 더 잘할 수 있다는 것은 Kerschenbaum과
@^Kerschenbaum, A.@>
@^Van Slyke, Richard Maurice@>
Van Slyke가 1972년에 지적했다. 여기서는 Williams가 1964년에 고안한 이진 힙의
@^Williams, John William Joseph@>
간추린 판을 쓴다.

이진 힙은 원소 $n$개짜리 배열이고, 우리에게는 그 자리가 필요하다. 다행히 그
자리는 이미 있다. 그래프의 정점 레코드마다 있는 |u| 유틸리티 필드를 쓰면 된다.
게다가 |heapElt(i)|(곧 |gv[i].U.V|)가 정점 |v|를 가리키면 |v.V.I=i|가 되도록
맞춰 둔다. 힙은 1부터 센다.

힙을 비우는 데는 ``레지스터'' 둘을 아는 값으로 두기만 하면 되므로, mem을
아예 물리지 않는다. (실전 구현이라면 이 코드는 신장 트리 알고리즘 안에
인라인으로 들어갔을 것이다.)
@^\\{mems} 이야기@>

@ 힙을 돌아가게 하는 핵심 불변식은
$$\hbox{|heapElt(k/2).dist| $\le$ |heapElt(k).dist|,\qquad $1<k\le hsize$}$$
이다. (힙 순서를 처음 보는 독자라면 여기서 잠깐 멈추고, 이 별것 아닌 듯한
부등식 묶음이 낳는 아름다운 결과들을 음미해 보기를 권한다.)

@<이진 힙@>=
type binHeap struct {
	s     *solver
	gv    []gbgraph.Vertex // |g.Vertices|, 힙 배열의 바탕
	hsize int64            // 지금 힙에 든 원소 수
}

func (h *binHeap) initQueue(d int64) {
	h.gv = h.s.g.Vertices
	h.hsize = 0
}

@ 큐에 넣기다. 새 원소를 힙 끝에 두었다가, 부모보다 키가 작으면 위로 올린다
(``siftup''). 부모 위치의 정점 |u|를 읽어 그 |dist|와 견주는 데 2 mem을 문다.

@<이진 힙@>=
func (h *binHeap) enqueue(v *gbgraph.Vertex, d int64) {
	h.s.mems++ // |o,v->dist=d|
	v.Z.I = d
	h.hsize++
	k := h.hsize
	j := k >> 1
	for j > 0 {
		h.s.mems += 2 // |oo,(u=heapElt(j))->dist>d|
		u := h.gv[j].U.V
		if u.Z.I <= d {
			break
		}
		h.s.mems++ // |o,heapElt(k)=u|
		h.gv[k].U.V = u
		h.s.mems++ // |o,u->heap_index=k|
		u.V.I = k
		k = j
		j = k >> 1
	}
	h.s.mems++ // |o,heapElt(k)=v|
	h.gv[k].U.V = v
	h.s.mems++ // |o,v->heap_index=k|
	v.V.I = k
}

@ 그리고 사실 일반적인 다시 넣기 연산은 넣기와 거의 똑같다. 이 연산은 흔히
``siftup''이라 불리는데, 키가 줄어든 정점이 제 조상들을 힙 위쪽으로 밀어낼 수
있기 때문이다. 넣기를 구현할 때 새 원소를 힙 끝에 놓고 나서 다시 넣기를 부르는
식으로 할 수도 있었다. 그랬다면 mem이 많아야 두어 개 더 들었을 것이다.

@<이진 힙@>=
func (h *binHeap) requeue(v *gbgraph.Vertex, d int64) {
	h.s.mems++ // |o,v->dist=d|
	v.Z.I = d
	h.s.mems++ // |o,k=v->heap_index|
	k := v.V.I
	j := k >> 1
	var u *gbgraph.Vertex
	if j > 0 {
		h.s.mems += 2 // |oo,(u=heapElt(j))->dist>d|
		u = h.gv[j].U.V
	}
	if j > 0 && u.Z.I > d { // 바꿀 일이 있다
		for {
			h.s.mems++ // |o,heapElt(k)=u|
			h.gv[k].U.V = u
			h.s.mems++ // |o,u->heap_index=k|
			u.V.I = k
			k = j
			j = k >> 1
			if j <= 0 {
				break
			}
			h.s.mems += 2 // |oo|
			u = h.gv[j].U.V
			if u.Z.I <= d {
				break
			}
		}
		h.s.mems++ // |o,heapElt(k)=v|
		h.gv[k].U.V = v
		h.s.mems++ // |o,v->heap_index=k|
		v.V.I = k
	}
}

@ 끝으로, 키가 가장 작은 정점을 빼내는 절차는 조금 더 까다로울 뿐이다. 뺄
정점은 늘 |heapElt(1)|이다. 그것을 지운 뒤 기본 힙 부등식이 다시 성립할
때까지 |heapElt(hsize)|를 아래로 ``내려 거른다''(siftdown). 두 자식의 |dist|를
견주는 데 4 mem을 문다.

이 과정의 결정적인 대목에서 우리는 |j.dist<u.dist|를 얻는다. 그때
$|j|=|hsize|+1$일 수는 없는데, 앞선 걸음들이 |heapElt(hsize+1).dist| $=$
|u.dist| $=$ |d|로 만들어 두었기 때문이다. 그래서 아래 고리 안에서 |j|가
|hsize|를 넘는지 다시 살피지 않아도 안전하다.

@<이진 힙@>=
func (h *binHeap) delMin() *gbgraph.Vertex {
	if h.hsize == 0 {
		return nil
	}
	h.s.mems++ // |o,v=heapElt(1)|
	v := h.gv[1].U.V
	h.s.mems++ // |o,u=heapElt(hsize--)|
	u := h.gv[h.hsize].U.V
	h.hsize--
	h.s.mems++ // |o,d=u->dist|
	d := u.Z.I
	k, j := int64(1), int64(2)
	for j <= h.hsize {
		h.s.mems += 4 // |oooo|, 두 자식의 |dist| 견주기
		if h.gv[j].U.V.Z.I > h.gv[j+1].U.V.Z.I {
			j++
		}
		if h.gv[j].U.V.Z.I >= d { // 방금 읽은 값이라 mem 없음
			break
		}
		hj := h.gv[j].U.V
		h.s.mems++ // |o,heapElt(k)=heapElt(j)|
		h.gv[k].U.V = hj
		h.s.mems++ // |o,heapElt(k)->heap_index=k|
		hj.V.I = k
		k = j
		j = k << 1
	}
	h.s.mems++ // |o,heapElt(k)=u|
	h.gv[k].U.V = u
	h.s.mems++ // |o,u->heap_index=k|
	u.V.I = k
	return v
}

@ 이제 이진 힙을 Jarn\'\i k/Prim에 끼운다. 결과 길이가 Kruskal과 다르면
버그다.

@<이진 힙으로 |jarPr(g)|를 실행한다@>=
if l := s.jarPr(&binHeap{s: s}); l != spLength {
	fmt.Fprintln(s.out, " ...oops, I've got a bug, please fix fix fix")
	os.Exit(4)
}

@* 피보나치 힙. 정점 $n$개와 간선 $m$개를 가진 이어진 그래프에 이진 힙을 쓴
Jarn\'\i k/Prim을 돌리면 실행 시간은 $O(m\log n)$이다. 연산의 총수가
$O(m+n)=O(m)$이고 힙 연산 하나가 많아야 $O(\log n)$ 걸리기 때문이다.

피보나치 힙은 이보다 잘하려고 Fredman과 Tarjan이 1984년에 고안했다.
@^Fibonacci, Leonardo, 힙@>
@^Fredman, Michael Lawrence@>
@^Tarjan, Robert Endre@>
Jarn\'\i k/Prim 알고리즘은 넣기를 $O(n)$번, 키 최소 빼기를 $O(n)$번, 다시 넣기를
$O(m)$번 한다. 그래서 두 사람은 다시 넣기를 ``분할 상환 상수 시간''에 해내는
자료 구조를 설계했다. 다시 말해 피보나치 힙에서는 다시 넣기 하나하나는 오래
걸릴 수 있어도 $m$번을 통틀어 $O(m)$이면 된다. 그러면 점근적 실행 시간이
$O(m+n\log n)$이 된다. (같은 기법을 Dijkstra의 최단 경로 알고리즘에 쓰면 이것이
상수배 안에서 최적임이 드러난다. 그러나 최소 신장 트리에서는 피보나치 방식이 늘
최적인 것은 아니다. 이를테면 $m\approx n\sqrt{\mathstrut\log n}$이면 Cheriton과
Tarjan의 알고리즘이 $O(m\log\log n)$으로 조금 더 낫다.)

@ 피보나치 힙은 이진 힙보다 복잡하니, $m$과 $n$이 꽤 크지 않은 한 부대 비용
때문에 겨룰 만하지 않으리라 볼 만하다. 게다가 단순한 이진 힙의 실행 시간이
현실적인 자료에서 정말 $m\log n$처럼 움직일지도 분명치 않다. $O(m\log n)$은
꽤 비관적인 가정에 바탕한 최악의 경우 어림이기 때문이다. (이를테면 다시 넣기가
siftup 고리를 여러 번 도는 일은 드물지도 모른다.) 그래도 피보나치 힙을 할 수
있는 한 잘 구현해 두면, 실제로 얼마나 좋아 보이는지 알 수 있어 배울 것이 있다.

숲에서 마디의 {\sl 계수\/}(rank)란 그 마디가 가진 자식의 수라고 하자. 피보나치
힙은 순서 없는 트리들의 숲으로, 각 마디의 키가 그 자식들의 키보다 작거나 같고,
게다가 성질~F라 부르는 다음 조건도 성립한다: 계수 $k$인 마디의 자식들의 계수
$\{r_1,r_2,\ldots,r_k\}$를 줄지 않는 차례 $r_1\le r_2\le\cdots\le r_k$로 놓았을
때 모든 $j$에 대해 $r_j\ge j-2$다.

@ 성질 F의 결과로, 계수 $k$인 마디는 (자기까지 쳐서) 자손이 적어도 $F_{k+2}$개
있음을 귀납법으로 증명할 수 있다. 그러므로 이를테면 숲 전체의 크기가 적어도
$F_{32}=2{,}178{,}309$가 아닌 한 계수 $30$ 이상인 마디는 있을 수 없다. 계수
$46$ 이상인 마디가 있으려면 숲의 크기가 $2^{32}$를 넘어야 한다.

@ 필요한 모든 연산의 효율을 보장하려고, 피보나치 힙은 꽤 공들인 자료 구조로
나타낸다. 마디마다 포인터 넷을 둔다. |parent|는 마디의 부모(뿌리면 |nil|),
|child|는 마디의 자식 가운데 하나(자식이 없으면 뜻이 없다), |lsib|와 |rsib|는
왼쪽과 오른쪽 형제다. 각 마디의 자식들, 그리고 숲의 뿌리들은 |lsib|와 |rsib|로
순환 이중 연결 리스트를 이룬다. 이 리스트에서 마디들이 어떤 차례로 놓이든
상관없고, |child| 포인터도 어느 자식을 가리키든 상관없다.

포인터 넷 말고도 자식이 몇인지 알려 주는 |rank| 필드와, $0$이거나 $1$인 |tag|
필드가 있다. 이 둘은 $|rank|\cdot2+|tag|$인 |rank_tag| 필드 하나로 합쳐 자리와
시간을 조금 아낀다.

외부 포인터 |fHeap|이 키가 가장 작은 마디를 가리킨다. (힙이 비었으면 |nil|이다.)

@ |tag|가 무엇을 위한 것인지 밝혀 두자. 어떤 마디의 자식들의 계수가
$r_1\le r_2\le\cdots\le r_k$라 하자. 모든 $j$에 대해 $r_j\ge j-2$인 것은 아는데,
$r_j=j-2$인 등호가 $l$번 성립하면 그 마디에 {\sl 위태로운\/}(critical) 자식이
$l$개 있다고 하자. 우리 구현은 위태로운 자식이 $l$개인 마디에는 그에 대응하는
계수의 표식 붙은 자식이 적어도 $l$개 있도록 보장한다.

이를테면 어떤 마디에 계수가 각각 $\{1,1,1,2,4,4,6\}$인 자식 일곱이 있다고 하자.
이 마디에는 위태로운 자식이 셋인데, $r_3=1$, $r_4=2$, $r_6=4$이기 때문이다. 우리
구현에서는 계수 $1$인 자식 가운데 적어도 하나가 $|tag|=1$일 것이고, 계수 $2$인
자식도 그럴 것이며, 계수 $4$인 자식 가운데 하나도 그럴 것이다.

@ \CEE/ 원본은 자리가 모자랐다. GraphBase 그래프의 정점에는 유틸리티 필드가
여섯 개 있는데, |parent|, |child|, |lsib|, |rsib|, |rank_tag|, 그리고 키 필드
|dist|를 담기에 딱 맞는다. 그러나 |backlink| 필드도 있어야 하니 한도를 넘는다.
원본은 정점마다 |Arc| 레코드 하나를 따로 잡아 |parent|와 |child|를 거기 우회해
담고, 간접 참조에 드는 시간은 mem으로 물리지 않았다---실전 시스템이라면 |Vertex|
레코드에 유틸리티 필드를 일곱 개 두었을 것이기 때문이다.
@^\\{mems} 이야기@>

\GO/에서는 그럴 일이 없다. 유틸리티 필드가 |.V|, |.A|, |.I|를 저마다 따로 가진
구조체라, 우회 없이 곧장 담는다: |parent|(|U.V|), |child|(|X.V|), |lsib|(|V.V|),
|rsib|(|W.V|), |rank_tag|(|X.I|), |dist|(|Z.I|).

@<피보나치 힙@>=
type fibHeap struct {
	s        *solver
	fHeap    *gbgraph.Vertex     // 뿌리 마디들의 고리; 키 최소를 가리킴
	newRoots [46]*gbgraph.Vertex // 계수별 뿌리 (크기 $2^{32}$까지)
}

func (h *fibHeap) initQueue(d int64) { h.fHeap = nil }

@ 우리가 나타낸 대로의 피보나치 힙의 {\sl 위치 에너지\/}는 숲에 있는 트리의 수에
표식 붙은 자식의 총수의 두 배를 더한 것으로 정의한다. 힙에 연산을 할 때 우리는
나중에 쓸 위치 에너지를 쌓아 두고, 그러면 뒤의 연산들을 실행 시간에 조금만
보태면서 해낼 수 있다. (위치 에너지는 분할 상환 비용이 작음을 증명하는 방편일
뿐, 구현에 드러나 나타나지는 않는다. 그저 우리가 셈하는 mem 수가 왜 늘
$O(m+n\log n)$인지를 설명해 줄 따름이다.)

넣기는 쉽다. 새 원소를 숲에 새 트리로 넣기만 한다. 이는 상수 시간이 드는데,
새 트리를 위한 위치 에너지 한 단위를 새로 쌓는 값까지 쳐서 그렇다.
|fHeap.dist|는 레지스터에 있다고 보아 읽는 데 mem을 물리지 않는다.

@<피보나치 힙@>=
func (h *fibHeap) enqueue(v *gbgraph.Vertex, d int64) {
	h.s.mems++ // |o,v->dist=d|
	v.Z.I = d
	h.s.mems++ // |o,v->parent=NULL|
	v.U.V = nil
	h.s.mems++ // |o,v->rank_tag=0|
	v.X.I = 0
	if h.fHeap == nil {
		h.s.mems += 2 // |oo,F_heap=v->lsib=v->rsib=v|
		v.V.V, v.W.V = v, v
		h.fHeap = v
	} else {
		h.s.mems++ // |o,u=F_heap->lsib|
		u := h.fHeap.V.V
		h.s.mems++ // |o,v->lsib=u|
		v.V.V = u
		h.s.mems++ // |o,v->rsib=F_heap|
		v.W.V = h.fHeap
		h.s.mems += 2 // |oo,F_heap->lsib=u->rsib=v|
		h.fHeap.V.V, u.W.V = v, v
		if h.fHeap.Z.I > d {
			h.fHeap = v
		}
	}
}

@ 다시 넣기는 중간 난도다. 뿌리 마디에서 키를 줄이거나, 줄여도 부모의 키보다
작아지지 않으면 (|fHeap| 자신 말고는) 이음을 바꿀 것이 없다. 그렇지 않으면 그
마디와 그 자손들을 지금의 가족에서 떼어 내, 예전에 부분트리이던 그것을 숲의
새 트리로 넣는다. (위치 에너지 한 단위를 그것과 함께 쌓아야 한다.)

예전 부모 |p|의 계수는 1 줄어든다. |p|가 뿌리이면 그것으로 끝이다. 그렇지 않고
|p|에 표식이 없었으면 표식을 단다(그리고 위치 에너지 두 단위를 더 치른다).
표식 없는 마디는 계수가 줄어드는 것을 언제나 받아들일 수 있으므로 성질 F는 여전히
성립한다. 그러나 |p|에 표식이 있었으면 |p|와 그 남은 자손들을 떼어 내 숲의 또
다른 새 트리로 만들고, |p|의 표식을 없앤다. 표식을 떼면 |p|를 옮기는 데 드는
여분의 일을 치를 만큼의 에너지가 풀려 나온다. 그러고 나서 |p|의 부모의 계수를
줄여야 하고, 이런 식으로 마침내 뿌리나 표식 없는 마디에 이를 때까지 이어진다.
알짜 비용은 많아야 에너지 세 단위에 원래 마디를 다시 잇는 값이니 $O(1)$이다.

뿌리 마디의 표식 필드는 굳이 지우지 않는다. 우리가 그것을 들여다볼 일이 없기
때문이다.

@<피보나치 힙@>=
func (h *fibHeap) requeue(v *gbgraph.Vertex, d int64) {
	h.s.mems++; v.Z.I = d // |o,v->dist=d|
	h.s.mems++; p := v.U.V // |o,p=v->parent|
	if p == nil {
		if h.fHeap.Z.I > d {
			h.fHeap = v
		}
		return
	}
	h.s.mems++ // |o,p->dist>d|
	if p.Z.I <= d {
		return
	}
	for {
		h.s.mems++; r := p.X.I // |o,r=p->rank_tag|
		if r >= 4 { // |v|는 외자식이 아니다
			@<|v|를 가족에서 뗀다@>
		}
		@<|v|를 숲에 넣는다@>
		@<부모의 계수를 줄이고, 필요하면 위로 이어 간다@>
	}
}

@ 잘라 낸 부분트리를 숲에 옮겨 놓았으니, 이제 부모 |p|의 살림을 셈할 차례다.
|p|가 뿌리이면 계수만 1 줄이고 끝낸다. 뿌리가 아닌데 표식이 없었으면 표식을
달고 끝낸다---|rank_tag|가 $r-1$이 되는 것이 곧 계수는 그대로 두고 표식만 켜는
일이다. 표식이 있었으면 |p| 자신을 잘라 올려야 하므로, |v|와 |p|를 한 대 위로
옮겨 고리를 한 바퀴 더 돈다.

@<부모의 계수를 줄이고, 필요하면 위로 이어 간다@>=
h.s.mems++; pp := p.U.V // |o,pp=p->parent|
if pp == nil { // |v|의 부모가 뿌리다
	h.s.mems++; p.X.I = r - 2 // |o,p->rank_tag=r-2|
	break
}
if r&1 == 0 { // 부모에 표식이 없다
	h.s.mems++; p.X.I = r - 1 // |o,p->rank_tag=r-1|
	break // 이제 표식이 붙었다
}
h.s.mems++; p.X.I = r - 2 // |o,p->rank_tag=r-2| (표식 있던 부모는 뿌리가 된다)
v = p
p = pp

@ @<|v|를 가족에서 뗀다@>=
h.s.mems++ // |o,u=v->lsib|
u := v.V.V
h.s.mems++ // |o,w=v->rsib|
w := v.W.V
h.s.mems++ // |o,u->rsib=w|
u.W.V = w
h.s.mems++ // |o,w->lsib=u|
w.V.V = u
h.s.mems++ // |o,p->child==v|
if p.X.V == v {
	h.s.mems++ // |o,p->child=w|
	p.X.V = w
}

@ @<|v|를 숲에 넣는다@>=
h.s.mems++ // |o,v->parent=NULL|
v.U.V = nil
h.s.mems++ // |o,u=F_heap->lsib|
fu := h.fHeap.V.V
h.s.mems++ // |o,v->lsib=u|
v.V.V = fu
h.s.mems++ // |o,v->rsib=F_heap|
v.W.V = h.fHeap
h.s.mems += 2 // |oo,F_heap->lsib=u->rsib=v|
h.fHeap.V.V, fu.W.V = v, v
if h.fHeap.Z.I > d {
	h.fHeap = v // 원래 |v|에서만 일어난다
}

@ 키 최소 빼기는 한결 더 재미있다. 사실 여기가 볼거리의 대부분이 있는 곳이다.
|fHeap|이 우리가 지울 마디 $v$를 가리킨다는 것은 안다. 좋은 일이지만, |fHeap|의
새 값을 알아내야 한다. 그러자면 $v$의 모든 자식과 숲의 모든 뿌리 마디를 봐야
한다. 그럴 만큼의 위치 에너지는 쌓아 두었지만, 다시 세운 판이 트리를 비교적 적게
담도록 피보나치 힙을 새로 지어야만 그 에너지를 되찾을 수 있다.

해법은 새 힙이 계수마다 뿌리를 많아야 하나 갖게 하는 것이다. 계수가 같은 트리
뿌리가 둘 생길 때마다 하나를 다른 하나의 자식으로 삼아 트리 수를 1 줄일 수 있다.
(새 자식은 성질 F를 어기지 않고 위태롭지도 않으니 표식 없음으로 두면 된다.)
마디가 모두 $n$개일 때 가장 큰 계수는 늘 $O(\log n)$이고, 위치 에너지에서
되찾지 못하는 일에 대해서는 $\log n$ 단위의 시간을 치를 만하다.

계수를 아는 뿌리들을 가리키는 배열이 이 과정을 다스리는 데 쓰인다. 크기 $46$이면
원소가 $2^{32}$개인 큐까지 넉넉하다.

@<피보나치 힙@>=
func (h *fibHeap) delMin() *gbgraph.Vertex {
	finalV := h.fHeap
	hi := int64(-1) // |new_roots|에 있는 가장 높은 계수
	if h.fHeap != nil {
		var v *gbgraph.Vertex
		@<지울 마디의 자식들을 뿌리 고리에 풀어 놓는다@>
		for v != h.fHeap {
			h.s.mems++ // |o,w=v->rsib|
			w := v.W.V
			@<|v|를 뿌리로 하는 트리를 |new_roots| 숲에 넣는다@>
			v = w
		}
		@<|new_roots|에서 |fHeap|을 다시 세운다@>
	}
	return finalV
}

@ 먼저 지울 마디의 자식들을 뿌리들의 고리에 풀어 놓는다. |fHeap|의 |rank_tag|가
2보다 작으면 계수가 $0$이라 자식이 없으니 오른쪽 형제부터 훑기 시작하면 된다.
자식이 있으면 자식들의 고리를 뿌리 고리에 이어 붙이고, 그 자식들의 |parent|를
모두 |nil|로 만든다---이제 그들이 뿌리이기 때문이다. |v|는 훑기를 시작할 자리를
가리키게 된다.

@<지울 마디의 자식들을 뿌리 고리에 풀어 놓는다@>=
h.s.mems++ // |o,F_heap->rank_tag<2|
if h.fHeap.X.I < 2 {
	h.s.mems++ // |o,v=F_heap->rsib|
	v = h.fHeap.W.V
} else {
	h.s.mems++ // |o,w=F_heap->child|
	w := h.fHeap.X.V
	h.s.mems++ // |o,v=w->rsib|
	v = w.W.V
	h.s.mems += 2 // |oo,w->rsib=F_heap->rsib| (지운 마디의 자식들을 잇는다)
	w.W.V = h.fHeap.W.V
	for w = v; w != h.fHeap.W.V; {
		h.s.mems++ // |o,w->parent=NULL|
		w.U.V = nil
		h.s.mems++ // 반복마다 |o,w=w->rsib|
		w = w.W.V
	}
}

@ |v|의 계수 |r|이 아직 |new_roots|에 없으면 그 자리에 놓는다. 이미 그 계수의
뿌리 |u|가 있으면, 키가 작은 쪽을 부모로 삼아 둘을 합치고(계수 |r+1|의 carry),
자리가 빌 때까지 이어 간다.

@<|v|를 뿌리로 하는 트리를 |new_roots| 숲에 넣는다@>=
h.s.mems++ // |o,r=v->rank_tag>>1|
r := v.X.I >> 1
for {
	if hi < r {
		for {
			hi++
			h.s.mems++ // |o,new_roots[h]=...|
			if hi == r {
				h.newRoots[hi] = v
			} else {
				h.newRoots[hi] = nil
			}
			if hi >= r {
				break
			}
		}
		break
	}
	h.s.mems++ // |o,new_roots[r]==NULL|
	if h.newRoots[r] == nil {
		h.s.mems++ // |o,new_roots[r]=v|
		h.newRoots[r] = v
		break
	}
	u := h.newRoots[r]
	h.s.mems++; h.newRoots[r] = nil// |o,new_roots[r]=NULL|
	h.s.mems += 2 // |oo,u->dist<v->dist|
	if u.Z.I < v.Z.I {
		h.s.mems++; v.X.I = r << 1 // |o,v->rank_tag=r<<1|
		u, v = v, u
	}
	@<|u|를 |v|의 자식으로 만든다@>
	r++
}
h.s.mems++; v.X.I = r << 1 // |o,v->rank_tag=r<<1|

@ 이때 |u|와 |v| 모두 계수 |r|이고 |u->dist>=v->dist|이며 |u|엔 표식이 없다.

@<|u|를 |v|의 자식으로 만든다@>=
if r == 0 {
	h.s.mems++ // |o,v->child=u|
	v.X.V = u
	h.s.mems += 2 // |oo,u->lsib=u->rsib=u|
	u.V.V, u.W.V = u, u
} else {
	h.s.mems++ // |o,t=v->child|
	t := v.X.V
	h.s.mems += 2 // |oo,u->rsib=t->rsib|
	u.W.V = t.W.V
	h.s.mems++ // |o,u->lsib=t|
	u.V.V = t
	h.s.mems += 2 // |oo,u->rsib->lsib=t->rsib=u|
	u.W.V.V.V, t.W.V = u, u
}
h.s.mems++ // |o,u->parent=v|
u.U.V = v

@ 마지막 걸음은 시시하다: |new_roots|의 뿌리들을 하나의 고리로 잇고, 그중 키가
가장 작은 것을 |fHeap|으로 삼는다.

@<|new_roots|에서 |fHeap|을 다시 세운다@>=
if hi < 0 {
	h.fHeap = nil
} else {
	h.s.mems++ // |o,u=v=new_roots[h]|
	u := h.newRoots[hi]
	v = u
	h.s.mems++ // |o,d=u->dist|
	d := u.Z.I
	h.fHeap = u
	for hi--; hi >= 0; hi-- {
		h.s.mems++ // |o,new_roots[h]|
		if h.newRoots[hi] != nil {
			w := h.newRoots[hi]
			h.s.mems++ // |o,w->lsib=v|
			w.V.V = v
			h.s.mems++ // |o,v->rsib=w|
			v.W.V = w
			h.s.mems++ // |o,w->dist<d|
			if w.Z.I < d {
				h.fHeap = w
				d = w.Z.I
			}
			v = w
		}
	}
	h.s.mems++ // |o,v->rsib=u|
	v.W.V = u
	h.s.mems++ // |o,u->lsib=v|
	u.V.V = v
}

@ 이제 피보나치 힙을 Jarn\'\i k/Prim에 끼운다.

@<피보나치 힙으로 |jarPr(g)|를 실행한다@>=
if l := s.jarPr(&fibHeap{s: s}); l != spLength {
	fmt.Fprintln(s.out, " ...oops, I've got a bug, please fix fix fix")
	os.Exit(5)
}

@* 이항 큐. Jean Vuillemin의 ``이항 큐'' 구조[{\sl CACM\/ \bf 21\/} (1978),
@^Vuillemin, Jean Etienne@>
309--314]는 우선순위 큐를 다루는 또 하나의 매력적인 길이다. 이항 큐는 피보나치
힙에서처럼 키가 정렬된 트리들의 숲인데, 피보나치 힙의 성질보다 상당히 강한 두
조건을 지킨다: 계수 $k$인 마디는 계수가 각각 $\{0,1,\ldots,k-1\}$인 자식들을
가지며, 숲의 뿌리들은 저마다 계수가 다르다. 그러므로 계수 $k$인 마디는 (자기까지
쳐서) 자손이 정확히 $2^k$개이고, 원소 $n$개짜리 이항 큐의 트리 수는 $n$을
이진법으로 적었을 때의 1의 개수와 정확히 같다.

@ 이항 큐를 Jarn\'\i k/Prim에 끼울 수도 있겠지만, 다시 넣기를 그리 곱게 다루지
못하므로 이미 살펴본 힙 방식들보다 나을 것이 없다. 그러나 이항 큐는 합치기---두
우선순위 큐를 하나로 묶는 연산---를 효율적으로 해내며, 게다가 피보나치 힙만큼
자리를 더 쓰지 않고 그렇게 한다. 사실 이항 큐는 마디당 포인터 둘만으로 구현할 수
있다. 가장 큰 자식을 가리키는 것과 다음 형제를 가리키는 것이다. 그러니 GraphBase
|Arc| 레코드의 유틸리티 필드만으로 신장 트리 조각 밖으로 뻗는 호들을 이을 자리가
딱 나온다. 곧 살펴볼 Cheriton, Tarjan, Karp의 알고리즘은 정점이 아니라 {\sl 호\/}
의 우선순위 큐를 지니며, 다시 넣기가 아니라 합치기를 필요로 한다. 그러므로 이항
큐가 거기에 잘 맞고, 우리는 그 알고리즘에 대비해 기본 이항 큐 절차들을 먼저
구현해 둔다.

두 포인터는 |qchild|(|A.A|)와 |qsib|(|B.A|)라 부른다.

@ 그런데 Vuillemin이 왜 제 구조를 이항 큐라 불렀는지 궁금하다면, $2^k$개
원소짜리 트리에 즐거운 조합적 성질이 많기 때문인데 그 가운데 하나가 레벨 $l$에
있는 원소의 수가 이항계수 $k\choose l$이라는 것이다. $k$개짜리 집합의 부분집합을
훑는 되추적 트리도 같은 구조다. $k=5$인 이항 큐 트리를 Jill~C. Knuth가 그린
@^Knuth, Nancy Jill Carter@>
그림이 {\sl The Art of Computer Programming\/} 제1권 1쪽 맞은편에 권두 삽화로
실려 있다.

@ 큐 자체를 나타내는 특별한 머리 마디를 큐 앞에 둔다. 이 마디의 |qsib| 필드는
숲에서 계수가 가장 작은 뿌리 마디를 가리킨다(``가장 작은''은 키 값이 아니라
계수가 작다는 뜻이다). 머리 마디에는 |qchild| 자리를 대신 차지하는
|qcount|(|A.I|) 필드도 있는데, 이는 마디의 총수이므로 그 이진 표현이 |qsib|에서
닿을 수 있는 트리들의 크기를 말해 준다.

이를테면 머리 마디가 |h|인 큐에 원소 다섯 $\{a,b,c,d,e\}$가 있고 그 키가 마침
알파벳 차례라고 하자. 첫 트리는 마디 하나 $c$일 수 있고, 다른 트리는 $a$를
뿌리로 하여 자식 $e$와 $b$를 가질 수 있다. 그러면 이렇게 된다.
$$\vbox{\halign{#\hfil&\qquad#\hfil\cr
|h.qcount=5|,&|h.qsib=c|;\cr
|c.qsib=a|;\cr
|a.qchild=b|;\cr
|b.qchild=d|,&|b.qsib=e|;\cr
|e.qsib=b|.\cr}}$$
나머지 필드 |c.qchild|, |a.qsib|, |e.qchild|, |d.qsib|, |d.qchild|는 뜻이 없다.
뜻 없는 필드는 읽지도 쓰지도 않음으로써 시간을 아낄 수 있는데, 그런 필드가 구조
전체의 약 $3/8$을 차지한다.

빈 이항 큐는 |h.qcount=0|이고 |h.qsib|은 뜻이 없다.

피보나치 힙처럼 이항 큐도 위치 에너지를 쌓아 둔다. 여기서 에너지 단위의 수는
그저 숲에 있는 트리의 수다.

이 큐의 키 필드는 |dist|가 아니라 |len|이다. 이 경우 마디가 정점이 아니라
호이기 때문이다.

@ 우리가 이항 큐로 하려는 연산 대부분이 다음의 기본 서브루틴에 기댄다. |qunite|는
|q|에서 시작하는 |m|개 마디 숲과 |qq|에서 시작하는 |mm|개 마디 숲을 합쳐,
$|m|+|mm|$개 마디로 된 결과 숲의 포인터를 |h.qsib|에 넣는다. 분할 상환 실행
시간은 |mm|과 무관하게 $O(\log |m|)$이다.

피보나치 힙에서 보았듯, 힙 정렬된 두 트리는 한쪽을 다른 쪽의 새 자식으로 붙이기만
하면 합쳐진다. 이 연산은 이항 트리를 보존한다. (사실 피보나치 힙을 쓰면서 다시
넣기를 한 번도 하지 않으면, 키 최소 빼기를 할 때마다 나타나는 숲이 곧 이항
큐다.) 트리 수가 1 줄어드니 이 계산을 치를 위치 에너지 한 단위가 생긴다.

이 절차는 이진 덧셈의 자리올림과 똑같이 움직인다. |m|과 |mm|을 이진수로 보면
같은 크기의 트리 둘이 만날 때 크기 $2k$짜리 ``자리올림'' 트리가 생겨, 더 큰
자리로 번져 간다.

@<이항 큐@>=
func (s *solver) qunite(m int64, q *gbgraph.Arc, mm int64, qq *gbgraph.Arc, h *gbgraph.Arc) {
	p := h
	k := int64(1)
	for m != 0 {
		@<크기 |k|짜리 자리를 처리한다@>
		k <<= 1
	}
	if mm != 0 {
		s.mems++ // |o,p->qsib=qq|
		p.B.A = qq
	}
}

@ 크기 $k$짜리 자리에서 벌어질 수 있는 일은 셋이다. 한쪽에만 그 크기의 트리가
있으면 그것을 결과 리스트에 그냥 잇는다. 양쪽에 다 있으면 자리올림이 난다.
양쪽에 다 없으면 아무 일도 없다---이진 덧셈 그대로다.

@<크기 |k|짜리 자리를 처리한다@>=
if m&k == 0 {
	if mm&k != 0 { // |qq|가 합친 리스트에 들어간다
		s.mems++ // |o,p->qsib=qq|
		p.B.A = qq
		p = qq
		mm -= k
		if mm != 0 {
			s.mems++ // |o,qq=qq->qsib|
			qq = qq.B.A
		}
	}
} else if mm&k == 0 { // |q|가 합친 리스트에 들어간다
	s.mems++ // |o,p->qsib=q|
	p.B.A = q
	p = q
	m -= k
	if m != 0 {
		s.mems++ // |o,q=q->qsib|
		q = q.B.A
	}
} else {
	@<|q|와 |qq|를 carry 트리로 합쳐, carry가 안 번질 때까지 잇는다@>
}

@ 두 입력 리스트에 같은 크기 트리가 있으면, 크기 $2k$의 carry 트리로 합친다.
그 carry는 더 큰 크기로 번질 수 있어, 자리가 빌 때까지 이어 합친다.

@<|q|와 |qq|를 carry 트리로 합쳐, carry가 안 번질 때까지 잇는다@>=
var c, r, rr *gbgraph.Arc
var key int64
m -= k
if m != 0 {
	s.mems++; r = q.B.A // |o,r=q->qsib|
}
mm -= k
if mm != 0 {
	s.mems++; rr = qq.B.A // |o,rr=qq->qsib|
}
@<|c|를 |q|와 |qq|의 합으로 놓는다@>
k <<= 1
q = r
qq = rr
for (m|mm)&k != 0 {
	if m&k == 0 {
		@<|qq|를 |c|에 합치고 |qq|를 나아가게 한다@>
	} else {
		@<|q|를 |c|에 합치고 |q|를 나아가게 한다@>
		if mm&k != 0 {
			s.mems++; p.B.A = qq // |o,p->qsib=qq|
			p = qq
			mm -= k
			if mm != 0 {
				s.mems++; qq = qq.B.A // |o,qq=qq->qsib|
			}
		}
	}
	k <<= 1
}
s.mems++; p.B.A = c // |o,p->qsib=c|
p = c
_ = key

@ @<|c|를 |q|와 |qq|의 합으로 놓는다@>=
if s.mems += 2; q.Len < qq.Len { // |oo,q->len<qq->len|
	c, key = q, q.Len
	q = qq
} else {
	c, key = qq, qq.Len
}
if k == 1 {
	s.mems++ // |o,c->qchild=q|
	c.A.A = q
} else {
	s.mems++ // |o,qq=c->qchild|
	qq = c.A.A
	s.mems++ // |o,c->qchild=q|
	c.A.A = q
	if k == 2 {
		s.mems++ // |o,q->qsib=qq|
		q.B.A = qq
	} else {
		s.mems += 2 // |oo,q->qsib=qq->qsib|
		q.B.A = qq.B.A
	}
	s.mems++ // |o,qq->qsib=q|
	qq.B.A = q
}

@ 이때 |k>1|이다.

@<|q|를 |c|에 합치고 |q|를 나아가게 한다@>=
m -= k
if m != 0 {
	s.mems++ // |o,r=q->qsib|
	r = q.B.A
}
s.mems++ // |o,q->len<key|
if q.Len < key {
	rr, c, key, q = c, q, q.Len, c
}
s.mems++ // |o,rr=c->qchild|
rr = c.A.A
s.mems++ // |o,c->qchild=q|
c.A.A = q
if k == 2 {
	s.mems++ // |o,q->qsib=rr|
	q.B.A = rr
} else {
	s.mems += 2 // |oo,q->qsib=rr->qsib|
	q.B.A = rr.B.A
}
s.mems++ // |o,rr->qsib=q|
rr.B.A = q
q = r

@ @<|qq|를 |c|에 합치고 |qq|를 나아가게 한다@>=
mm -= k
if mm != 0 {
	s.mems++ // |o,rr=qq->qsib|
	rr = qq.B.A
}
s.mems++ // |o,qq->len<key|
if qq.Len < key {
	r, c, key, qq = c, qq, qq.Len, c
}
s.mems++ // |o,r=c->qchild|
r = c.A.A
s.mems++ // |o,c->qchild=qq|
c.A.A = qq
if k == 2 {
	s.mems++ // |o,qq->qsib=r|
	qq.B.A = r
} else {
	s.mems += 2 // |oo,qq->qsib=r->qsib|
	qq.B.A = r.B.A
}
s.mems++ // |o,r->qsib=qq|
r.B.A = qq
qq = rr

@ 이제 힘든 일은 다 했으니 |qunite|의 열매를 거둘 차례다. 손쉬운 응용 하나가
|qenque|로, 새 호를 분할 상환 $O(1)$ 시간에 큐에 넣는다. |qmerge|는 한 이항 큐를
다른 이항 큐에 합치는데, 분할 상환 실행 시간이 작은 쪽 큐의 마디 수의 로그에
비례한다. |qdelMin|은 키가 가장 작은 마디를 빼는데, 분할 상환 실행 시간이 큐
크기의 로그에 비례한다.

@<이항 큐@>=
func (s *solver) qenque(h, a *gbgraph.Arc) {
	s.mems++ // |o,m=h->qcount|
	m := h.A.I
	s.mems++ // |o,h->qcount=m+1|
	h.A.I = m + 1
	if m == 0 {
		s.mems++ // |o,h->qsib=a|
		h.B.A = a
	} else {
		s.mems++ // |o,| qunite에 넘길 |h->qsib|
		s.qunite(1, a, m, h.B.A, h)
	}
}

func (s *solver) qmerge(h, hh *gbgraph.Arc) {
	s.mems++ // |o,mm=hh->qcount|
	mm := hh.A.I
	if mm != 0 {
		s.mems++ // |o,m=h->qcount|
		m := h.A.I
		s.mems++ // |o,h->qcount=m+mm|
		h.A.I = m + mm
		if m >= mm {
			s.mems += 2 // |oo|
			s.qunite(mm, hh.B.A, m, h.B.A, h)
		} else if m == 0 {
			s.mems += 2 // |oo,h->qsib=hh->qsib|
			h.B.A = hh.B.A
		} else {
			s.mems += 2 // |oo|
			s.qunite(m, h.B.A, mm, hh.B.A, h)
		}
	}
}

@ 키 최소 마디 빼기다. |m&(m-1)|이 |m|에서 최하위 1비트를 지운 값이라는 잘
알려진 요령을 쓴다.

@<이항 큐@>=
func (s *solver) qdelMin(h *gbgraph.Arc) *gbgraph.Arc {
	s.mems++ // |o,m=h->qcount|
	m := h.A.I
	if m == 0 {
		return nil
	}
	s.mems++ // |o,h->qcount=m-1|
	h.A.I = m - 1
	var q *gbgraph.Arc
	var k int64
	@<키가 가장 작은 뿌리 |q|의 트리를 찾아 뺀다@>
	if k > 2 {
		if k+k <= m {
			s.mems += 2 // |oo|
			s.qunite(k-1, q.A.A.B.A, m-k, h.B.A, h)
		} else {
			s.mems += 2 // |oo|
			s.qunite(m-k, h.B.A, k-1, q.A.A.B.A, h)
		}
	} else if k == 2 {
		s.mems++ // |o|
		s.qunite(1, q.A.A, m-k, h.B.A, h)
	}
	return q
}

@ 키 최소 트리가 숲에서 가장 크면, 알고리즘이 마지막 |qsib|을 보지 않으므로
이음을 바꿀 것이 없다.

@<키가 가장 작은 뿌리 |q|의 트리를 찾아 뺀다@>=
mm := m & (m - 1)
s.mems++ // |o,q=h->qsib|
q = h.B.A
k = m - mm
if mm != 0 { // 트리가 둘 이상이다
	p := q
	qq := h
	s.mems++ // |o,key=q->len|
	key := q.Len
	for {
		t := mm & (mm - 1)
		pp := p
		s.mems++ // |o,p=p->qsib|
		p = p.B.A
		s.mems++ // |o,p->len<=key|
		if p.Len <= key {
			q, qq, k, key = p, pp, mm-t, p.Len
		}
		mm = t
		if mm == 0 {
			break
		}
	}
	if k+k <= m {
		s.mems += 2 // |oo,qq->qsib=q->qsib|
		qq.B.A = q.B.A
	}
}

@ 구현을 마무리하려면, 이항 큐를 훑으며 마디마다 정확히 한 번씩 |visit|을 부르되
지나가면서 큐를 헐어 버리는 알고리즘이 필요하다. 드는 mem의 총수는 약 $1.75m$이다.

@<이항 큐@>=
func (s *solver) qtraverse(h *gbgraph.Arc, visit func(*gbgraph.Arc)) {
	s.mems++ // |o,m=h->qcount|
	m := h.A.I
	p := h
	for m != 0 {
		s.mems++ // |o,p=p->qsib|
		p = p.B.A
		visit(p)
		if m&1 != 0 {
			m--
		} else {
			s.mems++ // |o,q=p->qchild|
			q := p.A.A
			if m&2 != 0 {
				visit(q)
			} else {
				s.mems++ // |o,r=q->qsib|
				r := q.B.A
				if m&(m-1) != 0 {
					s.mems += 2 // |oo,q->qsib=p->qsib|
					q.B.A = p.B.A
				}
				visit(r)
				p = r
			}
			m -= 2
		}
	}
}

@* Cheriton, Tarjan, Karp의 알고리즘.
\def\lsqrtn{\hbox{$\lfloor\sqrt n\rfloor$}}%
\def\usqrtn{\hbox{$\lfloor\sqrt{n+1}+{1\over2}\rfloor$}}%
우리가 살펴볼 마지막 알고리즘은 신장 트리 최소화에 또 다른 길로 다가간다. 이
알고리즘은 뚜렷이 구분되는 두 단계로 움직인다. 단계 1은 최소 트리의 작은 조각들을
만드는데, Kruskal의 방법처럼 간선 전부를 한꺼번에 다루는 대신 각 조각에서 나가는
간선만 지역적으로 다룬다. 조각의 수가 $n$에서 \lsqrtn\ 로 줄어드는 순간 단계 2가
시작된다. 단계 2는 남은 간선들을 훑어 $\lsqrtn\times\lsqrtn$ 행렬을 세우는데, 이
행렬이 남은 \lsqrtn\ 개 조각 위에서 최소 신장 트리를 찾는 문제를 나타낸다. 그러면
간단한 $O(\sqrt n\,)^2=O(n)$ 알고리즘이 일을 마무리한다.

단계 1을 떠받치는 생각은, 작은 성분 안의 정점에서 나가는 간선은 같은 성분이 아니라
다른 성분의 정점으로 이어지기 쉽다는 것이다. 그러니 키 최소 빼기가 저마다 보람
있는 일이 되는 편이다. Karp와 Tarjan은 정점 $n$개, 간선 $m$개인 무작위 그래프에서
@^Karp, Richard Manning@>
@^Tarjan, Robert Endre@>
평균 실행 시간이 $O(m)$임을 증명했다[{\sl Journal of Algorithms\/ \bf 1\/} (1980),
374--393].

단계 2를 떠받치는 생각은, 처음에 성긴 그래프였던 문제가 끝내는 더 작지만 빽빽한
그래프 위의 문제로 줄어들고, 그런 문제는 다른 방법으로 푸는 것이 가장 낫다는
것이다.

@<Cheriton/Tarjan/Karp 알고리즘@>=
func (s *solver) cherTarKar() int64 {
	s.mems = 0
	var totLen int64
	headers := make([]gbgraph.Arc, s.g.N)
	for i := int64(0); i < s.g.N; i++ {
		s.g.Vertices[i].U.A = &headers[i] // |pq| 머리 (mem 없음)
	}
	@<CTK 단계 1@>
	if s.verbose {
		fmt.Fprintf(s.out, "    [Stage 1 has used %d mems]\n", s.mems)
	}
	@<CTK 단계 2@>
	return totLen
}

@ 조각에 정점이 \usqrtn\ 개 이상 있으면 {\sl 크다\/}고 한다. 조각이 커지는 순간
단계 1은 그것을 더 늘리려 하지 않는다. 큰 조각은 \lsqrtn\ 개를 넘을 수 없는데,
$(\lsqrtn+1)\cdot\usqrtn>n$이기 때문이다. 나머지 조각은 {\sl 작다\/}고 한다.

단계 1은 작은 조각을 모두 담은 리스트를 지닌다. 처음에 이 리스트에는 정점 하나씩
으로 된 조각이 $n$개 들어 있다. 알고리즘은 리스트의 첫 조각을 거듭 들여다보며,
다른 조각으로 가는 가장 짧은 간선을 찾는다. 그 두 조각을 리스트에서 빼고 하나로
합친다. 그렇게 나온 조각은 아직 작으면 리스트 끝에 놓이고, 커졌으면 다른
리스트로 옮겨진다.

@ 조각을 나타내는 데는 앞서 정의한 유틸리티 필드 여럿을 다시 쓴다. |lsib|(|V.V|)과
|rsib|(|W.V|) 포인터는 작은 리스트의 조각들 사이에 쓰이며 이 리스트는 두 겹으로
이어진다. |sm|이 첫 작은 조각을, |sm.rsib|이 그다음을 \dots\ 가리키고, |tl.lsib|이
끝에서 둘째를, |tl|이 마지막을 가리킨다. |sm.lsib|과 |tl.rsib|은 뜻이 없다.
|largeList|는 |rsib| 포인터로 한 겹으로 이어지며 |nil|로 끝난다.

각 조각의 |csize|(|X.I|) 필드는 그 조각에 정점이 몇인지 알려 준다.

각 정점의 |comp|(|Y.V|) 필드는 그 정점이 조각을 대표하면(곧 작은 리스트나
|largeList|에 있으면) |nil|이고, 그렇지 않으면 조각 대표에 더 가까운 다른 정점을
가리킨다.

끝으로 각 조각의 |pq| 포인터는 그 조각의 우선순위 큐의 머리 마디를 가리킨다. 이
큐는 그 조각의 정점들에서 나가는, 아직 들여다보지 않은 호를 모두 담은 이항 큐다.
실전 구현이라면 |pq|가 따로 필드일 필요가 없고 정점 레코드의 일부였을 테니, 그것을
참조하는 데 mem을 물리지 않는다.
@^\\{mems} 이야기@>

@ \lsqrtn\ 과 \usqrtn\ 을 셈하는 뻔하지 않은 방법이 있다. $\sqrt n$은 작고 산술은
mem이 들지 않으므로, 저자는 아래처럼 |for| 고리를 쓰고 싶은 마음을 참지 못했다.
물론 이런 계산이 실행 시간에 중요한 요소였다면 mem을 세는 기준이 달랐을 것이다.
@^\\{mems} 이야기@>

@<CTK 단계 1@>=
s.mems++ // |o,frags=g->n|
frags := s.g.N
var hiSqrt int64
for hiSqrt = 1; hiSqrt*(hiSqrt+1) <= frags; hiSqrt++ {
}
loSqrt := hiSqrt
if hiSqrt*hiSqrt > frags {
	loSqrt = hiSqrt - 1
}
var largeList *gbgraph.Vertex
@<작은 리스트를 만든다@>
for frags > loSqrt {
	@<작은 리스트 맨 앞 조각을 가장 가까운 이웃과 합친다@>
	frags--
}

@ @<작은 리스트를 만든다@>=
s.mems++ // |o,s=g->vertices|
sm := &s.g.Vertices[0]
for i := int64(0); i < frags; i++ {
	v := &s.g.Vertices[i]
	if i > 0 {
		s.mems++ // |o,v->lsib=v-1|
		v.V.V = &s.g.Vertices[i-1]
		s.mems++ // |o,(v-1)->rsib=v|
		s.g.Vertices[i-1].W.V = v
	}
	s.mems++ // |o,v->comp=NULL|
	v.Y.V = nil
	s.mems++ // |o,v->csize=1|
	v.X.I = 1
	s.mems++ // |o,v->pq->qcount=0|
	v.U.A.A.I = 0
	s.mems++ // |o,a=v->arcs|
	for a := v.Arcs; a != nil; {
		s.qenque(v.U.A, a)
		s.mems++ // |o,a=a->next|
		a = a.Next
	}
}
tl := &s.g.Vertices[frags-1]

@ 맨 앞 조각 |v|를 작은 리스트에서 빼고, 그 큐에서 다른 조각으로 가는 가장 짧은
간선을 찾을 때까지 |qdelMin|을 거듭한다. 그 두 조각을 합쳐 |u|로 만든다.

@<작은 리스트 맨 앞 조각을 가장 가까운 이웃과 합친다@>=
v := sm
s.mems++ // |o,s=s->rsib|
sm = sm.W.V
var a *gbgraph.Arc
var u *gbgraph.Vertex
for {
	a = s.qdelMin(v.U.A)
	if a == nil {
		return infinity // 그래프가 이어져 있지 않다
	}
	s.mems++; u = a.Tip // |o,u=a->tip|
	for {
		s.mems++ // |o,u->comp|
		if u.Y.V == nil {
			break
		}
		u = u.Y.V
	}
	if u != v {
		break
	}
}
if s.verbose {
	s.report(a.Partner.Tip, a.Tip, a.Len)
}
s.mems++; totLen += a.Len // |o,tot_len+=a->len|
s.mems++; v.Y.V = u // |o,v->comp=u|
s.qmerge(u.U.A, v.U.A)
s.mems++; oldSize := u.X.I // |o,old_size=u->csize|
s.mems++; newSize := oldSize + v.X.I // |o,new_size=old_size+v->csize|
s.mems++; u.X.I = newSize // |o,u->csize=new_size|
sm, tl, largeList = s.moveU(u, v, sm, tl, largeList, oldSize, newSize, hiSqrt)

@ 작은 조각 |v|를 |u|에 합친 뒤 |u|의 자리를 옮긴다. 여러 특별한 경우를 mem을
아끼며 가른다. \CEE/의 |goto fin|은 이른 반환으로 푼다.

@<Cheriton/Tarjan/Karp 알고리즘@>=
func (s *solver) moveU(u, v, first, last, largeList *gbgraph.Vertex,
	oldSize, newSize, hiSqrt int64) (nf, nl, nll *gbgraph.Vertex) {
	nf, nl, nll = first, last, largeList
	if oldSize >= hiSqrt { // |u|는 이미 컸다
		if last == v {
			nf = nil // 작은 리스트가 방금 비었다
		}
		return
	}
	if newSize < hiSqrt { // |u|는 여전히 작다
		@<|u|를 작은 리스트의 끝으로 옮긴다@>
	}
	@<|u|를 작은 리스트에서 떼어 큰 리스트에 붙인다@>
}

@ |u|가 여전히 작으면 작은 리스트의 맨 끝으로 옮긴다.

@<|u|를 작은 리스트의 끝으로 옮긴다@>=
if u == last {
	return // 이미 우리가 바라는 자리다
}
if u == first {
	s.mems++; nf = u.W.V // |o,s=u->rsib|
} else {
	s.mems += 3; u.W.V.V.V = u.V.V // |ooo,u->rsib->lsib=u->lsib|
	s.mems++; u.V.V.W.V = u.W.V // |o,u->lsib->rsib=u->rsib|
}
s.mems++; last.W.V = u // |o,t->rsib=u|
s.mems++; u.V.V = last // |o,u->lsib=t|
nl = u
return

@ |u|가 방금 커졌으면 작은 리스트에서 떼어 큰 리스트 앞에 붙인다.

@<|u|를 작은 리스트에서 떼어 큰 리스트에 붙인다@>=
if u == last {
	if u == first {
		return
	}
	s.mems++; nl = u.V.V // |o,t=u->lsib|
} else if u == first {
	s.mems++; nf = u.W.V // |o,s=u->rsib|
} else {
	s.mems += 3 // |ooo|
	u.W.V.V.V = u.V.V
	s.mems++ // |o|
	u.V.V.W.V = u.W.V
}
s.mems++; u.W.V = largeList // |o,u->rsib=large_list|
nll = u
return

@ 이제 알고리즘의 둘째 부분이다. 여기서는 $\lsqrtn\times\lsqrtn$ 짜리 간선 길이
행렬을 놓을 자리가 있어야 한다. |cherTarKar|가 여태 |z| 유틸리티 필드를 쓴 적이
없으므로, 정점 레코드의 그 필드에 임의 접근해 쓰기로 한다. |v| 유틸리티 필드도
가장 짧은 길이를 낸 호를 적어 두는 데 쓸 수 있는데, 그것이 이제 필요 없어진
|lsib| 필드였기 때문이다. 그 필드를 갱신하는 데는 mem을 세지 않는다. 이 프로그램은
제 목표를 그저 최소 신장 트리의 {\sl 길이\/}를 셈하는 것으로 보고, 실제 간선은
|verbose| 모드에서만 셈하기 때문이다. (|cherTarKar|를 할 수 있는 한 날씬하게
만들었을 때 얼마나 겨룰 만한지 보고 싶은 것이다.)
@^\\{mems} 이야기@>

단계 2에서 정점들은 $0$부터 $\lsqrtn-1$ 사이의 번호를 받는다. 이 번호는 이제 필요
없어진 |csize| 필드에 넣고 |findex|라 부른다. 행렬 |matx(j,k)|는
|g.Vertices[j*loSqrt+k].Z.I|에, 그에 대응하는 호는 |.V.A|에 둔다. |INF=30000|은
모든 간선 길이의 상한이다.

@<CTK 단계 2@>=
const inf = 30000 // 모든 간선 길이의 상한
var distance [100]int64
var distArc [100]*gbgraph.Arc
var kk int64
matx := func(j, k int64) *int64 { return &s.g.Vertices[j*loSqrt+k].Z.I }
@<정점들을 번호로 옮긴다@>
@<남은 간선으로 축소 행렬을 만든다@>
@<축소 행렬에 Prim의 알고리즘을 돌린다@>

@ |comp|이 |nil|이 아닌 정점마다, 그 조각 대표의 |findex|를 따라 자기 |findex|를
채운다. 채운 뒤 |comp|을 |nil|로 두어 표시한다.

@<정점들을 번호로 옮긴다@>=
if sm == nil {
	sm = largeList
} else {
	s.mems++ // |o,t->rsib=large_list|
	tl.W.V = largeList
}
k := int64(0)
for v := sm; v != nil; k++ {
	s.mems++ // |o,v->findex=k|
	v.X.I = k
	s.mems++ // 반복마다 |o,v=v->rsib|
	v = v.W.V
}

@ 이제 나머지 정점들에도 자기 조각의 번호를 퍼뜨린다. \CEE/의
|for(t=v;o,u=t->comp;t=u)|는 대표에 이르면 몸통 실행 전에 빠져나가므로,
|nxt==nil| 검사를 |comp=NULL|·|findex| 대입보다 앞에 둔다.

@<정점들을 번호로 옮긴다@>=
for i := int64(0); i < s.g.N; i++ {
	v := &s.g.Vertices[i]
	s.mems++ // |o,v->comp|
	if v.Y.V != nil {
		tmp := v.Y.V
		for {
			s.mems++ // |o,t->comp|
			if tmp.Y.V == nil {
				break
			}
			tmp = tmp.Y.V
		}
		s.mems++ // |o,k=t->findex|
		kv := tmp.X.I
		for t := v; ; {
			s.mems++ // |o,u=t->comp|
			nxt := t.Y.V
			if nxt == nil {
				break // 대표는 처리하지 않는다
			}
			s.mems++ // |o,t->comp=NULL|
			t.Y.V = nil
			s.mems++ // |o,t->findex=k|
			t.X.I = kv
			t = nxt
		}
	}
}

@ |note_edge|는 |qtraverse|가 훑는 이항 큐의 간선마다 불린다. |kk|는 이 호가
나가는 조각의 번호다.

@<남은 간선으로 축소 행렬을 만든다@>=
noteEdge := func(a *gbgraph.Arc) {
	s.mems += 2 // |oo,k=a->tip->findex|
	k := a.Tip.X.I
	if k == kk {
		return
	}
	s.mems += 2 // |oo,a->len<matx(kk,k)|
	if a.Len < *matx(kk, k) {
		s.mems++ // |o,matx(kk,k)=a->len|
		*matx(kk, k) = a.Len
		s.mems++ // |o,matx(k,kk)=a->len|
		*matx(k, kk) = a.Len
		s.g.Vertices[kk*loSqrt+k].V.A = a // 대응 호 (mem 없음)
		s.g.Vertices[k*loSqrt+kk].V.A = a
	}
}
for j := int64(0); j < loSqrt; j++ {
	for k := int64(0); k < loSqrt; k++ {
		s.mems++ // |o,matx(j,k)=INF|
		*matx(j, k) = inf
	}
}
for kk = 0; sm != nil; kk++ {
	s.qtraverse(sm.U.A, noteEdge)
	s.mems++ // 반복마다 |o,s=s->rsib|
	sm = sm.W.V
}

@ 크기 $\lsqrtn\times\lsqrtn$짜리 마지막 부분문제를 풀 때는, 아직 조각 $0$과
이어지지 않은 조각마다 그 거리를 알려 주는 짧은 벡터를 지닌다. 이미 이어진 자리에는
$-1$을 둔다. 실전 판이라면 이것을 |matx|의 $0$번 행에 넣어 둘 수 있을 것이다.

Prim이 제안한 마지막 걸음은, 행렬의 각 행을 만날 때마다 그 행에 대해 거리 표를
@^Prim, Robert Clay@>
거듭 갱신하는 것이다. 이것이 완전 그래프의 최소 신장 트리를 찾는 데 고를 만한
알고리즘이다.

@<축소 행렬에 Prim의 알고리즘을 돌린다@>=
s.mems++ // |o,distance[0]=-1|
distance[0] = -1
d := int64(inf)
j := int64(0)
for k := int64(1); k < loSqrt; k++ {
	s.mems++ // |o,distance[k]=matx(0,k)|
	distance[k] = *matx(0, k)
	distArc[k] = s.g.Vertices[k].V.A // 대응 호 (mem 없음)
	if distance[k] < d {
		d, j = distance[k], k
	}
}
for frags > 1 {
	@<조각 0을 조각 |j|와 잇고, 다음 판의 |j|와 |d|를 셈한다@>
	frags--
}

@ @<조각 0을 조각 |j|와 잇고, 다음 판의 |j|와 |d|를 셈한다@>=
if d == inf {
	return infinity // 그래프가 이어져 있지 않다
}
s.mems++ // |o,distance[j]=-1|
distance[j] = -1
totLen += d
if s.verbose {
	s.report(distArc[j].Partner.Tip, distArc[j].Tip, distArc[j].Len)
}
d = inf
for k := int64(1); k < loSqrt; k++ {
	s.mems++ // |o,distance[k]>=0|
	if distance[k] >= 0 {
		s.mems++ // |o,matx(j,k)<distance[k]|
		if *matx(j, k) < distance[k] {
			s.mems++ // |o,distance[k]=matx(j,k)|
			distance[k] = *matx(j, k)
			distArc[k] = s.g.Vertices[j*loSqrt+k].V.A // (mem 없음)
		}
		if distance[k] < d {
			d, kk = distance[k], k
		}
	}
}
j = kk

@* 결론. 여기서 살펴본 네 방법 가운데, 여기서 다룬 크기의 문제에서, mem 세기로
따진 우승자는 뚜렷하게 이진 힙을 쓴 Jarn\'\i k/Prim이다. 둘째는 성긴 그래프에서는
기수 정렬을 쓴 Kruskal인데, 빽빽한 그래프에서는 피보나치 힙 방식이 그것을 이긴다.
|cherTarKar| 프로시저는 근처에도 못 간다. 그것이 밟는 걸음 하나하나가 그럴듯하고
효율적으로 보이는데도, 그리고 위 구현이 mem을 셀 때 그것에게 온갖 이로운 해석을
베풀었는데도 그렇다. 지는 까닭은 아무래도 간선 하나를 두 번씩 다루느라 인수 2를
거의 그대로 내주기 때문인 듯하다. 다른 방법들은 짝이 이미 처리된 호를 버리는 데
품을 거의 들이지 않는다.

@ 그러나 mem 세기가 이야기의 전부가 아니라는 것을 아는 것이 중요하다. 파이프라인,
캐시, 컴파일러 최적화의 온갖 복잡함까지 고려한 참 실행 시간을 재려고 Sun
SPARCstation~2에서 시험을 더 해 보았다. 그 결과 적어도 그 시스템에서는 사실
@^\\{mems} 이야기@>
Kruskal의 알고리즘이 가장 좋았다.
$$\vbox{\halign{#\hfil&&\quad\hfil#\cr
\hfill 최적화 수준&\.{-g}\hfil&\.{-O2}\hfil&\.{-O3}\hfil&mem\hfil\cr
\noalign{\vskip2pt}
Kruskal/기수 정렬&132&111&111&8379\cr
Jarn\'\i k/Prim/이진&307&226&212&7972\cr
Jarn\'\i k/Prim/피보나치&432&350&333&11736\cr
Cheriton/Tarjan/Karp&686&509&492&17770\cr}}$$
(시간은 기본 그래프 |miles(100,0,0,0,0,10,0)|으로 10만 번 돌렸을 때의 초 단위다.
최적화 수준 \.{-O4}는 \.{-O3}과 같은 결과를 냈다. 최적화는 mem 수를 바꾸지
않는다.) 그러니 Kruskal 절차는 최적화 없이 mem당 약 160나노초를, 최적화하면 약
130나노초를 썼고, 나머지는 최적화 없이 약 380--400ns/mem을, 최적화하면
270--300ns/mem을 썼다. mem이라는 잣대는 ``세련된'' 자료 구조 셋에 대해서는 일관된
값을 주었지만, ``순박한'' Kruskal 방법이 하드웨어와 더 잘 어울렸다.

@ \.{-d100} 옵션으로 얻는 완전 그래프 |miles(100,0,0,0,0,99,0)|은 사뭇 다른
통계를 냈다.
$$\vbox{\halign{#\hfil&&\quad\hfil#\cr
\hfill 최적화 수준&\.{-g}\hfil&\.{-O2}\hfil&\.{-O3}\hfil&mem\hfil\cr
\noalign{\vskip2pt}
Kruskal/기수 정렬&1846&1787&1810&63795\cr
Jarn\'\i k/Prim/이진&2246&1958&1845&50594\cr
Jarn\'\i k/Prim/피보나치&2675&2377&2248&59050\cr
Cheriton/Tarjan/Karp&8881&6964&6909&175519\cr}}$$
이번에는 똑같은 기계 명령어가 mem당 눈에 띄게 더 오래 걸렸다. 아마도 캐시 실패
때문이겠지만 조건 분기 명령어의 잦기도 한몫했을 수 있다. 이 현상을 꼼꼼히
분석해 보면 배울 것이 있을 것이다. 앞으로의 컴퓨터는 메모리 속도에 더 가깝게
매일 것으로 보이므로, mem당 실행 시간은 방법들 사이에서 더 고르게 되어 갈 듯하다.
다만 캐시 성능은 아마 늘 한 요인으로 남을 것이다.

|krusk| 프로시저는 날씬하게 다듬은 합집합/찾기 알고리즘을 주면 더 빨라질지도
모른다. 아니면 그런 ``날씬하게 하기''가 지금 누리는 효율의 일부를 도리어 깎아
먹을까?

@ 한 가지 덧붙이자. 위 표의 시간은 1993년 무렵 SPARCstation~2에서 \CEE/ 판을
잰 것이라 오늘날의 기계에는 그대로 들어맞지 않는다. 그러나 {\sl mem 수는
그렇지 않다.\/} mem은 기계와도 컴파일러와도 무관하게 정의되므로, 우리 \GO/ 판이
같은 자리에 같은 수의 mem을 물리는 한 위 네 mem 열은 지금도 그대로 재현된다.
바로 그것이 Knuth가 mem을 세자고 한 까닭이다.

@* 찾아보기.
