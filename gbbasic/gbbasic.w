% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_basic.w를 Go로 이식한다.
@i ../types.w

\input kotexgweb
\def\title{GB\_\,BASIC}

@* 들어가며. 이 모듈은 온갖 표준 그래프를 빚어내는 여섯 생성기와, 이미 있는
그래프를 엮거나 탈바꿈시키는 여섯 변환기를 담는다. 통틀어 {\sc GB\_BASIC}은
GraphBase에서 가장 다재다능한 연장통이다---체스판 위의 말 움직임, 삼각형
격자, 부분집합의 교차, 순열과 분할, 이진 트리, 그리고 그래프의 여집합·합집합·
교집합·선그래프·곱·유도까지. 이 여러 함수를 어떻게 쓰는지는 {\sc QUEEN}
데모에서 맛볼 수 있다.

여섯 생성기는 |Board|, |Simplex|, |Subsets|, |Perms|, |Parts|, |Binary|이고,
여섯 변환기는 |Complement|, |Gunion|, |Intersection|, |Lines|, |Product|,
|Induced|이다. 여기에 |Induced|의 손쉬운 응용 둘---|BiComplete|와 |Wheel| ---
과, 자주 쓰이는 특수한 경우를 위한 짧은 별명들을 곁들인다.

@ 프로그램의 뼈대다. 생성기들이 쓰는 임시 작업 배열(\CEE/ 원본의 정적
전역 |nn|, |wr|, |del|, |sig|, |xx|, |yy|)은 패키지 수준 가변 상태를 피해
|builder| 구조체에 담는다. 각 생성기 호출은 자기만의 |builder|를 새로 마련하니
서로 간섭할 일이 없다.

여러 생성기가 공유하는 논리---매개변수 정규화, 정점 수 세기---는 한 곳
넘게 쓰이므로 절이 아니라 |builder|의 메서드로 두었다. 변환기들은 작업 배열이
거의 필요 없고 대신 정점의 유틸리티 필드를 임시로 빌려 쓴다.
@c
package gbbasic

import (
	"fmt"
	"strconv"
	"strings"
	"unsafe"
	@#
	"github.com/sjnam/go-sgb/gbgraph"
)

@<상수 정의@>
@<빌더 자료구조@>
@<공유 생성기 도우미@>
@<기본 서브루틴@>
@<기본 서브루틴의 응용@>

@ \CEE/ 원본은 차원 수를 91 이하로 제한한다. 정점 수가 천문학적이 되므로
실질적 제약은 아니지만, 뒤에 나올 순열 이름이 인쇄 가능한 표준 문자
91개에 대응하기에 이 수가 상한이 된다. 이름을 조립하는 |buffer|의 크기
|bufSize|도 넉넉히 잡는다.

@<상수 정의@>=
const (
	maxD    = 91         // 차원 수의 상한
	bufSize = 4096       // 이름 버퍼의 크기
	maxNNN  = 1000000000 // 정점 수의 상한($10^9$)
)

@ |builder|는 짓고 있는 그래프와 작업 배열들을 한데 묶는다. |sig|만 색인
$d+1$까지 쓰므로 한 칸 더 크게 잡는다.

@<빌더 자료구조@>=
type builder struct {
	g   *gbgraph.Graph // 짓고 있는 그래프
	nn  [maxD + 2]int64 // 각 좌표의 크기
	wr  [maxD + 2]int64 // 이 좌표가 둘러 감기는가?
	del [maxD + 2]int64 // 현재 이동의 변위
	sig [maxD + 2]int64 // 변위 제곱의 부분합
	xx  [maxD + 2]int64 // 좌표값(이동 전)
	yy  [maxD + 2]int64 // 좌표값(이동 후)
}

@ 좌표 나열 $(x_1,\ldots,x_d)$을 |"3.1.4"| 꼴의 이름으로 엮는 도우미다.
여러 생성기가 자기 좌표 구간을 넘겨 쓴다.

@<빌더 자료구조@>=
func dotJoin(vals []int64, sep byte) string {
	var sb strings.Builder
	for i, x := range vals {
		if i > 0 {
			sb.WriteByte(sep)
		}
		sb.WriteString(strconv.FormatInt(x, 10))
	}
	return sb.String()
}

@*격자와 게임판. |Board(n1,n2,n3,n4,piece,wrap,directed)|은 일반화된
직사각형 판 위에서 움직이는 일반화된 체스말의 이동을 그래프로 짓는다. 각
정점은 판 위의 한 자리에, 각 호는 한 자리에서 다른 자리로의 이동에 대응한다.

|n1|부터 |n4|까지가 판의 크기를 정한다. 예컨대 $n_1$행 $n_2$열의 2차원 판을
원하면 $|n1|=n_1$, $|n2|=n_2$, |n3=0|으로 둔다. 세 번째 인자부터 처음 나오는
0 이하의 값에서 차원 훑기가 멈춘다: 그 값이 0이면 앞서 준 |k|개 차원을 쓰고,
음수 $-d$이면 앞 값들을 주기적으로 되풀이해 $d$차원을 만든다. 아무 것도 안
주면(|n1<=0|) 기본 $8\times8$ 판이다.

|piece|는 말의 이동 규칙이다. |piece>0|이면 두 자리 사이 유클리드 거리가
$\sqrt{|piece|}$일 때 이동이 허락된다: |piece=1|은 와지르(왕·룩 공통 수),
|piece=2|는 페르스(왕·비숍 공통 수), |piece=5|는 나이트다. |piece<0|이면 기본
이동의 배수가 다 허락된다: |piece=-1|은 룩, |piece=-2|는 비숍이다. |piece=0|은
기본값 1로 바뀐다. |piece>0|이면 호 길이는 모두 1, |piece<0|이면 기본 이동을
몇 배 한 것인지가 길이다.

@ |wrap|이 0이 아니면, 그 비트가 가리키는 좌표들은 제 크기로 나눈 나머지로
계산된다---곧 그 좌표는 판의 가장자리에서 반대편으로 ``둘러 감긴다''. 좌표
$k_1,k_2,\ldots$가 감기려면 $|wrap|=2^{k_1-1}+2^{k_2-1}+\cdots$이다.
|wrap=-1|이면 모든 좌표가 감긴다. 만든 그래프는 |directed|가 참이 아니면
무향이다.

몇몇 중요한 특수한 경우는 별명으로 부르는 것이 편하다. |Complete(n)|은
$n$개 정점의 완전 그래프, |Transitive(n)|은 추이 토너먼트, |Empty(n)|은
간선 없는 그래프, |Circuit(n)|과 |Cycle(n)|은 길이 |n|의 무향 회로와 유향
순환이다.

@<기본 서브루틴@>=
func Board(n1, n2, n3, n4, piece, wrap int64, directed bool) (*gbgraph.Graph, error) {
	b := &builder{}
	var d, n, k int64
	@<판 크기 매개변수를 정규화한다@>
	@<|n|개 정점의 그래프를 마련하고 이름을 붙인다@>
	@<모든 합법적 이동에 대해 호나 간선을 넣는다@>
	return b.g, nil
}

@ 차원 수 |d|와 각 좌표 크기 |nn[1..d]|를 정한다. \CEE/ 원본은 |goto done|으로
주기적 되풀이 계산을 건너뛰지만, 우리는 |periodic| 깃발로 대신한다.

@<판 크기 매개변수를 정규화한다@>=
if piece == 0 {
	piece = 1
}
if n1 <= 0 {
	n1, n2, n3 = 8, 8, 0
}
b.nn[1] = n1
periodic := true
switch {
case n2 <= 0:
	k, d, n3, n4 = 2, -n2, 0, 0
case n3 <= 0:
	b.nn[2] = n2
	k, d, n4 = 3, -n3, 0
case n4 <= 0:
	b.nn[2], b.nn[3] = n2, n3
	k, d = 4, -n4
default:
	b.nn[2], b.nn[3], b.nn[4] = n2, n3, n4
	d, periodic = 4, false
}

@ 마지막 인자가 음수 $-d$였으면(|periodic|), 앞서 준 크기들을 주기적으로
되풀이해 |nn[1..d]|를 채운다.

@<판 크기 매개변수를 정규화한다@>=
if periodic {
	if d == 0 {
		d = k - 1
	} else {
		if d > maxD {
			return nil, gbgraph.BadSpecs // 차원이 너무 많다
		}
		for j := int64(1); k <= d; j, k = j+1, k+1 {
			b.nn[k] = b.nn[j]
		}
	}
}

@ 얼간이 방지를 위해, 부동소수점 산술로 10억 칸을 넘는 판을 걸러낸다. 그런
뒤 정점마다 좌표를 혼합 진법 덧셈으로 매기며 이름을 붙인다. 좌표 $(3,1)$의
이름은 문자열 |"3.1"|이고, 처음 세 좌표는 정수로 |X.I|, |Y.I|, |Z.I|에도
저장해 빠르게 꺼내 쓸 수 있게 한다.

@<|n|개 정점의 그래프를 마련하고 이름을 붙인다@>=
nnn := 1.0
n = 1
for j := int64(1); j <= d; j++ {
	nnn *= float64(b.nn[j])
	if nnn > maxNNN {
		return nil, gbgraph.VeryBadSpecs // 너무 크다
	}
	n *= b.nn[j] // 이 곱셈은 정수 넘침을 일으킬 수 없다
}
b.g = gbgraph.NewGraph(n)
b.g.ID = fmt.Sprintf("board(%d,%d,%d,%d,%d,%d,%d)",
	n1, n2, n3, n4, piece, wrap, boolInt(directed))
b.g.UtilTypes = "ZZZIIIZZZZZZZZ"

@ 좌표를 혼합 진법 덧셈으로 매기며 정점마다 이름을 붙인다. 좌표 $(3,1)$의
이름은 |"3.1"|이고, 처음 세 좌표는 |X.I|, |Y.I|, |Z.I|에도 둔다.

@<|n|개 정점의 그래프를 마련하고 이름을 붙인다@>=
for j := int64(1); j <= d; j++ {
	b.xx[j] = 0
}
for vi := int64(0); ; vi++ {
	v := &b.g.Vertices[vi]
	v.Name = dotJoin(b.xx[1:d+1], '.')
	v.X.I, v.Y.I, v.Z.I = b.xx[1], b.xx[2], b.xx[3]
	kk := d
	for kk > 0 && b.xx[kk]+1 == b.nn[kk] {
		b.xx[kk] = 0
		kk--
	}
	if kk == 0 {
		break // 자리올림이 맨 왼쪽까지 갔다
	}
	b.xx[kk]++
}

@ |bool|을 표식 문자열용 0/1로 바꾸는 잔심부름이다.

@<빌더 자료구조@>=
func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

@ 이제 조금 까다로운 이동 생성기다. $p=\vert|piece|\vert$로 두고, 바깥
고리는 $\delta_1^2+\cdots+\delta_d^2=p$의 모든 음이 아닌 정수 해를 훑는다. 그
안쪽에서 $\delta$들에 부호를 붙이되, $\delta_1=\cdots=\delta_{k-1}=0$이면
$\delta_k$는 양수로 남긴다. 그런 벡터 $\delta$마다 모든 정점 |v|에서
$v+\delta$로 가는 이동을 낸다.

@<모든 합법적 이동에 대해 호나 간선을 넣는다@>=
w := wrap
for k := int64(1); k <= d; k, w = k+1, w>>1 {
	b.wr[k] = w & 1
	b.del[k], b.sig[k] = 0, 0
}
b.sig[0], b.del[0], b.sig[d+1] = 0, 0, 0
p := piece
if p < 0 {
	p = -p
}
Outer:
for {
	@<다음 음이 아닌 |del| 벡터로 나아가거나, 없으면 멈춘다@>
	for {
		@<현재 |del| 벡터에 대한 이동들을 낸다@>
		@<다음 부호 붙은 |del| 벡터로 나아가거나, |del|을 음이 아닌 값으로 되돌리고 멈춘다@>
	}
}

@ |sig| 배열 덕에 |p|를 제곱들의 순서 있는 합으로 나누는 모든 방법을 거슬러
훑기 쉽다.

@<다음 음이 아닌 |del| 벡터로 나아가거나, 없으면 멈춘다@>=
kk := d
for b.sig[kk]+(b.del[kk]+1)*(b.del[kk]+1) > p {
	b.del[kk] = 0
	kk--
}
if kk == 0 {
	break Outer
}
b.del[kk]++
b.sig[kk+1] = b.sig[kk] + b.del[kk]*b.del[kk]
for kk++; kk <= d; kk++ {
	b.sig[kk+1] = b.sig[kk]
}
if b.sig[d+1] < p {
	continue Outer
}

@ @<다음 부호 붙은 |del| 벡터로 나아가거나, |del|을 음이 아닌 값으로 되돌리고 멈춘다@>=
kk := d
for b.del[kk] <= 0 {
	b.del[kk] = -b.del[kk]
	kk--
}
if b.sig[kk] == 0 {
	break // |del[kk]| 말고는 다 음수거나 0이었다
}
b.del[kk] = -b.del[kk] // |del[kk]| 앞의 어떤 성분이 양수다

@ 혼합 진법 덧셈 기법을 다시 써서 각 정점에서 이동을 낸다.

@<현재 |del| 벡터에 대한 이동들을 낸다@>=
for k := int64(1); k <= d; k++ {
	b.xx[k] = 0
}
for vi := int64(0); ; vi++ {
	@<정점 |vi|에서 |del|에 해당하는 이동들을 낸다@>
	kk := d
	for kk > 0 && b.xx[kk]+1 == b.nn[kk] {
		b.xx[kk] = 0
		kk--
	}
	if kk == 0 {
		break
	}
	b.xx[kk]++
}

@ |piece|가 음수일 때의 합법적 이동은 이렇다: $(x_1,\ldots,x_d)$에서
출발해 $\delta$를 한 배, 두 배, \dots\ 더해 가며, 감기지 않는 좌표가 판을
벗어나거나 출발점으로 되돌아올 때까지 나아간다. 좌표가 감기고 |piece>0|이면
자기 고리가 생길 수 있지만, |piece<0|이면 결코 생기지 않는다.

@<정점 |vi|에서 |del|에 해당하는 이동들을 낸다@>=
for k := int64(1); k <= d; k++ {
	b.yy[k] = b.xx[k] + b.del[k]
}
for l := int64(1); ; l++ {
	@<판을 벗어났으면 이 정점을 끝낸다; 아니면 감김을 바로잡는다@>
	if piece < 0 {
		@<|yy=xx|이면 이 정점을 끝낸다@>
	}
	@<|xx|에서 |yy|로 가는 합법적 이동을 기록한다@>
	if piece > 0 {
		break
	}
	for k := int64(1); k <= d; k++ {
		b.yy[k] += b.del[k]
	}
}

@ @<판을 벗어났으면 이 정점을 끝낸다; 아니면 감김을 바로잡는다@>=
offBoard := false
for k := int64(1); k <= d; k++ {
	if b.yy[k] < 0 {
		if b.wr[k] == 0 {
			offBoard = true
			break
		}
		for b.yy[k] < 0 {
			b.yy[k] += b.nn[k]
		}
	} else if b.yy[k] >= b.nn[k] {
		if b.wr[k] == 0 {
			offBoard = true
			break
		}
		for b.yy[k] >= b.nn[k] {
			b.yy[k] -= b.nn[k]
		}
	}
}
if offBoard {
	break
}

@ @<|yy=xx|이면 이 정점을 끝낸다@>=
equal := true
for k := int64(1); k <= d; k++ {
	if b.yy[k] != b.xx[k] {
		equal = false
		break
	}
}
if equal {
	break
}

@ @<|xx|에서 |yy|로 가는 합법적 이동을 기록한다@>=
j := b.yy[1]
for k := int64(2); k <= d; k++ {
	j = b.nn[k]*j + b.yy[k]
}
if directed {
	b.g.NewArc(&b.g.Vertices[vi], &b.g.Vertices[j], l)
} else {
	b.g.NewEdge(&b.g.Vertices[vi], &b.g.Vertices[j], l)
}

@ 자주 쓰이는 특수한 경우들을 위한 별명이다. \CEE/의 매크로를 Go 함수로
옮겼다.

@<기본 서브루틴@>=
// |Complete|는 |n|개 정점의 완전 그래프다.
func Complete(n int64) (*gbgraph.Graph, error) { return Board(n, 0, 0, 0, -1, 0, false) }

// |Transitive|는 |n|개 정점의 추이 토너먼트다.
func Transitive(n int64) (*gbgraph.Graph, error) { return Board(n, 0, 0, 0, -1, 0, true) }

// |Empty|는 |n|개 정점에 간선이 없는 그래프다.
func Empty(n int64) (*gbgraph.Graph, error) { return Board(n, 0, 0, 0, 2, 0, false) }

// |Circuit|은 길이 |n|의 무향 회로다.
func Circuit(n int64) (*gbgraph.Graph, error) { return Board(n, 0, 0, 0, 1, 1, false) }

// |Cycle|은 길이 |n|의 유향 순환이다.
func Cycle(n int64) (*gbgraph.Graph, error) { return Board(n, 0, 0, 0, 1, 1, true) }

@*일반화된 삼각형 판. |Simplex(n,n0,n1,n2,n3,n4,directed)|은 중국 장기의
말판처럼 직사각형이 아닌 격자에 바탕한 그래프를 짓는다. 정점은 합이 |n|인 음이
아닌 정수 나열 $(x_0,x_1,\ldots,x_d)$이고, 두 나열이 꼭 두 성분에서 $\pm1$만큼
다를 때---곧 유클리드 거리가 $\sqrt2$일 때---이웃이다. $d=2$이면 정점들은
삼각형 배열을 이루어, $n=3$일 때 $(n+1)(n+2)/2=10$개가 된다.

첫 인자 |n|은 좌표들의 합이고, 이어지는 |n0|부터 |n4|는 각 좌표의 상한이자
차원 |d|를 정한다. 규칙은 |Board|의 차원 훑기와 비슷하되 여기서는 |n0|부터
센다. |n0=1|, |n1=-d|는 사실상 $(d+1)$원소 집합의 모든 |n|원소 부분집합을
낳는다---이 특별한 경우가 |Subsets|의 바탕이 된다.

|directed|가 참이면 호는 사전순으로 더 큰 이웃으로만 가고, 그래프는 비순환이
된다.

@ |Simplex|는 매개변수를 정규화하고, 가능한 $(x_0,\ldots,x_d)$의 수를 세어
그래프를 마련한 뒤, 점마다 이름과 호를 짓는다. 좌표에서 정점 위치를 곧바로
셈할 방법이 없으므로 이름을 해시표에 넣어(|"VVZIII"|) 이웃을 찾는다.

@<기본 서브루틴@>=
func Simplex(n, n0, n1, n2, n3, n4 int64, directed bool) (*gbgraph.Graph, error) {
	b := &builder{}
	@<simplex 매개변수를 정규화하고 그래프를 마련한다@>
	@<점들에 이름을 붙이고 호나 간선을 만든다@>
	return b.g, nil
}

@ 매개변수를 정규화하고, 가능한 점의 수를 세어 그래프를 마련한다. 표식에는
정규화된 |np|를 쓰고, |UtilTypes|의 |"VV"|가 해시표의 쓰임을 알린다.

@<simplex 매개변수를 정규화하고 그래프를 마련한다@>=
d, np, err := b.normalizeSimplex(n, n0, n1, n2, n3, n4)
if err != nil {
	return nil, err
}
nverts, err := b.countSimplex(n, d)
if err != nil {
	return nil, err
}
b.g = gbgraph.NewGraph(nverts)
b.g.ID = fmt.Sprintf("simplex(%d,%d,%d,%d,%d,%d,%d)",
	n, np[0], np[1], np[2], np[3], np[4], boolInt(directed))
b.g.UtilTypes = "VVZIIIZZZZZZZZ" // 해시표를 쓴다

@ 정점들을 사전순으로 낳으므로, 현재 $(x_0,\ldots,x_d)$보다 앞선 이웃들을
그 이름으로 찾을 수 있다. |Subsets|와 공유하는 정점 생성 골격이되, |Simplex|는
해시로 이웃을 잇고 |Subsets|는 무차별 대입으로 잇는다.

@<점들에 이름을 붙이고 호나 간선을 만든다@>=
b.yy[d+1] = 0
b.sig[0] = n
for k := d; k >= 0; k-- {
	b.yy[k] = b.yy[k+1] + b.nn[k]
}
vi := int64(0)

@ 부분해를 완성하고, 이름 붙여 해시에 넣고, 앞선 이웃을 이어, 다음 부분해로
나아가기를 되풀이한다.

@<점들에 이름을 붙이고 호나 간선을 만든다@>=
if b.yy[0] >= n {
	k := int64(0)
	if b.yy[1] >= n {
		b.xx[0] = 0
	} else {
		b.xx[0] = n - b.yy[1]
	}
	for {
		@<부분해를 완성해 정점 |v|를 낳고 이웃을 잇는다@>
		nk, ok := b.advancePartial(d)
		if !ok {
			break
		}
		k = nk
	}
}
if vi != b.g.N {
	return nil, gbgraph.Impossible // 있을 수 없는 일
}

@ 부분해를 완성하고, 이름 붙여 해시에 넣고, 앞선 이웃을 이은 뒤 |vi|를 하나
올린다.

@<부분해를 완성해 정점 |v|를 낳고 이웃을 잇는다@>=
if err := b.completePartial(k, d); err != nil {
	return nil, err
}
v := &b.g.Vertices[vi]
b.assignSimplexName(v, d)
b.g.HashIn(v)
@<이전 점들에서 |v|로 가는 호를 만든다@>
vi++

@ 이 여러 도우미는 |Simplex|, |Subsets|, |Perms|가 나눠 쓰므로 절이 아니라
|builder|의 메서드로 둔다. |normalizeSimplex|는 차원 |d|와 좌표 크기
|nn[0..d]|를 정한다. \CEE/의 |goto done|은 |periodic| 깃발로 갈음한다.

@<공유 생성기 도우미@>=
func (b *builder) normalizeSimplex(n, n0, n1, n2, n3, n4 int64) (int64, [5]int64, error) {
	if n0 == 0 {
		n0 = -2
	}
	np := [5]int64{n0, n1, n2, n3, n4} // 표식에 쓸 정규화된 매개변수
	var k, d int64
	periodic := true
	if n0 < 0 {
		k, d = 2, -n0
		b.nn[0] = n
		np[1], np[2], np[3], np[4] = 0, 0, 0, 0
	} else {
		clamp := func(x int64) int64 {
			if x > n {
				return n
			}
			return x
		}
		np[0] = clamp(n0)
		b.nn[0] = np[0]
		@<정규화된 매개변수를 처리한다@>
	}
	if periodic {
		@<앞 크기들을 주기적으로 되풀이해 |nn|을 채운다@>
	}
	return d, np, nil
}

@ @<정규화된 매개변수를 처리한다@>=
done := false
for i := 0; i < 4; i++ {
	if np[i+1] <= 0 {
		k, d = int64(i)+2, -np[i+1]
		for j := i + 2; j <= 4; j++ {
			np[j] = 0
		}
		done = true
		break
	}
	np[i+1] = clamp(np[i+1])
	b.nn[i+1] = np[i+1]
}
if !done {
	d, periodic = 4, false
}

@ 마지막 인자가 음수 $-d$였으면, 앞서 준 크기들을 주기적으로 되풀이해
|nn[0..d]|를 채운다.

@<앞 크기들을 주기적으로 되풀이해 |nn|을 채운다@>=
if d == 0 {
	d = k - 2
} else {
	if d > maxD {
		return 0, np, gbgraph.BadSpecs // 차원이 너무 많다
	}
	b.nn[k-1] = b.nn[0]
	for j := int64(1); k <= d; j, k = j+1, k+1 {
		b.nn[k] = b.nn[j]
	}
}

@ 정점 수는 멱급수
$$(1+z+\cdots+z^{n_0})(1+z+\cdots+z^{n_1})\cdots(1+z+\cdots+z^{n_d})$$
에서 $z^n$의 계수다. $1+z+\cdots+z^{n_j}$을 곱하는 산뜻한 방법이 있다:
먼저 $1-z^{n_j+1}$을 곱한 뒤 계수들을 누적한다. 곱셈을 덧셈으로 하므로 정수
넘침 없이 지나치게 큰 명세를 알아챌 수 있다.

@<공유 생성기 도우미@>=
func (b *builder) countSimplex(n, d int64) (int64, error) {
	coef := make([]int64, n+1)
	for k := int64(0); k <= b.nn[0]; k++ {
		coef[k] = 1
	}
	for j := int64(1); j <= d; j++ {
		for k, i := n, n-b.nn[j]-1; i >= 0; k, i = k-1, i-1 {
			coef[k] -= coef[i]
		}
		s := int64(1)
		for k := int64(1); k <= n; k++ {
			s += coef[k]
			if s > maxNNN {
				return 0, gbgraph.VeryBadSpecs // 너무 크다
			}
			coef[k] = s
		}
	}
	return coef[n], nil
}

@ 부분해를 완성하고, 다음 부분해로 나아가고, 좌표에 이름을 붙이는 세 도우미다.
$y_j=n_j+\cdots+n_d$와 $\sigma_j=n-(x_0+\cdots+x_{j-1})$를 유지하며, 조건
$0\le x_j\le n_j$와 $\sigma_j-y_{j+1}\le x_j\le\sigma_j$가 필요충분이다.

@<공유 생성기 도우미@>=
func (b *builder) completePartial(k, d int64) error {
	s := b.sig[k] - b.xx[k]
	for k++; k <= d; k++ {
		b.sig[k] = s
		if s <= b.yy[k+1] {
			b.xx[k] = 0
		} else {
			b.xx[k] = s - b.yy[k+1]
		}
		s -= b.xx[k]
	}
	if s != 0 {
		return gbgraph.Impossible + 1 // 있을 수 없는 일
	}
	return nil
}

@ |advancePartial|은 조건을 어기지 않고 $x_k$를 키울 수 있는 가장 큰 |k|를
찾아 키우고 그 |k|를 돌려준다. 더 없으면 |ok|가 거짓이다.

@<공유 생성기 도우미@>=
func (b *builder) advancePartial(d int64) (int64, bool) {
	for k := d - 1; ; k-- {
		if b.xx[k] < b.sig[k] && b.xx[k] < b.nn[k] {
			b.xx[k]++
			return k, true
		}
		if k == 0 {
			return 0, false
		}
	}
}

@ 좌표 나열 $(2,0,1)$은 |Board|에서처럼 |"2.0.1"|로 적고, 처음 세 좌표를
|X.I|, |Y.I|, |Z.I|에도 둔다.

@<공유 생성기 도우미@>=
func (b *builder) assignSimplexName(v *gbgraph.Vertex, d int64) {
	v.Name = dotJoin(b.xx[0:d+1], '.')
	v.X.I, v.Y.I, v.Z.I = b.xx[0], b.xx[1], b.xx[2]
}

@ 앞선 이웃은 어떤 한 좌표를 1 줄이고 다른 좌표를 1 늘린 점이다. 그 이름을
해시로 찾아 |v|에 잇는다.

@<이전 점들에서 |v|로 가는 호를 만든다@>=
for j := int64(0); j < d; j++ {
	if b.xx[j] != 0 {
		b.xx[j]--
		for k := j + 1; k <= d; k++ {
			if b.xx[k] < b.nn[k] {
				b.xx[k]++
				u := b.g.HashLookup(dotJoin(b.xx[0:d+1], '.'))
				if u == nil {
					return nil, gbgraph.Impossible + 2
				}
				if directed {
					b.g.NewArc(u, v, 1)
				} else {
					b.g.NewEdge(u, v, 1)
				}
				b.xx[k]--
			}
		}
		b.xx[j]++
	}
}

@*부분집합 그래프. |Subsets(n,n0,n1,n2,n3,n4,sizeBits,directed)|은
|Simplex|와 같은 정점들을 갖되 이웃 관계가 사뭇 다르다. 해 $(x_0,\ldots,x_d)$를
판 위 자리가 아니라 다중집합 $\{n_0\cdot0,n_1\cdot1,\ldots,n_d\cdot d\}$의
|n|원소 부분다중집합($j$가 $x_j$번)으로 본다. 두 정점은 그 교집합의 크기가
|sizeBits|의 어떤 비트와 맞을 때 이웃이다.

예컨대 |sizeBits=3|$=2^0+2^1$이면 교집합 원소가 정확히 0개나 1개일 때 이웃이다.
|DisjointSubsets(n,k)|는 $n\choose k$개의 정점을 서로소인 $k$-부분집합일 때
잇는다. 그 유명한 |Petersen| 그래프---$\{0,1,2,3,4\}$의 2원소 부분집합
10개를 서로소일 때 이은 것, 정점마다 차수 3에 길이 5 미만의 회로가 없는---도
이 특별한 경우다.

@ |Subsets|는 |Simplex|와 똑같은 논리로 정점을 낳지만, 호는 무차별 대입으로
--- 모든 정점 쌍의 교집합 크기를 재어---만든다. 그래서 해시표가 필요 없어
|UtilTypes|가 |"ZZZIII"|이다.

@<기본 서브루틴@>=
func Subsets(n, n0, n1, n2, n3, n4 int64, sizeBits uint64, directed bool) (*gbgraph.Graph, error) {
	b := &builder{}
	d, np, err := b.normalizeSimplex(n, n0, n1, n2, n3, n4)
	if err != nil {
		return nil, err
	}
	nverts, err := b.countSimplex(n, d)
	if err != nil {
		return nil, err
	}
	b.g = gbgraph.NewGraph(nverts)
	b.g.ID = fmt.Sprintf("subsets(%d,%d,%d,%d,%d,%d,0x%x,%d)",
		n, np[0], np[1], np[2], np[3], np[4], sizeBits, boolInt(directed))
	b.g.UtilTypes = "ZZZIIIZZZZZZZZ" // 해시표를 쓰지 않는다
	@<부분집합에 이름을 붙이고 호나 간선을 만든다@>
	return b.g, nil
}

@ 정점 생성은 |Simplex|와 글자 그대로 같고, 이웃 잇기만 다르다.

@<부분집합에 이름을 붙이고 호나 간선을 만든다@>=
b.yy[d+1] = 0
b.sig[0] = n
for k := d; k >= 0; k-- {
	b.yy[k] = b.yy[k+1] + b.nn[k]
}
vi := int64(0)

@ |Simplex|와 같은 생성 골격이되, 이웃은 무차별 대입으로 잇는다.

@<부분집합에 이름을 붙이고 호나 간선을 만든다@>=
if b.yy[0] >= n {
	k := int64(0)
	if b.yy[1] >= n {
		b.xx[0] = 0
	} else {
		b.xx[0] = n - b.yy[1]
	}
	for {
		if err := b.completePartial(k, d); err != nil {
			return nil, err
		}
		v := &b.g.Vertices[vi]
		b.assignSimplexName(v, d)
		@<이전 부분집합들에서 |v|로 가는 호를 만든다@>
		vi++
		nk, ok := b.advancePartial(d)
		if !ok {
			break
		}
		k = nk
	}
}
if vi != b.g.N {
	return nil, gbgraph.Impossible
}

@ 각 이전 정점 |u|(자기 자신 포함)의 이름을 좌표로 되풀어, 현재 정점과의
교집합 크기 |ss|를 잰다. |ss|가 |sizeBits|의 한 비트와 맞으면 잇는다.

@<이전 부분집합들에서 |v|로 가는 호를 만든다@>=
for ui := int64(0); ui <= vi; ui++ {
	u := &b.g.Vertices[ui]
	parts := strings.Split(u.Name, ".")
	ss := int64(0)
	for j := int64(0); j <= d; j++ {
		s, _ := strconv.ParseInt(parts[j], 10, 64)
		if b.xx[j] < s {
			ss += b.xx[j]
		} else {
			ss += s
		}
	}
	if ss < 64 && sizeBits&(uint64(1)<<uint(ss)) != 0 {
		if directed {
			b.g.NewArc(u, v, 1)
		} else {
			b.g.NewEdge(u, v, 1)
		}
	}
}

@ |DisjointSubsets|와 |Petersen| 별명이다.

@<기본 서브루틴@>=
// |DisjointSubsets|는 $n$원소 집합의 서로소인 $k$-부분집합들을 잇는다.
func DisjointSubsets(n, k int64) (*gbgraph.Graph, error) {
	return Subsets(k, 1, 1-n, 0, 0, 0, 1, false)
}

// |Petersen|은 페테르센 그래프다.
func Petersen() (*gbgraph.Graph, error) { return DisjointSubsets(5, 2) }

@*순열 그래프. |Perms(n0,n1,n2,n3,n4,maxInv,directed)|은 다중집합의 순열
가운데 뒤바뀜(inversion)이 |maxInv|개 이하인 것들을 정점으로 삼는다. 두 순열은
이웃한 두 원소를 맞바꿔 서로에게서 얻어질 때 이웃이다. 뒤바뀜의 수란 $x>y$이면서
$x$가 $y$보다 앞서는 쌍 $xy$의 수인데, 이는 그 순열에서 사전순 첫 순열까지의
그래프 거리와 같다.

|n0|부터 |n4|가 다중집합의 구성을 정한다: 대략 0이 |n0|개, 1이 |n1|개, \dots.
더 많은 서로 다른 원소가 필요하면 |-d| 꼴을 쓴다. |maxInv=0|이면 뒤바뀜 수에
상관없이 모든 순열을 쓴다. $n$원소 집합의 $n!$개 순열을 다 원하면
|AllPerms(n,directed)|를 부른다.

@ |Perms|는 구조가 |Simplex|와 매우 비슷하다. 먼저 다중집합을 정규화하고,
$z$-다항계수의 계수들을 합해 정점 수를 세고, 뒤바뀜표를 유지하며 순열을 사전순으로
낳는다.

@<기본 서브루틴@>=
func Perms(n0, n1, n2, n3, n4, maxInv int64, directed bool) (*gbgraph.Graph, error) {
	b := &builder{}
	if n0 == 0 {
		n0, n1 = 1, 0 // 빈 집합을 $\{0\}$으로
	} else if n0 < 0 {
		n1, n0 = n0, 1
	}
	d, np, err := b.normalizeSimplex(bufSize, n0, n1, n2, n3, n4)
	if err != nil {
		return nil, err
	}
	@<|n|과 뒤바뀜 최댓값을 정한다@>
	@<순열 하나당 정점 하나인 그래프를 마련한다@>
	@<순열에 이름을 붙이고 호나 간선을 만든다@>
	return b.g, nil
}

@ |Simplex|의 코드를 빌려 쓰려고 |normalizeSimplex|에 |bufSize|를 |n| 삼아
넘겼으니, 이제 진짜 |n|(다중집합의 크기)과 가능한 뒤바뀜의 최댓값 |ss|를 다시
셈한다. |ss=\sum_{j<k}n_jn_k$다.

@<|n|과 뒤바뀜 최댓값을 정한다@>=
var n, ss, s int64
for k := int64(0); k <= d; k++ {
	if b.nn[k] >= bufSize {
		return nil, gbgraph.BadSpecs // 다중집합에 원소가 너무 많다
	}
	ss += s * b.nn[k]
	s += b.nn[k]
}
if s >= bufSize {
	return nil, gbgraph.BadSpecs + 1
}
n = s
if maxInv == 0 || maxInv > ss {
	maxInv = ss
}

@ 정점 수는, $z^j$의 계수가 뒤바뀜 $j$개인 순열의 수인 멱급수---곧
$z$-다항계수---의 처음 |maxInv+1|개 계수의 합이다. 각 $(1-z^{s+k})/(1-z^k)$을
곱해 나가면 계수가 음이 아닌 채로 유지된다.

@<순열 하나당 정점 하나인 그래프를 마련한다@>=
coef := make([]int64, maxInv+1)
coef[0] = 1
s = b.nn[0]
for j := int64(1); j <= d; j++ {
	for k := int64(1); k <= b.nn[j]; k++ {
		for i, ii := maxInv, maxInv-k-s; ii >= 0; i, ii = i-1, ii-1 {
			coef[i] -= coef[ii]
		}
		for i, ii := k, int64(0); i <= maxInv; i, ii = i+1, ii+1 {
			coef[i] += coef[ii]
			if coef[i] > maxNNN {
				return nil, gbgraph.VeryBadSpecs + 1 // 너무 크다
			}
		}
	}
	s += b.nn[j]
}
nverts := int64(1)
for k := int64(1); k <= maxInv; k++ {
	nverts += coef[k]
	if nverts > maxNNN {
		return nil, gbgraph.VeryBadSpecs
	}
}
b.g = gbgraph.NewGraph(nverts)
b.g.ID = fmt.Sprintf("perms(%d,%d,%d,%d,%d,%d,%d)",
	np[0], np[1], np[2], np[3], np[4], maxInv, boolInt(directed))
b.g.UtilTypes = "VVZZZZZZZZZZZZ" // 해시표를 쓴다

@ 순열을 낳는 동안 뒤바뀜표 $(y_1,\ldots,y_n)$을 유지한다. $y_k$는 다중집합의
$k$번째 원소를 첫 원소로 하는 뒤바뀜의 수다. $z$는 뒤바뀜 없는 첫 순열을 담는다.

@<순열에 이름을 붙이고 호나 간선을 만든다@>=
xtab := make([]int64, n+1)
ytab := make([]int64, n+1)
ztab := make([]int64, n+1)
@<|xtab|, |ytab|, |ztab|를 초기화한다@>
buf := make([]byte, n)
m := int64(0) // 현재 뒤바뀜 수
vi := int64(0)
for {
	@<현재 순열의 이름을 짓고 해시에 넣는다@>
	@<이전 순열들에서 |v|로 가는 호를 만든다@>
	vi++
	@<다음 순열로 나아가거나, 없으면 멈춘다@>
}
if vi != b.g.N {
	return nil, gbgraph.Impossible
}

@ @<|xtab|, |ytab|, |ztab|를 초기화한다@>=
j := int64(0)
s = b.nn[0]
for k := int64(1); ; k++ {
	xtab[k], ztab[k] = j, j
	if k == s {
		j++
		if j > d {
			break
		}
		s += b.nn[j]
	}
}

@ 순열은 인용부호가 필요한 문자를 뺀 |imap|(|shortImap|)으로 부호화한다.
서로 다른 원소가 62개 이하이면 이름에 숫자와 글자만 나온다.

@<상수 정의@>=
const shortImap = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
	"abcdefghijklmnopqrstuvwxyz" +
	"_^~&@@,;.:?!%#$+-*/|<=>()[]{}`'"

@ @<현재 순열의 이름을 짓고 해시에 넣는다@>=
for i := int64(0); i < n; i++ {
	buf[i] = shortImap[xtab[i+1]]
}
v := &b.g.Vertices[vi]
v.Name = string(buf)
b.g.HashIn(v)

@ 순열을 뒤바뀜 사전순으로 낳으므로, 현재보다 앞선 이웃들을 이름으로 찾을 수
있다. 이웃한 두 원소가 큰-작은 순이면 맞바꾼 이름을 만들어 잇는다.

@<이전 순열들에서 |v|로 가는 호를 만든다@>=
for j := int64(1); j < n; j++ {
	if xtab[j] > xtab[j+1] {
		buf[j-1] = shortImap[xtab[j+1]]
		buf[j] = shortImap[xtab[j]]
		u := b.g.HashLookup(string(buf))
		if u == nil {
			return nil, gbgraph.Impossible + 2
		}
		if directed {
			b.g.NewArc(u, v, 1)
		} else {
			b.g.NewEdge(u, v, 1)
		}
		buf[j-1] = shortImap[xtab[j]]
		buf[j] = shortImap[xtab[j+1]]
	}
}

@ 순열 논리의 핵심이다. $y_k$를 정당하게 1 키울 수 있는 가장 큰 |k|를 찾는다.
키울 수 없는 |k|를 만나면 $y_k=0$으로 되돌리고 $x$들을 손본다. 어느 $y_k$도 못
키우면 끝이다.

@<다음 순열로 나아가거나, 없으면 멈춘다@>=
moved := false
var mk int64
for k := n; k > 0; k-- {
	if m < maxInv && ytab[k] < k-1 {
		if ytab[k] < ytab[k-1] || ztab[k] > ztab[k-1] {
			mk, moved = k, true
			break
		}
	}
	if ytab[k] != 0 {
		for j := k - ytab[k]; j < k; j++ {
			xtab[j] = xtab[j+1]
		}
		m -= ytab[k]
		ytab[k] = 0
		xtab[k] = ztab[k]
	}
}
if !moved {
	break
}
j := mk - ytab[mk] // $k$번째 원소 $z_k$의 현재 위치
xtab[j] = xtab[j-1]
xtab[j-1] = ztab[mk]
ytab[mk]++
m++

@ @<기본 서브루틴@>=
// |AllPerms|는 $n$원소 집합의 $n!$개 순열을 다 낳는다.
func AllPerms(n int64, directed bool) (*gbgraph.Graph, error) {
	return Perms(1-n, 0, 0, 0, 0, 0, directed)
}

@*분할 그래프. |Parts(n,maxParts,maxSize,directed)|는 정수 |n|을 최대
|maxParts|개의 부분으로, 각 부분이 |maxSize| 이하가 되게 나누는 방법들을
정점으로 삼는다. 두 분할은 한쪽의 두 부분을 합쳐 다른 쪽을 얻을 수 있을 때
이웃이다. |maxParts|나 |maxSize|가 0이면 |n|으로 바뀌어 제한이 없어진다.
|n|의 분할 $p(n)$개를 다 원하면 |AllParts(n,directed)|를 부른다.

@ |Parts|는 |Perms|와 구조가 비슷하되 자기만의 부분해 완성·전진 논리를 쓴다.
정점 수는 $z$-이항계수 ${m+p\choose m}_z$에서 $z^n$의 계수다($m=|maxParts|$,
$p=|maxSize|$).

@<기본 서브루틴@>=
func Parts(n, maxParts, maxSize int64, directed bool) (*gbgraph.Graph, error) {
	b := &builder{}
	if maxParts == 0 || maxParts > n {
		maxParts = n
	}
	if maxSize == 0 || maxSize > n {
		maxSize = n
	}
	if maxParts > maxD {
		return nil, gbgraph.BadSpecs // 부분이 너무 많다
	}
	@<분할 하나당 정점 하나인 그래프를 마련한다@>
	@<분할에 이름을 붙이고 호나 간선을 만든다@>
	return b.g, nil
}

@ @<분할 하나당 정점 하나인 그래프를 마련한다@>=
coef := make([]int64, n+1)
coef[0] = 1
for k := int64(1); k <= maxParts; k++ {
	for j, i := n, n-k-maxSize; i >= 0; i, j = i-1, j-1 {
		coef[j] -= coef[i]
	}
	for j, i := k, int64(0); j <= n; i, j = i+1, j+1 {
		coef[j] += coef[i]
		if coef[j] > maxNNN {
			return nil, gbgraph.VeryBadSpecs // 너무 크다
		}
	}
}
b.g = gbgraph.NewGraph(coef[n])
b.g.ID = fmt.Sprintf("parts(%d,%d,%d,%d)", n, maxParts, maxSize, boolInt(directed))
b.g.UtilTypes = "VVZZZZZZZZZZZZ" // 해시표를 쓴다

@ 분할을 낳는 동안 $\sigma_j=n-(x_1+\cdots+x_{j-1})$을 유지한다. $x_0=|maxSize|$,
$y_j=|maxParts|+1-j$로 두면, 값 $(x_1,\ldots,x_{j-1})$가 주어졌을 때
$\sigma_j/y_j\le x_j\le\sigma_j$, $x_j\le x_{j-1}$이 합법적 $x_j$를 규정한다.

@<분할에 이름을 붙이고 호나 간선을 만든다@>=
b.xx[0] = maxSize
b.sig[1] = n
for k, s := maxParts, int64(1); k > 0; k, s = k-1, s+1 {
	b.yy[k] = s
}
var d int64
vi := int64(0)
if maxSize*maxParts >= n {
	k := int64(1)
	b.xx[1] = (n-1)/maxParts + 1 // $\lceil n/|maxParts|\rceil$
	for {
		@<부분해 $(x_1,\ldots,x_k)$를 완성한다@>
		@<이름 $x_1+\cdots+x_d$를 |v|에 붙인다@>
		@<|v|에서 이전 분할들로 가는 호를 만든다@>
		vi++
		@<다음 부분해로 나아가거나, 없으면 멈춘다@>
	}
}
if vi != b.g.N {
	return nil, gbgraph.Impossible
}

@ @<부분해 $(x_1,\ldots,x_k)$를 완성한다@>=
s := b.sig[k] - b.xx[k]
k++
for s != 0 {
	b.sig[k] = s
	b.xx[k] = (s-1)/b.yy[k] + 1
	s -= b.xx[k]
	k++
}
d = k - 1 // 가장 작은 부분이 $x_d$

@ @<이름 $x_1+\cdots+x_d$를 |v|에 붙인다@>=
v := &b.g.Vertices[vi]
v.Name = dotJoin(b.xx[1:d+1], '+')
b.g.HashIn(v)

@ 조건을 어기지 않고 $x_k$를 키울 수 있는 가장 큰 |k|를 찾는다.

@<다음 부분해로 나아가거나, 없으면 멈춘다@>=
if d == 1 {
	break
}
found := false
for k = d - 1; ; k-- {
	if b.xx[k] < b.sig[k] && b.xx[k] < b.xx[k-1] {
		found = true
		break
	}
	if k == 1 {
		break
	}
}
if !found {
	break
}
b.xx[k]++

@ 분할을 부분들의 사전순으로 낳으므로, $x_j\ne x_{j+1}$인 곳에서 $x_j$를 두
부분으로 쪼개 앞선 이웃을 만든다. $(x_1,\ldots,x_{j-1})$은 이미 |nn|에
베껴 두었으니, 작은 부분 $(x_{j+1},\ldots,x_d)$를 옮기며 $a\ge b$를 제자리에
끼운다.

@<|v|에서 이전 분할들로 가는 호를 만든다@>=
if d < maxParts {
	b.xx[d+1] = 0
	for j := int64(1); j <= d; j++ {
		if b.xx[j] != b.xx[j+1] {
			for lo, hi := b.xx[j]/2, b.xx[j]-b.xx[j]/2; lo > 0; lo, hi = lo-1, hi+1 {
				@<$x_j$를 $hi+lo$로 쪼갠 이웃 분할을 |v|에 잇는다@>
			}
		}
		b.nn[j] = b.xx[j]
	}
}

@ @<$x_j$를 $hi+lo$로 쪼갠 이웃 분할을 |v|에 잇는다@>=
k := j + 1
for b.xx[k] > hi {
	b.nn[k-1] = b.xx[k]
	k++
}
b.nn[k-1] = hi
for b.xx[k] > lo {
	b.nn[k] = b.xx[k]
	k++
}
b.nn[k] = lo
for ; k <= d; k++ {
	b.nn[k+1] = b.xx[k]
}
u := b.g.HashLookup(dotJoin(b.nn[1:d+2], '+'))
if u == nil {
	return nil, gbgraph.Impossible + 2
}
if directed {
	b.g.NewArc(v, u, 1)
} else {
	b.g.NewEdge(v, u, 1)
}

@ @<기본 서브루틴@>=
// |AllParts|는 |n|의 분할 $p(n)$개를 다 낳는다.
func AllParts(n int64, directed bool) (*gbgraph.Graph, error) {
	return Parts(n, 0, 0, directed)
}

@*이진 트리 그래프. |Binary(n,maxHeight,directed)|는 내부 노드가 |n|개이고
모든 잎이 뿌리에서 |maxHeight| 이내에 있는 이진 트리들을 정점으로 삼는다. 두
트리는 결합법칙을 한 번 적용해---부분트리 $(\alpha\cdot\beta)\cdot\gamma$를
$\alpha\cdot(\beta\cdot\gamma)$로 바꾸는 회전으로---서로에게서 얻어질 때
이웃이다. |maxHeight=0|이면 |n|으로 바뀌어 높이 제한이 없어지고, 그때 정점은
정확히 ${2n+1\choose n}/(2n+1)$개다. $n$개 내부 노드의 트리를 다 원하면
|AllTrees(n,directed)|를 부른다.

@ |Binary|는 |Parts|와 비슷하나 세부가 더 흥미롭다. 큰 |n|에서는 작업 배열이
|maxD|를 넘을 수 있으므로, |builder|의 고정 배열 대신 지역 슬라이스를 쓴다.
그 덕에 \CEE/ 원본의 정적 배열이 안고 있던 잠재적 넘침 걱정도 사라진다.

@<기본 서브루틴@>=
func Binary(n, maxHeight int64, directed bool) (*gbgraph.Graph, error) {
	if 2*n+2 > bufSize {
		return nil, gbgraph.BadSpecs // |n|이 우리에겐 너무 크다
	}
	if maxHeight == 0 || maxHeight > n {
		maxHeight = n
	}
	if maxHeight > 30 {
		return nil, gbgraph.VeryBadSpecs // 10억 정점이 넘는다
	}
	var g *gbgraph.Graph
	@<이진 트리 하나당 정점 하나인 그래프를 마련한다@>
	@<트리에 이름을 붙이고 호나 간선을 만든다@>
	return g, nil
}

@ 정점 수는 멱급수 $G_h$에서 $z^n$의 계수인데, $G_0=1$, $G_{h+1}=1+zG_h^2$이다.
$G_6$부터는 계수가 아주 커지므로, $h\ge6$이고 $n\ge20$이면 넘침을 피하려
$R_h=G_h/z^{2^h-1}$($R_0=1$, $R_{h+1}=R_h^2+z^{1-2^{h+1}}$)의 계수를 대신 본다.

@<이진 트리 하나당 정점 하나인 그래프를 마련한다@>=
cnt := make([]int64, n+2)
var nverts int64
if n >= 20 && maxHeight >= 6 {
	@<$R$ 급수로 |nverts|를 셈한다@>
} else {
	cnt[0], cnt[1] = 1, 1
	for j := int64(2); j <= maxHeight; j++ {
		for k := n - 1; k > 0; k-- {
			var s int64
			for i := k; i >= 0; i-- {
				s += cnt[i] * cnt[k-i]
			}
			cnt[k+1] = s
		}
	}
	nverts = cnt[n]
}
g = gbgraph.NewGraph(nverts)
g.ID = fmt.Sprintf("binary(%d,%d,%d)", n, maxHeight, boolInt(directed))
g.UtilTypes = "VVZZZZZZZZZZZZ" // 해시표를 쓴다

@ $h\ge6$이고 $n\ge20$일 때, 쓸 만한 크기의 그래프는 $n\ge2^h-7$에서만 나온다.
$z^{-(2^h-1-n)}$의 계수를 본다.

@<$R$ 급수로 |nverts|를 셈한다@>=
dd := (int64(1) << maxHeight) - 1 - n
if dd > 8 {
	return nil, gbgraph.BadSpecs + 1 // 정점이 너무 많다
}
if dd < 0 {
	nverts = 0
} else {
	cnt[0], cnt[1] = 1, 1
	for j := int64(2); j <= maxHeight; j++ {
		for k := dd; k > 0; k-- {
			var ss float64
			for i := k; i >= 0; i-- {
				ss += float64(cnt[i]) * float64(cnt[k-i])
			}
			if ss > maxNNN {
				return nil, gbgraph.VeryBadSpecs + 1 // 너무 크다
			}
			var s int64
			for i := k; i >= 0; i-- {
				s += cnt[i] * cnt[k-i]
			}
			cnt[k] = s
		}
		if i := (int64(1) << j) - 1; i <= dd {
			cnt[i]++ // $z^{1-2^j}$을 더한다
		}
	}
	nverts = cnt[dd]
}

@ 트리를 폴란드 전위 표기의 사전순으로 낳는다. `1'은 내부 노드, `0'은 잎이다.
보조 배열 $l_j$, $y_j$, $\sigma_j$를 유지하는데, $\sigma_j$는
$(x_j,\ldots,x_{2n})$의 잎 수보다 하나 적고, $l_j=2^{h-l}$이며($x_j$가 $l$준위
노드), $y_j$는 아직 오른쪽 자식을 못 받은 준위들의 이진 부호화다.

@<트리에 이름을 붙이고 호나 간선을 만든다@>=
d := n + n
xtab := make([]int64, d+1)
ytab := make([]int64, d+1)
ltab := make([]int64, d+1)
stab := make([]int64, d+1)
ltab[0] = int64(1) << maxHeight
stab[0] = n
buf := make([]byte, d+1)
vi := int64(0)
if ltab[0] > n {
	k := int64(0)
	if n != 0 {
		xtab[0] = 1
	}
	for {
		@<부분 트리 $x_0\ldots x_k$를 완성한다@>
		@<폴란드 전위 이름을 |v|에 붙인다@>
		@<|v|에서 이전 트리들로 가는 호를 만든다@>
		vi++
		@<다음 부분 트리로 나아가거나, 없으면 멈춘다@>
	}
}
if vi != g.N {
	return nil, gbgraph.Impossible
}

@ $\sigma_j>y_j$이면 $x_j$는 1로, $l_j=1$이거나 $y_j$의 1비트 수가 $\sigma_j$와
같으면 $x_j$는 0으로 강제된다. 아니면 0이나 1 모두 가능하고 사전순 최소를 고른다.

@<부분 트리 $x_0\ldots x_k$를 완성한다@>=
for j := k + 1; j <= d; j++ {
	if xtab[j-1] != 0 {
		ltab[j] = ltab[j-1] >> 1
		ytab[j] = ytab[j-1] + ltab[j]
		stab[j] = stab[j-1]
	} else {
		ytab[j] = ytab[j-1] & (ytab[j-1] - 1) // 최하위 1비트를 없앤다
		ltab[j] = ytab[j-1] - ytab[j]
		stab[j] = stab[j-1] - 1
	}
	if stab[j] <= ytab[j] {
		xtab[j] = 0
	} else {
		xtab[j] = 1
	}
}

@ 이름 필드에서 내부 노드는 `\..', 잎은 `\.x'로 부호화한다.

@<폴란드 전위 이름을 |v|에 붙인다@>=
for k := int64(0); k <= d; k++ {
	if xtab[k] != 0 {
		buf[k] = '.'
	} else {
		buf[k] = 'x'
	}
}
v := &g.Vertices[vi]
v.Name = string(buf)
g.HashIn(v)

@ 부분 문자열 $\..\..\alpha\beta$를 $\..\alpha\..\beta$로 바꿔 앞선 이웃을
만든다. 그 결과는 사전순으로 앞서므로, 높이 제한을 어기지 않는 한 이미 있는
정점이다.

@<|v|에서 이전 트리들로 가는 호를 만든다@>=
for j := int64(0); j < d; j++ {
	if xtab[j] == 1 && xtab[j+1] == 1 {
		i, s := j+1, int64(0)
		for s >= 0 {
			xtab[i] = xtab[i+1]
			s += (xtab[i+1] << 1) - 1
			i++
		}
		xtab[i] = 1
		for k := int64(0); k <= d; k++ {
			if xtab[k] != 0 {
				buf[k] = '.'
			} else {
				buf[k] = 'x'
			}
		}
		if u := g.HashLookup(string(buf)); u != nil {
			if directed {
				g.NewArc(v, u, 1)
			} else {
				g.NewEdge(v, u, 1)
			}
		}
		for i--; i > j; i-- {
			xtab[i+1] = xtab[i]
		}
		xtab[i+1] = 1
	}
}

@ 오른쪽에서 가장 가까운 1을 찾고, 그 왼쪽에서 키울 수 있는 자리를 찾는다.

@<다음 부분 트리로 나아가거나, 없으면 멈춘다@>=
done := false
for k = d - 1; ; k-- {
	if k <= 0 {
		done = true // |n<=1|일 때만 일어난다
		break
	}
	if xtab[k] == 1 {
		break // 오른쪽에서 가장 가까운 1
	}
}
if done {
	break
}
for k--; ; k-- {
	if xtab[k] == 0 && ltab[k] > 1 {
		break
	}
	if k == 0 {
		done = true
		break
	}
}
if done {
	break
}
xtab[k]++

@ @<기본 서브루틴@>=
// |AllTrees|는 |n|개 내부 노드의 이진 트리를 다 낳는다.
func AllTrees(n int64, directed bool) (*gbgraph.Graph, error) {
	return Binary(n, 0, directed)
}

@*여집합과 복사. 여기서부터는 이미 있는 그래프를 탈바꿈시키는 변환기들이다.
가장 간단한 것이 |Complement(g,cp,self,directed)|로, |g|와 같은 정점을 갖되 호를
여집합으로---전에 이웃이 아니던 정점끼리 이웃이 되게---만든다. |self|가
참이면 자기 고리를 허용한다. |cp|가 참이면 이중 여집합, 곧 중복 호(와 어쩌면
자기 고리)를 없앤 |g|의 복사본이 된다.

\CEE/ 원본은 원본 그래프의 정점과 복사본의 정점이 메모리에서 일정한 거리만큼
떨어져 있음을 이용하는 포인터 요령 |vert_offset|을 쓴다. 우리는 대신 정점을
색인으로 다룬다: |g|의 |i|번째 정점에 대응하는 것은 언제나 새 그래프의 |i|번째
정점이다. 임시로 어느 정점이 이웃인지 기억할 때는 새 정점의 |U.V| 필드(\CEE/의
|tmp|)를 빌려 쓴다.

@<기본 서브루틴@>=
func Complement(g *gbgraph.Graph, cp, self, directed bool) (*gbgraph.Graph, error) {
	if g == nil {
		return nil, gbgraph.MissingOperand // |g|가 어디 있나?
	}
	n := g.N
	ng := newLikeG(g)
	ng.MakeCompoundID("complement(", g,
		fmt.Sprintf(",%d,%d,%d)", boolInt(cp), boolInt(self), boolInt(directed)))
	@<여집합 호나 간선을 넣는다@>
	return ng, nil
}

@ 어느 |v|의 이웃을 |tmp|로 표시해 두고, 그 표시가 |cp|와 어긋나는(곧 여집합에
드는) 정점마다 호나 간선을 낸다. |v->arcs->tip|들이 엄격히 내림차순이 되는
성질이 여기서 나온다.

@<여집합 호나 간선을 넣는다@>=
for i := int64(0); i < n; i++ {
	v := &g.Vertices[i]
	u := &ng.Vertices[i]
	for a := range v.AllArcs() {
		ng.Vertices[g.Index(a.Tip)].U.V = u // |tmp|를 |u|로 찍는다
	}
	if directed {
		for j := int64(0); j < n; j++ {
			vv := &ng.Vertices[j]
			if (vv.U.V == u) == cp {
				if vv != u || self {
					ng.NewArc(u, vv, 1)
				}
			}
		}
	} else {
		j := i // |self|이면 |u|부터, 아니면 그다음부터
		if !self {
			j++
		}
		for ; j < n; j++ {
			vv := &ng.Vertices[j]
			if (vv.U.V == u) == cp {
				ng.NewEdge(u, vv, 1)
			}
		}
	}
}
for i := int64(0); i < n; i++ {
	ng.Vertices[i].U.V = nil
}

@*그래프 합집합과 교집합. |Gunion(g,gg,multi,directed)|은 |g|의 정점과 호에
|gg|의 호를 더한 그래프를, |Intersection(g,gg,multi,directed)|은 |g|의 정점에
|g|와 |gg| 둘 다에 있는 호만 담은 그래프를 만든다. |gg|는 |g|와 같은 정점을
--- 정점 배열에서 같은 자리의 정점을 같은 것으로 보아---갖는다고 가정한다.

|multi|가 참이면 중복 호가 살아남는다: |u|에서 |v|로 |g|에 $k_1$개, |gg|에
$k_2$개 있으면 합집합에 $k_1+k_2$개, 교집합에 $\min(k_1,k_2)$개다. 거짓이면
많아야 하나다.

@ |Gunion|은 |Complement|처럼 |tmp|(|U.V|) 요령으로 |u|에서 이미 기록한 호를
기억하고, 최소 길이를 유지하려 이를 |tlen|(|Z.A|)으로 넓힌다. 무향일 때 간선을
쌍으로 묶으려고, |vv<=u|일 때만 새 간선을 내고 같으면 |a|를 짝호로 건너뛴다.

@<기본 서브루틴@>=
func Gunion(g, gg *gbgraph.Graph, multi, directed bool) (*gbgraph.Graph, error) {
	if g == nil || gg == nil {
		return nil, gbgraph.MissingOperand
	}
	n := g.N
	ng := newLikeG(g)
	ng.MakeDoubleCompoundID("gunion(", g, ",", gg,
		fmt.Sprintf(",%d,%d)", boolInt(multi), boolInt(directed)))
	@<|g|와 |gg|의 호를 |ng|에 합친다@>
	for i := int64(0); i < n; i++ {
		ng.Vertices[i].U.V, ng.Vertices[i].Z.A = nil, nil
	}
	return ng, nil
}

@ 각 정점마다 |g|의 호와 |gg|의 호를 차례로 훑어 |vv|에서 잇는다. |gg|가
|g|보다 정점이 많으면 넘치는 것은 무시한다.

@<|g|와 |gg|의 호를 |ng|에 합친다@>=
for i := int64(0); i < n; i++ {
	v := &g.Vertices[i]
	vv := &ng.Vertices[i]
	for a := v.Arcs; a != nil; a = a.Next {
		u := &ng.Vertices[g.Index(a.Tip)]
		@<|vv|에서 |u|로 가는 합집합 호나 간선을 넣는다@>
	}
	if i < gg.N {
		for a := gg.Vertices[i].Arcs; a != nil; a = a.Next {
			if ti := gg.Index(a.Tip); ti < n {
				u := &ng.Vertices[ti]
				@<|vv|에서 |u|로 가는 합집합 호나 간선을 넣는다@>
			}
		}
	}
}

@ |tmp|가 |u->tmp==vv|이면 |u|로 가는 호를 이미 봤다는 뜻이고, 그때 |tlen|은
그 호 하나(무향이면 간선 쌍의 첫 호)를 가리킨다.

@<|vv|에서 |u|로 가는 합집합 호나 간선을 넣는다@>=
if directed {
	if multi || u.U.V != vv {
		ng.NewArc(vv, u, a.Len)
	} else if bb := u.Z.A; a.Len < bb.Len {
		bb.Len = a.Len
	}
	u.U.V, u.Z.A = vv, vv.Arcs
} else if ptrGeq(u, vv) {
	if multi || u.U.V != vv {
		ng.NewEdge(vv, u, a.Len)
	} else if bb := u.Z.A; a.Len < bb.Len {
		bb.Len, bb.Partner.Len = a.Len, a.Len
	}
	u.U.V, u.Z.A = vv, vv.Arcs
	if u == vv && a.Next == a.Partner {
		a = a.Partner // 자기 고리의 뒤 짝을 건너뛴다
	}
}

@ 정점 포인터의 주소 순서를 비교하는 잔심부름이다. \CEE/ 원본이 여러 곳에서
쓰는 포인터 비교(같은 배열 안의 정점은 색인 순으로 놓인다)를 옮긴 것으로,
|Index|와 마찬가지로 |unsafe|에 기댄다.

@<빌더 자료구조@>=
func ptrGeq(a, b *gbgraph.Vertex) bool {
	return uintptr(unsafe.Pointer(a)) >= uintptr(unsafe.Pointer(b))
}

// |newLikeG|는 |g|와 같은 정점(이름만 베낀)을 가진 빈 그래프를 만든다.
// |Complement|, |Gunion|, |Intersection|이 함께 쓴다.
func newLikeG(g *gbgraph.Graph) *gbgraph.Graph {
	ng := gbgraph.NewGraph(g.N)
	for i := int64(0); i < g.N; i++ {
		ng.Vertices[i].Name = g.Vertices[i].Name
	}
	return ng
}

func ptrLess(a, b *gbgraph.Vertex) bool {
	return uintptr(unsafe.Pointer(a)) < uintptr(unsafe.Pointer(b))
}

// |inArray|는 |v|가 |verts|가 뒷받침하는 배열 안의 정점인지 말한다.
func inArray(v *gbgraph.Vertex, verts []gbgraph.Vertex) bool {
	if len(verts) == 0 {
		return false
	}
	p := uintptr(unsafe.Pointer(v))
	lo := uintptr(unsafe.Pointer(&verts[0]))
	hi := lo + uintptr(len(verts))*unsafe.Sizeof(gbgraph.Vertex{})
	return p >= lo && p < hi
}

@ |Intersection|은 넉 개의 임시 필드를 쓴다: |tmp|(|U.V|), |tlen|(|Z.A|),
그리고 호의 다중도를 세는 |mult|(|V.I|)와 가장 작은 길이를 담는
|minlen|(|W.I|)이다. 먼저 |g|의 호들을 훑어 표시해 두고, |gg|의 호들을 훑어
양쪽에 다 있는 것만 낸다.

@<기본 서브루틴@>=
func Intersection(g, gg *gbgraph.Graph, multi, directed bool) (*gbgraph.Graph, error) {
	if g == nil || gg == nil {
		return nil, gbgraph.MissingOperand
	}
	n := g.N
	ng := newLikeG(g)
	ng.MakeDoubleCompoundID("intersection(", g, ",", gg,
		fmt.Sprintf(",%d,%d)", boolInt(multi), boolInt(directed)))
	@<두 그래프에 다 있는 호를 |ng|에 넣는다@>
	for i := int64(0); i < n; i++ {
		v := &ng.Vertices[i]
		v.U.V, v.Z.A, v.V.I, v.W.I = nil, nil, 0, 0
	}
	return ng, nil
}

@ 각 정점에서 |g|의 호를 먼저 표시해 두고, |gg|의 호 가운데 표시된 것만
--- 곧 양쪽에 다 있는 것만---낸다.

@<두 그래프에 다 있는 호를 |ng|에 넣는다@>=
for i := int64(0); i < n; i++ {
	if i >= gg.N {
		continue
	}
	v := &g.Vertices[i]
	vv := &ng.Vertices[i]
	@<|v|에서 나가는 모든 호를 표시한다@>
	for a := gg.Vertices[i].Arcs; a != nil; a = a.Next {
		ti := gg.Index(a.Tip)
		if ti >= n {
			continue
		}
		u := &ng.Vertices[ti]
		if u.U.V == vv {
			l := u.W.I
			if a.Len > l {
				l = a.Len
			}
			if u.V.I < 0 {
				@<여러 최댓값의 최솟값을 갱신한다@>
			} else {
				@<교집합 호나 간선을 만들고 다중도를 줄인다@>
			}
		}
	}
}

@ @<|v|에서 나가는 모든 호를 표시한다@>=
for a := v.Arcs; a != nil; a = a.Next {
	u := &ng.Vertices[g.Index(a.Tip)]
	if u.U.V == vv {
		u.V.I++
		if a.Len < u.W.I {
			u.W.I = a.Len
		}
	} else {
		u.U.V, u.V.I, u.W.I = vv, 0, a.Len
	}
	if u == vv && !directed && a.Next == a.Partner {
		a = a.Partner // 자기 고리의 뒤 짝을 건너뛴다
	}
}

@ |l|은 |g|쪽 최소 길이와 |gg|쪽 길이의 최댓값이다. |multi|가 아니면 여러
최댓값 중 최솟값만 살린다.

@<교집합 호나 간선을 만들고 다중도를 줄인다@>=
if directed {
	ng.NewArc(vv, u, l)
} else {
	if ptrGeq(u, vv) {
		ng.NewEdge(vv, u, l)
	}
	if vv == u && a.Next == a.Partner {
		a = a.Partner
	}
}
if !multi {
	u.Z.A, u.V.I = vv.Arcs, -1
} else if u.V.I == 0 {
	u.U.V = nil
} else {
	u.V.I--
}

@ @<여러 최댓값의 최솟값을 갱신한다@>=
bb := u.Z.A // |vv|에서 |u|로 가는 이전 호나 간선
if l < bb.Len {
	bb.Len = l
	if !directed {
		bb.Partner.Len = l
	}
}

@*선그래프. |Lines(g,directed)|는 |g|의 선그래프를 만든다. 무향이면 |g|의
간선마다 정점 하나를 두고, 공통 정점을 가진 두 간선이 이웃이다. 유향이면 |g|의
호마다 정점 하나를 두고, 한 호가 끝나는 정점에서 다른 호가 시작할 때 이웃이다.
선그래프 정점의 |U.V|와 |V.V|는 |g|에서 대응하는 호를 이루는 두 정점을,
|W.A|는 그 호를 가리킨다.

@ 선그래프를 효율적으로 짓기 위해 |g|에 임시 자료를 얹되, 일이 끝나면 |g|가
점령의 흔적을 하나도 안 남기게 되돌린다. 원래 정점 |v|의 |Z.V|(|map|)를 잠시
빌려, |U.V==v|인 첫 선그래프 정점을 가리키게 한다. 무향일 때는 간선 쌍의 둘째
호의 |Tip|을 그 선그래프 정점으로 잠시 바꾼다. \CEE/ 원본이 여러 배열에 걸쳐
쓰는 포인터 비교를 옮기느라 |ptrLess| 등 주소 비교 도우미를 쓴다.

@<기본 서브루틴@>=
func Lines(g *gbgraph.Graph, directed bool) (*gbgraph.Graph, error) {
	if g == nil {
		return nil, gbgraph.MissingOperand
	}
	m := g.M
	if !directed {
		m = g.M / 2
	}
	ng := gbgraph.NewGraph(m)
	idTail := ",0)"
	if directed {
		idTail = ",1)"
	}
	ng.MakeCompoundID("lines(", g, idTail)
	@<|g|를 되돌리는 |restore| 클로저를 마련한다@>
	@<선그래프의 정점들을 마련한다@>
	if directed {
		@<유향 선그래프의 호를 넣는다@>
	} else {
		@<무향 선그래프의 간선을 넣는다@>
	}
	restore(m)
	return ng, nil
}

@ |restore|는 |g|에 얹은 임시 자료(정점 |map|과 짝호 |Tip|)를 걷어내 |g|를
점령의 흔적 없이 되돌린다. |cnt|개의 선그래프 정점까지만 훑으므로, 중간에
실패해도 부분 복원에 쓸 수 있다.

@<|g|를 되돌리는 |restore| 클로저를 마련한다@>=
restore := func(cnt int64) {
	var prev *gbgraph.Vertex
	for ui := int64(0); ui < cnt; ui++ {
		u := &ng.Vertices[ui]
		if u.U.V != prev {
			prev = u.U.V
			prev.Z.V = u.Z.V // |v.Z|의 원래 값을 되돌린다
			u.Z.V = nil
		}
		if !directed {
			u.W.A.Partner.Tip = prev
		}
	}
}

@ 정점 |v|를 마지막부터 거슬러 훑으며, 각 호 |a|(무향이면 |Tip>=v|인 것만)마다
선그래프 정점 |u|를 만든다. |g|가 무향 관례를 어기면 |restore| 후
|InvalidOperand|로 물러난다.

@<선그래프의 정점들을 마련한다@>=
ui := int64(0)
for vidx := g.N - 1; vidx >= 0; vidx-- {
	v := &g.Vertices[vidx]
	mapped := false
	for a := v.Arcs; a != nil; a = a.Next {
		vv := a.Tip
		if !directed {
			if ptrLess(vv, v) {
				continue
			}
			if !inArray(vv, g.Vertices[:g.N]) {
				restore(ui)
				return nil, gbgraph.InvalidOperand // |g|가 무향이 아니다
			}
		}
		@<호 |a|를 나타내는 선그래프 정점 |u|를 만든다@>
	}
}
if ui != m {
	restore(ui)
	return nil, gbgraph.InvalidOperand
}

@ 정점 |u|의 |U.V|·|V.V|·|W.A|에 원래 정점 둘과 호를 담고, 무향이면 짝호의
|Tip|을 |u|로 잠시 돌린다. 정점 |v|의 |map|(|Z.V|)은 |v|의 첫 선그래프 정점을
가리키게 한다.

@<호 |a|를 나타내는 선그래프 정점 |u|를 만든다@>=
if ui >= m {
	restore(ui)
	return nil, gbgraph.InvalidOperand
}
u := &ng.Vertices[ui]
u.U.V, u.V.V, u.W.A = v, vv, a
if !directed {
	if a.Partner == nil || a.Partner.Tip != v {
		restore(ui)
		return nil, gbgraph.InvalidOperand
	}
	if v == vv && a.Next == a.Partner {
		a = a.Partner // 자기 고리의 뒤 짝을 건너뛴다
	} else {
		a.Partner.Tip = u // 짝호의 |Tip|을 선그래프 정점으로
	}
}
u.Name = lineName(v.Name, vv.Name, directed)
if !mapped {
	u.Z.V = v.Z.V
	v.Z.V = u
	mapped = true
}
ui++

@ 선그래프 정점 이름은 원래 두 이름을 무향이면 |"--"|로, 유향이면 |"->"|로
이은 것이다. 이름이 너무 길면 절반 길이로 잘라낸다.

@<빌더 자료구조@>=
func lineName(a, b string, directed bool) string {
	if int64(len(a)) > (bufSize-3)/2 {
		a = a[:(bufSize-3)/2]
	}
	if int64(len(b)) > bufSize/2-1 {
		b = b[:bufSize/2-1]
	}
	sep := "-"
	if directed {
		sep = ">"
	}
	return a + "-" + sep + b
}

@ 유향 선그래프에서, |u|가 나타내는 호가 정점 |v|에서 끝나면, |v|에서 시작하는
모든 선그래프 정점(|v.map|부터 이어진 블록)으로 호를 낸다.

@<유향 선그래프의 호를 넣는다@>=
for ui := int64(0); ui < m; ui++ {
	u := &ng.Vertices[ui]
	v := u.V.V
	if v.Arcs != nil {
		li := ng.Index(v.Z.V)
		for {
			ng.NewArc(u, &ng.Vertices[li], 1)
			li++
			if ng.Vertices[li].U.V != v {
				break
			}
		}
	}
}

@ 무향 선그래프에는 자기 고리가 없다. 첫 끝점에 닿는 앞선 선들과, 둘째 끝점에
닿는 앞선 선들을 각각 찾아 잇는다. 선들의 첫 정점이 비내림차순임을 이용한다.

@<무향 선그래프의 간선을 넣는다@>=
for ui := int64(0); ui < m; ui++ {
	u := &ng.Vertices[ui]
	mapped := false
	v := u.U.V // 첫 끝점에 닿는 앞선 선들
	for li := ng.Index(v.Z.V); li < ui; li++ {
		ng.NewEdge(u, &ng.Vertices[li], 1)
	}
	v = u.V.V // 이어서 둘째 끝점에 닿는 앞선 선들
	for a := range v.AllArcs() {
		vv := a.Tip
		if inArray(vv, ng.Vertices[:m]) && ptrLess(vv, u) {
			ng.NewEdge(u, vv, 1)
		} else if inArray(vv, g.Vertices[:g.N]) && ptrGeq(vv, v) {
			mapped = true
		}
	}
	if mapped && ptrLess(u.U.V, v) && v.Z.V != nil {
		for li := ng.Index(v.Z.V); ng.Vertices[li].U.V == v; li++ {
			ng.NewEdge(u, &ng.Vertices[li], 1)
		}
	}
}

@*그래프 곱. 두 그래프의 곱은 정점이 순서쌍 $(v,v')$이다. {\sl 데카르트 곱\/}은
한 성분에서 호가 있을 때, {\sl 직접 곱\/}은 두 성분 모두에서 호가 있을 때 호를
낸다. {\sl 강한 곱\/}은 둘 다다. |Product(g,gg,type,directed)|의 |type|은
|Cartesian|(0), |Direct|(1), |Strong|(2)이다.

@<기본 서브루틴@>=
// 곱의 종류.
const (
	Cartesian = 0
	Direct    = 1
	Strong    = 2
)

func Product(g, gg *gbgraph.Graph, typ int64, directed bool) (*gbgraph.Graph, error) {
	if g == nil || gg == nil {
		return nil, gbgraph.MissingOperand
	}
	if float64(g.N)*float64(gg.N) > maxNNN {
		return nil, gbgraph.VeryBadSpecs // 정점이 너무 많다
	}
	gn := gg.N
	n := g.N * gn
	ng := gbgraph.NewGraph(n)
	@<순서쌍 정점들에 이름을 붙인다@>
	if typ&1 == 0 {
		@<데카르트 곱의 호나 간선을 넣는다@>
	}
	if typ != 0 {
		@<직접 곱의 호나 간선을 넣는다@>
	}
	return ng, nil
}

@ 정점 $(v,v')$은 이름이 두 원래 이름을 쉼표로 이은 것이고, 곱 그래프에서
색인 $i\cdot|gn|+j$에 놓인다.

@<순서쌍 정점들에 이름을 붙인다@>=
for i := int64(0); i < g.N; i++ {
	for j := int64(0); j < gn; j++ {
		ng.Vertices[i*gn+j].Name = pairName(g.Vertices[i].Name, gg.Vertices[j].Name)
	}
}
tf := 0
if typ != 0 {
	tf = 2
}
tf -= int(typ & 1)
ng.MakeDoubleCompoundID("product(", g, ",", gg,
	fmt.Sprintf(",%d,%d)", tf, boolInt(directed)))

@ @<빌더 자료구조@>=
func pairName(a, b string) string {
	if int64(len(a)) > bufSize/2-1 {
		a = a[:bufSize/2-1]
	}
	if int64(len(b)) > (bufSize-1)/2 {
		b = b[:(bufSize-1)/2]
	}
	return a + "," + b
}

@ 데카르트 곱: |gg|의 호는 첫 성분을 고정한 채, |g|의 호는 둘째 성분을 고정한
채 복제한다.

@<데카르트 곱의 호나 간선을 넣는다@>=
for ju := int64(0); ju < gn; ju++ {
	for a := gg.Vertices[ju].Arcs; a != nil; a = a.Next {
		jv := gg.Index(a.Tip)
		if !directed {
			if ju > jv {
				continue
			}
			if ju == jv && a.Next == a.Partner {
				a = a.Partner
			}
		}
		for i := int64(0); i < g.N; i++ {
			@<곱 정점 $(i,ju)$에서 $(i,jv)$로 잇는다@>
		}
	}
}
for iu := int64(0); iu < g.N; iu++ {
	for a := g.Vertices[iu].Arcs; a != nil; a = a.Next {
		iv := g.Index(a.Tip)
		if !directed {
			if iu > iv {
				continue
			}
			if iu == iv && a.Next == a.Partner {
				a = a.Partner
			}
		}
		for j := int64(0); j < gn; j++ {
			@<곱 정점 $(iu,j)$에서 $(iv,j)$로 잇는다@>
		}
	}
}

@ @<곱 정점 $(i,ju)$에서 $(i,jv)$로 잇는다@>=
if directed {
	ng.NewArc(&ng.Vertices[i*gn+ju], &ng.Vertices[i*gn+jv], a.Len)
} else {
	ng.NewEdge(&ng.Vertices[i*gn+ju], &ng.Vertices[i*gn+jv], a.Len)
}

@ @<곱 정점 $(iu,j)$에서 $(iv,j)$로 잇는다@>=
if directed {
	ng.NewArc(&ng.Vertices[iu*gn+j], &ng.Vertices[iv*gn+j], a.Len)
} else {
	ng.NewEdge(&ng.Vertices[iu*gn+j], &ng.Vertices[iv*gn+j], a.Len)
}

@ 직접 곱: |g|의 호와 |gg|의 호가 함께 있어야 호를 낸다. 길이는 둘의 최솟값이다.

@<직접 곱의 호나 간선을 넣는다@>=
for iu := int64(0); iu < g.N; iu++ {
	for a := g.Vertices[iu].Arcs; a != nil; a = a.Next {
		iv := g.Index(a.Tip)
		if !directed {
			if iu > iv {
				continue
			}
			if iu == iv && a.Next == a.Partner {
				a = a.Partner
			}
		}
		for ju := int64(0); ju < gn; ju++ {
			for aa := gg.Vertices[ju].Arcs; aa != nil; aa = aa.Next {
				length := a.Len
				if length > aa.Len {
					length = aa.Len
				}
				jv := gg.Index(aa.Tip)
				pu := &ng.Vertices[iu*gn+ju]
				pv := &ng.Vertices[iv*gn+jv]
				if directed {
					ng.NewArc(pu, pv, length)
				} else {
					ng.NewEdge(pu, pv, length)
				}
			}
		}
	}
}

@*유도 그래프. |Induced(g,description,self,multi,directed)|는 정점을 없애거나,
동일시하거나, 쪼개어 그래프를 탈바꿈시킨다. 각 정점 |v|의 유도 부호는 |Z.I|
필드에 담는다: 0이면 |v|를 없애고, 1이면 남기고, |k>1|이면 이웃이 같은 서로
이웃 아닌 |k|개로 쪼개고, |k<0|이면 같은 |k|값을 가진 정점들과 하나로 합친다.
게다가 유도 부호가 |indGraph| 이상이면 |Y.G|(|subst|)가 가리키는 그래프의
정점들을 |v| 자리에 넣는다.

@ 유도 그래프의 정점 수는 양의 유도 부호들의 합에 가장 음인 유도 부호의
절댓값을 더한 것이다. \CEE/의 정적 배열 |nn|과 이름이 겹치던 지역 스칼라는
|nneg|로 옮겼다.

@<기본 서브루틴@>=
func Induced(g *gbgraph.Graph, description string, self, multi, directed bool) (*gbgraph.Graph, error) {
	if g == nil {
		return nil, gbgraph.MissingOperand
	}
	var n, nneg int64
	@<유도 정점 수 |n|과 음의 정점 수 |nneg|를 정한다@>
	ng := gbgraph.NewGraph(n)
	@<새 정점에 이름을 붙이고 |g| 에서 |ng|로의 지도를 만든다@>
	ng.MakeCompoundID("induced(", g,
		fmt.Sprintf(",%s,%d,%d,%d)", description, boolInt(self), boolInt(multi), boolInt(directed)))
	@<유도 정점들의 호나 간선을 넣는다@>
	@<|g|를 원래 상태로 되돌린다@>
	return ng, nil
}

@ @<유도 정점 수 |n|과 음의 정점 수 |nneg|를 정한다@>=
for i := int64(0); i < g.N; i++ {
	ind := g.Vertices[i].Z.I
	if ind > 0 {
		if n > indGraph {
			return nil, gbgraph.VeryBadSpecs
		}
		if ind >= indGraph {
			if g.Vertices[i].Y.G == nil {
				return nil, gbgraph.MissingOperand + 1 // 치환 그래프가 없다
			}
			n += g.Vertices[i].Y.G.N
		} else {
			n += ind
		}
	} else if ind < -nneg {
		nneg = -ind
	}
}
if n > indGraph || nneg > indGraph {
	return nil, gbgraph.VeryBadSpecs + 1 // 거대하다
}
n += nneg

@ 음의 정점은 그 음수를 이름으로 갖는다. 쪼갠 정점은 유도 부호가 2이면 이름
뒤에 프라임을, 아니면 콜론과 색인을 붙인다. 원래 유도 부호는 새 그래프 첫
대응 정점의 |mult|(|V.I|)에 저장하고, |map|(|Z.V|)이 그 정점을 가리키게 한다.

@<새 정점에 이름을 붙이고 |g| 에서 |ng|로의 지도를 만든다@>=
ui := int64(0)
for k := int64(1); k <= nneg; k++ {
	ng.Vertices[ui].V.I = -k
	ng.Vertices[ui].Name = strconv.FormatInt(-k, 10)
	ui++
}
for i := int64(0); i < g.N; i++ {
	v := &g.Vertices[i]
	k := v.Z.I
	if k < 0 {
		v.Z.V = &ng.Vertices[-(k + 1)]
	} else if k > 0 {
		u := &ng.Vertices[ui]
		u.V.I = k
		v.Z.V = u
		if k <= 2 {
			u.Name = v.Name
			ui++
			if k == 2 {
				ng.Vertices[ui].Name = v.Name + "'"
				ui++
			}
		} else if k >= indGraph {
			@<치환 그래프의 이름과 호를 만든다@>
		} else {
			for j := int64(0); j < k; j++ {
				ng.Vertices[ui].Name = fmt.Sprintf("%s:%d", v.Name, j)
				ui++
			}
		}
	}
}

@ 유도 그래프를 짓는 핵심은 |g|의 호를 |ng|의 호로 옮기는 대목이다. |v|가
|k|개로 쪼개졌으면 그 복제본들 사이에 호를 낳는다. |multi|가 아니면 |tmp|와
|tlen| 요령으로 중복 호를 걸러낸다.

@<유도 정점들의 호나 간선을 넣는다@>=
for i := int64(0); i < g.N; i++ {
	v := &g.Vertices[i]
	u0 := v.Z.V
	if u0 == nil {
		continue
	}
	k := u0.V.I // |v|의 복제본 수
	if k < 0 {
		k = 1
	} else if k >= indGraph {
		k = v.Y.G.N
	}
	ci := ng.Index(u0)
	for ; k > 0; k, ci = k-1, ci+1 {
		u := &ng.Vertices[ci]
		if !multi {
			@<|u|에 닿는 기존 간선을 표시한다@>
		}
		for a := v.Arcs; a != nil; a = a.Next {
			@<호 |a|가 낳는 유도 호나 간선을 넣는다@>
		}
	}
}

@ @<|u|에 닿는 기존 간선을 표시한다@>=
for a := range u.AllArcs() {
	tip := a.Tip
	tip.U.V = u
	if directed || ptrLess(u, tip) || a.Next == a.Partner {
		tip.Z.A = a
	} else {
		tip.Z.A = a.Partner
	}
}

@ @<호 |a|가 낳는 유도 호나 간선을 넣는다@>=
vv := a.Tip
vvmap := vv.Z.V
if vvmap == nil {
	continue
}
j := vvmap.V.I // |vv|의 복제본 수
if j < 0 {
	j = 1
} else if j >= indGraph {
	j = vv.Y.G.N
}
uui := ng.Index(vvmap)
if !directed {
	if ptrLess(vv, v) {
		continue
	}
	if vv == v {
		if a.Next == a.Partner {
			a = a.Partner
		}
		j, uui = k, ci // 자기 고리의 중복 간선도 건너뛴다
	}
}
@<복제본 |uu| 들에 |u|에서 호를 낸다@>

@ |vv|의 복제본 |uu|(색인 |uui|부터 |j|개)마다 |u|에서 호나 간선을 낸다.

@<복제본 |uu| 들에 |u|에서 호를 낸다@>=
for ; j > 0; j, uui = j-1, uui+1 {
	uu := &ng.Vertices[uui]
	if u == uu && !self {
		continue
	}
	if uu.U.V == u && !multi {
		@<|u|에서 |uu|로 가는 최소 길이를 갱신하고 건너뛴다@>
	}
	if directed {
		ng.NewArc(u, uu, a.Len)
	} else {
		ng.NewEdge(u, uu, a.Len)
	}
	uu.U.V = u
	if directed || ptrGeq(uu, u) {
		uu.Z.A = u.Arcs
	} else {
		uu.Z.A = uu.Arcs
	}
}

@ @<|u|에서 |uu|로 가는 최소 길이를 갱신하고 건너뛴다@>=
bb := uu.Z.A
if a.Len < bb.Len {
	bb.Len = a.Len
	if !directed {
		bb.Partner.Len = a.Len
	}
}
continue

@ 이제 남은 조각 하나---치환 그래프의 정점들을 넣는 대목---도 쉽게
끝난다. |g|의 정점 |v| 자리에 그래프 |v.subst|의 복사본을 넣는다.

@<치환 그래프의 이름과 호를 만든다@>=
gg := v.Y.G
base := ui
for j := int64(0); j < gg.N; j++ {
	fromV := &ng.Vertices[ui]
	sv := &gg.Vertices[j]
	fromV.Name = fmt.Sprintf("%s:%s", v.Name, sv.Name)
	for a := sv.Arcs; a != nil; a = a.Next {
		svv := a.Tip
		toV := &ng.Vertices[base+gg.Index(svv)]
		@<|fromV|에서 |toV|로 가는 치환 호를 넣는다@>
	}
	ui++
}

@ 치환 그래프 안의 호 |a|(|sv|에서 |svv|로)를 새 그래프의 |fromV|에서 |toV|로
옮긴다. |multi|가 아니면 |tmp|·|tlen| 요령으로 중복을 거른다.

@<|fromV|에서 |toV|로 가는 치환 호를 넣는다@>=
if svv == sv && !self {
	continue
}
if toV.U.V == fromV && !multi {
	bb := toV.Z.A
	if a.Len < bb.Len {
		bb.Len = a.Len
		if !directed {
			bb.Partner.Len = a.Len
		}
	}
	continue
}
if !directed {
	if ptrLess(svv, sv) {
		continue
	}
	if svv == sv && a.Next == a.Partner {
		a = a.Partner
	}
	ng.NewEdge(fromV, toV, a.Len)
} else {
	ng.NewArc(fromV, toV, a.Len)
}
toV.U.V = fromV
if directed || ptrGeq(toV, fromV) {
	toV.Z.A = fromV.Arcs
} else {
	toV.Z.A = toV.Arcs
}

@ |g|의 |map|과 |ng|의 임시 필드를 말끔히 치운다. \CEE/는 공용체라 |ind|를
되살리며 |map|이 사라지지만, 우리는 두 필드가 따로이므로 |map|을 손수 |nil|로
비운다.

@<|g|를 원래 상태로 되돌린다@>=
for v := range g.AllVertices() {
	if v.Z.V != nil {
		v.Z.I = v.Z.V.V.I // |ind|를 되살린다
		v.Z.V = nil
	}
}
for i := int64(0); i < n; i++ {
	v := &ng.Vertices[i]
	v.U.V, v.V.I, v.Z.A = nil, 0, nil
}

@ |Induced|의 손쉬운 응용 둘이다. |BiComplete(n1,n2,directed)|는 크기 |n1|과
|n2|의 완전 이분 그래프를, |Wheel(n,n1,directed)|은 |n1|개의 중심점에 모두
이어진 |n|개 정점의 바퀴를 만든다. 둘 다 자명한 2정점 그래프에서 출발해
정점을 쪼갠다.

@<기본 서브루틴의 응용@>=
// |BiComplete|는 크기 |n1|, |n2|의 완전 이분 그래프다.
func BiComplete(n1, n2 int64, directed bool) (*gbgraph.Graph, error) {
	ng, err := Board(2, 0, 0, 0, 1, 0, directed)
	if err != nil {
		return nil, err
	}
	ng.Vertices[0].Z.I = n1
	ng.Vertices[1].Z.I = n2
	ng, err = Induced(ng, "", false, false, directed)
	if err != nil {
		return nil, err
	}
	ng.ID = fmt.Sprintf("bi_complete(%d,%d,%d)", n1, n2, boolInt(directed))
	ng.MarkBipartite(n1)
	return ng, nil
}

@ |Wheel|은 |indGraph| 요령으로, 한 정점을 순환(또는 회로)으로 치환한다.

@<기본 서브루틴의 응용@>=
// |Wheel|은 |n1|개 중심점에 이어진 |n|개 정점의 바퀴다.
func Wheel(n, n1 int64, directed bool) (*gbgraph.Graph, error) {
	ng, err := Board(2, 0, 0, 0, 1, 0, directed)
	if err != nil {
		return nil, err
	}
	ng.Vertices[0].Z.I = n1
	ng.Vertices[1].Z.I = indGraph
	cyc, err := Board(n, 0, 0, 0, 1, 1, directed) // 순환 또는 회로
	if err != nil {
		return nil, err
	}
	ng.Vertices[1].Y.G = cyc
	ng, err = Induced(ng, "", false, false, directed)
	if err != nil {
		return nil, err
	}
	ng.ID = fmt.Sprintf("wheel(%d,%d,%d)", n, n1, boolInt(directed))
	return ng, nil
}

@ |indGraph|는 유도 부호가 이 값 이상이면 |subst| 필드를 본다는 뜻의 큰 상수다.

@<상수 정의@>=
const indGraph = 1000000000 // 유도 부호가 10억 이상이면 |subst|를 본다

@* 시험. 알려진 조합론적 사실로 생성기를 검증한다. |Board|는 완전 그래프와
퀸 그래프로 확인한다.

@(gbbasic_test.go@>=
package gbbasic

import (
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
)

@<board 시험@>

@ |Complete(n)|은 $n$개 정점 각각이 나머지 $n-1$개와 이어진 완전 그래프다.
$3\times4$ 판의 룩(|piece=-1|)과 비숍(|piece=-2|) 그래프를 합치면 퀸 그래프가
된다.

@<board 시험@>=
func TestComplete(t *testing.T) {
	g, err := Complete(5)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 5 {
		t.Fatalf("N = %d, 원함 5", g.N)
	}
	if g.M != 5*4 {
		t.Errorf("M = %d, 원함 20", g.M)
	}
	if g.ID != "board(5,0,0,0,-1,0,0)" {
		t.Errorf("ID = %q", g.ID)
	}
}

func degree(v *gbgraph.Vertex) (d int64) {
	for range v.AllArcs() {
		d++
	}
	return
}

@ $3\times4$ 판에서 각 칸의 룩 이동은 $(3-1)+(4-1)=5$개다.

@<board 시험@>=
func TestQueenBoard(t *testing.T) {
	g, err := Board(3, 4, 0, 0, -1, 0, false) // 룩
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 12 {
		t.Fatalf("N = %d, 원함 12", g.N)
	}
	// 3x4 판에서 각 칸의 룩 이동은 (3-1)+(4-1)=5개다.
	for v := range g.AllVertices() {
		if d := degree(v); d != 5 {
			t.Errorf("정점 %s의 룩 차수 = %d, 원함 5", v.Name, d)
		}
	}
}

@ |Simplex|의 삼각형 배열($n=3,d=2$)은 정점 10개, |Petersen|은 정점 10개에
모두 차수 3이며 길이 5 미만의 회로가 없다.

@<board 시험@>=
func TestSimplexTriangle(t *testing.T) {
	g, err := Simplex(3, 0, 0, 0, 0, 0, false)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 10 {
		t.Fatalf("N = %d, 원함 10", g.N)
	}
	if g.ID != "simplex(3,-2,0,0,0,0,0)" {
		t.Errorf("ID = %q", g.ID)
	}
}

@ |Petersen|은 정점 10개 모두 차수 3에, 길이 5 미만의 회로가 없다.

@<board 시험@>=
func TestPetersen(t *testing.T) {
	g, err := Petersen()
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 10 {
		t.Fatalf("N = %d, 원함 10", g.N)
	}
	if g.M/2 != 15 {
		t.Errorf("간선 수 = %d, 원함 15", g.M/2)
	}
	for v := range g.AllVertices() {
		if d := degree(v); d != 3 {
			t.Errorf("정점 %s의 차수 = %d, 원함 3", v.Name, d)
		}
	}
}

@ 다중집합 $\{0,0,1,2\}$의 순열은 12개, $\{0,1,2,3\}$의 순열은 $4!=24$개다.

@<board 시험@>=
func TestPerms(t *testing.T) {
	g, err := Perms(2, 1, 1, 0, 0, 0, false)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 12 {
		t.Errorf("N = %d, 원함 12", g.N)
	}
	g, err = AllPerms(4, false)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 24 {
		t.Errorf("AllPerms(4) N = %d, 원함 24", g.N)
	}
}

@ 정수 5의 분할은 7개다.

@<board 시험@>=
func TestParts(t *testing.T) {
	g, err := AllParts(5, false)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 7 {
		t.Errorf("N = %d, 원함 7", g.N)
	}
	if g.ID != "parts(5,5,5,0)" {
		t.Errorf("ID = %q", g.ID)
	}
}

@ 내부 노드 3개의 이진 트리는 길이 5의 회로를 이루니 정점 5개에 저마다 차수 2다.

@<board 시험@>=
func TestBinary(t *testing.T) {
	g, err := AllTrees(3, false)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 5 {
		t.Fatalf("N = %d, 원함 5", g.N)
	}
	if g.M/2 != 5 {
		t.Errorf("간선 수 = %d, 원함 5", g.M/2)
	}
	for v := range g.AllVertices() {
		if d := degree(v); d != 2 {
			t.Errorf("정점 %s의 차수 = %d, 원함 2", v.Name, d)
		}
	}
}

@ 변환기들도 알려진 사실로 검증한다. $K_5$의 여집합은 간선이 없고, 빈 그래프의
여집합은 완전 그래프다.

@<board 시험@>=
func TestComplement(t *testing.T) {
	k5, _ := Complete(5)
	c, err := Complement(k5, false, false, false)
	if err != nil {
		t.Fatal(err)
	}
	if c.M != 0 {
		t.Errorf("K5 여집합의 호 = %d, 원함 0", c.M)
	}
	e5, _ := Empty(5)
	c, err = Complement(e5, false, false, false)
	if err != nil {
		t.Fatal(err)
	}
	if c.M/2 != 10 {
		t.Errorf("빈 그래프 여집합의 간선 = %d, 원함 10", c.M/2)
	}
}

@ 퀸 그래프는 룩과 비숍 판의 합집합이다.

@<board 시험@>=
func TestGunionQueen(t *testing.T) {
	rook, _ := Board(3, 4, 0, 0, -1, 0, false)
	bishop, _ := Board(3, 4, 0, 0, -2, 0, false)
	q, err := Gunion(rook, bishop, false, false)
	if err != nil {
		t.Fatal(err)
	}
	if q.N != 12 {
		t.Fatalf("N = %d, 원함 12", q.N)
	}
	want := "gunion(board(3,4,0,0,-1,0,0),board(3,4,0,0,-2,0,0),0,0)"
	if q.ID != want {
		t.Errorf("ID = %q", q.ID)
	}
	// 모서리 칸 "0.0"의 퀸 차수는 룩 5 + 비숍 2 = 7이다.
	if d := degree(&q.Vertices[0]); d != 7 {
		t.Errorf("모서리 퀸 차수 = %d, 원함 7", d)
	}
}

@ $K_5$와 $K_5$의 교집합은 다시 $K_5$이다.

@<board 시험@>=
func TestIntersection(t *testing.T) {
	a, _ := Complete(5)
	b, _ := Complete(5)
	g, err := Intersection(a, b, false, false)
	if err != nil {
		t.Fatal(err)
	}
	if g.M/2 != 10 {
		t.Errorf("K5 ∩ K5의 간선 = %d, 원함 10", g.M/2)
	}
}

@ 삼각형 $K_3$의 선그래프는 다시 $K_3$이고, 원본은 흔적 없이 복원된다.

@<board 시험@>=
func TestLinesTriangle(t *testing.T) {
	k3, _ := Complete(3)
	l, err := Lines(k3, false)
	if err != nil {
		t.Fatal(err)
	}
	if l.N != 3 || l.M/2 != 3 {
		t.Errorf("L(K3): N=%d, 간선=%d, 원함 3,3", l.N, l.M/2)
	}
	if k3.M/2 != 3 {
		t.Errorf("원본 K3이 복원되지 않았다: 간선 %d", k3.M/2)
	}
}

@ $K_2$의 데카르트 곱은 4-순환($C_4$)이다.

@<board 시험@>=
func TestProductC4(t *testing.T) {
	k2a, _ := Complete(2)
	k2b, _ := Complete(2)
	p, err := Product(k2a, k2b, Cartesian, false)
	if err != nil {
		t.Fatal(err)
	}
	if p.N != 4 || p.M/2 != 4 {
		t.Errorf("K2□K2: N=%d, 간선=%d, 원함 4,4", p.N, p.M/2)
	}
	for v := range p.AllVertices() {
		if d := degree(v); d != 2 {
			t.Errorf("정점 %s의 차수 = %d, 원함 2", v.Name, d)
		}
	}
}

@ 완전 이분 그래프 $K_{2,3}$은 정점 5개에 간선 6개, 바퀴 |Wheel(4,1)|은 정점
5개에 간선 8개다.

@<board 시험@>=
func TestBiCompleteAndWheel(t *testing.T) {
	bc, err := BiComplete(2, 3, false)
	if err != nil {
		t.Fatal(err)
	}
	if bc.N != 5 || bc.M/2 != 6 {
		t.Errorf("K(2,3): N=%d, 간선=%d, 원함 5,6", bc.N, bc.M/2)
	}
	w, err := Wheel(4, 1, false)
	if err != nil {
		t.Fatal(err)
	}
	if w.N != 5 || w.M/2 != 8 {
		t.Errorf("Wheel(4,1): N=%d, 간선=%d, 원함 5,8", w.N, w.M/2)
	}
}

@* 찾아보기.
