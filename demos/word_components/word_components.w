% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 word_components.w를 Go로 이식한다.
@i ../../types.w

\input kotexgweb
\def\title{WORD\_\,COMPONENTS}

@* 성분. 이 조촐한 시연 프로그램은 다섯 글자 낱말 그래프의 연결 성분(connected
component)을 헤아린다. 무게가 큰 차례로 낱말을 하나씩 그래프에 들이면서, 매
단계마다 --- 즉 앞선 $n$개의 낱말로 이루어진 부분그래프마다 --- 간선 수, 성분 수,
외딴 정점 수를 찍는다. 그러면 그래프가 자라나며 작은 성분들이 하나둘 뭉쳐
끝내 하나의 거대한 성분(giant component)으로 자라는 모습을, 마치 강물이 여러
지류를 삼키며 흘러가듯 지켜볼 수 있다.

이 프로그램은 |gbwords.Words|가 지은 그래프를 곧바로 소비하는 첫 손님이므로,
원본의 \.{gb\_words} 이식을 end-to-end로 검증하는 몫도 겸한다.

@c
package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"os"

	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbwords"
)

@<보조 함수@>@;
@<성분을 분석해 찍는다@>@;

func main() {
	dir := flag.String("d", "data", "words.dat가 있는 디렉터리")
	flag.Parse()
	g, err := gbwords.Words(0, nil, 0, 0, *dir)
	if err != nil {
		log.Fatalf("사전을 짓지 못했습니다: %v", err)
	}
	analyze(g, os.Stdout)
}

@ |analyze|는 정점을 무게순으로 훑으며 성분 구조를 키운다. 정점 |v|의
|arcs| 리스트에서, |v|보다 나중에 온 낱말로 가는 호는 앞쪽에, 먼저 온 낱말로
가는 호는 뒤쪽에 놓인다(낱말이 그래프에 들어오는 차례가 그렇게 만든다). 우리는
과거에만 관심이 있고 미래에는 관심이 없으니, 앞쪽의 호들을 건너뛴다.

@<성분을 분석해 찍는다@>=
func analyze(g *gbgraph.Graph, out io.Writer) (comp, isol, m int64) {
	fmt.Fprintf(out, "Component analysis of %s\n", g.ID)
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		fmt.Fprintf(out, "%4d: %5d %s", i+1, v.U.I, v.Name)
		@<정점 |v|를 성분 구조에 더하며, 합쳐지는 성분을 찍는다@>@;
		fmt.Fprintf(out, "; c=%d,i=%d,m=%d\n", comp, isol, m)
	}
	@<뜻밖의 성분들을 모두 보여 준다@>@;
	return
}

@ 연결 성분은 순환 리스트로 좇는다. 이 방법은
참으로 무작위인 그래프에서 평균 $O(n)$ 시간이 걸린다고 알려져 있다[Knuth와
Sch\"onhage, {\sl Theoretical Computer Science\/ \bf 6\/} (1978), 281--315].

곧, |v|가 한 정점이면 그 성분의 모든 정점은 리스트 $$\hbox{|v|,\quad |v.Z.V|,\quad
|v.Z.V.Z.V|,\quad \dots}$$ 에 놓여, 돌고 돌아 다시 |v|로 돌아온다. 성분마다 으뜸 정점(master)이
하나 있어 |v.Y.V|로 가리키며, |v|가 으뜸이면 |v.X.I|가 그 성분의 정점 수다.

이 프로그램은 낱말 그래프의 남는 유틸리티 필드 셋을 이렇게 빌려 쓴다.

$$\vbox{\halign{\indent#\hfil&\quad#\hfil\cr
이음(link)&|v.Z.V| --- 성분 안 다음 정점\cr
으뜸(master)&|v.Y.V| --- 성분의 으뜸 정점\cr
크기(size)&|v.X.I| --- 성분의 정점 수(으뜸에서만 최신)\cr}}$$

@ 새 정점 |v|는 먼저 홀로 선 성분이 된다. 그런 다음 |v|에서 먼저 온 낱말로
가는 호마다 두 성분을 합친다. |v|가 어느 앞선 낱말과도 이웃하지 않으면
외딴(isolated) 낱말이라 |[1]|을 찍는다.

@<정점 |v|를 성분 구조에 더하며, 합쳐지는 성분을 찍는다@>=
@<|v|를 홀로 선 성분으로 만든다@>@;
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
		@<|u|와 |v|의 성분이 다르면 합친다@>@;
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
	@<두 순환 리스트를 잇는다@>@;
	comp--
}

@ 작은 쪽 리스트를 |wm|에서 시작하는 큰 쪽 리스트에 잇는다. 크기가 같아
|u|가 큰 쪽으로 뽑힌 경우에도, 두 리스트를 서로 엮으면 하나의 고리가 된다.

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

@<뜻밖의 성분들을 모두 보여 준다@>=
fmt.Fprint(out, "\nThe following non-isolated words didn't join the giant component:\n")
for i := int64(0); i < g.N; i++ {
	v := &g.Vertices[i]
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

@* 시험. 성분 분석을 조용히(|io.Discard|로) 돌려, 얻은 값들이 서로 아귀가
맞는지 본다. 간선 수 |m|은 반드시 |g.M/2|와 같아야 하고(|M|은 방향 있는 호를
세므로), 거대 성분·외딴 낱말·작은 성분의 크기 합은 정점 총수와 같아야 한다.
Knuth의 낱말 그래프는 5757개 낱말 가운데 4493개가 하나의 거대 성분을 이룬다.

@(word_components_test.go@>=
package main

import (
	"io"
	"testing"

	"github.com/sjnam/go-sgb/gbwords"
)

func TestWordComponents(t *testing.T) {
	g, err := gbwords.Words(0, nil, 0, 0, "../../data")
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 5757 {
		t.Fatalf("정점 수 = %d, 원함 5757", g.N)
	}
	comp, isol, m := analyze(g, io.Discard)
	@<성분 값들이 아귀가 맞는지 확인한다@>@;
}

@ 거대 성분의 크기는 으뜸 정점들의 |X.I| 가운데 가장 큰 값이다. 성분 크기의
총합은 정점 총수와 같아야 하고, 외딴 낱말은 크기 1인 성분의 수와 같아야 한다.

@<성분 값들이 아귀가 맞는지 확인한다@>=
if m != g.M/2 {
	t.Errorf("간선 수 = %d, 원함 %d(=M/2)", m, g.M/2)
}
var giant, sizeSum, singles int64
for i := int64(0); i < g.N; i++ {
	v := &g.Vertices[i]
	if v.Y.V == v { // 으뜸 정점
		sizeSum += v.X.I
		if v.X.I == 1 {
			singles++
		}
		if v.X.I > giant {
			giant = v.X.I
		}
	}
}
if sizeSum != g.N {
	t.Errorf("성분 크기 합 = %d, 원함 %d", sizeSum, g.N)
}
if singles != isol {
	t.Errorf("외딴 낱말 = %d, 크기 1 성분 = %d", isol, singles)
}
if giant != 4493 {
	t.Errorf("거대 성분 크기 = %d, 원함 4493", giant)
}
_ = comp

@* 찾아보기.
