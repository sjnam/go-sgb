% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 take_risc.w를 Go로 이식한다.
@i ../../gbtypes.w

\input kotexgweb
\def\title{TAKE\_\,RISC}
\def\<#1>{$\langle${\rm#1}$\rangle$}

@* 들어가며. 이 시연 프로그램은 {\sc GB\_\,GATES}의 |Risc| 프로시저가 지은
게이트 그래프를 써서, 작은 수를 느린 방식으로 --- 논리 회로의 동작을 게이트
하나하나 흉내 내어 --- 곱하고 나눈다.

명령줄에서 \.{take\_risc} \<추적>이라 부르되, 기계의 셈 과정을 낱낱이
찍어 보고 싶으면 \<추적>을 비지 않게 준다. 프로그램은 두 수를 물어본 뒤
흉내 낸 RISC 기계로 그 곱과 몫을 셈하고, 다시 두 수를 물어보기를 되풀이한다.
입력은 \UNIX/ 관례를 따라 표준 입력에서 읽는다.

@ 프로그램의 뼈대다. |Risc(8)|은 레지스터 여덟 개짜리 기계를 짓고,
추적할 때는 레지스터 0--7을 보인다.

@c
package main

import (
	"bufio"
	"fmt"
	"os"
	@#
	"github.com/sjnam/go-sgb/gbgates"
)

const (
	mult = 10 // 아래 프로그램에서 곱셈 진입점 위치
	div  = 7  // 아래 프로그램에서 나눗셈 진입점 위치
)

@<입력받기 서브루틴@>

func main() {
	var trace int64
	if len(os.Args) > 1 {
		trace = 8 // 추적하면 레지스터 0--7을 보인다
	}
	g, err := gbgates.Risc(8)
	if err != nil {
		fmt.Printf("Sorry, I couldn't generate the graph (trouble code %v)!\n", err)
		os.Exit(1)
	}
	fmt.Println("Welcome to the world of microRISC.")
	@<읽기 전용 메모리를 잡는다@>
	in := bufio.NewReader(os.Stdin)
	for {
		m, ok := getNumber(in, "\nGimme a number: ")
		if !ok {
			break
		}
		n, ok := getNumber(in, "OK, now gimme another: ")
		if !ok {
			break
		}
		@<RISC 기계로 곱 |p|를 셈한다@>
		fmt.Printf("The product of %d and %d is %d%s.\n", m, n, p, ovStr)
		@<RISC 기계로 몫 |q|와 나머지 |r|를 셈한다@>
		fmt.Printf("The quotient is %d, and the remainder is %d.\n", q, r)
	}
}

@ 두 수를 물어보는 대목이다. \CEE/ 원본은 |goto|로 얽힌 작은 상태 기계였는데,
여기서는 중첩 반복문으로 옮긴다. |getNumber|는 프롬프트를 찍고 한 줄을 읽어 그
줄에서 정수를 뽑는다. 파일 끝이거나 정수가 아니면 거짓을 돌려주고, 0 이하이면
한 번 더 채근하고, $2^{15}$ 이상이면 될 때까지 다시 묻는다 --- 다만 그 사이
0 이하가 나오면 양수 확인 단계로 되돌아간다.
@<입력받기 서브루틴@>=
func readInt(in *bufio.Reader, prompt string) (int64, bool) {
	fmt.Print(prompt)
	line, err := in.ReadString('\n')
	if err != nil && line == "" {
		return 0, false // 아무것도 못 읽은 파일 끝
	}
	var m int64
	if k, _ := fmt.Sscanf(line, "%d", &m); k != 1 {
		return 0, false // 정수가 아니다
	}
	return m, true
}

@ |readInt|이 거짓을 돌려주면 (파일 끝이든 파싱 실패든) 어느 자리에서나
그만두므로, 두 경우를 한 불리언으로 합쳐 다룬다.
@<입력받기 서브루틴@>=
func getNumber(in *bufio.Reader, firstPrompt string) (int64, bool) {
	m, ok := readInt(in, firstPrompt)
	if !ok {
		return 0, false
	}
	for {
		if m <= 0 {
			m, ok = readInt(in, "Excuse me, I meant a positive number: ")
			if !ok || m <= 0 {
				return 0, false
			}
		}
		for m > 0x7fff {
			m, ok = readInt(in, "That number's too big; please try again: ")
			if !ok {
				return 0, false
			}
			if m <= 0 {
				break // 양수 확인 단계로 되돌아간다
			}
		}
		if m > 0 && m <= 0x7fff {
			return m, true
		}
	}
}

@* RISC 프로그램. 작은 컴퓨터에 돌릴 작은 프로그램이다. 핵심은 삼항 연산
$x\lfloor y/z\rfloor$을 셈하는 |tri| 서브루틴으로, $y\ge0$, $z>0$을 가정한다.
입력 $x,y,z$는 각각 레지스터 1, 2, 3에 있고, 복귀 주소는 레지스터 7에 있다고
본다. 특수한 경우로 $z=1$이면 곱 $xy$를, $x=1$이면 몫 $\lfloor y/z\rfloor$을
얻는다. 서브루틴이 돌아올 때 결과는 레지스터 4에, $(y\bmod z)-z$ 값은 레지스터
2에 남는다. 참값이 $-2^{15}$과 $2^{15}-1$ 사이(양끝 포함)에 없을 때만 넘침이
켜진다.

@ 이 읽기 전용 메모리는 |RunRisc|가 흉내 낼 34낱말짜리 프로그램이다. 셈할 때마다
|rom[1]|에 |m|을, |rom[3]|에 |n|을, |rom[5]|에 |mult|나 |div|를 채워 넣는다.
그래서 전역이 아니라 |main| 안의 지역 슬라이스로 둔다.
@<읽기 전용 메모리를 잡는다@>=
rom := []int64{
	0x2ff0, // |start|: |r2| = m (다음 낱말의 내용)
	0x1111, // (|rom[1]|에 |m| 값을 넣는다)
	0x1a30, // |r1| = n (다음 낱말의 내용)
	0x3333, // (|rom[3]|에 |n| 값을 넣는다)
	0x7f70, // 다음 낱말로 뛰고 |r7| = 복귀 주소
	0x5555, // (|rom[5]|에 |mult|나 |div|를 넣는다)
	0x0f8f, // 상태 비트를 안 바꾸고 멈춘다
	0x3a21, // |div|: |r3 = r1|
	0x1a01, // |r1 = 1|
	0x0a12, // |tri|로 간다 (곧, |r0 += 2|)
	0x3a01, // |mult|: |r3 = 1|
	0x4000, // |tri|: |r4 = 0|
	0x5000, // |r5 = 0|
	0x6000, // |r6 = 0|
	0x2a63, // |r2 -= r3|
	0x0f95, // |l2|로 간다
	0x3063, // |l1|: |r3 <<= 1|
	0x1061, // |r1 <<= 1|
	0x6ac1, // 넘침이면 |r6 = 1|
	0x5fd1, // |r5++|
	0x2a63, // |l2|: |r2 -= r3|
	0x039b, // 0 이상이면 |l1|로 간다
	0x0843, // |l4|로 간다
	0x3463, // |l3|: |r3 >>= 1|
	0x1561, // |r1 >>= 1|
	0x2863, // |l4|: |r2 += r3|
	0x0c94, // 음수면 |l5|로 간다
	0x4861, // |r4 += r1|
	0x6ac1, // 넘침이면 |r6 = 1|
	0x2a63, // |r2 -= r3|
	0x5a41, // |l5|: |r5--|
	0x0398, // 0 이상이면 |l3|로 간다
	0x6666, // |r6|면 넘침을 강제한다 (곧, |r6 >>= 4|)
	0x0fa7, // 돌아간다 (곧, |r0 = r7|, 넘침 보존)
}

@ 곱을 셈한다. |RunRisc|는 기계를 지우고 주소 0에서 시작해, 레지스터 값 열여덟
개짜리 배열을 돌려준다. 결과는 레지스터 4에, 넘침 비트는 |st[16]|의 최하위
비트에 있다.
@<RISC 기계로 곱 |p|를 셈한다@>=
rom[1] = m
rom[3] = n
rom[5] = mult
st, _ := gbgates.RunRisc(g, rom, trace, os.Stdout)
p := st[4]
ovStr := ""
if st[16]&1 != 0 {
	ovStr = " (overflow occurred)"
}

@ 몫과 나머지를 셈한다. 나머지는 $(y\bmod z)-z$에서 되살린다.
@<RISC 기계로 몫 |q|와 나머지 |r|를 셈한다@>=
rom[5] = div
st, _ = gbgates.RunRisc(g, rom, trace, os.Stdout)
q := st[4]
r := (st[2] + n) & 0x7fff

@* 색인.
