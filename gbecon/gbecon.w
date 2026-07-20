% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_econ.w를 Go로 이식한다.
@i ../gbtypes.w

\input kotexgweb
\def\title{GB\_\,ECON}

@* 들어가며. 이 모듈은 산업 사이의 돈 흐름에 바탕한 유향 그래프 집안을 짓는
|Econ| 서브루틴을 담는다. 쓰임새는 데모 {\sc ECON\_\,ORDER}에서 볼 수 있다.

|Econ(n, omit, threshold, seed, dir)|은 |dir| 디렉터리의 \.{econ.dat}에 담긴
정보로 유향 그래프를 짓는다. 각 정점은 1985년 미국 경제의 81개 부문 가운데
하나에 대응한다. |omit=threshold=0|이면 이 그래프는 ``순환(circulation)''이다:
각 호에 |flow| 값이 있고, 정점마다 나가는 호 흐름의 합과 들어오는 호 흐름의
합이 같다.

@ |omit=1|이면 \.{Users} 정점(우리 같은 최종 소비자)이 빠지고, 따라서 음의
흐름 호가 모두 사라진다. |omit=2|이면 \.{Adjustments} 정점까지 빠져 79개 산업
부문만 남는다. 두 특별 정점이 남으면 \.{Users}가 마지막, \.{Adjustments}가
그 앞 정점이다.

|threshold=0|이면 흐름이 0이 아닌 호가 모두 생긴다. |threshold>0|이면 그래프가
성겨진다: 부문 |j|가 부문 |k|에 댄 양이 |k|의 총투입의 |threshold|/65536배를
넘을 때만 $j\to k$ 호가 생긴다. 호의 |len|은 언제나 1이다.

@ 그래프의 정점 수는 $\min(n,81-|omit|)$이다. |n|이 |81-omit|보다 작으면,
79개 비특별 부문의 고정된 위계 이진 트리를 가지치기해 |n|개 잎만 남긴다.
|seed=0|이면 총투입·총산출이 되도록 고르게 나뉘도록 가지치기하고, |seed>0|이면
원 트리의 모든 |n|-잎 부분트리가 (기계 독립적으로) 거의 같은 확률로 나오도록
무작위로 가지친다. 늘 그렇듯 |n=0|은 최대값을 뜻한다.

@ 유틸리티 필드: 호의 |flow|는 |A.I|, 정점의 |sector_total|(총투입=총산출)은
|Y.I|, SIC 부호 목록 |SIC_codes|는 |Z.A|에 둔다. 문제가 생기면 |Econ|은 |nil|과
함께 |error|(곧 |gbgraph.PanicCode|)를 돌려준다. \CEE/의 |calloc| 실패 경로는
\GO/의 |make|가 실패를 모르므로 사라졌다.

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
이름 뒤에 콜론이 오고, 잎이면 콜론 뒤에 SIC 번호가 온다. 전위 순회의 성질
덕에 트리가 유일하게 정해진다(폴란드 전위 표기와 같다). 두 특별 부문 이름은
파일에 없으므로 우리가 만들어 붙인다.

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
자료 줄로 되어 있고, 자료 줄마다 쉼표로 나뉜 10개의 수가 온다. 0은 |"0"|이
아니라 |""|로 적힌다.

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
트리를 가지치기해 부분트리를 ``기른다''. 고른 잎은 |tag| 필드가 1이 된다.

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
구하고, 위에서 아래로 내려가며 총투입이 큰 부문부터 나눈다. |special| 노드
(\.{Users})는 두 구실을 한다: |total|의 내림차순으로 정렬된 미탐색 노드 연결
리스트의 머리이자, |special->total=0|이라 그 리스트의 꼬리이기도 하다.

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

@ 주어진 트리의 |l|-잎 부분트리를 고르게 뽑는 방법: 부분트리 $T_0$, $T_1$을
가진 트리 $T$의 |l|-잎 부분트리 수는 $T(l)=\sum_k T_0(k)T_1(l-k)$이다. $0$과
$T(l)-1$ 사이 난수 $r$을 뽑아, $\sum_{k\le m}T_0(k)T_1(l-k)>r$인 가장 작은 $m$을
찾고, $T_0$의 $m$-잎, $T_1$의 $(l-m)$-잎 부분트리를 재귀적으로 구한다.

$T(l)$ 값들을 아래에서 위로 계산해 |table|에 담고(잎 수는 |table[0]|,
$T(l)$은 |table[l]|), 무작위 트리를 위에서 아래로 기른다. |tag| 필드는 그
노드 아래 기를 잎의 수가 된다.

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

@ 여기서는 두 생성 함수를 곱한다. $f_p(z)=z+f_{pl}(z)f_{pr}(z)$이다.

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
일반적으로는 몇몇 미시 부문을 거시 부문으로 합쳐야 한다. 이는 아래에서 위로의
가지치기다. |p|가 |pl|과 |pr|의 합집합이면, |p|에서 나가는 호는 |pl|·|pr|에서
나가는 수들의 합, 들어오는 호는 들어오는 수들의 합이다.

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

@ \.{Users}가 빠지지 않으면 각 부문의 총 최종 수요(행 합과 열 합이 같아지도록
정한 값)를 |table[MAX_N]|에 채운다. \.{Users} 특별 노드에서는 |total|과
|table[MAX_N]|(GNP)을 맞바꾼다.

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

@ 정수 $a,b,c,d$($b,d>0$)에 대해 ${a\over b}>{c\over d}$는
$a>\lfloor b/d\rfloor c+\lfloor(b\bmod d)c/d\rfloor$과 같다. 여기서
$b=$|total|, $c=$|threshold|$\le d=65536$이라 곱셈이 넘치지 않는다.

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

import "testing"

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

@* 찾아보기.
