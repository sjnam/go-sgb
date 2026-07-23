% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_raman.w를 Go로 이식한다.
@i ../gbtypes.w

\input kotexgweb
\def\title{GB\_\,RAMAN}
\let\==\equiv % 합동 기호

@* 들어가며. 이 모듈은 |Raman| 서브루틴을 내놓는다. Alexander Lubotzky,
@^Lubotzky, Alexander@>@^Phillips, Ralph Saul@>@^Sarnak, Peter@>
Ralph Phillips, Peter Sarnak이 세운 이론에 바탕해 ``Ramanujan 그래프''의 한
@^Ramanujan 그래프@>
갈래를 짓는다 [{\sl Combinatorica \bf8} (1988), 261--277 참고].

Ramanujan 그래프는 다음 성질들로 정의된다. 연결된 무향 그래프이고, 모든 정점의
차수가 $k$이며, 인접 행렬의 모든 고윳값이 $\pm k$이거나 절댓값이
$\le2\sqrt{\mathstrut k-1}$이다. 이런 그래프는 좋은 확장(expansion) 성질과 작은
지름, 그리고 비교적 작은 독립집합을 갖는 것으로 알려져 있다. 또 이분 그래프가
아닌 한
$$k\big/\bigl(2\sqrt{\mathstrut k-1}\,\bigr)$$
가지보다 적은 색으로는 칠할 수 없다. 여기서 짓는 Ramanujan 그래프의 구체적인
예들은 정수 계수 사원수(quaternion)의 흥미로운 성질에 바탕한다. 쓰임새는 데모
{\sc GIRTH}에서 볼 수 있다.

@ |Raman(p,q,type,reduce)|는 각 정점의 차수가 |p+1|인 무향 그래프를 짓는다.
정점 수는 |type=1|이면 |q+1|, |type=2|이면 ${1\over2}q(q+1)$, |type=3|이면
${1\over2}(q-1)q(q+1)$, |type=4|이면 |(q-1)q(q+1)|이다. 그래프는 |type=4|일
때만 이분이다.

|p|와 |q|는 서로 다른 소수여야 하고 |q|는 홀수여야 한다. 여기에 더해 제약이
몇 가지 붙는다. |p=2|이면 |q|가 $q\bmod8\in\{1,3\}$이면서
$q\bmod13\in\{1,3,4,9,10,12\}$를 만족해야 한다---이 조건 하나로 모든 소수의
4분의 1쯤이 걸러진다. 또 |type=3|이면 |p|가 |q|를 법으로 하는 이차 잉여라야
한다. 다시 말해 $x^2\=p\pmod q$인 정수 $x$가 있어야 한다. |type=4|이면
거꾸로 |p|가 이차 잉여가 아니라야 한다.

@ |type=0|을 주면 절차가 허용되는 가장 큰 |type|(3이나 4)을 스스로 고르고, 고른
값이 그래프 |ID| 문자열에 적힌다. 예컨대 |type=0|, |p=2|, |q=43|이면 2가 43을
법으로 하는 이차 잉여가 아니므로 type 4 그래프가 만들어진다. 그 그래프는 정점이
$44\times43\times42=79464$개이고 각 정점의 차수가 3이다. (type 3과 4의 그래프는
|q|가 제법 작아도 꽤 커질 수 있음에 유의하라.)

|q|의 최댓값은 46337이다. 제곱이 $2^{31}$보다 작은 가장 큰 소수다. 물론 이 값은
type 1 그래프에나 쓸 만하다.

|reduce|가 0이 아니면 자기 고리와 중복 간선을 없앤다. 그러면 위에서 말한 바와
달리 어떤 정점의 차수는 |p+1|보다 작아질 수 있다.

type 4 그래프는 이분이지만, GraphBase의 다른 이분 그래프들과 달리 정점이 두
덩이로 갈라져 있지는 않다. 모든 간선의 길이는 1이다.

@ 문제가 생기면 |Raman|은 무엇이 잘못됐는지 밝히는 오류를 돌려준다. \CEE/ 원본이
전역 |panic_code|에 담던 코드들에 대응한다. 메모리 부족은 \GO/의 쓰레기 수거기
아래서 실질적으로 안 나므로, 정수론적 실패만 구분한다.

@c
package gbraman

import (
	"errors"
	"fmt"
	"strconv"
	@#
	"github.com/sjnam/go-sgb/gbgraph"
)

@<오류 값@>
@<타입 선언@>
@<Raman 서브루틴@>
@<수 이론 서브루틴@>
@<정점 라벨 서브루틴@>
@<생성원 서브루틴@>
@<간선 잇기 서브루틴@>
@<보조 서브루틴@>

@ @<오류 값@>=
var (
	ErrQRange    = errors.New("q is out of range")
	ErrPRange    = errors.New("p is out of range")
	ErrQNotPrime = errors.New("q is not prime")
	ErrQIncompat = errors.New("q is not compatible with p=2")
	ErrPMultQ    = errors.New("p is a multiple of q")
	ErrWrongType = errors.New("wrong type for p modulo q")
	ErrQTooBig   = errors.New("q is too big")
	ErrPTooBig   = errors.New("p is too big")
	ErrPNotPrime = errors.New("p is not prime")
)

@ |builder|는 \CEE/의 정적 전역(모듈로 |q| 산술표, 생성원 표와 그 개수)을 담아
패키지 수준 가변 상태를 피한다. |quaternion|은 사원수 하나와 그 켤레(역원)의
인덱스를 담는다.

@<타입 선언@>=
type builder struct {
	q                 int64
	qSqr, qSqrt, qInv []int64
	gen               []quaternion
	genCount, maxGen  int64
}

type quaternion struct {
	a0, a1, a2, a3 int64 // 사원수 계수
	bar            int64 // 켤레(역원) 사원수의 인덱스
}

@ |Raman|의 뼈대다. 표를 세우고, |type|을 고르거나 검사해 정점 수 |n|을 정한
뒤, 정점에 라벨을 붙이고, |p+1|개의 생성원을 셈해, 그 순열들로 간선을 붙인다.

@<Raman 서브루틴@>=
func Raman(p, q, typ, reduce int64) (*gbgraph.Graph, error) {
	bd := &builder{q: q}
	if err := bd.prepareTables(p); err != nil {
		return nil, err
	}
	typ, n, nFactor, err := bd.chooseType(p, typ)
	if err != nil {
		return nil, err
	}
	g := gbgraph.NewGraph(n)
	g.ID = fmt.Sprintf("raman(%d,%d,%d,%d)", p, q, typ, reduce)
	g.UtilTypes = "ZZZIIZIZZZZZZZ"
	bd.assignLabels(g, typ, nFactor)
	if err := bd.computeGenerators(p); err != nil {
		return nil, err
	}
	bd.appendEdges(g, p, typ, nFactor, reduce)
	return g, nil
}

@* 억지 정수론. 모듈로 |q| 역원과 제곱근을 유클리드 알고리즘 따위로 구하는
대신, |q|가 정점 수보다 훨씬 작으니 표를 통째로 만든다. |qSqr[k]|는 $k^2$,
|qSqrt[k]|는 $\sqrt{\mathstrut k}$(이차 잉여가 아니면 $-1$), |qInv[k]|는 |k|의
역원이다.

@ |prepareTables|는 세 표를 세운다. |q|가 소수인지는 원시근을 찾다가 은근히
확인된다---소수가 아니면 그 최소 약수 때문에 원시근 찾기 안쪽 반복이 |k>=q|로
끝난다.

@<수 이론 서브루틴@>=
func (bd *builder) prepareTables(p int64) error {
	q := bd.q
	if q < 3 || q > 46337 {
		return ErrQRange // |q|가 너무 작거나 크다
	}
	if p < 2 {
		return ErrPRange // |p|가 너무 작다
	}
	bd.qSqr = make([]int64, q)
	bd.qSqrt = make([]int64, q)
	bd.qInv = make([]int64, q)
	@<qSqr와 qSqrt 표를 셈한다@>
	@<원시근 a와 그 역원 aa를 찾는다@>
	@<qInv 표를 셈한다@>
	return nil
}

@ @<qSqr와 qSqrt 표를 셈한다@>=
for a := int64(1); a < q; a++ {
	bd.qSqrt[a] = -1
}
sq := int64(1)
for a := int64(1); a < q; a++ {
	bd.qSqr[a] = sq
	bd.qSqrt[sq] = q - a // 더 작은 제곱근이 살아남는다
	bd.qInv[sq] = -1     // |sq|가 원시근이 될 수 없음을 표시
	sq = (sq + a + a + 1) % q
}

@ 원시근이면 그 거듭제곱이 모든 것을 낳는다. |q|가 소수가 아니면 안쪽 반복이
|k>=q|로 끝난다.

@<원시근 a와 그 역원 aa를 찾는다@>=
var a, aa int64
FindRoot:
for a = 2; ; a++ {
	if bd.qInv[a] == 0 {
		b, k := a, int64(1)
		for b != 1 && k < q {
			bd.qInv[b] = -1
			aa = b
			b = (a * b) % q
			k++
		}
		if k >= q {
			return ErrQNotPrime
		}
		if k == q-1 {
			break FindRoot // |a|가 찾던 원시근이다
		}
	}
}

@ 원시근을 찾으면 역원을 모두 쉽게 낳는다. |qInv[0]=q|로 두어 $\infty$를 안에서
나타낸다.

@<qInv 표를 셈한다@>=
b, bb := a, aa
for b != bb {
	bd.qInv[b] = bb
	bd.qInv[bb] = b
	b = (a * b) % q
	bb = (aa * bb) % q
}
bd.qInv[1] = 1
bd.qInv[b] = b // 이 자리에서 |b|는 |q-1|이라야 한다
bd.qInv[0] = q

@ |chooseType|은 |type|을 고르거나 검사하고 정점 수 |n|과 |nFactor|를 정한다.
|p=2|일 때의 |q| 조건은 이차 상호 법칙에 따라 $\sqrt{-2}$와 $\sqrt{13}$가
모듈로 |q|로 있다는 것과 같다.

@<수 이론 서브루틴@>=
func (bd *builder) chooseType(p, typ int64) (t, n, nFactor int64, err error) {
	q := bd.q
	if p == 2 {
		if bd.qSqrt[13%q] < 0 || bd.qSqrt[q-2] < 0 {
			return 0, 0, 0, ErrQIncompat
		}
	}
	pModQ := p % q
	if pModQ == 0 {
		return 0, 0, 0, ErrPMultQ
	}
	if typ == 0 {
		if bd.qSqrt[pModQ] > 0 {
			typ = 3
		} else {
			typ = 4
		}
	}
	if typ == 3 {
		nFactor = (q - 1) / 2
	} else {
		nFactor = q - 1
	}
	@<type에 따라 정점 수 n을 정한다@>
	if p >= 0x3fffffff/n { // $(p+1)n\ge2^{30}$
		return 0, 0, 0, ErrPTooBig
	}
	return typ, n, nFactor, nil
}

@ @<type에 따라 정점 수 n을 정한다@>=
switch typ {
case 1:
	n = q + 1
case 2:
	n = q * (q + 1) / 2
default:
	if (bd.qSqrt[pModQ] > 0 && typ != 3) || (bd.qSqrt[pModQ] < 0 && typ != 4) {
		return 0, 0, 0, ErrWrongType
	}
	if q > 1289 {
		return 0, 0, 0, ErrQTooBig // type 3, 4에는 너무 크다
	}
	n = nFactor * q * (q + 1)
}

@* 정점. type 1 그래프의 정점은 집합 $\{0,1,\ldots,q-1,\infty\}$이다. 곧 |q|를
법으로 하는 정수들에 ``무한'' 원소 하나를 던져 넣은 것이다. 이 값들에 상수를
더하거나 곱하거나 역수를 취하는 연산을 |q|를 법으로 베푸는 것이 이 모듈의
착상이다.

type 2 그래프의 정점은 같은 $(q+1)$원소 집합에서 고른, 서로 다른 두 원소의
순서 없는 짝이다.

@ type 3과 4의 정점은 |q|를 법으로 행렬식이 0이 아닌 $2\times2$ 행렬이다.
type 3 행렬의 행렬식은 그중에서도 0이 아닌 이차 잉여다. 우리는 한 행렬의 모든
성분에 (|q|를 법으로) 같은 상수를 곱해 다른 행렬이 얻어지면 그 둘을 동치로
여긴다. 그래서 둘째 행이 $(0,1)$이거나 $(1,x)$ 꼴이 되도록 모든 행렬을
정규화한다.

이런 식으로 얻어지는 type 4 행렬의 동치류는 모두 $(q+1)q(q-1)$개다. 둘째 행을
고르는 방법이 $q+1$가지이고, 그다음이 두 경우로 갈리기 때문이다. 둘째 행이
$(0,1)$이면 오른쪽 위 성분을 아무렇게나 고르고 왼쪽 위 성분을 0이 아니게 고른다.
둘째 행이 $(1,x)$이면 왼쪽 위 성분을 아무렇게나 고른 다음 행렬식이 0이 아니게
되도록 오른쪽 위 성분을 고른다. type 3의 셈도 비슷하되 ``0이 아닌''이 ``0이 아닌
이차 잉여''로 바뀌므로 경우의 수가 정확히 절반이다.

@ 이 그래프들의 정점에 대응하는 행렬 동치류가 행렬 곱셈에 대해 닫혀 있음은
확인하기 어렵지 않다. 그러므로 정점을 유한군의 원소로 볼 수 있다.

주어진 |q|에 대한 type 3 군은 흔히 일차 분수군 $LF(2,{\bf F}_q)$, 또는 사영
특수선형군 $PSL(2,{\bf F}_q)$, 또는 선형 단순군 $L_2(q)$라 불린다. 행렬 $A$와
$-A$를 동치로 볼 때 행렬식이 1인($\bmod\ q$) $2\times2$ 행렬들의 군으로 볼 수도
있다. (이 군은 $q>2$인 모든 소수에 대해 단순군이다.) type 4 군의 공식 이름은
|q|개 원소의 체 위 차수 2의 사영 일반선형군 $PGL(2,{\bf F}_q)$다.

@ 라벨을 붙이며 유틸리티 필드 |X.I|·|Y.I|·|Z.I|에 좌표를 적어 두어, 나중에
상을 셈할 때 쓴다.

@<정점 라벨 서브루틴@>=
func (bd *builder) assignLabels(g *gbgraph.Graph, typ, nFactor int64) {
	q := bd.q
	switch typ {
	case 1:
		@<집합 $\{0,\ldots,q-1,\infty\}$에서 라벨을 붙인다@>
	case 2:
		@<서로 다른 두 원소 짝에 라벨을 붙인다@>
	default:
		@<사영 행렬 라벨을 붙인다@>
	}
}

@ type 1은 |X.I|에 일련번호를 두되 |q|로 $\infty$를 나타낸다. |Y.I|는 안 쓰므로
끈다.

@<집합 $\{0,\ldots,q-1,\infty\}$에서 라벨을 붙인다@>=
g.SetUtilType(4, 'Z')
for a := int64(0); a < q; a++ {
	g.Vertices[a].Name = strconv.FormatInt(a, 10)
	g.Vertices[a].X.I = a
}
g.Vertices[q].Name = "INF"
g.Vertices[q].X.I = q

@ type 2 라벨은 $\{0,1\}$부터 $\{q-1,\infty\}$까지 훑는다. 두 계수를 |X.I|와
|Y.I|에 둔다.

@<서로 다른 두 원소 짝에 라벨을 붙인다@>=
vi := int64(0)
for a := int64(0); a < q; a++ {
	for aa := a + 1; aa <= q; aa++ {
		if aa == q {
			g.Vertices[vi].Name = fmt.Sprintf("{%d,INF}", a)
		} else {
			g.Vertices[vi].Name = fmt.Sprintf("{%d,%d}", a, aa)
		}
		g.Vertices[vi].X.I = a
		g.Vertices[vi].Y.I = aa
		vi++
	}
}

@ type 3·4는 |X.I|·|Y.I|에 첫 행 두 원소를, |Z.I|에 둘째 행의 비($\infty$는
|q|)를 둔다. 정점은 둘째 행과 위 한쪽 원소가 정해진 |q(q+1)|개 블록으로 나뉘고,
블록 안에서 행렬식이 type 3이면 $1^2,\ldots,({q-1\over2})^2$, type 4이면
$1,\ldots,q-1$을 훑는다.

@<사영 행렬 라벨을 붙인다@>=
g.SetUtilType(5, 'I')
vi := int64(0)
for c := int64(0); c <= q; c++ {
	for b := int64(0); b < q; b++ {
		for a := int64(1); a <= nFactor; a++ {
			v := &g.Vertices[vi]
			v.Z.I = c
			@<정점 |v|의 행렬 라벨을 매긴다@>
			vi++
		}
	}
}

@ 행렬식은 type 3이면 $a^2$, type 4이면 $a$다.

@<정점 |v|의 행렬 라벨을 매긴다@>=
var det int64
if typ == 3 {
	det = bd.qSqr[a]
} else {
	det = a
}
if c == q { // 둘째 행이 $(0,1)$
	v.Y.I = b
	v.X.I = det
	v.Name = fmt.Sprintf("(%d,%d;0,1)", det, b)
} else { // 둘째 행이 $(1,c)$
	v.X.I = b
	v.Y.I = (b*c + q - det) % q
	v.Name = fmt.Sprintf("(%d,%d;1,%d)", b, v.Y.I, c)
}

@* 군 생성원. 정점들의 순열 $\{\pi_0,\pi_1,\ldots,\pi_p\}$을 |p+1|개 정해,
$0\le k\le p$에 대해 호가 $v$에서 $v\pi_k$로 가게 한다. 그러면 그래프의 각
경로가 순열들의 곱으로 정해지고, 그래프의 순환은 순열들의 곱이 제자리에 두는
정점에 대응한다. 각 $\pi_k$의 역도 생성 집합 안의 순열이 되므로 그래프는
무향이다.

각 $\pi_k$는 사실 $2\times2$ 행렬 하나로 정해진다. type 3과 4의 그래프에서는
그래서 순열이 곧 어떤 정점에 대응하고, 정점 $v\pi_k$는 그저 행렬 $v$와 행렬
$\pi_k$의 곱이다.

type 1 그래프에서는 순열이 일차 분수 변환으로 정해진다. 곧
$$v\;\longmapsto\;{av+b\over cv+d}$$
꼴의 사상이다. 이 변환은 $v\in\{0,1,\ldots,q-1,\infty\}$ 전체에 베풀어지는데,
$x\ne0$일 때 $x/0=\infty$이고 $(x\infty+x')/(y\infty+y')=x/y$라는 여느 약속을
따른다. 그런 변환 둘을 합성하면 다시 일차 분수 변환이 되고, 그것은 두 행렬
$\bigl({a\,b\atop c\,d}\bigr)$의 곱에 대응한다.

type 2 그래프는 type 1과 똑같이 다루되, 서로 다른 두 점 $v=\{v_1,v_2\}$의 상을
함께 셈한다. 변환이 가역이므로 두 상도 서로 다르다.

@ |p=2|일 때는 Ramanujan 그래프를 낳는 특별한 생성 행렬 $\pi_0$, $\pi_1$,
$\pi_2$ 세 개가 알려져 있다(아래에서 밝힌다). 그렇지 않으면 |p|는 홀수이고,
생성원은 정수 사원수(integral quaternion)의 이론에 바탕한다.

우리 목적에 맞는 정수 사원수란 $\alpha=a_0+a_1i+a_2j+a_3k$ 꼴의 네쌍이다.
여기서 $a_0,a_1,a_2,a_3$은 정수이고, 곱셈은 결합적이되 교환적이지 않은 규칙
$i^2=j^2=k^2=ijk=-1$을 따른다. $\alpha=a+A$라 쓰자---$a$는 ``스칼라'' $a_0$이고
$A$는 ``벡터'' $a_1i+a_2j+a_3k$다. 그러면 사원수 $\alpha=a+A$와 $\beta=b+B$의
곱은
$$(a+A)(b+B)=ab-A\cdot B+aB+bA+A\times B$$
로 나타낼 수 있다. $A\cdot B$와 $A\times B$는 여느 벡터의 내적과 외적이다.

@ $\alpha=a+A$의 켤레는 $\overline\alpha=a-A$이고,
$\alpha\overline\alpha=a_0^2+a_1^2+a_2^2+a_3^2$이다. 이 중요한 값을
$N(\alpha)$, 곧 $\alpha$의 노름이라 부른다. $N(\alpha\beta)=N(\alpha)N(\beta)$임을
확인하기는 어렵지 않다. 기본 항등식
$\overline{\mathstrut\alpha\beta}=\overline{\mathstrut\beta}\,
\overline{\mathstrut\alpha}$와, $x$가 스칼라일 때 $\alpha x=x\alpha$라는
사실에서 따라 나온다.

정수 사원수에는 아름다운 이론이 딸려 있다. 이를테면 노름이 홀수인 두 정수
사원수의 최대공좌약수를 구하는 유클리드 알고리즘의 멋진 변형이 있다. 이
알고리즘 덕에, 계수가 서로소인 정수 사원수는 노름이 소수인 사원수들로 정준
인수분해된다는 것을 증명할 수 있다. 다만 그 이론의 자세한 내용은 이 문서가
다룰 바를 넘어선다.

@ 우리에게는 다음 사실만으로 넉넉하다. 사원수를 써서 유한군
$PSL(2,{\bf F}_q)$와 $PGL(2,{\bf F}_q)$를 앞서와는 다른 방식으로 정의할 수
있다는 것이다. 두 사원수가 |q|를 법으로 0이 아닌 스칼라 배 관계이면 동치라고
하자. 예컨대 $q=3$이면 $1+4i-j$는 $1+i+2j$와 동치이고, $2+2i+j$와도 동치다.

노름이 |q|의 배수인 사원수를 빼면, 그런 동치류가 정확히 $(q+1)q(q-1)$개
있음이 밝혀진다. 그리고 그것들이 사원수 곱셈에 대해 이루는 군이, |q|를 법으로
하는 $2\times2$ 행렬들의 사영군과 같다. 이를 증명하는 한 가지 방법은 다음
일대일 대응을 쓰는 것이다:
$$a_0+a_1i+a_2j+a_3k\;\longleftrightarrow\;
\left(\matrix{a_0+a_1g+a_3h& -a_1h+a_2+a_3g\cr
-a_1h-a_2+a_3g& a_0-a_1g-a_3h\cr}\right)$$
여기서 $g$와 $h$는 $g^2+h^2\=-1\pmod q$인 정수다.

@ 이제 생성원을 어떻게 찾는지가 남았다. Jacobi는 홀수 |p|를 네 제곱수의 합
@^Jacobi, Carl Gustav Jacob@>
$a_0^2+a_1^2+a_2^2+a_3^2$으로 나타내는 방법의 수가 |p|의 약수의 합의 8배임을
증명했다. [이 사실은 그의 기념비적 저작 {\sl Fundamenta Nova Theori\ae\
Functionum Ellipticorum\/}(쾨니히스베르크, 1829)의 마지막 문장에 나온다.]

특히 |p|가 소수이면 그런 표현이 $8(p+1)$개다. 다시 말해 $N(\alpha)=p$인 사원수
$\alpha=a_0+a_1i+a_2j+a_3k$가 정확히 $8(p+1)$개 있다. 이 사원수들은 여덟 개의
``단위 사원수'' $\{\pm1,\pm i,\pm j,\pm k\}$를 곱하는 관계 아래 |p+1|개의
동치류를 이룬다. 우리는 각 동치류에서 원소를 하나씩 고르고, 그렇게 얻은 |p+1|개
사원수가 |p+1|개 행렬에 대응하며, 그 행렬들이 지어질 그래프의 각 정점에서
나가는 |p+1|개 호를 낳는다.

@ |computeGenerators|는 |gen| 표를 채운다. |p|가 소수가 아니면 |p+1|개보다 많은
해를 찾으므로 여분 자리를 하나 더 둔다.

@<생성원 서브루틴@>=
func (bd *builder) computeGenerators(p int64) error {
	bd.gen = make([]quaternion, p+2)
	bd.genCount = 0
	bd.maxGen = p + 1
	if p == 2 {
		bd.specialGenerators()
	} else {
		bd.quaternionGenerators(p)
	}
	if bd.genCount != bd.maxGen {
		return ErrPNotPrime
	}
	return nil
}

@ 앞서 말했듯 노름이 |p|인 사원수는 여덟 개씩, 단위 사원수 배만큼만 서로 다른
채로 나온다. 그러니 그 여덟 중 하나를 골라야 한다. $a_0^2+a_1^2+a_2^2+a_3^2=p$
라 하자.

|p| mod 4가 1이면 $a$들 가운데 정확히 하나가 홀수다. 그것을 $a_0$이라 부르고
양의 부호를 준다. |p| mod 4가 3이면 정확히 하나가 짝수다. 그것을 $a_0$이라
부르고, 0이 아니면 양수로 만든다. 만약 $a_0=0$이면 나머지 가운데 하나---가장
큰 값이 여럿이면 그중 맨 오른쪽 것---를 양수로 만든다. 이렇게 하면 동치인 여덟
사원수의 묶음마다 유일한 대표를 얻는다.

예를 들어 노름이 3인 사원수 넷은 $\pm i\pm j+k$이고, 노름이 5인 여섯은
$1\pm2i$, $1\pm2j$, $1\pm2k$다. 각각 |p+1|개임에 유의하라.

@ 아래 프로그램은 $a\not\==b\==c\==d$ (mod~2)이고 $b\le c\le d$인
$a^2+b^2+c^2+d^2=p$의 해를 낳는다. 변수 |bb|, |cc|는 각각 $p-a^2-3b^2$, $p-a^2-2c^2$를, |aa|는
$p-a^2-b^2-c^2-d^2$를 담는다. (\CEE/ 원본의 |sb|는 여기서 안 쓰이므로 뺐다.)

@<생성원 서브루틴@>=
func (bd *builder) quaternionGenerators(p int64) {
	pp := (p >> 1) & 1 // $p\bmod4=1$이면 0, $p\bmod4=3$이면 1
	for a, sa := 1-pp, p-(1-pp); sa > 0; sa, a = sa-((a+1)<<2), a+2 {
		for b, bb := pp, sa-3*pp; bb >= 0; bb, b = bb-12*(b+1), b+2 {
			for c, cc := b, bb; cc >= 0; cc, c = cc-((c+1)<<3), c+2 {
				for d, aa := c, cc; aa >= 0; aa, d = aa-((d+1)<<2), d+2 {
					if aa == 0 {
						@<$a+bi+cj+dk$에 얽힌 사원수들을 등록한다@>
					}
				}
			}
		}
	}
	@<gen 표를 행렬 꼴로 바꾼다@>
}

@ |a>0|이고 $0<b<c<d$이면 $\{b,c,d\}$를 여섯 가지로 치환하고 부호를 여덟 가지로
붙여, 노름이 같은 사원수의 부류 48개를 얻는다. 이런 일은 이를테면 $p=71$이고
$(a,b,c,d)=(6,1,3,5)$일 때 일어난다. |a=0|이거나 $b=0$이거나 $b=c$이거나
$c=d$이면 더 적게 나온다.

사원수에 대응하는 행렬의 역행렬은 그 켤레 사원수에 대응하는 행렬이다. 그러므로
생성 행렬 $\pi_k$가 자기 자신의 역이 될 필요충분조건은 그것이 |a=0|인 사원수에서
나온 것이라는 점이다. |deposit|은 새 사원수와 그 켤레를 함께 생성원 표에 넣는다.

@<생성원 서브루틴@>=
func (bd *builder) deposit(a, b, c, d int64) {
	if bd.genCount >= bd.maxGen { // |p+1|개를 이미 찾았다---|p|가 소수가 아니다
		bd.genCount = bd.maxGen + 1
		return
	}
	i := bd.genCount
	bd.gen[i].a0, bd.gen[i+1].a0 = a, a
	bd.gen[i].a1, bd.gen[i+1].a1 = b, -b
	bd.gen[i].a2, bd.gen[i+1].a2 = c, -c
	bd.gen[i].a3, bd.gen[i+1].a3 = d, -d
	if a != 0 {
		bd.gen[i].bar = i + 1
		bd.gen[i+1].bar = i
		bd.genCount += 2
	} else {
		bd.gen[i].bar = i
		bd.genCount++
	}
}

@ 기본 해와 |b|·|c|의 부호를 바꾼 것들을 먼저 넣고, 나머지 치환들은 두 갈래로
나눠 넣는다.

@<$a+bi+cj+dk$에 얽힌 사원수들을 등록한다@>=
bd.deposit(a, b, c, d)
if b != 0 {
	bd.deposit(a, -b, c, d)
	bd.deposit(a, -b, -c, d)
}
if c != 0 {
	bd.deposit(a, b, -c, d)
}
@<$b<c$일 때의 치환들을 등록한다@>
@<$c<d$일 때의 치환들을 등록한다@>

@ $b<c$이면 $\{b,c\}$를 맞바꾼 치환들이 더 나온다.

@<$b<c$일 때의 치환들을 등록한다@>=
if b < c {
	bd.deposit(a, c, b, d)
	bd.deposit(a, -c, b, d)
	bd.deposit(a, c, d, b)
	bd.deposit(a, -c, d, b)
	if b != 0 {
		bd.deposit(a, c, -b, d)
		bd.deposit(a, -c, -b, d)
		bd.deposit(a, c, d, -b)
		bd.deposit(a, -c, d, -b)
	}
}

@ $c<d$이면 $d$를 셋째 자리로 올린 치환들이 더 나온다.

@<$c<d$일 때의 치환들을 등록한다@>=
if c < d {
	bd.deposit(a, b, d, c)
	bd.deposit(a, d, b, c)
	if b != 0 {
		bd.deposit(a, -b, d, c)
		bd.deposit(a, -b, d, -c)
		bd.deposit(a, d, -b, c)
		bd.deposit(a, d, -b, -c)
	}
	if c != 0 {
		bd.deposit(a, b, d, -c)
		bd.deposit(a, d, b, -c)
	}
	if b < c {
		bd.deposit(a, d, c, b)
		bd.deposit(a, d, -c, b)
		if b != 0 {
			bd.deposit(a, d, c, -b)
			bd.deposit(a, d, -c, -b)
		}
	}
}

@ 이제 사원수 꼴로 찾아 둔 생성원을, 앞서 말한 대응을 써서 $2\times2$ 행렬로
바꾼다. $g^2+h^2\==-1$ (mod~|q|)인 정수 $g,h$는 언제나
$$g=\sqrt{\mathstrut k}\qquad\hbox{그리고}\qquad h=\sqrt{\mathstrut q-1-k}$$
로 찾을 수 있다. 여기서 $k$는 |q|를 법으로 하는 가장 큰 이차 잉여다.

왜 이것이 늘 통하는가. $q-1$이 이차 잉여가 아니고 $k+1$도 이차 잉여가 아니라면,
$q-1-k$는 두 비잉여의 곱 $(q-1)(k+1)$과 합동이므로 이차 잉여일 수밖에 없기
때문이다. (|h=0|일 필요충분조건은 $q\bmod4=1$이고, |h=1|일 필요충분조건은
$q\bmod8=3$이다.)

@<gen 표를 행렬 꼴로 바꾼다@>=
q := bd.q
var kk int64
for kk = q - 1; bd.qSqrt[kk] < 0; kk-- {
}
gg := bd.qSqrt[kk]
hh := bd.qSqrt[q-1-kk]
for k := p; k >= 0; k-- {
	a0, a1, a2, a3 := bd.gen[k].a0, bd.gen[k].a1, bd.gen[k].a2, bd.gen[k].a3
	@<사원수 $(a0,a1,a2,a3)$을 행렬 항목으로 바꾼다@>
}

@ @<사원수 $(a0,a1,a2,a3)$을 행렬 항목으로 바꾼다@>=
a00 := (a0 + gg*a1 + hh*a3) % q
if a00 < 0 {
	a00 += q
}
a11 := (a0 - gg*a1 - hh*a3) % q
if a11 < 0 {
	a11 += q
}
a01 := (a2 + gg*a3 - hh*a1) % q
if a01 < 0 {
	a01 += q
}
a10 := (-a2 + gg*a3 - hh*a1) % q
if a10 < 0 {
	a10 += q
}
bd.gen[k].a0, bd.gen[k].a1, bd.gen[k].a2, bd.gen[k].a3 = a00, a01, a10, a11

@ |p=2|일 때는 Patrick Chiu가 찾아낸 다음 세 생성 행렬이 알맞다:
@^Chiu, Patrick@>
$$\left(\matrix{1&0\cr 0&-1\cr}\right),\qquad
\left(\matrix{s&1+t\cr 1-t&-s\cr}\right),\qquad
\left(\matrix{s&-1-t\cr -1+t&-s\cr}\right)$$
여기서 $s^2\==-2$이고 $t^2\==-26$ (mod~$q$)이다.

세 행렬의 행렬식은 각각 $-1$, 32, 32이고, 둘째와 셋째 행렬의 곱은 항등행렬의
32배다. 2가 이차 잉여일 때($q=8k+1$일 때 그렇다) 행렬식이 모두 이차 잉여가
되므로 type 3 그래프를 얻는다. 2가 이차 비잉여일 때($q=8k+3$일 때 그렇다)는
행렬식이 모두 비잉여가 되므로 type 4 그래프를 얻는다.

@<생성원 서브루틴@>=
func (bd *builder) specialGenerators() {
	q := bd.q
	s := bd.qSqrt[q-2]
	t := (bd.qSqrt[13%q] * s) % q
	bd.gen[0].a0, bd.gen[0].a1, bd.gen[0].a2, bd.gen[0].a3 = 1, 0, 0, q-1
	bd.gen[0].bar = 0
	bd.gen[1].a0, bd.gen[2].a3 = (2+s)%q, (2+s)%q
	bd.gen[1].a1, bd.gen[1].a2 = t, t
	bd.gen[2].a1, bd.gen[2].a2 = q-t, q-t
	bd.gen[1].a3, bd.gen[2].a0 = (q+2-s)%q, (q+2-s)%q
	bd.gen[1].bar, bd.gen[2].bar = 2, 1
	bd.genCount = 3
}

@* 간선 잇기. |gen| 표가 정한 순열들로 호와 그 역호를 만든다. 호의 |A.I|
필드(|ref|)에 그 호를 낳은 순열 번호를 적어, 대개 각 정점의 간선 목록이 |ref|
오름차순이 되게 한다. |reduce|가 0이 아니면 자기 고리와 중복 간선을 없앤다.

@ |reduce|가 0이라도 어떤 순열이 고정점을 가지면 그 정점에 자기 고리(호 두
개)가 생겨, 차수가 |p+1|을 넘을 수 있다. 그래서 무향 그래프 규약대로 자기 고리도
호 두 개로 만든다.

@<간선 잇기 서브루틴@>=
func (bd *builder) appendEdges(g *gbgraph.Graph, p, typ, nFactor, reduce int64) {
	n := g.N
	for k := p; k >= 0; k-- {
		kk := bd.gen[k].bar
		if kk > k { // |kk=k|이거나 |kk=k-1|이라 본다
			continue
		}
		for i := int64(0); i < n; i++ {
			v := &g.Vertices[i]
			u := bd.image(g, v, k, typ, nFactor)
			if u == v {
				if reduce == 0 {
					g.NewEdge(v, v, 1)
					v.Arcs.A.I = kk
					v.Arcs.Next.A.I = k
				}
			} else {
				@<정점 |u|와 |v|를 잇거나 건너뛴다@>
			}
		}
	}
}

@ |u|의 첫 호가 이미 |ref==kk|이면 (|kk=k|인 2-사이클을) 이미 처리한 것이니
건너뛴다. |reduce|이면 |u|로 가는 호가 이미 있는지 살펴 있으면 건너뛴다.

@<정점 |u|와 |v|를 잇거나 건너뛴다@>=
if u.Arcs != nil && u.Arcs.A.I == kk {
	continue // |kk=k|이고 이 2-사이클은 이미 했다
}
if reduce != 0 {
	dup := false
	for ap := v.Arcs; ap != nil; ap = ap.Next {
		if ap.Tip == u {
			dup = true
			break
		}
	}
	if dup {
		continue // |u|와 |v| 사이에 이미 간선이 있다
	}
}
g.NewEdge(v, u, 1)
v.Arcs.A.I = k
u.Arcs.A.I = kk
if ap := v.Arcs.Next; ap != nil && ap.A.I == kk {
	v.Arcs.Next = ap.Next // 이제 |v|의 호 목록이 |ref| 순서로 돌아왔다
	ap.Next = v.Arcs
	v.Arcs = ap
}

@ type 3·4는 $2\times2$ 행렬 곱을 모듈로 |q|로 줄여 알맞은 동치류 |u|를 찾는다.

@<간선 잇기 서브루틴@>=
func (bd *builder) image(g *gbgraph.Graph, v *gbgraph.Vertex, k, typ, nFactor int64) *gbgraph.Vertex {
	q := bd.q
	if typ < 3 {
		@<일차 분수 변환으로 상 |u|를 구한다@>
	}
	a00, a01, a10, a11 := bd.gen[k].a0, bd.gen[k].a1, bd.gen[k].a2, bd.gen[k].a3
	a, b := v.X.I, v.Y.I
	var c, d int64
	if v.Z.I == q {
		c, d = 0, 1
	} else {
		c, d = 1, v.Z.I
	}
	@<행렬 곱 $(aa,bb;cc,dd)=(a,b;c,d)(a00,a01;a10,a11)$를 셈한다@>
	@<라벨이 $(a,b;c,d)$인 정점 |u|로 놓는다@>
}

@ @<행렬 곱 $(aa,bb;cc,dd)=(a,b;c,d)(a00,a01;a10,a11)$를 셈한다@>=
aa := (a*a00 + b*a10) % q
bb := (a*a01 + b*a11) % q
cc := (c*a00 + d*a10) % q
dd := (c*a01 + d*a11) % q
var norm int64
if cc != 0 {
	norm = bd.qInv[cc]
} else {
	norm = bd.qInv[dd]
}
d = (norm * dd) % q
c = (norm * cc) % q
b = (norm * bb) % q
a = (norm * aa) % q

@ 정규화한 뒤 |aa|가 행렬식이다.

@<라벨이 $(a,b;c,d)$인 정점 |u|로 놓는다@>=
if c == 0 {
	d = q
	aa = a
} else {
	aa = (a*d - b) % q
	if aa < 0 {
		aa += q
	}
	b = a
}
det := aa
if typ == 3 {
	det = bd.qSqrt[aa]
}
return &g.Vertices[(d*q+b)*nFactor+det-1]

@* 일차 분수 변환. 비특이 $2\times2$ 행렬 $\bigl({a\,b\atop c\,d}\bigr)$이
주어지면, 일차 분수 변환 $z\mapsto(az+b)/(cz+d)$을 |q|를 법으로 셈하는 것이
아래 서브루틴이다. 행렬은 |gen| 표의 |k|번째 줄에 있다고 본다.

type 2 그래프에서는 똑같은 |linFrac| 값을 몇 번이고 되풀이해 셈하게 되는데,
저자는 그것을 최적화하기에는 너무 게을렀다고 적어 두었다. 우리도 그 게으름을
고스란히 물려받는다---원본과 같은 그래프를 같은 차례로 내는 것이 더 중요하기
때문이다.

@<보조 서브루틴@>=
func (bd *builder) linFrac(a, k int64) int64 {
	q := bd.qInv[0] // 법; |qInv[0]=q|
	a00, a01, a10, a11 := bd.gen[k].a0, bd.gen[k].a1, bd.gen[k].a2, bd.gen[k].a3
	var num, den int64
	if a == q {
		num, den = a00, a10
	} else {
		num = (a00*a + a01) % q
		den = (a10*a + a11) % q
	}
	if den == 0 {
		return q
	}
	return (num * bd.qInv[den]) % q
}

@ type 1은 상이 |linFrac|의 값 그대로다. type 2는 서로 다른 두 점의 상을 셈해
그 짝의 번호를 구한다.

@<일차 분수 변환으로 상 |u|를 구한다@>=
if typ == 1 {
	return &g.Vertices[bd.linFrac(v.X.I, k)]
}
a := bd.linFrac(v.X.I, k)
aa := bd.linFrac(v.Y.I, k)
if a < aa {
	return &g.Vertices[a*(2*q-1-a)/2+aa-1]
}
return &g.Vertices[aa*(2*q-1-aa)/2+a-1]

@* 시험. 문서와 참조 구현에서 확인한 몇 그래프의 정점 수·호 수·표식을 대조한다.

@(gbraman_test.go@>=
package gbraman

import "testing"

func TestRamanBasic(t *testing.T) {
	cases := []struct {
		p, q, typ, reduce int64
		n, m              int64
		id                string
	}{
		{2, 3, 1, 0, 4, 14, "raman(2,3,1,0)"},
		{2, 3, 0, 0, 24, 72, "raman(2,3,4,0)"},
		{3, 5, 1, 0, 6, 24, "raman(3,5,1,0)"},
		{3, 5, 0, 0, 120, 480, "raman(3,5,4,0)"},
		{5, 13, 0, 0, 2184, 13104, "raman(5,13,4,0)"},
		{2, 17, 0, 0, 2448, 7344, "raman(2,17,3,0)"},
		{3, 5, 0, 1, 120, 480, "raman(3,5,4,1)"},
		{31, 3, 0, 4, 12, 96, "raman(31,3,3,4)"},
	}
	for _, c := range cases {
		g, err := Raman(c.p, c.q, c.typ, c.reduce)
		if err != nil {
			t.Errorf("Raman(%d,%d,%d,%d) 오류: %v", c.p, c.q, c.typ, c.reduce, err)
			continue
		}
		if g.N != c.n || g.M != c.m || g.ID != c.id {
			t.Errorf("Raman(%d,%d,%d,%d) = N=%d M=%d id=%q; 기대 N=%d M=%d id=%q",
				c.p, c.q, c.typ, c.reduce, g.N, g.M, g.ID, c.n, c.m, c.id)
		}
	}
}

func TestRamanBadSpecs(t *testing.T) {
	if _, err := Raman(2, 5, 2, 0); err == nil {
		t.Error("Raman(2,5,2,0)는 오류를 돌려줘야 한다")
	}
}

@ 들어가며에서 든 보기를 그대로 확인한다. 2는 43을 법으로 이차 잉여가 아니므로
|Raman(2,43,0,0)|은 type 4를 고르고, 정점이 $44\times43\times42=79464$개에
차수가 3인 그래프를 낸다.

@(gbraman_test.go@>=
func TestRamanTypeZeroExample(t *testing.T) {
	g, err := Raman(2, 43, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if g.ID != "raman(2,43,4,0)" {
		t.Errorf("ID = %q, type 4를 골라야 한다", g.ID)
	}
	if g.N != 44*43*42 {
		t.Errorf("N = %d, 원함 %d", g.N, 44*43*42)
	}
	@<모든 정점의 차수가 3인지 본다@>
}

@ 차수 |p+1|은 |reduce|가 0일 때에만 보장된다.

@<모든 정점의 차수가 3인지 본다@>=
for i := int64(0); i < g.N; i++ {
	d := 0
	for range g.Vertices[i].AllArcs() {
		d++
	}
	if d != 3 {
		t.Fatalf("정점 %d의 차수 = %d, 원함 3", i, d)
	}
}

@ 네 |type|의 정점 수 공식도 확인한다. |q+1|, ${1\over2}q(q+1)$,
${1\over2}(q-1)q(q+1)$, $(q-1)q(q+1)$이다. |p=3|, |q=13|이면 3이 13을 법으로
이차 잉여이므로($4^2=16\=3$) type 3이 쓸 수 있고 type 4는 못 쓴다.

@(gbraman_test.go@>=
func TestVertexCountFormulas(t *testing.T) {
	const q = 13
	for _, c := range []struct {
		p, typ, want int64
	}{
		{3, 1, q + 1},
		{3, 2, q * (q + 1) / 2},
		{3, 3, (q - 1) * q * (q + 1) / 2},
		{5, 4, (q - 1) * q * (q + 1)},
	} {
		g, err := Raman(c.p, q, c.typ, 0)
		if err != nil {
			t.Errorf("Raman(%d,%d,%d,0): %v", c.p, q, c.typ, err)
			continue
		}
		if g.N != c.want {
			t.Errorf("type %d: N = %d, 원함 %d", c.typ, g.N, c.want)
		}
	}
}

@ 노름이 3인 사원수는 넷($\pm i\pm j+k$), 노름이 5인 사원수는 여섯
($1\pm2i$, $1\pm2j$, $1\pm2k$)이라 했다. 생성원의 수가 곧 |p+1|이므로
그래프의 차수로 이를 확인할 수 있다---|p=3|이면 4, |p=5|이면 6이다.

@(gbraman_test.go@>=
func TestGeneratorCount(t *testing.T) {
	for _, c := range []struct{ p, q, deg int64 }{
		{3, 13, 4},
		{5, 13, 6},
	} {
		g, err := Raman(c.p, c.q, 1, 0)
		if err != nil {
			t.Fatal(err)
		}
		d := 0
		for range g.Vertices[0].AllArcs() {
			d++
		}
		if int64(d) != c.deg {
			t.Errorf("p=%d일 때 차수 = %d, 원함 %d", c.p, d, c.deg)
		}
	}
}

@* 색인.
