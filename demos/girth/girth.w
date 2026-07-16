% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 girth.w를 Go로 이식한다.
@i ../../types.w

\input kotexgweb
\def\title{GIRTH}
\let\==\equiv % 합동 기호

@* 들어가며. 이 시연 프로그램은 {\sc GB\_\,RAMAN}의 |Raman| 프로시저가 지은
그래프의 둘레(girth)와 지름(diameter)을 셈한다. 그래프의 둘레는 가장 짧은
회로의 길이이고, 지름은 두 정점 사이 최단 경로 길이의 최댓값이다.

프로그램은 소수 |p|와 |q|를 물어본다. 서로 다른 소수이고 너무 크지 않으며
|q>2|라야 한다. 각 정점의 차수가 |p+1|인 그래프가 만들어진다. 정점 수는 |p|가
|q|의 이차 잉여이면 $(q^3-q)/2$, 아니면 $q^3-q$이다. 뒤의 경우 그래프는 이분이며
둘레가 꽤 크다고 알려져 있다. |p=2|이면 쓸 만한 |q|는 사실상 3, 17, 43뿐이다.

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
먼저, 차수 |p+1|인 임의의 |n|정점 정칙 그래프에 대해 둘레의 상계와 지름의 하계를
쉽게 얻는다. 그런 그래프에서 어떤 정점으로부터 거리 |k|에 있는 점은 많아야
$(p+1)p^{k-1}$개다.

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

@ Lubotzky, Phillips, Sarnak의 논증은 비이분이면 $p^{(d-1)/2}<2n$, 이분이면
$p^{(d-2)/2}<n$임을 보여, 지름 상계 $d\le2\log_p n+O(1)$을 준다.

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

@ 부동소수점은 이 판정에 충분히 정확하지 않을 수 있어, $\sqrt p$의 연분수에
바탕한 정수 방법으로 피한다. |nn/pp|를 $(\sqrt p+a)/b$와 견준다.

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

@ |p>2|이면 정수 사원수 이론으로 둘레의 하계를 얻는다. 둘레는 홀수변에서
$p^{\,g}\ge1+4q^2$나 $p^{\,g}\ge4+3q^2$이어야 하고, 이분이면 $p^{\,g}>q^2$인
가장 작은 짝수 $g$다.

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
