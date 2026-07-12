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
	"io"
	"log"
	"os"

	"github.com/sjnam/go-sgb/gbbasic"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbsave"
)

@<퀸 그래프를 짓는다@>@;
@<정점과 간선을 찍는다@>@;

func main() {
	g, err := buildQueen()
	if err != nil {
		log.Fatalf("무언가 잘못됐습니다: %v", err)
	}
	if err := gbsave.SaveGraph(g, "queen.gb"); err != nil {
		log.Fatalf("queen.gb를 저장하지 못했습니다: %v", err)
	}
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	printQueen(out, g)
}

@ 룩 판과 비숍 판의 합집합이 퀸 그래프다. 한 곳에서만 쓰이지만, 시험에서도
직접 부르므로 함수 경계를 둔다.

@<퀸 그래프를 짓는다@>=
func buildQueen() (*gbgraph.Graph, error) {
	rook, err := gbbasic.Board(3, 4, 0, 0, -1, 0, false) // 룩 행마
	if err != nil {
		return nil, err
	}
	bishop, err := gbbasic.Board(3, 4, 0, 0, -2, 0, false) // 비숍 행마
	if err != nil {
		return nil, err
	}
	return gbbasic.Gunion(rook, bishop, false, false) // 퀸 행마
}

@ 각 정점의 이름과, 그 정점에서 나가는 호의 목적지 및 길이를 차례로 찍는다.

@<정점과 간선을 찍는다@>=
func printQueen(out io.Writer, g *gbgraph.Graph) {
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
}

@* 시험. 퀸 그래프의 얼개를 확인한다: 정점 12개, 표식, 그리고 모서리 칸의
퀸 차수(룩 5 + 비숍 2 = 7).

@(queen_test.go@>=
package main

import (
	"strings"
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
)

func degree(v *gbgraph.Vertex) (d int64) {
	for a := v.Arcs; a != nil; a = a.Next {
		d++
	}
	return
}

func TestBuildQueen(t *testing.T) {
	g, err := buildQueen()
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 12 {
		t.Fatalf("N = %d, 원함 12", g.N)
	}
	want := "gunion(board(3,4,0,0,-1,0,0),board(3,4,0,0,-2,0,0),0,0)"
	if g.ID != want {
		t.Errorf("ID = %q", g.ID)
	}
	if d := degree(&g.Vertices[0]); d != 7 {
		t.Errorf("모서리 \"0.0\"의 퀸 차수 = %d, 원함 7", d)
	}
}

@ 출력이 머리글과 정점 이름을 담는지 살핀다.

@(queen_test.go@>=
func TestPrintQueen(t *testing.T) {
	g, err := buildQueen()
	if err != nil {
		t.Fatal(err)
	}
	var sb strings.Builder
	printQueen(&sb, g)
	s := sb.String()
	if !strings.Contains(s, "Queen Moves on a 3x4 Board") {
		t.Error("머리글이 없다")
	}
	if !strings.Contains(s, "has 12 vertices and 92 arcs:") {
		t.Errorf("정점·호 수 줄이 잘못됐다:\n%s", s)
	}
}

@* 찾아보기.
