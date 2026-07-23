% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 girth.w를 Go로 이식한다.
@i ../../gbtypes.w

\input kotexgweb
\def\title{GIRTH}
\let\==\equiv % 합동 기호

@* 들어가며. 이 시연 프로그램은 {\sc GB\_\,RAMAN}의 |Raman| 프로시저가 지은
그래프를 써서 \.{girth}라는 대화형 프로그램을 만든다. 이 프로그램은 한 갈래의
Ramanujan 그래프의 둘레(girth)와 지름(diameter)을 셈한다.

그래프의 둘레란 가장 짧은 순환의 길이이고, 지름이란 두 정점 사이 최단 경로
길이의 최댓값이다. Ramanujan 그래프란 이어진 무향 그래프로서 모든 정점의 차수가
@^Ramanujan 그래프@>
|p+1|이고, 인접 행렬의 모든 고윳값이 $\pm(p+1)$이거나 절댓값이
$\le2\sqrt{\mathstrut p}$인 것을 말한다.

@ 둘레의 정확한 값이 흥미로운 까닭은, |Raman|이 내놓는 이분 그래프가 알려진 어떤
정칙 그래프 족보다도 둘레가 큰 것으로 보이기 때문이다. 존재만 비구성적으로 알려진
그래프까지 쳐도 그렇다. 딱 하나, Biggs, Hoare, Weiss의 3차 ``육중주(sextet)''
@^Biggs, Norman L.@>
@^Hoare, M. J.@>
@^Weiss, Alfred@>
그래프만은 예외다[{\sl Combinatorica\/ \bf 3\/} (1983), 153--165;
{\bf 4\/} (1984), 241--245].

지름의 정확한 값이 흥미로운 까닭은, 어떤 Ramanujan 그래프의 지름이든 정칙 그래프가
가질 수 있는 최소 지름의 많아야 두 배이기 때문이다.

@ 프로그램은 두 수 |p|와 |q|를 물어본다. 서로 다른 소수여야 하고, 너무 크지
않아야 하며, $q>2$여야 한다. 그러면 각 정점의 차수가 |p+1|인 그래프가 만들어진다.
정점 수는 |p|가 |q|를 법으로 하는 이차 잉여이면 $(q^3-q)/2$이고, 이차 잉여가
아니면 $q^3-q$다. 뒤의 경우 그래프는 이분이며, 둘레가 꽤 크다고 알려져 있다.

$p=2$이면 |q|는 다시 $104k+(1,3,9,17,25,27,35,43,49,\allowbreak51,75,81)$ 꼴로
제한된다. 그래서 $p=2$와 함께 쓸 만한 |q|는 사실상 $3$, $17$, $43$뿐이다. 그다음
경우인 $q=107$은 정점 $1{,}224{,}936$개, 호 $3{,}674{,}808$개짜리 이분 그래프를
만들어, 메모리가 대략 113메가바이트나 든다(적잖은 계산 시간은 말할 것도 없다).

큰 |p|나 |q|에 대해 Ramanujan 그래프의 둘레와 지름을 셈하고 싶다면 수론에 바탕한
훨씬 나은 방법이 있다. 이 프로그램은 그저 |Raman|의 출력을 어떻게 받아 쓰는지
보여 주는 시범일 뿐이다. 참고로 $p=2$, $q=43$인 그래프는 정점이 $79464$개이고
둘레가 $20$, 지름이 $22$인 것으로 드러난다.

프로그램은 그래프를 살펴 둘레와 지름을 셈한 뒤, 다시 |p|와 |q|를 물어본다.

@ 프로그램의 뼈대다.

@c
package main

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	@#
	"github.com/sjnam/go-sgb/gbraman"
)

@<입력받기 서브루틴@>

func main() {
	fmt.Println("This program explores the girth and diameter of Ramanujan graphs.")
	fmt.Println("The bipartite graphs have q^3-q vertices, and the non-bipartite")
	fmt.Println("graphs have half that number. Each vertex has degree p+1.")
	fmt.Println("Both p and q should be odd prime numbers;")
	fmt.Println("  or you can try p = 2 with q = 17 or 43.")
	in := bufio.NewReader(os.Stdin)
	for {
		p, ok := readNum(in, "\nChoose a branching factor, p: ")
		if !ok {
			break
		}
		q, ok := readNum(in, "OK, now choose the cube root of graph size, q: ")
		if !ok {
			break
		}
		g, err := gbraman.Raman(p, q, 0, 0)
		if err != nil {
			@<그래프를 못 만든 까닭을 밝힌다@>
		} else {
			@<g의 둘레·지름 이론값을 찍는다@>
			@<g의 진짜 둘레·지름을 셈해 찍는다@>
		}
	}
}

@ |readNum|은 프롬프트를 찍고 한 줄을 읽어 정수를 뽑는다. 파일 끝이거나 정수가
아니면 거짓을 돌려주어 실행을 끝낸다.

@<입력받기 서브루틴@>=
func readNum(in *bufio.Reader, prompt string) (int64, bool) {
	fmt.Print(prompt)
	line, err := in.ReadString('\n')
	if err != nil && line == "" {
		return 0, false
	}
	var v int64
	if k, _ := fmt.Sscanf(line, "%d", &v); k != 1 {
		return 0, false
	}
	return v, true
}

@ |Raman|이 돌려준 오류를 {\sc GIRTH}가 밝히는 문구로 옮긴다.

@<그래프를 못 만든 까닭을 밝힌다@>=
var msg string
switch {
case errors.Is(err, gbraman.ErrQRange):
	msg = "q is out of range"
case errors.Is(err, gbraman.ErrPRange):
	msg = "p is out of range"
case errors.Is(err, gbraman.ErrQTooBig):
	msg = "q is too big"
case errors.Is(err, gbraman.ErrPTooBig):
	msg = "p is too big"
case errors.Is(err, gbraman.ErrQNotPrime):
	msg = "q isn't prime"
case errors.Is(err, gbraman.ErrPNotPrime):
	msg = "p isn't prime"
case errors.Is(err, gbraman.ErrPMultQ):
	msg = "p is a multiple of q"
case errors.Is(err, gbraman.ErrQIncompat):
	msg = "q isn't compatible with p=2"
default:
	msg = "not enough memory"
}
fmt.Printf(" Sorry, I couldn't make that graph (%s).\n", msg)

@* 이론값. Ramanujan 그래프 이론은 둘레와 지름을 2배 안팎으로 예측하게 해 준다.

우선, 차수 $p+1$인 임의의 $n$정점 정칙 그래프에 대해 둘레의 상계와 지름의 하계를
쉽게 이끌어 낼 수 있다. 그런 그래프에서 주어진 정점으로부터 거리 $k$에 있는 점은
많아야 $(p+1)p^{k-1}$개다. 이것이 지름 $d$의 하계를 준다.
$$1+(p+1)+(p+1)p+(p+1)p^2+\cdots+(p+1)p^{d-1}\;\ge\;n.$$

마찬가지로 둘레 $g$가 홀수여서 $g=2k+1$이라면, 어느 정점에서 거리 $\le k$인
점들은 모두 서로 달라야 하므로
$$1+(p+1)+(p+1)p+(p+1)p^2+\cdots+(p+1)p^{k-1}\;\le\;n$$
이다. 그리고 $g=2k+2$이면 거리 $k+1$에 적어도 $p^k$개의 점이 더 있어야 한다.
길이 $k+1$인 경로 $(p+1)p^k$개가 어느 한 정점에서 끝날 수 있는 것은 많아야
$p+1$번이기 때문이다. 그러니 둘레가 짝수일 때는
$$1+(p+1)+(p+1)p+(p+1)p^2+\cdots+(p+1)p^{k-1}+p^k\;\le\;n$$
이다.

@ @<g의 둘레·지름 이론값을 찍는다@>=
n := g.N
bipartite := n == (q+1)*q*(q-1)
notStr := "not "
if bipartite {
	notStr = ""
}
fmt.Printf("The graph has %d vertices, each of degree %d, and it is %sbipartite.\n",
	n, p+1, notStr)
@<자명한 상·하계 |gu|, |dl|을 셈한다@>
fmt.Printf("Any such graph must have diameter >= %d and girth <= %d;\n", dl, gu)
@<지름의 상계 |du|를 셈한다@>
fmt.Printf("theoretical considerations tell us that this one's diameter is <= %d", du)
if p == 2 {
	fmt.Println(".")
} else {
	@<둘레의 하계 |gl|을 셈한다@>
	fmt.Printf(",\nand its girth is >= %d.\n", gl)
}

@ $|pp|=p^{dl}$이고 $s=1+(p+1)+\cdots+(p+1)p^{dl}$로 둔다.

@<자명한 상·하계 |gu|, |dl|을 셈한다@>=
s := p + 2
dl := int64(1)
pp := p
gu := int64(3)
for s < n {
	s += pp
	if s <= n {
		gu++
	}
	dl++
	pp *= p
	s += pp
	if s <= n {
		gu++
	}
}

@ 어떤 Ramanujan 그래프든 지름의 상계는 Lubotzky, Phillips, Sarnak의 논문
@^Lubotzky, Alexander@>
@^Phillips, Ralph Saul@>
@^Sarnak, Peter@>
[{\sl Combinatorica\/ \bf 8\/} (1988), 275쪽]에 나온 대로 이끌어 낼 수 있다.
(다만 그들의 증명은 살짝 고쳐야 한다---$x$와 $y$가 이분 그래프의 서로 다른 쪽에
놓일 때는 그들의 매개변수 $l$이 홀수여야 한다.)

그들의 논증은 비이분인 경우 $p^{(d-1)/2}<2n$, 이분인 경우 $p^{(d-2)/2}<n$임을
보여 준다. 그러므로 상계 $d\le2\log_p n+O(1)$을 얻는데, 이는 임의의 정칙 그래프에서
성립하는 하계의 대략 두 배다.

@<지름의 상계 |du|를 셈한다@>=
nn := 2 * n
if bipartite {
	nn = n
}
du := int64(0)
pp = 1
for pp < nn {
	du += 2
	pp *= p
}
@<$|pp|/|nn|\ge\sqrt p$이면 |du|를 1 줄인다@>
if bipartite {
	du++
}

@ 이 절이 필요로 하는 판정에는 부동소수점 산술이 충분히 정확하지 않을 수 있다.
그래서 유클리드 알고리즘과 비슷한, $\sqrt p$의 연분수에 바탕한 온전한 정수
방법으로 그것을 피한다[{\sl Seminumerical Algorithms\/}, 연습문제 4.5.3--12].
아래 고리에서 우리는 |nn/pp|를 $(\sqrt p+a)/b$와 견주려 하는데, 여기서
$\sqrt p+a>b>0$이고 $p-a^2$은 $b$의 배수다.

@<$|pp|/|nn|\ge\sqrt p$이면 |du|를 1 줄인다@>=
qq := pp / nn
if qq*qq > p {
	du--
} else if (qq+1)*(qq+1) > p { // $|qq|=\lfloor\sqrt p\,\rfloor$
	aa := qq
	bb := p - aa*aa
	parity := int64(0)
	pp -= qq * nn
	for {
		x := (aa + qq) / bb
		y := nn - x*pp
		if y <= 0 {
			break
		}
		aa = bb*x - aa // 이제 $0<|aa|<\sqrt p$
		bb = (p - aa*aa) / bb
		nn = pp
		pp = y
		parity ^= 1
	}
	if parity == 0 {
		du--
	}
}

@ $p>2$이면 정수 사원수 이론으로 |Raman|이 내놓는 그래프의 둘레에 대한 하계를
이끌어 낼 수 있다. 어떤 정점에서 자기 자신으로 가는 길이 $g$인 경로가 있을
필요충분조건은, 노름이 $p^{\,g}$인 정수 사원수
$\alpha=a_0+a_1i+a_2j+a_3k$가 있어 $a$들이 모두 $p$의 배수인 것은 아니면서
$a_1$, $a_2$, $a_3$이 $q$의 배수이고 $a_0\not\=a_1\=a_2\=a_3$ (mod~2)인 것이다.
곧 정수 $(a_0,a_1,a_2,a_3)$이 있어
$$a_0^2+a_1^2+a_2^2+a_3^2=p^{\,g}$$
이면서 위의 성질을 mod~$q$와 mod~2로 만족한다는 뜻이다.

$a_1$, $a_2$, $a_3$이 짝수이면 그것들이 모두 $0$일 수는 없으므로
$p^{\,g}\ge1+4q^2$여야 한다. 홀수이면 $p^{\,g}\ge4+3q^2$여야 한다. (뒤엣것은
$g$가 홀수이고 $p\bmod4=3$일 때만 가능하다.) $n$은 대략 $q^3$에 비례하므로,
이는 $g$가 적어도 대략 ${2\over3}\log_p n$이어야 한다는 뜻이다. 그러니 $g$는,
어떤 정칙 그래프에서든 많아야 대략 $2\log_p n$임을 앞서 보인 최대 가능 둘레보다
그리 많이 작지 않다.

@ 그래프가 이분일 때는 사실 $g$가 대략 ${4\over3}\log_p n$임을 증명할 수 있다.
이분인 경우는 $p$가 $q$를 법으로 하는 이차 잉여가 아닐 때, 그리고 그때뿐이다.
따라서 앞 절의 수 $g$는 짝수여야 하니 $g=2r$이라 하자. 그러면
$p^{\,g}\bmod4=1$이고 $a_0$은 홀수여야 한다. 합동식 $a_0^2\=p^{2r}$ (mod~$q^2$)은
$a_0\=\pm p^r$을 뜻하는데, $q^2$과 서로소인 수는 모두 원시근의 거듭제곱이기
때문이다. 일반성을 잃지 않고 $a_0=p^r-2mq^2$이라 둘 수 있다. 여기서
$0<m<p^r/q^2$이며, 특히 $p^r>q^2$이 따라 나온다.

거꾸로 $p^r-q^2$을 세 제곱수의 합 $b_1^2+b_2^2+b_3^2$으로 쓸 수 있으면
$$p^{2r}=(p^r-2q^2)^2+(2b_1q)^2+(2b_2q)^2+(2b_3q)^2$$
이 요구되는 꼴의 표현이 된다. $p^r-q^2$이 세 제곱수의 합으로 나타낼 수 없는 양의
정수라면, 잘 알려진 Legendre의 정리에 따라 $p^r-q^2=4^ts$이고 $s\=7$ (mod~8)이다.
$p$와 $q$가 홀수이므로 $t\ge1$이고, 따라서 $p^r-2q^2$은 홀수다. $p^r-2q^2$이 양의
홀수이면 Legendre의 정리는 $2p^r-4q^2=b_1^2+b_2^2+b_3^2$으로 쓸 수 있다고 말해
주므로
$$p^{2r}=(p^r-4q^2)^2+(2b_1q)^2+(2b_2q)^2+(2b_3q)^2$$
이 된다.

그러므로 둘레는 $2\lceil\log_pq^2\rceil$이거나 $2\lceil\log_p2q^2\rceil$이라고
결론지을 수 있다. (이 명시적 계산은 이분인 경우 둘레를 셈하는 우리 프로그램을
불필요하거나 기껏해야 군더더기로 만드는데, G.~A. Margulis와, 그와 따로
@^Margulis, Grigori{\u\i} Aleksandrovich@>
@^Biggs, Norman L.@>
@^Boshier, A. G.@>
Biggs와 Boshier가 얻은 것이다[{\sl Journal of Combinatorial Theory\/ \bf B49\/}
(1990), 190--194].)

둘레가 $1$이나 $2$일 수도 있다. |p|가 충분히 크면 이 그래프들에 자기 고리나 중복
간선이 생길 수 있기 때문이다.

@<둘레의 하계 |gl|을 셈한다@>=
var gl int64
if bipartite {
	b := q * q
	gl, pp = 1, p
	for pp <= b { // $p^{\,g}>q^2$가 될 때까지
		gl++
		pp *= p
	}
	gl += gl
} else {
	b1 := 1 + 4*q*q
	b2 := 4 + 3*q*q // $p^{\,g}$의 한계들
	gl, pp = 1, p
	for pp < b1 {
		if pp >= b2 && gl&1 != 0 && p&2 != 0 {
			break
		}
		gl++
		pp *= p
	}
}

@* 너비 우선 탐색. |Raman|이 낸 그래프는 대칭이라, 어떤 정점에서 어느 정점으로도
옮기는 자기동형사상이 있다. 그래서 아무 정점 |v0|에서 시작해 둘레와 지름을 찾을
수 있다. |v0|에서 거리 |k|에 있는 점들의 연결 목록을 만든다. 유틸리티 필드
|W.V|는 링크(처음엔 |nil|), |V.I|는 시작점으로부터의 거리, |U.V|는 한 걸음 더
가까운 정점을 가리킨다. 목록은 |nil|이 아닌 |sentinel| 값으로 끝나므로,
|W.V==nil|로 처음 보는 정점인지도 가린다.

@ @<g의 진짜 둘레·지름을 셈해 찍는다@>=
fmt.Println("Starting at any given vertex, there are")
sentinel := &g.Vertices[n] // 목록 끝의 0이 아닌 링크
girth := int64(999)        // 지금껏 찾은 가장 짧은 회로 길이, 처음엔 무한대
k := int64(0)
u := &g.Vertices[0]
u.W.V = sentinel
c := int64(1)
for c != 0 {
	v := u
	u = sentinel
	c = 0
	k++
	for v != sentinel {
		@<|v|에 인접한 정점들을 목록 |u|에 얹는다@>
		v = v.W.V
	}
	sep := "."
	if c > 0 {
		sep = ","
	}
	fmt.Printf("%8d vertices at distance %d%s\n", c, k, sep)
}
fmt.Printf("So the diameter is %d, and the girth is %d.\n", k-1, girth)

@ 처음 보는 정점이면 목록에 얹고 거리·역포인터를 적는다. 이미 본 정점이면
(부모로 가는 나무 간선만 빼고) 회로 길이 후보 |w.dist+k|를 |girth|와 견준다.

@<|v|에 인접한 정점들을 목록 |u|에 얹는다@>=
for a := v.Arcs; a != nil; a = a.Next {
	w := a.Tip // |v|에 인접한 정점
	if w.W.V == nil {
		w.W.V = u
		w.V.I = k
		w.U.V = v
		u = w
		c++
	} else if w.V.I+k < girth && w != v.U.V {
		girth = w.V.I + k
	}
}

@* 색인.
