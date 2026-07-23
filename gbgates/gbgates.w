% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_gates.w를 Go로 이식한다.
@i ../gbtypes.w

\input kotexgweb
\def\title{GB\_\,GATES}
\def\flog{\mathop{\rm flog}\nolimits}
\def\down{\mathop{\rm down}\nolimits}

@* 들어가며. 이 모듈은 여섯 서브루틴을 내놓는다:
$$\vbox{\halign{\hfil#\hfil&\quad#\hfil\cr
|Risc|&간단한 RISC 컴퓨터의 논리에 바탕한 유향 무순환 그래프(dag)를 짓는다\cr
|Prod|&병렬 곱셈 회로의 논리에 바탕한 dag를 짓는다\cr
|PrintGates|&그런 dag를 기호로 찍는다\cr
|GateEval|&각 게이트에 불리언 값을 매겨 dag를 평가한다\cr
|PartialGates|&입력 게이트 일부에 무작위 값을 매겨 부분 그래프를 뽑는다\cr
|RunRisc|&|Risc|의 출력을 가지고 놀 수 있게 한다\cr}}$$
쓰임새는 데모 {\sc TAKE\_\,RISC}와 {\sc MULTIPLY}에서 볼 수 있다.

@ {\sc GB\_\,GATES}가 내는 dag는 논리 회로에 얽힌 특별한 규약을 가진 GraphBase
그래프다. 각 정점은 회로의 게이트 하나를 나타내고, 유틸리티 필드 |val|(우리의
|X.I|)은 그 게이트에 딸린 불리언 값이다. 유틸리티 필드 |typ|(|Y.I|)은 어떤
종류의 게이트인지 알려 주는 ASCII 부호로, 여섯 가지가 있다:
$$\vbox{\halign{\hfil#\hfil&\quad#\hfil\cr
|'I'|&입력 게이트. 값이 바깥에서 주어진다.\cr
|AND|&\.{AND} 게이트. 앞선 게이트 {\it 둘 이상\/}의 논리곱---그 게이트들이
  모두 1이면 1, 아니면 0.\cr
|OR|&\.{OR} 게이트. 앞선 게이트 둘 이상의 논리합---모두 0이면 0, 아니면 1.\cr
|XOR|&\.{XOR} 게이트. 앞선 게이트 둘 이상의 배타적 논리합---곧 그 값들의
  2를 법으로 한 합.\cr
|NOT|&인버터. 앞선 게이트 {\it 하나\/}의 값의 논리적 여집합.\cr
|'L'|&래치(latch). 값이 지난 이력에 달렸다.\cr}}$$
네 상수 |AND|·|OR|·|XOR|·|NOT|이 실제로 어떤 문자인지는 아래 |const| 묶음에
그대로 적혀 있다.

@ 래치의 값은 회로를 가장 최근에 평가했을 때 {\it 뒤에 오는\/} 어떤 게이트에
매겨졌던 값이고, 유틸리티 필드 |alt|(|Z.V|)가 바로 그 뒤 게이트를 가리킨다.
래치를 쓰면 회로에 ``상태(state)'' 정보를 담을 수 있다. 예컨대 |Risc|가 만드는
RISC 기계에서는 래치가 곧 레지스터에 대응한다. 반면 |Prod| 절차는 래치를 쓰지
않는다---곱셈 회로에는 기억할 상태가 없기 때문이다.

정점은 평가하기 편한 특별한 ``위상(topological)'' 차례로 놓인다: 입력 게이트가
모두 먼저 오고, 그다음 래치가 모두 오고, 그러고 나서 앞선 것들로부터 값이
셈해지는 나머지 게이트들이 온다. 그래프의 호는 각 게이트에서 그 인수로 가며,
어떤 게이트의 인수든 모두 그 게이트보다 앞선다. 그래서 정점을 배열 차례대로
한 번만 훑으면 회로 전체가 평가된다.

|g|가 이런 게이트 그래프를 가리킬 때, 유틸리티 필드 |outs|(|g.ZZ.A|)는 응용에
따라 쓰일 ``출력''을 나타내는 |Arc| 레코드 목록을 가리킨다. 예컨대 |Prod|가
만든 그래프의 출력은 입력 게이트가 나타내는 두 수의 곱의 각 비트에 대응한다.

@ 부분 평가를 뒷받침하려고 특별한 규약이 하나 더 있다. 출력 목록의 |tip| 필드는
정점을 가리키거나, 아니면 상수 0이나 1을 담는다. \CEE/에서는 이것이 말 그대로
포인터 자리에 정수 0·1을 숨겨 넣는 것이었고(|is_boolean(v)|가
|(unsigned long)(v)<=1|이었다), 그래서 출력을 읽을 때마다 상수인지 먼저
가려내야 했다.

\GO/에는 그런 재주가 없다. 대신 값이 각각 0과 1로 고정된 불변 센티넬 정점
|gateFalse|와 |gateTrue| 둘을 두어 이를 대신한다. 이들은 어느 그래프에도 속하지
않고 절대 바뀌지 않으므로, |tipValue|는 상수인지 따질 것 없이 언제나 |tip.X.I|를
읽으면 그만이다---\CEE/의 삼항 조건이 통째로 사라진 셈이다. 다만 응용 쪽에서는
출력이 상수인지 알아야 할 때가 있으므로(이를테면 회로의 깊이를 잴 때 상수
출력을 건너뛰려면), 공개 술어 |IsBoolean|을 내어 준다.

@ 유틸리티 필드를 정리하면 이렇다:
$$\vbox{\halign{\hfil#\hfil&\quad#\hfil&\quad#\hfil\cr
원본&\GO/&뜻\cr
\noalign{\smallskip\hrule\smallskip}
|val|&|X.I|&(정점) 불리언 값\cr
|typ|&|Y.I|&(정점) 게이트의 종류\cr
|alt|&|Z.V|&(정점) 래치가 값을 받아 오는 뒤 게이트\cr
|outs|&|ZZ.A|&(그래프) 출력 |Arc| 목록\cr}}$$
@d AND OR NOT XOR DELAY
@c
package gbgates

import (
	"fmt"
	"io"
	"strconv"
	"strings"
	@#
	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
)

const (
	AND   = '&'
	OR    = '|'
	NOT   = '~'
	XOR   = '^'
	DELAY = 100 // 게이트에서 인수로 가는 호의 길이
)

var (
	gateFalse = &gbgraph.Vertex{}                          // 상수 0 (|X.I=0|)
	gateTrue  = &gbgraph.Vertex{X: gbgraph.Util{I: 1}}     // 상수 1 (|X.I=1|)
)

func isBoolean(v *gbgraph.Vertex) bool { return v == gateFalse || v == gateTrue }
func theBoolean(v *gbgraph.Vertex) int64 { if v == gateTrue { return 1 }; return 0 }
func tipValue(v *gbgraph.Vertex) int64   { return v.X.I }
func boolGate(bit int64) *gbgraph.Vertex { if bit != 0 { return gateTrue }; return gateFalse }

// IsBoolean은 v가 상수 게이트(0이나 1)인지 알려주는 공개 술어다.
func IsBoolean(v *gbgraph.Vertex) bool { return isBoolean(v) }

@<게이트 만들기@>
@<GateEval@>
@<Risc 서브루틴@>
@<RunRisc 서브루틴@>
@<PrintGates 서브루틴@>
@<reduce 서브루틴@>
@<Prod 서브루틴@>
@<PartialGates 서브루틴@>

@ |GateEval| 절차부터 보자. 아주 단순한 데다, 방금 설명한 규약들이 어떻게
쓰이는지를 잘 보여 주기 때문이다.

게이트 그래프 |g|가 주어지면 |GateEval|은 |g|의 게이트마다 값을 매긴다.
|inVec|가 비어 있지 않으면 그것은 |'0'| 아니면 |'1'|인 문자들의 열이라야 하며,
회로의 앞쪽 게이트들에 차례대로 매겨진다. 비어 있으면 입력 게이트에 이미 알맞은
값이 들어 있다고 보고 건드리지 않는다. |inVec|의 비트를 다 쓴 뒤에는 나머지
게이트마다 값을 새로 셈한다.

원본은 호출자가 |m+1|글자를 담을 자리를 |out_vec|로 넘겨 주면 거기에 출력 값
문자열을 적어 주었다(|m|은 |g|의 출력 수). \GO/에서는 그냥 문자열을 돌려준다.
함께 돌려주는 코드는 성공이면 0, 모르는 종류의 게이트를 만나면 $-1$(그 자리에서
평가를 그만둔다), 그래프가 |nil|이면 $-2$다.

@<GateEval@>=
func GateEval(g *gbgraph.Graph, inVec string) (string, int64) {
	if g == nil {
		return "", -2 // 그래프가 없다
	}
	vi := 0
	for i := 0; i < len(inVec) && vi < int(g.N); i++ {
		g.Vertices[vi].X.I = int64(inVec[i] - '0')
		vi++
	}
	for ; vi < int(g.N); vi++ {
		v := &g.Vertices[vi]
		var t int64
		@<게이트 |v|의 값 |t|를 셈한다@>
		v.X.I = t
	}
	@<출력 값을 문자열로 모은다@>
}

@ @<게이트 |v|의 값 |t|를 셈한다@>=
switch v.Y.I {
case 'I':
	continue // 입력 게이트 값은 밖에서 매긴다
case 'L':
	t = v.Z.V.X.I // |alt.val|
case AND:
	t = 1
	for a := range v.AllArcs() {
		t &= a.Tip.X.I
	}
case OR:
	t = 0
	for a := range v.AllArcs() {
		t |= a.Tip.X.I
	}
case XOR:
	t = 0
	for a := range v.AllArcs() {
		t ^= a.Tip.X.I
	}
case NOT:
	t = 1 - v.Arcs.Tip.X.I
default:
	return "", -1 // 모르는 게이트 종류
}

@ @<출력 값을 문자열로 모은다@>=
var sb strings.Builder
for a := g.ZZ.A; a != nil; a = a.Next {
	sb.WriteByte(byte('0' + tipValue(a.Tip)))
}
return sb.String(), 0

@* 게이트 만들기.
RISC 논리를 짓는 잔심부름들이다. |builder|는 \CEE/의 정적 전역(다음 정점,
이름 접두사, 일련번호)을 담아 패키지 수준 가변 상태를 피한다. |newVert|는 새
게이트에 이름과 종류를 매긴다. 접두사가 지금 짓는 논리의 부분을 나타내고,
|count|가 음수면 일련번호 없이 접두사만 이름으로 삼는다.

@<게이트 만들기@>=
type builder struct {
	g      *gbgraph.Graph
	nextV  int    // 아직 이름을 안 매긴 첫 정점
	prefix string // 정점 이름의 접두사
	count  int64  // 정점 이름의 일련번호
}

func (b *builder) newVert(t int64) *gbgraph.Vertex {
	v := &b.g.Vertices[b.nextV]
	b.nextV++
	if b.count < 0 {
		v.Name = b.prefix
	} else {
		v.Name = b.prefix + strconv.FormatInt(b.count, 10)
		b.count++
	}
	v.Y.I = t
	return v
}

@ |vAt|은 |i|번째 정점을, |at|은 |v|에서 |k|만큼 뒤의 정점을 준다 --- \CEE/의
포인터 산술(|reg[r]+k|, |x+j|)을 |Index|로 옮긴 것이다. |startPrefix|와
|numericPrefix|는 접두사를 새로 세운다.

@<게이트 만들기@>=
func (b *builder) vAt(i int64) *gbgraph.Vertex { return &b.g.Vertices[i] }

func (b *builder) at(v *gbgraph.Vertex, k int64) *gbgraph.Vertex {
	return &b.g.Vertices[b.g.Index(v)+k]
}

func (b *builder) startPrefix(s string) { b.prefix = s; b.count = 0 }

func (b *builder) numericPrefix(a byte, n int64) {
	b.prefix = fmt.Sprintf("%c%d:", a, n)
	b.count = 0
}

func (b *builder) firstOf(n int, t int64) *gbgraph.Vertex {
	first := b.newVert(t)
	for k := 1; k < n; k++ {
		b.newVert(t)
	}
	return first
}

@ 인수 2, 3, 4, 5개짜리 게이트를 만드는 시시한 루틴들이다. 게이트에서 인수로
가는 호는 길이 |DELAY|다. \CEE/는 인수 평가 순서를 강제하려 |do2|~|do5| 매크로를
썼지만, \GO/는 함수 인수를 왼쪽에서 오른쪽으로 평가한다고 못박으므로 그냥
|make2|~|make5|를 인라인 식으로 부르면 된다.

@<게이트 만들기@>=
func (b *builder) make2(t int64, v1, v2 *gbgraph.Vertex) *gbgraph.Vertex {
	v := b.newVert(t)
	b.g.NewArc(v, v1, DELAY)
	b.g.NewArc(v, v2, DELAY)
	return v
}

func (b *builder) make3(t int64, v1, v2, v3 *gbgraph.Vertex) *gbgraph.Vertex {
	v := b.make2(t, v1, v2)
	b.g.NewArc(v, v3, DELAY)
	return v
}

func (b *builder) make4(t int64, v1, v2, v3, v4 *gbgraph.Vertex) *gbgraph.Vertex {
	v := b.make3(t, v1, v2, v3)
	b.g.NewArc(v, v4, DELAY)
	return v
}

func (b *builder) make5(t int64, v1, v2, v3, v4, v5 *gbgraph.Vertex) *gbgraph.Vertex {
	v := b.make4(t, v1, v2, v3, v4)
	b.g.NewArc(v, v5, DELAY)
	return v
}

@ 유틸리티 필드 |bar|(|W.V|)에 게이트의 여(complement)를 담아, 서로 같은 게이트가
잔뜩 생기는 것을 막는다. |comp|는 여 게이트를 준다(없으면 만든다). |evenComp|는
|s|가 홀수면 |v| 그대로, 짝수면 |comp(v)|를 준다 --- 순서를 뒤집으면 안 된다.
|makeXor|는 두 \.{AND}의 \.{OR}로 배타적 논리합을 짓는다.

@<게이트 만들기@>=
func (b *builder) comp(v *gbgraph.Vertex) *gbgraph.Vertex {
	if v.W.V != nil {
		return v.W.V
	}
	u := &b.g.Vertices[b.nextV]
	b.nextV++
	u.W.V, v.W.V = v, u
	u.Name = v.Name + "~"
	u.Y.I = NOT
	b.g.NewArc(u, v, 1)
	return u
}

func (b *builder) evenComp(s int64, v *gbgraph.Vertex) *gbgraph.Vertex {
	if s&1 != 0 {
		return v
	}
	return b.comp(v)
}

func (b *builder) makeXor(u, v *gbgraph.Vertex) *gbgraph.Vertex {
	t1 := b.make2(AND, u, b.comp(v))
	t2 := b.make2(AND, b.comp(u), v)
	return b.make2(OR, t1, t2)
}

@* RISC 넷리스트. |Risc(regs)|는 |regs|개의 레지스터를 가진 게이트 그래프를
짓는다. |regs|는 2와 16 사이라야 하고, 아니면 16으로 맞춘다. 게이트 총수는
|1400+115*regs|로 밝혀졌으니, |regs=2|일 때 1630, |regs=16|일 때 3240 사이에
놓인다. \.{XOR} 게이트는 쓰지 않고, 배타적 논리합이 필요한 자리에서는
\.{AND}·\.{OR}·인버터로 그 효과를 낸다.

이 문서만으로도 읽을 수 있도록, 이 회로가 흉내내는 RISC 기계의 명세를 아래에
그대로 옮겨 적는다.

이 RISC 기계는 16비트 레지스터와 16비트 데이터 낱말을 다룬다. 메모리에 쓰지는
못하고, 바깥의 읽기 전용 메모리가 있다고 본다. 회로에는 출력 16개(메모리 주소
레지스터의 16비트)와 입력 17개가 있는데, 입력의 마지막 16개는 앞 주기에 셈한
메모리 주소의 내용으로 채워진다. 그래서 |GateEval| 호출 사이에 메모리를 읽어
기계를 돌릴 수 있다. 첫 입력 비트 \.{RUN}은 보통 1이고, 0이면 다른 입력은
무시되며 모든 레지스터와 출력이 0으로 지워진다. 메모리 입력 비트는 리틀엔디언
(최하위 비트 먼저), 출력 주소 비트는 빅엔디언(최상위 먼저)이다.
메모리에서 읽은 낱말은 다음 형식의 명령어로 풀이된다:

$$\vbox{\offinterlineskip
 \def\\#1&{\omit&#1&}
 \hrule
 \halign{&\vrule#&\strut\sevenrm\hbox to 1.7em{\hfil#\hfil}\cr
 height 5pt&\multispan7\hfill&&\multispan7\hfill&&\multispan3\hfill
  &&\multispan3\hfill&&\multispan7\hfill&\cr
 &\multispan7\hfill\.{DST}\hfill&&\multispan7\hfill\.{MOD}\hfill
  &&\multispan3\hfill\.{OP}\hfill&&\multispan3\hfill\.{A}\hfill
  &&\multispan7\hfill\.{SRC}\hfill&\cr
 height 5pt&\multispan7\hfill&&\multispan7\hfill&&\multispan3\hfill
  &&\multispan3\hfill&&\multispan7\hfill&\cr
 \noalign{\hrule}
 \\15&\\14&\\13&\\12&\\11&\\10&\\9&\\8&\\7&\\6&\\5&\\4&\\3&\\2&\\1&%
  \\0&\omit\cr}}$$
\.{SRC}와 \.A 필드는 ``원본(source)'' 값을 정한다. $\.A=0$이면 원본은
\.{SRC}를 $-8$과 $+7$ 사이의 4비트 부호수로 본 값이고, $\.A=1$이면 레지스터
\.{DST}의 내용에 (부호 있는) \.{SRC}를 더한 값, $\.A=2$이면 레지스터 \.{SRC}의
내용, $\.A=3$이면 레지스터 \.{SRC}가 가리키는 메모리 자리의 내용이다. 예컨대
$\.{DST}=3$, $\.{SRC}=10$이고 \.{r3}에 17, \.{r10}에 1009이 들었다면, 원본값은
$\.A=0$일 때 $-6$, $\.A=1$일 때 $17-6=11$, $\.A=2$일 때 1009, $\.A=3$일 때
메모리 1009번지의 내용이다.

\.{DST} 필드는 목적 레지스터 번호다. 이 레지스터는 \.{OP}·\.{MOD}가 정한
연산에 따라 옛 값과 원본값으로부터 새 값을 받는다. $\.{OP}=0$이면 일반 논리
연산을 한다: \.{MOD} 비트를 왼쪽부터 $\mu_{11}\mu_{10}\mu_{01}\mu_{00}$이라
할 때, 목적 레지스터의 $k$번째 비트가 $i$, 원본값의 $k$번째 비트가 $j$이면 그
비트를 $\mu_{ij}$로 바꾼다. 이를테면 $\.{MOD}=1010$이면 원본을 그대로 복사,
$0110$이면 배타적 논리합, $0011$이면 목적을 여로 바꾼다(원본 무시).

기계에는 상태 비트 넷이 있다: \.S(부호), \.N(0 아님), \.K(자리 올림),
\.V(넘침). 모든 일반 논리 연산은 새 결과의 부호(최상위 비트 15)를 \.S에 넣고,
나머지 15비트 가운데 하나라도 1이면 \.N을 1로, 다 0이면 0으로 놓는다. 곧 결과가
온통 0일 때에만 \.S와 \.N이 함께 0이 된다. 논리 연산은 \.K·\.V를 바꾸지 않는다.

$\.{OP}=2$는 조건부 적재로 \.S·\.N을 검사한다: \.{MOD} 비트 $\mu_{ij}=1$일
때에만 원본값을 목적에 싣는다($i$, $j$는 현재 \.S, \.N). 예컨대 $\.{MOD}=0011$
이면 \.S$=0$일 때만(마지막 결과가 0 이상이었을 때만) 싣고, $\.{MOD}=1111$이면
늘 실어 \.S·\.N을 건드리지 않고 원본을 목적으로 옮긴다. $\.{OP}=3$도 비슷하되
\.S·\.N 대신 \.K·\.V를 검사한다.

$\.{OP}=1$이면 초보적 산술을 한다. \.{MOD}에 따라 갈리는데, $\.{MOD}=0{\to}7$은
원본값을 자리 옮긴 값을 목적에 넣는다: $0$은 왼쪽 1칸(2배), $1$은 왼쪽 순환
1칸, $2$는 왼쪽 4칸(16배), $3$은 왼쪽 순환 4칸, $4$는 오른쪽 1칸(2로 나눠 내림),
$5$는 부호 없는 오른쪽 1칸, $6$은 오른쪽 4칸, $7$은 부호 없는 오른쪽 4칸이다.
자리 옮김은 \.S·\.N과 함께 \.K·\.V도 바꾼다: 왼쪽 옮김은 왼쪽으로 밀려난 비트에
1이 있으면 \.K를, 곱셈 넘침이 나면 \.V를 1로 놓고, 오른쪽 옮김은 밀려난 비트를
\.K에 담는다.

$\.{MOD}=8$이면 원본값을 목적에 더하고 \.S·\.N·\.V를 여느 때처럼, \.K를 부호
없는 16비트 자리 올림으로 놓는다. $\.{MOD}=9$는 여기에 현재 \.K도 더한다 --- 그래서
32비트 수의 아래 절반에 $\.{MOD}=8$을, 위 절반에 $\.{MOD}=9$를 쓰면 부호·자리
올림까지 맞는 32비트 결과를 얻는다. $\.{MOD}=10$은 목적에서 원본값을 빼고(이때
\.K는 ``빌림''), $\.{MOD}=11$은 현재 \.K도 빼 32비트 뺄셈을 이룬다.
$\.{MOD}=12,13,14$는 ``앞날을 위해 남겨 둔'' 것으로, 목적과 상태 비트 넷을 모두
0으로 놓을 뿐이다. $\.{MOD}=15$는 \.{JUMP}로, \.S·\.N·\.K·\.V를 건드리지 않는다.

레지스터 0은 남다르다: 현재 명령어의 자리다. 그러니 레지스터 0의 내용을 바꾸면
프로그램의 흐름을 바꾸는 셈이다. 바꾸지 않으면 저절로 1씩 는다. 특별한 경우로
$\.A=3$이고 $\.{SRC}=0$이면, 원래 규칙대로면 원본값이 레지스터 0이 가리키는
메모리(곧 현재 명령어)여야 하지만, 기계는 그 {\sl다음\/} 자리를 16비트 원본
피연산자로 삼는다. 이런 두 낱말 명령어가 레지스터 0을 바꾸지 않으면 레지스터
0은 1 대신 2 늘어난다. \.{JUMP} 명령은 원본값을 레지스터 0으로 옮겨 흐름을
바꾸고, $\.{DST}\ne0$이면 레지스터 \.{DST}에 \.{JUMP} 다음 명령어의 자리를 넣는다
--- 어셈블리 프로그래머라면 이를 서브루틴 호출로 알아볼 것이다. 예제 프로그램은
{\sc TAKE\_\,RISC} 모듈에 있다.

@<Risc 서브루틴@>=
func Risc(regs int64) (*gbgraph.Graph, error) {
	if regs < 2 || regs > 16 {
		regs = 16
	}
	b := &builder{g: gbgraph.NewGraph(1400 + 115*regs)}
	b.g.ID = fmt.Sprintf("risc(%d)", regs)
	b.g.UtilTypes = "ZZZIIVZZZZZZZA"
	@<RISC 지역 변수@>
	@<입력과 래치를 만든다@>
	@<명령어 해독 게이트를 만든다@>
	@<원본값을 가져오는 게이트를 만든다@>
	@<일반 논리 연산 게이트를 만든다@>
	@<조건부 적재 연산 게이트를 만든다@>
	@<산술 연산 게이트를 만든다@>
	@<모든 것을 알맞게 모으는 게이트를 만든다@>
	if b.nextV != int(b.g.N) {
		return nil, gbgraph.Impossible // 게이트 수를 잘못 셌다
	}
	return b.g, nil
}

@ RISC 논리를 짓는 동안 쓰는 게이트 포인터들이다. 대부분 16비트(또는 상태·자리
올림까지 18비트) 배열이다.

@<RISC 지역 변수@>=
var (
	mem                                    [16]*gbgraph.Vertex
	reg                                    [16]*gbgraph.Vertex
	mod, dest                              [4]*gbgraph.Vertex
	destMatch, oldDest, oldSrc, incDest    [16]*gbgraph.Vertex
	source, log, nextLoc, nextNextLoc      [16]*gbgraph.Vertex
	tmp                                    [16]*gbgraph.Vertex
	shift, sum, diff, result               [18]*gbgraph.Vertex
	runBit, prog, sign, nonzero, carry     *gbgraph.Vertex
	overflow, extra, imm, rel, dir, ind    *gbgraph.Vertex
	op, cond, change, jump, nextra         *gbgraph.Vertex
	nzs, nzd, up, down, skip, hop          *gbgraph.Vertex
	normal, special, t5                    *gbgraph.Vertex
	k, r                                   int64
)
latchit := func(u, latch *gbgraph.Vertex) {
	latch.Z.V = b.make2(AND, u, runBit) // |u&runBit|가 래치의 새 값
}

@ 입력과 래치를 위상 차례로 만든다. |runBit|·|mem|이 입력(|'I'|)이고, 나머지는
모두 래치(|'L'|)다.

@<입력과 래치를 만든다@>=
b.prefix, b.count = "RUN", -1
runBit = b.newVert('I')
b.startPrefix("M")
for k = 0; k < 16; k++ {
	mem[k] = b.newVert('I')
}
b.startPrefix("P")
prog = b.firstOf(10, 'L')
for _, nm := range []string{"S", "N", "K", "V", "X"} {
	b.prefix, b.count = nm, -1
	switch nm {
	case "S":
		sign = b.newVert('L')
	case "N":
		nonzero = b.newVert('L')
	case "K":
		carry = b.newVert('L')
	case "V":
		overflow = b.newVert('L')
	case "X":
		extra = b.newVert('L')
	}
}
for r = 0; r < regs; r++ {
	b.numericPrefix('R', r)
	reg[r] = b.firstOf(16, 'L')
}

@ 여섯째 줄은 |op|를 논리식
$(\.{extra}\land\.{prog})\lor(\lnot\.{extra}\land\.{mem}[6])$으로 옮긴다.
이것을 알면 나머지 알쏭달쏭한 코드도 읽을 수 있다.

@<명령어 해독 게이트를 만든다@>=
b.startPrefix("D")
imm = b.make3(AND, b.comp(extra), b.comp(mem[4]), b.comp(mem[5])) // $\.A=0$
rel = b.make3(AND, b.comp(extra), mem[4], b.comp(mem[5]))         // $\.A=1$
dir = b.make3(AND, b.comp(extra), b.comp(mem[4]), mem[5])         // $\.A=2$
ind = b.make3(AND, b.comp(extra), mem[4], mem[5])                 // $\.A=3$
op = b.make2(OR, b.make2(AND, extra, prog), b.make2(AND, b.comp(extra), mem[6]))
cond = b.make2(OR, b.make2(AND, extra, b.at(prog, 1)), b.make2(AND, b.comp(extra), mem[7]))
for k = 0; k < 4; k++ {
	mod[k] = b.make2(OR, b.make2(AND, extra, b.at(prog, 2+k)),
		b.make2(AND, b.comp(extra), mem[8+k]))
	dest[k] = b.make2(OR, b.make2(AND, extra, b.at(prog, 6+k)),
		b.make2(AND, b.comp(extra), mem[12+k]))
}

@ @<원본값을 가져오는 게이트를 만든다@>=
b.startPrefix("F")
@<|oldDest|를 목적 레지스터의 현재 값으로 놓는다@>
@<|oldSrc|를 원본 레지스터의 현재 값으로 놓는다@>
@<|incDest|를 |oldDest| 더하기 \.{SRC}로 놓는다@>
for k = 0; k < 16; k++ {
	mk := 3
	if k < 4 {
		mk = int(k)
	}
	source[k] = b.make4(OR,
		b.make2(AND, imm, mem[mk]),
		b.make2(AND, rel, incDest[k]),
		b.make2(AND, dir, oldSrc[k]),
		b.make2(AND, extra, mem[k]))
}

@ 여기와 바로 다음 절에서 입력이 최대 16개(실제로는 |regs|개)일 수 있는 \.{OR}
게이트 |oldDest[k]|·|oldSrc[k]|를 만든다. 다른 모든 게이트는 입력이 많아야 5개다.

@<|oldDest|를 목적 레지스터의 현재 값으로 놓는다@>=
for r = 0; r < regs; r++ {
	destMatch[r] = b.make4(AND, b.evenComp(r, dest[0]), b.evenComp(r>>1, dest[1]),
		b.evenComp(r>>2, dest[2]), b.evenComp(r>>3, dest[3]))
}
for k = 0; k < 16; k++ {
	for r = 0; r < regs; r++ {
		tmp[r] = b.make2(AND, destMatch[r], b.at(reg[r], k))
	}
	oldDest[k] = b.newVert(OR)
	for r = 0; r < regs; r++ {
		b.g.NewArc(oldDest[k], tmp[r], DELAY)
	}
}

@ @<|oldSrc|를 원본 레지스터의 현재 값으로 놓는다@>=
for k = 0; k < 16; k++ {
	for r = 0; r < regs; r++ {
		tmp[r] = b.make5(AND, b.at(reg[r], k), b.evenComp(r, mem[0]),
			b.evenComp(r>>1, mem[1]), b.evenComp(r>>2, mem[2]), b.evenComp(r>>3, mem[3]))
	}
	oldSrc[k] = b.newVert(OR)
	for r = 0; r < regs; r++ {
		b.g.NewArc(oldSrc[k], tmp[r], DELAY)
	}
}

@ @<일반 논리 연산 게이트를 만든다@>=
b.startPrefix("L")
for k = 0; k < 16; k++ {
	log[k] = b.make4(OR,
		b.make3(AND, mod[0], b.comp(oldDest[k]), b.comp(source[k])),
		b.make3(AND, mod[1], b.comp(oldDest[k]), source[k]),
		b.make3(AND, mod[2], oldDest[k], b.comp(source[k])),
		b.make3(AND, mod[3], oldDest[k], source[k]))
}

@ @<조건부 적재 연산 게이트를 만든다@>=
b.startPrefix("C")
tmp[0] = b.make4(OR,
	b.make3(AND, mod[0], b.comp(sign), b.comp(nonzero)),
	b.make3(AND, mod[1], b.comp(sign), nonzero),
	b.make3(AND, mod[2], sign, b.comp(nonzero)),
	b.make3(AND, mod[3], sign, nonzero))
tmp[1] = b.make4(OR,
	b.make3(AND, mod[0], b.comp(carry), b.comp(overflow)),
	b.make3(AND, mod[1], b.comp(carry), overflow),
	b.make3(AND, mod[2], carry, b.comp(overflow)),
	b.make3(AND, mod[3], carry, overflow))
change = b.make3(OR, b.comp(cond), b.make2(AND, tmp[0], b.comp(op)), b.make2(AND, tmp[1], op))

@ 하드웨어는 늘 모든 연산을 다 해 놓고 필요한 결과만 고른다는 점만 빼면
소프트웨어와 같다.

@<모든 것을 알맞게 모으는 게이트를 만든다@>=
b.startPrefix("Z")
@<|nextLoc|과 |nextNextLoc| 비트 게이트를 만든다@>
@<|result| 비트 게이트를 만든다@>
@<레지스터 1부터 |regs|까지의 새 값 게이트를 만든다@>
@<\.S, \.N, \.K, \.V의 새 값 게이트를 만든다@>
@<프로그램 레지스터와 |extra|의 새 값 게이트를 만든다@>
@<레지스터 0과 메모리 주소 레지스터의 새 값 게이트를 만든다@>

@ @<|nextLoc|과 |nextNextLoc| 비트 게이트를 만든다@>=
nextLoc[0] = b.comp(reg[0])
nextNextLoc[0] = reg[0]
nextLoc[1] = b.makeXor(b.at(reg[0], 1), reg[0])
nextNextLoc[1] = b.comp(b.at(reg[0], 1))
t5 = b.at(reg[0], 1)
for k = 2; k < 16; k++ {
	nextLoc[k] = b.makeXor(b.at(reg[0], k), b.make2(AND, reg[0], t5))
	nextNextLoc[k] = b.makeXor(b.at(reg[0], k), t5)
	t5 = b.make2(AND, t5, b.at(reg[0], k))
}

@ @<|result| 비트 게이트를 만든다@>=
jump = b.make5(AND, op, mod[0], mod[1], mod[2], mod[3]) // |cond=0|이라 가정
for k = 0; k < 16; k++ {
	result[k] = b.make5(OR,
		b.make2(AND, b.comp(op), log[k]),
		b.make2(AND, jump, nextLoc[k]),
		b.make3(AND, op, b.comp(mod[3]), shift[k]),
		b.make5(AND, op, mod[3], b.comp(mod[2]), b.comp(mod[1]), sum[k]),
		b.make5(AND, op, mod[3], b.comp(mod[2]), mod[1], diff[k]))
	result[k] = b.make2(OR,
		b.make3(AND, cond, change, source[k]),
		b.make2(AND, b.comp(cond), result[k]))
}
for k = 16; k < 18; k++ { // 결과의 자리 올림·넘침 비트
	result[k] = b.make3(OR,
		b.make3(AND, op, b.comp(mod[3]), shift[k]),
		b.make5(AND, op, mod[3], b.comp(mod[2]), b.comp(mod[1]), sum[k]),
		b.make5(AND, op, mod[3], b.comp(mod[2]), mod[1], diff[k]))
}

@ 메모리에서 한 낱말을 더 가져오려 한 주기를 더 쓸 때 |prog|와 |extra|가
필요하다. 첫 주기엔 |ind|가 참이라 ``결과''는 셈하되 안 쓰이고, 둘째 주기엔
|extra|가 참이다.

@<프로그램 레지스터와 |extra|의 새 값 게이트를 만든다@>=
for k = 0; k < 10; k++ {
	latchit(mem[k+6], b.at(prog, k))
}
nextra = b.make2(OR, b.make2(AND, ind, b.comp(cond)), b.make2(AND, ind, change))
latchit(nextra, extra)
nzs = b.make4(OR, mem[0], mem[1], mem[2], mem[3])
nzd = b.make4(OR, dest[0], dest[1], dest[2], dest[3])

@ @<레지스터 1부터 |regs|까지의 새 값 게이트를 만든다@>=
t5 = b.make2(AND, change, b.comp(ind)) // 목적 레지스터가 바뀌어야 하나?
for r = 1; r < regs; r++ {
	t4 := b.make2(AND, t5, destMatch[r]) // 레지스터 |r|이 바뀌어야 하나?
	for k = 0; k < 16; k++ {
		t3 := b.make2(OR, b.make2(AND, t4, result[k]), b.make2(AND, b.comp(t4), b.at(reg[r], k)))
		latchit(t3, b.at(reg[r], k))
	}
}

@ @<\.S, \.N, \.K, \.V의 새 값 게이트를 만든다@>=
t5 = b.make4(OR,
	b.make2(AND, sign, cond),
	b.make2(AND, sign, jump),
	b.make2(AND, sign, ind),
	b.make4(AND, result[15], b.comp(cond), b.comp(jump), b.comp(ind)))
latchit(t5, sign)
t5 = b.make4(OR,
	b.make4(OR, result[0], result[1], result[2], result[3]),
	b.make4(OR, result[4], result[5], result[6], result[7]),
	b.make4(OR, result[8], result[9], result[10], result[11]),
	b.make4(OR, result[12], result[13], result[14],
		b.make5(AND, b.make2(OR, nonzero, sign), op, mod[0], b.comp(mod[2]), mod[3])))
t5 = b.make4(OR,
	b.make2(AND, nonzero, cond),
	b.make2(AND, nonzero, jump),
	b.make2(AND, nonzero, ind),
	b.make4(AND, t5, b.comp(cond), b.comp(jump), b.comp(ind)))
latchit(t5, nonzero)
t5 = b.make5(OR,
	b.make2(AND, overflow, cond),
	b.make2(AND, overflow, jump),
	b.make2(AND, overflow, b.comp(op)),
	b.make2(AND, overflow, ind),
	b.make5(AND, result[17], b.comp(cond), b.comp(jump), b.comp(ind), op))
latchit(t5, overflow)
t5 = b.make5(OR,
	b.make2(AND, carry, cond),
	b.make2(AND, carry, jump),
	b.make2(AND, carry, b.comp(op)),
	b.make2(AND, carry, ind),
	b.make5(AND, result[16], b.comp(cond), b.comp(jump), b.comp(ind), op))
latchit(t5, carry)

@ 가장 까다로운 경우를 마지막에 남겨 두었다. \.{JUMP} 명령($\.A=3$)이 가장
미묘한데, $\.{SRC}=0$이면 첫 주기에 레지스터 0을 1 늘려 다음 주기의 |result|가
맞게 한다.

@<레지스터 0과 메모리 주소 레지스터의 새 값 게이트를 만든다@>=
skip = b.make2(AND, cond, b.comp(change)) // 거짓 조건?
hop = b.make2(AND, b.comp(cond), jump)    // \.{JUMP} 명령?
normal = b.make4(OR,
	b.make2(AND, skip, b.comp(ind)),
	b.make2(AND, skip, nzs),
	b.make3(AND, b.comp(skip), ind, b.comp(nzs)),
	b.make3(AND, b.comp(skip), b.comp(hop), nzd))
special = b.make3(AND, b.comp(skip), ind, nzs)
for k = 0; k < 16; k++ {
	t5 = b.make4(OR,
		b.make2(AND, normal, nextLoc[k]),
		b.make4(AND, skip, ind, b.comp(nzs), nextNextLoc[k]),
		b.make3(AND, hop, b.comp(ind), source[k]),
		b.make5(AND, b.comp(skip), b.comp(hop), b.comp(ind), b.comp(nzd), result[k]))
	t4 := b.make2(OR, b.make2(AND, special, b.at(reg[0], k)), b.make2(AND, b.comp(special), t5))
	latchit(t4, b.at(reg[0], k))
	t4 = b.make2(OR, b.make2(AND, special, oldSrc[k]), b.make2(AND, b.comp(special), t5))
	@<메모리 주소 비트 하나를 출력 목록에 넣는다@>
}

@ 출력 비트의 호는 빅엔디언 차례로 나타난다.

@<메모리 주소 비트 하나를 출력 목록에 넣는다@>=
a := b.g.VirginArc()
a.Tip = b.make2(AND, t4, runBit)
a.Next = b.g.ZZ.A
b.g.ZZ.A = a

@* 직렬 덧셈. |Risc|에서 덧셈과 뺄셈을 맡는 부분은 아직 밝히지 않았다. 어쩐지
그 부분은 나머지와 떨어져 있고 싶어 했다. |makeAdder(n,x,y,z,carry,add)|는
|n|비트 배열 |x|·|y|를
(|add|이 참) 빼서 |(n+1)|비트 배열 |z|에 담는다. |carry|가 |nil|이 아니면 그
게이트를 |y|에 먼저 더한다.

여기서는 |n|비트 덧셈을 |(n-1)|비트 덧셈으로 줄이는 단순한 |n|단 직렬 방식이면
넉넉하다. (문제 크기를 |n|에서 $n/\phi$로 줄여 효율을 얻는 병렬 가산기는 뒤의
|Prod| 루틴에 나온다.) 그리고 요긴한 항등식
$$x-y=\overline{\overline x+y}$$
을 써서 뺄셈을 덧셈으로 돌린다---따로 감산기를 만들 필요가 없다.

@<Risc 서브루틴@>=
func (b *builder) makeAdder(n int, x, y, z []*gbgraph.Vertex, carry *gbgraph.Vertex, add int64) {
	k := 0
	if carry == nil {
		z[0] = b.makeXor(x[0], y[0])
		carry = b.make2(AND, b.evenComp(add, x[0]), y[0])
		k = 1
	}
	for ; k < n; k++ {
		b.comp(x[k])
		b.comp(y[k])
		b.comp(carry) // 여 게이트를 만들어 둔다
		z[k] = b.make4(OR,
			b.make3(AND, x[k], b.comp(y[k]), b.comp(carry)),
			b.make3(AND, b.comp(x[k]), y[k], b.comp(carry)),
			b.make3(AND, b.comp(x[k]), b.comp(y[k]), carry),
			b.make3(AND, x[k], y[k], carry))
		carry = b.make3(OR,
			b.make2(AND, b.evenComp(add, x[k]), y[k]),
			b.make2(AND, b.evenComp(add, x[k]), carry),
			b.make2(AND, y[k], carry))
	}
	z[n] = carry
}

@ 첫째로, $|oldDest|+\.{SRC}$의 하위 4비트를 4비트 가산기로 셈한다. 나머지 12
비트는 더 간단하다.

@<|incDest|를 |oldDest| 더하기 \.{SRC}로 놓는다@>=
b.makeAdder(4, oldDest[:], mem[:], incDest[:], nil, 1)
up = b.make2(AND, incDest[4], b.comp(mem[3]))  // 나머지 비트는 늘어야 한다
down = b.make2(AND, b.comp(incDest[4]), mem[3]) // 나머지 비트는 줄어야 한다
for k = 4; ; k++ {
	b.comp(up)
	b.comp(down)
	incDest[k] = b.make3(OR,
		b.make2(AND, b.comp(oldDest[k]), up),
		b.make2(AND, b.comp(oldDest[k]), down),
		b.make3(AND, oldDest[k], b.comp(up), b.comp(down)))
	if k < 15 {
		up = b.make2(AND, up, oldDest[k])
		down = b.make2(AND, down, b.comp(oldDest[k]))
	} else {
		break
	}
}

@ 둘째로, 네 덧셈·뺄셈 명령을 위해 16비트 가산기와 16비트 감산기가 필요하다.

@<산술 연산 게이트를 만든다@>=
b.startPrefix("A")
@<자리 옮김 연산 게이트를 만든다@>
b.makeAdder(16, oldDest[:], source[:], sum[:], b.make2(AND, carry, mod[0]), 1)  // 가산기
b.makeAdder(16, oldDest[:], source[:], diff[:], b.make2(AND, carry, mod[0]), 0) // 감산기
sum[17] = b.make2(OR,
	b.make3(AND, oldDest[15], source[15], b.comp(sum[15])),
	b.make3(AND, b.comp(oldDest[15]), b.comp(source[15]), sum[15])) // 넘침
diff[17] = b.make2(OR,
	b.make3(AND, oldDest[15], b.comp(source[15]), b.comp(diff[15])),
	b.make3(AND, b.comp(oldDest[15]), source[15], diff[15])) // 넘침

@ @<자리 옮김 연산 게이트를 만든다@>=
for k = 0; k < 16; k++ {
	@<자리 옮김 비트 |shift[k]|를 만든다@>
}
shift[16] = b.make4(OR,
	b.make2(AND, b.comp(mod[2]), source[15]),
	b.make3(AND, b.comp(mod[2]), mod[1], b.make3(OR, source[14], source[13], source[12])),
	b.make3(AND, mod[2], b.comp(mod[1]), source[0]),
	b.make3(AND, mod[2], mod[1], source[3])) // ``자리 올림''
shift[17] = b.make3(OR,
	b.make3(AND, b.comp(mod[2]), b.comp(mod[1]), b.makeXor(source[15], source[14])),
	b.make4(AND, b.comp(mod[2]), mod[1],
		b.make5(OR, source[15], source[14], source[13], source[12], source[11]),
		b.make5(OR, b.comp(source[15]), b.comp(source[14]), b.comp(source[13]),
			b.comp(source[12]), b.comp(source[11]))),
	b.make3(AND, mod[2], mod[1], b.make3(OR, source[0], source[1], source[2]))) // ``넘침''

@ 네 자리 옮김 인수는 왼쪽 1·왼쪽 4·오른쪽 1·오른쪽 4에 해당한다. 경계 비트는
따로 다룬다.

@<자리 옮김 비트 |shift[k]|를 만든다@>=
var a1, a2, a3, a4 *gbgraph.Vertex
if k == 0 {
	a1 = b.make4(AND, source[15], mod[0], b.comp(mod[1]), b.comp(mod[2]))
} else {
	a1 = b.make3(AND, source[k-1], b.comp(mod[1]), b.comp(mod[2]))
}
if k < 4 {
	a2 = b.make4(AND, source[k+12], mod[0], mod[1], b.comp(mod[2]))
} else {
	a2 = b.make3(AND, source[k-4], mod[1], b.comp(mod[2]))
}
if k == 15 {
	a3 = b.make4(AND, source[15], b.comp(mod[0]), b.comp(mod[1]), mod[2])
} else {
	a3 = b.make3(AND, source[k+1], b.comp(mod[1]), mod[2])
}
if k > 11 {
	a4 = b.make4(AND, source[15], b.comp(mod[0]), mod[1], mod[2])
} else {
	a4 = b.make3(AND, source[k+4], mod[1], mod[2])
}
shift[k] = b.make4(OR, a1, a2, a3, a4)

@* RISC 관리. |RunRisc|는 |Risc|가 낸 게이트 그래프를 받아, 그 읽기 전용
메모리의 내용을 주고 그 동작을 흉내낸다. (쓰임새의 본보기는 따로 한 모듈을
이루는 시연 프로그램 {\sc TAKE\_\,RISC}에 있다.)

이 절차는 흉내내는 기계를 먼저 지우고 주소 0에서 시작하는 프로그램을 실행한다.
그리고 주어진 읽기 전용 메모리의 크기를 넘는 주소에 이르면 멈춘다. 그러니
프로그램을 멈추는 한 가지 방법은 |0x0f00| 같은 명령을 실행하는 것이다. 이는
제어를 |0xffff|번지로 옮긴다. |0x0f8f|는 한술 더 떠서, \.S와 \.N의 상태를
건드리지 않고 |0xffff|로 옮긴다. 다만 주어진 읽기 전용 메모리가 $2^{16}$개
낱말을 꽉 채우고 있으면 |RunRisc|는 영영 멈추지 않는다.

멈추면 흉내낸 레지스터들의 마지막 내용을 담은 배열 |riscState|와 0을 함께
돌려준다. |g|가 성한 게이트 그래프가 아니면 음수를 돌려주고 |riscState|는
건드리지 않는다. |traceRegs|가 0보다 크면 그 수만큼의 레지스터를 |trace|에
적어 나간다.

@<RunRisc 서브루틴@>=
func RunRisc(g *gbgraph.Graph, rom []int64, traceRegs int64, trace io.Writer) ([18]int64, int64) {
	var riscState [18]int64
	if traceRegs > 0 {
		@<머리글을 찍는다@>
	}
	@<RISC를 지우고 \.{RUN} 비트를 켠다@>
	var l int64
	for {
		@<출력 게이트에서 메모리 주소 |l|을 읽는다@>
		if traceRegs > 0 {
			@<레지스터 내용을 찍는다@>
		}
		if l >= int64(len(rom)) {
			break // 메모리 검사에 걸리면 멈춘다
		}
		@<메모리 낱말을 입력에 넣고 한 주기를 돌린다@>
	}
	if traceRegs > 0 {
		fmt.Fprintf(trace, "Execution terminated with memory address %04x.\n", l)
	}
	@<레지스터 내용을 |riscState|에 담는다@>
	return riscState, 0
}

@ 기계를 지우는 방법은 \.{RUN} 비트를 끈 채로 회로를 한 번 평가하는 것이다.
그러면 모든 레지스터와 출력이 0이 된다. 이때 |GateEval|이 음수를 내면 |g|가
성한 게이트 그래프가 아니라는 뜻이므로 그대로 물러난다. 지운 뒤에 첫 입력
게이트---곧 \.{RUN}---를 1로 되돌려 놓는다.

@<RISC를 지우고 \.{RUN} 비트를 켠다@>=
if _, code := GateEval(g, "0"); code < 0 {
	return riscState, code
}
g.Vertices[0].X.I = 1

@ 출력은 메모리 주소 레지스터의 16비트를 빅엔디언(최상위 먼저)으로 내놓으므로,
출력 목록을 앞에서 뒤로 훑으며 2를 곱해 더해 나가면 주소가 된다.

@<출력 게이트에서 메모리 주소 |l|을 읽는다@>=
l = 0
for a := g.ZZ.A; a != nil; a = a.Next {
	l = 2*l + a.Tip.X.I
}

@ 반대로 메모리 입력 비트는 리틀엔디언(최하위 먼저)이므로, 읽어 온 낱말을
아래 비트부터 하나씩 떼어 입력 게이트 1번부터 16번에 넣는다. 0번은 \.{RUN}이라
건드리지 않는다. 그러고 나서 |GateEval|을 빈 입력 벡터로 불러 회로를 한 주기
돌린다---빈 벡터는 ``입력이 이미 매겨져 있다''는 뜻이다.

@<메모리 낱말을 입력에 넣고 한 주기를 돌린다@>=
m := rom[l]
for vi := 1; vi <= 16; vi++ {
	g.Vertices[vi].X.I = m & 1
	m >>= 1
}
GateEval(g, "")

@ 레지스터 |r|의 값은 최상위 비트(정점 |16*r+47|)에서 아래로 16번 훑어 읽는다.
래치가 다음에 받을 값(|alt.val|)을 들여다본다.

@<레지스터 내용을 |riscState|에 담는다@>=
readReg := func(base int64) int64 {
	v := g.Vertices[base]
	var m int64
	if v.Y.I == 'L' {
		for k := int64(0); k < 16; k++ {
			m = 2*m + g.Vertices[base-k].Z.V.X.I
		}
	}
	return m
}
for r := int64(0); r < 16; r++ {
	riscState[r] = readReg(16*r + 47)
}
var m int64
for k := int64(0); k < 10; k++ {
	m = 2*m + g.Vertices[26-k].Z.V.X.I // |prog|
}
m = 4*m + g.Vertices[31].Z.V.X.I // |extra|
m = 2*m + g.Vertices[27].Z.V.X.I // |sign|
m = 2*m + g.Vertices[28].Z.V.X.I // |nonzero|
m = 2*m + g.Vertices[29].Z.V.X.I // |carry|
m = 2*m + g.Vertices[30].Z.V.X.I // |overflow|
riscState[16] = m
riscState[17] = l

@ 자취 출력이다.

@<머리글을 찍는다@>=
for r := int64(0); r < traceRegs; r++ {
	fmt.Fprintf(trace, " r%-2d ", r)
}
fmt.Fprint(trace, " P XSNKV MEM\n")

@ @<레지스터 내용을 찍는다@>=
readAlt := func(base int64) int64 {
	v := g.Vertices[base]
	var m int64
	if v.Y.I == 'L' {
		for k := int64(0); k < 16; k++ {
			m = 2*m + g.Vertices[base-k].Z.V.X.I
		}
	}
	return m
}
for r := int64(0); r < traceRegs; r++ {
	fmt.Fprintf(trace, "%04x ", readAlt(16*r+47))
}
var pm int64
for k := int64(0); k < 10; k++ {
	pm = 2*pm + g.Vertices[26-k].Z.V.X.I
}
xb := g.Vertices[31].Z.V.X.I
sb := g.Vertices[27].Z.V.X.I
nb := g.Vertices[28].Z.V.X.I
cb := g.Vertices[29].Z.V.X.I
ob := g.Vertices[30].Z.V.X.I
fmt.Fprintf(trace, "%03x%s ", pm<<2,
	statusStr(xb, 'X')+statusStr(sb, 'S')+statusStr(nb, 'N')+statusStr(cb, 'K')+statusStr(ob, 'V'))
if l >= int64(len(rom)) {
	fmt.Fprint(trace, "????\n")
} else {
	fmt.Fprintf(trace, "%04x\n", rom[l])
}

@ @<RunRisc 서브루틴@>=
func statusStr(bit int64, c byte) string {
	if bit != 0 {
		return string(c)
	}
	return "."
}

@* 일반화 게이트 그래프. 중간 셈을 하기에는 두 종류의 게이트를 더 허용하는 것이
편하다:
$$\vbox{\halign{\hfil#\hfil&\quad#\hfil\cr
|'C'|&값이 |bit|(우리의 |Z.I|)인 상수 게이트\cr
|'='|&앞선 게이트의 사본. |alt|(|Z.V|)가 그 게이트를 가리킨다.\cr}}$$
이런 게이트는 그래프 어디에나 나타날 수 있다. 입력이나 래치 사이에 섞여
들어가도 괜찮다---앞서 말한 위상 차례의 약속은 여느 게이트에만 해당한다.

이 두 게이트는 회로를 {\it 짓는\/} 동안의 발판이다. |Prod|는 상수 0이거나 다른
게이트의 사본인 게이트를 잔뜩 만들어 놓고서, 뒤의 |reduce|가 그것들을 걷어
내도록 맡긴다. 그래서 회로를 짓는 코드가 예외 없이 단순해진다.

|PrintGates|는 그런 일반화 게이트 그래프를 표준 출력에 기호로 찍는다.

@<PrintGates 서브루틴@>=
func prGate(out io.Writer, v *gbgraph.Vertex) {
	fmt.Fprintf(out, "%s = ", v.Name)
	switch v.Y.I {
	case 'I':
		fmt.Fprint(out, "input")
	case 'L':
		fmt.Fprint(out, "latch")
		if v.Z.V != nil {
			fmt.Fprintf(out, "ed %s", v.Z.V.Name)
		}
	case NOT:
		fmt.Fprint(out, "~ ")
	case 'C':
		fmt.Fprintf(out, "constant %d", v.Z.I)
	case '=':
		fmt.Fprintf(out, "copy of %s", v.Z.V.Name)
	}
	for a := v.Arcs; a != nil; a = a.Next {
		if a != v.Arcs {
			fmt.Fprintf(out, " %c ", byte(v.Y.I))
		}
		fmt.Fprint(out, a.Tip.Name)
	}
	fmt.Fprintln(out)
}

func PrintGates(out io.Writer, g *gbgraph.Graph) {
	for i := int64(0); i < g.N; i++ {
		prGate(out, &g.Vertices[i])
	}
	for a := g.ZZ.A; a != nil; a = a.Next {
		if isBoolean(a.Tip) {
			fmt.Fprintf(out, "Output %d\n", theBoolean(a.Tip))
		} else {
			fmt.Fprintf(out, "Output %s\n", a.Tip.Name)
		}
	}
}

@* 그래프 줄이기.
|reduce|는 일반화 그래프 |g|를 받아, $\overline{\overline x}=x$와 다음 항등식들을
써서 |'C'|·|'='|나 뻔히 군더더기인 게이트가 하나도 없는 동치 그래프를 만든다:
$$\vbox{\halign{$#$\hfil\quad&$#$\hfil\quad&$#$\hfil\quad&$#$\hfil\cr
x\land0=0,&x\land1=x,&x\land x=x,&x\land\overline x=0;\cr
x\lor0=x,&x\lor1=1,&x\lor x=x,&x\lor\overline x=1;\cr
x\oplus0=x,&x\oplus1=\overline x,&x\oplus x=0,&x\oplus\overline x=1.\cr}}$$
줄인 그래프에서는 출력 값을 셈하는 데 직접으로든 간접으로든 쓰이지 않는
게이트도 모두 빠진다. |PartialGates|가 이를 쓴다.

@ 여기에 미묘한 대목이 하나 있다. 상수 1로 정해진 입력이 |XOR| 게이트 여럿에
걸려 있으면, 그 게이트들은 저마다 인수 하나를 여로 바꾸어야 한다. 그런데 그
여 게이트가 아직 없으면 새로 만들어야 한다. 그래서 ``줄인'' 그래프가 원래
그래프보다 오히려 {\it 커질\/} 수도 있다---호는 줄었는데 정점은 늘어나는
것이다. 그러므로 |reduce|는 줄이는 도중에도 새 정점을 만들 수 있어야 한다.
\CEE/ 원본은 이를 위해 정점 배열에 여유를 두고 |avail_arc| 목록을 따로
간수했지만, \GO/에서는 슬라이스를 늘리면 그만이다.

정점 링크에 |foo|(|X.V|), 표시 스택에 |lnk|(|W.V|, |bar|와 같은 자리), 래치
목록에 |v.V|(|V.V|)를 쓴다. \CEE/처럼 작업 변수를 함수 어귀에 두고, |goto|는
이름표 |break|·헬퍼로 옮긴다.

@<reduce 서브루틴@>=
// |reverseArcs|는 호 목록을 제자리에서 뒤집어 새 머리를 준다.
func reverseArcs(head *gbgraph.Arc) *gbgraph.Arc {
	var prev *gbgraph.Arc
	for a := head; a != nil; {
		next := a.Next
		a.Next = prev
		prev = a
		a = next
	}
	return prev
}

@ |reduce|는 세 국면으로 나뉜다. 먼저 게이트를 되풀이해 줄이고, 그다음 어떤
출력에 쓰이는 게이트를 표시하고, 마지막으로 표시된 것만 새 그래프에 옮긴다.
줄이는 동안에는 |b.g|가 입력 그래프를 가리키게 두어 |Index| 따위가 옳게
돌아가도록 한다.

@<reduce 서브루틴@>=
func (b *builder) reduce(g *gbgraph.Graph) (*gbgraph.Graph, error) {
	if g == nil {
		return nil, gbgraph.MissingOperand
	}
	b.g = g
	sentinel := &g.Vertices[g.N]
	var n int64 // 표시된 게이트 수
	var newVerts []*gbgraph.Vertex
	newComp := func(u *gbgraph.Vertex, availArc *gbgraph.Arc) *gbgraph.Vertex {
		@<|u|의 여를 담을 새 정점을 만든다@>
	}
	@<모든 게이트를 되풀이해 줄인다@>
	@<어떤 출력에 쓰이는 게이트를 모두 표시한다@>
	@<표시된 게이트를 새 그래프에 옮긴다@>
	return newGraph, nil
}

@ 한 번 훑는 것으로는 모자란다. 래치가 상수로 밝혀지면 그 래치를 인수로 쓰던
게이트들이 다시 줄어들 수 있고, 그러다 또 다른 래치가 상수가 될 수 있기
때문이다. 그래서 상수가 된 래치가 더 나오지 않을 때까지 되풀이한다. 래치가
없는 그래프(|Prod|가 만든 것 따위)에서는 이 고리가 한 번만 돈다.

@<모든 게이트를 되풀이해 줄인다@>=
for {
	var latchPtr *gbgraph.Vertex
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		@<게이트 |v|를 줄이거나 래치 목록에 얹는다@>
	}
	@<상수가 된 래치가 있는지 본다; 없으면 멈춘다@>
}

@ 게이트를 줄이는 큰 분기다. 각 종류마다 항등식을 적용하고, 상수가 되면 |'C'|로,
한 인수만 남으면 |'='|로 바꾼다. \CEE/의 여러 |goto| 이름표(|make_v_0| 따위)는
헬퍼 |setConst|·|setEq|와 이름표 있는 |switch|로 옮긴다.

@<게이트 |v|를 줄이거나 래치 목록에 얹는다@>=
setConst := func(bit int64) { v.Z.I = bit; v.Y.I = 'C'; v.Arcs = nil }
setEq := func(u *gbgraph.Vertex) { v.Z.V = u; v.Y.I = '='; v.Arcs = nil }
resetBar := true // 정규 인버터만 |false|로: 새 |bar| 링크를 지키려 리셋을 건너뛴다
switch v.Y.I {
case 'L':
	v.V.V = latchPtr
	latchPtr = v
case 'I', 'C':
	// 그대로 둔다
case '=':
	u := v.Z.V
	if u.Y.I == '=' {
		v.Z.V = u.Z.V
	} else if u.Y.I == 'C' {
		setConst(u.Z.I)
	}
case NOT:
	@<인버터를 줄여 본다@>
case AND:
	@<\.{AND} 게이트를 줄여 본다@>
	@<인수가 하나뿐이면 |'='|로 바꾼다@>
case OR:
	@<\.{OR} 게이트를 줄여 본다@>
	@<인수가 하나뿐이면 |'='|로 바꾼다@>
case XOR:
	@<\.{XOR} 게이트를 줄여 본다@>
	@<인수가 하나뿐이면 |'='|로 바꾼다@>
}
if resetBar {
	v.W.V = nil // 이 필드는 나중에 여를 가리킬 수 있다
}
v.X.V = b.at(v, 1) // |foo|: 모든 정점을 잇는다

@ 이 세 종류는 인수가 하나만 남으면 그 인수의 사본(|'='|)이 된다. 각 절 끝에서
쓴다.

@<인수가 하나뿐이면 |'='|로 바꾼다@>=
if v.Arcs != nil && v.Arcs.Next == nil {
	setEq(v.Arcs.Tip)
}

@ @<인버터를 줄여 본다@>=
u := v.Arcs.Tip
if u.Y.I == '=' {
	u = u.Z.V
	v.Arcs.Tip = u
}
if u.Y.I == 'C' {
	setConst(1 - u.Z.I)
} else if u.W.V != nil { // 이 여는 이미 셈했다
	setEq(u.W.V)
} else {
	u.W.V, v.W.V = v, u
	resetBar = false // \CEE/의 |goto done|: |v.bar|을 지키려 리셋을 건너뛴다
}

@ \.{AND}: 상수 0이면 결과가 0, 상수 1이면 그 인수를 뺀다. 같은 인수가 둘이면
하나를 빼고, 서로 여인 인수 둘이면 결과가 0이다.

@<\.{AND} 게이트를 줄여 본다@>=
{
	var aa *gbgraph.Arc
	zero := false
	@<\.{AND}의 인수를 훑으며 손질한다@>
	if zero {
		setConst(0)
	} else if v.Arcs == nil {
		setConst(1)
	}
}

@ 상수 인수는 건너뛰고, 이미 나온 인수도 건너뛰며, 어떤 인수의 여를
만나면 결과가 0임을 |zero|에 적어 둔다.

@<\.{AND}의 인수를 훑으며 손질한다@>=
for a := v.Arcs; a != nil; a = a.Next {
	u := a.Tip
	if u.Y.I == '=' {
		u = u.Z.V
		a.Tip = u
	}
	bypass := false
	if u.Y.I == 'C' {
		if u.Z.I == 0 {
			zero = true
			break
		}
		bypass = true
	} else {
		@<이미 나온 인수나 그 여를 찾아 |zero|를 정한다@>
		if zero {
			break
		}
	}
	@<군더더기 인수면 |v|의 호 목록에서 뺀다@>
}

@ 같은 인수가 이미 있으면 하나는 군더더기고, 어떤 인수의 여가 있으면 |AND|는
0이다.

@<이미 나온 인수나 그 여를 찾아 |zero|를 정한다@>=
for bb := v.Arcs; bb != a; bb = bb.Next {
	if bb.Tip == u {
		bypass = true
		break
	}
	if bb.Tip == u.W.V {
		zero = true
		break
	}
}

@ 세 종류가 함께 쓰는 꼬리다. |bypass|면 호 |a|를 목록에서 떼고, 아니면 |aa|를
그 자리로 옮긴다.

@<군더더기 인수면 |v|의 호 목록에서 뺀다@>=
if bypass {
	if aa != nil {
		aa.Next = a.Next
	} else {
		v.Arcs = a.Next
	}
} else {
	aa = a
}

@ \.{OR}: \.{AND}의 쌍대다. 상수 1이면 1, 상수 0이면 그 인수를 뺀다.

@<\.{OR} 게이트를 줄여 본다@>=
{
	var aa *gbgraph.Arc
	one := false
	@<\.{OR}의 인수를 훑으며 손질한다@>
	if one {
		setConst(1)
	} else if v.Arcs == nil {
		setConst(0)
	}
}

@ \.{AND}과 쌍대라, 상수 1을 만나면 결과가 1임을 |one|에 적고, 서로 여인 인수
둘도 마찬가지다.

@<\.{OR}의 인수를 훑으며 손질한다@>=
for a := v.Arcs; a != nil; a = a.Next {
	u := a.Tip
	if u.Y.I == '=' {
		u = u.Z.V
		a.Tip = u
	}
	bypass := false
	if u.Y.I == 'C' {
		if u.Z.I != 0 {
			one = true
			break
		}
		bypass = true
	} else {
		@<이미 나온 인수나 그 여를 찾아 |one|을 정한다@>
		if one {
			break
		}
	}
	@<군더더기 인수면 |v|의 호 목록에서 뺀다@>
}

@ \.{AND} 때와 거울상이다.

@<이미 나온 인수나 그 여를 찾아 |one|을 정한다@>=
for bb := v.Arcs; bb != a; bb = bb.Next {
	if bb.Tip == u {
		bypass = true
		break
	}
	if bb.Tip == u.W.V {
		one = true
		break
	}
}

@ \.{XOR}: 상수 1은 |cmp|를 뒤집고, 같은 인수 둘은 서로 지우며, 서로 여인 인수
둘은 |cmp|를 뒤집고 지운다. 인수가 다 없어지면 상수 |cmp|가 되고, 아니면 |cmp|가
1일 때 한 인수를 여로 바꾼다.

@<\.{XOR} 게이트를 줄여 본다@>=
{
	var cmp int64
	var aa *gbgraph.Arc
	@<\.{XOR}의 인수를 훑으며 손질한다@>
	if v.Arcs == nil {
		setConst(cmp)
	} else if cmp != 0 {
		@<|v|의 한 인수를 여로 바꾼다@>
	}
}

@ 상수 1과 서로 여인 인수 둘은 |cmp|를 뒤집고, 같은 인수 둘은 서로 지운다.

@<\.{XOR}의 인수를 훑으며 손질한다@>=
for a := v.Arcs; a != nil; a = a.Next {
	u := a.Tip
	if u.Y.I == '=' {
		u = u.Z.V
		a.Tip = u
	}
	bypass := false
	if u.Y.I == 'C' {
		if u.Z.I != 0 {
			cmp = 1 - cmp
		}
		bypass = true
	} else {
		@<같은 인수나 그 여를 찾아 지우고 |cmp|를 손본다@>
	}
	@<군더더기 인수면 |v|의 호 목록에서 뺀다@>
}

@ 같은 인수 둘은 서로 지워 없애고, 여인 인수 둘은 지우면서 |cmp|를 뒤집는다.
찾으면 그 짝도 |bypass|로 함께 뺀다.

@<같은 인수나 그 여를 찾아 지우고 |cmp|를 손본다@>=
var bb *gbgraph.Arc
for c := v.Arcs; c != a; c = c.Next {
	if c.Tip == u || c.Tip == u.W.V {
		if c.Tip == u.W.V {
			cmp = 1 - cmp
		}
		if bb != nil {
			bb.Next = c.Next
		} else {
			v.Arcs = c.Next
		}
		bypass = true
		break
	}
	bb = c
}

@ |XOR|이 상수 1을 인수로 여럿 가지면, ``줄인'' 그래프가 정점 수로는 되레 커질
수 있다. 그래서 여 게이트를 만들 새 정점을 |reduce| 도중에도 잡을 수 있어야 한다.

@<|v|의 한 인수를 여로 바꾼다@>=
{
	var a *gbgraph.Arc
	var u *gbgraph.Vertex
	for a = v.Arcs; ; a = a.Next {
		u = a.Tip
		if u.W.V != nil {
			break // 여가 이미 알려져 있다
		}
		if a.Next == nil { // 마지막 기회다
			u.W.V = newComp(u, nil)
			break
		}
	}
	a.Tip = u.W.V
}

@ @<|u|의 여를 담을 새 정점을 만든다@>=
nv := new(gbgraph.Vertex)
nv.Y.I = NOT
nv.Name = u.Name + "~"
a := b.g.VirginArc()
a.Tip = u
nv.Arcs = a
nv.W.V = u
nv.X.V = u.X.V // |foo|
u.X.V = nv
newVerts = append(newVerts, nv)
return nv

@ 래치를 |v.V|로 이어, 값이 될 게이트가 상수(|'C'|)나 사본(|'='|)이 되었는지
살핀다. 상수가 하나도 없으면 바깥 반복을 멈춘다.

@<상수가 된 래치가 있는지 본다; 없으면 멈춘다@>=
noConstantsYet := true
for v := latchPtr; v != nil; v = v.V.V {
	u := v.Z.V // 값이 래치될 게이트
	if u.Y.I == '=' {
		v.Z.V = u.Z.V
	} else if u.Y.I == 'C' {
		v.Y.I = 'C'
		v.Z.I = u.Z.I
		noConstantsYet = false
	}
}
if noConstantsYet {
	break
}

@ 표시 단계에서는 |lnk|(|W.V|)로 표시할 노드 목록을 잇는다. 이 필드는 표시된
노드에서만 |nil|이 아니게 된다.

@<어떤 출력에 쓰이는 게이트를 모두 표시한다@>=
for v := &g.Vertices[0]; v != sentinel; v = v.X.V {
	v.W.V = nil
}
for a := g.ZZ.A; a != nil; a = a.Next {
	v := a.Tip
	if isBoolean(v) {
		continue
	}
	if v.Y.I == '=' {
		v = v.Z.V
		a.Tip = v
	}
	if v.Y.I == 'C' { // 이 출력은 상수라 불리언으로 만든다
		a.Tip = boolGate(v.Z.I)
		continue
	}
	@<|v|를 셈하는 데 쓰이는 게이트를 모두 표시한다@>
}

@ 표시 스택을 |lnk|로 잇는다. 래치는 |alt|로 가는 ``숨은'' 의존이 있고, 래치될
게이트가 앞서면(|Index(u)<Index(v)|) 특별한 게이트가 하나 더 생기므로 |n|을 센다
--- 표시 여부와 무관하게, \CEE/를 글자 그대로 따른다.

@<|v|를 셈하는 데 쓰이는 게이트를 모두 표시한다@>=
if v.W.V == nil {
	v.W.V = sentinel // |v|가 표시할 노드 스택의 꼭대기다
	@<표시 스택이 빌 때까지 게이트를 훑는다@>
}

@ 스택 꼭대기 |v|를 꺼내(다음 노드는 |v.W.V|로 잇는다) 그 인수들을 아직 안
표시했으면 스택에 얹는다. 래치는 |alt|로 가는 숨은 의존도 함께 챙긴다.

@<표시 스택이 빌 때까지 게이트를 훑는다@>=
for {
	n++
	bb := v.Arcs
	if v.Y.I == 'L' {
		u := v.Z.V
		if b.g.Index(u) < b.g.Index(v) {
			n++ // 래치될 입력값에 특별한 게이트가 생긴다
		}
		if u.W.V == nil {
			u.W.V = v.W.V
			v = u
		} else {
			v = v.W.V
		}
	} else {
		v = v.W.V
	}
	for ; bb != nil; bb = bb.Next {
		u := bb.Tip
		if u.W.V == nil {
			u.W.V = v
			v = u
		}
	}
	if v == sentinel {
		break
	}
}

@ 표시된 게이트를 |n|개짜리 새 그래프로 옮긴다. dag라 복사는 쉽지만, 래치의
되먹임을 다뤄야 한다. 호 목록을 뒤집는 |reverseArcs|로 원래 차례를 지킨다.

@<표시된 게이트를 새 그래프에 옮긴다@>=
newGraph := gbgraph.NewGraph(n)
newGraph.ID = g.ID
newGraph.UtilTypes = "ZZZIIVZZZZZZZA"
b.g = newGraph
b.nextV = 0
var latchPtr *gbgraph.Vertex
for v := &g.Vertices[0]; v != sentinel; v = v.X.V {
	if v.W.V != nil { // |v|가 표시되었다
		u := &newGraph.Vertices[b.nextV]
		b.nextV++
		v.W.V = u // 어디에 옮겼는지 적어 둔다
		@<|u|를 |v|의 사본으로 만들고, 래치면 래치 목록에 얹는다@>
	}
}
@<새로 옮긴 래치의 |alt| 필드를 손본다@>
g.ZZ.A = reverseArcs(g.ZZ.A)
for a := g.ZZ.A; a != nil; a = a.Next {
	nb := newGraph.VirginArc()
	if isBoolean(a.Tip) {
		nb.Tip = a.Tip
	} else {
		nb.Tip = a.Tip.W.V
	}
	nb.Next = newGraph.ZZ.A
	newGraph.ZZ.A = nb
}

@ @<|u|를 |v|의 사본으로 만들고, 래치면 래치 목록에 얹는다@>=
u.Name = v.Name
u.Y.I = v.Y.I
if v.Y.I == 'L' {
	u.Z.V = latchPtr
	latchPtr = v
}
v.Arcs = reverseArcs(v.Arcs)
for a := v.Arcs; a != nil; a = a.Next {
	b.g.NewArc(u, a.Tip.W.V, a.Len)
}

@ 새 래치의 |alt| 필드를 사본으로 다시 잇는다. 래치될 게이트가 앞서면, 앞
주기의 값을 담을 게이트를 새로 만든다(입력 하나를 두 번 가리키는 \.{OR}).

@<새로 옮긴 래치의 |alt| 필드를 손본다@>=
for latchPtr != nil {
	u := latchPtr.W.V // 래치의 사본
	v := u.Z.V
	u.Z.V = latchPtr.Z.V.W.V
	latchPtr = v
	if b.g.Index(u.Z.V) < b.g.Index(u) {
		@<|u.alt|을 입력을 베끼는 새 게이트로 바꾼다@>
	}
}

@ @<|u.alt|을 입력을 베끼는 새 게이트로 바꾼다@>=
w := u.Z.V // 래치를 위해 베낄 입력 게이트
nv := &b.g.Vertices[b.nextV]
b.nextV++
nv.Name = w.Name + ">" + u.Name
nv.Y.I = OR
b.g.NewArc(nv, w, DELAY)
b.g.NewArc(nv, w, DELAY)
u.Z.V = nv

@* 병렬 곱셈. 이제 |Prod| 루틴 차례다. 이번에는 사뭇 다른 게이트 그물을
짓는데, 바탕에 깔린 것은 분할 정복이다. 달려들기 전에 숨 한 번 돌리자.

(심호흡.)

@ |Prod(m,n)|은 부호 없는 |m|비트 수와 |n|비트 수의 이진 곱셈을 하는 그물을
짓는다. |m|과 |n|은 2 이상이라야 한다. 위쪽 한계는 없다---물론 이 루틴을 돌리는
기계의 메모리가 허락하는 데까지지만.

|Prod|의 전체 전략은 이렇다. 먼저 게이트 상당수가 항등적으로 0이거나 다른
게이트의 사본인 일반화 게이트 그래프를 짓는다. 그러고 나서 |reduce| 루틴이
국소 최적화를 해 원하는 결과를 낸다. 래치가 없으므로 일반 |reduce| 루틴의
복잡한 대목 몇 가지는 겪지 않아도 된다.

|Prod|가 돌려주는 그물의 |AND|·|OR|·|XOR| 게이트는 모두 입력이 정확히 둘이다.
회로의 깊이(곧 가장 긴 경로의 길이)는
$$3\log m/\!\log 1.5 + \log(m+n)/\!\log\phi + O(1)$$
이고, 여기서 $\phi=(1+\sqrt5\,)/2$는 황금비다. 게이트 총수는
$$6mn+5m^2+O\bigl((m+n)\log(m+n)\bigr)$$
이다. |Prod|로 큰 정수의 곱을 셈하는 시연 프로그램 {\sc MULTIPLY}가 있다.

@ 이 회로에는 두 가지 무늬가 쓰인다. 먼저 세 수의 합을 두 수의 합으로 줄이는
병렬 열 덧셈을 쓴다. 이 줄이기를 거듭하면 |m|개 수의 합을 단 두 수의 합으로
줄일 수 있고, 회로 깊이는 점화식 $T(3N)=T(2N)+O(1)$을 만족한다. 그렇게 두 수의
합으로 줄고 나면, 자료를 재귀적으로 ``황금 분할''하는 병렬 덧셈 방식을 쓴다.
다시 말해 재귀가 자료를 큰 쪽과 작은 쪽의 비가 대략 $\phi$가 되도록 두 조각으로
가른다. 이 방식은 이진 분할보다 점근적으로도, 실제로도 조금 낫다.

@ $\flog N$, 곧 $N$의 피보나치 로그를 $N\le F_{k+1}$을 만족하는 가장 작은 음이
아닌 정수 $k$로 정의하자. $N=m+n$이라 두면, 두 $N$비트 수를 더하는 우리 병렬
가산기의 깊이는 많아야 $2+\flog N$이 된다. 그리고 곱셈 회로의 줄이기 전 그래프
|g|는 게이트가 $(6m+3\flog N)N$개보다 적다---이것이 |NewGraph|에 미리 잡아
둘 크기의 근거다.

@ 세 수를 두 수로 줄이는 규칙은 한 비트에 대해
$$x+y+z=s+2c,\qquad s=x\oplus y\oplus z,\qquad
c=(x\land y)\lor(x\land z)\lor(y\land z)$$
인데, 이것을 $N$비트 수의 각 비트에 그대로 쓰면 된다. 자리 올림이 이웃 비트로
번지지 않으므로 깊이가 상수다.

그물의 입력 게이트를 $x_0,\ldots,x_{m-1}$, $y_0,\ldots,y_{n-1}$이라 하고 출력을
$z_0,\ldots,z_{m+n-1}$이라 하자. |Prod| 그물은 곱을 먼저 $m$겹 합
$A_0+A_1+\cdots+A_{m-1}$로 보아 셈하는데, 여기서
$$A_j=2^jx_j\cdot(y_{n-1}\ldots y_1y_0)_2\,,\qquad 0\le j<m$$
이다. 그런 다음 세 개를 두 개로 줄이는 규칙으로 $A_m$, $A_{m+1}$, \dots,
$A_{3m-5}$를 다음 얼개로 정의한다:
$$A_{m+2j}+A_{m+2j+1}=A_{3j}+A_{3j+1}+A_{3j+2}\,,\qquad 0\le j\le m-3.$$
[이와 비슷하되 조금 덜 효율적인 얼개를 Pratt과 Stockmeyer가 {\sl Journal of
@^Pratt, Vaughan Ronald@>@^Stockmeyer, Larry Joseph@>
Computer and System Sciences \bf12\/}(1976)의 명제 5.3에서 썼다. 여기 쓴 점화식은
걸음 크기가 3인 요세푸스 문제와 관련이 있다. {\sl Concrete Mathematics\/}를
보라.]

@<Prod 서브루틴@>=
func Prod(m, n int64) (*gbgraph.Graph, error) {
	if m < 2 {
		m = 2
	}
	if n < 2 {
		n = 2
	}
	mPlusN := m + n
	@<$f=\flog(m+n)$를 셈한다@>
	b := &builder{g: gbgraph.NewGraph((6*m - 7 + 3*f) * mPlusN)}
	b.g.ID = fmt.Sprintf("prod(%d,%d)", m, n)
	b.g.UtilTypes = "ZZZIIVZZZZZZZA"
	longTables := make([]int64, 2*mPlusN+f)
	vertTables := make([]*gbgraph.Vertex, f*mPlusN)
	@<|g|를 병렬 곱셈 일반화 게이트로 채운다@>
	return b.reduce(b.g)
}

@ $\flog N$은 $N\le F_{k+1}$인 가장 작은 음 아닌 정수 $k$다.

@<$f=\flog(m+n)$를 셈한다@>=
f := int64(4)
j := int64(3)
k := int64(5) // $j=F_f$, $k=F_{f+1}$
for k < mPlusN {
	k += j
	j = k - j
	f++
}

@ 곱셈은 $m$겹 합 $A_0+\cdots+A_{m-1}$로 보고, 3대2 덧셈 규칙으로 두 수의 합까지
줄인 뒤 병렬 덧셈으로 마무리한다. $A_j$의 최하위 비트는 정점 자리 $|aPos|(j)\cdot
N$에 둔다.

@<|g|를 병렬 곱셈 일반화 게이트로 채운다@>=
b.startPrefix("X")
x := b.firstOf(int(m), 'I')
b.startPrefix("Y")
y := b.firstOf(int(n), 'I')
aPos := func(j int64) int64 {
	if j < m {
		return j + 1
	}
	return m + 5*((j-m)>>1) + 3 + (((j - m) & 1) << 1)
}
@<$0\le j<m$에 대해 $A_j$를 정의한다@>
@<$0\le j\le m-3$에 대해 $P_j$, $Q_j$, $A_{m+2j}$, $R_j$, $A_{m+2j+1}$을 정의한다@>
@<$U$와 $V$를 정의한다@>
@<병렬 덧셈으로 마지막 결과 $Z$를 셈한다@>
b.g.N = int64(b.nextV) // 실제로 쓴 게이트 수로 줄인다

@ @<$0\le j<m$에 대해 $A_j$를 정의한다@>=
for j := int64(0); j < m; j++ {
	b.numericPrefix('A', j)
	for kk := int64(0); kk < j; kk++ {
		b.newVert('C').Z.I = 0 // 상수 0 게이트
	}
	for kk := int64(0); kk < n; kk++ {
		b.make2(AND, b.at(x, j), b.at(y, kk))
	}
	for kk := j + n; kk < mPlusN; kk++ {
		b.newVert('C').Z.I = 0
	}
}

@ |m|이 부호 없는 수라 |j<=m-3| 대신 |j<m-2|로 쓴다.

@<$0\le j\le m-3$에 대해 $P_j$, $Q_j$, $A_{m+2j}$, $R_j$, $A_{m+2j+1}$을 정의한다@>=
for j := int64(0); j < m-2; j++ {
	@<$P_j$, $Q_j$, $A_{m+2j}$를 만든다@>
	@<$R_j$, $A_{m+2j+1}$을 만든다@>
}

@ 3대2 규칙의 첫 두 게이트다. $P_j=\alpha\oplus\beta$, $Q_j=\alpha\land\beta$이고,
$A_{m+2j}=P_j\oplus A_{3j+2}$가 자리 올림 없는 합의 아랫자리다.

@<$P_j$, $Q_j$, $A_{m+2j}$를 만든다@>=
alpha := b.vAt(aPos(3*j) * mPlusN)
beta := b.vAt(aPos(3*j+1) * mPlusN)
b.numericPrefix('P', j)
for kk := int64(0); kk < mPlusN; kk++ {
	b.make2(XOR, b.at(alpha, kk), b.at(beta, kk))
}
b.numericPrefix('Q', j)
for kk := int64(0); kk < mPlusN; kk++ {
	b.make2(AND, b.at(alpha, kk), b.at(beta, kk))
}
alpha = b.vAt(int64(b.nextV) - 2*mPlusN)
beta = b.vAt(aPos(3*j+2) * mPlusN)
b.numericPrefix('A', m+2*j)
for kk := int64(0); kk < mPlusN; kk++ {
	b.make2(XOR, b.at(alpha, kk), b.at(beta, kk))
}

@ 나머지 둘이다. $R_j=P_j\land A_{3j+2}$이고, $Q_j\lor R_j$를 한 자리 올려
$A_{m+2j+1}$로 삼는다 --- 그래서 맨 아래에 상수 0을 하나 깐다.

@<$R_j$, $A_{m+2j+1}$을 만든다@>=
b.numericPrefix('R', j)
for kk := int64(0); kk < mPlusN; kk++ {
	b.make2(AND, b.at(alpha, kk), b.at(beta, kk))
}
alpha = b.vAt(int64(b.nextV) - 3*mPlusN)
beta = b.vAt(int64(b.nextV) - mPlusN)
b.numericPrefix('A', m+2*j+1)
b.newVert('C').Z.I = 0 // $Q\lor R$을 2배 하는 또 다른 0
for kk := int64(0); kk < mPlusN-1; kk++ {
	b.make2(OR, b.at(alpha, kk), b.at(beta, kk))
}

@ $v_{m+n-1}$은 결코 안 쓰이지만(0이라야 한다) 그래도 셈한다. |reduce|가 뻔한
군더더기를 다 없애 준다.

@<$U$와 $V$를 정의한다@>=
alpha := b.vAt(aPos(3*m-6) * mPlusN)
beta := b.vAt(aPos(3*m-5) * mPlusN)
b.startPrefix("U")
for kk := int64(0); kk < mPlusN; kk++ {
	b.make2(XOR, b.at(alpha, kk), b.at(beta, kk))
}
b.startPrefix("V")
for kk := int64(0); kk < mPlusN; kk++ {
	b.make2(AND, b.at(alpha, kk), b.at(beta, kk))
}

@* 병렬 덧셈. 이제 병렬 곱셈기는 마지막 한 걸음, 병렬 가산기의 설계만 남았다.

가산기는 다음 이론에 바탕한다. 우리는 두 $N$비트 수 $u$와 $v$의 이진 덧셈을
하려 하는데, 모든 $k$에 대해 $u_k+v_k\le1$임을 이미 알고 있다(앞 단계에서 세
수를 두 수로 줄일 때 그렇게 나왔다). 그러면 $z_k=u_k\oplus w_k$이고, $w_0=0$이며
$$w_k\;=\;v_{k-1}\;\lor\;u_{k-1}v_{k-2}\;\lor\;u_{k-1}u_{k-2}v_{k-3}\;\lor
\;\cdots$$
이다. 그러니 할 일은 $w_1$, $w_2$, \dots, $w_{N-1}$을 빨리 셈하는 것이다.

@ $c_k^{\,j}$를 $w_k$를 정의하는 위 식의 첫 $j$개 항의 |OR|이라 하고,
$d_k^{\,j}$를 $j$겹 곱 $u_{k-1}u_{k-2}\ldots u_{k-j}$라 하자. 그러면
$w_k=c_k^{\,k}$이고, 다음 꼴의 재귀 얼개로 셈할 수 있다:
$$c_k^{\,j}=c_k^{\,i}\lor d_k^{\,i}c_{k-i}^{\,j-i}\,,\qquad
d_k^{\,j}=d_k^{\,i}d_{k-i}^{\,j-i}\,.$$

@ 이 재귀는 $i=\down[j]$로 고르면 아주 얌전하게 움직인다. 여기서 $\down[j]$는
$j>1$에 대해
$$\down[j]\;=\;j-F_{(\flog j)-1}$$
로 정의된다. 예컨대 $F_7=13<18\le21=F_8$이므로 $\flog18=7$이고, 따라서
$\down[18]=18-F_6=18-8=10$이다.

$j\to\down[j]$라 쓰고, 이 관계가 정하는 양의 정수 전체 위의 유향 트리를
생각하자. 그 트리의 한 경로를 예로 들면 $18\to10\to5\to3\to2\to1$이다. $w_{18}=
c_{18}^{18}$에 대한 우리 점화식은 $c_{18}^{10}$을 쓰고, 그것은 $c_{18}^5$를 쓰고,
그것은 다시 $c_{18}^3$을 쓰는 식이다. 일반적으로 $k\to^*j$인 모든 $j$에 대해
$c_k^{\,j}$를 셈하고, $k\to^+j$인 모든 $j$에 대해 $d_k^{\,j}$를 셈한다.

@ 그런데
$$k\;\to^*\;j\;\to\;i\qquad\hbox{이면}\qquad k-i\;\to^*\;j-i$$
임을 어렵지 않게 보일 수 있다. 그러므로 점화식에 필요한 보조 인수
$c_{k-i}^{\,j-i}$와 $d_{k-i}^{\,j-i}$는 이미 셈해져 있게 된다---이것이 이
얼개가 성립하는 핵심이다.

또 $k>1$일 때
$$\flog k=\min_{0<j<k}\,\max\bigl(1+\flog j,\,2+\flog(k-j)\bigr)$$
이 성립하고, $\down[k]$가 바로 이 식에서 최솟값을 이루는 가장 작은 $j$임도 보일
수 있다. 따라서 $u$들과 $v$들로부터 $w_k$를 셈하는 회로의 깊이는 정확히
$\flog k$다. 특히 $z_k$를 셈할 때 만들어지는 게이트는 많아야 $3\flog N$개이고,
회로의 병렬 덧셈 부분 전체의 게이트는 많아야 $3N\flog N$개다.

@<병렬 덧셈으로 마지막 결과 $Z$를 셈한다@>=
w := vertTables
c := vertTables[mPlusN:]
flog := longTables
down := longTables[mPlusN+1:]
anc := longTables[2*mPlusN+1-mPlusN:] // |down| 뒤 |mPlusN|만큼; 아래에서 다시 잡는다
_ = anc
@<피보나치 재귀용 보조 표를 세운다@>
@<재사용할 중간값을 기억하며 $W$ 게이트를 만든다@>
@<마지막 게이트 $Z=U\oplus W$를 셈해 출력으로 적는다@>

@ |flog[]|와 |down[]| 표를 채운다. |anc[]|는 현재 |k|의 조상 목록에 쓴다.

@<피보나치 재귀용 보조 표를 세운다@>=
anc = longTables[2*mPlusN+1:] // |flog| 표(|mPlusN+1|개)와 |down| 표(|mPlusN|개) 다음
flog[1], flog[2] = 0, 2
down[1], down[2] = 0, 1
{
	i, jj, kk := int64(3), int64(2), int64(3)
	for l := int64(3); l <= mPlusN; l++ {
		if l > kk {
			kk += jj
			jj = kk - jj
			i++ // $F_i=jj<l\le kk=F_{i+1}$
		}
		flog[l] = i
		down[l] = l - kk + jj
	}
}

@ $w_k$ 게이트를 만든 뒤 그 자리를 |w[k]|에 적는다. $c_k^{\,i}$($i=F_{l+1}$,
$l=\flog i\ge2$)를 만든 뒤 그 자리를 |c[k+(l-2)N]|에 적고, $d_k^{\,i}$는 바로
뒤에 온다.

@<재사용할 중간값을 기억하며 $W$ 게이트를 만든다@>=
vv := b.vAt(int64(b.nextV) - mPlusN)
uu := b.vAt(int64(b.nextV) - 2*mPlusN)
b.startPrefix("W")
w[0] = b.newVert('C')
w[0].Z.I = 0 // $w_0=0$
w[1] = b.newVert('=')
w[1].Z.V = vv // $w_1=v_0$
for k := int64(2); k < mPlusN; k++ {
	@<|k|의 조상들을 |anc|에 내림차순으로 담는다(|anc[l]=2|에서 멈춤)@>
	i := int64(1)
	cc := b.at(vv, k-1)
	dd := b.at(uu, k-1)
	var v *gbgraph.Vertex
	for {
		jN := anc[l] // 이제 $i=\down[jN]$
		@<게이트 $b_k^{\,jN}=d_k^{\,i}\land c_{k-i}^{\,jN-i}$를 셈한다@>
		@<게이트 $c_k^{\,jN}=c_k^{\,i}\lor b_k^{\,jN}$를 셈한다@>
		if flog[jN] < flog[jN+1] { // $jN$이 피보나치 수다
			c[k+(flog[jN]-2)*mPlusN] = v
		}
		if l == 0 {
			break
		}
		cc = v
		@<게이트 $d_k^{\,jN}=d_k^{\,i}\land d_{k-i}^{\,jN-i}$를 셈한다@>
		dd = v
		i = jN
		l--
	}
	w[k] = v
}

@ @<|k|의 조상들을 |anc|에 내림차순으로 담는다(|anc[l]=2|에서 멈춤)@>=
var l int64
{
	jj := k
	for l = 0; ; l++ {
		anc[l] = jj
		if jj == 2 {
			break
		}
		jj = down[jj]
	}
}

@ |specGate|는 이름과 종류만 매긴 게이트를 만든다. $b$ 게이트의 둘째 인수
$c_{k-i}^{\,jN-i}$는 $f=\flog(jN-i)$가 양수면 저장된 $c$ 게이트, 아니면 $v_0$
줄의 값이다.

@<게이트 $b_k^{\,jN}=d_k^{\,i}\land c_{k-i}^{\,jN-i}$를 셈한다@>=
specGate := func(a byte, kk, jj, t int64) *gbgraph.Vertex {
	g := &b.g.Vertices[b.nextV]
	b.nextV++
	g.Name = fmt.Sprintf("%c%d:%d", a, kk, jj)
	g.Y.I = t
	return g
}
v = specGate('B', k, jN, AND)
b.g.NewArc(v, dd, DELAY) // 첫 인수는 $d_k^{\,i}$
f = flog[jN-i]           // 둘째 인수 $c_{k-i}^{\,jN-i}$를 셈할 채비
if f > 0 {
	b.g.NewArc(v, c[k-i+(f-2)*mPlusN], DELAY)
} else {
	b.g.NewArc(v, b.at(vv, k-i-1), DELAY)
}

@ $l$이 0이면 이 게이트가 $c_k^k=w_k$다.

@<게이트 $c_k^{\,jN}=c_k^{\,i}\lor b_k^{\,jN}$를 셈한다@>=
if l != 0 {
	v = specGate('C', k, jN, OR)
} else {
	v = b.newVert(OR)
}
b.g.NewArc(v, cc, DELAY)             // 첫 인수는 $c_k^{\,i}$
b.g.NewArc(v, b.vAt(int64(b.nextV)-2), DELAY) // 둘째 인수는 $b_k^{\,jN}$

@ $f=\flog(jN-i)$를 다시 쓴다. $d$ 게이트의 둘째 인수는 저장된 $c$ 게이트 바로
{\sl뒤\/}의 $d$ 게이트다 --- 배열 인덱스가 아니라 포인터로 한 칸 뒤다.

@<게이트 $d_k^{\,jN}=d_k^{\,i}\land d_{k-i}^{\,jN-i}$를 셈한다@>=
v = specGate('D', k, jN, AND)
b.g.NewArc(v, dd, DELAY) // 첫 인수는 $d_k^{\,i}$
if f > 0 {
	b.g.NewArc(v, b.at(c[k-i+(f-2)*mPlusN], 1), DELAY)
} else {
	b.g.NewArc(v, b.at(uu, k-i-1), DELAY)
}

@ 출력 목록은 리틀엔디언으로 넣어 빅엔디언 차례가 된다.

@<마지막 게이트 $Z=U\oplus W$를 셈해 출력으로 적는다@>=
b.startPrefix("Z")
for k := int64(0); k < mPlusN; k++ {
	a := b.g.VirginArc()
	a.Tip = b.make2(XOR, b.at(uu, k), w[k])
	a.Next = b.g.ZZ.A
	b.g.ZZ.A = a
}

@* 부분 평가. |PartialGates(g,r,prob,seed,buf)|는 주어진 게이트 그래프 |g|에
``부분 평가(partial evaluation)''를 해, 곧 입력 가운데 일부를 상수 값으로
못박고 결과를 줄여서 새 게이트 그래프를 만든다. 새 그래프는 대개 |g|보다
작다. 사실 훨씬 작을 수도 있다. 이 과정에서 그래프 |g|는 부서진다.

|g|의 앞 |r|개 입력은 조건 없이 남긴다. 나머지 입력은 저마다 |prob|$/65536$의
확률로 남기고, 남기지 않은 것에는 무작위 상수 값을 매긴다. 예컨대
|prob|$=32768$이면 입력의 절반쯤이 상수가 된다. |seed| 매개변수는 기계에 무관한
난수의 원천을 정하며, 0과 $2^{31}-1$ 사이의 아무 값이나 좋다.

|buf|가 |nil|이 아니면 부분 평가의 기록을 거기에 적는다. 앞 |r|개 뒤의 입력
게이트마다 글자 하나씩인데, 남겼으면 |'*'|, 0으로 매겼으면 |'0'|, 1로 매겼으면
|'1'|이다.

@ 새 그래프에는 출력 값을 적어도 하나 셈하는 데 이바지하는 게이트만 담긴다.
그러므로 ``남겼다''고 한 입력 게이트조차 사라질 수 있다---값이 상수로 못박히지
않았더라도 말이다. 어느 입력 게이트가 살아남았는지는 정점의 |Name| 필드로
가려낼 수 있다.

그래프 |g|가 |Risc|로 만든 것이라면 |r|을 1 이상으로 두고 싶을 것이다. 첫
입력 \.{RUN}이 0이 되면 RISC 회로 전체가 0으로 무너져 버리기 때문이다.

|PartialGates(Prod(m,n),m,0,seed,buf)|는 흥미로운 그래프 갈래를 낸다. 주어진
|m|비트 수에 (무작위로 골랐지만) 고정된 |n|비트 상수를 곱하는 회로에 대응하는
그래프다. 그 상수가 0이 아니면 ``남긴'' |m|개 입력 게이트는 반드시 모두
살아남는다. 시연 프로그램 {\sc MULTIPLY}가 이런 회로를 보여 준다.

|g|는 일반화 그물이어도 된다. 곧 앞서 말한 |'C'|나 |'='| 게이트를 담고 있어도
괜찮다. 그리고 |r|이 충분히 크면 |PartialGates|는 |reduce| 루틴과 같은 일을
하게 된다. 그래서 그 내부 루틴을 따로 공개할 필요가 없다.

@<PartialGates 서브루틴@>=
func PartialGates(g *gbgraph.Graph, r, prob, seed int64, buf *strings.Builder) (*gbgraph.Graph, error) {
	if g == nil {
		return nil, gbgraph.MissingOperand
	}
	rng := gbflip.New(seed)
	@<앞 |r|개 뒤 입력에 무작위 상수를 매긴다@>
	b := &builder{}
	rg, err := b.reduce(g)
	if err != nil {
		return nil, err
	}
	@<줄인 그래프에 알맞은 |id|를 매긴다@>
	return rg, nil
}

@ 입력 게이트를 만나면 |prob| 관문으로 남길지 정하고, 남기지 않으면 무작위 0·1
상수로 만든다. 입력이 아닌 게이트를 처음 만나면 멈춘다.

@<앞 |r|개 뒤 입력에 무작위 상수를 매긴다@>=
loop:
for vi := r; vi < g.N; vi++ {
	v := &g.Vertices[vi]
	switch v.Y.I {
	case 'C', '=':
		continue // 뒤에 입력이 더 올 수 있다
	case 'I':
		if (rng.Next() >> 15) >= prob {
			v.Y.I = 'C'
			v.Z.I = rng.Next() >> 30
			if buf != nil {
				buf.WriteByte(byte(v.Z.I) + '0')
			}
		} else if buf != nil {
			buf.WriteByte('*')
		}
	default:
		break loop // 입력 게이트가 더는 올 수 없다
	}
}

@ |buf|는 그래프에 영향이 없으므로 |id|에 담지 않는다. 원래 |id|가 길면 줄인다.

@<줄인 그래프에 알맞은 |id|를 매긴다@>=
if rg != nil {
	id := rg.ID
	if len(id) > 54 {
		id = id[:51] + "..."
	}
	rg.ID = fmt.Sprintf("partial_gates(%s,%d,%d,%d)", id, r, prob, seed)
}

@* 시험. {\sc GB\_\,SAMPLE}이 내놓는 |sample.correct|와 대조한다. |Risc(16)|은
게이트 $1400+115\cdot16=3240$개짜리 그래프이고, |PartialGates(Risc(16),1,43210,
98765)|는 정점 1702개·호 3796개짜리 그래프이며 그 79번 정점은 래치 ``R10:10''이다.

@(gbgates_test.go@>=
package gbgates

import (
	"strings"
	"testing"
)

func TestRiscSize(t *testing.T) {
	g, err := Risc(16)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 3240 {
		t.Fatalf("Risc(16).N = %d, 원함 3240", g.N)
	}
	if g.ID != "risc(16)" {
		t.Errorf("ID = %q", g.ID)
	}
}

@ @(gbgates_test.go@>=
func TestPartialGates(t *testing.T) {
	g, err := Risc(16)
	if err != nil {
		t.Fatal(err)
	}
	pg, err := PartialGates(g, 1, 43210, 98765, nil)
	if err != nil {
		t.Fatal(err)
	}
	if pg.ID != "partial_gates(risc(16),1,43210,98765)" {
		t.Errorf("ID = %q", pg.ID)
	}
	if pg.N != 1702 || pg.M != 3796 {
		t.Fatalf("N=%d M=%d, 원함 N=1702 M=3796", pg.N, pg.M)
	}
	v := &pg.Vertices[79]
	if v.Name != "R10:10" || v.Y.I != 'L' {
		t.Fatalf("정점 79 = %q, 종류 %c, 원함 R10:10 종류 L", v.Name, byte(v.Y.I))
	}
}

@ |Prod(m,n)|과 |GateEval|로 실제 곱셈을 확인한다. 입력은 |m+n|비트(리틀엔디언
|x| 다음 |y|), 출력은 |m+n|비트(빅엔디언)다.

@(gbgates_test.go@>=
func TestProdMultiplies(t *testing.T) {
	const m, n = 8, 8
	g, err := Prod(m, n)
	if err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct{ x, y int64 }{{0, 0}, {1, 1}, {12, 12}, {255, 255}, {13, 19}} {
		var sb strings.Builder
		for i := 0; i < m; i++ {
			sb.WriteByte(byte('0' + (c.x>>i)&1))
		}
		for i := 0; i < n; i++ {
			sb.WriteByte(byte('0' + (c.y>>i)&1))
		}
		out, code := GateEval(g, sb.String())
		if code != 0 {
			t.Fatalf("GateEval 코드 %d", code)
		}
		var got int64
		for i := 0; i < len(out); i++ {
			got = 2*got + int64(out[i]-'0')
		}
		if got != c.x*c.y {
			t.Errorf("%d*%d = %d, 원함 %d", c.x, c.y, got, c.x*c.y)
		}
	}
}

@* 찾아보기.
