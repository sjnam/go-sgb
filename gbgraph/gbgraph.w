% 이 문서는 Stanford GraphBase의 gb_graph.w((c) 1993 Stanford University)를
% 한글 GWEB(Go)로 옮긴 것으로, Stanford GraphBase의 일부가 아니다.
@i ../types.w

\input kotexgweb
\def\title{GB\_\,GRAPH}

@* 들어가며. 이것은 {\sc GB\_\,GRAPH}, 곧 모든 GraphBase 루틴이 쓰는
자료구조 모듈이다. 원본의 부제는 ``메모리를 할당하는 모듈''이었고 실제로
분량의 절반이 저장 공간 관리였지만, \GO/로 건너오면서 그 절반은 쓰레기
수거기(garbage collector)에게 자리를 물려주었다---그 사연은 |@<자료구조@>|
뒤에서 따로 애도한다. 여기 남는 것은 그래프 표현의 기본 타입들과
그래프를 만들고 키우고 검색하는 루틴들이다.

이 규약들을 어떻게 쓰는지 보여주는 예제는 다른 GraphBase 모듈 어디에나
있다. 가장 좋은 입문은 아마 {\sc GB\_\,BASIC}일 텐데, 고전적인 그래프들을
생성하고 변환하는 서브루틴들이 거기 모여 있다.

원본이 함께 뽑아내던 검증 프로그램 \.{test\_graph.c}는 \GO/ 시험 파일
\.{gbgraph\_test.go}가 되어 마지막 절에서 같은 검사---그리고 \CEE/에서는 하지
못했던 몇 가지---를 수행한다.
@c
package gbgraph

import (
	"fmt"
	"iter"
	"unsafe"
)

@<패닉 부호@>
@<자료구조@>
@<그래프 키우기@>
@<정점 찾기@>

@ GraphBase 프로그램에는 대개 ``verbose'' 옵션과, 특이한 오류를 짚어 주는
|panic_code| 변수가 있었다. 전역 |verbose|는 이 포팅에서 폐기한다---진단
출력이 필요한 곳은 |io.Writer|를 매개변수로 받으면 된다. 반면 패닉 부호는
쓸모가 여전하므로, 그래프 생성기가 |nil| 그래프와 함께 돌려주는 |error|
타입으로 만든다.

작은 값은 메모리 부족을, 10대와 20대는 입출력 이상을, 30대와 40대는
서브루틴 매개변수의 오류를 가리킨다. 어떤 부호는 저자가 결코 일어나지
않으리라 생각하면서도 만일을 위해 검사하는 경우를 위한 것이다. 한 루틴
안에서 같은 종류의 오류가 여럿이면 정수를 더해 구별한다---|SyntaxError+1|과
|SyntaxError+2|는 서로 다른 두 문법 오류다. 타입이 정수이므로 이 가산
구별이 \GO/에서도 그대로 통한다.
@<패닉 부호@>=
type PanicCode int64

const (
	AllocFault     PanicCode = -1 // 이전의 메모리 요청이 실패했었다
	NoRoom         PanicCode = 1  // 지금의 메모리 요청이 실패했다
	EarlyDataFault PanicCode = 10 // \.{.dat} 파일 첫머리에서 오류가 감지됐다
	LateDataFault  PanicCode = 11 // \.{.dat} 파일 끝에서 오류가 감지됐다
	SyntaxError    PanicCode = 20 // \.{.dat} 파일을 읽는 중 오류가 감지됐다
	BadSpecs       PanicCode = 30 // 매개변수가 범위 밖이거나 허용되지 않는다
	VeryBadSpecs   PanicCode = 40 // 매개변수가 한참 벗어났거나 어리석다
	MissingOperand PanicCode = 50 // 그래프 매개변수가 |nil|이다
	InvalidOperand PanicCode = 60 // 그래프 매개변수가 가정을 어긴다
	Impossible     PanicCode = 90 // ``이런 일은 있을 수 없다''
)

func (p PanicCode) Error() string {
	return fmt.Sprintf("gbgraph: 패닉 부호 %d", int64(p))
}

@* 그래프의 표현. GraphBase 프로그램은 단순하고 유연한 자료구조 한 벌로
그래프를 표현하고 다룬다. 정점들은 |Vertex| 레코드의 순차 배열에 놓이고,
각 정점에서 나가는 호(arc)들은 |Arc| 레코드의 연결 리스트에 놓인다. 그래프
전체에 관한 정보를 담는 |Graph| 레코드도 하나 있다.

세 레코드에는 그래프를 다루는 알고리즘이 마음대로 쓸 수 있는 다목적
``유틸리티 필드''들이 들어 있다. \CEE/에서 이들은 다섯 갈래 공용체(union)였다:
접미사 .|V|, .|A|, .|G|, .|S|는 각각 정점·호·그래프·문자열을 가리키는
포인터를, .|I|는 정수를 뜻한다. (디버깅할 때 치기 쉽도록 한 글자 이름을
썼다고 Knuth는 밝혀 두었다.) \GO/에는 공용체가 없으므로 다섯 필드를 다 가진
구조체로 만든다 — 필드마다 40바이트씩 쓰는 사치가 되지만, 32바이트 안에
정점 하나를 구겨 넣던 1993년의 절약 정신과 쓰레기 수거기 시대의 여유를
맞바꾼 셈 치자. 덤으로 \CEE/ 코드의 $v{\rightarrow}u.V$ 같은 표현이 |v.U.V|로 글자
그대로 옮겨진다.
@<자료구조@>=
type Util struct {
	V *Vertex // 정점을 가리킬 때
	A *Arc    // 호를 가리킬 때
	G *Graph  // 그래프를 가리킬 때
	S string  // 문자열일 때
	I int64   // 정수일 때
}

@ |Vertex|의 표준 필드는 둘이다: 호 리스트의 머리 |Arcs|와, 정점을 상징적으로
식별하는 문자열 |Name|. |v.Arcs|가 |nil|이면 |v|에서 나가는 호가 없는
것이고, 아니면 그것은 |v|에서 나가는 한 호의 레코드를 가리키며 그 레코드의
|Next| 필드가 같은 방식으로 나머지 호들을 이어 간다.

유틸리티 필드는 |U|, |V|, |W|, |X|, |Y|, |Z| 여섯이다. 진입 차수나 진출
차수, 정점에 ``표시''가 되었는지 따위를 기록하는 데 흔히 쓰이고, 정점을
다른 정점이나 호의 리스트에 잇는 데도 쓰인다.
@<자료구조@>=
type Vertex struct {
	Arcs *Arc   // 이 정점에서 나가는 호들의 연결 리스트
	Name string // 이 정점을 상징적으로 식별하는 문자열
	U, V, W, X, Y, Z Util // 다목적 필드들
}

@ |Arc|의 표준 필드는 셋이다: 호가 가리키는 정점 |Tip|, 같은 정점에서
나가는 다음 호 |Next|, 그리고 길이 |Len|. 호 |a|가 정점 |v|의 리스트에
있다면 그것은 |v|에서 |a.Tip|으로 가는 길이 |a.Len|의 호다. 유틸리티
필드는 |A|와 |B| 둘이다.

\CEE/의 |Arc|는 딱 20바이트였고 그 크기가 뒤에 나올 포인터 재주의 밑천이었다.
우리의 |Arc|에는 표준 필드가 하나 더 있다 — 간선의 반대쪽 호를 가리키는
|Partner|다. 왜 필요한지는 |@<그래프 키우기@>|의 간선 절에서 이야기한다.
@<자료구조@>=
type Arc struct {
	Tip     *Vertex // 호가 가리키는 정점
	Next    *Arc    // 같은 정점에서 나가는 다른 호
	Len     int64   // 이 호의 길이
	Partner *Arc    // 간선의 반대쪽 호; 홑호라면 |nil|
	A, B    Util    // 다목적 필드들
}

@ 원본의 이 자리에는 ``메모리 영역({\bf Area})''이라는
개념이 살았다. 사용자가 \&{\bf Area} 변수 하나를 선언해 두면 |gb_alloc(n,s)|가
0으로 지워진 |n|바이트 블록을 영역 |s|에 이어 붙이고, |gb_free(s)|가 그
영역의 블록 전부를 한꺼번에 돌려주는 방식이다. 블록 끝에 포인터 두 개를
숨겨 두는 구현을 두고 Knuth는 ``거의 우스꽝스러울 만큼 쉽다(almost
ridiculously easy)''고 자랑했다. 할당 실패는 전역 |gb_trouble_code|에
쌓아 두었다가 사용자가 긴 할당 행렬 끝에 단 한 번만 검사하면 되게 했고,
그마저 실패했을 때를 위해 필드를 읽어도 죽지 않는 가짜 레코드
|dummy_arc|까지 마련해 두었다. 문자열을 큼직한 블록에 모아 담는
|gb_save_string|, 그래프 하나를 통째로 없애는 |gb_recycle|, 그리고 모든
할당이 하나의 메모리 배열에서 나온다고 가정하는 포인터 비교가 ANSI 표준에
어긋난다는 정직한 경고문까지 — 한 시대의 공학이 여기 있었다.

\GO/의 쓰레기 수거기는 이 모든 장치를 은퇴시킨다. {\bf Area}도, |gb_alloc|도,
|gb_free|도, |gb_trouble_code|도, |dummy_arc|도, |gb_save_string|도,
|gb_recycle|도 이 포팅에는 없다. 도달할 수 없게 된 그래프는 알아서
수거되고, 문자열은 |string| 값으로 살면 된다. 심지어 뒤에서 보겠지만,
전역 할당 상태가 사라진 덕에 |switch_to_graph|라는 루틴 하나가 통째로
필요 없어진다. 삭제가 이렇게 즐거운 일인 줄은 이 절을 쓰면서 알았다.

@* 그래프 키우기. 이제 |Graph| 타입을 볼 차례다. 최소 신장 나무를 찾든
강한 성분을 찾든, 그래프를 다루는 알고리즘에 통째로 넘겨줄 수 있는
자료구조다. 표준 필드는 다음과 같다.
$$\vbox{\halign{\quad #\hfil&\quad #\hfil\cr
|Vertices|&정점 레코드 배열\cr
|N|&정점의 총수\cr
|M|&호의 총수\cr
|ID|&이 그래프를 만든 GraphBase 절차와 매개변수의 표식\cr
|UtilTypes|&유틸리티 필드들의 쓰임새를 적은 14자 기호\cr}}$$
\CEE/에는 호와 문자열을 담던 {\bf Area} 필드 |data|와 |aux\_data|도 있었지만,
앞 절에서 애도했듯 떠나보냈다. 유틸리티 필드는 |UU|, |VV|, |WW|, |XX|,
|YY|, |ZZ| 여섯이다.

이 규약 덕에 그래프 |g|의 모든 호를 다음과 같이 방문할 수 있다:
$$\vbox{\halign{#\hfil\cr
|for i := range g.Vertices[:g.N] {|\cr
\quad|for a := g.Vertices[i].Arcs; a != nil; a = a.Next {|\cr
\qquad|visit(&g.Vertices[i], a)|\cr
\quad|}|\cr
|}|\cr}}$$
슬라이스를 |g.N|에서 자르는 데 주의 — |Vertices|의 실제 길이는 조금 더
길다(다음다음 절 참조). 이 두 겹 순회는 워낙 흔하므로, 뒤에서 정점의
|AllArcs|와 그래프의 |AllVertices| 반복자로 감싸 |for v := range
g.AllVertices()| 꼴로 짧게 쓸 수 있게 해 둔다.

@<자료구조@>=
type Graph struct {
	Vertices []Vertex // 정점 배열; 길이는 |N+extraN|, 순회는 |g.Vertices[:g.N]|
	N        int64    // 정점의 총수
	M        int64    // 호의 총수
	ID       string   // GraphBase 표식
	UtilTypes string  // 유틸리티 필드들의 쓰임새
	UU, VV, WW, XX, YY, ZZ Util // 다목적 필드들
	arcs []*Arc // 할당 순서의 호 레코드; SGB 호환 저장을 위해서만 쓴다
}

@ |UtilTypes|는 언제나 길이 14의 문자열이다. 처음 여섯 자는 |Vertex|의
|U|, |V|, |W|, |X|, |Y|, |Z|의 쓰임새를, 다음 두 자는 |Arc|의 |A|, |B|를,
마지막 여섯 자는 |Graph|의 유틸리티 필드들을 말한다. 각 글자는 \.I(정수),
\.S(문자열), \.V(정점 포인터), \.A(호 포인터), \.G(그래프 포인터), 또는
\.Z(안 쓰여서 영으로 남는 필드)다. 아무 유틸리티 필드도 쓰지 않을 때의
기본값은 |"ZZZZZZZZZZZZZZ"|다.

예컨대 이분 그래프 |g|가 첫 부분의 크기를 |g.UU.I|에 두고, 호마다 |A|에
문자열을, 정점마다 |W|에 호 포인터를 두면서 다른 필드는 건드리지 않는다면,
|UtilTypes|는 |"ZZAZZZSZIZZZZZ"|라야 한다.

이 문자열을 실제로 검사하는 것은 현재 {\sc GB\_\,SAVE}의 저장·복원
루틴들뿐이므로, 그래프를 다루는 알고리즘을 쓸 때마다 갱신할 필요는 없다 —
그래프를 기호 형식으로 내보낼 작정이 아니라면. \GO/의 |string|은 글자
하나를 바꿔치기할 수 없으니 작은 도우미를 마련해 둔다.

@<그래프 키우기@>=
// |SetUtilType|은 |UtilTypes|의 |k|번째 자리를 |c|로 바꾼다.
func (g *Graph) SetUtilType(k int, c byte) {
	t := []byte(g.UtilTypes)
	t[k] = c
	g.UtilTypes = string(t)
}

@ 이분 그래프 응용 중에는 첫 부분의 정점들이 |Vertices| 배열 앞쪽에
몰려 있기를 요구하는 것이 많다. 그런 경우 전통적으로 |UU.I|에 첫 부분의
크기를 두고 그 필드를 $n_1$이라 부른다. 나머지 부분의 크기는 물론
$n-n_1$이다.

@<그래프 키우기@>=
// |N1|은 이분 그래프의 첫 부분 크기다.
func (g *Graph) N1() int64 {
	return g.UU.I
}

// |MarkBipartite|는 이분 그래프의 첫 부분 크기 |n1|을 새겨 둔다.
func (g *Graph) MarkBipartite(n1 int64) {
	g.UU.I = n1
	g.SetUtilType(8, 'I')
}

@ 새 그래프는 |NewGraph(n)|으로 만든다. 정점이 |n|개이고 호는 없는
그래프다. 실제로는 |n+extraN|개의 정점 자리를 마련하면서 |n|개라고만
주장하는데, 그래프에 특별한 정점 한둘을 덧붙이고 싶어 하는 알고리즘이
여럿 있기 때문이다. |extraN|은 4이고, 아마 언제까지나 4보다 작아질 일은
없을 것이다.

\CEE/에서는 |calloc|이 실패하면 |nil|을 돌려주는 경로가 있었지만, \GO/의
|make|는 실패를 모른다(정말 메모리가 바닥나면 실행 시간 패닉이다).
정점 이름의 초기값은 \CEE/의 |null_string|, 곧 빈 문자열이었다 — \GO/에서는
|string|의 영값이 이미 빈 문자열이라 따로 할 일이 없다.

@<그래프 키우기@>=
const extraN = 4 // |NewGraph|가 여분으로 마련하는 그림자 정점의 수

func NewGraph(n int64) *Graph {
	return &Graph{
		Vertices:  make([]Vertex, n+extraN),
		N:         n,
		ID:        fmt.Sprintf("gb_new_graph(%d)", n),
		UtilTypes: "ZZZZZZZZZZZZZZ",
	}
}

@ 그래프의 |ID|는 다른 그래프의 |ID|로부터 만들어질 때가 있다. 다음 두
루틴은 그런 합성을 하되, 거듭 복사해도 문자열이 한없이 길어지지 않도록
160자에서 말줄임표로 끊는다. 저장 파일 형식이 이 길이를 전제하므로 \CEE/의
상수를 그대로 쓴다.
|MakeCompoundID|는 |g|의 |ID|를 |s1+gg.ID+s2|로 만든다.
@<그래프 키우기@>=
const idFieldSize = 161 // \CEE/의 |ID| 배열 크기; 문자로는 160자까지

func (g *Graph) MakeCompoundID(s1 string, gg *Graph, s2 string) {
	avail := idFieldSize - len(s1) - len(s2)
	if len(gg.ID) < avail {
		g.ID = s1 + gg.ID + s2
	} else {
		g.ID = s1 + gg.ID[:avail-5] + "...)" + s2
	}
}

@ |MakeDoubleCompoundID|는 |g|의 |ID|를 |s1+gg.ID+s2+ggg.ID+s3|으로 만든다.
@<그래프 키우기@>=
func (g *Graph) MakeDoubleCompoundID(s1 string, gg *Graph, s2 string,
	ggg *Graph, s3 string) {
	avail := idFieldSize - len(s1) - len(s2) - len(s3)
	if len(gg.ID)+len(ggg.ID) < avail {
		g.ID = s1 + gg.ID + s2 + ggg.ID + s3
	} else {
		g.ID = s1 + gg.ID[:avail/2-5] + "...)" + s2 +
			ggg.ID[:(avail-9)/2] + "...)" + s3
	}
}

@ 그러면 호는 어떻게 생겨나는가? \CEE/에서는 |gb_virgin_arc|가 102개들이
블록에서 새 |Arc|를 하나씩 떼어 주었다 — 102개면 대부분의 시스템에서
정확히 2048바이트, ``기분 좋은 어림수''라고 원본은 적어 두었다. 메모리가
바닥나면 |dummy_arc|를 돌려주어 호출자가 안심하고 필드를 만지게 하는
안전망도 있었다. \GO/에서 이 루틴의 소임은 |new| 한 번으로 줄지만,
생성기들이 직접 부르는 일이 있으므로 이름은 남겨 둔다.

블록 관리는 쓰레기 수거기에게 넘겼지만, 딱 한 가지 흔적은 남긴다: {\sc
GB\_\,SAVE}가 SGB와 byte 단위로 같은 \.{.gb} 파일을 뽑으려면 호를 만들어진
순서대로 번호 매겨야 하므로, 새로 만든 호를 |g.arcs|에 차례로 적어 둔다.
|VirginArc|는 새 |Arc| 레코드 하나를 내주고, 할당 순서에 적어 둔다.
@<그래프 키우기@>=
func (g *Graph) VirginArc() *Arc {
	a := new(Arc)
	g.arcs = append(g.arcs, a)
	return a
}

@ |g.NewArc(u,v,len)|은 정점 |u|에서 |v|로 가는 길이 |len|의 호를
만든다. 새 호는 곧바로 |u.Arcs|가 가리킨다. \CEE/에서는 이 호가 ``가장
최근에 만든 그래프'', 곧 전역 |cur_graph|에 속했지만, 우리는 그래프를
수신자로 받으므로 그런 암묵은 없다.
|NewArc|는 |u|에서 |v|로 가는 길이 |len|의 호를 |g|에 만든다.
@<그래프 키우기@>=
func (g *Graph) NewArc(u, v *Vertex, len int64) {
	a := g.VirginArc()
	a.Tip, a.Next, a.Len = v, u.Arcs, len
	u.Arcs = a
	g.M++
}

@ 무향 그래프에는 호 대신 ``간선(edge)''이 있다. 간선 하나는 양쪽으로
가는 호 두 개로 표현한다. 짝을 찾는 일은 |Partner| 필드가 맡으므로
\CEE/의 |edge_trick| 포인터 산술은 필요 없다. 다만 두 호에 매기는 번호까지
\CEE/와 똑같이 하려고, |gb_new_edge|의 순서 규약은 글자 그대로 옮긴다:
잇달아 할당한 두 호 |a|, |b| 가운데 |a|가 앞 번호를 받는데, |u<v|이면 |a|가
|u|에서 |v|로 가는 호(|u|의 리스트)이고, 아니면 |a|가 |v|에서 |u|로 가는
호(|v|의 리스트)다. 이렇게 해야 {\sc GB\_\,SAVE}의 호 번호가 SGB와 맞는다.

정점의 앞뒤는 포인터 순서, 곧 |Index| 순서로 가른다. 자기 고리(|u==v|)는
|u>=v| 갈래로 들어가며, \CEE/가 만들던 모양---첫 호의 |Next|가 곧 짝---이
그대로 나온다.
|NewEdge|는 |u|와 |v|를 잇는 간선, 곧 서로 짝이 되는 호 한 쌍을 |g|에 만든다.
@<그래프 키우기@>=
func (g *Graph) NewEdge(u, v *Vertex, len int64) {
	a, b := g.VirginArc(), g.VirginArc() // |a|가 앞 번호, |b|가 뒤 번호
	a.Partner, b.Partner = b, a
	a.Len, b.Len = len, len
	if g.Index(u) < g.Index(v) {
		a.Tip, a.Next = v, u.Arcs
		b.Tip, b.Next = u, v.Arcs
		u.Arcs, v.Arcs = a, b
	} else { // |u>=v|; 자기 고리도 이 갈래다
		b.Tip, b.Next = v, u.Arcs
		u.Arcs = b // |u==v|일 때를 대비해 먼저 해 둔다
		a.Tip, a.Next = u, v.Arcs
		v.Arcs = a
	}
	g.M += 2
}

@ 원본의 이 자리에는 ``더러운 재주(dirty trick)''라는 제목이 붙을 만한
절이 있었다: 호 |a|의 짝이 $a-1$인지 $a+1$인지를 주소의 mod~8
비트로 알아내는 |edge_trick| 말이다. 짝은 이제 |Partner|가 맡으니 그
재주는 은퇴했지만, 그 빈자리에 우리만의 재주 하나를 고백해 둔다.

\CEE/ 코드는 정점의 번호를 포인터 뺄셈 $v-g{\rightarrow}vertices$로 얻고, 데모들은
그 번호로 병렬 배열을 인덱싱한다. \GO/에서 같은 일을 하려면 |unsafe|가
필요하다. 이 패키지가 허용하는 유일한 더러운 재주이며, |v|가 정말
|g.Vertices|의 원소일 때만 뜻이 있다---원본의 포인터 비교들이 ANSI
표준의 눈총을 받으면서도 실용을 택했던 것과 같은 정신이라고 변명해 둔다.
|Index|는 정점 |v|가 |g.Vertices|에서 차지하는 번호를 준다.
@<그래프 키우기@>=
func (g *Graph) Index(v *Vertex) int64 {
	base := uintptr(unsafe.Pointer(&g.Vertices[0]))
	off := uintptr(unsafe.Pointer(v)) - base
	return int64(off / unsafe.Sizeof(Vertex{}))
}

@ {\sc GB\_\,SAVE}는 호를 할당 순서대로 번호 매겨 내보낸다. \CEE/는 호를
|arcsPerBlock|(102)개들이 블록으로 떼어 주었고, 마지막 블록의 안 쓰인 자리는
빈 레코드로 남아 파일에도 그대로 실렸다. |ArcRecords|는 그 모양을 재현한다:
할당 순서의 호들에, 레코드 수가 102의 배수가 되도록 |nil| 자리를 덧붙여 준다.
|ArcRecords|는 할당 순서의 모든 호 레코드를 준다(빈 자리는 |nil|).
@<그래프 키우기@>=
const arcsPerBlock = 102 // \CEE/ |gb_virgin_arc|의 블록 크기

func (g *Graph) ArcRecords() []*Arc {
	total := len(g.arcs)
	if r := total % arcsPerBlock; r != 0 {
		total += arcsPerBlock - r
	}
	records := make([]*Arc, total)
	copy(records, g.arcs)
	return records
}

// |SetArcStore|는 되살린 그래프의 호 레코드를 파일 순서대로 등록해,
// {\sc GB\_\,SAVE}가 그 그래프를 똑같이 다시 저장할 수 있게 한다.
func (g *Graph) SetArcStore(arcs []*Arc) {
	g.arcs = arcs
}

@ \GO/ 1.23이 들여온 범위 함수(range-over-func) 덕에, 앞서 손으로 풀어
썼던 두 겹 순회의 각 겹을 반복자 하나로 감쌀 수 있다. 정점 하나의 호
리스트를 훑는 |AllArcs|와, 그래프 하나의 정점들을 훑는 |AllVertices|다.
둘 다 |yield|가 |false|를 돌려주면 그 자리에서 멈추므로, 순회하는 |for|
안의 |break|가 제대로 먹는다. 이제 그래프의 모든 호는
|for v := range g.AllVertices()|와 |for a := range v.AllArcs()|를 겹쳐
방문하면 된다.

@<그래프 키우기@>=
// |AllArcs|는 정점 |v|에서 나가는 호들을 차례로 내주는 반복자다.
func (v *Vertex) AllArcs() iter.Seq[*Arc] {
	return func(yield func(*Arc) bool) {
		for a := v.Arcs; a != nil; a = a.Next {
			if !yield(a) {
				return
			}
		}
	}
}

// |AllVertices|는 그래프 |g|의 정점들을 차례로 내주는 반복자다.
func (g *Graph) AllVertices() iter.Seq[*Vertex] {
	return func(yield func(*Vertex) bool) {
		for i := range g.Vertices[:g.N] {
			if !yield(&g.Vertices[i]) {
				return
			}
		}
	}
}

@* 정점 찾기. 이름으로 정점을 찾고 싶을 때가 있고, 그것을 표준적인
방식으로 하면 좋다. \CEE/에는 루틴이 넷 있었다: 현재 그래프에 이름을 넣는
|hash_in|과 찾는 |hash_out|, 그리고 임의의 그래프에 대해 같은 일을 하는
|hash_setup|과 |hash_lookup|. 앞의 둘이 따로 있던 이유는 오직 전역
|cur_graph| 때문이었으므로, 그래프를 수신자로 받는 우리에게는
|HashIn|·|HashLookup|·|HashSetup| 셋이면 된다---|hash_out|은
|HashLookup|에 흡수되었다.

중요: 해시가 살아 있는 동안 각 정점의 유틸리티 필드 |U|와 |V|는 검색
루틴의 것이다. 이 값들을 직접 주무르거나 이 필드를 바꾸는 서브루틴을
쓰면 시스템이 무너질 수 있다. 해시 정보를 {\sc GB\_\,SAVE}로 저장할
작정이면 |UtilTypes|의 처음 두 자가 \.{VV}라야 한다.

경고: 이 해시 방식을 쓰는 동안 |g.N|을 보존해야 한다. |g.N|이 바뀌면
해시표는 휴지 조각이다---|HashSetup|으로 전부 다시 해싱하기 전에는.

@<정점 찾기@>=
const (
	hashMult  = 314159    // 무작위 곱수; 이 양반 파이($\pi$)를 참 좋아하는군.
	hashPrime = 516595003 // 27182818번째 소수; $2^{29}$보다 작다
)

@ 길이 $l$인 문자열 $c_1c_2\ldots c_l$의 해시 부호는 문자들의 비선형
함수인데, 0과 정점 수 사이에서 제법 무작위한 결과를 내는 듯하다. 더
단순한 방법들은 저자의 실험에서 눈에 띄게 나빴다고 한다. 곱수가
$\pi$의 앞자리 314159이고 소수가 $e$의 앞자리 27182818번째라는 것은
아마 우연이 아닐 것이다.

주의: 이 해시 부호는 시스템의 문자 부호에 의존한다. ASCII 기계에서
그래프를 만들어 {\sc GB\_\,SAVE}로 저장한 파일을 ASCII가 아닌 기계를
쓰는 친구에게 보낸다면, 그 친구는 |HashLookup|이 통하기 전에
|HashSetup|으로 해시 구조를 다시 지어야 한다. (\GO/의 문자열은 어디서나
같은 바이트열이니, 이 경고가 실전이 될 일은 이제 드물겠다.)

정점 |u|는 이름의 해시 부호 |h|에 대해 |g.Vertices[h%g.N]|이고, 해시
주소가 같은 정점들의 리스트가 |u.V.V|(머리)에서 시작해 |U.V|(링크)로
이어진다.
|hashVertex|는 이름 |t|의 해시 부호가 가리키는 자리의 정점을 준다.
@<정점 찾기@>=
func (g *Graph) hashVertex(t string) *Vertex {
	var h int64
	for i := range len(t) {
		h += (h ^ (h >> 1)) + hashMult*int64(t[i])
		for h >= hashPrime {
			h -= hashPrime
		}
	}
	return &g.Vertices[h%g.N]
}

@ |HashIn|은 정점 |v|의 이름을 |g|의 해시표에 넣는다.
@<정점 찾기@>=
func (g *Graph) HashIn(v *Vertex) {
	u := g.hashVertex(v.Name)
	v.U.V = u.V.V // v의 링크가 사슬의 옛 머리를 잇고
	u.V.V = v     // v가 새 머리가 된다
}

@ 해시 함수가 정말 무작위라면 문자열 비교 횟수의 평균은, 성공하는
검색에서 $(e^2+7)/8\approx1.80$, 실패하는 검색에서 $(e^2+1)/4\approx2.10$
미만이다[{\sl Sorting and Searching}, 6.4절, 식 (15)와 (16)].
|HashLookup|은 이름이 |s|인 정점을 |g|에서 찾는다(없으면 |nil|).
@<정점 찾기@>=
func (g *Graph) HashLookup(s string) *Vertex {
	if g == nil || g.N <= 0 {
		return nil
	}
	for u := g.hashVertex(s).V.V; u != nil; u = u.U.V {
		if u.Name == s {
			return u
		}
	}
	return nil
}

@ |HashSetup|은 |g|의 모든 정점으로 해시표를 새로 짓는다.
@<정점 찾기@>=
func (g *Graph) HashSetup() {
	if g == nil || g.N <= 0 {
		return
	}
	verts := g.Vertices[:g.N]
	for i := range verts {
		verts[i].V.V = nil
	}
	for i := range verts {
		g.HashIn(&verts[i])
	}
	g.SetUtilType(0, 'V') // 해시 링크와
	g.SetUtilType(1, 'V') // 해시 머리의 사용을 표시
}

@* 시험. 원본의 \.{test\_graph}에는 1000만 바이트를 할당해 보는 시험이
있었다---초안에서는 메모리가 바닥날 때까지 할당했는데, 그 전술이 몇몇
대형 시스템을 무릎 꿇려서 같은 기계에서 무고하게 제 일을 하던 이웃들에게
몹시 불친절했다는 반성문이 붙어 있다. 할당이 쓰레기 수거기의 소관이 된
지금 그 시험은 원본의 반성과 함께 퇴역시키고, 작은 그래프 시험만 옮긴다.

정점 둘에 이름을 붙이고, 간선 둘(하나는 자기 고리)과 홑호 하나를 만든
뒤, 원본과 똑같은 — 문자 연산과 그래프 통계를 한 식에 버무린---%
검사식으로 자료구조가 살아 있는지 본다.
@(gbgraph_test.go@>=
package gbgraph

import "testing"

func TestGraph(t *testing.T) {
	g := NewGraph(2)
	u, v := &g.Vertices[0], &g.Vertices[1]
	u.Name = "vertex 0"
	v.Name = "vertex 1"
	g.NewEdge(v, u, -1)
	g.NewEdge(u, u, 1)
	g.NewArc(v, u, -1)
	if int64(v.Name[7])+g.N != int64(v.Arcs.Next.Tip.Name[7])+g.M-2 {
		t.Fatal("그래프 자료구조가 아직 제대로 돌지 않는다")
	}
}

@ 원본은 이어서 edge trick이 통하는지 — 호 주소의 mod~8 비트가 기대대로
놓였는지 — 를 살폈다. 우리의 짝은 |Partner|이므로 그쪽을 검사한다:
홑호에는 짝이 없어야 하고, 간선의 두 호는 서로가 서로의 짝이며, 자기
고리는 \CEE/가 만들던 모양 그대로 첫 호의 |Next|가 곧 짝이어야 한다.
@(gbgraph_test.go@>=
func TestPartner(t *testing.T) {
	g := NewGraph(2)
	u, v := &g.Vertices[0], &g.Vertices[1]
	g.NewEdge(u, v, 3)
	g.NewArc(u, v, 4)
	if a := u.Arcs; a.Partner != nil {
		t.Fatal("홑호에 짝이 생겼다")
	}
	e := u.Arcs.Next // 간선의 |u|쪽 호
	if e.Partner == nil || e.Partner.Partner != e ||
		e.Partner.Tip != u || e.Partner != v.Arcs {
		t.Fatal("간선의 두 호가 짝을 이루지 못했다")
	}
	if e.Len != 3 || e.Partner.Len != 3 || g.M != 3 {
		t.Fatal("간선의 길이나 호 수가 틀렸다")
	}
	g.NewEdge(v, v, 7) // 자기 고리
	if s := v.Arcs; s.Tip != v || s.Next != s.Partner || s.Next.Tip != v {
		t.Fatal("자기 고리가 C의 모양대로 놓이지 않았다")
	}
}

@ 끝으로 해시 검색과 정점 번호 재주를 함께 시험한다. 이름들은 물론
\.{words.dat}의 첫 다섯 단어다.
@(gbgraph_test.go@>=
func TestHashAndIndex(t *testing.T) {
	g := NewGraph(5)
	names := []string{"aargh", "abaca", "abaci", "aback", "abaft"}
	for i := range g.Vertices[:g.N] {
		g.Vertices[i].Name = names[i]
	}
	g.HashSetup()
	if g.UtilTypes[:2] != "VV" || g.UtilTypes[2:] != "ZZZZZZZZZZZZ" {
		t.Fatalf("UtilTypes가 바르게 갱신되지 않았다 (%s)", g.UtilTypes)
	}
	for i, s := range names {
		v := g.HashLookup(s)
		if v == nil {
			t.Fatalf("%s를 찾지 못했다", s)
		}
		if g.Index(v) != int64(i) {
			t.Fatalf("%s의 번호가 %d로 나왔다", s, g.Index(v))
		}
	}
	if g.HashLookup("zzzzz") != nil {
		t.Fatal("없는 이름이 찾아졌다")
	}
}

@ 끝으로 두 반복자를 시험한다. |AllVertices|는 |g.N|개의 정점을 번호
순서대로 내주어야 하고, |AllArcs|는 정점의 호를 빠짐없이 내주되 |break|로
일찍 멈추면 그 자리에서 멎어야 한다.
@(gbgraph_test.go@>=
func TestIterators(t *testing.T) {
	g := NewGraph(3)
	u := &g.Vertices[0]
	g.NewEdge(u, &g.Vertices[1], 1)
	g.NewArc(u, &g.Vertices[2], 2)
	var got []int64
	for x := range g.AllVertices() {
		got = append(got, g.Index(x))
	}
	if len(got) != 3 || got[0] != 0 || got[1] != 1 || got[2] != 2 {
		t.Fatalf("AllVertices가 %v를 내줬다", got)
	}
	n := 0
	for range u.AllArcs() {
		n++
	}
	if n != 2 {
		t.Fatalf("u의 호 수가 %d로 나왔다", n)
	}
	n = 0
	for range u.AllArcs() {
		n++
		break
	}
	if n != 1 {
		t.Fatal("AllArcs가 break를 존중하지 않았다")
	}
}

@* 찾아보기.
