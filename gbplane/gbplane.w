% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_plane.w를 Go로 이식한다.
@i ../gbtypes.w

\input kotexgweb
\def\title{GB\_\,PLANE}

@* 들어가며. 이 모듈은 직사각형 안에 무작위로 놓인 정점들로 무향 평면 그래프를
짓는 |Plane| 서브루틴과, \.{miles.dat}의 거리·좌표 자료에 바탕한 평면 그래프를
짓는 |PlaneMiles| 서브루틴을 담는다. 둘 다 주어진 점 집합의 델로네(Delaunay)
삼각분할을 계산하는 범용 |Delaunay| 서브루틴을 쓴다.

@ |Plane(n, xRange, yRange, extend, prob, seed)|는 정수 좌표가
$$\{\,(x,y)\mid 0\le x<|xRange|,\ 0\le y<|yRange|\,\}$$
에 고르게 흩어진 정점을 가진 평면 그래프를 짓는다. |xRange|·|yRange|는 많아야
$2^{14}=16384$이고, 0으로 주면 그 기본값이 쓰인다. |extend|가 참이면 정점이
|n+1|개가 되어 마지막 정점은 좌표 $(-1,-1)$인 무한원점 $\infty$다.

유한 정점 |n|개 가운데 좌표가 똑같은 것이 있을 수도 있다. 점의 밀도
|n/(xRange*yRange)|가 그리 작지 않을 때 특히 그렇다.

먼저 점들의 델로네 삼각분할을 짓고, 그 결과 그래프의 각 간선을 |prob|/65536의
확률로 버린다. 그러니 |prob|이 0이면 델로네 삼각분할이 통째로 나오고,
|prob|이 32768이면 델로네 간선의 절반쯤이 남는다. 살아남은 유한 간선의 길이는
두 점의 유클리드 거리에 $2^{10}$을 곱해 반올림한 값이다. |extend|이면 $\infty$와
볼록 껍질의 모든 점 사이 간선(버려지지 않으면 길이 |infty|$=2^{28}$)도
삼각분할에 든다.

@ |extend|가 참이고 |prob|이 0이면, 그래프는 정점 $n+1$개와 간선 $3(n-1)$개를
갖는다. 이것은 정점 $n+1$개짜리 평면 그래프가 가질 수 있는 {\it 최대\/}
간선 수다. 그런 경우 정점의 평균 차수는
$$6(n-1)/(n+1)$$
로 6보다 조금 작다. 따라서 |prob|이 32768이면 평균 차수가 대개 3 언저리가 된다.

난수에 기대는 다른 GraphBase 루틴들처럼, |seed|를 달리하면 다른 그래프가
나오되 그 방식은 기계에 무관해 여러 컴퓨터에서 똑같이 재현된다. |seed|는 0과
$2^{31}-1$ 사이면 무엇이든 좋다.

@ 유틸리티 필드 |x_coord|·|y_coord|·|z_coord|는 각각 |X.I|·|Y.I|·|Z.I|다.
|Plane|은 좌표를 여기에 두고, |z_coord|에는 |Delaunay|가 퇴화(점이 같거나
일직선·한 원 위에 있음)를 가를 때 쓸 유일한 ID 번호를 둔다. 문제가 생기면 |nil|과
|error|(곧 |gbgraph.PanicCode|)를 돌려준다.

@c
package gbplane

import (
	"fmt"
	"strconv"
	@#
	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbmiles"
)

const (
	infty    = 0x10000000 // ``무한'' 길이, $2^{28}$
	maxCoord = 16384      // 좌표의 상한, $2^{14}$
)

@<산술 서브루틴@>
@<행렬식 판정 서브루틴@>
@<Delaunay 자료 구조@>
@<Delaunay 서브루틴@>
@<Plane 서브루틴@>
@<PlaneMiles 서브루틴@>

@ 직사각형 안에 무작위로 놓인 정점들로 무향 평면 그래프를 짓는 서브루틴이다.
@<Plane 서브루틴@>=
func Plane(n, xRange, yRange int64, extend bool, prob, seed int64) (*gbgraph.Graph, error) {
	rng := gbflip.New(seed)
	if xRange > maxCoord || yRange > maxCoord {
		return nil, gbgraph.BadSpecs // 범위가 너무 크다
	}
	if n < 2 {
		return nil, gbgraph.VeryBadSpecs // |n|이 너무 작다
	}
	if xRange == 0 {
		xRange = maxCoord
	}
	if yRange == 0 {
		yRange = maxCoord
	}
	@<정점 |n|개를 고르게 흩어 그래프를 세운다@>
	@<델로네 삼각분할을 구해, 간선을 |prob|/65536로 버리며 유클리드 길이로 잇는다@>
	if extend {
		g.N++ // ``무한'' 정점을 정식 정점으로 만든다
	}
	return g, nil
}

@ |z_coord|에는 무작위 ID를 둔다. \CEE/처럼 |gb_next_rand()/n*n+k| 꼴이라 정점마다
다른 값이 되고, 좌표가 같은 점들의 순위를 유일하게 정한다. 무한 정점은 그래프가
|n+1|개를 담을 자리를 요구하는데, {\sc GB\_\,GRAPH}의 |NewGraph|가 늘 |extraN=4|개의
여분 정점을 더 잡으므로 자리는 넉넉하다.

@<정점 |n|개를 고르게 흩어 그래프를 세운다@>=
g := gbgraph.NewGraph(n)
g.ID = fmt.Sprintf("plane(%d,%d,%d,%d,%d,%d)",
	n, xRange, yRange, boolInt(extend), prob, seed)
g.UtilTypes = "ZZZIIIZZZZZZZZ"
for k := int64(0); k < n; k++ {
	v := &g.Vertices[k]
	v.X.I = rng.Unif(xRange)
	v.Y.I = rng.Unif(yRange)
	v.Z.I = (rng.Next()/n)*n + k
	v.Name = strconv.FormatInt(k, 10)
}
var infVertex *gbgraph.Vertex
if extend {
	infVertex = &g.Vertices[n]
	infVertex.Name = "INF"
	infVertex.X.I, infVertex.Y.I, infVertex.Z.I = -1, -1, -1
}

@ |Delaunay|가 부를 콜백은 유한 간선에 유클리드 길이를, 무한 간선에 |infty|를
매긴다. 간선마다 난수를 하나 뽑아 |prob| 문턱을 넘을 때만 잇는다 --- 이 뽑기가
버림 여부를 정하므로, \CEE/처럼 델로네 간선 차례대로 스트림을 소비한다.

@<델로네 삼각분할을 구해, 간선을 |prob|/65536로 버리며 유클리드 길이로 잇는다@>=
newEuclidEdge := func(u, v *gbgraph.Vertex) {
	if (rng.Next() >> 15) >= prob {
		if u != nil {
			if v != nil {
				dx := u.X.I - v.X.I
				dy := u.Y.I - v.Y.I
				g.NewEdge(u, v, intSqrt(dx*dx+dy*dy))
			} else if infVertex != nil {
				g.NewEdge(u, infVertex, infty)
			}
		} else if infVertex != nil {
			g.NewEdge(infVertex, v, infty)
		}
	}
}
Delaunay(g, newEuclidEdge)

@ 평면 위 정점 집합의 델로네 삼각분할은, 두 점 $u$, $v$를 지나
다른 정점을 안에 품지 않는 원이 있는 모든 선분 $uv$로 이루어진다. 곧 델로네
간선은 정점을 그 ``이웃''과 잇는다. |Delaunay|는 삼각분할을 그래프로 돌려주는
대신, 델로네 간선으로 이어진 정점 쌍 |u|, |v|마다 콜백 |f(u,v)|를 부른다. |u|나
|v|가 |nil|이면 무한원점 $\infty$를 뜻한다.

입력 정점의 좌표는 |X.I|·|Y.I|에, 유일한 ID는 |Z.I|에 있어야 하며, 좌표는 음이
아니고 $2^{14}$ 미만이어야 한다(호출자의 책임이다). \CEE/는 함수 포인터로 콜백을
받았지만, \GO/에서는 그냥 함수값 |f|로 받는다.

@ 먼저 정확한 결과를 위한 산술 서브루틴부터 다진다. |long|이 $2^{31}$ 미만이라고
본다. |intSqrt(x)|는 $\lfloor2^{10}\sqrt x+{1\over2}\rfloor$, 곧 음 아닌 정수
|x|의 제곱근에 $2^{10}$을 곱한 값에 가장 가까운 정수를 준다. 불변식
$m=\lfloor2^{2k-21}\rfloor$, $0<y=\lfloor2^{20-2k}x\rfloor-s^2+s\le q=2s$를
지키며 도는 것이 요령이다.

@* 델로네 삼각분할. 평면 위 정점 집합의 델로네 삼각분할이란, $u$와 $v$를
@^Delaunay [Delone], Boris Nikolaevich@>
지나면서 다른 정점을 하나도 품지 않는 원이 존재하는 모든 선분 $uv$의 모임이다.

같은 말을 달리 할 수도 있다. $uv$가 델로네 간선일 필요충분조건은 $u$와 $v$의
보로노이(Voronoi) 영역이 서로 맞닿아 있는 것이다. 정점 $u$의 보로노이 영역이란,
그 안의 모든 점이 다른 어느 정점보다 $u$에 가깝다는 성질을 지닌 다각형이다.
그런 뜻에서 델로네 간선은 정점을 그 ``이웃''과 잇는다고 말할 수 있다.

@ 앞 문단의 정의는 세 가지 비퇴화 조건을 전제한다: 두 정점이 같지 않고, 세
정점이 한 직선 위에 있지 않으며, 네 정점이 한 원 위에 있지 않다는 것이다. 이
조건이 만족되지 않으면 점들을 아주 살짝 흔들어 만족되게 만들 수 있다---실제로
아래 코드가 하는 일이 그것이다.

@ 델로네 삼각분할을 특징짓는 또 다른 방법은, 주어진 점들을 입체사영
(stereographic projection)으로 단위 구면에 옮겨 놓고 무슨 일이 벌어지는지
보는 것이다. 점 $(x,y)$는
$$\bigl(2x/(r^2+1),\ 2y/(r^2+1),\ (r^2-1)/(r^2+1)\bigr)$$
로 옮겨진다. 여기서 $r^2=x^2+y^2$이다.

이제 이 배치에 $(0,0,1)$을 더하자. $r$이 무한대로 갈 때 구면 위의 극한점이다.
그러면 원래 점들의 델로네 간선이 옮겨진 점들이 이루는 다면체의 변이 된다.
구면 위 $n+1$개 점의 3차원 볼록 껍질인 이 다면체에는 $(0,0,1)$에서 옮겨진
점들로 가는 변도 있는데, 그것들이 바로 원래 점들의 2차원 볼록 껍질에 대응한다.
비퇴화 가정 아래에서 이 다면체의 면은 모두 삼각형이다. 그래서 그 변들이
삼각분할을 이룬다고 말하는 것이다.

관련 이론 전체와 아래 알고리즘의 서술 및 정당성 증명은 저자의 논고 {\sl Axioms
@^Axioms and Hulls@>
and Hulls\/}, Lecture Notes in Computer Science {\bf606}(Springer-Verlag,
1992)에 자족적으로 실려 있다. 더 많은 참고문헌은 Franz Aurenhammer, {\sl ACM
@^Aurenhammer, Franz@>
Computing Surveys\/ \bf23\/}(1991), 345--405를 보라.

@ |Delaunay| 절차는 주어진 정점 집합의 델로네 삼각분할을 찾는다. 이 모듈이
평면 그래프를 만드는 알고리즘의 핵심 재료다. 주어질 정점들은 GraphBase 그래프
|g| 안에 있어야 하며, |g|의 간선이 있더라도 |Delaunay|는 그것을 무시한다.

각 정점의 좌표는 유틸리티 필드 |x_coord|와 |y_coord|에 있어야 하고, 음이 아니며
$2^{14}=16384$보다 작아야 한다. |z_coord|에는 정점마다 다른 유일한 ID 번호가
들어 있어야 한다. 알고리즘이 퇴화한 경우의 순위를 가르는 데 쓰기 때문이다.
(유의하라: 입력 자료에 대한 이 가정들은 부르는 쪽의 책임이다. |Delaunay|는
그것을 두 번 확인하지 않는다. 가정이 깨지면 파국적인 실패가 일어날 수 있다.)

@ |Delaunay|는 삼각분할을 그래프로 돌려주지 않는다. 대신 델로네 간선으로
이어지는 정점 쌍 |u|·|v|마다 매개변수로 받은 함수 |f(u,v)|를 불러, 답을
암묵적으로 알린다. |u|와 |v|는 정점을 가리키거나 |nil|인데, |nil|은 정점
``$\infty$''를 뜻한다. 앞서 말했듯 $\infty$와 주어진 점들의 볼록 껍질 위 모든
정점 사이에 간선이 놓인다. 무한 간선까지 포함한 이 그래프 전체가 평면 그래프다.

예컨대 무한원점을 거들떠보지 않으려면 이렇게 쓰면 된다:
$$\vbox{\halign{#\hfil\cr
|insFinite := func(u, v *gbgraph.Vertex) {|\cr
\quad|if u != nil && v != nil {|\cr
\qquad|g.NewEdge(u, v, 1)|\cr
\quad|}|\cr
|}|\cr}}$$
그러면 |Delaunay(g, insFinite)|가 유한 델로네 간선을 모두 길이 1로 |g|에
더한다.

@* 산술. 기하 알고리즘의 세계로 뛰어들기 전에, 올바른 결과를 보장하는 데
필요한 서브루틴 몇 개를 먼저 해치우며 자신감을 좀 붙이자. \CEE/ 원본은 |long|
정수가 $2^{31}$보다 작다고 가정했다.

첫째는
$$s=\lfloor2^{10}\sqrt x+{\textstyle{1\over2}}\rfloor$$
을 셈하는 루틴, 곧 음이 아닌 정수 |x|의 제곱근에 $2^{10}$을 곱한 값에 가장
가까운 정수를 구하는 루틴이다. |x>0|이면 이것은
$$2^{20}x-s\le s^2<2^{20}x+s$$
을 만족하는 유일한 정수다. 이어지는 루틴은 마술처럼 보이지만, 불변 관계를
따져 보면 신비는 사라진다.

@ 어떤 기하 술어를 제대로 셈하려면 다배정도 산술이 필요하다. 그런데 다행히
범용 큰수 서브루틴을 갖출 것까지는 없고, 특수 목적 루틴 하나면 넉넉하다.
|signTest(x1,x2,x3,y1,y2,y3)|은 내적
$$x_1y_1+x_2y_2+x_3y_3$$
과 부호가 같은 단배정도 정수를 셈한다. 단, $-2^{29}<x_1,x_2,x_3<2^{29}$이고
$0\le y_1,y_2,y_3<2^{29}$일 때다.

@<산술 서브루틴@>=
func boolInt(b bool) int64 {
	if b {
		return 1
	}
	return 0
}

@ @<산술 서브루틴@>=
func intSqrt(x int64) int64 {
	if x <= 0 {
		return 0
	}
	var y, m, k int64
	q := int64(2)
	for k, m = 25, 0x20000000; x < m; k, m = k-1, m>>2 {
	}
	if x >= m+m {
		y = 1
	} else {
		y = 0
	}
	for {
		@<|x|, |y|, |m|, |q|의 불변식을 지키며 |k|를 1 줄인다@>
		if k == 0 {
			break
		}
	}
	return q >> 1
}

@ @<|x|, |y|, |m|, |q|의 불변식을 지키며 |k|를 1 줄인다@>=
if x&m != 0 {
	y += y + 1
} else {
	y += y
}
m >>= 1
if x&m != 0 {
	y += y - q + 1
} else {
	y += y - q
}
q += q
if y > q {
	y -= q
	q += 2
} else if y <= 0 {
	q -= 2
	y += q
}
m >>= 1
k--

@ 어떤 기하 술어를 제대로 셈하려면 다배정도(multiple-precision) 산술이 필요한데,
범용 큰수 루틴은 필요 없고 |signTest| 하나면 족하다. 이것은
$-2^{29}<|x1|,|x2|,|x3|<2^{29}$이고 $0\le|y1|,|y2|,|y3|<2^{29}$일 때 내적
|x1*y1+x2*y2+x3*y3|과 같은 부호의 단정도 정수를 준다.

@<산술 서브루틴@>=
func signTest(x1, x2, x3, y1, y2, y3 int64) int64 {
	var s1, s2, s3 int64
	var a, b, c int64
	@<항들의 부호를 정한다@>
	@<답이 뻔하면 곧장 돌려주고, 아니면 |x3*y3|가 반대 부호가 되게 한다@>
	@<내적의 잉여 표현 |a|, |b|, |c|를 계산한다@>
	@<잉여 표현의 부호를 돌려준다@>
}

@ @<항들의 부호를 정한다@>=
if x1 == 0 || y1 == 0 {
	s1 = 0
} else if x1 > 0 {
	s1 = 1
} else {
	x1, s1 = -x1, -1
}
if x2 == 0 || y2 == 0 {
	s2 = 0
} else if x2 > 0 {
	s2 = 1
} else {
	x2, s2 = -x2, -1
}
if x3 == 0 || y3 == 0 {
	s3 = 0
} else if x3 > 0 {
	s3 = 1
} else {
	x3, s3 = -x3, -1
}

@ 한 항이 양수이고 다른 항이 음수인 때가 아니면 답은 뻔하다.

@<답이 뻔하면 곧장 돌려주고, 아니면 |x3*y3|가 반대 부호가 되게 한다@>=
if (s1 >= 0 && s2 >= 0 && s3 >= 0) || (s1 <= 0 && s2 <= 0 && s3 <= 0) {
	return s1 + s2 + s3
}
if s3 == 0 || s3 == s1 {
	s2, s3 = s3, s2
	x2, x3 = x3, x2
	y2, y3 = y3, y2
} else if s3 == s2 {
	s1, s3 = s3, s1
	x1, x3 = x3, x1
	y1, y3 = y3, y1
}

@ 잉여 표현 $2^{28}a+2^{14}b+c$를 우격다짐으로 구한다(모두 |-s3|이 곱해진
셈이다).

@<내적의 잉여 표현 |a|, |b|, |c|를 계산한다@>=
{
	var lx, rx, ly, ry int64
	lx, rx = x1/0x4000, x1%0x4000 // 아래 14비트를 떼낸다
	ly, ry = y1/0x4000, y1%0x4000
	a, b, c = lx*ly, lx*ry+ly*rx, rx*ry
	lx, rx = x2/0x4000, x2%0x4000
	ly, ry = y2/0x4000, y2%0x4000
	a, b, c = a+lx*ly, b+lx*ry+ly*rx, c+rx*ry
	lx, rx = x3/0x4000, x3%0x4000
	ly, ry = y3/0x4000, y3%0x4000
	a, b, c = a-lx*ly, b-lx*ry-ly*rx, c-rx*ry
}

@ $|c|<2^{29}$임을 쓴다. \CEE/의 두 |goto ez|는 |a==0|일 때로 가는데, |a!=0|
가지를 건너뛰어 마지막 |ez| 셈으로 떨어지게 하면 |goto| 없이 같아진다.

@<잉여 표현의 부호를 돌려준다@>=
if a != 0 {
	if a < 0 {
		a, b, c, s3 = -a, -b, -c, -s3
	}
	cZero := false
	for c < 0 {
		a--
		c += 0x10000000
		if a == 0 {
			cZero = true
			break
		}
	}
	if !cZero {
		if b >= 0 {
			return -s3 // |a>0 && b>=0 && c>=0|이면 답은 분명하다
		}
		b = -b
		a -= b / 0x4000
		if a > 0 {
			return -s3
		}
		if a <= -2 {
			return s3
		}
		return -s3 * ((a*0x4000-b%0x4000)*0x4000 + c)
	}
}
if b >= 0x8000 {
	return -s3
}
if b <= -0x8000 {
	return s3
}
return -s3 * (b*0x4000 + c)

@* 행렬식. |Delaunay|가 내리는 모든 판단은 두 기하 술어에 달려 있고, 그 둘은
어떤 행렬식이 양수인지 음수인지에 달려 있다.

첫째 술어 |ccw(u,v,w)|는 세 점 $(u,v,w)$가 반시계 방향으로 놓여 있을 때, 오직
그때만 참이다. 그 세 점을 지나는 유일한 원을 그리고 $u$에서 출발해 반시계
방향으로 그 원을 따라간다면 $w$보다 $v$를 먼저 만나게 된다는 뜻이다.

|ccw(u,v,w)|가 성립할 필요충분조건은 행렬식
$$\left\vert\matrix{x_u&y_u&1\cr x_v&y_v&1\cr x_w&y_w&1\cr}\right\vert
=\left\vert\matrix{x_u-x_w&y_u-y_w\cr x_v-x_w&y_v-y_w\cr}\right\vert$$
이 양수인 것이다. 이 값은 {\it 정확히\/} 셈해야 한다. 답이 0이면 세 점이
일직선 위에 있다는 뜻이므로 특별한 파훼 규칙을 써야 한다. 그 규칙은
까다로운데, {\sl Axioms and Hulls\/}의 이론에 따르면 까다로울 수밖에 없다.

@ 이 행렬식을 정수로 셈해도 넘침은 일어나지 않는다. 모든 $x$·$y$ 좌표가 0과
$2^{14}-1$ 사이라고 가정했기 때문이다. 사실 $2^{15}-1$까지 올려도 넘칠 위험은
없다. 그런데도 14비트로 묶어 둔 것은, 아래에서 더 복잡한 행렬식을 다룰 때
그 여유가 요긴하기 때문이다.

@<행렬식 판정 서브루틴@>=
func ccw(u, v, w *gbgraph.Vertex) bool {
	wx, wy := w.X.I, w.Y.I
	det := (u.X.I-wx)*(v.Y.I-wy) - (u.Y.I-wy)*(v.X.I-wx)
	if det == 0 {
		det = 1
		if u.Z.I > v.Z.I {
			u, v, det = v, u, -det
		}
		if v.Z.I > w.Z.I {
			v, w, det = w, v, -det
		}
		if u.Z.I > v.Z.I {
			u, v, det = v, u, -det
		}
		@<일직선인 |u|, |v|, |w|의 순위로 |det|을 정한다@>
	}
	return det > 0
}

@ @<일직선인 |u|, |v|, |w|의 순위로 |det|을 정한다@>=
if u.X.I > v.X.I || (u.X.I == v.X.I && (u.Y.I > v.Y.I ||
	(u.Y.I == v.Y.I && (w.X.I > u.X.I ||
		(w.X.I == u.X.I && w.Y.I >= u.Y.I))))) {
	det = -det
}

@ 다른 기하 술어 |incircle(t,u,v,w)|는, |ccw(u,v,w)|가 성립한다고 할 때, 점
|t|가 |u|·|v|·|w|를 지나는 원 바깥에 있으면 참이다. 이 술어는 우리를 좀 더
고생시킨다. 배정도가 두 배로 필요한 $4\times4$ 행렬식의 부호와 같기 때문이다:
$$\left\vert\matrix{
x_t&y_t&x_t^2+y_t^2&1\cr
x_u&y_u&x_u^2+y_u^2&1\cr
x_v&y_v&x_v^2+y_v^2&1\cr
x_w&y_w&x_w^2+y_w^2&1\cr}\right\vert$$
다행히 그 부호는 앞서 미리 마련해 둔 |signTest| 서브루틴으로 알아낼 수 있다.

@ 점들을 살짝 흔들면 언제나 비퇴화로 만들 수 있지만, 자세한 사정은 복잡하다.
{\sl Axioms and Hulls\/}가 설명하듯, 보조 함수 넷
$$\eqalign{
\\{hh}(t,u,v,w)&=(x_u-x_t)(y_v-y_w),\cr
\\{jj}(t,u,v,w)&=(x_u-x_v)^2+(y_u-y_w)^2-(x_t-x_v)^2-(y_t-y_w)^2\cr}$$
따위를 최대 넷까지 동원하는 열두 단계의 절차가 그 일을 해낸다.

@<행렬식 판정 서브루틴@>=
func incircle(t, u, v, w *gbgraph.Vertex) bool {
	wx, wy := w.X.I, w.Y.I
	tx, ty := t.X.I-wx, t.Y.I-wy
	ux, uy := u.X.I-wx, u.Y.I-wy
	vx, vy := v.X.I-wx, v.Y.I-wy
	det := signTest(tx*uy-ty*ux, ux*vy-uy*vx, vx*ty-vy*tx,
		vx*vx+vy*vy, tx*tx+ty*ty, ux*ux+uy*uy)
	if det == 0 {
		@<|(t,u,v,w)|를 ID 번호로 정렬한다@>
		@<incircle 퇴화를 없앤다@>
	}
	return det > 0
}

@ @<|(t,u,v,w)|를 ID 번호로 정렬한다@>=
det = 1
if t.Z.I > u.Z.I {
	t, u, det = u, t, -det
}
if v.Z.I > w.Z.I {
	v, w, det = w, v, -det
}
if t.Z.I > v.Z.I {
	t, v, det = v, t, -det
}
if u.Z.I > w.Z.I {
	u, w, det = w, u, -det
}
if u.Z.I > v.Z.I {
	u, v, det = v, u, -det
}

@ 점들을 살짝 흔들어 늘 비퇴화로 만든다. {\sl Axioms and Hulls\/}가 밝힌 12단계
순서를 따르며, 처음으로 0이 아닌 술어가 음수면 |det|을 뒤집는다. 술어
|ff|·|gg|·|hh|·|jj|는 부작용 없는 순수 함수라, 순서대로 모두 셈해 두고 첫 0 아닌
값을 봐도 결과가 같다.

@<incircle 퇴화를 없앤다@>=
for _, dd := range [...]int64{
	ff(t, u, v, w), gg(t, u, v, w),
	ff(u, t, w, v), gg(u, t, w, v),
	ff(v, w, t, u), gg(v, w, t, u),
	hh(t, u, v, w), jj(t, u, v, w),
	hh(v, t, u, w), jj(v, t, u, w),
	jj(t, w, u, v),
} {
	if dd != 0 {
		if dd < 0 {
			det = -det
		}
		break
	}
}

@ 퇴화를 없애는 데 쓰는 네 보조 함수다.

@<행렬식 판정 서브루틴@>=
func ff(t, u, v, w *gbgraph.Vertex) int64 {
	wx, wy := w.X.I, w.Y.I
	tx, ty := t.X.I-wx, t.Y.I-wy
	ux, uy := u.X.I-wx, u.Y.I-wy
	vx, vy := v.X.I-wx, v.Y.I-wy
	return signTest(ux-tx, vx-ux, tx-vx, vx*vx+vy*vy, tx*tx+ty*ty, ux*ux+uy*uy)
}

func gg(t, u, v, w *gbgraph.Vertex) int64 {
	wx, wy := w.X.I, w.Y.I
	tx, ty := t.X.I-wx, t.Y.I-wy
	ux, uy := u.X.I-wx, u.Y.I-wy
	vx, vy := v.X.I-wx, v.Y.I-wy
	return signTest(uy-ty, vy-uy, ty-vy, vx*vx+vy*vy, tx*tx+ty*ty, ux*ux+uy*uy)
}

func hh(t, u, v, w *gbgraph.Vertex) int64 {
	return (u.X.I - t.X.I) * (v.Y.I - w.Y.I)
}

func jj(t, u, v, w *gbgraph.Vertex) int64 {
	vx, wy := v.X.I, w.Y.I
	return (u.X.I-vx)*(u.X.I-vx) + (u.Y.I-wy)*(u.Y.I-wy) -
		(t.X.I-vx)*(t.X.I-vx) - (t.Y.I-wy)*(t.Y.I-wy)
}

@* 델로네 자료 구조. 현재 삼각분할의 각 간선은 반대 방향의 두 호(서로 {\sl짝
(mate)\/})로 나타낸다. |darc|는 |gbgraph.Arc|와 다른 것으로, 세 필드가 있다:
|vert|는 이 호가 가는 정점(또는 $\infty$면 |nil|), |next|는 같은 삼각형을 왼쪽에
둔 다음 호, |inst|는 삼각형이 바뀔 때 고칠 분기 노드다. |p.next.next.next==p|이고
|p.next.inst==p.inst|다.

@<Delaunay 자료 구조@>=
type darc struct {
	idx  int             // |arcBlock| 안의 자리; 짝을 찾는 데 쓴다
	vert *gbgraph.Vertex // 이 호가 가는 정점
	next *darc           // 같은 삼각형을 공유하는 다음 호
	inst *bnode          // 삼각형이 바뀔 때 고칠 지시
}

@ 마지막 요소는 이진 트리(사실은 dag)로 엮이는 {\sl분기 노드(branch node)\/}
|bnode|다. 새 정점 |w|가 어느 삼각형에 드는지, 뿌리에서 시작해 ``|w|가 $uv$의
오른쪽이면 $\alpha$로, 아니면 $\beta$로'' 꼴의 지시를 따라 내려가며 알아낸다.
끝 노드(|u==nil|)에 이르면 삼각형을 가리키는 호 |tri|를 얻는다. \CEE/는 |node.v|
필드를 |Vertex*|와 호 포인터로 겸용했지만, \GO/에서는 끝 노드용 |tri| 필드를
따로 둔다.

@<Delaunay 자료 구조@>=
type bnode struct {
	u, v *gbgraph.Vertex // 분기 노드의 두 정점 (|u==nil|이면 끝 노드)
	l, r *bnode          // |w|가 $uv$의 왼쪽·오른쪽일 때 갈 곳
	tri  *darc           // 끝 노드: 삼각형의 한 호
}

@ 호와 그 짝은 |arcBlock| 안에서 대칭으로 놓인다: |p|와 그 짝 |q|의 자리 번호
합은 늘 |m-1|이다($m$은 할당한 호의 총수 $6n-6$). 이 규약으로 호마다 포인터
하나를 아낀다. 분기 노드는 \GO/의 GC에 맡겨 그때그때 |new|로 잡는다.

@<Delaunay 자료 구조@>=
type dtri struct {
	arcBlock []darc // 모든 호
	maxIdx   int    // |arcBlock|의 마지막 자리, $6n-7$
	nextIdx  int    // 아직 안 쓴 첫 호
	root     bnode  // 삼각형을 찾기 시작하는 뿌리
}

func (dt *dtri) mate(a *darc) *darc { return &dt.arcBlock[dt.maxIdx-a.idx] }
func (dt *dtri) off(a *darc, k int) *darc { return &dt.arcBlock[a.idx+k] }
func (dt *dtri) terminal(a *darc) *bnode { return &bnode{tri: a} }

@ |flip|은 호 |c|의 왼쪽·오른쪽 두 삼각형을, 끝 노드 |xp|·|xpp|에 대응하는 두
삼각형으로 갈아 끼운다. |t|·|tp|는 실제로 안 쓰인다.

@<Delaunay 자료 구조@>=
func flip(c, d, e *darc, t, tp, tpp, p *gbgraph.Vertex, xp, xpp *bnode) {
	ep, cp := e.next, c.next
	cpp := cp.next
	e.next, c.next, cpp.next = c, cpp, e
	e.inst, c.inst, cpp.inst = xp, xp, xp
	c.vert = p
	d.next, ep.next, cp.next = ep, cp, d
	d.inst, ep.inst, cp.inst = xpp, xpp, xpp
	d.vert = tpp
}

@* Delaunay 서브루틴. 알고리즘은 한 번에 정점 하나씩 자료구조를 갱신한다. 새
정점은 늘 자기를 품던 삼각형의 세 꼭짓점과 이어지고, 가까운 다른 정점과도 이어질
수 있다. \CEE/처럼 작업 변수들을 함수 어귀에 한꺼번에 선언하고 |:=| 대신 |=|로
대입한다.

@<Delaunay 서브루틴@>=
func Delaunay(g *gbgraph.Graph, f func(u, v *gbgraph.Vertex)) {
	if g.N < 2 {
		return // 정점이 둘은 있어야 간선이 있다
	}
	dt := &dtri{}
	var a, aa, b, c, d, e *darc
	var p, q, r, s, t, tp, tpp, u, v *gbgraph.Vertex
	var x, y, yp, ypp *bnode
	@<자료 구조를 초기화한다@>
	for pi := int64(2); pi < g.N; pi++ {
		p = &g.Vertices[pi]
		@<|p|를 품은 삼각형의 경계 호 |a|를 찾는다@>
		@<|a|의 왼쪽 삼각형을 |p|를 둘러싼 세 삼각형으로 나눈다@>
		@<|p|를 둘러싼 삼각형들을 살피며 이웃을 뒤집는다@>
	}
	@<델로네 간선마다 |f(u,v)|를 부른다@>
}

@ 처음엔 두 정점 |u|, |v|와, 그 왼쪽·오른쪽으로 무한대까지 뻗은 두 ``삼각형''만
가진 자명한 삼각분할로 시작한다.

@<자료 구조를 초기화한다@>=
m := 6*g.N - 6
dt.arcBlock = make([]darc, m)
for i := range dt.arcBlock {
	dt.arcBlock[i].idx = i
}
dt.maxIdx = int(m) - 1
u = &g.Vertices[0]
v = &g.Vertices[1]
@<|u|, |v|, $\infty$로 두 ``삼각형''을 만든다@>

@ @<|u|, |v|, $\infty$로 두 ``삼각형''을 만든다@>=
dt.root.u, dt.root.v = u, v
a = &dt.arcBlock[dt.nextIdx]
x = dt.terminal(dt.off(a, 1))
dt.root.l = x
a.vert, a.next, a.inst = v, dt.off(a, 1), x
dt.off(a, 1).next, dt.off(a, 1).inst = dt.off(a, 2), x // |(a+1).vert=nil|, 곧 $\infty$
dt.off(a, 2).vert, dt.off(a, 2).next, dt.off(a, 2).inst = u, a, x
b = dt.mate(a)
x = dt.terminal(dt.off(b, -2))
dt.root.r = x
b.vert, b.next, b.inst = u, dt.off(b, -2), x
dt.off(b, -2).next, dt.off(b, -2).inst = dt.off(b, -1), x // |(b-2).vert=nil|
dt.off(b, -1).vert, dt.off(b, -1).next, dt.off(b, -1).inst = v, b, x
dt.nextIdx += 3

@ 분기 노드들이 삼각형 찾기 문제를 풀도록 짜였으므로, 뿌리에서 시작해 끝 노드에
이를 때까지 따라간다.

@<|p|를 품은 삼각형의 경계 호 |a|를 찾는다@>=
x = &dt.root
for {
	if ccw(x.u, x.v, p) {
		x = x.l
	} else {
		x = x.r
	}
	if x.u == nil {
		break // 끝 노드에 이르렀다
	}
}
a = x.tri

@ |p|를 품은 삼각형의 꼭짓점을 반시계 방향으로 |q|, |r|, |s|라 하자. 끝 노드
|x|를 고쳐, 앞으로 이 삼각형의 점을 세 부분 삼각형 가운데 하나에서 찾도록 한다.
|q|가 $\infty$면 삼각형 대신 ``쐐기(wedge)''를 쓴다.

@<|a|의 왼쪽 삼각형을 |p|를 둘러싼 세 삼각형으로 나눈다@>=
b = a.next
c = b.next
q, r, s = a.vert, b.vert, c.vert
@<끝 노드 |y|, |yp|, |ypp|와 그들을 가리키는 새 호들을 만든다@>
if q == nil {
	@<볼록 껍질을 갱신하는 지시를 짓는다@>
} else {
	x.u, x.v = r, p
	xp := new(bnode)
	xp.u, xp.v, xp.l, xp.r = q, p, yp, ypp // 지시 $x''$
	x.l = xp
	xp = new(bnode)
	xp.u, xp.v, xp.l, xp.r = s, p, y, yp // 지시 $x'$
	x.r = xp
}

@ |q=a.vert|가 |nil|일 수 있음이 유일한 미묘함이다. 끝 노드는 무한 삼각형의
알맞은 호를 가리켜야 한다.

@<끝 노드 |y|, |yp|, |ypp|와 그들을 가리키는 새 호들을 만든다@>=
na := &dt.arcBlock[dt.nextIdx]
yp = dt.terminal(a)
ypp = dt.terminal(na)
y = dt.terminal(c)
c.inst, a.inst, b.inst = y, yp, ypp
e = dt.mate(na)
a.next, b.next, c.next = e, dt.off(e, -1), dt.off(e, -2)
na.vert, na.next, na.inst = q, b, ypp
dt.off(na, 1).vert, dt.off(na, 1).next, dt.off(na, 1).inst = r, c, y
dt.off(na, 2).vert, dt.off(na, 2).next, dt.off(na, 2).inst = s, a, yp
e.vert, dt.off(e, -1).vert, dt.off(e, -2).vert = p, p, p
e.next, dt.off(e, -1).next, dt.off(e, -2).next = dt.off(na, 2), na, dt.off(na, 1)
e.inst, dt.off(e, -1).inst, dt.off(e, -2).inst = yp, ypp, y
dt.nextIdx += 3

@ 볼록 껍질 밖에는 삼각형 대신 쐐기가 있다. 새 점이 쐐기에 들면, 시계 방향으로
$st$, $tu$, \dots 변 밖에도 있는지 살펴, 그렇다면 볼록 껍질에서 점들을 덜어내며
쐐기를 갱신한다. 프로그램에서 옳음을 증명하기 가장 어려웠던 대목이다.

@<볼록 껍질을 갱신하는 지시를 짓는다@>=
xp := new(bnode)
x.u, x.v, x.l = r, p, ypp
xp.u, xp.v, xp.l, xp.r = s, p, y, yp
x.r = xp
aa = dt.mate(a)
d = aa.next
t = d.vert
for t != r && ccw(p, s, t) {
	@<쐐기를 하나 넘기고 삼각형을 뒤집는다@>
}
xp = dt.terminal(d.next)
x = d.inst
x.u, x.v, x.l, x.r = s, p, xp, yp
d.inst, d.next.inst, d.next.next.inst = xp, xp, xp
r = s // 이 |r| 값은 뒤따르는 탐색 단계를 줄여 준다

@ @<쐐기를 하나 넘기고 삼각형을 뒤집는다@>=
xpp := dt.terminal(d)
xp.r = d.inst
xp = d.inst
xp.u, xp.v, xp.l, xp.r = t, p, xpp, yp
flip(a, aa, d, s, nil, t, p, xpp, yp)
a = aa.next
aa = dt.mate(a)
d = aa.next
s, t = t, d.vert
yp.tri = a

@ 갱신은 |p|를 둘러싼 삼각형들을 돌며, 그중 어느 것도 |p|를 외접원 안에 품은
삼각형과 이웃하지 않도록 하며 끝난다(그런 삼각형은 더는 델로네가 아니다).

@<|p|를 둘러싼 삼각형들을 살피며 이웃을 뒤집는다@>=
for {
	d = dt.mate(c)
	e = d.next
	t, tp, tpp = d.vert, c.vert, e.vert
	if tpp != nil && incircle(tpp, tp, t, p) {
		@<삼각형 $tt''t'$이 더는 델로네가 아니니 뒤집는다@>
		c = e
	} else if tp == r {
		break
	} else {
		aa = dt.mate(c.next)
		c = aa.next
	}
}

@ @<삼각형 $tt''t'$이 더는 델로네가 아니니 뒤집는다@>=
xp := dt.terminal(e)
xpp := dt.terminal(d)
x = c.inst
x.u, x.v, x.l, x.r = tpp, p, xp, xpp
x = d.inst
x.u, x.v, x.l, x.r = tpp, p, xp, xpp
flip(c, d, e, t, tp, tpp, p, xp, xpp)

@ 삼각분할이 끝나면, 앞쪽에서 자라난 호와 뒤쪽의 그 짝을 짝지어 각 간선마다
콜백을 부른다.

@<델로네 간선마다 |f(u,v)|를 부른다@>=
for i := 0; i < dt.nextIdx; i++ {
	ai := &dt.arcBlock[i]
	f(ai.vert, dt.mate(ai).vert)
}

@* 마일리지 자료 이용. |PlaneMiles(n, northWeight, westWeight, popWeight, extend,
prob, seed, dir)|은 $\min(128,n)$개 정점을 가진 평면 그래프를 짓는다. 정점은
|Miles|가 내는 도시와 똑같고, 간선은 위도·경도를 평면에 투영해 만든 델로네
삼각분할에서 얻되 |prob|/65536로 버린다. 살아남은 간선의 길이는 두 도시 사이의
마일리지다.

|maxDistance|를 1로 주어 |Miles|가 정점만 있고 간선은 없는 그래프를 내게 한다.
정점의 좌표 필드 |X.I|·|Y.I|·|Z.I|는 |Delaunay|에 알맞게 채워져 있다. \CEE/는
간선 길이를 |miles_distance|(가장 최근 그래프의 전역 상태)로 읽었지만, \GO/에서는
|MilesRNGDist|가 함께 돌려주는 가지치기 전 거리 행렬에서 |Z.I|(도시 번호)로
찾는다.

@ \CEE/ 생성기들은 전역 |gb_flip| 스트림 하나를 공유한다. |PlaneMiles|는 |rng|
하나를 열어 |MilesRNGDist|에 넘겨 도시 선택에 쓰게 하고, 그 뒤 {\sl같은\/} |rng|를
델로네 간선 버리기에 이어 쓴다 --- 그래야 \CEE/와 난수열이 맞는다.

@<PlaneMiles 서브루틴@>=
func PlaneMiles(n, northWeight, westWeight, popWeight int64, extend bool,
	prob, seed int64, dir string) (*gbgraph.Graph, error) {
	rng := gbflip.New(seed)
	g, dist, err := gbmiles.MilesRNGDist(
		n, northWeight, westWeight, popWeight, 1, 0, seed, rng, dir)
	if err != nil {
		return nil, err // |MilesRNGDist|가 이미 사정을 알렸다
	}
	g.ID = fmt.Sprintf("plane_miles(%d,%d,%d,%d,%d,%d,%d)",
		n, northWeight, westWeight, popWeight, boolInt(extend), prob, seed)
	@<무한 정점을 마련하고 델로네 간선을 마일리지로 잇는다@>
	if extend {
		g.N++ // ``무한'' 정점을 정식 정점으로 만든다
	}
	return g, nil
}

@ @<무한 정점을 마련하고 델로네 간선을 마일리지로 잇는다@>=
var infVertex *gbgraph.Vertex
if extend {
	infVertex = &g.Vertices[g.N]
	infVertex.Name = "INF"
	infVertex.X.I, infVertex.Y.I, infVertex.Z.I = -1, -1, -1
}
newMileEdge := func(u, v *gbgraph.Vertex) {
	if (rng.Next() >> 15) >= prob {
		if u != nil {
			if v != nil {
				g.NewEdge(u, v, dist[gbmiles.MaxN*u.Z.I+v.Z.I])
			} else if infVertex != nil {
				g.NewEdge(u, infVertex, infty)
			}
		} else if infVertex != nil {
			g.NewEdge(infVertex, v, infty)
		}
	}
}
Delaunay(g, newMileEdge)

@* 시험. \.{miles.dat}이 \.{../data}에 있다고 보고, {\sc GB\_\,SAMPLE}이 내놓는
\.{sample.correct}와 대조한다. |PlaneMiles|는 |Delaunay|를 end-to-end로 거치므로
가장 든든한 검사다.

@(gbplane_test.go@>=
package gbplane

import "testing"

const dataDir = "../data"

@ |plane_miles(50,500,-100,1,1,40000,271818)|은 정점 51개·호 96개짜리
그래프이고, 그 14번 정점은 ``Saint Louis, MO''(인구 453085, 좌표 3293·1785,
도시 번호 24)이며, 세 호가 각각 Waterloo·South Bend·San Diego로 373·358·1875
마일씩 간다. 정점·좌표·호 차례·길이까지 글자 그대로 맞아야 |Miles|의 도시 선택,
|Delaunay|의 삼각분할, |gbflip| 난수열이 모두 \CEE/와 비트까지 같다는 뜻이다.

@(gbplane_test.go@>=
func TestPlaneMiles(t *testing.T) {
	g, err := PlaneMiles(50, 500, -100, 1, true, 40000, 271818, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	@<그래프의 크기와 머리글을 확인한다@>
	@<정점 14와 그 호들을 확인한다@>
}

@ @<그래프의 크기와 머리글을 확인한다@>=
if g.ID != "plane_miles(50,500,-100,1,1,40000,271818)" {
	t.Errorf("ID = %q", g.ID)
}
if g.N != 51 || g.M != 96 {
	t.Fatalf("N=%d M=%d, 원함 N=51 M=96", g.N, g.M)
}
if g.UtilTypes != "ZZIIIIZZZZZZZZ" {
	t.Errorf("UtilTypes = %q", g.UtilTypes)
}

@ @<정점 14와 그 호들을 확인한다@>=
v := &g.Vertices[14]
if v.Name != "Saint Louis, MO" || v.W.I != 453085 ||
	v.X.I != 3293 || v.Y.I != 1785 || v.Z.I != 24 {
	t.Fatalf("정점 14 = %q[%d][%d][%d][%d]", v.Name, v.W.I, v.X.I, v.Y.I, v.Z.I)
}
type arc struct {
	name string
	len  int64
}
var got []arc
for a := range v.AllArcs() {
	got = append(got, arc{a.Tip.Name, a.Len})
}
want := []arc{
	{"Waterloo, IA", 373}, {"South Bend, IN", 358}, {"San Diego, CA", 1875},
}
@<|got|과 |want|를 견준다@>

@ @<|got|과 |want|를 견준다@>=
if len(got) != len(want) {
	t.Fatalf("정점 14의 호 %d개, 원함 %d개", len(got), len(want))
}
for i, a := range want {
	if got[i] != a {
		t.Errorf("호 %d = %v, 원함 %v", i, got[i], a)
	}
}

@ |Plane|은 \.{sample.correct}에 없으므로 짜임새를 확인한다. |extend|이고 |prob=0|
이면 정점 |n+1|개짜리 평면 그래프가 가질 수 있는 최대 간선 수 $3(n-1)$개, 곧 호
$6(n-1)$개를 가진다.

@(gbplane_test.go@>=
func TestPlaneFullTriangulation(t *testing.T) {
	const n = 20
	g, err := Plane(n, 1000, 1000, true, 0, 12345)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != n+1 {
		t.Fatalf("N=%d, 원함 %d", g.N, n+1)
	}
	if g.M != 6*(n-1) {
		t.Fatalf("M=%d, 원함 %d (호 $6(n-1)$개)", g.M, 6*(n-1))
	}
	@<평균 차수가 6보다 조금 작은지 본다@>
}

@ 들어가며에서 밝힌 평균 차수 $6(n-1)/(n+1)$도 확인한다. 6보다 조금 작아야
한다.

@<평균 차수가 6보다 조금 작은지 본다@>=
avg := float64(g.M) / float64(g.N)
if want := 6 * float64(n-1) / float64(n+1); avg != want {
	t.Errorf("평균 차수 = %.4f, 원함 %.4f", avg, want)
}
if avg >= 6 {
	t.Errorf("평균 차수 %.4f는 6보다 작아야 한다", avg)
}

@ |prob=32768|이면 델로네 간선의 절반쯤이 버려지므로 평균 차수가 3 언저리가
되어야 한다. 통계적 주장이라 넉넉한 범위로 확인한다.

@(gbplane_test.go@>=
func TestPlaneHalfDiscarded(t *testing.T) {
	const n = 400
	g, err := Plane(n, 4000, 4000, true, 32768, 271828)
	if err != nil {
		t.Fatal(err)
	}
	full, err := Plane(n, 4000, 4000, true, 0, 271828)
	if err != nil {
		t.Fatal(err)
	}
	if r := float64(g.M) / float64(full.M); r < 0.4 || r > 0.6 {
		t.Errorf("남은 간선의 비율 = %.3f, 절반 언저리라야 한다", r)
	}
	if avg := float64(g.M) / float64(g.N); avg < 2.4 || avg > 3.6 {
		t.Errorf("평균 차수 = %.3f, 3 언저리라야 한다", avg)
	}
}

@* 찾아보기.
