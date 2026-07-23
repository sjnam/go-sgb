% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_books.w를 Go로 이식한다.
@i ../gbtypes.w

\input kotexgweb
\def\title{GB\_\,BOOKS}
\def\<#1>{\hbox{$\langle$\rm#1$\rangle$}}

@* 들어가며. 이 모듈은 고전 문학 작품에 바탕한 무향 그래프 집안을 짓는 |Book|
서브루틴과, 그와 짝을 이루는 이분 그래프를 짓는 |BiBook| 서브루틴을 담는다.
쓰임새는 {\sc BOOK\_COMPONENTS} 데모에서 볼 수 있다.

|Book(title, n, x, firstChapter, lastChapter, inWeight, outWeight, seed, dir)|은
\<title>\/\.{.dat}의 정보로 그래프를 짓는다. \<title>\/은 |"anna"|({\sl Anna
Karenina\/}), |"david"|({\sl David Copperfield\/}), |"jean"|({\sl Les
Mis\'erables\/}), |"huck"|({\sl Huckleberry Finn\/}), |"homer"|({\sl The
Iliad\/}) 가운데 하나다. 각 정점은 그 책의 한 등장인물이고, 두 정점 사이의
간선은 그 인물들의 마주침(encounter)을 뜻한다. 간선 길이는 모두 1이다.

@ 간선 자료를 |firstChapter|부터 |lastChapter|까지의 장(chapter)으로 한정해
책의 일부만 잘라 쓸 수 있다. |firstChapter|가 0이면 1을 준 것과 같고,
|lastChapter|가 0이거나 그 책의 전체 장 수를 넘으면 마지막 장을 준 것과 같다.

그래프는 $\min(n,N)-x$개의 정점을 갖는데, $N$은 그 책의 전체 인물 수다.
|n|이 0이면 자동으로 최댓값 $N$이 된다. |n|이 $N$보다 작으면, 인물마다 무게를
매겨 가장 무거운 |n|명을 고른 뒤 그중 가장 무거운 |x|명을 다시 빼서 |n-x|명을
얻는다. 무게가 같아 순위를 가릴 수 없을 때는 난수로 정한다. 무게는
$$|inWeight|\cdot\\{chaptersIn}+|outWeight|\cdot\\{chaptersOut}$$
로 셈하는데, \\{chaptersIn}은 그 인물이 |firstChapter|와 |lastChapter| 사이의
장에서 나오는 장 수, \\{chaptersOut}은 그 밖의 장에서 나오는 장 수다. 두 무게
계수는 절댓값이 1,000,000 이하여야 한다.

그래프의 정점은 무게가 줄어드는 차례로 놓인다. |seed| 매개변수는 무게가 같은
정점 사이에서 ``무작위'' 선택을 해야 할 때 쓰는 유사난수를 정한다. GraphBase의
다른 루틴들처럼, |seed|를 달리하면 대체로 다른 선택이 나오되 그 방식은
기계에 무관하다 --- 같은 매개변수를 주면 어떤 컴퓨터에서도 똑같은 결과가
나온다. |seed|는 0 이상 $2^{31}-1$ 이하면 무엇이든 좋다.

@ 보기를 들어 보자. |Book("anna",0,0,0,0,0,0,0,"")|은 \.{anna.dat}에 적힌
톨스토이 {\sl Anna Karenina\/}의 138개 인물 모두를 정점으로 하는 그래프를
짓는다. 두 정점은 그 인물들이 책 어디에서든 마주치면 인접하다.

|Book("anna",50,0,0,0,1,1,0,"")|도 비슷하되, 가장 자주---즉 가장 많은 장에---
나오는 인물 50명으로 한정한다. |Book("anna",50,0,10,120,1,1,0,"")|은 정점은
그대로이고 간선만 10장부터 120장 사이의 마주침으로 제한한다.

|Book("anna",50,0,10,120,1,0,0,"")|은 또 비슷하되, 정점이 ``10장부터 120장에
가장 자주 나오는 50명''이다---나머지 장에 얼마나 나오든 아랑곳하지 않는다.
|Book("anna",50,0,10,120,0,0,0,"")|도 비슷한데, 두 무게 계수가 모두 0이라
무게가 전부 같아지므로 인물 50명을 완전히 무작위로 고른다(고른 장에 아예
나오지 않는 인물이 뽑힐 수도 있다).

@ 무게가 가장 큰 정점 |x|개를 빼는 매개변수 |x|는 대개 0이나 1이다. 이것을
둔 까닭은 주로 {\sl David Copperfield\/}와 {\sl Huckleberry Finn\/} 때문이다.
두 소설은 주인공이 화자라서, 주인공과 나머지 거의 모두 사이에 간선이 생긴다.
(1인칭 서술에서는 화자와 마주치거나 화자가 남의 이야기를 옮겨 적지 않는 한
어떤 인물도 이야기에 끼어들 수가 없다.) 그래서 |x=1|로 화자를 빼면 연결
구조가 한결 흥미로워진다. 예컨대 {\sl David Copperfield\/}에는 인물이
87명인데, |Book("david",0,1,0,0,1,1,0,"")|은 David Copperfield 자신만 빼고
86개 정점을 가진 그래프를 낳는다.

@ |BiBook|은 |Book|과 같은 매개변수를 받아, 첫 갈래의 정점이 |Book|이 낳는
그래프의 정점과 똑같고 둘째 갈래의 정점은 고른 장들인 이분 그래프를 낳는다.
예컨대 |BiBook("anna",50,0,10,120,1,1,0,"")|은 $50+111$개 정점의 이분
그래프를 만든다. 각 인물과 그 인물이 나오는 장 사이에 간선이 하나씩 생긴다.

@ 장 번호에는 설명이 좀 더 필요하다. {\sl Anna Karenina\/}는 작품 자체에서는
1.1부터 8.19까지 번호가 붙은 239개의 장으로 이루어져 있는데, |Book| 루틴이
보기에는 1부터 239까지로 다시 매겨진 것이다. 그러니 |firstChapter=10|,
|lastChapter=120|은 결국 1.10부터 4.19까지---더 정확히는 1권 10장부터 4권
19장까지---를 고르는 셈이다. {\sl Les Mis\'erables\/}는 더 복잡해서, 356개의
장이 1.1.1(1부 1권 1장)부터 5.9.6(5부 9권 6장)까지 뻗는다.

\CEE/ 원본은 그래프를 다 짓고 나면 외부 변수 |chapters|에 전체 장 수를,
배열 |chap_name|에 그 구조적 장 번호 문자열들을 남겼다. |book("jean",\ldots)|
뒤에는 |chapters=356|, |chap_name[1]="1.1.1"|, \dots, |chap_name[356]="5.9.6"|
이 되는 식이었다. 우리는 패키지 수준 가변 상태를 두지 않으므로 이 둘을 밖에
내놓지 않고 |bookBuilder| 안에 감춘다. 다만 장 이름이 정말 필요한 쓰임새---
|BiBook|이 만든 장 정점---에서는 그 이름이 정점의 |Name|으로 그대로 남으니,
쓰는 쪽이 아쉬울 일은 별로 없다.

@ 원본은 문제가 생기면 |NULL|을 돌려주고 외부 변수 |panic_code|에 실패의
종류를 적었다. \GO/에서는 그 대신 |error|를 돌려주는데, 값은
{\sc GB\_\,GRAPH}가 정의한 |gbgraph.PanicCode| 상수들이다. 그래서 원본의
|panic(c)| 매크로 자리마다 |return nil, c|가 놓인다.

@ 프로그램의 뼈대다. \CEE/ 원본은 정적 전역 |node_block|·|xnode|·|chap_name|과
외부 변수 |chapters|를 두지만, 우리는 패키지 수준 가변 상태를 피해 이들을
|bookBuilder| 구조체에 담는다. |Book|과 |BiBook|은 안쪽 |bgraph|를 부르는데,
|bgraph|가 두 루틴의 일을 겸한다.
@c
package gbbooks

import (
	"fmt"
	"path/filepath"
	"strings"
	@#
	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/gbsort"
)

const	DataDirectory = "/usr/local/sgb/data"

@<상수 정의@>
@<자료 구조@>
@<|Book|과 |BiBook|@>
@<|bgraph|와 그 도우미@>

@ 어떤 책도 이만큼 많지는 않을 상한들이다. |weightBias|가 왜 $2^{30}$인지는
뒤에 무게를 셈할 때 설명한다.

@<상수 정의@>=
const (
	maxChaps   = 360        // 어떤 책도 이만큼 장이 많지 않다
	maxChars   = 600        // 인물도 이만큼 많지 않다
	maxCode    = 1296       // $36\times36$, 36진법 두 자리 코드의 수
	weightBias = 1 << 30    // 무게를 음이 아닌 정렬 키로 만드는 치우침
	cliqueMax  = 30         // 한 클릭에 담기는 정점 수의 상한
	maxWeight  = 1000000    // 무게 계수의 절댓값 상한
)

@ |bookBuilder|는 짓고 있는 그래프와 작업 상태를 한데 묶는다. |nodes|는 용량을
|maxChars|로 미리 잡아, 뒤에 원소를 더해도 재할당되지 않게 한다---그래야
|xnode|가 담은 포인터가 그대로 유효하다. \CEE/ 원본이 |node_block|을 고정 크기
배열로 잡아 두고 그 안을 포인터로 걸어 다닌 것과 같은 사정이다.

@<자료 구조@>=
type bookBuilder struct {
	g          *gbgraph.Graph
	rng        *gbflip.RNG
	bipartite  bool
	fileName   string
	nodes      []gbsort.Node[charInfo]
	xnode      map[int64]*gbsort.Node[charInfo]
	characters int64
	chapters   int64
	chapName   []string // 1번부터 쓰는 장 이름 배열
	chapBase   int64    // 이분 그래프에서 장 정점의 색인 치우침
	seed       int64    // 표식에 쓸 난수 씨앗
	n, x, firstChapter, lastChapter, inWeight, outWeight int64
}

@ |Book|과 |BiBook|은 그저 |bgraph|를 |bipartite| 깃발만 달리해 부른다.

@<|Book|과 |BiBook|@>=
// |Book|은 책의 인물 마주침을 무향 그래프로 짓는다.
func Book(title string, n, x, firstChapter, lastChapter, inWeight, outWeight, seed int64,
	dir string) (*gbgraph.Graph, error) {
	if dir == "" {
		dir = DataDirectory
	}
	b := newBuilder(false)
	return b.bgraph(title, n, x, firstChapter, lastChapter, inWeight, outWeight, seed, dir)
}

// |BiBook|은 인물과 장 사이의 이분 그래프를 짓는다.
func BiBook(title string, n, x, firstChapter, lastChapter, inWeight, outWeight, seed int64,
	dir string) (*gbgraph.Graph, error) {
	if dir == "" {
		dir = DataDirectory
	}
	b := newBuilder(true)
	return b.bgraph(title, n, x, firstChapter, lastChapter, inWeight, outWeight, seed, dir)
}

@ @<|Book|과 |BiBook|@>=
func newBuilder(bipartite bool) *bookBuilder {
	return &bookBuilder{
		bipartite: bipartite,
		nodes:     make([]gbsort.Node[charInfo], 0, maxChars),
		xnode:     make(map[int64]*gbsort.Node[charInfo]),
		chapName:  make([]string, maxChaps),
	}
}

@ |bgraph|는 씨앗으로 난수 스트림을 열고, 매개변수를 다듬고, 자료 파일을 두 번
읽는다: 한 번은 빠르게(통계 수집), 한 번은 꼼꼼히(정점 이름과 간선).

@<|bgraph|와 그 도우미@>=
func (b *bookBuilder) bgraph(title string, n, x, firstChapter, lastChapter,
	inWeight, outWeight, seed int64, dir string) (*gbgraph.Graph, error) {
	b.rng = gbflip.New(seed)
	b.seed = seed
	b.n, b.x = n, x
	b.firstChapter, b.lastChapter = firstChapter, lastChapter
	b.inWeight, b.outWeight = inWeight, outWeight
	@<매개변수가 올바른지 확인한다@>
	if err := b.skim(); err != nil {
		return nil, err
	}
	@<정점을 골라 빈 그래프에 넣는다@>
	if err := b.fill(); err != nil {
		return nil, err
	}
	return b.g, nil
}

@ |n==0|은 최대치로, |firstChapter==0|은 1로, |lastChapter==0|은 최대치로 바꾼다.
파일 이름은 제목의 앞 여섯 글자에 \.{.dat}을 붙인 것이다---원본의
|sprintf(file_name,"%.6s.dat",title)|이 하던 일이다.

@<매개변수가 올바른지 확인한다@>=
if b.n == 0 {
	b.n = maxChars
}
if b.firstChapter == 0 {
	b.firstChapter = 1
}
if b.lastChapter == 0 {
	b.lastChapter = maxChaps
}
if b.inWeight > maxWeight || b.inWeight < -maxWeight ||
	b.outWeight > maxWeight || b.outWeight < -maxWeight {
	return nil, gbgraph.BadSpecs // 무게가 너무 크다
}
t := title
if len(t) > 6 {
	t = t[:6]
}
b.fileName = filepath.Join(dir, t+".dat")

@* 정점. 책의 인물마다 안에서 쓸 두 글자 코드 이름이 붙어 있다. 코드 이름은
각 자료 파일 첫머리에 이런 꼴의 줄들로 설명된다:
$$\hbox{\tt XX \<name>,\<description>}$$
예컨대 \.{anna.dat} 첫머리 가까이에 있는 한 줄은 이렇다:
$$\hbox{\tt AL Alexey Alexandrovitch Karenin, minister of state}$$
\<name>\/에는 콤마가 들어가지 않지만 \<description>\/에는 들어갈 수 있다.
그래서 이름은 첫 콤마까지 읽으면 된다. 인물 목록 다음에는 빈 줄이 하나 온다.

@ 안에서는 두 글자 코드를 36진법 정수로 여긴다. 그러니 \.{AA}는
$10\times36+10$이고 \.{ZZ}는 $35\times36+35$다. {\sc GB\_\,IO}의 |Number|
루틴은 16진법을 읽듯 36진법 정수도 읽도록 되어 있어, 코드를 곧바로 수로
받을 수 있다. 코드 \.{00}은 쓰이지 않으므로 0이 읽히면 인물 목록의 끝이다.

{\sl The Iliad\/}에서는 조연들 상당수의 코드 이름에 숫자가 섞여 있다.
인물이 561명이나 되어 모두에게 기억하기 좋은 코드를 줄 수가 없었기 때문이다.

@ 정점을 고르려면 인물마다 무게에 해당하는 키를 가진 노드로 나타내야 한다.
그러면 {\sc GB\_\,SORT}의 |LinkSort|가 원하는 순위 매김을 해 준다. 이 노드는
|bgraph|가 하는 모든 자료 처리에 두루 쓰기에도 편하다.

|code|는 36진법 두 자리 코드, |in|·|out|은 선택 구간 안팎의 등장 장 수,
|chap|은 가장 최근에 본 장(한 장에서 두 번 세지 않으려는 것), |vert|는 이
인물에 배정된 정점이다.

@<자료 구조@>=
type charInfo struct {
	code    int64
	in, out int64
	chap    int64
	vert    *gbgraph.Vertex
}

@ 노드가 코드를 가리킬 뿐 아니라, 코드가 노드를 가리키게도 하고 싶다. 원본은
|MAX_CODE|개짜리 포인터 배열 |xnode|를 썼지만, 우리는 |map|을 쓴다. 쓰이는
코드는 기껏해야 600개 남짓이라 1296칸 배열이 아깝기도 하고, 없는 코드가
|nil|로 나오는 것도 그대로다.

@ 자료 파일은 두 번 읽는다. 한 번은 빠르게(통계 수집), 한 번은 꼼꼼히(자세한
정보 기록). 여기가 빠른 쪽이다.

@<|bgraph|와 그 도우미@>=
func (b *bookBuilder) skim() error {
	f, err := gbio.Open(b.fileName)
	if err != nil {
		return gbgraph.EarlyDataFault // 파일을 열 수 없다
	}
	@<파일 첫머리의 인물 코드를 읽어 노드를 만든다@>
	@<장 정보를 훑어 각 인물의 등장 장 수를 센다@>
	if f.Close() != nil {
		return gbgraph.LateDataFault // 검사합 등 실패
	}
	return nil
}

@ 코드 다음에는 빈칸 하나가 온다. 이 훑기에서는 이름도 설명도 건너뛰고
코드만 챙긴다.

@<파일 첫머리의 인물 코드를 읽어 노드를 만든다@>=
for c := f.Number(36); c != 0; c = f.Number(36) {
	if c >= maxCode || f.Char() != ' ' {
		return gbgraph.SyntaxError // 읽을 수 없는 줄
	}
	if int64(len(b.nodes)) >= maxChars {
		return gbgraph.SyntaxError + 1 // 인물이 너무 많다
	}
	b.nodes = append(b.nodes, gbsort.Node[charInfo]{Data: charInfo{code: c}})
	b.xnode[c] = &b.nodes[len(b.nodes)-1]
	f.NextLine()
}
b.characters = int64(len(b.nodes))
f.NextLine() // 인물 자료를 끝맺는 빈 줄을 건너뛴다

@ 뒤에 이 부분을 다시 읽으면서, 쓸모가 있다면 더 많은 정보를 뽑아낸다.
\<description>\/ 문자열은 혹시 들여다볼 사람이 있을까 하여 |desc| 필드로
내어 준다. |in|과 |out| 통계도 |in_count|와 |out_count|라는 유틸리티 필드로
내어 주고, 코드 값은 |short_code| 필드에 둔다. 원본이 매크로로 붙인 이 이름들이
\GO/에서는 이렇게 대응한다:
$$\vbox{\halign{\hfil#\hfil&\quad#\hfil&\quad#\hfil\cr
원본&\GO/&뜻\cr
\noalign{\smallskip\hrule\smallskip}
|desc|&|Z.S|&\<description> 문자열\cr
|in_count|&|Y.I|&고른 장에서의 등장 장 수\cr
|out_count|&|X.I|&그 밖의 장에서의 등장 장 수\cr
|short_code|&|U.I|&36진법 코드\cr
|chap_no|&|A.I|&(호) 그 간선을 낳은 장 번호\cr}}$$
이 배치가 곧 |UtilTypes| 문자열 |"IZZIISIZZZZZZZ"|가 뜻하는 바다.

@ 두 번째 읽기(꼼꼼한 읽기)다. 파일을 다시 열어, 고른 인물의 이름과 설명을
적고, 그래프의 간선을 만든다.

@<|bgraph|와 그 도우미@>=
func (b *bookBuilder) fill() error {
	f, err := gbio.Open(b.fileName)
	if err != nil {
		return gbgraph.Impossible + 1 // 앞서 성공했으니 있을 수 없다
	}
	@<인물 자료를 다시 읽어 정점 이름과 설명을 적는다@>
	if b.bipartite {
		@<장 정보를 다시 읽어 이분 간선을 만든다@>
	} else {
		@<장 정보를 다시 읽어 마주침 간선을 만든다@>
	}
	if f.Close() != nil {
		return gbgraph.Impossible + 2
	}
	return nil
}

@ 고른 인물(|vert|이 |nil|이 아닌)에만 이름·설명과 통계를 적는다. 뽑히지
않은 인물의 줄은 그냥 지나친다.

@<인물 자료를 다시 읽어 정점 이름과 설명을 적는다@>=
for c := f.Number(36); c != 0; c = f.Number(36) {
	p := b.xnode[c]
	if v := p.Data.vert; v != nil {
		if f.Char() != ' ' {
			return gbgraph.Impossible
		}
		v.Name = f.String(',') // 이름 부분
		if f.Char() != ',' {
			return gbgraph.SyntaxError + 2 // 이름 뒤 콤마가 없다
		}
		if f.Char() != ' ' {
			return gbgraph.SyntaxError + 3 // 콤마 뒤 빈칸이 없다
		}
		v.Z.S = f.String('\n')  // 설명 부분(|desc|)
		v.Y.I = p.Data.in       // |in_count|
		v.X.I = p.Data.out      // |out_count|
		v.U.I = c               // |short_code|
	}
	f.NextLine()
}
f.NextLine()

@* 간선. 자료 파일의 둘째 부분은 장마다 한 줄씩, ``마주침의
클릭(clique)''들을 담는다. 예컨대 다음 줄은
$$\hbox{\tt3.22:AA,BB,CC,DD;CC,DD,EE;AA,FF}$$
3권 22장에서 다음 쌍들이 마주쳤다는 뜻이다:
$$\def\\{{\rm,} }
\hbox{\tt AA-BB\\AA-CC\\AA-DD\\BB-CC\\BB-DD\\CC-DD\\CC-EE\\DD-EE\\{\rm 그리고 }%
AA-FF\rm.}$$
즉 세미콜론으로 나뉜 각 덩이가 하나의 클릭이고, 클릭 안의 모든 쌍이 서로
마주친 것으로 친다. (\.{CC-DD}는 클릭 \.{AA,BB,CC,DD}와 \.{CC,DD,EE}에서
두 번 나오는데, 그렇다고 그 장에서 \.{CC}와 \.{DD}가 실제로 몇 번 마주쳤는지에
대해 뭔가를 뜻하지는 않는다.)

@ 이 형식에는 잔가지가 셋 있다.

클릭에 인물이 하나뿐일 수도 있다. 그 인물이 일종의 독백(soliloquy)을 하는
경우다.

어떤 장에는 인물에 대한 언급이 아예 없을 수도 있다. 그럴 때는 장 번호 뒤의
`\.:'가 생략된다. \.{jean.dat}에는 그런 장이 68개나 있다(이를테면 \.{1.2.8}).

한 줄에 다 담기지 않을 만큼 마주침이 많을 수도 있다. 그럴 때 이어지는 줄은
`\.{\&:}'로 시작한다. 이 관례가 필요한 곳은 \.{homer.dat}뿐이다({\sl The
Iliad\/}의 장은 다른 GraphBase 책들의 장보다 훨씬 복잡하다---\.{homer.dat}에
그런 이어짐 줄이 84개 있다).

@ 자료를 처음 훑을 때는 누가 어느 장에 나오는지 통계만 내면 되므로,
콤마와 세미콜론의 구별을 무시한다. 즉 클릭의 경계는 신경 쓰지 않는다.

@<장 정보를 훑어 각 인물의 등장 장 수를 센다@>=
k := int64(1)
for ; k < maxChaps && !f.EOF(); k++ {
	s := f.String(':') // 장 번호를 지나쳐 읽는다
	if len(s) > 0 && s[0] == '&' {
		k-- // 앞 장의 이어짐
	}
	@<이 장에 나오는 인물들의 등장 수를 센다@>
	f.NextLine()
}
if k == maxChaps {
	return gbgraph.SyntaxError + 6 // 장이 너무 많다
}
b.chapters = k - 1

@ 줄 끝(|'\n'|)까지, 구분자와 코드를 번갈아 읽는다. 한 인물을 한 장에서 처음
볼 때만 센다---그것이 |chap| 필드가 하는 일이다.

@<이 장에 나오는 인물들의 등장 수를 센다@>=
for f.Char() != '\n' {
	c := f.Number(36)
	if c >= maxCode {
		return gbgraph.SyntaxError + 4 // 인물 사이 구두점이 없다
	}
	p := b.xnode[c]
	if p == nil {
		return gbgraph.SyntaxError + 5 // 모르는 인물
	}
	if p.Data.chap != k {
		p.Data.chap = k
		if k >= b.firstChapter && k <= b.lastChapter {
			p.Data.in++
		} else {
			p.Data.out++
		}
	}
}

@ 장 이름의 |'\n'|을 떼어 저장하는 잔심부름이다. |'&'| 이어짐 줄이면 저장하지
않는다---그 장의 이름은 앞줄에서 이미 적혔다.

@<|bgraph|와 그 도우미@>=
func (b *bookBuilder) noteChapter(k int64, s string) (cont bool) {
	if len(s) > 0 && s[0] == '&' {
		return true
	}
	b.chapName[k] = strings.TrimSuffix(s, "\n")
	return false
}

@ 두 번째 읽기는, 마주침을 클릭에서 뽑아내야 하는 만큼 첫 번째보다 좀 더
일해야 한다. 그래도 논리가 어렵지는 않다. 각 간선을 처음 낳은 장 번호를
해당 |Arc| 레코드의 유틸리티 필드 |chap_no|에 적어 둔다.

@<장 정보를 다시 읽어 마주침 간선을 만든다@>=
clique := make([]*gbgraph.Vertex, 0, cliqueMax)
for k := int64(1); !f.EOF(); k++ {
	if b.noteChapter(k, f.String(':')) {
		k--
	}
	if k >= b.firstChapter && k <= b.lastChapter {
		@<이 장의 클릭들을 읽어 정점 쌍을 잇는다@>
	}
	f.NextLine()
}

@ 클릭은 콤마로 이어진 코드들이고, 세미콜론이나 줄 끝으로 끝난다. 클릭 하나를
다 읽으면 그 안의 모든 쌍을 인접하게 만든다. 뽑히지 않은 인물은 |vert|이
|nil|이므로 클릭에 담지 않는다.

@<이 장의 클릭들을 읽어 정점 쌍을 잇는다@>=
c := f.Char() // 장 번호 뒤의 |':'|
for c != '\n' {
	clique = clique[:0]
	for {
		if v := b.xnode[f.Number(36)].Data.vert; v != nil {
			clique = append(clique, v)
		}
		c = f.Char()
		if c != ',' {
			break
		}
	}
	@<클릭 안 모든 쌍을 잇는다@>
}

@ @<클릭 안 모든 쌍을 잇는다@>=
for qi := 0; qi+1 < len(clique); qi++ {
	for ri := qi + 1; ri < len(clique); ri++ {
		b.makeAdjacent(clique[qi], clique[ri], k)
	}
}

@ 두 정점이 아직 이웃이 아니면 간선을 만들고, 간선을 이루는 두 호의 |chap_no|를
현재 장 번호로 적는다. 원본은 |u<v|인지 보아 |u->arcs|와 |v->arcs| 가운데
어느 것이 짝의 앞쪽인지 가렸지만, 우리는 |gbgraph|의 |Partner|가 그 일을
대신해 주므로 방금 만든 호와 그 짝을 곧바로 짚는다.

@<|bgraph|와 그 도우미@>=
func (b *bookBuilder) makeAdjacent(u, v *gbgraph.Vertex, k int64) {
	for a := range u.AllArcs() {
		if a.Tip == v {
			return // 이미 이웃이다
		}
	}
	b.g.NewEdge(u, v, 1)
	a := u.Arcs // 방금 만든 호와 그 짝
	a.A.I, a.Partner.A.I = k, k
}

@ 이분 그래프를 셈할 때의 두 번째 읽기는 첫 번째와 매우 비슷하다. 고른 장과
그 장에 나오는 고른 인물 사이마다 간선을 하나 놓으면 된다. |chapBase|는
장 |k|의 정점이 |Vertices[chapBase+k]|가 되도록 잡은 치우침이다.

장 정점의 |in_count|는 그 정점의 차수, 곧 그 장에 나오는 고른 인물의 수다.
|out_count|는 그 장에 나오지만 그래프에서 빠진 인물의 수다. 그러니 장의
|in_count|·|out_count|는 인물의 그것과 서로 닮은꼴이다.

@<장 정보를 다시 읽어 이분 간선을 만든다@>=
for i := int64(0); i < b.characters; i++ {
	b.nodes[i].Data.chap = 0
}
for k := int64(1); !f.EOF(); k++ {
	cont := b.noteChapter(k, f.String(':'))
	if cont {
		k--
	}
	if k >= b.firstChapter && k <= b.lastChapter {
		@<이 장의 이분 간선을 만든다@>
	}
	f.NextLine()
}

@ 이어짐 줄이 아닐 때만 장 정점의 이름과 통계를 새로 매긴다.

@<이 장의 이분 간선을 만든다@>=
u := &b.g.Vertices[b.chapBase+k]
if !cont {
	u.Name = b.chapName[k]
	u.Z.S = "" // 설명은 빈 문자열
	u.Y.I, u.X.I = 0, 0
}
for f.Char() != '\n' {
	p := b.xnode[f.Number(36)]
	if p.Data.chap != k {
		p.Data.chap = k
		if v := p.Data.vert; v != nil {
			b.g.NewEdge(v, u, 1)
			u.Y.I++ // |in_count|
		} else {
			u.X.I++ // |out_count|
		}
	}
}

@* 마무리. 이제 자잘한 관리 사항 몇 가지만 빼면 프로그램은 다 됐다.
그건 점심 먹고 마저 하겠다.
@^점심 먹으러 나감@>

@ 자, 돌아왔다. 뭘 해야 했더라? 가장 중요한 건 그래프 자체를 만드는 일이다.
먼저 매개변수를 실제 자료에 맞춰 다듬는다. 이제야 |characters|와 |chapters|를
알기 때문에, |n|과 |lastChapter|를 여기서 비로소 잘라 낼 수 있다.

@<정점을 골라 빈 그래프에 넣는다@>=
if b.n > b.characters {
	b.n = b.characters
}
if b.x > b.n {
	b.x = b.n
}
if b.lastChapter > b.chapters {
	b.lastChapter = b.chapters
}
if b.firstChapter > b.lastChapter {
	b.firstChapter = b.lastChapter + 1
}
@<빈 그래프를 마련하고 표식을 짓는다@>
@<무게를 셈해 고른 노드에 정점을 배정한다@>

@ 이분 그래프이면 인물 |n-x|명 뒤에 고른 장 수만큼 정점을 더 둔다. 표식은
원본과 같은 꼴이라 |bi_|가 앞에 붙느냐로 두 루틴을 가른다.

@<빈 그래프를 마련하고 표식을 짓는다@>=
size := b.n - b.x
if b.bipartite {
	size += b.lastChapter - b.firstChapter + 1
}
b.g = gbgraph.NewGraph(size)
b.g.UtilTypes = "IZZIISIZZZZZZZ"
prefix := ""
if b.bipartite {
	prefix = "bi_"
}
b.g.ID = fmt.Sprintf("%sbook(%q,%d,%d,%d,%d,%d,%d,%d)", prefix, b.title(),
	b.n, b.x, b.firstChapter, b.lastChapter, b.inWeight, b.outWeight, b.seed)
if b.bipartite {
	b.g.MarkBipartite(b.n - b.x)
	b.chapBase = b.g.N1() - b.firstChapter
}

@ 무게에 |weightBias|$\,=2^{30}$을 더해 정렬 키로 삼는다. 무게 자체는 음수일
수 있는데(무게 계수가 음수일 수 있으므로) |LinkSort|는 $2^{31}$보다 작은 음이
아닌 키를 요구하기 때문이다. 치우침이 $2^{30}$이면 넉넉하다: 무게의 절댓값은
많아야 $2\times10^6\times360=7.2\times10^8$인데 이것은 $2^{30}$보다 작으므로,
키는 언제나 $0$과 $2^{31}$ 사이에 머문다.

정렬 리스트는 \CEE/처럼 마지막 노드가 머리이고 |Link|가 앞 노드를 가리키게
엮는다.

@<무게를 셈해 고른 노드에 정점을 배정한다@>=
for i := int64(0); i < b.characters; i++ {
	d := &b.nodes[i].Data
	b.nodes[i].Key = b.inWeight*d.in + b.outWeight*d.out + weightBias
	if i == 0 {
		b.nodes[i].Link = nil
	} else {
		b.nodes[i].Link = &b.nodes[i-1]
	}
}
buckets := gbsort.LinkSort(&b.nodes[b.characters-1], b.rng)
@<정렬된 노드에서 정점을 골라 배정한다@>

@ 무게가 큰 차례로 |n|개의 노드를 훑되, 앞 |x|개는 건너뛰고 나머지에 정점을
차례로 배정한다. |LinkSort|가 무게가 같은 노드를 무작위 순서로 놓아 주므로,
동점을 가르는 일은 저절로 된다.

@<정렬된 노드에서 정점을 골라 배정한다@>=
vi := int64(0)
skip := b.x    // 이만큼은 뺀다
count := b.n   // 이만큼의 노드를 본다
Outer:
for j := 127; j >= 0; j-- {
	for p := buckets[j]; p != nil; p = p.Link {
		if skip > 0 {
			skip-- // 이 노드는 뺀다
		} else {
			p.Data.vert = &b.g.Vertices[vi] // 이 노드를 고른다
			vi++
		}
		count--
		if count == 0 {
			break Outer
		}
	}
}

@ 표식에 쓰는 제목은 파일 이름에서 되찾는다. |bgraph|가 이미 |title|을 갖고
있지 않으므로, 파일 이름의 바탕(basename)에서 확장자를 떼어 쓴다.

@<|bgraph|와 그 도우미@>=
func (b *bookBuilder) title() string {
	return strings.TrimSuffix(filepath.Base(b.fileName), ".dat")
}

@* 시험. 기본 |Book("anna",...)|은 톨스토이의 {\sl Anna Karenina\/} 138개
인물을 모두 담는다. Knuth의 발표값과 대조한다.

@(gbbooks_test.go@>=
package gbbooks

import (
	"fmt"
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
)

const dataDir = "../data"

@<기본 anna 그래프 시험@>
@<가중 선택과 장 한정 시험@>
@<책마다 장 수를 확인하는 시험@>
@<이분 그래프 시험@>

@ |Book("anna",0,0,0,0,0,0,0)|은 정점 138개짜리 그래프를 짓는다. 표식과
정점 수, 그리고 한 인물의 코드·이름을 확인한다.

@<기본 anna 그래프 시험@>=
func TestAnnaFull(t *testing.T) {
	g, err := Book("anna", 0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 138 {
		t.Fatalf("N = %d, 원함 138", g.N)
	}
	if g.ID != `book("anna",138,0,1,239,0,0,0)` {
		t.Errorf("ID = %q", g.ID)
	}
	if g.M == 0 {
		t.Error("간선이 하나도 없다")
	}
}

@ 첫 정점은 무게가 가장 큰 인물이다. 코드(|U.I|)를 두 글자로 되살려 확인하고,
이름·설명이 채워졌는지 본다.

@<기본 anna 그래프 시험@>=
func TestAnnaVertexFields(t *testing.T) {
	g, err := Book("anna", 0, 0, 0, 0, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	v := &g.Vertices[0]
	if v.Name == "" || v.Z.S == "" {
		t.Errorf("정점 이름/설명이 비었다: %q / %q", v.Name, v.Z.S)
	}
	if v.U.I <= 0 || v.U.I >= maxCode {
		t.Errorf("short_code = %d, 범위 밖", v.U.I)
	}
}

@ 들어가며에서 예로 든 \.{anna.dat}의 줄
`\.{AL Alexey Alexandrovitch Karenin, minister of state}'가 정말 그렇게
읽히는지 본다. \.{AL}은 36진법으로 $10\times36+21=381$이다.

@<기본 anna 그래프 시험@>=
func TestAnnaKareninEntry(t *testing.T) {
	g, err := Book("anna", 0, 0, 0, 0, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	for i := range g.N {
		v := &g.Vertices[i]
		if v.U.I != 10*36+21 {
			continue
		}
		if v.Name != "Alexey Alexandrovitch Karenin" {
			t.Errorf("이름 = %q", v.Name)
		}
		if v.Z.S != "minister of state" {
			t.Errorf("설명 = %q", v.Z.S)
		}
		return
	}
	t.Fatal("코드 AL인 인물을 찾지 못했다")
}

@ |Book("anna",50,0,0,0,1,1,0)|은 가장 자주 나오는 50명으로 한정한다.
장 구간을 좁히면(|10..120|) 정점은 그대로되 간선이 줄어든다.

@<가중 선택과 장 한정 시험@>=
func TestAnnaSelect(t *testing.T) {
	g, err := Book("anna", 50, 0, 0, 0, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 50 {
		t.Fatalf("N = %d, 원함 50", g.N)
	}
	sub, err := Book("anna", 50, 0, 10, 120, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if sub.N != 50 {
		t.Fatalf("N = %d, 원함 50", sub.N)
	}
	if sub.M > g.M {
		t.Errorf("장을 한정했는데 간선이 늘었다: %d > %d", sub.M, g.M)
	}
}

@ |x=1|은 무게가 가장 큰 인물 하나를 뺀다. {\sl David Copperfield\/}는 인물이
87명이라, |x=1|이면 정점이 86개가 된다.

@<가중 선택과 장 한정 시험@>=
func TestDavidExclude(t *testing.T) {
	g, err := Book("david", 0, 1, 0, 0, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 86 {
		t.Errorf("N = %d, 원함 86", g.N)
	}
	if g.ID != `book("david",87,1,1,64,1,1,0)` {
		t.Errorf("ID = %q", g.ID)
	}
}

@ 다섯 책의 인물 수와 장 수를 한꺼번에 확인한다. 이 시험이 특히 값진 까닭은
\.{jean.dat}이 콜론 없는 장을, \.{homer.dat}이 |'&'| 이어짐 줄을 갖고 있어서
간선 읽기의 잔가지 두 가지를 함께 밟기 때문이다. 표식에 찍히는 |lastChapter|가
곧 그 책의 전체 장 수다.

@<책마다 장 수를 확인하는 시험@>=
func TestChapterCounts(t *testing.T) {
	for _, c := range []struct {
		title      string
		chars, chaps int64
	}{
		{"anna", 138, 239},
		{"david", 87, 64},
		{"jean", 80, 356},
		{"huck", 74, 43},
		{"homer", 561, 24},
	} {
		@<책 |c|의 인물 수와 장 수를 확인한다@>
	}
}

@ @<책 |c|의 인물 수와 장 수를 확인한다@>=
g, err := Book(c.title, 0, 0, 0, 0, 1, 1, 0, dataDir)
if err != nil {
	t.Fatalf("%s: %v", c.title, err)
}
if g.N != c.chars {
	t.Errorf("%s: N = %d, 원함 %d", c.title, g.N, c.chars)
}
want := fmt.Sprintf("book(%q,%d,0,1,%d,1,1,0)", c.title, c.chars, c.chaps)
if g.ID != want {
	t.Errorf("%s: ID = %q, 원함 %q", c.title, g.ID, want)
}

@ |BiBook("anna",50,0,10,120,1,1,0)|은 $50+111$개 정점의 이분 그래프를 짓는다.
첫 갈래는 인물 50명, 둘째 갈래는 10장부터 120장까지의 111개 장이다.

@<이분 그래프 시험@>=
func TestBiBookAnna(t *testing.T) {
	g, err := BiBook("anna", 50, 0, 10, 120, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 50+111 {
		t.Fatalf("N = %d, 원함 161", g.N)
	}
	if g.N1() != 50 {
		t.Errorf("N1 = %d, 원함 50", g.N1())
	}
	if !isBipartite(g) {
		t.Error("이분 그래프가 아니다")
	}
}

@ 이분 그래프의 둘째 갈래 정점 이름은 그 책의 구조적 장 번호다. {\sl Les
Mis\'erables\/}의 첫 장과 마지막 장이 |"1.1.1"|과 |"5.9.6"|인지 본다---
들어가며에서 말한 |chap_name| 배열이 이렇게 살아남는다.

@<이분 그래프 시험@>=
func TestBiBookChapterNames(t *testing.T) {
	g, err := BiBook("jean", 80, 0, 0, 0, 1, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	first, last := &g.Vertices[g.N1()], &g.Vertices[g.N-1]
	if first.Name != "1.1.1" {
		t.Errorf("첫 장 이름 = %q, 원함 1.1.1", first.Name)
	}
	if last.Name != "5.9.6" {
		t.Errorf("끝 장 이름 = %q, 원함 5.9.6", last.Name)
	}
}

@ 이분성 검사: 모든 간선이 두 갈래를 잇는지(양 끝이 |N1| 경계의 반대쪽인지)
확인한다.

@<이분 그래프 시험@>=
func isBipartite(g *gbgraph.Graph) bool {
	n1 := g.N1()
	for i := int64(0); i < g.N; i++ {
		left := i < n1
		for a := range g.Vertices[i].AllArcs() {
			if (g.Index(a.Tip) < n1) == left {
				return false
			}
		}
	}
	return true
}

@* 찾아보기.
