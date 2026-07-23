% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_econ.w를 Go로 이식한다.
@i ../gbtypes.w

\input kotexgweb
\def\title{GB\_\,ECON}

@* 들어가며. 이 모듈은 산업 사이의 돈 흐름에 바탕한 유향 그래프 집안을 짓는
|Econ| 서브루틴을 담는다. 쓰임새는 데모 {\sc ECON\_\,ORDER}에서 볼 수 있다.

|Econ(n, omit, threshold, seed, dir)|은 |dir| 디렉터리의 \.{econ.dat}에 담긴
정보로 유향 그래프를 짓는다. 각 정점은 1985년 미국 경제의 81개 부문 가운데
하나에 대응한다. 자료 값은 {\sl Survey of Current Business\/ \bf70}(1990),
41--56쪽에 실린 표에서 뽑은 것이다.

@ |omit=threshold=0|이면 이 그래프는 ``순환(circulation)''이다: 각 호에 |flow|
값이 있고, 정점마다 나가는 호 흐름의 합과 들어오는 호 흐름의 합이 같다. 그
합을 그 부문의 ``총상품산출(total commodity output)''이라 부른다. 부문 $j$에서
부문 $k$로 가는 호의 흐름은, $j$가 만든 상품 가운데 $k$가 쓴 양을 생산자
가격 기준 백만 달러 단위로 반올림한 값이다.

예를 들어 보자. \.{Apparel}(의류) 부문의 총상품산출은 54031이다. 1985년에
온갖 의류를 만드는 데 든 비용이 모두 540억 달러쯤이었다는 뜻이다.
\.{Apparel}에서 자기 자신으로 가는 호의 흐름은 9259인데, 의류 산업 안의 한
무리에서 다른 무리로 92억 5900만 달러어치가 건너갔다는 말이다. \.{Apparel}에서
\.{Household furniture}(가정용 가구)로 가는 흐름 44짜리 호도 있다. 4400만
달러어치의 의류가 가정용 가구를 만드는 데 들어갔다는 뜻이다. \.{Apparel}에서
{\it 나가는\/} 호를 모두 보면 그 새 옷들이 어디로 갔는지 알 수 있고,
\.{Apparel}로 {\it 들어오는\/} 호를 모두 보면 의류 산업이 옷을 만드는 데 어떤
재료를 필요로 했는지 알 수 있다.

@ \.{Users}라는 정점 하나는 우리 같은 사람들, 곧 모든 것의 비산업적 최종
소비자를 나타낸다. \.{Apparel}에서 \.{Users}로 가는 호의 흐름은 42172다. 이것이
의류의 ``총최종수요(total final demand)'', 즉 우리에게 닿기 전에 경제의 다른
부문으로 흘러 들어가지 않은 몫이다. 거꾸로 \.{Users}에서 \.{Apparel}로 가는
호의 흐름은 19409인데, 이것을 사용자가 보탠 ``부가가치(value added)''라 부른다.
제조 과정을 떠받치려고 치른 임금과 봉급을 나타낸다.

모든 부문에 걸친 총최종수요의 합은 모든 부문에 걸친 부가가치의 합과 같고,
이것을 흔히 국민총생산(GNP)이라 부른다. \.{econ.dat}에 따르면 1985년의 GNP는
3999362, 거의 4조 달러였다.

@ 반면 모든 정점에서 나가는 호 흐름을 다 더하면 7198847\footnote*{\ninepoint
Knuth는 이 값을 7198680이라 적었지만, \.{econ.dat}의 $81\times80$ 행렬을
직접 더하면 7198847이 나온다---167만큼 차이가 난다. 우리 포팅이 만든
그래프에서 세어도 같은 값이고, SGB 정오표에도 이 항목은 없다. 이 문서는
자료에서 실제로 나오는 값을 적는다.}이 된다. 이 합은 경제
활동의 총량을 과대평가한다. 어떤 품목은 여러 번 세어지기 때문이다---통계
수집자를 지나칠 때마다 통계에 잡히는 탓이다. 경제학자들은 이런 이중 계산을
할 수 있는 한 피하도록 자료를 다듬으려 애쓴다.

@ 경제학자 이야기가 나온 김에 덧붙이면, \.{Adjustments}라는 특별 정점이 하나
더 있다. GNP를 더 정확히 재려고 경제학자들이 끼워 넣은 것이다. 이 정점은
재고 가치의 변동, 미국 안에서 구할 수 없어 수입해야 하는 원자재, 그리고
정부와 외국을 위해 한 일 따위를 셈에 넣는다. 1985년에 이 조정분은 457090으로,
GNP의 11\%쯤이었다.

@ 그런데 ``총최종수요'' 호 가운데 몇몇은 음수다. 예컨대 \.{Petroleum and
natural gas production}(석유·천연가스 생산)에서 \.{Users}로 가는 호의 흐름은
$-27032$다. 처음에는 이상해 보이지만, 수입을 생각하면 말이 된다. 원유와
천연가스는 최종 소비자보다 다른 산업으로 훨씬 많이 가기 때문이다. 총최종수요는
총 사용자 수요를 뜻하는 것이 아니다.

전체 그래프에서 음의 흐름을 가진 호는 정확히 열 개이고, 모두 \.{Users}로
들어간다. 광업과 1차 금속 제조업이 대부분이다(가장 큰 것이 방금 든 석유·
천연가스의 $-27032$, 다음이 \.{Primary iron and steel manufacturing}의
$-10910$).

@ |omit=1|이면 \.{Users} 정점이 그래프에서 빠지고, 따라서 방금 말한 음의 흐름
호가 모두 사라진다. |omit=2|이면 \.{Adjustments} 정점까지 빠져, 산업 사이의
흐름만 보여 주는 79개 부문이 남는다. (물론 |omit>0|이면 그래프는 더 이상
``순환''이 아니다.) 두 특별 정점이 남으면 \.{Users}가 마지막, \.{Adjustments}가
그 앞 정점이다.

@ |threshold=0|이면 흐름이 0이 아닌 호가 모두 생긴다. |threshold>0|이면 그래프가
성겨진다: 부문 $j$가 부문 $k$에 댄 양이 $k$의 총투입의 |threshold|$/65536$배를
넘을 때에만 $j\to k$ 호가 생긴다. (총투입 값에는 |omit>0|일 때에도 언제나
부가가치가 들어 있다.) 그러니 호는 각 부문으로, 그 부문의 주된 공급자들로부터
들어오게 된다. 호의 |len|은 언제나 1이다.

|n=79|, |omit=2|, |threshold=0|이면 유향 그래프의 호는 가능한
$79\times79=6241$개 가운데 4602개다. |threshold|를 1로 올리면 4473개로 줄고,
6000으로 올리면 겨우 72개만 남는다.

@ 그래프의 정점 수는 $\min(n,81-|omit|)$이다. |n|이 |81-omit|보다 작으면,
관련된 부문들을 거듭 합쳐서 |n|개의 정점을 만든다. 예컨대 원래 81개 부문 가운데
둘은 `\.{Paper products, except containers}'(용기를 제외한 종이 제품, SIC 24)와
`\.{Paperboard containers and boxes}'(판지 용기와 상자, SIC 25)인데, 이 둘을
`\.{Paper products}'라는 한 부문으로 합칠 수 있다.

79개 비특별 부문에는 고정된 위계적 분해를 나타내는, 잎이 79개인 이진 트리가
딸려 있다. 필요하면 이 트리를 가지치기한다---잎 한 쌍을 그 부모 노드로
바꾸어 부모가 새 잎이 되게 하고, 잎이 꼭 |n|개 남을 때까지 이어 간다.

@ 가지치기는 아래에서 위로 가는 과정이지만, 그 효과는 위에서 아래로 트리를
``기르는'' 것으로도 얻을 수 있다. 경제 전체를 부문 하나로 놓고 시작해서,
한 부문을 둘로 거듭 쪼개 나가는 것이다. 예컨대 |omit=2|이고 |n=2|이면 두 부문의
이름은 \.{Goods}(재화)와 \.{Services}(용역)가 된다. |n=3|이면 \.{Goods}가
\.{Natural Resources}와 \.{Manufacturing}으로 쪼개지거나, \.{Services}가
\.{Indirect services}와 \.{Direct services}로 쪼개질 수 있다---|seed=0|일 때
실제로 일어나는 쪽은 후자여서, \.{Goods}·\.{Indirect services}·
\.{Direct services}가 나온다.

@ |seed=0|이면 트리 구조를 지키는 한도 안에서 |n|개 부문의 총투입과 총산출이
되도록 고르게 나뉘도록 가지친다. |seed>0|이면 무작위로 가지치되, 원 트리의 모든
|n|-잎 부분트리가 (기계에 무관한 방식으로) 거의 같은 확률로 나오도록 한다.
|seed| 값은 1부터 $2^{31}-1=2147483647$까지면 무엇이든 좋다.

GraphBase의 다른 루틴들처럼 |n=0|은 |n|이 최대값을 갖는 기본 상황을 뜻한다.
그러니 |Econ(0,0,0,0)|과 |Econ(81,0,0,0)|이 같은 전체 그래프를 내고,
|Econ(0,2,0,0)|과 |Econ(79,2,0,0)|이 두 특별 정점을 뺀 그래프를 낸다.

@ 미국 경제분석국(Bureau of Economic Analysis)과 인구조사국(Bureau of the
Census)은 \.{econ.dat}이 통계를 주는 개별 부문에 1부터 79까지 부호를 매겼다.
이 부문 번호를 전통적으로 표준산업분류(Standard Industrial Classification,
SIC) 부호라 부른다. |Econ|이 만든 그래프의 정점 |v|가 나타내는 모든 부문의 SIC
부호를 알고 싶으면, 유틸리티 필드 |v.Z.A|에서 시작하는 |Arc| 노드 목록으로
찾아갈 수 있다. 이 목록은 여느 때처럼 |Next| 필드로 이어지고, SIC 부호는 각
|Arc|의 |Len| 필드에 들어 있다. |Tip| 필드는 쓰이지 않는다.

특별 정점 \.{Adjustments}에는 부호 80이 주어진다. 이것은 사실 발표된 표에서
80--86번으로 매겨진 여섯 개의 서로 다른 SIC 범주를 하나로 뭉친 것이다.

예컨대 |n=80|이고 |omit=1|이면 어느 목록이나 길이가 1이다. 그러니 모든 |v|에
대해 |v.Z.A.Next|가 |nil|이고, |v.Z.A.Len|이 곧 |v|의 SIC 부호로 1과 80 사이의
수다. 특별 정점 \.{Users}에는 SIC 부호가 없다---|Econ|이 돌려주는 그래프에서
|Z.A|가 |nil|인 정점은 이것 하나뿐이다.

@ 각 부문의 총산출(총투입과 같다)은 해당 정점의 |Y.I| 필드에 담는다. 유틸리티
필드를 정리하면 이렇다:
$$\vbox{\halign{\hfil#\hfil&\quad#\hfil&\quad#\hfil\cr
원본&\GO/&뜻\cr
\noalign{\smallskip\hrule\smallskip}
|flow|&|A.I|&(호) 이 호를 타고 흐른 금액\cr
|sector_total|&|Y.I|&(정점) 총투입 $=$ 총산출\cr
|SIC_codes|&|Z.A|&(정점) SIC 부호 목록의 첫 |Arc|\cr}}$$
이 배치가 곧 |UtilTypes| 문자열 |"ZZZZIAIZZZZZZZ"|가 뜻하는 바다.

문제가 생기면 |Econ|은 |nil|과 함께 |error|(곧 |gbgraph.PanicCode|)를
돌려준다. \CEE/의 |calloc| 실패 경로는 \GO/의 |make|가 실패를 모르므로
사라졌다.

@c
package gbecon

import (
	"fmt"
	"path/filepath"
	@#
	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
)

const (
	maxN   = 81 // 만드는 그래프의 최대 정점 수
	normN  = 79 // 보통 SIC 부문의 수 (|maxN-2|)
	adjSec = 80 // \.{Adjustments} 부문의 부호 번호 (|maxN-1|)
)

const DataDirectory = "/usr/local/sgb/data"

@<타입 정의@>
@<Econ 서브루틴@>
@<자료를 읽는다@>
@<부분트리를 기른다@>
@<호를 만든다@>

@ 자료를 읽으며 경제의 미시 부문(기본 SIC 부문)이나 거시 부문(두 하위 노드의
합집합)을 나타내는 노드의 차례 목록을 짓는다. 노드들은 확장 이진 트리를 이루고,
전위 순회(preorder) 차례로 놓인다. 각 노드는 부문 산출 벡터를 통째로 담으므로
꽤 큰 레코드다. \CEE/의 포인터 산술(|p+1|이 왼쪽 자식, |p-1|이 앞 노드)을 옮기려
전위 순회 색인 |idx|를 노드마다 담아 둔다.
@<타입...@>=
type node struct {
	idx     int              // |nodeBlock| 안의 전위 순회 위치
	rchild  *node            // 거시 부문의 오른쪽 자식
	title   string           // 부문 이름
	table   [maxN + 1]int64  // 이 부문의 산출들
	total   int64            // 이 부문의 총투입 (= 총산출)
	thresh  int64            // 이 부문으로 오는 호의 |flow| 문턱
	SIC     int64            // SIC 부호 번호; 거시 부문은 처음엔 0
	tag     int64            // 이 노드가 그래프 정점이 되면 1 (또는 잎 수)
	link    *node            // 아직 안 살핀 다음 부문
	sicList *gbgraph.Arc     // SIC 부호 목록의 첫 항목
}

@ |builder|는 \CEE/의 정적 전역들(스택·노드 블록·색인표)을 담아 패키지 수준
가변 상태를 피한다.
@<타입...@>=
type builder struct {
	rng             *gbflip.RNG
	f               *gbio.File
	g               *gbgraph.Graph
	n, omit, thresh int64
	nodeBlock       []node // 전위 순회로 트리를 나타내는 노드 배열
	nodeIndex       [maxN + 1]*node // 주어진 SIC 부호를 가진 노드
	vertIndex       [maxN + 1]*gbgraph.Vertex // SIC 부호에 배정된 정점
	stack           [normN + normN]*node // 오른쪽 자식을 채울 노드들
	stackPtr        int
}

@ |left|는 노드 |p|의 왼쪽 자식(전위 순회에서 바로 다음 노드 |p+1|)을 준다.
여러 곳에서 쓰인다.

@<타입...@>=
func (b *builder) left(p *node) *node {
	return &b.nodeBlock[p.idx+1]
}

@ |Econ|의 뼈대는 \CEE/ 원본을 그대로 따른다: 난수를 앉히고, 매개변수를
가다듬고, 빈 그래프를 세운 뒤, 자료를 읽고, 쓸 부문을 정하고, 호를 채운다.

@<Econ 서브루틴@>=
func Econ(n, omit, threshold, seed int64, dir string) (*gbgraph.Graph, error) {
	if dir == "" {
		dir = DataDirectory
	}
	b := &builder{rng: gbflip.New(seed)}
	@<매개변수를 검사하고 기본값을 채운다@>
	b.n, b.omit, b.thresh = n, omit, threshold
	@<정점 |n|개짜리 그래프를 세운다@>
	if err := b.readData(dir); err != nil {
		return nil, err
	}
	b.chooseSectors(seed)
	if err := b.makeArcs(); err != nil {
		return nil, err
	}
	if b.f.Close() != nil {
		return nil, gbgraph.LateDataFault // \.{econ.dat}에 탈이 있다
	}
	return b.g, nil
}

@ @<매개변수를 검사하고 기본값을 채운다@>=
if omit > 2 {
	omit = 2
}
if n == 0 || n > maxN-omit {
	n = maxN - omit
} else if n+omit < 3 {
	omit = 3 - n // 보통 부문이 적어도 하나는 있어야 한다
}
if threshold > 65536 {
	threshold = 65536
}

@ @<정점 |n|개짜리 그래프를 세운다@>=
b.g = gbgraph.NewGraph(n)
b.g.ID = fmt.Sprintf("econ(%d,%d,%d,%d)", n, omit, threshold, seed)
b.g.UtilTypes = "ZZZZIAIZZZZZZZ"

@* 자료 읽기.
\.{econ.dat}의 앞부분은 이진 트리의 노드를 전위 순회로 적는다. 각 줄은 노드
이름 뒤에 콜론이 오고, 잎이면 콜론 뒤에 SIC 번호가 온다.

이렇게만 적어도 트리가 유일하게 정해진다. 전위 순회의 성질 덕이다. 폴란드
전위 표기를 떠올리면 된다---`${+}x{+}xx$' 같은 식은 `${+}(x,{+}(x,x))$'를
뜻하며, 괄호가 없어도 읽는 데 아무 지장이 없다. 여기서도 마찬가지다. 왼쪽
자식은 언제나 부모 바로 다음에 오므로 따로 가리킬 필요가 없고, 오른쪽 자식만
나중에 채워 넣으면 된다. 그래서 노드에 \\{lchild} 필드가 없는 것이다.

두 특별 부문 이름은 파일에 없으므로 우리가 만들어 붙인다. 그리고 이 읽기
코드는 자료가 아무리 뒤틀려 있어도 프로그램이 스스로를 망가뜨리지는 않도록
조심스럽게 짜여 있다.

@<자료를 읽는다@>=
func (b *builder) readData(dir string) error {
	b.nodeBlock = make([]node, 2*maxN-3)
	for i := range b.nodeBlock {
		b.nodeBlock[i].idx = i
	}
	f, err := gbio.Open(filepath.Join(dir, "econ.dat"))
	if err != nil {
		return gbgraph.EarlyDataFault // \.{econ.dat}을 열 수 없다
	}
	b.f = f
	@<부문 이름과 SIC 번호를 읽어 트리를 세운다@>
	for k := int64(1); k <= maxN; k++ {
		@<부문 |k|의 출력 계수를 읽는다@>
	}
	return nil
}

@ 각 노드의 이름을 콜론까지 읽고 SIC 번호를 읽는다. 거시 부문(SIC 0)은 왼쪽
자식이 바로 뒤 노드이고 오른쪽 자식은 나중에 정해지므로 스택에 얹는다. 미시
부문은 |node_index|에 등록하고, 스택에 얹힌 부모의 오른쪽 자식이 된다. 자료가
아무리 뒤틀려도 프로그램이 스스로를 망치지 않도록 조심한다.

@<부문 이름과 SIC 번호를 읽어 트리를 세운다@>=
b.stackPtr = 0
for pi := 0; pi < normN+normN-1; pi++ {
	p := &b.nodeBlock[pi]
	p.title = b.f.String(':')
	if len(p.title) > 43 {
		return gbgraph.SyntaxError // 부문 이름이 너무 길다
	}
	if b.f.Char() != ':' {
		return gbgraph.SyntaxError + 1 // 콜론이 없다
	}
	c := b.f.Number(10)
	p.SIC = c
	if c == 0 { // 거시 부문
		b.stack[b.stackPtr] = p
		b.stackPtr++
	} else { // 미시 부문; |p+1|은 누군가의 오른쪽 자식이 된다
		b.nodeIndex[c] = p
		if b.stackPtr > 0 {
			b.stackPtr--
			b.stack[b.stackPtr].rchild = &b.nodeBlock[pi+1]
		}
	}
	if b.f.Char() != '\n' {
		return gbgraph.SyntaxError + 2 // 줄에 군더더기가 있다
	}
	b.f.NextLine()
}
@<트리가 온전한지 확인하고 특별 부문을 붙인다@>

@ @<트리가 온전한지 확인하고 특별 부문을 붙인다@>=
if b.stackPtr != 0 {
	return gbgraph.SyntaxError + 3 // 트리가 뒤틀렸다
}
for k := normN; k >= 1; k-- {
	if b.nodeIndex[k] == nil {
		return gbgraph.SyntaxError + 4 // 트리에 없는 SIC 부호
	}
}
adj := &b.nodeBlock[normN+normN-1]
adj.title = "Adjustments"
adj.SIC = adjSec
b.nodeIndex[adjSec] = adj
users := &b.nodeBlock[normN+normN]
users.title = "Users"
b.nodeIndex[maxN] = users

@ \.{econ.dat}의 나머지는 $81\times80$ 행렬이다. |k|번째 행은 부문 |k|가
\.{Users}를 뺀 모든 부문에 댄 산출이다. 각 행은 빈 줄 하나에 이어 8개의
자료 줄로 되어 있고, 자료 줄마다 쉼표로 나뉜 10개의 수가 온다. 0은 \.{0}이
아니라 빈칸으로 적힌다.

맨 처음 빈 줄 다음에 오는 자료 줄은 이렇게 생겼다:
$$\hbox{\tt 8490,2182,42,467,,,,,,}$$
1번 부문이 자기 자신에게 8490백만 달러, 2번 부문에게 2182백만 달러, \dots,
10번 부문에게 0달러를 냈다는 뜻이다.

@<부문 |k|의 출력 계수를 읽는다@>=
if b.f.Char() != '\n' {
	return gbgraph.SyntaxError + 5 // 행 사이 빈 줄이 없다
}
b.f.NextLine()
p := b.nodeIndex[k]
s := int64(0) // 행 합
for j := int64(1); j < maxN; j++ {
	x := b.f.Number(10)
	p.table[j] = x
	s += x
	b.nodeIndex[j].total += x
	@<자료 항목 뒤의 쉼표나 개행을 확인한다@>
}
p.table[maxN] = s // |table[1]|부터 |table[80]|까지의 합

@ @<자료 항목 뒤의 쉼표나 개행을 확인한다@>=
if j%10 == 0 {
	if b.f.Char() != '\n' {
		return gbgraph.SyntaxError + 6 // 입력 파일의 동기가 어긋났다
	}
	b.f.NextLine()
} else if b.f.Char() != ',' {
	return gbgraph.SyntaxError + 7 // 항목 뒤에 쉼표가 없다
}

@* 부분트리 기르기.
모든 자료가 |nodeBlock|에 담기면, 매개변수 |n|·|omit|·|seed|가 시키는 대로
그 자료를 뽑아내고 합쳐야 한다. 이 합병 과정은 사실상 트리를 가지치는 일이고,
동시에 전체 경제 트리의 부분트리 하나를 ``기르는'' 절차로도 볼 수 있다.
고른 잎은 |tag| 필드가 1이 된다.

@<부분트리를 기른다@>=
func (b *builder) chooseSectors(seed int64) {
	l := b.n + b.omit - 2 // 원하는 부분트리의 잎 수
	switch {
	case l == normN:
		for k := normN; k >= 1; k-- {
			b.nodeIndex[k].tag = 1 // 모든 부문 선택
		}
	case seed != 0:
		b.growRandom(l)
	default:
		b.growLargest(l)
	}
}

@ |seed=0|일 때는 먼저 트리를 아래에서 위로 훑어 각 거시 부문의 총투입을
구하고, 위에서 아래로 내려가며 총투입이 큰 부문부터 나눈다. 이 절차는 이
프로그램의 다른 여러 곳에서도 쓸 ``아래에서 위로''와 ``위에서 아래로''라는 두
가지 트리 훑기 방식을 잘 보여 주는 본보기다---노드가 전위 순회로 늘어서 있으니,
배열을 앞에서 뒤로 훑으면 위에서 아래로, 뒤에서 앞으로 훑으면 아래에서 위로
가는 셈이 된다.

|special| 노드(\.{Users})는 두 구실을 한다: |total|의 내림차순으로 정렬된
미탐색 노드 연결 리스트의 머리이자, |special.total|이 0이라 그 리스트의
꼬리이기도 하다---어떤 노드의 |total|도 0 이상이므로 삽입 자리를 찾는 루프가
경계 검사 없이 반드시 여기서 멈춘다.

@<부분트리를 기른다@>=
func (b *builder) growLargest(l int64) {
	special := b.nodeIndex[maxN]
	for i := b.nodeIndex[adjSec].idx - 1; i >= 0; i-- { // 아래에서 위로
		if p := &b.nodeBlock[i]; p.rchild != nil {
			p.total = b.nodeBlock[i+1].total + p.rchild.total
		}
	}
	special.link = &b.nodeBlock[0] // 뿌리에서 시작한다
	b.nodeBlock[0].link = special
	k := int64(1) // 태그했거나 리스트에 얹은 노드 수
	for k < l {
		@<리스트 첫 노드가 잎이면 태그, 아니면 두 자식으로 나눈다@>
	}
	for p := special.link; p != special; p = p.link {
		p.tag = 1 // 리스트에 남은 것을 모두 태그한다
	}
}

@ @<리스트 첫 노드가 잎이면 태그, 아니면 두 자식으로 나눈다@>=
p := special.link // |total|이 가장 큰 |p|를 뗀다
special.link = p.link
if p.rchild == nil {
	p.tag = 1 // |p|는 잎이다
} else {
	pl, pr := b.left(p), p.rchild
	q := special
	for q.link.total > pl.total {
		q = q.link
	}
	pl.link, q.link = q.link, pl // 왼쪽 자식을 제자리에 끼운다
	q = special
	for q.link.total > pr.total {
		q = q.link
	}
	pr.link, q.link = q.link, pr // 오른쪽 자식을 제자리에 끼운다
	k++
}

@ 주어진 트리의 |l|-잎 부분트리를 고르게 뽑는 방법은 이렇다. |l=1|이면 뿌리를
고르면 그만이다. |l>1|이면 다음 생각을 쓴다: 주어진 트리 $T$가 부분트리 $T_0$과
$T_1$을 갖는다고 하자. 그러면 $T$의 |l|-잎 부분트리 수는
$$T(l)=\sum_k T_0(k)T_1(l-k)$$
이다. $0$과 $T(l)-1$ 사이의 난수 $r$을 뽑아, $\sum_{k\le m}T_0(k)T_1(l-k)>r$인
가장 작은 $m$을 찾는다. 그러고는 $T_0$의 $m$-잎 부분트리와 $T_1$의 $(l-m)$-잎
부분트리를 재귀적으로 구한다.

@ $T(l)$이 $2^{31}$ 이상이면 곤란해진다. 하지만 그럴 때는 위 식의 $T_0(k)$와
$T_1(l-k)$를 각각 $\lceil T_0(k)/d_0\rceil$과 $\lceil T_1(k)/d_1\rceil$로
바꾸면 된다. $d_0$과 $d_1$은 아무 상수나 좋다. 이러면 $T(l)$이 작아지면서도
$k$의 분포는 거의 그대로다.

\.{econ.dat}의 자료는 충분히 단순해서 $T(l)$ 값 대부분이 $2^{31}$보다 작다.
넘침을 피하려고 눈금을 줄여야 하는 곳은 트리의 뿌리 노드뿐이며, 그래서 그
경우만 따로 다룬다.

@ $T(l)$ 값들을 아래에서 위로 계산해 |table|에 담고(노드 |p|가 잎이 아니면
|p.table[0]|은 그 아래 잎의 수, |p.table[l]|은 $1\le l\le|p.table[0]|$에 대한
$T(l)$), 무작위 트리를 위에서 아래로 기른다.

|tag| 필드에는 그 노드를 뿌리로 하는 부분트리에서 기를 잎의 수를 담는다. 이
약속은 ``|tag=1|인 노드가 곧 정점으로 뽑힌 노드''라는 앞의 규정과 어긋나지
않는다---잎을 하나만 기른다는 것이 바로 그 노드 자신이 잎이 된다는 뜻이기
때문이다.

@<부분트리를 기른다@>=
func (b *builder) growRandom(l int64) {
	b.nodeBlock[0].tag = l
	adjIdx := b.nodeIndex[adjSec].idx
	for i := adjIdx - 1; i > 0; i-- { // 뿌리만 빼고 아래에서 위로
		if p := &b.nodeBlock[i]; p.rchild != nil {
			b.computeTL(p)
		}
	}
	for i := 0; i < adjIdx; i++ { // 뿌리부터 위에서 아래로
		if p := &b.nodeBlock[i]; p.tag > 1 {
			@<노드 |p| 두 자식의 잎 수를 정한다@>
		}
	}
}

@ @<노드 |p| 두 자식의 잎 수를 정한다@>=
l := p.tag
pl, pr := b.left(p), p.rchild
switch {
case pl.rchild == nil:
	pl.tag, pr.tag = 1, l-1
case pr.rchild == nil:
	pl.tag, pr.tag = l-1, 1
default:
	@<확률적으로 각 자식의 잎 수를 정한다@>
}

@ 여기서 하는 일은 본질적으로 두 생성 함수를 곱하는 것이다. $f(z)=\sum_l
T(l)z^l$이라 두면, 우리가 셈하는 것은
$$f_p(z)=z+f_{pl}(z)f_{pr}(z)$$
이다. 오른쪽의 $z$ 항은 |l=1|인 경우---곧 노드 |p| 자신을 잎으로 삼아 더는
쪼개지 않는 경우---하나를 헤아린다.

@<부분트리를 기른다@>=
func (b *builder) computeTL(p *node) {
	pl, pr := b.left(p), p.rchild
	p.table[1], p.table[2] = 1, 1 // $T(1)$과 $T(2)$는 늘 1
	switch {
	case pl.rchild == nil && pr.rchild == nil:
		p.table[0] = 2 // 두 자식 다 잎
	case pl.rchild == nil:
		for k := int64(2); k <= pr.table[0]; k++ {
			p.table[1+k] = pr.table[k]
		}
		p.table[0] = pr.table[0] + 1
	case pr.rchild == nil:
		for k := int64(2); k <= pl.table[0]; k++ {
			p.table[1+k] = pl.table[k]
		}
		p.table[0] = pl.table[0] + 1
	default:
		@<|pl|과 |pr| 표의 합성곱을 |p.table|에 담는다@>
		p.table[0] = pl.table[0] + pr.table[0]
	}
}

@ @<|pl|과 |pr| 표의 합성곱을 |p.table|에 담는다@>=
p.table[2] = 0
for j := pl.table[0]; j >= 1; j-- {
	t := pl.table[j]
	for k := pr.table[0]; k >= 1; k-- {
		p.table[j+k] += t * pr.table[k]
	}
}

@ 뿌리에서는 $T(l)$이 $2^{31}$을 넘을 수 있어, 그럴 땐 $T_0(k)$를 $d_0=1024$로
나눠 올림해 눈금을 줄인다. 난수 |rr|을 뽑고, 부분합이 |rr|을 넘는 자리에서
멈춰 두 자식의 잎 수를 가른다.

@<확률적으로 각 자식의 잎 수를 정한다@>=
var ss int64
scale := false
if p.idx == 0 { // 뿌리
	if l > 29 && l < 67 {
		scale = true // $2^{31}$을 넘는 경우
	}
	for k := max(l-pr.table[0], 1); k <= pl.table[0] && k < l; k++ {
		@<|k| 항을 |ss|에 더한다@>
	}
} else {
	ss = p.table[l]
}
rr := b.rng.Unif(ss)
ss = 0
var k int64
for k = max(l-pr.table[0], 1); ss <= rr; k++ {
	@<|k| 항을 |ss|에 더한다@>
}
pl.tag, pr.tag = k-1, l-k+1

@ 눈금 조정이 필요하면 $\lceil T_0(k)/1024\rceil$을 쓰고, 아니면 곧이곧대로
$T_0(k)T_1(l-k)$을 더한다.

@<|k| 항을 |ss|에 더한다@>=
if scale {
	ss += ((pl.table[k] + 0x3ff) >> 10) * pr.table[l-k]
} else {
	ss += pl.table[k] * pr.table[l-k]
}

@* 호 만들기.
일반적으로는 몇몇 미시 부문을 거시 부문으로 합쳐야 한다. 알맞은 투입·산출
계수들을 더해서 말이다. 이는 아래에서 위로의 가지치기다.

|p|가 |pl|과 |pr|의 합집합으로 만들어진다고 하자. 그러면 |p|에서 나가는 호의
수는 |pl|과 |pr|에서 나가는 수들을 더해 얻고, |p|로 들어오는 호의 수는 |pl|과
|pr|로 들어오는 수들을 더해 얻는다. 그리고 |p|에서 자기 자신으로 가는 호의
수는 |pl|이나 |pr|에서 |pl|이나 |pr|로 가는 {\it 네\/} 수를 모두 더해 얻는다.

|nodeIndex| 표는 |nil|이 아닌 자리가 지금 살아 있는 노드 전부가 되도록 계속
간수한다. |pl|과 |pr|이 |p|에 밀려 가지치기될 때, |p|는 |nodeIndex| 안에서
|pl|이 있던 자리를 물려받고 |pr|이 있던 자리는 |nil|이 된다.

@<호를 만든다@>=
func (b *builder) makeArcs() error {
	@<매크로 부문을 가지치기하고 SIC 목록을 만든다@>
	@<특별 정점을 감추거나 드러낸다@>
	@<부문별 문턱값을 계산한다@>
	@<정점을 배정한다@>
	@<정점 사이에 호를 놓는다@>
	return nil
}

@ 아래에서 위로 훑는다. 원래 잎이면 SIC 목록의 첫 호를 만들고, 거시 부문이면
그 |tag|(기를 잎 수)가 1 이하일 때 두 자식을 합집합으로 접는다.

@<매크로 부문을 가지치기하고 SIC 목록을 만든다@>=
for i := b.nodeIndex[adjSec].idx; i >= 0; i-- { // 아래에서 위로
	p := &b.nodeBlock[i]
	if p.SIC != 0 { // 원래 잎
		p.sicList = b.g.VirginArc()
		p.sicList.Len = p.SIC
	} else {
		pl, pr := b.left(p), p.rchild
		if p.tag == 0 {
			p.tag = pl.tag + pr.tag
		}
		if p.tag <= 1 {
			@<|pl|과 |pr|을 합집합 |p|로 바꾼다@>
		}
	}
}

@ |p|는 |pl|의 |node_index| 자리를 물려받고, |pr|의 자리는 |nil|이 된다.

@<|pl|과 |pr|을 합집합 |p|로 바꾼다@>=
a := pl.sicList
jj, kk := pl.SIC, pr.SIC
p.sicList = a
for a.Next != nil {
	a = a.Next
}
a.Next = pr.sicList
for k := maxN; k >= 1; k-- {
	if q := b.nodeIndex[k]; q != nil {
		if q != pl && q != pr {
			q.table[jj] += q.table[kk]
		}
		p.table[k] = pl.table[k] + pr.table[k]
	}
}
p.total = pl.total + pr.total
p.SIC = jj
p.table[jj] += p.table[kk]
b.nodeIndex[jj] = p
b.nodeIndex[kk] = nil

@ \.{Users} 정점이 빠지지 않으면 각 부문의 총최종수요를 셈해야 한다. 이 값은
투입·산출 계수의 행 합과 열 합이 같아지도록 정해진다. 열 합은 이미 |total|로
구해 두었고, |table[1]|부터 |table[adjSec]|까지의 합도 이미 구해 |table[maxN]|에
넣어 두었다. 그러니 이제 |table[maxN]|을 |total-table[maxN]|으로 바꾸면 된다.
앞서 말했듯 이 값은 음수일 수도 있다---그것이 바로 열 개의 음의 흐름 호다.

\.{Users}를 나타내는 특별 노드 |p|에서는 앞선 처리 덕에 |p.total|이 0이 되어
있고, |p.table[maxN]|에는 부가가치의 합, 곧 GNP가 들어 있다. 이 둘을 맞바꾸면
된다.

@<특별 정점을 감추거나 드러낸다@>=
switch b.omit {
case 2:
	b.nodeIndex[adjSec], b.nodeIndex[maxN] = nil, nil
case 1:
	b.nodeIndex[maxN] = nil
default:
	for k := int64(adjSec); k >= 1; k-- {
		if p := b.nodeIndex[k]; p != nil {
			p.table[maxN] = p.total - p.table[maxN]
		}
	}
	p := b.nodeIndex[maxN] // 특별 노드
	p.total = p.table[maxN]
	p.table[maxN] = 0
}

@ 이 단계를 떠받치는 이론은 다음과 같다. 정수 $a,b,c,d$에 대해 $b,d>0$이면
$$ {a\over b}>{c\over d} \qquad\iff\qquad
  a>\biggl\lfloor{b\over d}\biggr\rfloor\,c +
       \biggl\lfloor{(b\bmod d)c\over d}\biggr\rfloor\,.$$
분수 비교를 정수 연산만으로 해내는 것이다. 우리 경우에는 $b=|total|$이고
$c=|threshold|\le d=65536=2^{16}$이므로 곱셈이 넘치지 않는다. (하지만 넘치기
직전까지 아슬아슬하게 다가가기는 한다.)

|threshold|가 0이면 문턱을 $-99999999$로 두어, 음의 흐름을 가진 호까지 모두
살아남게 한다.

@<부문별 문턱값을 계산한다@>=
for k := maxN; k >= 1; k-- {
	if p := b.nodeIndex[k]; p != nil {
		if b.thresh == 0 {
			p.thresh = -99999999
		} else {
			p.thresh = ((p.total >> 16) * b.thresh) +
				(((p.total & 0xffff) * b.thresh) >> 16)
		}
	}
}

@ 활성 노드마다 정점을 하나씩 배정한다. \CEE/처럼 뒤에서 앞으로 채운다.

@<정점을 배정한다@>=
vi := b.n
for k := maxN; k >= 1; k-- {
	if p := b.nodeIndex[k]; p != nil {
		vi--
		v := &b.g.Vertices[vi]
		b.vertIndex[k] = v
		v.Name = p.title
		v.Z.A = p.sicList // |SIC_codes|
		v.Y.I = p.total   // |sector_total|
	} else {
		b.vertIndex[k] = nil
	}
}
if vi != 0 {
	return gbgraph.Impossible // 알고리즘 버그; 있을 수 없다
}

@ 흐름이 0이 아니면서 문턱을 넘는 자리마다 호를 하나 놓고 |flow|를 새긴다.

@<정점 사이에 호를 놓는다@>=
for j := maxN; j >= 1; j-- {
	p := b.nodeIndex[j]
	if p == nil {
		continue
	}
	u := b.vertIndex[j]
	for k := maxN; k >= 1; k-- {
		v := b.vertIndex[k]
		if v != nil && p.table[k] != 0 && p.table[k] > b.nodeIndex[k].thresh {
			b.g.NewArc(u, v, 1)
			u.Arcs.A.I = p.table[k] // |flow|
		}
	}
}

@* 시험. \.{econ.dat}이 |../data|에 있다고 보고, {\sc GB\_\,SAMPLE}이 내놓는
|sample.correct|와 대조한다.

@(gbecon_test.go@>=
package gbecon

import (
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
)

const dataDir = "../data"

func TestEconDefaults(t *testing.T) {
	for _, c := range []struct {
		n, omit, want int64
	}{
		{0, 0, 81}, {81, 0, 81}, {0, 2, 79}, {79, 2, 79}, {0, 1, 80},
	} {
		g, err := Econ(c.n, c.omit, 0, 0, dataDir)
		if err != nil {
			t.Fatal(err)
		}
		if g.N != c.want {
			t.Errorf("Econ(%d,%d,0,0).N = %d, 원함 %d", c.n, c.omit, g.N, c.want)
		}
	}
}

@ |econ(40,0,400,-111)|은 정점 40개·호 512개짜리 그래프이고, 그 11번 정점은
``Printing and publishing''(총액 69451)이며, 여섯 호가 정해진 흐름으로 여섯
부문(Users 포함)으로 간다. 정점 차례·호 차례·흐름 값까지 글자 그대로 맞아야
|gbflip|의 난수열과 무작위 가지치기, 호 생성이 \CEE/와 비트까지 같다는 뜻이다.

@(gbecon_test.go@>=
func TestEconSample(t *testing.T) {
	g, err := Econ(40, 0, 400, -111, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	@<그래프의 크기와 머리글을 확인한다@>
	@<정점 11과 그 호들을 확인한다@>
	@<\.{Users} 정점만 SIC 목록이 비었는지 확인한다@>
}

@ @<그래프의 크기와 머리글을 확인한다@>=
if g.ID != "econ(40,0,400,-111)" {
	t.Errorf("ID = %q", g.ID)
}
if g.N != 40 || g.M != 512 {
	t.Fatalf("N=%d M=%d, 원함 N=40 M=512", g.N, g.M)
}
if g.UtilTypes != "ZZZZIAIZZZZZZZ" {
	t.Errorf("UtilTypes = %q", g.UtilTypes)
}

@ @<정점 11과 그 호들을 확인한다@>=
v := &g.Vertices[11]
if v.Name != "Printing and publishing" || v.Y.I != 69451 {
	t.Fatalf("정점 11 = %q[%d], 원함 Printing and publishing[69451]",
		v.Name, v.Y.I)
}
type arc struct {
	name        string
	total, flow int64
}
var got []arc
for a := range v.AllArcs() {
	got = append(got, arc{a.Tip.Name, a.Tip.Y.I, a.A.I})
}
want := []arc{
	{"Food, liquor, and candy", 300724, 1863},
	{"Cigarettes, cigars, tobacco", 24445, 195},
	{"Printing and publishing", 69451, 6089},
	{"Business support services", 463594, 8369},
	{"Personal services", 827615, 9073},
	{"Users", 3999362, 30676},
}
@<|got|과 |want|를 견준다@>

@ @<|got|과 |want|를 견준다@>=
if len(got) != len(want) {
	t.Fatalf("정점 11의 호 %d개, 원함 %d개", len(got), len(want))
}
for i, a := range want {
	if got[i] != a {
		t.Errorf("호 %d = %v, 원함 %v", i, got[i], a)
	}
}

@ \.{Users}는 SIC 부호가 없는 유일한 정점이다(|omit=0|이라 마지막 정점).

@<\.{Users} 정점만 SIC 목록이 비었는지 확인한다@>=
users := &g.Vertices[g.N-1]
if users.Name != "Users" {
	t.Fatalf("마지막 정점 = %q, 원함 Users", users.Name)
}
if users.Z.A != nil {
	t.Errorf("Users의 SIC_codes가 비어 있지 않다")
}
if v.Z.A == nil {
	t.Errorf("정점 11의 SIC_codes가 비어 있다")
}

@ 들어가며에서 든 경제 이야기를 그대로 확인한다. \.{Apparel}의 총상품산출은
54031이고, 자기 자신으로 9259, \.{Household furniture}로 44, \.{Users}로
42172가 흐르며, \.{Users}에서 \.{Apparel}로 오는 부가가치는 19409다.
\.{Users}의 총액이 GNP $=3999362$이고, \.{Adjustments}는 457090으로 GNP의
11\%쯤이다.

@(gbecon_test.go@>=
func find(g *gbgraph.Graph, name string) *gbgraph.Vertex {
	for i := int64(0); i < g.N; i++ {
		if g.Vertices[i].Name == name {
			return &g.Vertices[i]
		}
	}
	return nil
}

func flowTo(u *gbgraph.Vertex, name string) (int64, bool) {
	for a := range u.AllArcs() {
		if a.Tip.Name == name {
			return a.A.I, true
		}
	}
	return 0, false
}

@ @(gbecon_test.go@>=
func TestApparelExample(t *testing.T) {
	g, err := Econ(0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	ap, users := find(g, "Apparel"), find(g, "Users")
	if ap == nil || users == nil {
		t.Fatal("Apparel이나 Users 정점이 없다")
	}
	if ap.Y.I != 54031 {
		t.Errorf("Apparel 총액 = %d, 원함 54031", ap.Y.I)
	}
	@<의류 부문의 호 세 개를 확인한다@>
	if f, ok := flowTo(users, "Apparel"); !ok || f != 19409 {
		t.Errorf("Users->Apparel = %d, 원함 19409", f)
	}
	if users.Y.I != 3999362 {
		t.Errorf("GNP = %d, 원함 3999362", users.Y.I)
	}
	if adj := find(g, "Adjustments"); adj.Y.I != 457090 {
		t.Errorf("Adjustments = %d, 원함 457090", adj.Y.I)
	}
}

@ @<의류 부문의 호 세 개를 확인한다@>=
for _, c := range []struct {
	to   string
	want int64
}{
	{"Apparel", 9259},
	{"Household furniture", 44},
	{"Users", 42172},
} {
	if f, ok := flowTo(ap, c.to); !ok || f != c.want {
		t.Errorf("Apparel->%s = %d, 원함 %d", c.to, f, c.want)
	}
}

@ 음의 흐름을 가진 호는 정확히 열 개이고 모두 \.{Users}로 들어간다. 그중
가장 큰 것이 석유·천연가스의 $-27032$다. 모든 호 흐름의 합은 7198847이다---
Knuth가 책에 적은 7198680이 아니라(들어가며의 단서를 보라).

@(gbecon_test.go@>=
func TestNegativeFlowsAndTotal(t *testing.T) {
	g, err := Econ(0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	@<음의 호를 세고 전체 흐름을 더한다@>
	if neg != 10 {
		t.Errorf("음의 호 = %d개, 원함 10개", neg)
	}
	if sum != 11198209 {
		t.Errorf("전체 호 흐름 = %d, 원함 11198209", sum)
	}
	if sum-g.Vertices[g.N-1].Y.I != 7198847 {
		t.Errorf("Users 나가는 호를 뺀 합 = %d, 원함 7198847",
			sum-g.Vertices[g.N-1].Y.I)
	}
}

@ @<음의 호를 세고 전체 흐름을 더한다@>=
var neg, sum int64
for i := int64(0); i < g.N; i++ {
	for a := range g.Vertices[i].AllArcs() {
		sum += a.A.I
		if a.A.I < 0 {
			neg++
			if a.Tip.Name != "Users" {
				t.Errorf("음의 호가 %q로 간다", a.Tip.Name)
			}
		}
	}
}
if f, _ := flowTo(find(g, "Petroleum and natural gas production"),
	"Users"); f != -27032 {
	t.Errorf("석유·천연가스 -> Users = %d, 원함 -27032", f)
}

@ 문턱값과 가지치기의 발표된 값들이다. |Econ(79,2,0,0)|은 가능한 6241개
가운데 4602개의 호를 갖고, |threshold|를 1로 올리면 4473개, 6000으로 올리면
72개가 된다. 그리고 |Econ(2,2,0,0)|은 \.{Goods}와 \.{Services}를 낸다.

@(gbecon_test.go@>=
func TestThresholdAndPruning(t *testing.T) {
	for _, c := range []struct{ thresh, want int64 }{
		{0, 4602}, {1, 4473}, {6000, 72},
	} {
		g, err := Econ(79, 2, c.thresh, 0, dataDir)
		if err != nil {
			t.Fatal(err)
		}
		if g.M != c.want {
			t.Errorf("Econ(79,2,%d,0).M = %d, 원함 %d", c.thresh, g.M, c.want)
		}
	}
	@<재화와 용역으로 갈리는지 본다@>
}

@ |n=3|이면 갈리는 쪽은 \.{Services}여서 \.{Goods}·\.{Indirect services}·
\.{Direct services}가 된다.

@<재화와 용역으로 갈리는지 본다@>=
for _, c := range []struct {
	n     int64
	names []string
}{
	{2, []string{"Goods", "Services"}},
	{3, []string{"Goods", "Indirect services", "Direct services"}},
} {
	g, err := Econ(c.n, 2, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	for i, want := range c.names {
		if got := g.Vertices[i].Name; got != want {
			t.Errorf("Econ(%d,2,0,0) 정점 %d = %q, 원함 %q", c.n, i, got, want)
		}
	}
}

@ |n=80|, |omit=1|이면 SIC 목록의 길이가 모두 1이라야 한다. 그리고 종이 관련
두 부문의 SIC 부호가 24와 25인지 본다---들어가며에서 합쳐 보인 그 둘이다.

@(gbecon_test.go@>=
func TestSICLists(t *testing.T) {
	g, err := Econ(80, 1, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	for i := int64(0); i < g.N; i++ {
		a := g.Vertices[i].Z.A
		if a == nil || a.Next != nil {
			t.Fatalf("정점 %d(%q)의 SIC 목록 길이가 1이 아니다",
				i, g.Vertices[i].Name)
		}
		if a.Len < 1 || a.Len > 80 {
			t.Errorf("SIC 부호 %d가 범위 밖이다", a.Len)
		}
	}
	for name, want := range map[string]int64{
		"Paper products, except containers": 24,
		"Paperboard containers and boxes":   25,
	} {
		if v := find(g, name); v == nil || v.Z.A.Len != want {
			t.Errorf("%q의 SIC 부호가 %d가 아니다", name, want)
		}
	}
}

@* 찾아보기.
