% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 assign_lisa.w를 Go로 이식한다.
@i ../../gbtypes.w

\input kotexgweb
\def\title{ASSIGN\_\,LISA}
\def\<#1>{$\langle${\rm#1}$\rangle$}
\def\dash{\mathrel-\joinrel\joinrel\mathrel-} % 이웃한 정점
\def\ddash{\mathrel{\above.2ex\hbox to1.1em{}}}  % 짝지어진 정점

@* 배정 문제. 이 시연 프로그램은 {\sc GB\_\,LISA}가 지은 수의 행렬에서, 각 행과
각 열에서 많아야 하나씩 골라 그 합을 최대로 하는 짜임을 찾는다. 셈에 든 ``mem''
(메모리 참조) 수도 알려, 이 알고리즘을 다른 방법과 견줄 수 있게 한다.

행렬은 $m$행 $n$열이다. $m\le n$이면 각 행에서 하나씩, $m\ge n$이면 각 열에서
하나씩 고른다. 행렬의 수는 모나리자를 디지털화한 판의 밝기값(픽셀 값)이다.

물론 저자도 다빈치의 그림에서 행마다 하나 열마다 하나씩 ``도드라진 곳''을
집어내는 일이 미술 감상에 무슨 쓸모가 있다고 우기지는 않는다. 그래도 이
프로그램에는 가르치는 값어치가 있어 보인다. 픽셀 값과 회색의 짙고 옅음이
맞물려 있는 덕분에, 배정 문제의 이 특별한 사례에서는 밑에 깔린 자료를 눈으로
볼 수 있기 때문이다. 그냥 숫자만 늘어놓은 행렬은 알아보기가 훨씬 어렵다.
게다가 예술 작품의 픽셀은 마구잡이가 아니어서, 실제 응용에서 만나는 자료의
``유기적인'' 성질과 닮은 데가 있을지도 모른다.

이 프로그램은 원하면 캡슐화 PostScript 파일도 낼 수 있어, 해를 반색조(halftone)
음영을 넣은 그림으로 띄워 볼 수 있다.

@ {\sc GB\_\,LISA}가 밝혔듯 |Lisa(m,n,d,m0,m1,n0,n1,d0,d1,dir)|은 디지털화한
모나리자의 직사각 조각을 바탕으로, 값이 $0$과 $d$ 사이(양끝 포함)인 $m\times n$
정수 행렬을 짓는다. 그 조각은 $[|m0|,|m1|)$행 $[|n0|,|n1|)$열이다. 날자료는
$0$과 $255$ 사이인 픽셀 값 $MN$개의 합 $D$로 얻는데, 여기서 $M=|m1|-|m0|$이고
$N=|n1|-|n0|$이다. 그 합은 $D\le|d0|$이면 $0$으로, $D\ge|d1|$이면 $d$로, 그
사이면 선형으로 $[0,d]$에 옮겨진다. 매개변수 가운데 $0$인 것이 있으면 기본값
$|m1|=360$, $|n1|=250$, $m=M$, $n=N$, $d=255$, $|d1|=255MN$이 대신 들어간다.

@ 사용자는 아홉 매개변수 |(m,n,d,m0,m1,n0,n1,d0,d1)|을 명령줄에서 \.{m=}\<수>
따위로 줄 수 있다(등호 앞뒤에 빈칸을 두지 않는다). 그밖의 옵션:
$$\vbox{\halign{\.{#}\hfil\quad&#\hfil\cr
-s& 모나리자의 $16\times32$ ``미소''만 쓴다\cr
-e& 그의 $19\times49$ 두 눈만 쓴다\cr
-c& 흑백을 뒤집는다\cr
-p& 행렬과 해를 찍는다\cr
-P& 그래픽 출력용 PostScript 파일 \.{lisa.eps}를 만든다\cr
-h& $m=n$일 때만 쓰는 발견법을 쓴다\cr
-v, -V& 알고리즘의 성능을 (아주) 자세히 늘어놓는다\cr}}$$
(원본은 두 눈이 $20\times50$이라 적었으나, |m0=61|, |m1=80|, |n0=91|, |n1=140|
이므로 실제로는 $19\times49$다. {\sc GB\_\,LISA}에서 이미 짚은 대로다.)

@ \.{-s}와 \.{-e}는 조각만 정하는 것이 아니라 |d1|도 함께 낮춘다. 이유는
이렇다. 기본값 $|d1|=255MN$은 그 조각이 낼 수 있는 가장 큰 합이니, 자료를
있는 그대로---곧 픽셀 값 그대로---내놓는다. 그런데 모나리자의 입가나 눈가는
그림 전체로 보면 어두운 편이라 위쪽 눈금이 남아돈다. |d1|을 미소는 100000,
두 눈은 200000으로 낮추면(기본값은 각각 $255\cdot512=130560$과
$255\cdot931=237405$이다) 그 좁은 범위가 $[0,d]$ 전체에 펼쳐져, 밝은 쪽이
포화되는 대신 명암 대비가 살아난다.

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

@ 문제를 푸는 데 드는 것은 모두 |solver| 구조체에 담는다. 뒤쪽 절반을 차지하는
배열들의 뜻은 ``알고리즘의 세부'' 장에서 하나씩 밝힌다.

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

@ \.{-s}(미소)와 \.{-e}(두 눈)는 |m0,m1,n0,n1|과 |d1|을 함께 정한다. 원본은
|smile|·|eyes| 매크로로 네 값을 한꺼번에 대입했는데, \GO/에는 매크로가 없으니
{\sc GB\_\,LISA}가 내놓는 |Region| 값을 그대로 가져다 쓴다.

@<깃발 |arg|를 처리한다@>=
switch arg {
case "-s":
	r := gblisa.Smile
	m0, m1, n0, n1 = r.M0, r.M1, r.N0, r.N1
	d1 = 100000 // 픽셀을 더 밝게
case "-e":
	r := gblisa.Eyes
	m0, m1, n0, n1 = r.M0, r.M1, r.N0, r.N1
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
겹치지 않는 간선을 골라 가중치 합을 최대로 하기. 여기서는 완전 이분 그래프,
곧 가중치가 $m\times n$ 행렬로 주어지는 경우만 다룬다.

알고리즘은 행렬이 정사각($m=n$)이라 보고 최대화 대신 최소화한다고 하면 세우기가
가장 쉽다. 그러면 배정 문제는 $\{0,\ldots,n-1\}$의 순열 $\pi[0]\ldots\pi[n-1]$
가운데 $\sum_{k=0}^{n-1}a_{k\pi[k]}$을 가장 작게 하는 것을 찾는 일이 된다.
여기서 $A=(a_{kl})$은 $0\le k,l<n$에 대해 주어진 수 $a_{kl}$의 행렬이다. 아래
알고리즘은 $a_{kl}$이 아무 실수라도 돌아가지만, 우리 구현에서는 행렬 원소가
정수라고 본다.

@ 배정 문제에 다가가는 한 가지 길은 간단한 관찰 셋을 하는 것이다. (a)~행렬의
어느 행에 상수를 더해도 해 $\pi[0]\ldots\pi[n-1]$은 바뀌지 않는다. (b)~어느
열에 상수를 더해도 바뀌지 않는다. (c)~모든 $k$와 $l$에 대해 $a_{kl}\ge0$이고,
모든 $k$에 대해 $a_{k\pi[k]}=0$인 순열 $\pi[0]\ldots\pi[n-1]$이 있으면, 그
순열이 배정 문제를 푼다.

놀라운 사실은 이 관찰 셋으로 정말 충분하다는 것이다. 다시 말해, 늘 상수열
$(\sigma_0,\ldots,\sigma_{n-1})$과 $(\tau_0,\ldots,\tau_{n-1})$, 그리고 순열
$\pi[0]\ldots\pi[n-1]$이 있어
$$\vbox{\halign{$#$,\hfil&\quad #\hfil\cr
a_{kl}-\sigma_k+\tau_{\,l}\ge0& $0\le k<n$이고 $0\le l<n$일 때\cr
a_{k\pi[k]}-\sigma_k+\tau_{\pi[k]}=0& $0\le k<n$일 때\cr}}$$
가 성립한다.

@ 방금 말한 놀라운 사실을 증명하려면 {\sl 가중치 없는\/} 이분 매칭의 이론부터
되짚어야 한다. 임의의 $m\times n$ 행렬 $A=(a_{kl})$은, $a_{kl}=0$일 때
$r_k\dash c_l$이라 하기로 하면, 정점 $(r_0,\ldots,r_{m-1})$과
$(c_0,\ldots,c_{n-1})$ 위의 이분 그래프를 정한다. 곧 이 이분 그래프의 간선은
행렬의 $0$들이다. $A$의 두 $0$이 서로 다른 행, 서로 다른 열에 있으면 {\sl
독립\/}이라 한다. 대응하는 두 간선이 정점을 함께 쓰지 않는다는 뜻이다. 따라서
서로 독립인 $0$들의 모임은 서로 겹치지 않는 간선들의 모임, 곧 행과 열 사이의
{\sl 매칭\/}에 대응한다.

헝가리 수학자 Egerv\'ary와 K\H{o}nig은 [{\sl Matematikai \'es Fizikai Lapok\/
\bf38} (1931), 16--28, 116--119] 행렬에서 독립인 $0$의 최대 개수가 모든 $0$을
``덮는'' 데 드는 행과 열의 최소 개수와 같음을 증명했다.
@^Egerv\'ary, Eugen (= Jen\H{o})@>
@:Konig}{K\H{o}nig, D\'enes@>
곧 독립인 $0$을 $p$개는 찾을 수 있지만 $p+1$개는 찾을 수 없다면, 줄 $p$개를 잘
골라 행렬의 모든 $0$이 그 가운데 적어도 하나에 들게 할 수 있다. 여기서
``줄''이란 행이거나 열이다.

@ 그들의 증명은 구성적이어서 쓸모 있는 계산 절차로 이어진다. 행렬의 독립인 $0$
$p$개가 주어졌을 때, $a_{kl}$이 그 특별한 $0$ 가운데 하나이면
$r_k\ddash c_l$ 또는 $c_l\ddash r_k$라 쓰고 $r_k$가 $c_l$과 짝지어졌다고 하자.
특별하지 않은 $0$에 대해서는 계속 $r_k\dash c_l$ 또는 $c_l\dash r_k$라 쓴다.
그러면 특별한 $0$ $p$개가 다음과 같이 줄 $p$개를 정한다. 열 $c$가 뽑히는 것은
$$r^{(0)}\dash c^{(1)}\ddash r^{(1)}\dash c^{(2)}\ddash\cdots
  \dash c^{(q)}\ddash r^{(q)}\eqno(*)$$
꼴의 경로로 닿을 수 있을 때, 그리고 그때뿐이다. 여기서 $r^{(0)}$은 짝이 없고,
$q\ge1$이며, $c=c^{(q)}$이다. 행 $r$이 뽑히는 것은 뽑히지 않은 열과 짝지어졌을
때, 그리고 그때뿐이다. 이렇게 하면 뽑히는 줄은 정확히 $p$개다.

@ 이제 독립인 $0$을 $p+1$개 찾는 길이 없는 한, 뽑힌 줄들이 모든 $0$을 덮는다는
것을 보일 수 있다. $c\ddash r$이면 $c$나 $r$ 가운데 하나는 뽑혔다. $c\dash r$
이면 다음 가운데 한 경우다. (1)~$r$과 $c$가 둘 다 짝이 없으면, 둘을 서로
짝지어 $p$를 늘릴 수 있다. (2)~$r$은 짝이 없고 $c\ddash r'$이면 $c$가 뽑혔으니
그 $0$은 덮였다. (3)~$r$이 $c'\ne c$와 짝지어졌으면 $r$이 뽑혔거나 $c'$이
뽑혔다. 뒤엣것이면
$$r^{(0)}\dash c^{(1)}\ddash r^{(1)}\dash c^{(2)}\ddash\cdots\ddash
       r^{(q-1)}\dash c'\ddash r\dash c$$
꼴의 경로가 있다($r^{(0)}$은 짝이 없고 $q\ge1$이다). 이때 $c$에 짝이 있으면
$c$는 뽑힌 것이고, 짝이 없으면 매칭을
$$r^{(0)}\ddash c^{(1)}\dash r^{(1)}\ddash c^{(2)}\dash\cdots\dash
     r^{(q-1)}\ddash c'\dash r\ddash c$$
로 고쳐 $p$를 늘릴 수 있다. 어느 쪽이든 주장한 대로다.

@ 이제 $A$가 $n\times n$짜리 {\sl 음이 아닌\/} 행렬이라 하자. Egerv\'ary와
K\H{o}nig의 절차로 $A$의 $0$들을 최소 개수 $p$개의 줄로 덮는다. $p<n$이면 아직
덮이지 않은 원소가 있고, 그런 원소는 양수다. 덮이지 않은 값 가운데 가장 작은
것을 $\delta>0$이라 하자. 그러면 뽑히지 {\sl 않은\/} 행마다 $\delta$를 빼고,
뽑힌 열마다 $\delta$를 더할 수 있다. 알짜 효과는 덮이지 않은 원소에서는
$\delta$가 빠지고, 두 번 덮인 원소에는 $\delta$가 더해지며, 한 번 덮인 원소는
그대로인 것이다.

이 변환은 새 $0$을 하나 만들면서도, 앞선 행렬의 독립인 $0$ $p$개를 그대로
남긴다(그것들은 저마다 꼭 한 번만 덮였기 때문이다). 같은 $p$개로 Egerv\'ary와
K\H{o}nig의 구성을 되풀이하면, $p$가 더는 최대가 아니거나, 아니면 적어도 열
하나가 더 뽑힌다. 새 $0$인 $r\dash c$가 놓인 행 $r$은 뽑히지 않았으므로 짝이
없거나 이미 뽑힌 열과 짝지어져 있기 때문이다. 그러니 이 과정을 되풀이하면
끝내는 $p$를 늘릴 수 있고, 마침내 $p=n$에 이른다. 이것이 배정 문제를 풀며,
앞서 내세운 놀라운 주장을 증명한다.

@ 주어진 행렬 $A$가 $m$행 $n>m$열이면, $m\le k<n$이고 $0\le l<n$인 자리에
$a_{kl}=0$을 채워 억지로 정사각으로 늘릴 수 있다. 그러면 위 구성이 그대로
쓰인다. 하지만 그렇게 늘리느라 시간을 버릴 것 없이, 원래의 $m\times n$ 행렬에
알고리즘을 돌려 독립인 $0$을 $m$개 찾을 때까지만 하면 된다.

까닭은 Egerv\'ary--K\H{o}nig 구성에서 짝지어진 정점의 집합이 늘 단조롭게
자라기 때문이다. 어느 단계에서 짝지어진 열은 그 뒤로도 계속 짝을 가진다---짝이
바뀔 수는 있어도. $A$ 아래에 덧댄 가짜 행 $n-m$개는 늘 덮개의 일부로 뽑히므로,
가짜 원소가 $0$이 아니게 되는 것은 어떤 덮개에 든 열에서뿐이다. 그런 열은 어떤
매칭의 일부이므로 마지막 매칭의 일부이기도 하다. 그러니 절차가 도는 동안
가짜 원소가 $0$이 아니게 되는 열은 많아야 $m$개다. 가짜 행 $n-m$개 안에서는
독립인 $0$을 늘 $n-m$개 찾을 수 있으니, 가짜 원소를 드러내 놓고 다룰 까닭이
없다.

@ 알고리즘을 설명할 때는 $A$의 행과 열에 상수를 더하고 뺀다고 말하는 편이
편했다. 그러나 그 덧셈 뺄셈을 다 하려면 시간이 꽤 든다. 그래서 우리는 방법이
요구하는 조정을 하는 {\sl 척\/}만 하고, 벡터 두 개
$(\sigma_0,\ldots,\sigma_{m-1})$과 $(\tau_0,\ldots,\tau_{n-1})$로 그것을 넌지시
나타내겠다. 그러면 행렬 원소의 현재 값은 $a_{kl}$이 아니라
$a_{kl}-\sigma_k+\tau_{\,l}$이고, ``$0$''이란 $a_{kl}=\sigma_k-\tau_{\,l}$인
자리를 뜻한다.

처음에는 $0\le l<n$에 대해 $\tau_{\,l}=0$으로, $0\le k<m$에 대해
$\sigma_k=\min\{a_{k0},\ldots,a_{k(n-1)}\}$으로 둔다. $m=n$이면 모든 $k$와 $l$에
대해 $a_{kl}$에서 $\min\{a_{0l},\ldots,a_{(n-1)l}\}$을 빼서 열마다도 $0$이
하나씩 있게 만들 수 있다. 이 처음 한 번의 조정은 $\tau$를 거치지 않고 원래
행렬 원소에 바로 해 두는 편이 편하다. 그것이 값어치 있는 일인지는 사용자가
\.{-h} 옵션을 켜고 꺼 가며 견주어 보면 알 수 있다.

@ mem 단위로 셈 시간을 어림한다({\sc MILES\_\,SPAN}에서 설명한 방식이다). 원본은
매크로 |o|·|oo|·|ooo|로 각각 한둘셋 mem을 셌는데, \GO/에는 매크로가 없으니 그
자리에 |p.mems|를 직접 늘린다. 원본의 |aa(k,l)| 매크로는 |p.mtx[k*p.n+l]|로
편다.
@^\\{mems} 이야기@>

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

@ 우리는 여태 말만 잔뜩 하고 정리를 한 무더기 증명했을 뿐, 코드는 한 줄도 쓰지
않았다. \.{-h} 옵션이 주어졌을 때 움직이는 루틴을 쓰면서 다시 프로그래밍 모드로
돌아가자. $m=n$일 때 각 열에서 최솟값을 빼 두면 시작부터 $0$이 많아진다.

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

@* 알고리즘의 세부. 위에서 그린 알고리즘은 꽤 간단하다. 다만 $(*)$ 꼴의 경로로
닿을 수 있는 뽑힌 열 $c^{(q)}$을 어떻게 알아내는지는 아직 이야기하지 않았다.
그런 열을 모두 찾기는 쉽다. 노드가 행인 순서 없는 forest를 짓되, 짝이 없는 행
$r^{(0)}$을 모두 넣고 시작해서, 이미 forest에 든 행과 이웃한 열 $c$에 대해
$c\ddash r$인 행 $r$을 덧붙여 가면 된다.

@ 우리 자료 구조는 Papadimitriou와 Steiglitz의 제안
@^Papadimitriou, Christos Harilaos@>
@^Steiglitz, Kenneth@>
[{\sl Combinatorial Optimization\/} (Prentice-Hall, 1982), $\mathchar"278$11.1]
을 바탕으로 하며, 배열 여럿을 쓴다. 행 $r$이 열 $c$와 짝지어지면
|colMate[r]=c|, |rowMate[c]=r|이다. 행 $r$에 짝이 없으면 |colMate[r]|이 $-1$이고,
열 $c$에 짝이 없으면 |rowMate[c]|가 $-1$이다. 열 $c$에 짝이 있으면서 $(*)$ 꼴의
경로로 닿을 수 있으면 forest 속 어떤 행 $r'$에 대해 |parentRow[c]|가 $r'$이고,
그렇지 않으면 열 $c$는 뽑히지 않은 것이어서 |parentRow[c]|가 $-1$이다. 지금
forest에 든 행들은 |unchosenRow[0]|부터 |unchosenRow[t-1]|까지이며, |t|는 지금의
노드 총수다.

@ 행 $k$에서 뺀 양 $\sigma_k$를 |rowDec[k]|라 하고, 열 $l$에 더한 양
$\tau_{\,l}$을 |colInc[l]|이라 한다. 덮이지 않은 원소의 최솟값을 효율적으로
셈하려고 |slack[l]|이라는 양을 지닌다. 좀 더 정확히 말하면, 열 $l$이 뽑히지
않았을 때 |slack[l]|은 $k$가 |unchosenRow[0]|부터 |unchosenRow[q-1]|까지 돌 때의
$a_{kl}-\sigma_k+\tau_{\,l}$의 최솟값이다. 여기서 $q\le t$는 forest에서 여태
살펴본 행의 수다. 그 최솟값이 난 행 |slackRow[l]|도 함께 기억해 둔다.

열 $l$이 뽑힌 것은 |parentRow[l]|이 음수가 아닐 때, 그리고 그때뿐이다. 그리고
뽑힌 열에서는 |slack[l]|이 $0$이 되도록 살림을 꾸려 갈 것이다.

@ 원본은 |mtx|·|mems|와 이 배열들을 모두 전역에 두었지만, 우리는 |solver|
구조체에 담아 패키지 수준 가변 상태를 피한다.

@<matching과 forest를 담는 배열들@>=
colMate     []int64 // 주어진 행과 짝지어진 열, 또는 $-1$
rowMate     []int64 // 주어진 열과 짝지어진 행, 또는 $-1$
parentRow   []int64 // 주어진 열의 짝의 조상, 또는 $-1$
unchosenRow []int64 // forest의 노드
rowDec      []int64 // $\sigma_k$, 주어진 행에서 뺀 양
colInc      []int64 // $\tau_{\,l}$, 주어진 열에 더한 양
slack       []int64 // 주어진 열에서 본 가장 작은 덮이지 않은 원소
slackRow    []int64 // 그 |slack|이 난 행

@ 알고리즘은 단계로 나뉘고, 각 단계는 매칭된 원소 수를 하나 늘릴 수 있게 되면
끝난다. 첫 단계는 다르다: 그저 행렬을 훑어 $0$을 찾아 되도록 많은 행·열을 짝짓고,
뒤 단계에서 쓸 표들을 채운다.

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

@ 가장 작은 |slack|을 가진 열이 여럿일 수 있다. 그 가운데 하나가 돌파를 이루면
아주 기쁜 일이지만, 다음 단계를 위해 |col_inc|를 챙겨 두어야 하므로 |l|에 대한
고리를 끝까지 돈 뒤에야 돌파한다.

또 열 |l| 안에서도 같은 slack을 내는 행이 여럿일 수 있다. 우리는 그 가운데
|slack_row[l]| 하나만 기억해 두었다. 다행히 하나로 충분하다. 어느 행이 그 열을
살피게 했든, 결과는 돌파이거나 열 |l|을 뽑는 것 둘 중 하나이기 때문이다.

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

@* 캡슐화 PostScript. 사용자가 \.{-P} 옵션을 골랐으면 \.{lisa.eps}라는 특별한
출력 파일을 쓴다. 이 파일에는 여러 종류의 문서 안에 그림을 만들어 넣는 데 쓸 수
있는 PostScript 명령이 죽 들어 있다. 이를테면 \TEX/을 Radical Eye Software의
\.{dvips} 출력 드라이버, 그리고 딸린 \.{epsf.tex} 매크로와 함께 쓰고 있다면
@.dvips@>
$$\.{\\epsfxsize=10cm \\epsfbox\{lisa.eps\}}$$
라고 \TEX/ 문서에 적는 것으로 그림이 너비 10센티미터인 상자에 조판된다.

PostScript의 관례 덕분에 그림은 아무 크기로나 키우고 줄일 수 있다. 찍었을 때
픽셀 하나가 적어도 1밀리미터(1/25인치쯤)는 되게 하면 가장 볼만할 것이다.

@ 그림은 이렇게 만들어진다. 먼저 입력 자료를 최대 256가지 회색조의 픽셀
직사각형으로 ``칠한다.'' 그다음 해에 해당하는 픽셀을 검은 테로 두르되, 검은
가장자리 바로 안쪽에 흰 테를 살짝 덧대어 이미 어두운 자리에서도 테가 보이게
한다. 테는 원래 그림 위에 덧칠해 만드므로, 해 픽셀의 한가운데는 제 색을
그대로 지닌다.

캡슐화 PostScript 파일의 형식은 단순해서 많은 소프트웨어와 인쇄 장치가 알아본다.
우리는 필요하면 다른 언어로 옮기기 쉬운 부분집합만 쓴다. 여기서는 기계에 딸리지
않는 출력이 필요 없으므로 부동소수점을 써도 안전하다. 입력 행렬 출력은 전치와
뒤집기 전에 하므로 원래 |m|·|n|과 원자료를 쓴다.

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
