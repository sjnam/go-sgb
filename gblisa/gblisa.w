% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_lisa.w를 Go로 이식한다.
@i ../gbtypes.w

\input kotexgweb
\def\title{GB\_\,LISA}

@* 들어가며. 이 모듈은 레오나르도 다 빈치의 {\sl 조콘다\/}(일명 모나리자)를
@^Vinci, Leonardo da@>
디지털화한 자료에 바탕한 자료 구조를 짓는다. 세 서브루틴이 있다. |Lisa|는
\.{lisa.dat}의 픽셀 자료로 직사각형 정수 행렬을 만들고, |PlaneLisa|는 그
행렬에서 무향 평면 그래프를 얽어내며, |BiLisa|는 무향 이분 그래프를 짓는다.
|Lisa|의 또 다른 쓰임새는 데모 {\sc ASSIGN\_\,LISA}에서 볼 수 있다.

\.{lisa.dat}의 자료는 360행 250열이다. 행은 위에서 아래로 0부터 359까지,
열은 왼쪽에서 오른쪽으로 0부터 249까지 번호가 매겨진다. 픽셀 값은 0(검정)에서
255(흰색)까지이고 그 사이는 회색조다. |Lisa|의 출력은 그림의 직사각형
조각---|m1-m0|행과 |n1-n0|열---에서 만들어진다. 더 정확히 말하면 |m0|$\,\le
k<\,$|m1|이고 |n0|$\,\le l<\,$|n1|인 자리 $(k,l)$의 자료를 쓴다. 두 구간이
모두 {\it 오른쪽이 열린\/} 구간임에 유의하라---이 약속이 뒤에 이름난 부분들의
크기를 셈할 때 다시 나온다.

@ |M=|\thinspace|m1-m0|행과 |N=|\thinspace|n1-n0|열의 입력을 |m|행 |n|열의
출력으로 옮기는 과정은, 거대한 $mM\times nN$ 행렬을 상상하면 이해하기 쉽다.
이 거대 행렬에는 원래 입력 자료가 $M\times N$개의 부분행렬 배열로 복제되어
들어 있고, 부분행렬 하나하나는 크기가 $m\times n$이며 그 안의 $mn$개 값이 모두
같다. 그런데 같은 거대 행렬을 크기 $M\times N$인 부분행렬 $m\times n$개의
배열로 볼 수도 있다. 출력할 픽셀 값은 이 {\it 두 번째\/} 해석에서 부분행렬
하나에 든 $MN$개 픽셀 값을 평균해 얻는다.

좀 더 정확히는 두 단계를 밟는다. 먼저 해당 부분행렬의 $MN$개 값을 모두 더해
$0$과 $255MN$ 사이의 값 $D$를 얻는다. 그런 다음 $D$를 원하는 최종 범위
$[0,d]$로 선형으로 옮긴다: $D<|d0|$이면 0, $D\ge|d1|$이면 $d$, 그 사이면
$\lfloor d(D-|d0|)/(|d1|-|d0|)\rfloor$이다.

@ |m|·|n|·|d|·|m1|·|n1|·|d1|을 0으로 주면 기본값이 자동으로 채워진다.
|m1|이 0이거나 360보다 크면 360으로, |n1|이 0이거나 250보다 크면 250으로
바뀐다. 그러고 나서 |m|이 0이면 |m1-m0|으로, |n|이 0이면 |n1-n0|으로 바뀐다.
|d|가 0이면 255가 되고, |d1|이 0이면 $255(|m1|-|m0|)(|n1|-|n0|)$이 된다.
이 치환이 모두 끝난 뒤의 매개변수는 반드시
$$\hbox{|m0<m1|,\qquad |n0<n1|,\qquad |d0<d1|}$$
을 만족해야 한다. (|d0|만은 기본값 치환의 대상이 아니다.)

@ 보기를 몇 가지 들어 보자. |Lisa(0,0,0,0,0,0,0,0,0,dir)|은
|Lisa(360,250,255,0,360,0,250,0,22950000,dir)|과 같다---끝의 수는
$255\times360\times250$이다. 이 특별한 경우는 \.{lisa.dat}의 원래 자료를
$[0,255]$ 범위 정수의 $360\times250$ 배열로 그대로 내어 준다. 행 $k$·열 $l$의
픽셀은 |Pix[n*k+l]|로 꺼내면 되고, 여기서 |n|은 250이다.

|Lisa(250,250,255,0,250,0,250,0,0,dir)|은 그림 위쪽에서 잘라 낸 정사각 배열을
준다. 아래쪽 모나리자의 두 손은 빠진다.

|Lisa(36,25,25500,0,0,0,0,0,0,dir)|은 원래 자료의 $10\times10$ 부분정사각형을
더해 만든, 값이 $[0,25500]$ 범위인 $36\times25$ 배열을 준다.

@ |Lisa(100,100,100,0,0,0,0,0,0,dir)|은 값이 $[0,100]$ 범위인 $100\times100$
배열을 준다. 이 경우 원래 자료가 사실상 부분픽셀로 쪼개졌다가 알맞게 평균된다.
그런데 이 보기에서는 출력 픽셀 하나가 입력 3.6행과 2.5열에서 나옴에 유의하라.
그러니 이미지가 일그러진다(세로로 눌린다). 다만 우리의 GraphBase 응용은
대체로 이미지 자체보다 조합적 시험 자료에 더 관심이 있다.

|(m1-m0)/m|과 |(n1-n0)/n|이 같으면 |Lisa|의 출력은 ``정사각 픽셀''을
나타낸다. |(m1-m0)/m|이 더 작으면 이 출력으로 만든 하프톤이 가로로 눌리고,
더 크면 세로로 눌린다.

@ 원래 이미지를 이진 자료로 줄이고 싶다면---원래 픽셀이 어떤 문턱값 $t$보다
작은 곳은 0, $t$ 이상인 곳은 1---이렇게 부르면 된다:
$$|Lisa(m,n,1,m0,m1,n0,n1,0,t*(m1-m0)*(n1-n0),dir)|$$

|Lisa(1000,1000,255,0,250,0,250,0,0,dir)|은 원래 이미지 위쪽에서 백만 개의
픽셀을 만들어 낸다. 이 행렬은 \.{lisa.dat}의 원래 자료보다 원소가 많지만,
물론 더 정확하지는 않다. 그저 선형 보간으로---사실은 원래 자료를 $4\times4$
부분배열로 복제해서---얻은 것일 뿐이다.

@ 모나리자의 저 유명한 미소는 |m0=94|, |m1=110|, |n0=97|, |n1=129|가 정하는
$16\times32$ 부분배열에 나타난다. 두 눈은 |m0=61|, |m1=80|, |n0=91|,
|n1=140|에 있다. 원본은 이 둘을 \CEE/ 매크로 |smile|과 |eyes|\footnote*{
\ninepoint 원본은 |eyes|에 ``$20\times50$''이라는 주석을 달았지만, 구간이 오른쪽이
열려 있으므로 실제 크기는 $80-61=19$행, $140-91=49$열이다. 바로 옆의
|smile|은 $110-94=16$, $129-97=32$로 이 약속과 잘 맞으니, |eyes|의 주석이
1씩 어긋난 것으로 보인다. SGB 정오표에는 이 항목이 없다. 아래 |Eyes|의
주석은 자료에서 실제로 나오는 값을 적는다.}로 두어
|lisa(0,0,0,smile,0,0,area)|처럼 쓸 수 있게 했다. \GO/에는 그런 매크로가
없으므로, 같은 구실을 하도록 구간을 값으로 내어 준다.

@<타입 정의@>=
// |Region|은 그림에서 이름난 부분을 가리키는 입력 구간이다.
// 구간은 $[M0,M1)$행, $[N0,N1)$열로 오른쪽이 열려 있다.
type Region struct{ M0, M1, N0, N1 int64 }

var (
	Smile = Region{94, 110, 97, 129} // $16\times32$짜리 미소
	Eyes  = Region{61, 80, 91, 140}  // $19\times49$짜리 두 눈
)

@ 원본은 세 서브루틴을 각각 |long*|·|Graph*|로 돌려주고, 기본값을 채운 뒤의
실제 매개변수는 전역 문자열 |lisa_id|에 담아 두었다가 |plane_lisa|와 |bi_lisa|가
|sscanf|로 되읽었다. \GO/에서는 패키지 수준 가변 상태를 두지 않으므로, |Lisa|가
픽셀 행렬과 함께 기본값이 채워진 매개변수·식별 문자열을 |Matrix| 값 하나에 담아
돌려준다. 그러면 |PlaneLisa|·|BiLisa|는 |sscanf| 없이 그 값을 그대로 읽는다.

@c
package gblisa

import (
	"fmt"
	"path/filepath"
	"strconv"
	@#
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
)

const (
	maxM = 360 // 입력 자료의 전체 행 수
	maxN = 250 // 입력 자료의 전체 열 수
	maxD = 255 // 입력 자료의 최대 픽셀 값
)

const DataDirectory = "/usr/local/sgb/data"

@<타입 정의@>
@<서브루틴@>

@ |Matrix|는 |Lisa|가 돌려주는 값이다. |Pix|는 길이 $|M|\times|N|$인 픽셀
행렬이고(행 |k|·열 |l|의 픽셀은 |Pix[k*N+l]|), 나머지 필드는 기본값이 채워진
뒤의 실제 매개변수와 원본의 |lisa_id|에 해당하는 식별 문자열 |ID|다.

@<타입 정의@>=
type Matrix struct {
	M, N           int64   // 기본값 적용 뒤의 행·열 수
	D              int64   // 기본값 적용 뒤의 최대 픽셀 값
	M0, M1, N0, N1 int64   // 실제 쓰인 입력 구간
	Pix            []int64 // 길이 |M*N|의 픽셀 행렬
	ID             string  // \.{"lisa(...)"} 꼴의 식별 문자열
}

@* Lisa 서브루틴.
|Lisa(m,n,d,m0,m1,n0,n1,d0,d1,dir)|은 |dir| 디렉터리의 \.{lisa.dat}에서
$[|m0|,|m1|)$행·$[|n0|,|n1|)$열의 직사각형 조각을 뽑아, 값이 $[0,d]$ 범위인
$|m|\times|n|$ 정수 행렬을 만든다. |m|·|n|·|d|·|m1|·|n1|·|d1| 가운데 0으로
주어진 것은 기본값으로 바뀐다.

출력 픽셀 값은 두 단계로 얻는다. 먼저 대응하는 입력 부분행렬의 값을 모두 더해
$0$과 $255MN$ 사이의 합 $D$를 얻는다($M=|m1|-|m0|$, $N=|n1|-|n0|$). 그런 다음
$D$를 $[0,d]$로 눈금을 옮긴다: $D<|d0|$이면 0, $D\ge|d1|$이면 $d$, 그 사이면
$\lfloor d(D-|d0|)/(|d1|-|d0|)\rfloor$이다.

@ 문제가 생기면 |Lisa|는 |nil|과 함께 무엇이 잘못됐는지 알리는 |error|(곧
|gbgraph.PanicCode|)를 돌려준다.

원본에는 여기에 ``정수 눈금 조정''이라는 장이 통째로 하나 더 있었다. 마지막
눈금 조정 단계가 $\lfloor d(D-|d0|)/|capD|\rfloor$을 셈해야 하는데, 세 값이
모두 $2^{31}$에 육박할 수 있어 32비트 |long|에서는 곱 $d(D-|d0|)$가 넘쳐
버리기 때문이다. Knuth는 이를 피하려고 |na_over_b|라는 서브루틴을 두었다.
$n$을 2진법으로 쪼개 비트를 스택에 밀어 넣었다가 되꺼내면서, 몫과 나머지를
한 비트씩 갱신해 $\lfloor na/b\rfloor$을 넘침 없이 구하는 방식이다.

\GO/의 |int64|에서는 그럴 필요가 없다. 두 인자가 $2^{31}$ 미만이므로 곱해도
$2^{62}$ 안쪽이라, 곱하고 나누기만 하면 그만이다. 그래서 그 장은 이 문서에
남지 않았다---이식이 원본보다 짧아지는 몇 안 되는 자리다.

@<서브루틴@>=
func Lisa(m, n, d, m0, m1, n0, n1, d0, d1 int64, dir string) (*Matrix, error) {
	if dir == "" {
		dir = DataDirectory
	}
	@<매개변수를 검사하고 기본값을 채운다@>
	matx := make([]int64, m*n)
	@<\.{lisa.dat}을 읽어 원하는 출력 꼴로 옮긴다@>
	return &Matrix{M: m, N: n, D: d, M0: m0, M1: m1, N0: n0, N1: n1,
		Pix: matx, ID: id}, nil
}

@ |d0|는 기본값을 채우지 않는다. |d1|만 0일 때 $255MN$으로 바뀐다. 식별
문자열은 이 모두가 채워진 뒤의 값으로 짓는다.

@<매개변수를 검사하고 기본값을 채운다@>=
if m1 == 0 || m1 > maxM {
	m1 = maxM
}
if m1 <= m0 {
	return nil, gbgraph.BadSpecs + 1 // |m0|는 |m1|보다 작아야 한다
}
if n1 == 0 || n1 > maxN {
	n1 = maxN
}
if n1 <= n0 {
	return nil, gbgraph.BadSpecs + 2 // |n0|는 |n1|보다 작아야 한다
}
capM, capN := m1-m0, n1-n0
if m == 0 {
	m = capM
}
if n == 0 {
	n = capN
}
if d == 0 {
	d = maxD
}
if d1 == 0 {
	d1 = maxD * capM * capN
}
if d1 <= d0 {
	return nil, gbgraph.BadSpecs + 3 // |d0|는 |d1|보다 작아야 한다
}
if d1 >= 0x80000000 {
	return nil, gbgraph.BadSpecs + 4 // |d1|은 $2^{31}$보다 작아야 한다
}
capD := d1 - d0
id := fmt.Sprintf("lisa(%d,%d,%d,%d,%d,%d,%d,%d,%d)",
	m, n, d, m0, m1, n0, n1, d0, d1)

@ 자료 파일을 열어 |m0| 앞의 원치 않는 행들을 건너뛴 뒤 출력 |m|행을 만들고,
|m1| 뒤의 남은 행들을 건너뛰고 파일을 닫는다. 각 입력 행은 파일에서 다섯 줄을
차지한다.

@<\.{lisa.dat}을 읽어 원하는 출력 꼴로 옮긴다@>=
df, err := gbio.Open(filepath.Join(dir, "lisa.dat"))
if err != nil {
	return nil, gbgraph.EarlyDataFault // 파일을 열 수 없다
}
for i := int64(0); i < m0; i++ {
	for j := 0; j < 5; j++ {
		df.NextLine() // 입력 한 행을 건너뛴다
	}
}
inRow := make([]int64, maxN)
@<출력 |m|행을 만든다@>
for i := m1; i < maxM; i++ {
	for j := 0; j < 5; j++ {
		df.NextLine() // 입력 한 행을 건너뛴다
	}
}
if df.Close() != nil {
	return nil, gbgraph.LateDataFault // 검사합 따위의 오류
}

@* 기본적인 이미지 처리.
입력을 거대한 $mM\times nN$ 행렬로 상상하자. 여기에 $M\times N$ 이미지가 픽셀
값의 복제로 채워지고, 여기서 $m\times n$ 이미지가 픽셀 값의 합산과 눈금 조정으로
얻어진다. 바깥 고리(행 |k|)는 안쪽 고리(열 |l|)와 짜임새가 같되, 합의 벡터
하나를 통째로 다루고 한 입력 행을 다 쓰면 입력 루틴을 부른다는 점만 다르다.

|kappa|는 |inRow|에 담긴 입력 픽셀의 거대 행렬 속 아래 경계, |kap|은 아직 쓰지
않은 첫 거대 행, |nextKap|은 출력 행 |k|의 아래 경계다. |fac|은 지금 입력 합을
몇 곱해 복제할지를 나타내는 인자다.

@<출력 |m|행을 만든다@>=
kappa, kap := int64(0), int64(0)
for k := int64(0); k < m; k++ {
	base := k * n
	for l := int64(0); l < n; l++ {
		matx[base+l] = 0 // 합의 벡터를 지운다
	}
	nextKap := kap + capM
	for {
		if kap >= kappa {
			@<입력 한 행을 |inRow|에 읽는다@>
			kappa += m
		}
		nk := kappa
		if nextKap < nk {
			nk = nextKap
		}
		fac := nk - kap
		@<픽셀 합 한 행을 구해 |fac|배 한다@>
		kap = nk
		if kap >= nextKap {
			break
		}
	}
	@<이 행의 합들을 눈금 맞춘다@>
}

@ 안쪽 고리다. |lambda|는 |curPix|의 입력 픽셀이 차지하는 거대 열의 오른쪽
경계, |lam|은 이 행에서 아직 쓰지 않은 첫 거대 열, |nextLam|은 출력 열 |l|의
오른쪽 경계다. 많은 원소가 되풀이되므로 덧셈 대신 곱셈으로 몰아 센다.

@<픽셀 합 한 행을 구해 |fac|배 한다@>=
lambda := n
curPix := n0
lam := int64(0)
for l := int64(0); l < n; l++ {
	sum := int64(0)
	nextLam := lam + capN
	for {
		if lam >= lambda {
			curPix++
			lambda += n
		}
		nl := lambda
		if nextLam < nl {
			nl = nextLam
		}
		sum += (nl - lam) * inRow[curPix]
		lam = nl
		if lam >= nextLam {
			break
		}
	}
	matx[base+l] += fac * sum
}

@ 합 $D$를 최종 범위 $[0,d]$로 옮긴다. 앞서 밝혔듯 |int64|에서는 넘침 걱정이
없어 곱하고 나누기만 하면 된다.

@<이 행의 합들을 눈금 맞춘다@>=
for l := int64(0); l < n; l++ {
	switch s := matx[base+l]; {
	case s <= d0:
		matx[base+l] = 0
	case s >= d1:
		matx[base+l] = d
	default:
		matx[base+l] = d * (s - d0) / capD
	}
}

@* 입력 자료 형식.
\.{lisa.dat}은 360행의 픽셀 자료를 담고, 한 행은 이어지는 다섯 줄에 걸친다.
앞 네 줄은 60픽셀씩을 담는데, 네 픽셀마다 {\sc GB\_\,IO}의 |icode| 대응으로 다섯
자리 85진수 하나가 된다. 마지막 다섯째 줄은 $4+4+2=10$픽셀을 $5+5+3$자리
85진수로 담는다.

포인터 산술을 |inRow|의 인덱스 |p|로 옮긴다. |dd|는 고리 밖에 두어야
|p==maxN-2|에서 빠져나온 뒤에도 마지막 세 자리로 읽은 두 픽셀을 쓸 수 있다.

@<입력 한 행을 |inRow|에 읽는다@>=
j := int64(15)
p := int64(0)
var dd int64
for {
	dd = df.Digit(85)
	dd = dd*85 + df.Digit(85)
	dd = dd*85 + df.Digit(85)
	if p == maxN-2 {
		break
	}
	dd = dd*85 + df.Digit(85)
	dd = dd*85 + df.Digit(85)
	inRow[p+3] = dd & 0xff
	dd = (dd >> 8) & 0xffffff
	inRow[p+2] = dd & 0xff
	dd >>= 8
	inRow[p+1] = dd & 0xff
	inRow[p] = dd >> 8
	if j--; j == 0 {
		df.NextLine()
		j = 15
	}
	p += 4
}
inRow[p+1] = dd & 0xff
inRow[p] = dd >> 8
df.NextLine()

@* 평면 그래프.
모나리자의 디지털화에서 평면 그래프의 커다란 집안 하나를 다음의 간단한
방식으로 얻을 수 있다. 픽셀 행렬은 값이 같은 픽셀들의 연결 영역 집합을
이룬다(두 픽셀은 변을 맞대면 이웃이다). 이 영역들을 무향 그래프의 정점으로
삼고, 두 영역이 픽셀 변을 하나라도 공유하면 두 정점이 이웃이라고 한다.

이 구성을 달리 말할 수도 있다. 평면 그래프에서 이웃한 두 정점을 하나로
합치면(collapse) 다시 평면 그래프가 된다. 이제 $0\le k<m$, $0\le l<n$인
$mn$개 정점 $[k,l]$을 가지며, $l>0$일 때 $[k,l]$이 $[k,l-1]$과 이웃이고
$k>0$일 때 $[k-1,l]$과 이웃인 평면 그래프에서 출발한다고 하자. 각 정점에 픽셀
값을 붙인 다음, 픽셀 값이 같은 이웃 정점들을 거듭 하나로 합쳐 나간다. 그렇게
얻은 평면 그래프가 바로 앞 문단에서 말한 연결 영역의 그래프다.

|PlaneLisa(m,n,d,m0,m1,n0,n1,d0,d1,dir)|은 |Lisa|가 낸 디지털화에 대응하는
이 평면 그래프를 짓는다. 매개변수의 뜻은 앞서 |Lisa|를 설명하며 밝힌 그대로다.
정점은 많아야 $mn$개이며, |d|가 충분히 작아서 이웃한 픽셀이 같은 값을 가질 수
있게 되지 않는 한 그래프는 그냥 $m\times n$ 격자다. 거꾸로 |d|가 너무 작아도
그래프는 시시해진다---모든 것이 한 덩이로 합쳐져 버리기 때문이다.

@ 정점의 유틸리티 필드에는 원래 픽셀 값과, 그 영역의 맨 위·왼쪽 자리 및
맨 아래·오른쪽 자리를 $k*n+l$ 꼴의 수로 담는다:
$$\vbox{\halign{\hfil#\hfil&\quad#\hfil&\quad#\hfil\cr
원본&\GO/&뜻\cr
\noalign{\smallskip\hrule\smallskip}
|pixel_value|&|X.I|&(정점) 이 영역의 픽셀 값\cr
|first_pixel|&|Y.I|&(정점) 맨 위·왼쪽 자리 $k*n+l$\cr
|last_pixel|&|Z.I|&(정점) 맨 아래·오른쪽 자리\cr
|matrix_rows|&|UU.I|&(그래프) |m|\cr
|matrix_cols|&|VV.I|&(그래프) |n|\cr}}$$
|first_pixel|과 |last_pixel|을 낱낱의 좌표로 되풀려면 |n|을 알아야 하는데,
바로 그 값이 |g.VV.I|에 들어 있다. 그래서 그래프만 받아 든 쪽에서도
$k=|Y.I|/|g.VV.I|$, $l=|Y.I|\bmod|g.VV.I|$로 자리를 복원할 수 있다.

@<서브루틴@>=
func PlaneLisa(m, n, d, m0, m1, n0, n1, d0, d1 int64, dir string) (*gbgraph.Graph, error) {
	mx, err := Lisa(m, n, d, m0, m1, n0, n1, d0, d1, dir)
	if err != nil {
		return nil, err // |Lisa|가 이미 사정을 알렸다
	}
	a := mx.Pix
	m, n = mx.M, mx.N
	@<연결 영역 수 |regs|를 센다@>
	@<정점 |regs|개짜리 그래프를 세운다@>
	@<알맞은 간선들을 그래프에 넣는다@>
	return g, nil
}

@ 영역 수를 세는 알고리즘은 배열 원소 |a[k,l]|을 메모리에 놓인 차례대로,
곧 한 줄로 늘어선 것으로 여긴다. 그러면 $k>0$일 때 주어진 원소 |a[k,l]|
{\it 앞의 |n|개 원소\/}를 말할 수 있다. 그것들은
$$|a[k,l-1]|,\ \ldots,\ |a[k,0]|,\ |a[k-1,n-1]|,\ \ldots,\ |a[k-1,l]|$$
이다. 여기서 결정적인 점은, {\it 이 |n|개 원소가 서로 다른 |n|개의 열에
하나씩 놓인다\/}는 것이다. 그래서 길이가 |n|인 표 하나로 이들 전부를 갈무리할
수 있다.

@ 알고리즘은 배열을 오른쪽 아래에서 왼쪽 위로 훑으며 보조 표
$\langle f[0],\ldots,f[n-1]\rangle$을 다음 뜻으로 유지한다. 현재 자리
|[k,l]| 앞의 |n|개 원소 가운데 둘이 값이 같은 픽셀들의 사슬로 서로 이어져
있고 그 이음새가 현재 자리에서 |n|걸음보다 더 앞선 픽셀을 거치지 않는다면,
그 둘은 $f$ 배열에서 서로 엮여 있다. 더 정확히는, 열 $c_1$, \dots, $c_j$에
동치인 원소가 $j$개 있을 때
$$f[c_1]=c_2,\quad\ldots,\quad f[c_{j-1}]=c_j,\quad f[c_j]=c_j$$
가 된다. 여기서 감아 도는 차례로 볼 때 $c_1$이 ``마지막'' 열이고 $c_j$가
``첫'' 열이며, $f[c]\ne c$인 원소는 저마다 더 앞선 원소를 가리킨다.

$f$ 표의 주된 구실은 한 영역의 맨 위·왼쪽 픽셀을 가려내는 것이다. 자리
|[k,l]|에 이르러 $f[l]=l$이면서 $a[k-1,l]\ne a[k,l]$이면, 이 자리를 앞선
자리들과 이을 길이 전혀 없다는 뜻이므로 새 정점을 만든다.

@ 또 뒤에 올 알고리즘을 돕도록 |a| 행렬 자체를 고쳐 쓴다. 자리 |[k,l]|이
어떤 영역의 맨 위·왼쪽 픽셀이면 |a[k,l]|을 $-1-|a[k,l]|$로 바꾸고(음수라는
사실이 곧 표시가 된다), 아니면 같은 영역에 속하는 앞선 원소의 열 번호
$f[l]$로 바꾼다. 픽셀 값은 음수 쪽에 부호를 뒤집어 넣어 두었으므로 잃지
않는다.

@<연결 영역 수 |regs|를 센다@>=
f := make([]int64, n)
regs := int64(0)
apos := n*(m+1) - 1
for k := m; k >= 0; k-- {
	for l := n - 1; l >= 0; l-- {
		@<자리 |[k,l]|을 살펴 |a[apos]|와 영역 수를 갱신한다@>
		if k > 0 && l < n-1 && a[apos-n] == a[apos-n+1] {
			f[l+1] = l
		}
		f[l] = l
		apos--
	}
}

@ 첫째 행(|k==m|)은 거대 행렬 너머를 가리키는 파수꾼이라 |a[apos]|를 건드리지
않는다. |f[j]|를 |j|로 되돌리는 안쪽 고리 탓에 최악의 경우 $mn^2$ 시간이 들 수
있지만, 경로 압축까지 들일 만큼은 아니다.

@<자리 |[k,l]|을 살펴 |a[apos]|와 영역 수를 갱신한다@>=
if k < m {
	switch {
	case k > 0 && a[apos-n] == a[apos]:
		j := l
		for f[j] != j {
			j = f[j] // 이 영역의 첫 원소를 찾는다
		}
		f[j] = l // 새 첫 원소에 잇는다
		a[apos] = l
	case f[l] == l:
		a[apos] = -1 - a[apos]
		regs++ // 새 영역을 찾았다
	default:
		a[apos] = f[l]
	}
}

@ @<정점 |regs|개짜리 그래프를 세운다@>=
g := gbgraph.NewGraph(regs)
g.ID = "plane_" + mx.ID
g.UtilTypes = "ZZZIIIZZIIZZZZ"
g.UU.I = m // |matrix_rows|
g.VV.I = n // |matrix_cols|

@ 이번엔 왼쪽 위에서 오른쪽 아래로 다시 훑는다. 길이 |n|짜리 보조 벡터 |u|가
현재 자리 앞 |n|개 자리의 정점 포인터를 담아, 한 영역이 앞 영역과 이웃인지
알려 준다. \CEE/ 원본은 |unsigned long| 배열 |f|의 자리를 |Vertex**|로 재활용해
아꼈지만, \GO/에서는 그런 형 재활용이 없으므로 |u|를 새로 잡는다. 정점 이름은
0부터의 정수다.

@<알맞은 간선들을 그래프에 넣는다@>=
regs = 0
u := make([]*gbgraph.Vertex, n)
ap, aloc := int64(0), int64(0)
for k := int64(0); k < m; k++ {
	for l := int64(0); l < n; l++ {
		w := u[l] // 자리 |[k-1,l]|의 정점
		var v *gbgraph.Vertex
		@<자리 |[k,l]|의 정점 |v|를 정한다@>
		u[l] = v
		v.Z.I = aloc // |last_pixel|
		if k > 0 && v != w {
			adjac(g, v, w)
		}
		if l > 0 && v != u[l-1] {
			adjac(g, v, u[l-1])
		}
		ap++
		aloc++
	}
}

@ |a[ap]|이 음수이면 이 자리가 새 영역의 시작이므로 새 정점을 만들고, 아니면
같은 영역의 앞선 원소가 가리키는 열 |a[ap]|의 정점을 잇는다.

@<자리 |[k,l]|의 정점 |v|를 정한다@>=
if a[ap] < 0 {
	v = &g.Vertices[regs]
	v.Name = strconv.FormatInt(regs, 10)
	v.X.I = -a[ap] - 1 // |pixel_value|
	v.Y.I = aloc       // |first_pixel|
	regs++
} else {
	v = u[a[ap]]
}

@ |adjac|은 두 정점이 아직 이웃이 아니면 이웃으로 만든다. 두 곳에서 부르므로
따로 함수로 둔다. 중복을 알아내는 데 인접 리스트를 처음부터 훑으므로, Knuth의
말마따나 중복을 더 빨리 알아내는 방법을 쓰면 아마 속도가 붙을 것이다. 다만
영역의 차수가 대개 작아서 실제로는 문제가 되지 않는다.

@<서브루틴@>=
func adjac(g *gbgraph.Graph, u, v *gbgraph.Vertex) {
	for a := range u.AllArcs() {
		if a.Tip == v {
			return // 이미 이웃이다
		}
	}
	g.NewEdge(u, v, 1)
}

@* 이분 그래프.
모나리자에 바탕한 그래프의 더 단순한 갈래는, |m|개의 행과 |n|개의 열을
저마다 정점으로 삼고 해당 픽셀 값이 충분히 크거나 충분히 작을 때 행과 열을
잇는 것이다. 간선의 길이는 모두 1이다.

|BiLisa(m,n,m0,m1,n0,n1,thresh,c,dir)|은 |Lisa|가 낸 $m\times n$ 디지털화에
대응하는 이분 그래프를 짓는다. |m0|·|m1|·|n0|·|n1|은 앞서 설명한 대로
직사각형 부분 그림을 정한다. 문턱 |thresh|는 0과 65535 사이여야 한다. 행
|k|·열 |l|의 픽셀 값이 최댓값의 |thresh|$/65535$ 이상이면 정점 |k|와 |l|이
이웃이다. 다만 |c|가 참이면 규약이 뒤집혀, 픽셀 값이 그보다 {\sl작을\/} 때
이웃이다. 곧 |c|가 거짓이면 다 빈치 그림의 ``밝은'' 곳에서, 참이면 ``어두운''
곳에서 이웃이 생긴다. 정점은 |m+n|개이고 간선은 많아야 $m\times n$개다.

실제 픽셀 값은 $[0,65535]$로 눈금 맞춰 각 호의 유틸리티 필드 |B.I|에 새긴다.
그래서 |Lisa|를 |d=65535|로 부른다---그러면 이웃 판정이 픽셀 값과 |thresh|를
곧바로 견주는 일로 끝난다.

@<서브루틴@>=
func BiLisa(m, n, m0, m1, n0, n1, thresh int64, c bool, dir string) (*gbgraph.Graph, error) {
	mx, err := Lisa(m, n, 65535, m0, m1, n0, n1, 0, 0, dir)
	if err != nil {
		return nil, err // |Lisa|가 이미 사정을 알렸다
	}
	m, n = mx.M, mx.N
	m0, m1, n0, n1 = mx.M0, mx.M1, mx.N0, mx.N1
	@<정점 |m+n|개짜리 이분 그래프를 세운다@>
	@<알맞은 간선들을 이분 그래프에 넣는다@>
	return g, nil
}

@ |Lisa|를 |d=65535|로 불렀으므로 이웃 판정이 간단하다. 행 정점은 |"r0"|,
|"r1"|, \dots, 열 정점은 |"c0"|, |"c1"|, \dots 로 이름 붙인다.

@<정점 |m+n|개짜리 이분 그래프를 세운다@>=
g := gbgraph.NewGraph(m + n)
cflag := byte('0')
if c {
	cflag = '1'
}
g.ID = fmt.Sprintf("bi_lisa(%d,%d,%d,%d,%d,%d,%d,%c)",
	m, n, m0, m1, n0, n1, thresh, cflag)
g.SetUtilType(7, 'I') // 호의 |B.I| 필드를 켠다
g.MarkBipartite(m)
for k := int64(0); k < m; k++ {
	g.Vertices[k].Name = "r" + strconv.FormatInt(k, 10)
}
for l := int64(0); l < n; l++ {
	g.Vertices[m+l].Name = "c" + strconv.FormatInt(l, 10)
}

@ @<알맞은 간선들을 이분 그래프에 넣는다@>=
ap := int64(0)
for k := int64(0); k < m; k++ {
	uu := &g.Vertices[k]
	for l := int64(0); l < n; l++ {
		v := &g.Vertices[m+l]
		pix := mx.Pix[ap]
		adj := pix >= thresh
		if c {
			adj = pix < thresh
		}
		if adj {
			g.NewEdge(uu, v, 1)
			uu.Arcs.B.I = pix // 두 짝 호에 픽셀 값을 새긴다
			v.Arcs.B.I = pix
		}
		ap++
	}
}

@* 시험. \.{lisa.dat}이 |../data|에 있다고 보고, {\sc GB\_\,SAMPLE}이 내놓는
|sample.correct|와 대조한다. 여기서는 |PlaneLisa|가 |Lisa|의 픽셀 처리 전체를
end-to-end로 거치므로 가장 든든한 검사다.

@(gblisa_test.go@>=
package gblisa

import "testing"

const dataDir = "../data"

@ |plane_lisa(100,100,50,1,300,1,200,2975050,11900200)|은 정점 2452개·호
10814개짜리 그래프이고, 그 1294번 정점은 픽셀 값 11, |first_pixel| 2407,
|last_pixel| 2408이며, 네 호가 각각 정점 ``1295''(12, 2409, 2409),
``1256''(8, 2308, 2308), ``1293''(10, 2406, 2508), ``1255''(10, 2307, 2307)로
간다. 정점 이름·유틸리티 필드·호 차례까지 글자 그대로 맞아야 |Lisa|의 픽셀
처리와 |PlaneLisa|의 영역 이음, 그리고 |NewEdge|의 호 삽입 차례가 모두 \CEE/와
비트까지 같다는 뜻이다.

@(gblisa_test.go@>=
func TestPlaneLisa(t *testing.T) {
	g, err := PlaneLisa(100, 100, 50, 1, 300, 1, 200, 2975050, 11900200, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	@<그래프의 크기와 머리글을 확인한다@>
	@<정점 1294와 그 호들을 확인한다@>
}

@ @<그래프의 크기와 머리글을 확인한다@>=
if g.ID != "plane_lisa(100,100,50,1,300,1,200,2975050,11900200)" {
	t.Errorf("ID = %q", g.ID)
}
if g.N != 2452 || g.M != 10814 {
	t.Fatalf("N=%d M=%d, 원함 N=2452 M=10814", g.N, g.M)
}
if g.UtilTypes != "ZZZIIIZZIIZZZZ" {
	t.Errorf("UtilTypes = %q", g.UtilTypes)
}
if g.UU.I != 100 || g.VV.I != 100 {
	t.Errorf("matrix_rows,cols = %d,%d, 원함 100,100", g.UU.I, g.VV.I)
}

@ @<정점 1294와 그 호들을 확인한다@>=
v := &g.Vertices[1294]
if v.Name != "1294" || v.X.I != 11 || v.Y.I != 2407 || v.Z.I != 2408 {
	t.Fatalf("정점 1294 = %q[%d][%d][%d], 원함 1294[11][2407][2408]",
		v.Name, v.X.I, v.Y.I, v.Z.I)
}
type arc struct {
	name             string
	pix, first, last int64
}
var got []arc
for a := range v.AllArcs() {
	tip := a.Tip
	got = append(got, arc{tip.Name, tip.X.I, tip.Y.I, tip.Z.I})
}
want := []arc{
	{"1295", 12, 2409, 2409}, {"1256", 8, 2308, 2308},
	{"1293", 10, 2406, 2508}, {"1255", 10, 2307, 2307},
}
@<|got|과 |want|를 견준다@>

@ @<|got|과 |want|를 견준다@>=
if len(got) != len(want) {
	t.Fatalf("정점 1294의 호 %d개, 원함 %d개", len(got), len(want))
}
for i, a := range want {
	if got[i] != a {
		t.Errorf("호 %d = %v, 원함 %v", i, got[i], a)
	}
}

@ |BiLisa|는 |sample.correct|에 없으므로, 짜임새만 확인한다. 미소 영역의
$16\times32$ 그림에서 밝은 픽셀로 이분 그래프를 지으면 정점이 $16+32=48$개이고,
첫 부분 크기 |N1|이 16이며, 켜 둔 |B.I|에는 문턱 이상의 값이 담겨야 한다.

@(gblisa_test.go@>=
func TestBiLisa(t *testing.T) {
	g, err := BiLisa(0, 0, 94, 110, 97, 129, 30000, false, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 48 || g.N1() != 16 {
		t.Fatalf("N=%d N1=%d, 원함 N=48 N1=16", g.N, g.N1())
	}
	@<모든 호의 |B.I|가 문턱 이상인지 본다@>
}

@ @<모든 호의 |B.I|가 문턱 이상인지 본다@>=
for k := int64(0); k < g.N; k++ {
	for a := range g.Vertices[k].AllArcs() {
		if a.B.I < 30000 {
			t.Fatalf("호의 B.I = %d, 문턱 30000 미만", a.B.I)
		}
	}
}

@ 들어가며의 보기들을 그대로 돌려 본다. 기본값만 준 |Lisa|는 $360\times250$
행렬을 값 범위 $[0,255]$로 내며, 그 식별 문자열의 |d1|은
$255\times360\times250=22950000$이라야 한다. 백만 픽셀짜리 보기는 원래 자료를
$4\times4$로 복제한 것이므로 왼쪽 위 $4\times4$ 값이 모두 같아야 한다.

@(gblisa_test.go@>=
func TestDocumentedExamples(t *testing.T) {
	full, err := Lisa(0, 0, 0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if full.M != 360 || full.N != 250 || full.D != 255 {
		t.Fatalf("기본값 = %dx%d D=%d, 원함 360x250 D=255",
			full.M, full.N, full.D)
	}
	if full.ID != "lisa(360,250,255,0,360,0,250,0,22950000)" {
		t.Errorf("ID = %q", full.ID)
	}
	@<픽셀 값이 $[0,255]$ 안에 있는지 본다@>
	@<$4\times4$ 복제를 확인한다@>
}

@ @<픽셀 값이 $[0,255]$ 안에 있는지 본다@>=
for i, v := range full.Pix {
	if v < 0 || v > 255 {
		t.Fatalf("픽셀 %d = %d, 범위 밖", i, v)
	}
}

@ @<$4\times4$ 복제를 확인한다@>=
big, err := Lisa(1000, 1000, 255, 0, 250, 0, 250, 0, 0, dataDir)
if err != nil {
	t.Fatal(err)
}
if big.M != 1000 || big.N != 1000 {
	t.Fatalf("%dx%d, 원함 1000x1000", big.M, big.N)
}
for k := int64(0); k < 4; k++ {
	for l := int64(0); l < 4; l++ {
		if big.Pix[k*1000+l] != big.Pix[0] {
			t.Fatalf("왼쪽 위 4x4가 균일하지 않다: [%d,%d]", k, l)
		}
	}
}

@ 이름난 두 부분의 크기를 확인한다. |Smile|은 원본 주석대로 $16\times32$이고,
|Eyes|는 원본이 $20\times50$이라 적었으나 실제로는 $19\times49$다---구간이
오른쪽이 열려 있기 때문이다(들어가며의 단서를 보라).

@(gblisa_test.go@>=
func TestNamedRegions(t *testing.T) {
	for _, c := range []struct {
		name       string
		r          Region
		rows, cols int64
	}{
		{"Smile", Smile, 16, 32},
		{"Eyes", Eyes, 19, 49},
	} {
		mx, err := Lisa(0, 0, 0, c.r.M0, c.r.M1, c.r.N0, c.r.N1, 0, 0, dataDir)
		if err != nil {
			t.Fatal(err)
		}
		if mx.M != c.rows || mx.N != c.cols {
			t.Errorf("%s = %dx%d, 원함 %dx%d",
				c.name, mx.M, mx.N, c.rows, c.cols)
		}
		if mx.M != c.r.M1-c.r.M0 || mx.N != c.r.N1-c.r.N0 {
			t.Errorf("%s가 반열린 구간 약속과 어긋난다", c.name)
		}
	}
}

@* 찾아보기.
