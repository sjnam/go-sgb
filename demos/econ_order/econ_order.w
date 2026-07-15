% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 econ_order.w를 Go로 이식한다.
@i ../../types.w

\input kotexgweb
\def\title{ECON\_\,ORDER}
\def\<#1>{$\langle${\rm#1}$\rangle$}

@* 준삼각 순서. 이 시연 프로그램은 {\sc GB\_\,ECON}이 지은 자료 행렬을 받아,
순서의 앞쪽 부문은 다른 산업에 원자재를 대는 1차 생산자, 뒤쪽 부문은 산출을
주로 최종 소비자에게 넘기는 완제품 산업이 되도록 경제 부문을 재배열한다.

더 정확히는, 행이 부문의 산출, 열이 투입을 나타낸다고 할 때, 주대각선 아래
원소들의 합을 최소로 하는 행·열 순열을 찾는다(이 합이 0이면 행렬이 상삼각이 되어,
각 공급자가 앞서고 각 고객이 뒤따른다). 최소화 순열 찾기는 일반적으로
NP-완전이다. 여기서는 A. M. Gleason이 제안한 ``신중한 하강(cautious descent)''
--- 양의 이득 가운데 가장 작은 것을 고르는 --- 이라는 간단한 발견법을 쓴다.

@ {\sc GB\_\,ECON}에서 밝혔듯 |Econ(n,2,0,s,dir)|은 |n<=79|개 부문을 정점으로,
부문 |u|에서 |v|로의 산출 흐름을 호에 담은 그래프를 짓는다. 이 프로그램은 난수
씨앗 둘을 쓴다: |Econ|에 줄 |s|와 무작위 초기 순열에 줄 |t|. 매개변수 |r|은
같은 행렬에 시도할 서로 다른 시작 순열의 수다. 기본값은 |n=79|, |r=1|,
|s=t=0|이다. 명령줄 옵션 \.{-n}\<수>, \.{-r}\<수>, \.{-s}\<수>, \.{-t}\<수>와
\.{-v}(수다), \.{-V}(더 수다), \.{-g}(신중한 하강 대신 탐욕적 최급강하)을 준다.

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

@ 조건 $x_{jk}+x_{kj}=1$만으로 얻는 자명한 하한을 찍는다.
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

@ |mapping[k]|를 왼쪽 |mapping[j]| 자리로 옮기며 사잇값을 오른쪽으로 밀면
점수는 |del[mapping[k]][mapping[j]]| 따위만큼 준다. 가능한 수는 $(n-1)^2$개이고,
그 가운데 점수를 줄이되 (탐욕이 아니면) 가장 조금 줄이는 수를 찾는다.
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

@* 찾아보기.
