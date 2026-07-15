% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_lisa.w를 Go로 이식한다.
@i ../types.w

\input kotexgweb
\def\title{GB\_\,LISA}

@* 들어가며. 이 모듈은 레오나르도 다 빈치의 {\sl 조콘다\/}(일명 모나리자)를
디지털화한 자료에 바탕한 자료 구조를 짓는다. 세 서브루틴이 있다. |Lisa|는
\.{lisa.dat}의 픽셀 자료로 직사각형 정수 행렬을 만들고, |PlaneLisa|는 그
행렬에서 무향 평면 그래프를 얽어내며, |BiLisa|는 무향 이분 그래프를 짓는다.
|Lisa|의 또 다른 쓰임새는 데모 {\sc ASSIGN\_\,LISA}에서 볼 수 있다.

\.{lisa.dat}의 자료는 360행 250열이다. 행은 위에서 아래로 0부터 359까지,
열은 왼쪽에서 오른쪽으로 0부터 249까지 번호가 매겨진다. 픽셀 값은 0(검정)에서
255(흰색)까지이고 그 사이는 회색조다.

@d smile @t\quad@> m0=94, m1=110, n0=97, n1=129 /* $16\times32$짜리 미소 */
@d eyes @t\quad@> m0=61, m1=80, n0=91, n1=140 /* $20\times50$짜리 두 눈 */

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

const DataInputDirectory = "/usr/local/sgb/data"

@<Matrix 형@>
@<Lisa 서브루틴@>
@<PlaneLisa 서브루틴@>
@<BiLisa 서브루틴@>

@ |Matrix|는 |Lisa|가 돌려주는 값이다. |Pix|는 길이 $|M|\times|N|$인 픽셀
행렬이고(행 |k|·열 |l|의 픽셀은 |Pix[k*N+l]|), 나머지 필드는 기본값이 채워진
뒤의 실제 매개변수와 원본의 |lisa_id|에 해당하는 식별 문자열 |ID|다.

@<Matrix 형@>=
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
|gbgraph.PanicCode|)를 돌려준다. \CEE/ 원본은 32비트 |long|이 넘칠까 봐
$\lfloor na/b\rfloor$을 조심스레 계산하는 |na_over_b| 서브루틴을 두었지만,
\GO/의 |int64|에서는 $d(D-|d0|)$가 넘칠 일이 없어(둘 다 $2^{31}$ 미만이라 곱해도
$2^{62}$ 안쪽) 그냥 나눗셈 한 번으로 족하다.

@<Lisa 서브루틴@>=
func Lisa(m, n, d, m0, m1, n0, n1, d0, d1 int64, dir string) (*Matrix, error) {
	if dir == "" {
		dir = DataInputDirectory
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
픽셀 행렬은 값이 같은 픽셀들의 연결 영역 집합을 이룬다(두 픽셀은 변을 맞대면
이웃이다). 이 영역들이 무향 그래프의 정점이고, 두 영역이 픽셀 변을 하나라도
공유하면 두 정점이 이웃이다. |PlaneLisa(m,n,d,m0,m1,n0,n1,d0,d1,dir)|은 |Lisa|가
낸 디지털화에 대응하는 이 평면 그래프를 짓는다.

정점의 유틸리티 필드에는 원래 픽셀 값(|pixel_value|, 우리의 |X.I|), 영역의
맨 위·왼쪽 자리(|first_pixel|, |Y.I|), 맨 아래·오른쪽 자리(|last_pixel|,
|Z.I|)를 $k*n+l$ 꼴로 담는다. 그래프 수준 필드 |matrix_rows|(|UU.I|)와
|matrix_cols|(|VV.I|)에는 |m|과 |n|을 담아, 나중에 자리를 좌표로 풀 때 쓴다.

@<PlaneLisa 서브루틴@>=
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

@ 영역 수를 세는 알고리즘은 배열 원소 |a[k,l]|을 메모리에 놓인 차례대로 훑는다.
오른쪽 아래에서 왼쪽 위로 나아가며 보조 표 $\langle f[0],\ldots,f[n-1]\rangle$을
유지한다. 값이 같아 연결된 원소들이 이 표에서 서로 이어지고, $f[c]\ne c$인
원소는 앞선 원소를 가리킨다. 자리 |[k,l]|에서 $f[l]=l$이면서 $a[k-1,l]\ne a[k,l]$
이면, 이 자리를 앞선 자리와 이을 길이 없으므로 새 정점을 만든다.

또 다음 알고리즘을 돕도록 |a| 행렬을 고친다. |[k,l]|이 영역의 맨 위·왼쪽
픽셀이면 |a[k,l]| 을 $-1-a[k,l]$로, 아니면 같은 영역의 앞선 원소의 열
$f[l]$로 바꾼다.

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
따로 함수로 둔다.

@<PlaneLisa 서브루틴@>=
func adjac(g *gbgraph.Graph, u, v *gbgraph.Vertex) {
	for a := range u.AllArcs() {
		if a.Tip == v {
			return // 이미 이웃이다
		}
	}
	g.NewEdge(u, v, 1)
}

@* 이분 그래프.
더 단순한 집안은 |m|행과 |n|열을 저마다 정점으로 삼고, 픽셀 값이 충분히 크거나
작으면 행과 열을 잇는 것이다. |BiLisa(m,n,m0,m1,n0,n1,thresh,c,dir)|은 |Lisa|가
낸 $m\times n$ 디지털화에 대응하는 이분 그래프를 짓는다. 문턱 |thresh|는 0과
65535 사이여야 한다. 행 |k|·열 |l|의 픽셀 값이 최댓값의 |thresh|/65535 이상이면
정점 |k|와 |l|이 이웃이다. 다만 |c|가 참이면 규약이 뒤집혀, 픽셀 값이 그보다
{\sl작을\/} 때 이웃이다. 곧 |c|가 거짓이면 그림의 ``밝은'' 곳에서, 참이면
``어두운'' 곳에서 이웃이 생긴다.

실제 픽셀 값은 $[0,65535]$로 눈금 맞춰 각 호의 유틸리티 필드 |B.I|에 새긴다.

@<BiLisa 서브루틴@>=
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

@* 찾아보기.
