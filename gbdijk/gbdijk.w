% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_dijk.w를 Go로 이식한다.
@i ../types.w

\input kotexgweb
\def\title{GB\_\,DIJK}

@* 들어가며. 시연용 루틴 |Dijkstra(uu, vv, gg, hh, pq, trace)|는 그래프 |gg|의
정점 |uu|에서 |vv|까지 가는 최단 경로를, 선택적 어림 함수 |hh|의 도움을 받아
찾는다. 이는 음이 아닌 호 길이를 가진 유향 그래프에서 최단 경로를 구하는
Dijkstra의 알고리즘을 구현한 것이다[E.~W. Dijkstra, ``A note on two problems in
connexion with graphs,'' {\sl Numerische Mathematik\/ \bf 1\/} (1959),
269--271].

|hh|가 |nil|이면 |gg|의 모든 호 길이는 음이 아니어야 한다. |hh|가 |nil|이
아니면, |hh|는 정점 위의 함수로서 |u|에서 |v|로 가는 호의 길이 |d|가 늘
$$d \ge |hh|(u)-|hh|(v)$$
를 지켜야 한다. 그러면 각 호 길이 |d|를 |d-hh(u)+hh(v)|로 바꾼, 음이 아닌 호
길이의 그래프를 얻는다. 이 바뀐 그래프에서의 최단 경로는 원래 그래프에서의
최단 경로와 같다. 이것이 바로 A* 탐색의 씨앗이다 --- |hh(u)|가 |u|에서 목적지
|vv|까지의 참거리와 같다면, 최단 경로 위 모든 호의 바뀐 길이는 0이 되어,
알고리즘은 헛된 곁길로 새지 않고 가장 쓸모 있는 호부터 살핀다.

|trace|가 |nil|이 아니면 |Dijkstra|는 |uu|에서 방문하는 모든 정점까지의
거리를 그 |trace|에 적어 발자취를 남긴다. \CEE/ 원본은 전역 |verbose|에
기대었지만, 우리 관례는 진단 출력을 |io.Writer|로 받는다(|nil|이면 침묵).

최단 경로를 찾으면 |Dijkstra|는 그 길이를 돌려준다. |uu|에서 |vv|로 가는
경로가 없으면(특히 |vv|가 |nil|이면) $-1$을 돌려주며, 그런 경우 |uu|에서
닿을 수 있는 모든 정점까지의 최단 거리가 그래프에 채워진다. 딸린 함수
|PrintResult(vv, out)|는 찾은 경로 자체를 보여 준다.

이 함수들의 쓰임새는 {\sc LADDERS} 시연 모듈에서 볼 수 있다.

@ 이 모듈은 다른 프로그램의 부품으로 쓰인다. 뼈대는 우선순위 큐 인터페이스와
그 도우미들, Dijkstra 절차, 두 가지 큐 구현, 그리고 결과 출력으로 이루어진다.

@c
package gbdijk

import (
	"fmt"
	"io"

	"github.com/sjnam/go-sgb/gbgraph"
)

@<우선순위 큐 인터페이스와 이음 도우미@>@;
@<|Dijkstra| 절차@>@;
@<기본 큐: 이중 연결 리스트@>@;
@<작은 길이용 큐: 128열@>@;
@<결과를 찍는 |PrintResult|@>@;

@* 주 알고리즘. Dijkstra의 알고리즘이 나아가는 동안, 그것은 |uu|에서 점점 더
많은 정점까지의 최단 경로를 ``안다''(known). 처음엔 |uu| 자신만 안다. |vv|를
알게 되거나 |uu|에서 닿을 수 있는 모든 정점을 알게 되면 끝난다.

알고리즘은 아는 정점에 이웃한 모든 정점을 살핀다. 정점이 아는 정점이거나 아는
정점에 이웃하면 ``보았다''(seen)고 한다. 아직 알지 못하되 본 정점들은 보조
목록에 담아 두는데, 이 목록은 실은 |d| 값으로 정렬된 우선순위 큐다. 큐에서
|d|가 가장 작은 정점 |v|는 꺼내어 아는 정점으로 삼을 수 있다 --- |uu|에서 |v|로
가는 길이 |d|보다 짧은 경로는 있을 수 없기 때문이다. 바로 이 대목에서 호
길이가 음이 아니라는 가정이 알고리즘의 정당성에 결정적이다.

@ 이 생각을 구현하려고 정점 레코드의 유틸리티 필드 여럿을 빌려 쓴다. 정점 |v|의
|dist| 필드는, |v|를 알면 |uu|로부터의 참거리를, 아직 모르면 지금까지 찾아낸
최단 거리를 담는다. |backlink| 필드는 |v|를 보았을 때에만 |nil|이 아니며, 그때
|dist|를 이루는 경로에서 |uu|에 한 걸음 더 가까운 정점을 가리킨다(예외:
|uu|의 |backlink|는 자기 자신을 가리킨다). |backlink|들을 거슬러 오르면 최단
경로를 되짚을 수 있다. |hh_val|에는 한 번 셈한 |hh(v)|를 갈무리해 두어 다시
셈하지 않는다.

$$\vbox{\halign{\indent#\hfil&\quad#\hfil\cr
|dist|&|v.Z.I| --- |uu|로부터의 (|hh|로 바뀐) 거리\cr
|backlink|&|v.Y.V| --- 한 걸음 앞선 정점\cr
|hh_val|&|v.X.I| --- 셈해 둔 |hh(v)|\cr
|llink|, |rlink|&|v.V.V|, |v.W.V| --- 큐의 두 이음\cr}}$$

@ 이제 |Dijkstra|다. |Dijkstra|는 |gg|에서 |uu|부터 |vv|까지 최단 경로의
길이를 돌려준다. 경로가 없으면 $-1$이다. |hh|가 |nil|이면 늘 0을 주는 더미로
바꾸되, 사용자가 어림 함수를 주었는지는 |hasHH|에 미리 적어 둔다(발자취에서 |hh|
값을 괄호로 보일지 정하는 데 쓴다). |pq|가 |nil|이면 기본 큐를 쓴다. |trace|가
|nil|이 아니면 발자취를 남긴다.
@<|Dijkstra| 절차@>=
func Dijkstra(uu, vv *gbgraph.Vertex, gg *gbgraph.Graph,
	hh func(*gbgraph.Vertex) int64,
	pq PriorityQueue, trace io.Writer) int64 {
	hasHH := hh != nil
	if hh == nil {
		hh = func(*gbgraph.Vertex) int64 { return 0 }
	}
	if pq == nil {
		pq = NewDList()
	}
	@<|uu|만을 본 정점으로 만들고, 아는 정점으로도 삼는다@>@;
	t := uu
	if trace != nil {
		@<첫 알림을 찍는다@>@;
	}
	for t != vv {
		@<|t|에 이웃한 아직 못 본 정점을 큐에 넣고, 나머지의 거리를 고친다@>@;
		t = pq.DelMin()
		if t == nil {
			return -1 // 큐가 비면 |vv|로 갈 길이 없다
		}
		if trace != nil {
			@<|t|까지의 거리를 찍는다@>@;
		}
	}
	return vv.Z.I - vv.X.I + uu.X.I // |uu|에서 |vv|까지의 참거리
}

@ 정점은 |backlink|가 |nil|이 아닐 때 보았다고, 보았으되 큐에 없을 때 안다고
여긴다. 처음엔 모든 |backlink|를 지우고, |uu|만 자기 자신을 가리키게 한다.

@<|uu|만을 본 정점으로 만들고, 아는 정점으로도 삼는다@>=
for i := int64(0); i < gg.N; i++ {
	gg.Vertices[i].Y.V = nil // |backlink|를 지운다
}
uu.Y.V = uu   // |backlink|
uu.Z.I = 0    // |dist|
uu.X.I = hh(uu) // |hh| 값
pq.Init(0)    // 큐를 비운다

@ |t|의 이웃을 훑는다. 이미 본 이웃은 더 나은 길을 찾았을 때만 다시 큐에
넣고(|Requeue|), 처음 본 이웃은 |hh| 값을 셈해 큐에 넣는다(|Enqueue|).

@<|t|에 이웃한 아직 못 본 정점을 큐에 넣고, 나머지의 거리를 고친다@>=
d := t.Z.I - t.X.I // |dist|에서 |hh| 값을 뺀 값
for a := t.Arcs; a != nil; a = a.Next {
	v := a.Tip
	if v.Y.V != nil { // |v|를 이미 보았다
		dd := d + a.Len + v.X.I
		if dd < v.Z.I {
			v.Y.V = t
			pq.Requeue(v, dd) // 더 나은 길을 찾았다
		}
	} else { // |v|를 처음 본다
		v.X.I = hh(v)
		v.Y.V = t
		pq.Enqueue(v, d+a.Len+v.X.I)
	}
}

@ 발자취에는 참거리를 보인다. 게다가 자명하지 않은 어림 함수를 쓸 때는
|hh| 값을 대괄호로 곁들여, 정점들이 참거리에 |hh|를 더한 순서로 알려짐을
지켜볼 수 있게 한다.

@<첫 알림을 찍는다@>=
fmt.Fprintf(trace, "Distances from %s", uu.Name)
if hasHH {
	fmt.Fprintf(trace, " [%d]", uu.X.I)
}
fmt.Fprint(trace, ":\n")

@ @<|t|까지의 거리를 찍는다@>=
fmt.Fprintf(trace, " %d to %s", t.Z.I-t.X.I+uu.X.I, t.Name)
if hasHH {
	fmt.Fprintf(trace, " [%d]", t.X.I)
}
fmt.Fprintf(trace, " via %s\n", t.Y.V.Name)

@* 결과 출력. |Dijkstra|가 최단 경로를 찾고 나면, |vv|에서 시작하는
|backlink|들이 그 경로의 걸음들을 일러 준다. 경로를 앞쪽 방향으로 찍으려고
이음들을 뒤집는다. 그리고 사용자가 |backlink|가 망가지길 바라지 않았을지도
모르니, 다시 되뒤집어 원래대로 돌려놓는다. 리스트 뒤집기는 한 스택에서 꺼내
다른 스택에 쌓는 일로 여기면 편하다.
@<결과를 찍는 |PrintResult|@>=
func PrintResult(vv *gbgraph.Vertex, out io.Writer) {
	if vv.Y.V == nil {
		fmt.Fprintf(out, "Sorry, %s is unreachable.\n", vv.Name)
		return
	}
	@<|backlink| 사슬을 뒤집는다@>@;
	@<|uu|에서 |vv|까지 앞쪽으로 찍는다@>@;
	@<|backlink| 사슬을 되뒤집는다@>@;
}

@ 뒤집기는 |p|에서 하나씩 꺼내 |t|에 쌓는다. |uu|의 |backlink|가 자기 자신을
가리키므로, 고리는 |t==p==uu|에서 멈춘다.

@<|backlink| 사슬을 뒤집는다@>=
var t *gbgraph.Vertex
p := vv
for {
	q := p.Y.V
	p.Y.V = t
	t = p
	p = q
	if t == p {
		break
	}
}

@ 이제 |t==p==uu|이고, |backlink|들은 앞쪽 방향을 가리킨다. 참거리는
|s.Z.I - s.X.I + p.X.I|인데, 여기서 |p|는 시작점 |uu|다.

@<|uu|에서 |vv|까지 앞쪽으로 찍는다@>=
for s := t; s != nil; s = s.Y.V {
	fmt.Fprintf(out, "%10d %s\n", s.Z.I-s.X.I+p.X.I, s.Name)
}

@ 되뒤집기는 |t|에서 하나씩 꺼내 |p|에 쌓아, |backlink|들을 원래대로
돌려놓는다. |p|가 |vv|에 이르면 멈춘다.

@<|backlink| 사슬을 되뒤집는다@>=
t = p
for {
	q := t.Y.V
	t.Y.V = p
	p = t
	t = q
	if p == vv {
		break
	}
}

@* 우선순위 큐. 큐는 인터페이스로 감싼다. 그러면 {\sc GB\_DIJK}의 사용자는
원하는 다른 큐 방식을 끼워 넣을 수 있다 --- \CEE/ 원본이 함수 포인터로 하던
일을, 우리는 인터페이스로 또렷하게 한다. 네 연산은 다음과 같다.

$$\vbox{\halign{\indent#\hfil&\quad#\hfil\cr
|Init(d)|&큐를 비우고, 앞으로 키가 |d| 이상임을 준비한다\cr
|Enqueue(v, d)|&정점 |v|를 키 |d|로 큐에 넣는다\cr
|Requeue(v, d)|&|v|를 빼내 더 작은 키 |d|로 다시 넣는다\cr
|DelMin()|&키가 가장 작은 정점을 빼내 돌려준다(비었으면 |nil|)\cr}}$$

@<우선순위 큐 인터페이스와 이음 도우미@>=
type PriorityQueue interface {
	Init(d int64)
	Enqueue(v *gbgraph.Vertex, d int64)
	Requeue(v *gbgraph.Vertex, d int64)
	DelMin() *gbgraph.Vertex
}

@ 큐는 정점의 남는 두 유틸리티 필드를 이음으로 빌려 쓴다. |llink|는 |V.V|에,
|rlink|는 |W.V|에 둔다. 아래 도우미들이 그 두 이음을 감싸고, 흔한 세 가지
이음질 --- |t|의 오른쪽에 끼우기, |u|의 왼쪽에 끼우기, 떼어내기 --- 을 이름
있는 연산으로 만든다. 그러면 아래 두 큐 구현의 이음질이 한눈에 읽힌다.

@<우선순위 큐 인터페이스와 이음 도우미@>=
func llink(v *gbgraph.Vertex) *gbgraph.Vertex { return v.V.V }
func rlink(v *gbgraph.Vertex) *gbgraph.Vertex { return v.W.V }
func setLlink(v, x *gbgraph.Vertex)           { v.V.V = x }
func setRlink(v, x *gbgraph.Vertex)           { v.W.V = x }

func insertRight(t, v *gbgraph.Vertex) { // |v|를 |t|와 그 |rlink| 사이에
	r := rlink(t)
	setLlink(v, t)
	setRlink(v, r)
	setLlink(r, v)
	setRlink(t, v)
}

func insertLeft(u, v *gbgraph.Vertex) { // |v|를 |u|의 |llink|와 |u| 사이에
	l := llink(u)
	setLlink(v, l)
	setRlink(l, v)
	setRlink(v, u)
	setLlink(u, v)
}

func unlink(v *gbgraph.Vertex) { // |v|를 두 이웃으로부터 떼어낸다
	setRlink(llink(v), rlink(v))
	setLlink(rlink(v), llink(v))
}

@ 기본 큐는 소박한 이중 연결 리스트다. 애플리케이션이 너무 크지 않을 때
알맞은 기본값이다(큐가 커질 때 더 빠른 다른 방식은 {\sc MILES\_SPAN}을 보라).
특별한 리스트 머리 |head| 하나에서 |llink|를 따라가면 큐의 모든 원소를 키가
줄어드는 차례로 만난다. |Init|은 머리의 |dist|를 어떤 실제 키보다도 작은
|d-1|로 두어, 삽입 훑기가 반드시 머리에서 멈추게 한다.

@<기본 큐: 이중 연결 리스트@>=
type dlist struct {
	head gbgraph.Vertex // 늘 있는 리스트 머리
}

// |NewDList|는 빈 이중 연결 리스트 큐를 만든다.
func NewDList() PriorityQueue { return new(dlist) }

func (q *dlist) Init(d int64) {
	h := &q.head
	setLlink(h, h)
	setRlink(h, h)
	h.Z.I = d - 1
}

@ 큐에 처음 들어오는 원소는 다른 원소들보다 키가 클 법하다고 보아, 머리의
|llink| 쪽(큰 키 끝)에서부터 훑어 자리를 찾는다. 실제로 모든 호의 길이가 같은
특별한 경우, 이 방식은 꽤 빠르다 --- 모든 정점이 큐 끝에 붙고 앞에서 빠지므로,
다시 넣기 없이 엄격한 선입선출이 되어 너비 우선 탐색을 이룬다.

@<기본 큐: 이중 연결 리스트@>=
func (q *dlist) Enqueue(v *gbgraph.Vertex, d int64) {
	t := llink(&q.head)
	v.Z.I = d
	for d < t.Z.I {
		t = llink(t)
	}
	insertRight(t, v)
}

func (q *dlist) DelMin() *gbgraph.Vertex {
	h := &q.head
	t := rlink(h)
	if t == h {
		return nil
	}
	unlink(t)
	return t
}

@ 다시 넣기는 |v|를 제자리에서 떼어낸 뒤, 새 (더 작은) 키에 맞는 자리를
그 옛 |llink|에서부터 찾아 끼운다.

@<기본 큐: 이중 연결 리스트@>=
func (q *dlist) Requeue(v *gbgraph.Vertex, d int64) {
	t := llink(v)
	unlink(v)
	v.Z.I = d
	for d < t.Z.I {
		t = llink(t)
	}
	insertRight(t, v)
}

@* 특별한 경우. 그래프의 호 길이가 모두 꽤 작으면, 연산 하나하나를 빠르게
해내는 다른 큐 방식을 쓸 수 있다. 길이가 0, 1, \dots, |k-1|뿐이라면, 우선순위
큐에 서로 다른 값이 |k|개보다 많이 담기는 일은 결코 없음을 쉽게 증명할 수
있다. 게다가 키 값을 |k|로 나눈 나머지별로 |k|개의 이중 연결 리스트를 두어
구현할 수 있다. |k=128|로 잡자. 아래는 호 길이가 128보다 작다고 알 때 쓰는
큐로, |ladders|가 |alph|이나 |freq| 선택지에서 부린다.

@<작은 길이용 큐: 128열@>=
type list128 struct {
	head      [128]gbgraph.Vertex // 128개의 리스트 머리
	masterKey int64               // 큐에 있을 수 있는 가장 작은 키
}

// |NewList128|은 호 길이가 128 미만일 때 쓰는 빠른 큐를 만든다.
func NewList128() PriorityQueue { return new(list128) }

func (q *list128) Init(d int64) {
	q.masterKey = d
	for i := range q.head {
		u := &q.head[i]
		setLlink(u, u)
		setRlink(u, u)
	}
}

@ 리스트 수가 2의 거듭제곱이 아니라면 나머지를 나눗셈으로 구했겠지만,
128이므로 |d & 0x7f|가 곧 |d % 128|이다. |DelMin|은 |masterKey|부터 128개
열을 돌며 비지 않은 첫 열의 앞 원소를 빼낸다.

@<작은 길이용 큐: 128열@>=
func (q *list128) DelMin() *gbgraph.Vertex {
	for d := q.masterKey; d < q.masterKey+128; d++ {
		u := &q.head[d&0x7f] // |d % 128|
		t := rlink(u)
		if t != u { // 키가 최소인 비지 않은 열을 찾았다
			q.masterKey = d
			unlink(t)
			return t
		}
	}
	return nil // 128개 열이 모두 비었다
}

@ 연산이 하나같이 단순한데 왜 리스트를 이중으로 잇는지 궁금할 만하다. 단일
연결로도 넉넉하다 --- 다시 넣기만 없다면. 다시 넣기는 리스트 한가운데의 아무
원소나 지우는 일을 포함하는데, 그러려면 두 이음이 필요해 보인다. Dijkstra의
알고리즘에서는 새 |d|가 늘 |masterKey| 이상이지만, 최소 신장 트리 셈
({\sc MILES\_SPAN})처럼 다른 알고리즘에서도 쓰이도록 다시 넣기를 일반적으로
구현한다.

@<작은 길이용 큐: 128열@>=
func (q *list128) Enqueue(v *gbgraph.Vertex, d int64) {
	v.Z.I = d
	insertLeft(&q.head[d&0x7f], v)
}

func (q *list128) Requeue(v *gbgraph.Vertex, d int64) {
	unlink(v)
	v.Z.I = d
	insertLeft(&q.head[d&0x7f], v)
	if d < q.masterKey {
		q.masterKey = d // Dijkstra에는 필요 없다
	}
}

@* 시험. 작은 유향 그래프 하나를 손으로 지어, 두 큐 방식과 어림 함수가 모두
같은 최단 거리를 주는지, 닿을 수 없는 정점에는 $-1$을 주는지, 그리고
|PrintResult|가 경로를 옳게 찍는지 본다. 고전적인 다섯 정점 예제에서
|a|부터 |d|까지의 최단 경로는 |a|-|c|-|b|-|d|로 길이 4다.

@(gbdijk_test.go@>=
package gbdijk

import (
	"strings"
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
)

@<시험용 그래프를 짓는다@>@;
@<최단 거리 시험@>@;
@<어림 함수 시험@>@;
@<닿을 수 없는 정점 시험@>@;
@<경로 출력 시험@>@;

@ 정점 |a|(0)부터 |e|(4)까지 다섯 정점에 다섯 개의 유향 호를 둔다. |e|로 가는
호는 없어 |e|는 |a|에서 닿을 수 없다.

@<시험용 그래프를 짓는다@>=
func buildGraph() *gbgraph.Graph {
	g := gbgraph.NewGraph(5)
	for i := range g.Vertices[:5] {
		g.Vertices[i].Name = string(rune('a' + i))
	}
	v := func(i int) *gbgraph.Vertex { return &g.Vertices[i] }
	g.NewArc(v(0), v(1), 4)
	g.NewArc(v(0), v(2), 1)
	g.NewArc(v(2), v(1), 2)
	g.NewArc(v(1), v(3), 1)
	g.NewArc(v(2), v(3), 5)
	return g
}

@ 두 큐 방식 모두 |a|에서 |d|까지 거리 4를 주어야 한다.

@<최단 거리 시험@>=
func TestShortestPath(t *testing.T) {
	for _, pq := range []struct {
		name string
		make func() PriorityQueue
	}{
		{"dlist", NewDList},
		{"list128", NewList128},
	} {
		g := buildGraph()
		d := Dijkstra(&g.Vertices[0], &g.Vertices[3], g, nil, pq.make(), nil)
		if d != 4 {
			t.Errorf("%s: 거리 = %d, 원함 4", pq.name, d)
		}
	}
}

@ 어림 함수는 모든 호 |u|-|v|에 대해 $|len| \ge |hh|(u)-|hh|(v)$를 지켜야
한다. 아래 값들이 그 조건을 지키므로, 어림을 써도 참거리는 4로 그대로다.

@<어림 함수 시험@>=
func TestHeuristic(t *testing.T) {
	g := buildGraph()
	hval := map[string]int64{"a": 2, "b": 1, "c": 1, "d": 0, "e": 0}
	hh := func(v *gbgraph.Vertex) int64 { return hval[v.Name] }
	d := Dijkstra(&g.Vertices[0], &g.Vertices[3], g, hh, NewList128(), nil)
	if d != 4 {
		t.Errorf("어림을 쓴 거리 = %d, 원함 4", d)
	}
}

@ |e|는 |a|에서 닿을 수 없으니 $-1$이라야 한다.

@<닿을 수 없는 정점 시험@>=
func TestUnreachable(t *testing.T) {
	g := buildGraph()
	if d := Dijkstra(&g.Vertices[0], &g.Vertices[4], g, nil, nil, nil); d != -1 {
		t.Errorf("거리 = %d, 원함 -1", d)
	}
}

@ 경로 출력은 |a|, |c|, |b|, |d|를 거리 0, 1, 3, 4와 함께 앞쪽 방향으로
찍어야 한다. 되뒤집기가 |backlink|를 원래대로 돌려놓는지도 아울러 확인한다.

@<경로 출력 시험@>=
func TestPrintResult(t *testing.T) {
	g := buildGraph()
	Dijkstra(&g.Vertices[0], &g.Vertices[3], g, nil, nil, nil)
	var b strings.Builder
	PrintResult(&g.Vertices[3], &b)
	want := "         0 a\n         1 c\n         3 b\n         4 d\n"
	if b.String() != want {
		t.Errorf("경로 출력 =\n%q\n원함\n%q", b.String(), want)
	}
	if g.Vertices[0].Y.V != &g.Vertices[0] {
		t.Errorf("되뒤집기 뒤 a의 backlink가 자기 자신이 아니다")
	}
}

@* 찾아보기.
