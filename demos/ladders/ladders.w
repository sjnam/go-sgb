% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 ladders.w를 Go로 이식한다.
@i ../../gbtypes.w

\input kotexgweb
\def\title{LADDERS}

@* 들어가며. 이 시연 프로그램은 {\sc GB\_WORDS} 모듈이 지은 그래프를 써서
{\sc LADDERS}라는 대화형 프로그램을 만든다. 영어 다섯 글자 낱말 둘을 주면 그
사이의 최단 경로를 찾아 준다. 이는 Lewis Carroll이 1877년 크리스마스에
두 어린 친구를 위해 고안한 놀이 ``doublets''를, 컴퓨터가 대신 풀어 주는
셈이다. 한 낱말에서 한 번에 한 글자씩만 바꾸어 다른 낱말로 건너가되, 거치는
낱말이 모두 진짜 영어 낱말이라야 한다. Carroll의 이름난 예로 |"head"|를
|"tail"|로, 또는 |"four"|를 |"five"|로 바꾸는 사다리가 있다.

프로그램은 명령줄에서 `\.{ladders} 〈옵션〉'으로 부르며, 옵션은 아무 차례로나
다음을 섞어 쓸 수 있다.

$$\vbox{\halign{\indent\.{#}\hfil&\quad#\hfil\cr
-v&최단 경로 셈 중에 만난 낱말을 목적지로부터의 거리와 함께 낱낱이 찍는다\cr
-a&이웃한 낱말 사이를 1이 아니라 알파벳 거리로 잰다\cr
-f&빈도에 바탕한 거리를 쓴다(\.{-a}나 \.{-r}이 있으면 무시)\cr
-h&탐색을 좁히는 하한 어림 함수를 쓴다(\.{-f}가 있으면 무시)\cr
-e&입력을 출력에 되울린다(입력이 파일일 때 쓸모 있다)\cr
-nN&그래프를 가장 흔한 N개 낱말로 제한한다\cr
-rN&그래프를 무작위로 고른 N개 낱말로 제한한다(\.{-n}과 함께 못 씀)\cr
-sN&난수 씨앗으로 0 대신 N을 쓴다\cr
-dDIR&\.{words.dat}가 있는 디렉터리(기본 \.{data})\cr}}$$

\noindent
\.{-f} 옵션은 가장 흔한 낱말에 값 0을, 가장 드문 낱말에 값 16을 매겨, 가장
``친근한'' 사다리를 낳는 경향이 있다. \.{-h} 옵션은 목적지에 가까운 낱말에
우선권을 주어 탐색을 목적지 쪽으로 몬다---바로 A* 탐색이며, \.{-v}와 함께
보면 가장 흥미롭다.

@ 시작 낱말과 목적 낱말을 차례로 묻는다. 시작 낱말 물음에 그냥 엔터를 치면
프로그램이 끝나고, 목적 낱말 물음에 그냥 엔터를 치면 시작 낱말을 다시 묻는다.
두 낱말은 프로그램이 아는 낱말이 아니어도 된다---임시로 그래프에 더했다가,
새 낱말을 받을 때마다 도로 뺀다. 그래서 |"sturm"|에서 |"drang"|으로도 갈 수
있다, 비록 그 둘이 영어가 아닐지라도.

@c
package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	@#
	"github.com/sjnam/go-sgb/gbdijk"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbwords"
)

@<거리 보조 함수@>
@<빈도 비용 함수@>
@<사다리 찾개 |ladders|@>
@<끝말을 다섯 자로 받는다@>

func main() {
	@<명령줄 옵션을 읽는다@>
	@<낱말 그래프를 짓는다@>
	@<차례로 사다리를 찾는다@>
}

@* 옵션 훑기. \UNIX/ 명령줄 잡동사니부터 치워, 알맹이에 집중하자. 우리 일은
전역 |verbose|의 기본값 0을 바꿀지, 그리고 아래 내부 변수들의 기본값을 바꿀지
살피는 것이다. \CEE/ 원본은 |sscanf|로 |-nN| 꼴을 읽었으므로, 우리도 접두어를
떼어 수를 파싱한다. |usage|와 |num|은 잘못된 인자를 만나면 쓰임새를 알리고
빠져나가는 작은 닫힘함수다.

@<명령줄 옵션을 읽는다@>=
var (
	verbose, alph, freq, heur, echo, randm bool
	n, seed                                int64
	dir                                    = "data"
)
usage := func() {
	fmt.Fprintf(os.Stderr,
		"Usage: %s [-v][-a][-f][-h][-e][-nN][-rN][-sN][-dDIR]\n", os.Args[0])
	os.Exit(2)
}
num := func(s string) int64 {
	v, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		usage()
	}
	return v
}
@<인자를 하나씩 훑는다@>
if alph || randm {
	freq = false
}
if freq {
	heur = false
}

@ @<인자를 하나씩 훑는다@>=
for _, arg := range os.Args[1:] {
	switch {
	case arg == "-v":
		verbose = true
	case arg == "-a":
		alph = true
	case arg == "-f":
		freq = true
	case arg == "-h":
		heur = true
	case arg == "-e":
		echo = true
	case strings.HasPrefix(arg, "-n"):
		n, randm = num(arg[2:]), false
	case strings.HasPrefix(arg, "-r"):
		n, randm = num(arg[2:]), true
	case strings.HasPrefix(arg, "-s"):
		seed = num(arg[2:])
	case strings.HasPrefix(arg, "-d"):
		dir = arg[2:]
	default:
		usage()
	}
}

@* 그래프 만들기. {\sc GB\_WORDS}의 |Words|가 우리가 바라는 다섯 글자 낱말들을
그래프 꼴로 지어 준다. |randm|이면 빈도를 모두 무시하도록 아홉 개의 0으로 된
무게 벡터를 넘긴다.

@<낱말 그래프를 짓는다@>=
var wt []int64
if randm {
	wt = make([]int64, 9) // 빈도를 무시하는 무게 벡터
}
g, err := gbwords.Words(n, wt, 0, seed, dir)
if err != nil {
	fmt.Fprintf(os.Stderr, "Sorry, I couldn't build a dictionary (trouble code %v)!\n", err)
	os.Exit(1)
}
@<고른 옵션을 확인해 준다@>
@<|alph|이나 |freq|이면 간선 길이를 고친다@>
@<우선순위 큐를 고른다@>

@ 실제 낱말 수는 사전 크기만큼 줄어들 수 있으므로, 그래프를 지은 뒤에야
사용자가 고른 옵션을 확인해 준다.

@<고른 옵션을 확인해 준다@>=
if verbose {
	if alph {
		fmt.Println("(alphabetic distance selected)")
	}
	if freq {
		fmt.Println("(frequency-based distances selected)")
	}
	if heur {
		fmt.Println("(lowerbound heuristic will be used to focus the search)")
	}
	if randm {
		fmt.Printf("(random selection of %d words with seed %d)\n", g.N, seed)
	} else {
		fmt.Printf("(the graph has %d words)\n", g.N)
	}
}

@ |Words| 그래프의 간선은 원래 길이가 1이므로, 사용자가 |alph|이나 |freq|을
골랐으면 고쳐야 한다. 이웃한 두 낱말이 다른 글자 자리는 각 호의 |A.I| 필드에
적혀 있고(|loc|), 낱말의 빈도는 정점의 |U.I| 필드에 있다(|weight|). |alph|일
때는 그 한 자리의 알파벳 차이가 곧 간선 길이다.

@<|alph|이나 |freq|이면 간선 길이를 고친다@>=
if alph {
	for u := range g.AllVertices() {
		for a := range u.AllArcs() {
			a.Len = aDist(u.Name, a.Tip.Name, int(a.A.I))
		}
	}
} else if freq {
	for u := range g.AllVertices() {
		for a := range u.AllArcs() {
			a.Len = freqCost(a.Tip)
		}
	}
}

@ |Dijkstra|의 기본 큐는 모든 간선 길이가 1일 때 아주 효율적이다. 그렇지
않으면 길이가 128보다 작을 때 가장 좋은 128열 큐로 바꾼다. |alph|·|freq|·|heur|
어느 것이든 켜지면 길이가 1이 아닐 수 있으므로 128열 큐를 쓴다.

@<우선순위 큐를 고른다@>=
var pq gbdijk.PriorityQueue
if alph || freq || heur {
	pq = gbdijk.NewList128()
} else {
	pq = gbdijk.NewDList()
}

@ 빈도는 {\sc GB\_WORDS} 문서가 설명한 기본 무게로 셈해 두었고, 대개 $2^{16}$
보다 작다. 빈도가 0인 낱말은 값 16, 1인 낱말은 15, 2나 3인 낱말은 14, 이렇게
빈도가 두 배가 될 때마다 값이 1씩 줄어 0에 이른다.

@<빈도 비용 함수@>=
func freqCost(v *gbgraph.Vertex) int64 {
	acc := v.U.I // 빈도(오른쪽으로 밀어 갈 값)
	k := int64(16)
	for acc != 0 {
		k--
		acc >>= 1
	}
	if k < 0 {
		return 0
	}
	return k
}

@* 최소 사다리. 이 프로그램의 알맹이는 두 낱말 |start|와 |goal| 사이의 최단
경로를 셈하는 일이다. |Dijkstra|가 그 일을 해내지만, 한 가지 성가신 점은
|start|와 |goal|이 그래프에 없을 수도 있다는 것이다. 그럴 때 우리는 그들을
임시로 끼워 넣는다.

{\sc GB\_GRAPH}의 관례 덕분에, 정점을 |g|에서 빌려 온 새 그래프 |gg|를 지어
그 증폭(amplification)을 할 수 있다. |g|는 정점 두 개(실은 네 개)를 더 둘
자리가 있고, |gg|에 새로 생긴 호를 위한 저장 공간은 나중에 가비지 컬렉터가
치운다. |ladders| 구조체는 그래프와 옵션들을 한데 묶어, 대화의 매 판마다 쓴다.

@<사다리 찾개 |ladders|@>=
type ladders struct {
	g       *gbgraph.Graph
	alph    bool
	freq    bool
	heur    bool
	verbose bool
	pq      gbdijk.PriorityQueue
	out     io.Writer
}

@ |start|에서 |goal|까지 최단 사다리를 찾아 찍는다. 증폭 그래프 |gg|를 짓고,
|Dijkstra|에게 궂은일을 맡기고, 답을 찍고, |gg|의 흔적을 지워 |g|를 원래대로
돌려놓는다.

@<|start|에서 |goal|까지 최단 사다리를 찾아 찍는다@>=
gg := gbgraph.NewGraph(0)
gg.Vertices = l.g.Vertices // |g|의 정점을 빌린다
gg.N = l.g.N
@<새 간선을 심는 |plant|을 마련한다@>
@<|start|와 |goal|을 |gg|에 끼워 넣는다@>
@<둘 다 새 낱말이고 서로 이웃이면 잇는다@>
@<|Dijkstra|에게 궂은일을 맡기고 답을 찍는다@>
@<|gg|의 흔적을 모두 지운다@>

@ |FindWord|는 |g|에 없는 낱말이면 |nil|을 돌려주는데, 그 전에 두 번째 인자를
이웃한 낱말마다 부른다. |plant|이 바로 그 인자로, 갓 끼운 정점에서 이웃으로
간선을 심는다. 새 정점은 늘 |gg.Vertices[gg.N]|, 곧 지금 끼우는 중인 여분
슬롯이다. 간선의 길이는 |alph|이면 알파벳 거리, |freq|이면 앞쪽은 빈도 비용
뒤쪽은 20, 그 밖에는 1이다. \CEE/의 |edge_trick| 포인터 산술 대신 |Partner|가
짝을 또렷이 가리킨다.

@<새 간선을 심는 |plant|을 마련한다@>=
plant := func(v *gbgraph.Vertex) {
	u := &gg.Vertices[gg.N] // 새 간선은 |u|에서 |v|로 간다
	gg.NewEdge(u, v, 1)
	if l.alph {
		d := alphDist(u.Name, v.Name)
		u.Arcs.Len, u.Arcs.Partner.Len = d, d
	} else if l.freq {
		u.Arcs.Len = freqCost(v)     // |u|에서 |v|로 가는 호
		u.Arcs.Partner.Len = 20      // |v|에서 |u|로 가는 호
	}
}

@ 시작 낱말을 여분 슬롯에 임시로 두고 |FindWord|로 찾는다. 그래프에 있으면
|uu|가 그 정점을, 없으면 갓 끼운 새 정점을 가리킨다. 목적 낱말도 마찬가지로
하되, 두 낱말이 같으면 두 번 끼우지 않는다.

@<|start|와 |goal|을 |gg|에 끼워 넣는다@>=
gg.Vertices[gg.N].Name = start
uu := gbwords.FindWord(l.g, start, plant)
if uu == nil {
	uu = &gg.Vertices[gg.N]
	gg.N++ // 새 정점을 인정한다
}
var vv *gbgraph.Vertex
if start == goal {
	vv = uu // 같은 낱말을 두 번 끼우지 않는다
} else {
	gg.Vertices[gg.N].Name = goal
	vv = gbwords.FindWord(l.g, goal, plant)
	if vv == nil {
		vv = &gg.Vertices[gg.N]
		gg.N++
	}
}

@ 위 논리에는 사용자가 얄궂게 굴 때에만 드러나는 창피한 허점이 있다.
|FindWord|는 |g|의 낱말만 알아서, |start|와 |goal|이 그래프에 없으면서 서로
이웃일 때 그 둘을 직접 잇지 못한다. 그러면 컴퓨터가 멍청해 보이니 고쳐 두는
게 낫다. 두 낱말의 해밍 거리가 1이면(즉 정확히 한 자리만 다르면) 손수 잇는다.

@<둘 다 새 낱말이고 서로 이웃이면 잇는다@>=
if gg.N == l.g.N+2 && hammDist(start, goal) == 1 {
	gg.N-- // |vv|를 아직 안 끼운 척한다
	plant(uu) // |vv|를 |uu|에 이웃하게 한다
	gg.N++ // 다시 인정한다
}

@ 이제 |Dijkstra|가 일할 그래프가 갖춰졌다. |heur|이면 어림 함수를 건네는데,
|alph|이면 알파벳 거리 어림을, 아니면 해밍 거리 어림을 쓴다. 둘 다 목적
낱말까지의 참거리 하한이므로 조건 $|len| \ge |hh|(u)-|hh|(v)$를 지킨다.
|verbose|이면 발자취를 |l.out|에 남긴다.

@<|Dijkstra|에게 궂은일을 맡기고 답을 찍는다@>=
var hh func(*gbgraph.Vertex) int64
if l.heur {
	if l.alph {
		hh = func(v *gbgraph.Vertex) int64 { return alphDist(v.Name, goal) }
	} else {
		hh = func(v *gbgraph.Vertex) int64 { return hammDist(v.Name, goal) }
	}
}
var trace io.Writer
if l.verbose {
	trace = l.out
}
if gbdijk.Dijkstra(uu, vv, gg, hh, l.pq, trace) < 0 {
	fmt.Fprintf(l.out, "Sorry, there's no ladder from %s to %s.\n", start, goal)
} else {
	gbdijk.PrintResult(vv, l.out)
}

@ 마지막으로 자취를 치운다. 새 정점에서 옛 정점으로 간 호는 쉽게 지운다. 옛
정점에서 새 정점으로 간 호는 조금 까다롭다---간선의 두 호는 짝지어 다니고,
심을 때 짝을 옛 정점의 호 리스트 맨 앞에 밀어 넣었으므로, 새 정점을 나중에
심은 차례의 역순으로 훑으며 맨 앞을 하나씩 떼어내면 된다. 가비지 컬렉터가
|gg|의 호 저장 공간을 치우므로 |gb_recycle|은 필요 없다.

@<|gg|의 흔적을 모두 지운다@>=
for i := gg.N - 1; i >= l.g.N; i-- {
	u := &gg.Vertices[i]
	for a := u.Arcs; a != nil; a = a.Next {
		a.Tip.Arcs = a.Tip.Arcs.Next // 짝을 맨 앞에서 떼어낸다
	}
	u.Arcs = nil
}

@ |aDist|는 두 낱말의 한 자리 |k|에서의 알파벳 거리를, |alphDist|는 다섯
자리를 통틀어 이웃이든 아니든 알파벳 거리를 잰다. |hammDist|는 두 낱말이 다른
글자 자리의 수(해밍 거리)다.

@<거리 보조 함수@>=
func aDist(p, q string, k int) int64 {
	if p[k] < q[k] {
		return int64(q[k] - p[k])
	}
	return int64(p[k] - q[k])
}

func alphDist(p, q string) int64 {
	var d int64
	for k := 0; k < 5; k++ {
		d += aDist(p, q, k)
	}
	return d
}

func hammDist(p, q string) int64 {
	var d int64
	for k := 0; k < 5; k++ {
		if p[k] != q[k] {
			d++
		}
	}
	return d
}

@* 끝말 대화. 재미난 일은 다 끝냈다. 이제 남은 건 사용자와의 대화뿐이다.
매 판마다 빈 줄을 하나 찍어 눈에 쉼표를 주고, 시작 낱말과 목적 낱말을 받아
사다리를 찾는다. 시작 낱말이 없으면 프로그램을 마치고, 목적 낱말이 없으면
시작 낱말부터 다시 받는다(\CEE/의 |goto restart|를 안쪽 고리로 풀었다).

@<차례로 사다리를 찾는다@>=
l := &ladders{g: g, alph: alph, freq: freq, heur: heur, verbose: verbose, pq: pq, out: os.Stdout}
in := bufio.NewReader(os.Stdin)
for {
	fmt.Println()
	start, ok := promptForFive(in, os.Stdout, "Starting", echo)
	if !ok {
		break // 시작 낱말이 없으면 끝
	}
	goal, ok := promptForFive(in, os.Stdout, "    Goal", echo)
	if !ok {
		continue // 목적 낱말이 없으면 시작부터 다시
	}
	@<|start|에서 |goal|까지 최단 사다리를 찾아 찍는다@>
}

@ |promptForFive|는 정확히 다섯 개의 소문자를 엔터와 함께 받을 때까지 조른다.
소문자가 아닌 글자가 섞이거나 길이가 다르면 다시 조른다. 좋은 낱말을 얻으면
|(낱말, true)|를, 빈 줄이나 파일 끝이면 |("", false)|를 돌려준다---부르는
쪽이 그 |false|를 끝냄으로 볼지 다시 받기로 볼지 정한다.

@<끝말을 다섯 자로 받는다@>=
func promptForFive(in *bufio.Reader, out io.Writer, s string, echo bool) (string, bool) {
	for {
		fmt.Fprintf(out, "%s word: ", s)
		var buf []byte
		valid, n := true, 0
		@<한 줄을 읽어 |buf|에 모은다@>
		if n == 5 && valid {
			return string(buf), true
		}
		if n == 0 {
			return "", false // 빈 줄이거나 파일 끝
		}
		fmt.Fprintf(out, "(Please type five lowercase letters and RETURN.)\n")
	}
}

@ 한 글자씩 읽는다. 파일 끝이면 곧바로 |("", false)|로 돌아간다. 소문자가
아니면 그 줄을 그르다고 표시하고, 소문자면 다섯 자까지 |buf|에 담는다.

@<한 줄을 읽어 |buf|에 모은다@>=
for {
	c, err := in.ReadByte()
	if err != nil {
		return "", false // 파일 끝
	}
	if echo {
		out.Write([]byte{c})
	}
	if c == '\n' {
		break
	}
	n++
	if c < 'a' || c > 'z' {
		valid = false
	} else if len(buf) < 5 {
		buf = append(buf, c)
	}
}

@* 찾아보기.
