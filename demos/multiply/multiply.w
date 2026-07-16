% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 multiply.w를 Go로 이식한다.
@i ../../types.w

\input kotexgweb
\def\title{MULTIPLY}
\def\<#1>{$\langle${\rm#1}$\rangle$}

@* 들어가며. 이 시연 프로그램은 {\sc GB\_\,GATES}의 |Prod| 프로시저가 지은
그래프를 써서, 작은 수를 느린 방식으로---논리 회로의 동작을 게이트 하나하나
흉내 내어---곱한다.

명령줄에서 \.{multiply} $m$ $n$ [|seed|]라고 부른다. $m$과 $n$은 곱할 두 수의
비트 크기다. |seed|는 주면, $m$비트 수에 무작위로 고른 $n$비트 상수를 곱하는
특수 회로를 만들라는 뜻이다. 프로그램은 두 수(상수 옵션을 골랐으면 한 수)를
물어 게이트 망으로 곱을 셈하고, 다시 입력을 물어보기를 되풀이한다. 입력은
\UNIX/ 관례를 따라 표준 입력에서 읽는다.

@ 프로그램의 뼈대다.

@c
package main

import (
	"bufio"
	"fmt"
	"math/big"
	"os"
	"strings"
	@#
	"github.com/sjnam/go-sgb/gbgates"
	"github.com/sjnam/go-sgb/gbgraph"
)

@<깊이 재기 서브루틴@>
@<입력받기 서브루틴@>

func main() {
	@<명령줄에서 |m|, |n|, 씨앗을 얻는다@>
	@<|m|, |n|을 확인하고 |Prod| 그래프 |g|를 짓는다@>
	seeded := seed >= 0
	var x, y string
	@<준비되었음을 알린다@>
	fmt.Printf("(I'm simulating a logic circuit with %d gates, depth %d.)\n",
		g.N, depth(g))
	in := bufio.NewReader(os.Stdin)
	for {
		var ok bool
		x, ok = getNumber(in, "\nNumber, please? ")
		if !ok {
			break
		}
		if !seeded {
			y, ok = getNumber(in, "Another? ")
			if !ok {
				break
			}
		}
		@<게이트 망으로 곱 |z|를 셈한다@>
		@<곱 |z|를 찍는다@>
	}
}

@ 인자는 셋이나 넷이어야 한다. |m|과 |n|은 \CEE/의 |sscanf("%ld")|처럼 앞쪽
정수만 읽고, 음수 부호가 붙었으면 절댓값을 취한다. 씨앗은 넷째 인자가 정수일
때만 켜지며, 역시 절댓값으로 바꾼다(안 주면 $-1$).
@<명령줄에서 |m|, |n|, 씨앗을 얻는다@>=
var m, n, seed int64
ok1, ok2 := false, false
if len(os.Args) == 3 || len(os.Args) == 4 {
	m, ok1 = parseArg(os.Args[1])
	n, ok2 = parseArg(os.Args[2])
}
if !ok1 || !ok2 {
	fmt.Fprintf(os.Stderr, "Usage: %s m n [seed]\n", os.Args[0])
	os.Exit(2)
}
if m < 0 {
	m = -m
}
if n < 0 {
	n = -n
}
seed = -1
if len(os.Args) == 4 {
	if s, ok := parseArg(os.Args[3]); ok {
		seed = s
		if seed < 0 {
			seed = -seed
		}
	}
}

@ |Prod|은 정밀도 1000비트 미만만 다룬다. 너무 작은 크기는 2로 올린다.
@<|m|, |n|을 확인하고 |Prod| 그래프 |g|를 짓는다@>=
if m < 2 {
	m = 2
}
if n < 2 {
	n = 2
}
if m > 999 || n > 999 {
	fmt.Println("Sorry, I'm set up only for precision less than 1000 bits.")
	os.Exit(1)
}
g, err := gbgates.Prod(m, n)
if err != nil {
	fmt.Printf("Sorry, I couldn't generate the graph (%v)!\n", err)
	os.Exit(3)
}

@ 씨앗이 없으면 그대로 알린다. 씨앗이 있으면 |PartialGates|로 앞 |m|개 입력만
남기고 나머지 |n|개에 무작위 상수를 구워 넣는다. 그 상수의 이진 문자열은
리틀엔디언으로 |buf|에 담기므로, 십진값 |y|로 옮긴다. 상수가 0이면 회로가
통째로 무너지니 다른 씨앗을 청한다.
@<준비되었음을 알린다@>=
if !seeded {
	fmt.Printf("Here I am, ready to multiply %d-bit numbers by %d-bit numbers.\n",
		m, n)
} else {
	var buf strings.Builder
	g2, err := gbgates.PartialGates(g, m, 0, seed, &buf)
	if err != nil {
		fmt.Printf("Sorry, I couldn't process the graph (trouble code %v)!\n", err)
		os.Exit(9)
	}
	g = g2
	yVal := new(big.Int)
	bits := buf.String()
	for i := 0; i < len(bits); i++ {
		if bits[i] == '1' {
			yVal.SetBit(yVal, i, 1)
		}
	}
	y = yVal.String()
	if y == "0" {
		fmt.Printf("Please try another seed value; %d makes the answer zero!\n", seed)
		os.Exit(5)
	}
	fmt.Printf("OK, I'm ready to multiply any %d-bit number by %s.\n", m, y)
}

@* 망 쓰기. 십진 입력을 리틀엔디언 이진 문자열로 바꿔 |GateEval|에 넣고, 그
빅엔디언 이진 출력을 다시 십진 |z|로 되돌린다. \CEE/ 원본은 고정도 수를 문자열로
두고 곱하기 두 배·반 나눔을 손수 짰지만, 여기서는 |math/big|을 쓴다.
@ 입력이 |m|(또는 |m+n|)비트에 안 들어가면 알리고 넘어간다. |xVal.Bit(i)|가
|x|의 |i|번째 비트다.
@<게이트 망으로 곱 |z|를 셈한다@>=
xVal, _ := new(big.Int).SetString(x, 10)
if xVal.BitLen() > int(m) {
	fmt.Printf("(Sorry, %s has more than %d bits.)\n", x, m)
	continue
}
var input strings.Builder
for i := int64(0); i < m; i++ {
	input.WriteByte('0' + byte(xVal.Bit(int(i))))
}
if !seeded {
	yVal, _ := new(big.Int).SetString(y, 10)
	if yVal.BitLen() > int(n) {
		fmt.Printf("(Sorry, %s has more than %d bits.)\n", y, n)
		continue
	}
	for i := int64(0); i < n; i++ {
		input.WriteByte('0' + byte(yVal.Bit(int(i))))
	}
}
out, code := gbgates.GateEval(g, input.String())
if code < 0 {
	fmt.Print("??? An internal error occurred!")
	os.Exit(666)
}
zVal := new(big.Int)
for i := 0; i < len(out); i++ {
	zVal.Lsh(zVal, 1)
	if out[i] == '1' {
		zVal.SetBit(zVal, 0, 1)
	}
}
z := zVal.String()

@ 두 피연산자의 십진 자릿수 합이 35를 넘으면 곱을 새 줄에 찍는다.
@<곱 |z|를 찍는다@>=
sep := ""
if len(x)+len(y) > 35 {
	sep = "\n "
}
fmt.Printf("%sx%s=%s%s.\n", x, y, sep, z)

@* 입력 다루기. |parseArg|는 명령줄 인자에서 앞쪽 정수를 읽는다. |getNumber|는
프롬프트를 찍고 한 줄을 읽어, 앞 0을 떼고 음 아닌 십진 숫자열만 받아들인다.
빈 줄이거나 파일 끝이면 거짓을 돌려주어 실행을 끝내고, 숫자가 아니거나 너무
길면 채근하고 다시 묻는다. \CEE/ 원본의 |goto|는 반복문으로 옮긴다.
@<입력받기 서브루틴@>=
func parseArg(s string) (int64, bool) {
	var v int64
	k, _ := fmt.Sscanf(s, "%d", &v)
	return v, k == 1
}

@ @<입력받기 서브루틴@>=
func getNumber(in *bufio.Reader, prompt string) (string, bool) {
	for {
		fmt.Print(prompt)
		line, err := in.ReadString('\n')
		if err != nil && line == "" {
			return "", false // 파일 끝
		}
		p := 0
		for p < len(line) && line[p] == '0' {
			p++ // 앞 0을 건너뛴다
		}
		if p < len(line) && line[p] == '\n' {
			if p > 0 {
				p-- // 0 하나는 남긴다
			} else {
				return "", false // 빈 줄이면 끝낸다
			}
		}
		q := p
		for q < len(line) && line[q] >= '0' && line[q] <= '9' {
			q++
		}
		if q >= len(line) || line[q] != '\n' {
			fmt.Print("Excuse me... I'm looking for a " +
				"nonnegative sequence of decimal digits.")
			continue
		}
		num := line[p:q]
		if len(num) > 301 {
			fmt.Print("Sorry, that's too big.")
			continue
		}
		return num, true
	}
}

@* 깊이 재기. {\sc GB\_\,GATES}가 낸 게이트 망의 깊이는 정점을 한 번 훑어 쉽게
구한다. 입력·상수는 깊이 0이고, 다른 게이트는 인수들의 최대 깊이보다 1 크다.
래치의 결과도 깊이 0으로 본다. 정점이 위상 차례라 인수의 깊이는 이미 셈해져
있다. 상수 출력은 |gbgates.IsBoolean|으로 걸러낸다.
@<깊이 재기 서브루틴@>=
func depth(g *gbgraph.Graph) int64 {
	if g == nil {
		return -1 // 그래프가 없다
	}
	dp := make([]int64, g.N)
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		switch v.Y.I {
		case 'I', 'L', 'C':
			dp[i] = 0
		default:
			var d int64
			for a := v.Arcs; a != nil; a = a.Next {
				if t := dp[g.Index(a.Tip)]; t > d {
					d = t
				}
			}
			dp[i] = 1 + d
		}
	}
	var d int64
	for a := g.ZZ.A; a != nil; a = a.Next {
		if !gbgates.IsBoolean(a.Tip) {
			if t := dp[g.Index(a.Tip)]; t > d {
				d = t
			}
		}
	}
	return d
}

@* 색인.
