% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 assign_lisa.w를 Go로 이식한다.
@i ../../gbtypes.w

\input kotexgweb
\def\title{ASSIGN\_\,LISA}
\def\<#1>{$\langle${\rm#1}$\rangle$}

@* 배정 문제. 이 시연 프로그램은 {\sc GB\_\,LISA}가 지은 수의 행렬에서, 각 행과
각 열에서 많아야 하나씩 골라 그 합을 최대로 하는 짜임을 찾는다. 셈에 든 ``mem''
(메모리 참조) 수도 알려, 이 알고리즘을 다른 방법과 견줄 수 있게 한다.

행렬은 $m$행 $n$열이다. $m\le n$이면 각 행에서 하나씩, $m\ge n$이면 각 열에서
하나씩 고른다. 행렬의 수는 모나리자를 디지털화한 판의 밝기값(픽셀 값)이다.

@ {\sc GB\_\,LISA}가 밝혔듯 |Lisa(m,n,d,m0,m1,n0,n1,d0,d1,dir)|은 $[|m0|,|m1|)$행
$[|n0|,|n1|)$열의 직사각 조각으로 값이 $[0,d]$인 $m\times n$ 행렬을 짓는다. 사용
자는 아홉 매개변수 |(m,n,d,m0,m1,n0,n1,d0,d1)|을 명령줄에서 \.{m=}\<수> 따위로
줄 수 있다(등호 앞뒤에 빈칸을 두지 않는다). 그밖의 옵션:
$$\vbox{\halign{\.{#}\hfil\quad&#\hfil\cr
-s& 모나리자의 $16\times32$ ``미소''만 쓴다\cr
-e& 그의 $20\times50$ 두 눈만 쓴다\cr
-c& 흑백을 뒤집는다\cr
-p& 행렬과 해를 찍는다\cr
-P& 그래픽 출력용 PostScript 파일 \.{lisa.eps}를 만든다\cr
-h& $m=n$일 때만 쓰는 발견법을 쓴다\cr
-v, -V& 알고리즘의 성능을 (아주) 자세히 늘어놓는다\cr}}$$

@ 프로그램의 뼈대다. 행렬을 짓고, (필요하면) 찍고, 문제를 풀고, 다시 (필요하면)
찍은 뒤, 든 mem 수를 알린다.

@c
package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	@#
	"github.com/sjnam/go-sgb/gblisa"
)

const inf = int64(0x7fffffff) // 무한대(에 가까운 값)

@<solver 형@>
@<옵션을 훑는다@>
@<입력 행렬을 찍는다@>
@<배정 문제를 푼다@>
@<PostScript 출력@>

func main() {
	@<명령줄 옵션을 읽는다@>
	mx, err := gblisa.Lisa(m, n, d, m0, m1, n0, n1, d0, d1, dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "행렬을 만들 수 없습니다! (오류 코드 %v)\n", err)
		os.Exit(1)
	}
	complNote := ""
	if compl {
		complNote = ", complemented"
	}
	fmt.Printf("Assignment problem for %s%s\n", mx.ID, complNote)
	p := &solver{mtx: mx.Pix, m: mx.M, n: mx.N, d: mx.D,
		verbose: verbose, compl: compl, heur: heur && mx.M == mx.N}
	@<찍거나 PostScript로 낼 채비를 하고 문제를 푼다@>
	heurNote := ""
	if p.heur {
		heurNote = " with square-matrix heuristic"
	}
	fmt.Printf("Solved in %d mems%s.\n", p.mems, heurNote)
}

@ 입력 행렬 찍기와 입력 PostScript는 (있다면) 푸는 것보다 먼저 한다. mem 세기는
바로 그 뒤 |p.mems=0|에서 시작하므로, 찍기와 원본 자료 읽기는 세지 않는다.

@<찍거나 PostScript로 낼 채비를 하고 문제를 푼다@>=
if printing {
	p.displayInput()
}
if postScript {
	p.epsFile, err = os.Create("lisa.eps")
	if err != nil {
		fmt.Fprintln(os.Stderr, "`lisa.eps' 파일을 열 수 없습니다!")
		postScript = false
	} else {
		p.outputInputEPS()
	}
}
p.mems = 0
p.solve()
if printing {
	p.displaySolution()
}
if postScript {
	p.outputSolutionEPS()
	p.epsFile.Close()
}

@ 원본은 |mtx|·|mems|·중간 배열들을 전역에 두었지만, 우리는 |solver| 구조체에
담아 패키지 수준 가변 상태를 피한다. 배열의 뜻은 뒤에서 하나씩 밝힌다.

@<solver 형@>=
type solver struct {
	mtx        []int64 // 배정 문제의 입력 자료
	m, n, d    int64   // 행·열 수와 최대 픽셀 값
	mems       int64   // 센 메모리 참조의 수
	verbose    int     // 얼마나 수다스러운가(0, 1, 2)
	compl      bool    // 입력값을 뒤집을까?
	heur       bool    // 정사각 발견법을 쓸까?
	transposed bool    // 자료를 전치했는가?
	@<matching과 forest를 담는 배열들@>
	epsFile *os.File // PostScript 출력 파일
}

@ 행 |r|이 열 |c|와 짝지어지면 |colMate[r]=c|, |rowMate[c]=r|이다. 짝이 없으면
$-1$이다. 짝이 있으면서 경로 $(*)$로 닿는 열 |c|는 |parentRow[c]|가 forest 속
어느 행이고, 아니면 $-1$이다. forest의 행들은 |unchosenRow[0..t-1]|이다.

행 $k$에서 뺀 양은 |rowDec[k]|($\sigma_k$), 열 $l$에 더한 양은 |colInc[l]|
($\tau_{\,l}$)이다. |slack[l]|은 열 |l|에서 이제껏 본 가장 작은 가려지지 않은
원소이고, |slackRow[l]|은 그 최솟값이 난 행이다.

@<matching과 forest를 담는 배열들@>=
colMate     []int64 // 주어진 행과 짝지어진 열, 또는 $-1$
rowMate     []int64 // 주어진 열과 짝지어진 행, 또는 $-1$
parentRow   []int64 // 주어진 열의 짝의 조상, 또는 $-1$
unchosenRow []int64 // forest의 노드
rowDec      []int64 // $\sigma_k$, 주어진 행에서 뺀 양
colInc      []int64 // $\tau_{\,l}$, 주어진 열에 더한 양
slack       []int64 // 주어진 열에서 본 가장 작은 가려지지 않은 원소
slackRow    []int64 // 그 |slack|이 난 행

@ 명령줄 옵션은 손수 훑는다. 등호가 든 인자는 매개변수 대입, 그렇지 않은
인자는 깃발이다.

@<옵션을 훑는다@>=
func atoi(s string) int64 {
	v, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "잘못된 수: %q\n", s)
		os.Exit(2)
	}
	return v
}

@ @<명령줄 옵션을 읽는다@>=
var m, n, d, m0, m1, n0, n1, d0, d1 int64
var compl, heur, printing, postScript bool
var verbose int
dir := "/usr/local/sgb/data"
for _, arg := range os.Args[1:] {
	if k, val, ok := strings.Cut(arg, "="); ok {
		@<매개변수 대입 |k=val|을 처리한다@>
	} else {
		@<깃발 |arg|를 처리한다@>
	}
}

@ 자료 디렉터리는 |D=|로 준다(원본에는 없던, {\sc MILES\_\,SPAN} 방식의 편의다).

@<매개변수 대입 |k=val|을 처리한다@>=
switch k {
case "m":
	m = atoi(val)
case "n":
	n = atoi(val)
case "d":
	d = atoi(val)
case "m0":
	m0 = atoi(val)
case "m1":
	m1 = atoi(val)
case "n0":
	n0 = atoi(val)
case "n1":
	n1 = atoi(val)
case "d0":
	d0 = atoi(val)
case "d1":
	d1 = atoi(val)
case "D":
	dir = val
default:
	@<쓰임새를 알리고 끝낸다@>
}

@ \.{-s}(미소)와 \.{-e}(두 눈)는 |m0,m1,n0,n1|과 |d1|을 함께 정한다.

@<깃발 |arg|를 처리한다@>=
switch arg {
case "-s":
	m0, m1, n0, n1 = 94, 110, 97, 129 // 미소
	d1 = 100000                       // 픽셀을 더 밝게
case "-e":
	m0, m1, n0, n1 = 61, 80, 91, 140 // 두 눈
	d1 = 200000
case "-c":
	compl = true
case "-h":
	heur = true
case "-v":
	verbose = 1
case "-V":
	verbose = 2 // 굉장히 수다스럽게
case "-p":
	printing = true
case "-P":
	postScript = true
default:
	@<쓰임새를 알리고 끝낸다@>
}

@ @<쓰임새를 알리고 끝낸다@>=
fmt.Fprintf(os.Stderr,
	"쓰임새: %s [param=value] [-s] [-e] [-c] [-h] [-v] [-p] [-P]\n", os.Args[0])
os.Exit(2)

@ @<입력 행렬을 찍는다@>=
func (p *solver) displayInput() {
	for k := int64(0); k < p.m; k++ {
		for l := int64(0); l < p.n; l++ {
			v := p.mtx[k*p.n+l]
			if p.compl {
				v = p.d - v
			}
			fmt.Printf("% 4d", v)
		}
		fmt.Println()
	}
}

@* 알고리즘 개요. 배정 문제는 가중 이분 매칭의 고전이다: 이분 그래프에서 서로
겹치지 않는 간선을 골라 가중치 합을 최대로 하기. 알고리즘은 행렬이 정사각
($m=n$)이고 최대화 대신 최소화한다고 보면 세우기 쉽다. 그러면 문제는
$\sum_{k} a_{k\pi[k]}$을 최소로 하는 순열 $\pi$를 찾는 일이 된다.

핵심은 세 관찰이다: (a)~어느 행에 상수를 더해도 해는 안 바뀐다. (b)~어느 열에
상수를 더해도 안 바뀐다. (c)~모든 $a_{kl}\ge0$이고 $a_{k\pi[k]}=0$인 순열 $\pi$가
있으면 그 $\pi$가 답이다. 이 셋으로 늘 상수열 $(\sigma_k)$, $(\tau_l)$과 순열
$\pi$를 찾을 수 있다는 것이 Egerv\'ary와 K\H{o}nig의 정리로 보장된다.

@ mem 단위로 셈 시간을 어림한다({\sc MILES\_\,SPAN}에서 설명한 방식이다). 원본은
매크로 |o|·|oo|·|ooo|로 각각 한둘셋 mem을 셌는데, \GO/에는 매크로가 없으니 그
자리에 |p.mems|를 직접 늘린다.

@<배정 문제를 푼다@>=
func (p *solver) solve() {
	if p.m > p.n {
		@<행렬을 전치한다@>
	}
	@<중간 자료 구조를 마련한다@>
	if !p.compl {
		@<최대화를 최소화로 바꾸려 값을 뒤집는다@>
	}
	if p.heur {
		@<열마다 최솟값을 빼 0을 잔뜩 만든다@>
	}
	@<헝가리 알고리즘을 돌린다@>
}

@ 우리 알고리즘은 행과 열에 대칭이 아니어서 $m\le n$일 때만 맞다. 그래서
$m>n$이면 행렬을 전치한다.

@<행렬을 전치한다@>=
if p.verbose > 1 {
	fmt.Println("Temporarily transposing rows and columns...")
}
tmtx := make([]int64, p.m*p.n)
for k := int64(0); k < p.m; k++ {
	for l := int64(0); l < p.n; l++ {
		tmtx[l*p.m+k] = p.mtx[k*p.n+l]
	}
}
p.m, p.n = p.n, p.m
p.mtx = tmtx
p.transposed = true

@ @<중간 자료 구조를 마련한다@>=
p.colMate = make([]int64, p.m)
p.rowMate = make([]int64, p.n)
p.parentRow = make([]int64, p.n)
p.unchosenRow = make([]int64, p.m)
p.rowDec = make([]int64, p.m)
p.colInc = make([]int64, p.n)
p.slack = make([]int64, p.n)
p.slackRow = make([]int64, p.n)

@ 알고리즘은 최소화하지만 우리는 (|compl|이 아니면) 최대화하고 싶다. 그래서
|compl|이 거짓이면 각 값을 $d-a_{kl}$로 뒤집는다. 이 변환은 세지 않는다.

@<최대화를 최소화로 바꾸려 값을 뒤집는다@>=
for k := int64(0); k < p.m; k++ {
	for l := int64(0); l < p.n; l++ {
		p.mtx[k*p.n+l] = p.d - p.mtx[k*p.n+l]
	}
}

@ \.{-h} 발견법이다. $m=n$일 때, 각 열에서 최솟값을 빼 두면 시작부터 0이 많아진다.

@<열마다 최솟값을 빼 0을 잔뜩 만든다@>=
for l := int64(0); l < p.n; l++ {
	p.mems++ // |o,s=aa(0,l)|
	s := p.mtx[l]
	for k := int64(1); k < p.n; k++ {
		p.mems++ // |o,aa(k,l)|
		if v := p.mtx[k*p.n+l]; v < s {
			s = v
		}
	}
	if s != 0 {
		for k := int64(0); k < p.n; k++ {
			p.mems += 2 // |oo,aa(k,l)-=s|
			p.mtx[k*p.n+l] -= s
		}
	}
}
if p.verbose > 0 {
	fmt.Printf(" The heuristic has cost %d mems.\n", p.mems)
}

@* 알고리즘의 세부. 알고리즘은 단계로 나뉘고, 각 단계는 매칭된 원소 수를 하나
늘릴 수 있게 되면 끝난다. 첫 단계는 다르다: 행렬을 훑어 0을 찾아 되도록 많은
행·열을 짝짓고, 뒤 단계에서 쓸 표들을 채운다.

작업 변수 |k|·|l|·|j|·|s|·|t|·|q|는 여러 이름 있는 조각에 걸쳐 쓰이고, 돌파
(breakthru) 지점의 행·열을 고리 밖으로 실어 나른다. 그래서 \GO/의 관용을
살짝 벗어나 함수 어귀에 한꺼번에 선언하고 |:=| 대신 |=|로 대입한다 --- 이는
\CEE/의 |register long| 작업 집합을 그대로 옮긴 것이다.

@<배정 문제를 푼다@>=
func (p *solver) hungarian() {
	var k, l, j, s, t, q int64
	@<첫 단계를 한다@>
	if t != 0 {
		@<단계들을 돌며 매칭을 완성한다@>
	}
	@<해를 다시 확인한다@>
}

@ @<첫 단계를 한다@>=
t = 0 // forest는 비어서 시작한다
for l = 0; l < p.n; l++ {
	p.mems++ // |o,row_mate[l]=-1|
	p.rowMate[l] = -1
	p.mems++ // |o,parent_row[l]=-1|
	p.parentRow[l] = -1
	p.mems++ // |o,col_inc[l]=0|
	p.colInc[l] = 0
	p.mems++ // |o,slack[l]=INF|
	p.slack[l] = inf
}
for k = 0; k < p.m; k++ {
	@<행 |k|의 최솟값을 |rowDec[k]|에 넣고 짝을 찾아본다@>
}

@ 행 |k|의 최솟값 |s|를 구해 빼 두고($\sigma_k$), 그 값과 같으면서 아직 짝이
없는 열이 있으면 곧바로 짝짓는다. 없으면 |k|를 forest에 넣는다. 짧은회로 mem
세기가 중요하다: |s==aa(k,l)|이 참일 때만 |row_mate[l]|을 한 번 더 읽는다.

@<행 |k|의 최솟값을 |rowDec[k]|에 넣고 짝을 찾아본다@>=
p.mems++ // |o,s=aa(k,0)|
s = p.mtx[k*p.n]
for l = 1; l < p.n; l++ {
	p.mems++ // |o,aa(k,l)|
	if v := p.mtx[k*p.n+l]; v < s {
		s = v
	}
}
p.mems++ // |o,row_dec[k]=s|
p.rowDec[k] = s
matched := false
for l = 0; l < p.n; l++ {
	p.mems++ // |o,s==aa(k,l)|
	if s == p.mtx[k*p.n+l] {
		p.mems++ // |o,row_mate[l]<0|
		if p.rowMate[l] < 0 {
			@<열 |l|과 행 |k|를 짝짓는다@>
			matched = true
			break
		}
	}
}
if !matched {
	p.mems++ // |o,col_mate[k]=-1|
	p.colMate[k] = -1
	if p.verbose > 1 {
		fmt.Printf("  node %d: unmatched row %d\n", t, k)
	}
	p.mems++ // |o,unchosen_row[t++]=k|
	p.unchosenRow[t] = k
	t++
}

@ @<열 |l|과 행 |k|를 짝짓는다@>=
p.mems++ // |o,col_mate[k]=l|
p.colMate[k] = l
p.mems++ // |o,row_mate[l]=k|
p.rowMate[l] = k
if p.verbose > 1 {
	fmt.Printf(" matching col %d==row %d\n", l, k)
}

@ 알고리즘의 전체 얼개다. 단계는 많아야 $m$번, 각 단계는 $O(mn)$이라 통틀어
$O(m^2n)$이다. \CEE/의 |goto breakthru|는 이름표 붙은 |break search|로, |goto
done|은 고리 탈출로 옮긴다.

@<단계들을 돌며 매칭을 완성한다@>=
unmatched := t
for { // 각 단계
	if p.verbose > 0 {
		fmt.Printf(" After %d mems I've matched %d rows.\n", p.mems, p.m-t)
	}
	q = 0
search:
	for {
		for q < t {
			@<forest의 노드 |q|를 살핀다; 돌파면 break search@>
			q++
		}
		@<행렬에 새 0을 들인다; 돌파면 break search@>
	}
	@<행 |k|와 열 |l|을 짝지어 매칭을 갱신한다@>
	unmatched--
	if unmatched == 0 {
		break
	}
	@<다음 단계를 채비한다@>
}

@ 노드 |q|(행 |k|)를 살펴, 짝 없는 열에서 새 0을 찾으면 돌파한다. 아니면
|slack|을 갱신하며 forest를 키운다.

@<forest의 노드 |q|를 살핀다; 돌파면 break search@>=
p.mems++ // |o,k=unchosen_row[q]|
k = p.unchosenRow[q]
p.mems++ // |o,s=row_dec[k]|
s = p.rowDec[k]
for l = 0; l < p.n; l++ {
	p.mems++ // |o,slack[l]|
	if p.slack[l] != 0 {
		p.mems += 2 // |oo,del=aa(k,l)-s+col_inc[l]|
		del := p.mtx[k*p.n+l] - s + p.colInc[l]
		if del < p.slack[l] {
			@<|del|로 |slack[l]|을 낮추거나, 새 0이면 forest를 키운다@>
		}
	}
}

@ @<|del|로 |slack[l]|을 낮추거나, 새 0이면 forest를 키운다@>=
if del == 0 {
	p.mems++ // |o,row_mate[l]<0|
	if p.rowMate[l] < 0 {
		break search // 돌파!
	}
	p.mems++ // |o,slack[l]=0|
	p.slack[l] = 0
	p.mems++ // |o,parent_row[l]=k|
	p.parentRow[l] = k
	if p.verbose > 1 {
		fmt.Printf("  node %d: row %d==col %d--row %d\n", t, p.rowMate[l], l, k)
	}
	p.mems += 2 // |oo,unchosen_row[t++]=row_mate[l]|
	p.unchosenRow[t] = p.rowMate[l]
	t++
} else {
	p.mems++ // |o,slack[l]=del|
	p.slack[l] = del
	p.mems++ // |o,slack_row[l]=k|
	p.slackRow[l] = k
}

@ 돌파 지점에서 열 |l|은 짝이 없고 행 |k|는 forest 안에 있다. parent 링크를
따라가며 행과 열을 다시 짝지어, 짝 없던 행 $r^{(0)}$이 짝을 얻게 한다.

@<행 |k|와 열 |l|을 짝지어 매칭을 갱신한다@>=
if p.verbose > 0 {
	fmt.Printf(" Breakthrough at node %d of %d!\n", q, t)
}
for {
	p.mems++ // |o,j=col_mate[k]|
	j = p.colMate[k]
	p.mems++ // |o,col_mate[k]=l|
	p.colMate[k] = l
	p.mems++ // |o,row_mate[l]=k|
	p.rowMate[l] = k
	if p.verbose > 1 {
		fmt.Printf(" rematching col %d==row %d\n", l, k)
	}
	if j < 0 {
		break
	}
	p.mems++ // |o,k=parent_row[j]|
	k = p.parentRow[j]
	l = j
}

@ forest를 다 뒤졌는데도 돌파가 없으면, |slack|이 가장 작은 짝 없는 열이
길을 터 준다. |row_dec|와 |col_inc|를 고쳐 새 0을 들인다.

@<행렬에 새 0을 들인다; 돌파면 break search@>=
s = inf
for l = 0; l < p.n; l++ {
	p.mems++ // |o,slack[l]|
	if p.slack[l] != 0 && p.slack[l] < s {
		s = p.slack[l]
	}
}
for q = 0; q < t; q++ {
	p.mems += 3 // |ooo,row_dec[unchosen_row[q]]+=s|
	p.rowDec[p.unchosenRow[q]] += s
}
for l = 0; l < p.n; l++ {
	p.mems++ // |o,slack[l]|
	if p.slack[l] != 0 { // 열 |l|은 안 골렸다
		p.mems++ // |o,slack[l]-=s|
		p.slack[l] -= s
		if p.slack[l] == 0 {
			@<새 0을 살피고, 돌파면 |col_inc|를 갖춘 뒤 break search@>
		}
	} else {
		p.mems += 2 // |oo,col_inc[l]+=s|
		p.colInc[l] += s
	}
}

@ 가장 작은 |slack|을 가진 열이 여럿일 수 있다. 그 중 하나가 돌파를 이루면
기쁘지만, 다음 단계를 위해 |col_inc|를 유지해야 하므로 |l|에 대한 고리를 끝까지
돈 뒤에야 돌파한다.

@<새 0을 살피고, 돌파면 |col_inc|를 갖춘 뒤 break search@>=
p.mems++ // |o,k=slack_row[l]|
k = p.slackRow[l]
if p.verbose > 1 {
	fmt.Printf(" Decreasing uncovered elements by %d produces zero at [%d,%d]\n", s, k, l)
}
p.mems++ // |o,row_mate[l]<0|
if p.rowMate[l] < 0 { // 돌파!
	for j = l + 1; j < p.n; j++ {
		p.mems++ // |o,slack[j]==0|
		if p.slack[j] == 0 {
			p.mems += 2 // |oo,col_inc[j]+=s|
			p.colInc[j] += s
		}
	}
	break search
} else { // 돌파는 아니고, forest가 더 자란다
	p.mems++ // |o,parent_row[l]=k|
	p.parentRow[l] = k
	if p.verbose > 1 {
		fmt.Printf("  node %d: row %d==col %d--row %d\n", t, p.rowMate[l], l, k)
	}
	p.mems += 2 // |oo,unchosen_row[t++]=row_mate[l]|
	p.unchosenRow[t] = p.rowMate[l]
	t++
}

@ 한 단계가 짝짓기에 성공하지 못하면, forest를 다시 세워 다음 단계를 채비한다.

@<다음 단계를 채비한다@>=
t = 0
for l = 0; l < p.n; l++ {
	p.mems++ // |o,parent_row[l]=-1|
	p.parentRow[l] = -1
	p.mems++ // |o,slack[l]=INF|
	p.slack[l] = inf
}
for k = 0; k < p.m; k++ {
	p.mems++ // |o,col_mate[k]<0|
	if p.colMate[k] < 0 {
		if p.verbose > 1 {
			fmt.Printf("  node %d: unmatched row %d\n", t, k)
		}
		p.mems++ // |o,unchosen_row[t++]=k|
		p.unchosenRow[t] = k
		t++
	}
}

@ 우주선(cosmic ray)이 하드웨어를 망가뜨리지 않았다면 이 조각은 군더더기다.
그래도 배정이 참으로 최적으로 풀렸는지 확인해 두면 마음이 놓인다(mem은 세지
않는다). 어긋나면 ``있을 수 없는'' 일이므로 곧장 멈춘다.

@<해를 다시 확인한다@>=
for k := int64(0); k < p.m; k++ {
	for l := int64(0); l < p.n; l++ {
		if p.mtx[k*p.n+l] < p.rowDec[k]-p.colInc[l] {
			fmt.Fprintln(os.Stderr, "이런, 계산이 틀렸습니다!")
			os.Exit(6)
		}
	}
}
for k := int64(0); k < p.m; k++ {
	l := p.colMate[k]
	if l < 0 || p.mtx[k*p.n+l] != p.rowDec[k]-p.colInc[l] {
		fmt.Fprintln(os.Stderr, "이런, 망쳤습니다!")
		os.Exit(66)
	}
}
cnt := int64(0)
for l := int64(0); l < p.n; l++ {
	if p.colInc[l] != 0 {
		cnt++
	}
}
if cnt > p.m {
	fmt.Fprintln(os.Stderr, "이런, 열을 너무 많이 조정했습니다!")
	os.Exit(666)
}

@ @<헝가리 알고리즘을 돌린다@>=
p.hungarian()

@ 전치했으면 행과 열의 자리를 되돌려 찍는다.

@<배정 문제를 푼다@>=
func (p *solver) displaySolution() {
	fmt.Println("The following entries produce an optimum assignment:")
	for k := int64(0); k < p.m; k++ {
		if p.transposed {
			fmt.Printf(" [%d,%d]\n", p.colMate[k], k)
		} else {
			fmt.Printf(" [%d,%d]\n", k, p.colMate[k])
		}
	}
}

@* 캡슐화 PostScript. \.{-P} 옵션을 주면 \.{lisa.eps} 파일을 쓴다. 먼저 입력
자료를 최대 256 회색조의 픽셀 직사각형으로 ``칠하고'', 이어 해에 해당하는
픽셀을 검은 테로 두른다. 여기서는 기계 독립 출력이 필요 없으므로 부동소수점을
써도 안전하다. 입력 행렬 출력은 전치·뒤집기 전에 하므로 원래 |m|·|n|과 원자료를
쓴다.

@<PostScript 출력@>=
func (p *solver) outputInputEPS() {
	f := p.epsFile
	fmt.Fprintln(f, "%!PS-Adobe-3.0 EPSF-3.0")
	fmt.Fprintf(f, "%%%%BoundingBox: -1 -1 %d %d\n", p.n+1, p.m+1)
	fmt.Fprintf(f, "/buffer %d string def\n", p.n)
	fmt.Fprintf(f, "%d %d 8 [%d 0 0 -%d 0 %d]\n", p.n, p.m, p.n, p.m, p.m)
	fmt.Fprintln(f, "{currentfile buffer readhexstring pop} bind")
	fmt.Fprintf(f, "gsave %d %d scale image\n", p.n, p.m)
	for k := int64(0); k < p.m; k++ {
		@<행 |k|를 16진 문자열로 낸다@>
	}
	fmt.Fprintln(f, "grestore")
}

@ 한 줄에 많아야 64자(픽셀 32개)를 낸다.

@<행 |k|를 16진 문자열로 낸다@>=
conv := 255.0 / float64(p.d)
for l := int64(0); l < p.n; l++ {
	v := p.mtx[k*p.n+l]
	if p.compl {
		v = p.d - v
	}
	x := int64(conv * float64(v))
	fmt.Fprintf(p.epsFile, "%02x", min(x, 255))
	if l&0x1f == 0x1f {
		fmt.Fprintln(p.epsFile)
	}
}
if p.n&0x1f != 0 {
	fmt.Fprintln(p.epsFile)
}

@ 해 픽셀을 검은 테로 두른다. 전치했으면 자리를 되돌린다.

@<PostScript 출력@>=
func (p *solver) outputSolutionEPS() {
	f := p.epsFile
	fmt.Fprintln(f, "/bx {moveto 0 1 rlineto 1 0 rlineto 0 -1 rlineto closepath")
	fmt.Fprint(f, " gsave .3 setlinewidth 1 setgray clip stroke")
	fmt.Fprintln(f, " grestore stroke} bind def")
	fmt.Fprintln(f, " .1 setlinewidth")
	for k := int64(0); k < p.m; k++ {
		if p.transposed {
			fmt.Fprintf(f, " %d %d bx\n", k, p.n-1-p.colMate[k])
		} else {
			fmt.Fprintf(f, " %d %d bx\n", p.colMate[k], p.m-1-k)
		}
	}
}

@* 찾아보기.
