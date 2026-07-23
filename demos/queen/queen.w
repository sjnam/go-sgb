% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 queen.w를 Go로 이식한다.
@i ../../gbtypes.w

\input kotexgweb
\def\title{QUEEN}

@* 퀸의 행마. GraphBase로 그래프를 짓고 훑는 법을 보여 주는 짧은 시연이다.
$3\times4$ 직사각형 판의 열두 칸을 정점으로 삼고, 한 칸에서 다른 칸으로 퀸의
한 수로 갈 수 있으면 두 칸을 이웃으로 본다. 그런 뒤 정점들과 그 이웃을 표준
출력에 찍는다.

\.{queen.gb}라는 ASCII 파일도 함께 만든다. 다른 프로그램은
|gbsave.RestoreGraph("queen.gb")|를 불러 이 퀸 그래프의 사본을 얻을 수 있다.
{\sc QUEEN}의 출력은 사람이 읽으라고, \.{queen.gb}는 컴퓨터가 읽으라고 있는
것이니, 둘을 견주어 보는 것도 흥미롭다.

@ 그런데 퀸 그래프를 어떻게 짓는가? {\sc GB\_\,BASIC}의 |Board|는 일반화된
체스 말의 행마로 판 그래프를 짓는데, 말의 종류를 |piece| 하나로 정한다. 그
규칙은 이렇다.

|piece|가 양수이면, 두 칸 사이의 유클리드 거리가 $\sqrt{|piece|}$일 때만 한
수로 갈 수 있다. 그래서 |piece=1|이면 $(x,y)$에서 $(x,y\pm1)$과 $(x\pm1,y)$로
가는데, 킹과 룩이 둘 다 낼 수 있는 수뿐이라 옛 이슬람 체스에서 와지르라 부르던
말이다. |piece=2|는 $(x\pm1,y\pm1)$ 네 수로, 킹과 비숍이 공유하는 수다.
|piece=5|는 나이트다. 요정 체스 문헌은 이 값들에 이름을 붙여 두었다---와지르 1,
페르스 2, 다바바 4, 나이트 5, 알필 8, 낙타 10, 얼룩말 13, 기린 17 하는 식이다.

|piece|가 음수이면 그 절댓값에 해당하는 기본 수의 임의의 배수가 허용된다.
|piece=-1|은 $(x,y)$에서 $(x\pm a,y)$나 $(x,y\pm a)$로 가는 룩이고,
|piece=-2|는 $(x\pm a,y\pm a)$로 가는 비숍이다($a>0$).

여기서 이 시연의 요령이 나온다. 퀸을 뜻하는 |piece| 값은 없다. 하지만 퀸의
행마는 룩과 비숍의 행마를 합친 것이므로, 룩 판과 비숍 판을 따로 짓고
|gbbasic.Gunion|으로 합집합을 취하면 된다. (같은 요령으로 킹은 |piece|가 1인
판과 2인 판의 합집합이다.) Knuth가 {\sc GB\_\,BASIC}에서 일러 준 이 수법을
그대로 보여 주는 것이 {\sc QUEEN}의 본론이다.

@ 호의 길이도 |piece|의 부호에 달렸다. |piece|가 양수면 모든 호의 길이가 1이고,
음수면 기본 수를 몇 배 했는지가 곧 길이다. 그래서 룩이 한 칸 옆으로 가면 길이
1, 세 칸 옆으로 가면 길이 3이다. 출력에 길이가 섞여 나오는 까닭이 이것이다.

@ 프로그램의 뼈대다. 판 둘을 지어 합치고, 저장하고, 찍는다. 출력이 백 줄
남짓이라 |bufio|로 한 번에 흘려보낸다.

@c
package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	@#
	"github.com/sjnam/go-sgb/gbbasic"
	"github.com/sjnam/go-sgb/gbsave"
)

func main() {
	@<퀸 그래프를 짓는다@>
	if err := gbsave.SaveGraph(g, "queen.gb"); err != nil {
		log.Fatalf("queen.gb를 저장하지 못했습니다: %v", err)
	}
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	@<정점과 간선을 찍는다@>
}

@ 룩 판과 비숍 판의 합집합이 퀸 그래프다. |Board|의 앞 네 인자는 판의 크기로,
0인 차원은 쓰지 않으므로 $3\times4$ 이차원 판이 된다. 마지막 두 인자는 감싸기
여부와 방향성인데, 여기서는 둘 다 쓰지 않는다.

\CEE/ 원본은 세 호출을 잇달아 하고 마지막에 결과가 널인지 한 번만 살펴
|panic_code|를 찍는다. \GO/에서는 생성기마다 오류를 돌려주므로 그때그때 살핀다.

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
정점 이름은 |Board|가 좌표로 지어 준 것이라 $3\times4$ 판의 |0.0|부터 |2.3|까지다.

@<정점과 간선을 찍는다@>=
fmt.Fprint(out, "Queen Moves on a 3x4 Board\n\n")
fmt.Fprintf(out, "  The graph whose official name is\n%s\n", g.ID)
fmt.Fprintf(out, "  has %d vertices and %d arcs:\n\n", g.N, g.M)
for v := range g.AllVertices() {
	fmt.Fprintf(out, "%s\n", v.Name)
	for a := range v.AllArcs() {
		fmt.Fprintf(out, "  -> %s, length %d\n", a.Tip.Name, a.Len)
	}
}

@ 출력은 이렇게 시작한다:
$$\vbox{\halign{\tt#\hfil\cr
Queen Moves on a 3x4 Board\cr
\cr
\ \ The graph whose official name is\cr
gunion(board(3,4,0,0,-1,0,0),board(3,4,0,0,-2,0,0),0,0)\cr
\ \ has 12 vertices and 92 arcs:\cr
\cr
0.0\cr
\ \ -> 1.1, length 1\cr
\ \ -> 2.2, length 2\cr
\ \ -> 0.1, length 1\cr
\ \ -> 0.2, length 2\cr
\ \ -> 0.3, length 3\cr
\ \ -> 1.0, length 1\cr
\ \ -> 2.0, length 2\cr}}$$
표식이 곧 그래프를 지은 방법의 기록이라는 점을 눈여겨보라---|Gunion|이 두 판의
표식을 그대로 품어, 이 그래프가 어디서 왔는지 이름만 보고도 알 수 있다.

첫 정점 |0.0|은 판의 모퉁이다. 거기 선 퀸은 일곱 칸에 닿는다. 대각선으로 |1.1|과
|2.2|, 한 줄을 따라 |0.1|·|0.2|·|0.3|, 다른 줄을 따라 |1.0|과 |2.0|이다. 길이가
1, 2, 3으로 갈리는 것은 앞서 말한 대로 기본 수를 몇 배 했는지를 나타낸다.
열두 정점을 다 합하면 호가 92개, 곧 간선이 46개다.

@ \.{queen.gb}는 같은 그래프를 {\sc GB\_\,SAVE}의 형식으로 적은 것이다. 첫 줄에
|util_types|와 잡아 둔 공간이 오고, 둘째 줄에 표식과 정점 수·호 수가 온 뒤,
정점과 호가 차례로 나온다:
$$\vbox{\halign{\tt#\hfil\cr
* GraphBase graph (util\_types ZZZZZZZZZZZZZZ,16V,102A)\cr
"gunion(board(3,4,0,0,-1,0,0),board(3,4,0,0,-2,0,0),0,0)",12,92\cr
* Vertices\cr
"0.0",A12\cr
"0.1",A26\cr
"0.2",A38\cr}}$$
정점 줄의 |A12|는 그 정점의 호 목록이 호 배열의 12번에서 시작한다는 뜻이다.
사람이 읽으라고 만든 앞의 출력과 견주어 보면, 같은 그래프를 두 가지 눈높이로
적으면 이렇게 달라진다는 것을 한눈에 알 수 있다.

@* 찾아보기.
