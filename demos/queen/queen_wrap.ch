% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
%
% 이것은 시연용 "변경 파일"이다. queen이라는 시연 프로그램을 queen_wrap이라는
% 비슷한 시연 프로그램으로 바꾼다.
%
% 변경 파일이 있으면 원본 파일을 건드리지 않고도 GWEB 소스를 고칠 수 있어서,
% 다른 모든 사용자와 온전히 호환된 채로 남는다. 누구나 자기 변경 파일에는
% 무엇이든 마음대로 고쳐 넣을 수 있지만, 원본 파일은 그대로 두기로 되어 있다.
% 이 파일도 변경 파일이라는 발상을 보여 주는 본보기로 남기는 것이 좋겠다.
%
% 변경 파일의 형식은 간단하다. 먼저 @x로 시작하는 줄이 오고, 다음에 원본 파일의
% 어느 줄을 그대로 베낀 줄이 오고, 이어서 원본의 그다음 줄들과 맞아야 하는 줄이
% 0개 이상 온다. 그런 뒤 @y라 적고, 원본의 @x와 @y 사이를 대신할 줄들을 적고,
% 마지막에 @z라 적는다. 모든 변경은 원본에서 바뀌는 자리의 순서대로 와야 하고,
% @x 바로 다음 줄만으로 자리가 하나로 정해져야 한다.
%
% @x, @y, @z 뒤에는 주석을 덧붙일 수 있고, @x-@y-@z 무리 바깥에도 주석을 둘 수
% 있다. 사실 지금 읽고 있는 것이 그런 주석이다.

@x 프로그램 이름을 바꾼다
\def\title{QUEEN}
@y
\def\title{QUEEN\_WRAP}
\def\botofcontents{\vskip 0pt plus 1filll \parskip=0pt
  이 프로그램은 Stanford GraphBase의 {\sc QUEEN}을 변경 파일
  \.{queen\_wrap.ch}로 고쳐 얻은 것이다.\par}
@z

@x 이제 첫 절의 소개말을 손본다
\.{queen.gb}라는 ASCII 파일도 함께 만든다. 다른 프로그램은
|gbsave.RestoreGraph("queen.gb")|를 불러 이 퀸 그래프의 사본을 얻을 수 있다.
{\sc QUEEN}의 출력은 사람이 읽으라고, \.{queen.gb}는 컴퓨터가 읽으라고 있는
것이니, 둘을 견주어 보는 것도 흥미롭다.
@y
여느 체스판과 달리 여기서 다루는 판은 좌우 가장자리에서 ``감싸진다''. 그러니
사실상 원기둥인 셈이다. 위아래로는 감싸지 않는데, 양쪽으로 다 감싸면 하찮은
비숍조차 아무 칸에서 아무 칸으로 그것도 두 가지 길로 갈 수 있게 되기 때문이다.

\.{queen\_wrap.gb}라는 ASCII 파일도 함께 만든다. 다른 프로그램은
|gbsave.RestoreGraph("queen_wrap.gb")|를 불러 이 그래프의 사본을 얻을 수 있다.
{\sc QUEEN\_WRAP}의 출력은 사람이 읽으라고, \.{queen\_wrap.gb}는 컴퓨터가
읽으라고 있는 것이니, 둘을 견주어 보는 것도 흥미롭다.
@z

@x 저장할 파일 이름을 바꾼다
	if err := gbsave.SaveGraph(g, "queen.gb"); err != nil {
		log.Fatalf("queen.gb를 저장하지 못했습니다: %v", err)
@y
	if err := gbsave.SaveGraph(g, "queen_wrap.gb"); err != nil {
		log.Fatalf("queen_wrap.gb를 저장하지 못했습니다: %v", err)
@z

@x 감싸기를 설명하는 말을 보탠다
@ 룩 판과 비숍 판의 합집합이 퀸 그래프다. |Board|의 앞 네 인자는 판의 크기로,
0인 차원은 쓰지 않으므로 $3\times4$ 이차원 판이 된다. 마지막 두 인자는 감싸기
여부와 방향성인데, 여기서는 둘 다 쓰지 않는다.
@y
@ 룩 판과 비숍 판의 합집합이 퀸 그래프다. |Board|의 앞 네 인자는 판의 크기로,
0인 차원은 쓰지 않으므로 $3\times4$ 이차원 판이 된다.

끝에서 둘째 인자 |wrap|은 어느 좌표가 감싸지는지를 비트로 고른다. 비트 $2^{k-1}$이
켜져 있으면 $k$번째 좌표를 그 크기로 나눈 나머지로 셈한다. 우리는 둘째
좌표(열)만 감싸고 싶으므로 |wrap=2|다. 마지막 인자는 방향성인데 여기서도 쓰지
않는다.

감싸기는 칸의 개수를 늘리지 않는다. 늘어나는 것은 이웃 관계다. 원기둥 위에서는
왼쪽 끝과 오른쪽 끝이 맞붙으므로 룩이 한 걸음에 판을 돌아 나올 수 있고, 비숍의
대각선도 옆구리를 지나 이어진다.
@z

@x 감싸기를 켠다
rook, err := gbbasic.Board(3, 4, 0, 0, -1, 0, false) // 룩 행마
@y
rook, err := gbbasic.Board(3, 4, 0, 0, -1, 2, false) // 감싸는 룩 행마
@z

@x
bishop, err := gbbasic.Board(3, 4, 0, 0, -2, 0, false) // 비숍 행마
@y
bishop, err := gbbasic.Board(3, 4, 0, 0, -2, 2, false) // 감싸는 비숍 행마
@z

@x 머리글도 바꾼다
fmt.Fprint(out, "Queen Moves on a 3x4 Board\n\n")
@y
fmt.Fprint(out, "Queen Moves on a Cylindrical 3x4 Board\n\n")
@z

@x 출력 보기를 감싸는 판의 것으로 갈아 끼운다
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
@y
@ 출력은 이렇게 시작한다:
$$\vbox{\halign{\tt#\hfil\cr
Queen Moves on a Cylindrical 3x4 Board\cr
\cr
\ \ The graph whose official name is\cr
gunion(board(3,4,0,0,-1,2,0),board(3,4,0,0,-2,2,0),0,0)\cr
\ \ has 12 vertices and 100 arcs:\cr
\cr
0.0\cr
\ \ -> 1.1, length 1\cr
\ \ -> 1.3, length 1\cr
\ \ -> 2.2, length 2\cr
\ \ -> 0.1, length 1\cr
\ \ -> 0.2, length 2\cr
\ \ -> 0.3, length 1\cr
\ \ -> 1.0, length 1\cr
\ \ -> 2.0, length 2\cr}}$$
표식이 감싸기까지 기억한다는 점을 눈여겨보라. |wrap| 자리에 2가 찍혀 있어,
이름만 보고도 이것이 원기둥 판임을 알 수 있다.

모퉁이 |0.0|에 선 퀸이 이제 여덟 칸에 닿는다. 감싸지 않던 판에서보다 하나
늘었는데, 새로 생긴 것은 판을 돌아 나가는 대각선 |1.3|이다. |0.3|의 길이가
3에서 1로 줄어든 것도 눈에 띈다---원기둥에서는 |0.0|의 바로 왼쪽이 |0.3|이므로
룩이 한 걸음이면 닿는다.

대각선이 왜 하나만 느는지 따져 보면 감싸기의 성질이 드러난다. 비숍의 수는
$(x\pm a,\,y\pm a)$인데 행은 감싸지 않으므로 $x$가 $0$에서 줄어들 수는 없다.
그래서 $(1,1)$과 $(2,2)$ 말고 새로 얻는 것은 열만 감싸는 $(1,-1)\equiv(1,3)$
하나다. $(2,-2)$는 $(2,2)$와 같은 칸이라 셈에 보태지 않는다. 열두 정점을 다
합하면 호가 100개, 곧 간선이 50개다---감싸지 않을 때보다 넷이 늘었다.
@z

@x 저장 파일의 보기도 갈아 끼운다
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
@y
@ \.{queen\_wrap.gb}는 같은 그래프를 {\sc GB\_\,SAVE}의 형식으로 적은 것이다.
첫 줄에 |util_types|와 잡아 둔 공간이 오고, 둘째 줄에 표식과 정점 수·호 수가
온 뒤, 정점과 호가 차례로 나온다:
$$\vbox{\halign{\tt#\hfil\cr
* GraphBase graph (util\_types ZZZZZZZZZZZZZZ,16V,102A)\cr
"gunion(board(3,4,0,0,-1,2,0),board(3,4,0,0,-2,2,0),0,0)",12,100\cr
* Vertices\cr
"0.0",A14\cr
"0.1",A28\cr
"0.2",A40\cr}}$$
정점 줄의 |A14|는 그 정점의 호 목록이 호 배열의 14번에서 시작한다는 뜻이다.
감싸지 않는 판에서는 이 자리가 |A12|였다---|0.0|의 호가 일곱에서 여덟으로
늘었으니 뒤따르는 정점들의 자리도 그만큼씩 밀린다. 사람이 읽으라고 만든 앞의
출력과 견주어 보면, 같은 그래프를 두 가지 눈높이로 적으면 이렇게 달라진다는
것을 한눈에 알 수 있다.
@z

% 변경 파일은 보통 원본 파일보다 훨씬 짧지만, 이 파일은 예외다. 원본 자체가
% 짧은 데다 우리는 실제 출력까지 문서에 실어 두었기 때문이다. 같은 원본에
% 서로 다른 변경 파일을 얼마든지 물릴 수 있다.
%
% queen_wrap 프로그램을 돌리려면 이렇게 한다:
%   gtangle -o ../queen_wrap queen.w queen_wrap.ch
%   go build -o queen_wrap ../queen_wrap
% 저장소 루트에서라면 make queen_wrap 한 줄이면 된다.
%
% 조판한 문서를 얻으려면 이렇게 한다:
%   gweave -o ../queen_wrap queen.w queen_wrap.ch
%   (cd ../queen_wrap && luatex queen.tex)
