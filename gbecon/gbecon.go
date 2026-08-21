//line gbecon.w:148
package gbecon

import (
	"fmt"
	"path/filepath"

	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
)

const (
	maxN   = 81 // 만드는 그래프의 최대 정점 수
	normN  = 79 // 보통 SIC 부문의 수 (|maxN-2|)
	adjSec = 80 // \.{Adjustments} 부문의 부호 번호 (|maxN-1|)
)

//line gbecon.w:177
type node struct {
	idx     int             // |nodeBlock| 안의 전위 순회 위치
	rchild  *node           // 거시 부문의 오른쪽 자식
	title   string          // 부문 이름
	table   [maxN + 1]int64 // 이 부문의 산출들
	total   int64           // 이 부문의 총투입 (= 총산출)
	thresh  int64           // 이 부문으로 오는 호의 |flow| 문턱
	SIC     int64           // SIC 부호 번호; 거시 부문은 처음엔 0
	tag     int64           // 이 노드가 그래프 정점이 되면 1 (또는 잎 수)
	link    *node           // 아직 안 살핀 다음 부문
	sicList *gbgraph.Arc    // SIC 부호 목록의 첫 항목
}

//line gbecon.w:193
type builder struct {
	rng             *gbflip.RNG
	f               *gbio.File
	g               *gbgraph.Graph
	n, omit, thresh int64
	nodeBlock       []node                    // 전위 순회로 트리를 나타내는 노드 배열
	nodeIndex       [maxN + 1]*node           // 주어진 SIC 부호를 가진 노드
	vertIndex       [maxN + 1]*gbgraph.Vertex // SIC 부호에 배정된 정점
	stack           [normN + normN]*node      // 오른쪽 자식을 채울 노드들
	stackPtr        int
}

//line gbecon.w:209
func (b *builder) left(p *node) *node {
	return &b.nodeBlock[p.idx+1]
}

//line gbecon.w:217
func Econ(n, omit, threshold, seed int64, dir string) (*gbgraph.Graph, error) {
	b := &builder{rng: gbflip.New(seed)}

//line gbecon.w:236
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

//line gbecon.w:220
	b.n, b.omit, b.thresh = n, omit, threshold

//line gbecon.w:249
	b.g = gbgraph.NewGraph(n)
	b.g.ID = fmt.Sprintf("econ(%d,%d,%d,%d)", n, omit, threshold, seed)
	b.g.UtilTypes = "ZZZZIAIZZZZZZZ"

//line gbecon.w:222
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

//line gbecon.w:268
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

//line gbecon.w:291
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

//line gbecon.w:321
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

//line gbecon.w:279
	for k := int64(1); k <= maxN; k++ {

//line gbecon.w:348
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

//line gbecon.w:364
			if j%10 == 0 {
				if b.f.Char() != '\n' {
					return gbgraph.SyntaxError + 6 // 입력 파일의 동기가 어긋났다
				}
				b.f.NextLine()
			} else if b.f.Char() != ',' {
				return gbgraph.SyntaxError + 7 // 항목 뒤에 쉼표가 없다
			}

//line gbecon.w:360
		}
		p.table[maxN] = s // |table[1]|부터 |table[80]|까지의 합

//line gbecon.w:281
	}
	return nil
}

//line gbecon.w:380
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

//line gbecon.w:407
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

//line gbecon.w:426
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

//line gbecon.w:419
	}
	for p := special.link; p != special; p = p.link {
		p.tag = 1 // 리스트에 남은 것을 모두 태그한다
	}
}

//line gbecon.w:472
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

//line gbecon.w:488
			l := p.tag
			pl, pr := b.left(p), p.rchild
			switch {
			case pl.rchild == nil:
				pl.tag, pr.tag = 1, l-1
			case pr.rchild == nil:
				pl.tag, pr.tag = l-1, 1
			default:

//line gbecon.w:542
				var ss int64
				scale := false
				if p.idx == 0 { // 뿌리
					if l > 29 && l < 67 {
						scale = true // $2^{31}$을 넘는 경우
					}
					for k := max(l-pr.table[0], 1); k <= pl.table[0] && k < l; k++ {

//line gbecon.w:566
						if scale {
							ss += ((pl.table[k] + 0x3ff) >> 10) * pr.table[l-k]
						} else {
							ss += pl.table[k] * pr.table[l-k]
						}

//line gbecon.w:550
					}
				} else {
					ss = p.table[l]
				}
				rr := b.rng.Unif(ss)
				ss = 0
				var k int64
				for k = max(l-pr.table[0], 1); ss <= rr; k++ {

//line gbecon.w:566
					if scale {
						ss += ((pl.table[k] + 0x3ff) >> 10) * pr.table[l-k]
					} else {
						ss += pl.table[k] * pr.table[l-k]
					}

//line gbecon.w:559
				}
				pl.tag, pr.tag = k-1, l-k+1

//line gbecon.w:497
			}

//line gbecon.w:483
		}
	}
}

//line gbecon.w:506
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

//line gbecon.w:529
		p.table[2] = 0
		for j := pl.table[0]; j >= 1; j-- {
			t := pl.table[j]
			for k := pr.table[0]; k >= 1; k-- {
				p.table[j+k] += t * pr.table[k]
			}
		}

//line gbecon.w:524
		p.table[0] = pl.table[0] + pr.table[0]
	}
}

//line gbecon.w:586
func (b *builder) makeArcs() error {

//line gbecon.w:599
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

//line gbecon.w:618
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

//line gbecon.w:611
			}
		}
	}

//line gbecon.w:588

//line gbecon.w:650
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

//line gbecon.w:589

//line gbecon.w:678
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

//line gbecon.w:590

//line gbecon.w:692
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

//line gbecon.w:591

//line gbecon.w:712
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

//line gbecon.w:592
	return nil
}
