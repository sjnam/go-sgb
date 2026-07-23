% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 word_components.w를 Go로 이식한다.
@i ../../gbtypes.w

\input kotexgweb
\def\title{WORD\_\,COMPONENTS}

@* 성분. 이 조촐한 시연 프로그램은 다섯 글자 낱말 그래프의 연결 성분(connected
component)을 헤아린다. 무게가 큰 차례로 낱말을 하나씩 그래프에 들이면서, 매
단계마다---즉 앞선 $n$개의 낱말로 이루어진 부분그래프마다---간선 수, 성분 수,
외딴 정점 수를 찍는다. 그러면 그래프가 자라나며 작은 성분들이 하나둘 뭉쳐
끝내 하나의 거대한 성분(giant component)으로 자라는 모습을, 마치 강물이 여러
지류를 삼키며 흘러가듯 지켜볼 수 있다.

이 프로그램은 |gbwords.Words|가 지은 그래프를 곧바로 소비하는 첫 손님이므로,
원본의 {\sc GB\_\,WORDS} 이식을 end-to-end로 검증하는 몫도 겸한다.

@ 출력이 조금 빽빽하니 미리 읽는 법을 익혀 두자. 낱말마다 한 줄이 나오고,
그 줄은 차례 번호, 무게, 낱말로 시작해서 세 셈값 |c|(성분 수), |i|(외딴 정점
수), |m|(간선 수)로 끝난다. 가운데에는 이 낱말이 성분 구조에 어떤 일을
저질렀는지가 적힌다. 실제 출력에서 네 가지 꼴이 나온다.
$$\vbox{\halign{\indent\.{#}\hfil\cr
\ \ 8:\ 47043 words[1]; c=7,i=6,m=1\cr
\ \ 6:\ 54585 these in there[2]; c=5,i=4,m=1\cr
\ 58:\ \ 9604 white with write[1] in while[4]; c=45,i=39,m=16\cr
161:\ \ 3604 lives with lines[1], given[2] in lived[5]; c=120,i=97,m=45\cr}}$$
\.{[1]}은 이 낱말이 앞선 어느 낱말과도 이웃하지 않아 외딴섬으로 남았다는 뜻이다
(놀랍게도 \.{words}가 그렇다---여덟째로 흔한 낱말인데 그때까지 나온 일곱 낱말
가운데 이웃이 없다). \.{in \it이름\/[\it크기\/]}는 이 낱말이 끝내 속하게 된
성분의 으뜸과 그 크기다.

@ 재미있는 것은 그 사이에 끼는 \.{with}와 쉼표다. 낱말 |v|가 앞선 낱말들과
이웃해서 성분을 합칠 때, {\sl 첫 번째\/} 합침은 잠자코 넘어간다---|v|가 어느
성분에 들어가는 것뿐이니 새삼스러울 게 없다. 그러나 두 번째부터는 |v|가 여태
따로 놀던 성분들을 서로 이어 주는 셈이니, 흡수되는 쪽의 이름과 크기를 찍어
알린다. 두 번째 앞에는 \.{with}를, 세 번째부터는 쉼표를 둔다.

그러니 위 셋째 줄은 ``\.{white}가 (조용히 어딘가에 들어간 뒤) \.{write}\.{[1]}
성분까지 끌어당겨, 끝내 크기 4인 \.{while} 성분이 되었다''로 읽는다. 넷째 줄은
\.{lives}가 성분 셋을 한꺼번에 묶어 크기 5짜리 \.{lived} 성분을 만든 것이다
($1+1+1+2=5$).

@c
package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	@#
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbwords"
)

@<보조 함수@>

func main() {
	dir := flag.String("d", "data", "words.dat가 있는 디렉터리")
	flag.Parse()
	g, err := gbwords.Words(0, nil, 0, 0, *dir)
	if err != nil {
		log.Fatalf("사전을 짓지 못했습니다: %v", err)
	}
	@<성분을 분석해 찍는다@>
}

@ 정점을 무게순으로 훑으며 성분 구조를 키운다. 정점 |v|의 |arcs| 리스트에서,
|v|보다 나중에 온 낱말로 가는 호는 앞쪽에, 먼저 온 낱말로 가는 호는 뒤쪽에
놓인다(낱말이 그래프에 들어오는 차례가 그렇게 만든다). 우리는 과거에만 관심이
있고 미래에는 관심이 없으니, 앞쪽의 호들을 건너뛴다.

@<성분을 분석해 찍는다@>=
out := os.Stdout
var comp, isol, m int64
fmt.Fprintf(out, "Component analysis of %s\n", g.ID)
for i := int64(0); i < g.N; i++ {
	v := &g.Vertices[i]
	fmt.Fprintf(out, "%4d: %5d %s", i+1, v.U.I, v.Name)
	@<정점 |v|를 성분 구조에 더하며, 합쳐지는 성분을 찍는다@>
	fmt.Fprintf(out, "; c=%d,i=%d,m=%d\n", comp, isol, m)
}
@<뜻밖의 성분들을 모두 보여 준다@>

@ 연결 성분은 순환 리스트로 좇는다. 이 방법은
참으로 무작위인 그래프에서 평균 $O(n)$ 시간이 걸린다고 알려져 있다[Knuth와
Sch\"onhage, {\sl Theoretical Computer Science\/ \bf 6\/} (1978), 281--315].
@^Knuth, Donald Ervin@>
@^Sch\"onhage, Arnold@>
합칠 때 늘 {\sl 작은 쪽\/}의 으뜸을 고쳐 쓰는 것이 요령이다. 한 정점의 으뜸이
바뀔 때마다 그 정점이 속한 성분의 크기는 적어도 두 배가 되므로, 한 정점의
으뜸은 많아야 $\lg n$번 바뀐다.

곧, |v|가 한 정점이면 그 성분의 모든 정점은 리스트 $$\hbox{|v|,\quad |v.Z.V|,\quad
|v.Z.V.Z.V|,\quad \dots}$$ 에 놓여, 돌고 돌아 다시 |v|로 돌아온다. 성분마다 으뜸 정점(master)이
하나 있어 |v.Y.V|로 가리키며, |v|가 으뜸이면 |v.X.I|가 그 성분의 정점 수다.

이 프로그램은 낱말 그래프의 남는 유틸리티 필드 셋을 이렇게 빌려 쓴다.

$$\vbox{\halign{\indent#\hfil&\quad#\hfil\cr
이음(link)&|v.Z.V|---성분 안 다음 정점\cr
으뜸(master)&|v.Y.V|---성분의 으뜸 정점\cr
크기(size)&|v.X.I|---성분의 정점 수(으뜸에서만 최신)\cr}}$$

@ 새 정점 |v|는 먼저 홀로 선 성분이 된다. 그런 다음 |v|에서 먼저 온 낱말로
가는 호마다 두 성분을 합친다. |v|가 어느 앞선 낱말과도 이웃하지 않으면
외딴(isolated) 낱말이라 |[1]|을 찍는다.

@<정점 |v|를 성분 구조에 더하며, 합쳐지는 성분을 찍는다@>=
@<|v|를 홀로 선 성분으로 만든다@>
a := v.Arcs
for a != nil && g.Index(a.Tip) > i {
	a = a.Next
}
if a == nil {
	fmt.Fprint(out, "[1]") // 이 낱말은 외딴섬이다
} else {
	var c int64 // |v| 때문에 일어난 합침의 수
	for ; a != nil; a = a.Next {
		u := a.Tip
		m++
		@<|u|와 |v|의 성분이 다르면 합친다@>
	}
	fmt.Fprintf(out, " in %s[%d]", v.Y.V.Name, v.Y.V.X.I) // 최종 성분
}

@ @<|v|를 홀로 선 성분으로 만든다@>=
v.Z.V = v
v.Y.V = v
v.X.I = 1
isol++
comp++

@ 두 성분이 합쳐질 때는 작은 쪽의 으뜸을 바꾼다. |v|가 어떤 앞선 낱말과
이웃하면 |v| 자신을 대표하던 으뜸도 바뀐다. 크기가 갱신되기 전에 먼저 찍어야
하므로, 출력이 갱신을 앞선다.

외딴 정점 셈 |isol|을 줄이는 대목이 두 갈래에서 서로 다른데, 실수가 아니라
꼭 그래야 한다. 첫 갈래는 |u.X.I|가 |wm.X.I|보다 {\sl 진짜로\/} 작은 경우라,
|u|의 크기가 1이면 |wm|의 크기는 2 이상이다---그러니 외딴 성분일 수 있는 것은
|u| 하나뿐이다. 둘째 갈래는 크기가 같을 수도 있어 둘 다 1일 수 있으므로 양쪽을
다 살펴야 한다. 게다가 |u.X.I|를 먼저 살핀 뒤에 더해야 한다. 순서를 바꾸면
자기 자신을 세는 꼴이 된다.

@<|u|와 |v|의 성분이 다르면 합친다@>=
u = u.Y.V
if u != v.Y.V {
	wm := v.Y.V
	c++
	if u.X.I < wm.X.I {
		if c > 1 {
			printMerge(out, c, u.Name, u.X.I)
		}
		wm.X.I += u.X.I
		if u.X.I == 1 {
			isol--
		}
		relink(u, wm)
	} else {
		if c > 1 {
			printMerge(out, c, wm.Name, wm.X.I)
		}
		if u.X.I == 1 {
			isol--
		}
		u.X.I += wm.X.I
		if wm.X.I == 1 {
			isol--
		}
		relink(wm, u)
	}
	@<두 순환 리스트를 잇는다@>
	comp--
}

@ 두 순환 리스트를 하나로 잇는 것은 이음 두 개를 맞바꾸는 일이 전부다. |u|가
$u\to u_1\to\cdots\to u$라는 고리에, |wm|이 $w\to w_1\to\cdots\to w$라는 고리에
있다고 하자. |u.Z.V|와 |wm.Z.V|를 서로 바꾸면 |u|는 $w_1$을 가리키고 |wm|은
$u_1$을 가리키게 되어, $u\to w_1\to\cdots\to w\to u_1\to\cdots\to u$라는 하나의
고리가 된다. 어느 쪽이 크고 작은지와 상관없이 늘 그렇다.

@<두 순환 리스트를 잇는다@>=
t := u.Z.V
u.Z.V = wm.Z.V
wm.Z.V = t

@ 두 보조 함수다. |relink|는 |from|에서 시작하는 순환 리스트의 모든 정점(과
|from| 자신)의 으뜸을 |to|로 바꾼다. |printMerge|는 합침을 찍되, 첫 합침 뒤
둘째에는 |" with"|를, 그 뒤로는 쉼표를 앞에 둔다.

@<보조 함수@>=
func relink(from, to *gbgraph.Vertex) {
	for t := from.Z.V; t != from; t = t.Z.V {
		t.Y.V = to
	}
	from.Y.V = to
}

func printMerge(out io.Writer, c int64, name string, size int64) {
	conj := ","
	if c == 2 {
		conj = " with"
	}
	fmt.Fprintf(out, "%s %s[%d]", conj, name, size)
}

@ 낱말 그래프에는 하나의 거대한 성분과 수많은 외딴 낱말이
있다. 그 밖의 성분은 모두 뜻밖이라 여겨, 다른 계산이 끝난 뒤에 찍어 낸다.
으뜸이면서, 크기가 1보다 크고, 그 두 배가 |g.N|보다 작은(즉 거대 성분이 아닌)
정점이 그런 성분의 대표다. 한 줄에 열두 낱말씩 늘어놓는다.

낱말 $5757$개를 다 넣고 나면 마지막 줄이 이렇게 끝난다.
$$\hbox{\.{5757:\ \ \ \ \ 0 pupal with pupil[1] in
lived[4493]; c=853,i=671,m=14135}}$$
곧 간선은 $14135$개, 성분은 $853$개, 그 가운데 $671$개가 외딴 낱말이고,
거대 성분은 \.{lived}를 으뜸으로 하는 $4493$개짜리다. 그러니 뜻밖의 성분은
$853-671-1=181$개이고 거기 든 낱말은 $5757-671-4493=593$개다. 그 목록이
이 프로그램의 마지막 출력이며, \.{sound moult fount mould hound mound mount
court count wound world could would pound bound round found}로 시작해서
\.{utero uteri}로 끝난다.

@<뜻밖의 성분들을 모두 보여 준다@>=
fmt.Fprint(out, "\nThe following non-isolated words didn't join the giant component:\n")
for v := range g.AllVertices() {
	if v.Y.V == v && v.X.I > 1 && v.X.I+v.X.I < g.N {
		c := int64(1) // 이번 줄에 찍은 낱말 수
		fmt.Fprint(out, v.Name)
		for u := v.Z.V; u != v; u = u.Z.V {
			if c == 12 {
				fmt.Fprint(out, "\n")
				c = 1
			} else {
				c++
			}
			fmt.Fprintf(out, " %s", u.Name)
		}
		fmt.Fprint(out, "\n")
	}
}

@* 찾아보기.
