% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 miles_span.w를 Go로 이식한다.
@i ../../types.w

\input kotexgweb
\raggedbottom % 코드가 빽빽한 문서라 페이지 하단을 억지로 늘리지 않는다
\def\title{MILES\_\,SPAN}

@* 최소 신장 트리. 그래프의 최소 길이 신장 트리를 찾는 알고리즘의 역사를 다룬
R.~L. Graham과 Pavol Hell의 고전적 논문[{\sl Annals of the History of
Computing\/ \bf 7\/} (1985), 43--57]은 세 갈래 접근을 소개한다. 알고리즘 1
``두 가장 가까운 조각''(Kruskal, 1956)은 아직 잇지 않은 두 조각을 잇는 가장
짧은 간선을 거듭 더한다. 알고리즘 2 ``가장 가까운 이웃''(Jarn\'\i k, 1930)은
한 조각을 그 조각 밖 정점에 잇는 가장 짧은 간선을 거듭 더한다. 알고리즘 3
``모든 가장 가까운 조각''(Bor\accent23uvka, 1926)은 각 조각을 다른 조각에 잇는
가장 짧은 간선을 한꺼번에 더한다.

이 프로그램은 세 접근을 모두 소박하게 구현해, ``현실적인'' 자료에서 그들이
어떻게 움직이는지 견준다. 이 프로그램의 큰 목표 하나는, 메모리 참조 곧
``mem''을 세어 \CEE/로(여기서는 \GO/로) 쓴 프로그램을 기계와 무관하게 견주는
간단한 길을 보이는 것이다. 다시 말해, 이 프로그램은 실행하기보다 읽으라고
쓴 것이다.

@ 우리가 다룰 그래프는 {\sc GB\_MILES} 모듈의 |Miles| 서브루틴이 짓는다.
기본으로 $n=100$, $northWeight=westWeight=popWeight=0$, $maxDegree=10$을
쓴다. 씨앗 |seed|가 다르면 $\,128\,\choose100$ 가지 부분그래프 가운데 다른
하나를 고르므로, 갖가지 성긴 그래프를 얻는다.

명령줄 옵션 \.{-n}, \.{-N}, \.{-W}, \.{-P}, \.{-d}, \.{-s}로 각각 |n|,
|northWeight|, |westWeight|, |popWeight|, |maxDegree|, |seed|의 기본값을
바꾼다. \.{-r}〈수〉는 씨앗을 하나씩 늘려 가며 여러 그래프를 잇달아 살핀다.
\.{-v}는 고른 간선을 낱낱이 찍는다.

(\CEE/ 원본의 \.{-g}〈파일〉 옵션은 |save_graph|가 갈무리한 그래프를 되살려
쓰는데, 아직 {\sc GB\_SAVE}를 옮기지 않았으므로 여기서는 뺐다.)

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

	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbmiles"
	"github.com/sjnam/go-sgb/gbsave"
)

const infinity = int64(1) << 50 // 신장 트리가 없을 때 돌려주는 값

@<보고 함수@>@;
@<Kruskal 알고리즘@>@;
@<Jarn\'\i k/Prim 알고리즘@>@;
@<이진 힙@>@;
@<피보나치 힙@>@;
@<이항 큐@>@;
@<Cheriton/Tarjan/Karp 알고리즘@>@;

func main() {
	@<명령줄 옵션을 읽는다@>@;
	s := &solver{verbose: verbose, out: os.Stdout}
	for ; r > 0; r-- {
		@<이 반복에 쓸 그래프를 |g|에 만든다@>@;
		if err != nil || g.N <= 1 {
			fmt.Fprintf(os.Stderr, "Sorry, can't create the graph! (%v)\n", err)
			os.Exit(1)
		}
		s.g = g
		@<이 그래프의 최소 신장 트리 mem 수를 알린다@>@;
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
@<이진 힙으로 |jarPr(g)|를 실행한다@>@;
fmt.Fprintf(s.out, " the Jarnik/Prim/binary-heap algorithm takes %d mems;\n", s.mems)
@<피보나치 힙으로 |jarPr(g)|를 실행한다@>@;
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

@* 전략과 규칙. {\sl 조각\/}(fragment)이란 최소 신장 트리의 부분 트리다. 세
알고리즘 모두 R.~C. Prim이 1957년에 온전히 밝힌 원리에 기댄다: ``조각 $F$가
모든 정점을 담지 않고, $e$가 $F$를 $F$ 밖 정점에 잇는 가장 짧은 간선이면,
$F\cup e$도 조각이다.''

|Miles| 그래프에는 쓸모 있는 성질이 있다. 첫째, 각 간선의 길이는 $2^{12}$보다
작은 양의 정수다. 둘째, $k$번째 정점은 |g.Vertices[k]|이고, 무게를 매겼으면
무게순이다. 셋째, 정점 |v|에서 나가는 간선은 |v.Arcs|에서 시작하는 리스트에
있는데, |v|에서 $v_j$로 가는 간선이 |v|에서 $v_k$로 가는 간선보다 앞서는 것은
$j>k$일 때뿐이다. Kruskal 구현은 첫째 성질(길이 $<2^{12}$)과 셋째 성질(간선을
한 번만 보기)을 쓴다.

@ mem을 세는 방법을 이야기하자. \CEE/ 원본은 매크로 |o|, |oo|, |ooo|, |oooo|를
어떤 문장이나 식 바로 앞에 두어, 그것이 만드는 메모리 참조 수만큼 |mems|를
늘렸다. \GO/에는 매크로가 없으니, 그 자리에 |s.mems|를 직접 늘린다 --- |o|는
|s.mems++|, |oo|는 |s.mems += 2|, 이런 식이다. 레지스터에 있다고 볼 값
(반복문의 유도 변수 등)을 읽는 데는 mem을 물리지 않는다. 그래서 이 프로그램은
원본과 같은 자리에 같은 수의 mem을 물려, Knuth가 발표한 mem 수를 그대로 낸다.

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
	@<간선을 낮은 6비트로 |aucket|에 담는다@>@;
	@<|aucket|을 높은 6비트로 |bucket|에 옮긴다@>@;
	if s.verbose {
		fmt.Fprintf(s.out, "   [%d mems to sort the edges into buckets]\n", s.mems)
	}
	@<모든 정점을 저마다의 성분에 넣는다@>@;
	var totLen int64
	for l := 0; l < 64; l++ {
		s.mems++ // |o,a=bucket[l]|
		for a := bucket[l]; a != nil; a = a.B.A {
			s.mems++ // 반복마다 |o,a=a->klink|
			@<간선 |a|를 보아, 새 성분을 이으면 더한다@>@;
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

@ union-find 자료 구조로 성분을 좇는다[Knuth와 Sch\"onhage, {\sl Theoretical
Computer Science\/ \bf 6\/} (1978), 281--315]. 각 성분의 정점들은 |clink|(|Z.V|)
으로 순환하며 이어지고, |comp|(|Y.V|)은 성분 대표를 가리키며, |csize|(|X.I|)는
대표에서만 성분 크기를 담는다.

@<모든 정점을 저마다의 성분에 넣는다@>=
components := s.g.N
for i := int64(0); i < s.g.N; i++ {
	v := &s.g.Vertices[i]
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
	@<|u|와 |v|의 성분을 합친다@>@;
}

@ 두 성분을 합칠 때, 작은 쪽의 |comp|들을 큰 쪽으로 바꾸고 두 순환 리스트를
잇는다. 크기 비교에 2 mem, 크기 갱신에 1 mem을 물린다(더할 값들은 이미 읽었다).

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

@* Jarn\'\i k와 Prim의 알고리즘. 두 번째 접근도 꽤 단순하다. 임의의 정점
$v_0$에서 시작해 가장 가까운 이웃 $v_1$에 잇고, 그 조각을 다시 가장 가까운
이웃 $v_2$에 잇고, 이렇게 나아간다. 우선순위 큐가 조각에 이웃하되 아직 조각에
들지 않은 정점들을 담으며, 각 정점의 키는 조각까지의 거리다. 이는
{\sc GB\_DIJK}의 Dijkstra 알고리즘과 놀랍도록 닮았다 --- 실제로 Dijkstra는
최단 경로 절차를 떠올린 바로 그때 이 알고리즘도 따로 발견했다.

큐를 갈아 끼울 수 있도록, {\sc GB\_DIJK}에서처럼 네 연산 |initQueue|·|enqueue|·
|requeue|·|delMin|을 인터페이스로 감싼다. 정점의 키는 |dist|(|Z.I|)에, 그
거리만큼 떨어진 상대는 |backlink|(|Y.V|)에 둔다.

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
	@<정점 0만 보고 알게 한다@>@;
	for fragmentSize < s.g.N {
		@<|t|에 이웃한 못 본 정점을 큐에 넣고, 나머지 거리를 고친다@>@;
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

@* 이진 힙. |jarPr|를 마치려면 네 큐 연산을 채워야 한다. 이진 힙은 $n$개
원소의 배열인데, 그 공간은 이미 있다 --- 정점 레코드의 |u| 유틸리티 필드를
쓴다. |heapElt(i)|(곧 |gv[i].U.V|)가 정점 |v|를 가리키면 |v.V.I=i|가 되도록
맞춘다. 힙은 1부터 센다.

핵심 불변식은 |heapElt(k/2).dist <= heapElt(k).dist|($1<k\le hsize$)이다.

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

@ 다시 넣기도 siftup이라 넣기와 거의 같다. 키가 줄어든 정점이 조상들을 밀어
올릴 수 있다.

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

@ 가장 작은 키를 빼내기다. 뺄 정점은 늘 |heapElt(1)|이다. 그것을 지운 뒤
|heapElt(hsize)|를 아래로 내린다(``siftdown''). 두 자식의 |dist|를 견주는 데
4 mem을 문다.

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

@* 피보나치 힙. Fredman과 Tarjan이 1984년에 고안한 피보나치 힙은 다시 넣기를
``분할 상환 상수 시간''에 해내, 점근적으로 $O(m+n\log n)$을 이룬다. 힙은
키가 부모 $\le$ 자식으로 정렬된 트리들의 숲인데, 성질 F를 더 지킨다: 계수 $k$인
마디의 자식들의 계수 $\{r_1\le\cdots\le r_k\}$는 모든 $j$에 대해 $r_j\ge j-2$다.

마디마다 |parent|, |child|, |lsib|, |rsib| 네 포인터와, 계수 |rank|·표식 |tag|를
합친 |rank_tag|($=rank\cdot2+tag$) 필드를 둔다. \CEE/는 정점 유틸리티 필드가
여섯뿐이라 |parent|·|child|를 여분 |Arc|에 우회해 담았지만, \GO/의 유틸리티
필드는 각각 |.V|·|.A|·|.I|를 따로 가진 구조체라 우회 없이 곧장 담는다:
|parent|(|U.V|), |child|(|X.V|), |lsib|(|V.V|), |rsib|(|W.V|), |rank_tag|(|X.I|),
|dist|(|Z.I|). 외부 포인터 |fHeap|은 키가 가장 작은 마디를 가리킨다.

@<피보나치 힙@>=
type fibHeap struct {
	s        *solver
	fHeap    *gbgraph.Vertex     // 뿌리 마디들의 고리; 키 최소를 가리킴
	newRoots [46]*gbgraph.Vertex // 계수별 뿌리 (크기 $2^{32}$까지)
}

func (h *fibHeap) initQueue(d int64) { h.fHeap = nil }

@ 넣기는 쉽다. 새 원소를 숲에 새 트리로 넣기만 한다. |fHeap->dist|는 레지스터에
있다고 보아 읽는 데 mem을 물리지 않는다.

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

@ 다시 넣기는 중간 난도다. 뿌리에서 키를 줄이거나 줄여도 부모보다 작지 않으면
이음을 바꿀 게 없다. 아니면 그 마디와 자손들을 떼어 숲에 새 트리로 넣는다.
부모의 계수가 1 줄고, 부모가 표식이 없었으면 표식을 달며, 표식이 있었으면
부모마저 떼어 올린다 --- 뿌리나 표식 없는 마디에 이를 때까지.

@<피보나치 힙@>=
func (h *fibHeap) requeue(v *gbgraph.Vertex, d int64) {
	h.s.mems++ // |o,v->dist=d|
	v.Z.I = d
	h.s.mems++ // |o,p=v->parent|
	p := v.U.V
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
		h.s.mems++ // |o,r=p->rank_tag|
		r := p.X.I
		if r >= 4 { // |v|는 외자식이 아니다
			@<|v|를 가족에서 뗀다@>@;
		}
		@<|v|를 숲에 넣는다@>@;
		h.s.mems++ // |o,pp=p->parent|
		pp := p.U.V
		if pp == nil { // |v|의 부모가 뿌리다
			h.s.mems++ // |o,p->rank_tag=r-2|
			p.X.I = r - 2
			break
		}
		if r&1 == 0 { // 부모에 표식이 없다
			h.s.mems++ // |o,p->rank_tag=r-1|
			p.X.I = r - 1
			break // 이제 표식이 붙었다
		}
		h.s.mems++ // |o,p->rank_tag=r-2| (표식 있던 부모는 뿌리가 된다)
		p.X.I = r - 2
		v = p
		p = pp
	}
}

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

@ 키 최소 빼기가 가장 볼거리다. |fHeap|이 뺄 마디를 가리키니, 그 자식들과 숲의
뿌리들을 모두 보아 새 |fHeap|을 찾아야 한다. 그러면서 계수별로 뿌리가 많아야
하나가 되도록 숲을 다시 세운다 --- 같은 계수 뿌리 둘을 만나면 하나를 다른 하나의
자식으로 삼아 트리 수를 줄인다. |new_roots| 배열이 그 일을 돕는다.

@<피보나치 힙@>=
func (h *fibHeap) delMin() *gbgraph.Vertex {
	finalV := h.fHeap
	hi := int64(-1) // |new_roots|에 있는 가장 높은 계수
	if h.fHeap != nil {
		var v *gbgraph.Vertex
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
		for v != h.fHeap {
			h.s.mems++ // |o,w=v->rsib|
			w := v.W.V
			@<|v|를 뿌리로 하는 트리를 |new_roots| 숲에 넣는다@>@;
			v = w
		}
		@<|new_roots|에서 |fHeap|을 다시 세운다@>@;
	}
	return finalV
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
	h.s.mems++ // |o,new_roots[r]=NULL|
	h.newRoots[r] = nil
	h.s.mems += 2 // |oo,u->dist<v->dist|
	if u.Z.I < v.Z.I {
		h.s.mems++ // |o,v->rank_tag=r<<1|
		v.X.I = r << 1
		u, v = v, u
	}
	@<|u|를 |v|의 자식으로 만든다@>@;
	r++
}
h.s.mems++ // |o,v->rank_tag=r<<1|
v.X.I = r << 1

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

@* 이항 큐. Vuillemin의 이항 큐[{\sl CACM\/ \bf 21\/} (1978), 309--314]는
또 다른 우선순위 큐다. 피보나치 힙보다 강한 두 조건을 지킨다: 계수 $k$인 마디는
계수 $\{0,1,\ldots,k-1\}$의 자식을 정확히 하나씩 갖고, 숲의 뿌리들은 계수가
저마다 다르다. 이항 큐는 다시 넣기를 잘 못하는 대신, 두 큐를 합치기(merge)를
효율적으로 해내며, 마디당 포인터 둘이면 충분하다 --- 가장 큰 자식을 가리키는
|qchild|(|A.A|)와 다음 형제를 가리키는 |qsib|(|B.A|). 그래서 Cheriton, Tarjan,
Karp의 알고리즘이 쓰는 정점(이 아니라 호)의 큐에 꼭 맞는다.

큐 자체를 나타내는 머리 마디를 하나 둔다. 그 |qsib|은 계수가 가장 작은 뿌리를
가리키고, |qchild| 자리(|A.I|)에는 마디 총수 |qcount|를 담는다 --- 그 이진
표현이 |qsib|에서 닿는 트리들의 크기를 말해 준다. 이 큐의 키 필드는 |dist|가
아니라 |len|이다(마디가 정점이 아니라 호이므로).

@ 대부분의 연산이 기대는 |qunite|는, |q|에서 시작하는 |m|개 마디 숲과 |qq|에서
시작하는 |mm|개 마디 숲을 합쳐, |m+mm|개 마디 숲의 포인터를 |h->qsib|에 넣는다.
분할 상환 시간은 |mm|과 무관하게 $O(\log m)$이다. 두 힙 정렬 트리는 한쪽을
다른 쪽의 새 자식으로 붙이면 합쳐진다.

@<이항 큐@>=
func (s *solver) qunite(m int64, q *gbgraph.Arc, mm int64, qq *gbgraph.Arc, h *gbgraph.Arc) {
	p := h
	k := int64(1)
	for m != 0 {
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
			@<|q|와 |qq|를 carry 트리로 합쳐, carry가 안 번질 때까지 잇는다@>@;
		}
		k <<= 1
	}
	if mm != 0 {
		s.mems++ // |o,p->qsib=qq|
		p.B.A = qq
	}
}

@ 두 입력 리스트에 같은 크기 트리가 있으면, 크기 $2k$의 carry 트리로 합친다.
그 carry는 더 큰 크기로 번질 수 있어, 자리가 빌 때까지 이어 합친다.

@<|q|와 |qq|를 carry 트리로 합쳐, carry가 안 번질 때까지 잇는다@>=
var c, r, rr *gbgraph.Arc
var key int64
m -= k
if m != 0 {
	s.mems++ // |o,r=q->qsib|
	r = q.B.A
}
mm -= k
if mm != 0 {
	s.mems++ // |o,rr=qq->qsib|
	rr = qq.B.A
}
@<|c|를 |q|와 |qq|의 합으로 놓는다@>@;
k <<= 1
q = r
qq = rr
for (m|mm)&k != 0 {
	if m&k == 0 {
		@<|qq|를 |c|에 합치고 |qq|를 나아가게 한다@>@;
	} else {
		@<|q|를 |c|에 합치고 |q|를 나아가게 한다@>@;
		if mm&k != 0 {
			s.mems++ // |o,p->qsib=qq|
			p.B.A = qq
			p = qq
			mm -= k
			if mm != 0 {
				s.mems++ // |o,qq=qq->qsib|
				qq = qq.B.A
			}
		}
	}
	k <<= 1
}
s.mems++ // |o,p->qsib=c|
p.B.A = c
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

@ 이제 |qunite|의 열매를 거둔다. |qenque|는 새 호를 큐에 넣고, |qmerge|는 한
큐를 다른 큐에 합치고, |qdelMin|은 키 최소 마디를 뺀다.

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
	@<키가 가장 작은 뿌리 |q|의 트리를 찾아 뺀다@>@;
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

@ 마지막으로, 이항 큐를 훑으며 마디마다 |visit|을 한 번씩 불러 큐를 헐어
간다. 드는 mem은 마디당 약 1.75다.

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
마지막 알고리즘은 두 단계로 움직인다.
단계 1은 각 조각에서 나가는 간선만 지역적으로 다루며 작은 조각들을 만든다.
조각 수가 $n$에서 \lsqrtn\ 로 줄면 단계 2가 시작된다. 단계 2는 남은 간선들로
$\lsqrtn\times\lsqrtn$ 행렬을 세워, 남은 \lsqrtn\ 조각의 최소 신장 트리를
$O(\sqrt n)^2=O(n)$ 알고리즘으로 마무리한다.

@<Cheriton/Tarjan/Karp 알고리즘@>=
func (s *solver) cherTarKar() int64 {
	s.mems = 0
	var totLen int64
	headers := make([]gbgraph.Arc, s.g.N)
	for i := int64(0); i < s.g.N; i++ {
		s.g.Vertices[i].U.A = &headers[i] // |pq| 머리 (mem 없음)
	}
	@<CTK 단계 1@>@;
	@<CTK 단계 2@>@;
	return totLen
}

@ 조각이 \usqrtn\ 이상이면 {\sl 크다\/}고 한다. 조각이 커지면 단계 1은 더 늘리길
멈춘다. 작은 조각들의 리스트를 두고, 맨 앞 조각과 그것에 가장 가까운 다른 조각을
거듭 합친다. |sm|·|tl|이 작은 리스트의 처음·끝이고, |lsib|(|V.V|)·|rsib|(|W.V|)
으로 두 겹 잇는다. |largeList|는 |rsib|으로 한 겹 잇는다. |comp|(|Y.V|)이 |nil|이면
그 정점이 조각 대표이고, |csize|(|X.I|)가 조각 크기다. 각 조각의 |pq|는 그 조각
정점들에서 나가는, 아직 안 본 호들의 이항 큐다.

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
@<작은 리스트를 만든다@>@;
for frags > loSqrt {
	@<작은 리스트 맨 앞 조각을 가장 가까운 이웃과 합친다@>@;
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
	s.mems++ // |o,u=a->tip|
	u = a.Tip
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
s.mems++ // |o,tot_len+=a->len|
totLen += a.Len
s.mems++ // |o,v->comp=u|
v.Y.V = u
s.qmerge(u.U.A, v.U.A)
s.mems++ // |o,old_size=u->csize|
oldSize := u.X.I
s.mems++ // |o,new_size=old_size+v->csize|
newSize := oldSize + v.X.I
s.mems++ // |o,u->csize=new_size|
u.X.I = newSize
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
		if u == last {
			return // 이미 우리가 바라는 자리다
		}
		if u == first {
			s.mems++ // |o,s=u->rsib|
			nf = u.W.V
		} else {
			s.mems += 3 // |ooo,u->rsib->lsib=u->lsib|
			u.W.V.V.V = u.V.V
			s.mems++ // |o,u->lsib->rsib=u->rsib|
			u.V.V.W.V = u.W.V
		}
		s.mems++ // |o,t->rsib=u|
		last.W.V = u
		s.mems++ // |o,u->lsib=t|
		u.V.V = last
		nl = u
		return
	}
	// |u|가 방금 커졌다
	if u == last {
		if u == first {
			return
		}
		s.mems++ // |o,t=u->lsib|
		nl = u.V.V
	} else if u == first {
		s.mems++ // |o,s=u->rsib|
		nf = u.W.V
	} else {
		s.mems += 3 // |ooo|
		u.W.V.V.V = u.V.V
		s.mems++ // |o|
		u.V.V.W.V = u.W.V
	}
	s.mems++ // |o,u->rsib=large_list|
	u.W.V = largeList
	nll = u
	return
}

@ 단계 2다. 정점들을 0부터 $\lsqrtn-1$까지의 번호로 옮기고(|findex|, |csize|를
되씀), 남은 간선으로 축소 행렬을 세운 뒤, Prim의 알고리즘으로 마무리한다.
행렬 |matx(j,k)|는 |g.Vertices[j*loSqrt+k].Z.I|에, 그에 대응하는 호는 |.V.A|에
둔다. |INF=30000|은 모든 간선 길이의 상한이다.

@<CTK 단계 2@>=
const inf = 30000 // 모든 간선 길이의 상한
var distance [100]int64
var distArc [100]*gbgraph.Arc
var kk int64
matx := func(j, k int64) *int64 { return &s.g.Vertices[j*loSqrt+k].Z.I }
@<정점들을 번호로 옮긴다@>@;
@<남은 간선으로 축소 행렬을 만든다@>@;
@<축소 행렬에 Prim의 알고리즘을 돌린다@>@;

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

@ Prim이 제안한 마지막 걸음은, 행렬의 각 행을 만날 때마다 거리 벡터를 갱신한다.
완전 그래프의 최소 신장 트리를 찾는 데 알맞은 방법이다.

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
	@<조각 0을 조각 |j|와 잇고, 다음 판의 |j|와 |d|를 셈한다@>@;
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

@* 시험. 기본 그래프 |miles(100,0,0,0,0,10,0)|과 완전 그래프
|miles(100,0,0,0,0,99,0)|(옵션 \.{-d100})에서, 각 알고리즘이 쓰는 mem 수를
Knuth의 발표값과 대조하고, 네 알고리즘의 결과 길이가 모두 같은지 본다.

@(miles_span_test.go@>=
package main

import (
	"io"
	"testing"

	"github.com/sjnam/go-sgb/gbmiles"
)

func TestSpanMems(t *testing.T) {
	cases := []struct {
		degree                         int64
		krusk, jarPrBin, jarPrFib, ctk int64
	}{
		{10, 8379, 7972, 11736, 17770},
		{99, 63795, 50594, 59050, 175519},
	}
	for _, c := range cases {
		g, err := gbmiles.Miles(100, 0, 0, 0, 0, c.degree, 0, "../../data")
		if err != nil {
			t.Fatal(err)
		}
		s := &solver{g: g, out: io.Discard}
		lk := s.krusk()
		if s.mems != c.krusk {
			t.Errorf("d=%d: Kruskal mems = %d, 원함 %d", c.degree, s.mems, c.krusk)
		}
		lb := s.jarPr(&binHeap{s: s})
		if s.mems != c.jarPrBin {
			t.Errorf("d=%d: Prim/binary mems = %d, 원함 %d", c.degree, s.mems, c.jarPrBin)
		}
		lf := s.jarPr(&fibHeap{s: s})
		if s.mems != c.jarPrFib {
			t.Errorf("d=%d: Prim/Fibonacci mems = %d, 원함 %d", c.degree, s.mems, c.jarPrFib)
		}
		lc := s.cherTarKar()
		if s.mems != c.ctk {
			t.Errorf("d=%d: Cheriton/Tarjan/Karp mems = %d, 원함 %d", c.degree, s.mems, c.ctk)
		}
		if lk != lb || lk != lf || lk != lc {
			t.Errorf("d=%d: 길이 불일치 K %d, bin %d, fib %d, ctk %d", c.degree, lk, lb, lf, lc)
		}
	}
}

@* 찾아보기.
