% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 econ_order.w를 Go로 이식한다.
@i ../../gbtypes.w

\input kotexgweb
\def\title{ECON\_\,ORDER}
\def\<#1>{$\langle${\rm#1}$\rangle$}

@* 준삼각 순서. 이 시연 프로그램은 {\sc GB\_\,ECON}이 지은 자료 행렬을 받아,
순서의 앞쪽 부문은 다른 산업에 원자재를 대는 1차 생산자, 뒤쪽 부문은 산출을
주로 최종 소비자에게 넘기는 완제품 산업이 되도록 경제 부문을 재배열한다.

더 정확히는, 행이 부문의 산출, 열이 투입을 나타낸다고 하자. 이 프로그램은
주대각선 아래 원소들의 합을 최소로 하는 행·열 순열을 찾으려 한다. (이 합이
$0$이면 행렬이 상삼각이 되어, 어느 부문의 공급자는 모두 그 부문보다 앞서고
고객은 모두 뒤따르게 된다.)

@ 최소화하는 순열을 찾는 일반 문제는 NP-완전이다. 그 안에는 아주 특별한
경우로 Karp의 고전적 논문[{\sl Complexity of Computer Computations\/} (Plenum
@^Karp, Richard Manning@>
Press, 1972), 85--103]에서 다룬 {\sc FEEDBACK ARC SET} 문제가 들어 있다. 그러나
알맞은 크기의 문제라면 실제로 잘 듣는 정교한 ``분기 절단(branch and cut)''
방법들이 개발되어 있다.

여기서는 간단한 발견적 내리막 방법으로 {\sl 지역적으로\/} 최적인 순열을 찾는다.
지역 최적이란, 어느 한 부문을 다른 자리로 옮기되 나머지 부문들의 상대적 차례는
그대로 두었을 때 대각선 아래 합이 줄어들지 않는다는 뜻이다. 무작위 순열에서
시작해 거듭 개선하되, 매 단계에서 {\sl 양의 이득 가운데 가장 작은 것\/}을
주는 개선을 고른다. 이 구현의 주된 동기 하나는 A.~M. Gleason이 {\sl AMS
@^Gleason, Andrew Mattei@>
Proceedings of Symposia in Applied Mathematics\/ \bf 10\/} (1958), 175--178에서
제안한 이 ``신중한 하강(cautious descent)'' 방법을 좀 더 겪어 보는 것이었다.
(아래 프로그램에 뒤따르는 논평을 보라.)

@ {\sc GB\_\,ECON}에서 밝혔듯 |Econ(n,2,0,s,dir)| 호출은 미국 경제의 부문들을
나타내는 정점 $n\le79$개짜리 그래프를 짓는데, 호 $u\to v$에는 부문 |u|에서
부문 |v|로 흐르는 산물의 양에 해당하는 수가 붙는다. $n<79$이면 관련된 상품들을
합쳐 기본 79부문에서 |n|부문을 얻는다. $s=0$이면 행 합이 고르게 되도록 합치고,
$s>0$이면 주어진 79잎 트리의 무작위 부분트리를 골라 합친다---그 ``무작위''는
$s$ 값으로 온전히 정해진다.

이 프로그램은 난수 씨앗 둘을 쓴다: |Econ|에 줄 |s|와 무작위 초기 순열에 줄
|t|다. 매개변수 |r|은 되풀이 횟수를 다스려, 같은 행렬에 서로 다른 시작 순열을
|r|개 시도하게 한다. $r>1$일 때는 앞선 최선을 개선한 해만 보여 준다.

기본값은 $n=79$, $r=1$, $s=t=0$이다. 명령줄 옵션 \.{-n}\<수>, \.{-r}\<수>,
\.{-s}\<수>, \.{-t}\<수>로 이를 바꾼다. 그밖에 \.{-v}(수다스럽게),
\.{-V}(아주 수다스럽게), \.{-g}(신중한 하강 대신 탐욕적 최급강하)도 있다.

@ 프로그램의 뼈대다.

@c
package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	@#
	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbecon"
)

const inf = int64(0x7fffffff) // 무한대(에 가까운 값)

@<타입 정의@>
@<함수@>

func main() {
	@<명령줄 옵션을 읽는다@>
	g, err := gbecon.Econ(n, 2, 0, s, dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "행렬을 만들 수 없습니다! (오류 %v)\n", err)
		os.Exit(1)
	}
	fmt.Printf("Ordering the sectors of %s, using seed %d:\n", g.ID, t)
	method := "Cautious"
	if greedy {
		method = "Steepest"
	}
	fmt.Printf(" (%s descent method)\n", method)
	sv := &solver{g: g, n: g.N, greedy: greedy, verbose: verbose, bestScore: inf}  
	@<행렬을 짓고 하한을 찍는다@>
	sv.rng = gbflip.New(t)
	for ; r > 0; r-- {
		@<하강으로 지역 최적을 찾는다@>
	}
}

@ 상태를 |solver| 구조체에 담아 패키지 수준 가변 상태를 피한다. |mat|은
입출력 계수 행렬, |del|은 그 반대칭 차 $\Delta_{jk}=M_{jk}-M_{kj}$이다.
@<타입...@>=
type solver struct {
	g                 *gbgraph.Graph
	n                 int64
	mat, del          [][]int64
	mapping           []int64 // 현재 순열
	score, steps      int64   // 현재 대각선 아래 합, 지금까지의 반복 수
	bestScore         int64   // 여태 본 가장 작은 대각선 아래 합
	bestD             int64   // 이 단계에서 본 가장 좋은 개선
	bestK, bestJ      int64   // |bestK|를 |bestJ|로 옮기면 |bestD|만큼 준다
	greedy            bool
	verbose           int
	rng               *gbflip.RNG
}

@ 최적 순열은 $\Delta$ 행렬만의 함수다($M_{jk}$와 $M_{kj}$에서 같은 상수를 빼도
문제가 안 바뀌므로). 호의 |flow|는 |A.I|에 있다.
@<행렬을 짓고 하한을 찍는다@>=
sv.mat = make([][]int64, sv.n)
sv.del = make([][]int64, sv.n)
sv.mapping = make([]int64, sv.n)
for i := int64(0); i < n; i++ {
	sv.mat[i] = make([]int64, sv.n)
	sv.del[i] = make([]int64, sv.n)
}
for i := int64(0); i < sv.n; i++ {
	for a := range sv.g.Vertices[i].AllArcs() {
		sv.mat[i][sv.g.Index(a.Tip)] = a.A.I // |flow|
	}
}
for j := int64(0); j < sv.n; j++ {
	for k := int64(0); k < sv.n; k++ {
		sv.del[j][k] = sv.mat[j][k] - sv.mat[k][j]
	}
}

@ 순서 문제의 최적해를 증명할 수 있을 만큼 강하게 만들 수 있는 자명하지 않은
하한은 선형계획법에 바탕해 얻을 수 있다. Gr\"otschel, J\"unger, Reinelt가
@^Gr\"otschel, Martin@>
@^J\"unger, Michael@>
@^Reinelt, Gerhard@>
보인 것이 그 예다[{\sl Operations Research\/ \bf 32\/} (1984), 1195--1220].

기본 착상은 이 문제를, 정수 변수 $x_{jk}\ge0$에 대해 $\sum M_{jk}x_{jk}$를 최소로
하되 서로 다른 첨자 세 쌍 $(i,j,k)$ 모두에 대해
$$x_{jk}+x_{kj}=1,\qquad x_{ik}\le x_{ij}+x_{jk}$$
라는 조건을 지키게 하는 일로 정식화하는 것이다. 이 조건들은 필요충분하다.
정수 제약을 풀면 하한이 나오고, 게다가
$$x_{14}+x_{25}+x_{36}+x_{42}+x_{43}+x_{51}+x_{53}+x_{61}+x_{62}\le7$$
같은 부등식을 더 얹을 수도 있다. 이런 부등식들에 얽힌 흥미로운 이야기는
P.~C. Fishburn이 개관해 두었다[{\sl Mathematical Social Sciences\/ \bf 23\/}
@^Fishburn, Peter Clingerman@>
(1992), 67--80].

그러나 우리 목표는 좀 더 소박하다---그저 가장 단순한 발견법 둘을 살펴보려는
것뿐이다. 그러니 조건 $x_{jk}+x_{kj}=1$만으로 얻는 자명한 하한으로 만족한다.
@<행렬을 짓고 하한을 찍는다@>=
var sum int64
for j := int64(1); j < sv.n; j++ {
	for k := int64(0); k < j; k++ {
		if sv.mat[j][k] <= sv.mat[k][j] {
			sum += sv.mat[j][k]
		} else {
			sum += sv.mat[k][j]
		}
	}
}
fmt.Printf("(The amount of feed-forward must be at least %d.)\n", sum)

@* 하강. 매 단계에서 |mapping|이 현재 순열이다: 행·열 |k|의 부문은
|g.Vertices[mapping[k]]|이다. 현재 대각선 아래 합은 |score|다.
@<함수@>=
func (s *solver) secName(k int64) string {
	return s.g.Vertices[s.mapping[k]].Name
}

@ @<하강으로 지역 최적을 찾는다@>=
@<mapping을 무작위 순열로 초기화한다@>
for {
	@<다음 수를 정한다; 지역 최적이면 멈춘다@>
	if sv.verbose > 0 {
		fmt.Printf("%8d after step %d\n", sv.score, sv.steps)
	} else if sv.steps%1000 == 0 && sv.steps > 0 {
		fmt.Print(".") // 진행 표시
	}
	@<다음 수를 둔다@>
}
@<지역 최소를 알리고, 나아졌으면 순서를 찍는다@>

@ @<mapping을 무작위 순열로 초기화한다@>=
sv.steps, sv.score = 0, 0
for k := int64(0); k < sv.n; k++ {
	j := sv.rng.Unif(k + 1)
	sv.mapping[k] = sv.mapping[j]
	sv.mapping[j] = k
}
for j := int64(1); j < sv.n; j++ {
	for k := int64(0); k < j; k++ {
		sv.score += sv.mat[sv.mapping[j]][sv.mapping[k]]
	}
}
if sv.verbose > 1 {
	fmt.Println("\nInitial permutation:")
	for k := int64(0); k < sv.n; k++ {
		fmt.Printf(" %s\n", sv.secName(k))
	}
}

@ 이를테면 |mapping[5]|를 |mapping[3]| 자리로 옮기고 앞서 있던 |mapping[3]|과
|mapping[4]|를 오른쪽으로 한 칸씩 밀면, 점수는
$$\hbox{|del[mapping[5]][mapping[3]]| $+$ |del[mapping[5]][mapping[4]]|}$$
만큼 준다. 마찬가지로 |mapping[5]|를 |mapping[7]| 자리로 옮기고 앞서 있던
|mapping[6]|과 |mapping[7]|을 왼쪽으로 한 칸씩 밀면, 점수는
$$\hbox{|del[mapping[6]][mapping[5]]| $+$ |del[mapping[7]][mapping[5]]|}$$
만큼 준다.

가능한 수는 $(n-1)^2$개다. 우리가 할 일은 점수를 줄이되 되도록 조금만 줄이는
수를 찾는 것이다(|greedy|이면 거꾸로 되도록 많이 줄이는 수를 찾는다).
@<다음 수를 정한다; 지역 최적이면 멈춘다@>=
if sv.greedy {
	sv.bestD = 0
} else {
	sv.bestD = inf
}
sv.bestK = -1
for k := int64(0); k < sv.n; k++ {
	var d int64
	for j := k - 1; j >= 0; j-- {
		d += sv.del[sv.mapping[k]][sv.mapping[j]]
		@<|d|가 |bestD|보다 나으면 |k|에서 |j|로의 수를 기록한다@>
	}
	d = 0
	for j := k + 1; j < sv.n; j++ {
		d += sv.del[sv.mapping[j]][sv.mapping[k]]
		@<|d|가 |bestD|보다 나으면 |k|에서 |j|로의 수를 기록한다@>
	}
}
if sv.bestK < 0 {
	break // 지역 최적에 이르렀다
}

@ @<|d|가 |bestD|보다 나으면 |k|에서 |j|로의 수를 기록한다@>=
if d > 0 && (sv.greedy && d > sv.bestD || !sv.greedy && d < sv.bestD) {
	sv.bestK, sv.bestJ, sv.bestD = k, j, d
}

@ 고른 수를 실제로 둔다: |bestK| 자리의 부문을 |bestJ| 자리로 옮기고 사잇값을
한 칸씩 민다.
@<다음 수를 둔다@>=
if sv.verbose > 1 {
	dir := "right"
	if sv.bestJ < sv.bestK {
		dir = "left"
	}
	fmt.Printf("Now move %s to the %s, past\n", sv.secName(sv.bestK), dir)
}
j := sv.bestK
k := sv.mapping[j]
for {
	if sv.bestJ < sv.bestK {
		sv.mapping[j] = sv.mapping[j-1]
		j--
	} else {
		sv.mapping[j] = sv.mapping[j+1]
		j++
	}
	@<옮기는 부문을 수다스럽게 알린다@>
	if j == sv.bestJ {
		break
	}
}
sv.mapping[j] = k
sv.score -= sv.bestD
sv.steps++

@ @<옮기는 부문을 수다스럽게 알린다@>=
if sv.verbose > 1 {
	var val int64
	if sv.bestJ < sv.bestK {
		val = sv.del[sv.mapping[j+1]][k]
	} else {
		val = sv.del[k][sv.mapping[j-1]]
	}
	fmt.Printf("    %s (%d)\n", sv.secName(j), val)
}

@ @<지역 최소를 알리고, 나아졌으면 순서를 찍는다@>=
label := "Local minimum feed-forward"
if sv.bestScore != inf {
	label = "Another local minimum"
}
plural := "s"
if sv.steps == 1 {
	plural = ""
}
fmt.Printf("\n%s is %d, found after %d step%s.\n",
	label, sv.score, sv.steps, plural)
if sv.verbose > 0 || sv.score < sv.bestScore {
	fmt.Println("The corresponding economic order is:")
	for k := int64(0); k < sv.n; k++ {
		fmt.Printf(" %s\n", sv.secName(k))
	}
	if sv.score < sv.bestScore {
		sv.bestScore = sv.score
	}
}

@ 명령줄 옵션은 {\sc ECON\_\,ORDER}의 붙여 쓰는 방식(\.{-n79})이라 손수 훑는다.
\.{-D}\<디렉터리>는 원본에 없던, 저장소 루트에서 실행하기 위한 편의다.

@<명령줄 옵션을 읽는다@>=
n := int64(79)
r := int64(1)
var s, t int64
greedy := false
verbose := 0
var dir string
num := func(a string) int64 {
	v, err := strconv.ParseInt(a, 10, 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "잘못된 수: %q\n", a)
		os.Exit(2)
	}
	return v
}
for _, arg := range os.Args[1:] {
	@<옵션 하나를 처리한다@>
}

@ @<옵션 하나를 처리한다@>=
switch {
case strings.HasPrefix(arg, "-n"):
	n = num(arg[2:])
case strings.HasPrefix(arg, "-r"):
	r = num(arg[2:])
case strings.HasPrefix(arg, "-s"):
	s = num(arg[2:])
case strings.HasPrefix(arg, "-t"):
	t = num(arg[2:])
case strings.HasPrefix(arg, "-D"):
	dir = arg[2:]
case arg == "-v":
	verbose = 1
case arg == "-V":
	verbose = 2
case arg == "-g":
	greedy = true
default:
	fmt.Fprintf(os.Stderr, "쓰임새: %s [-nN][-rN][-sN][-tN][-g][-v][-V][-DDIR]\n",
		os.Args[0])
	os.Exit(2)
}

@* 논평. 신중한 하강은 얼마나 잘 들을까? 이 응용에서는 아무래도 지나치게
신중하다. 이를테면 기본 설정으로 한참을 셈한 끝에 꽤 좋은 값 $457342$를 내놓기는
하는데, 무려 $39{,}418$걸음이나 걸은 뒤다! 그러고 나서 ($r>1$이면) 다시 해 보고는
$47{,}634$걸음 만에 $461584$에서 멈춘다.

같은 시작 순열로 탐욕 알고리즘을 돌리면 겨우 $93$걸음 만에 지역 최소 $457408$을
얻고, 이어 $83$걸음 만에 $460411$을 얻는다. 탐욕 알고리즘은 조금 못한 해를 찾는
편이지만 워낙 빨라서 훨씬 많은 실험을 해 볼 수 있다. 기본 설정으로 $20$번
시도하면 대각선 아래가 $456315$뿐인 순열을 찾아내고, $250$번쯤 더 하면 이
상계를 $456295$까지 낮춘다. (Gerhard Reinelt는 분기 절단으로 $456295$가 실제로
@^Reinelt, Gerhard@>
최적임을 증명했다.)

참고로 이 행렬의 자명한 하한은 $321656$이다. 그러니 최적값과 하한 사이에는
$40$퍼센트가 넘는 틈이 있다---조건 $x_{jk}+x_{kj}=1$만 쓴 하한이 얼마나 헐거운지
보여 준다.

@ {\sc FOOTBALL} 모듈이 보여 주는 {\sl 계층적 탐욕\/}(stratified greed) 방법은
보통 탐욕 알고리즘보다 잘해야 마땅하다. 그리고 계층적 탐욕을 모의 담금질
(simulated annealing)이나 유전적 번식 같은 다른 방법과도 견주어 보면 흥미로운
결과가 나올 법하다. 견줄 때는 정해진 수의 mem을 셈한 뒤 어느 방법이 가장 좋은
상계를 내놓는지를 보아야 한다({\sc MILES\_\,SPAN}을 보라). 어느 실행에서든 얻는
상계는 확률변수이므로, 방법마다 독립적인 시도를 여러 번 해 보아야 한다.

물음: 정점들을 두 부분집합으로 나누고 각 부분집합 위에 순열을 하나씩 고정해
두었다고 하자. 이 두 순열을 합치는 최적의 방법을 찾는 일---곧 주어진 두 순열을
연장하면서 대각선 아래 합이 가장 작은 순열을 찾는 일---은 NP-완전일까?

@* 찾아보기.
