% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 queen.w를 Go로 이식한다.
@i ../../types.w

\input kotexgweb
\def\title{QUEEN}

@* 퀸의 행마. GraphBase로 그래프를 짓고 훑는 법을 보여 주는 짧은 시연이다.
$3\times4$ 직사각형 판의 열두 칸을 정점으로 삼고, 한 칸에서 다른 칸으로 퀸의
한 수로 갈 수 있으면 두 칸을 이웃으로 본다. 그런 뒤 정점들과 그 이웃을 표준
출력에 찍는다.

퀸의 행마는 룩과 비숍의 행마를 합친 것이다. 그래서 룩 판(|piece=-1|)과 비숍
판(|piece=-2|)을 |gbbasic.Board|로 각각 짓고, |gbbasic.Gunion|으로 두 그래프의
합집합을 취하면 퀸 그래프가 된다.

\.{queen.gb}라는 ASCII 파일도 함께 만든다. 다른 프로그램은
|gbsave.RestoreGraph("queen.gb")|를 불러 이 퀸 그래프의 사본을 얻을 수 있다.
{\sc QUEEN}의 출력은 사람이 읽으라고, \.{queen.gb}는 컴퓨터가 읽으라고 있는
것이니, 둘을 견주어 보는 것도 흥미롭다.

@c
package main

import (
	"bufio"
	"fmt"
	"log"
	"os"

	"github.com/sjnam/go-sgb/gbbasic"
	"github.com/sjnam/go-sgb/gbsave"
)

func main() {
	@<퀸 그래프를 짓는다@>@;
	if err := gbsave.SaveGraph(g, "queen.gb"); err != nil {
		log.Fatalf("queen.gb를 저장하지 못했습니다: %v", err)
	}
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	@<정점과 간선을 찍는다@>@;
}

@ 룩 판과 비숍 판의 합집합이 퀸 그래프다.

@<퀸 그래프를 짓는다@>=
rook, err := gbbasic.Board(3, 4, 0, 0, -1, 0, false) // 룩 행마
if err != nil {
	log.Fatalf("무언가 잘못됐습니다: %v", err)
}
bishop, err := gbbasic.Board(3, 4, 0, 0, -2, 0, false) // 비숍 행마
if err != nil {
	log.Fatalf("무언가 잘못됐습니다: %v", err)
}
g, err := gbbasic.Gunion(rook, bishop, false, false) // 퀸 행마
if err != nil {
	log.Fatalf("무언가 잘못됐습니다: %v", err)
}

@ 각 정점의 이름과, 그 정점에서 나가는 호의 목적지 및 길이를 차례로 찍는다.

@<정점과 간선을 찍는다@>=
fmt.Fprint(out, "Queen Moves on a 3x4 Board\n\n")
fmt.Fprintf(out, "  The graph whose official name is\n%s\n", g.ID)
fmt.Fprintf(out, "  has %d vertices and %d arcs:\n\n", g.N, g.M)
for i := range g.Vertices[:g.N] {
	v := &g.Vertices[i]
	fmt.Fprintf(out, "%s\n", v.Name)
	for a := v.Arcs; a != nil; a = a.Next {
		fmt.Fprintf(out, "  -> %s, length %d\n", a.Tip.Name, a.Len)
	}
}

@* 찾아보기.
