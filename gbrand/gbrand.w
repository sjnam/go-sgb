% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_rand.w를 Go로 이식한다.
@i ../types.w

\input kotexgweb
\def\title{GB\_\,RAND}

@* 들어가며. 이 모듈은 ``무작위로'' 고른 호나 간선으로 그래프를 짓는 |RandomGraph|와
|RandomBigraph|, 그리고 기존 그래프의 호 길이를 무작위로 바꾸는 |RandomLengths|를
담는다. 이런 무작위 그래프에서 알고리즘이 어떻게 움직이는지는, 다른 GraphBase
생성기가 낳는 (무작위가 아닌) 그래프에서의 움직임과 견줘 볼 만하다.

|RandomGraph(n, m, multi, self, directed, distFrom, distTo, minLen, maxLen, seed)|는
정점 |n|개와 호(또는 간선) |m|개의 그래프를 짓는다. |multi|가 양수면 중복 호를
허용하고, 0이면 금지하고, 음수면 --- 특별한 경우로 --- 중복을 물리적으로 두 번
두는 대신 길이가 더 짧은 쪽 하나로 합친다. |self|가 참이면 자기 고리를 허용한다.
|directed|가 참이면 방향 그래프, 아니면 각 호가 무향 간선이 된다. |distFrom|과
|distTo|는 호의 출발점·도착점에 걸 확률 분포다 --- |nil|이면 정점에 고르게
분포하고, 아니면 $2^{30}$으로 합해지는 음이 아닌 정수 |n|개짜리 배열이라야 한다.
|minLen|과 |maxLen|은 호 길이의 범위로, 그 사이에 고르게 분포한다. 정점의 이름은
그냥 |"0"|, |"1"|, \dots 이다.

@ 씨앗 |seed|가 같으면 어디서 돌리든 똑같은 그래프가 나온다. 이를테면
$$\hbox{|RandomGraph(1000, 5000, 0, false, false, nil, nil, 1, 1, 0)|}$$
은 1000개 정점에 길이 1인 간선 5000개(따라서 호 10000개)를 지닌 무향
그래프를 짓는데, 중복도 자기 고리도 없다. 씨앗을 바꾸면 다른 그래프가
나오지만, 같은 씨앗이면 세상 어디서 돌려도 같은 그래프가 나온다 --- 그래서
그래프 알고리즘을 저마다 다른 곳에서 실험하는 연구자들이 똑같은 조건에서
견줄 수 있다.

@ |RandomGraph|가 문제를 만나면 |nil|과 함께 |gbgraph.PanicCode| 오류를 준다.
아니면 새 그래프를 준다.

@c
package gbrand

import (
	"fmt"
	"strconv"

	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
)

@<상수와 잔심부름@>
@<Walker의 별칭법@>
@<랜덤 함수들@>

@ $2^{30}$은 확률 분포의 단위다(모든 확률을 여기에 맞춰 정수로 나타낸다).
|maxSpan|은 |maxLen-minLen|이 넘으면 안 되는 상한이다.

@<상수와 잔심부름@>=
const (
	probUnit = 1 << 30 // 확률의 단위, $2^{30}$
	maxSpan  = 1 << 31 // |maxLen-minLen|의 상한, $2^{31}$
)

@ |distCode|는 표식에 쓸 문자열이다 --- 분포가 있으면 그 값이 아니라 그냥
|"dist"|라는 이름표를, 없으면 |"0"|을 남긴다(\CEE/ 원본의 |dist_code| 매크로와
같다). |boolInt|는 \CEE/의 0/1 플래그를 표식 문자열에 그대로 남기려고 쓴다.
|normMulti|는 |multi|의 부호만 $-1$, 0, 1로 다듬는다(|RandomGraph|와
|RandomBigraph|가 둘 다 표식에 쓰므로 도우미로 뺀다).

@<상수와 잔심부름@>=
func distCode(dist []int64) string {
	if dist != nil {
		return "dist"
	}
	return "0"
}
@#
func boolInt(b bool) int64 {
	if b {
		return 1
	}
	return 0
}
@#
func normMulti(multi int64) int64 {
	switch {
	case multi > 0:
		return 1
	case multi < 0:
		return -1
	default:
		return 0
	}
}

@ |checkDist|는 확률 분포 |dist|가 올바른지 --- 음수가 없고, 누적 합이 $2^{30}$을
넘지 않고, 끝내 정확히 $2^{30}$이 되는지 --- 살핀다. |dist|가 |nil|이면(고른
분포를 쓰겠다는 뜻이니) 그냥 넘어간다. 어긋난 자리에 따라 |base|·|base+1|·
|base+2|를 준다.

@<상수와 잔심부름@>=
func checkDist(dist []int64, base gbgraph.PanicCode) error {
	if dist == nil {
		return nil
	}
	var acc int64
	for _, p := range dist {
		if p < 0 {
			return base // 음수 확률이 있다
		}
		if p > probUnit-acc {
			return base + 1 // 확률이 너무 크다
		}
		acc += p
	}
	if acc != probUnit {
		return base + 2 // 합이 $2^{30}$이 아니다
	}
	return nil
}

@* Walker의 별칭법. |distFrom|·|distTo|처럼 고르지 않은 분포로 정점을 뽑으려면,
Walker의 별칭법[{\sl Seminumerical Algorithms}, 2판, 연습문제 3.4.1--7]을 쓴다.
길이 |nn|(|n| 이상인 가장 작은 $2$의 거듭제곱)짜리 ``마법'' 표를 만들어 두면,
난수 하나로 뽑기 한 번을 $O(1)$에 해낼 수 있다.

$$\vbox{\halign{\indent#\hfil&\quad#\hfil\cr
확률(prob)&|magicEntry.prob|\cr
대안 색인(inx)&|magicEntry.inx|\cr}}$$

@<Walker의 별칭법@>=
type magicEntry struct {
	prob int64
	inx  int64
}

@ 표를 만드는 동안 두 뭉치(|hi|·|lo|)에 나눠 담아 둔다. |hi|는 평균
$t=2^{30}/|nn|$보다 확률이 큰 자리들, |lo|는 그 나머지다. \CEE/ 원본은 이를
링크드 리스트로 엮지만, Go의 슬라이스를 스택으로 쓰면 같은 차례로 밀고
당길 수 있다 --- 뒤에서 밀고 뒤에서 당기면(LIFO), \CEE/이 앞에서 밀고
당기는 것과 정확히 같은 차례가 된다.

@<Walker의 별칭법@>=
type walkerNode struct {
	key int64 // 확률(다듬어지는 중)
	j   int64 // 뽑힐 정점 번호
}

@ |walker|는 길이 |n|짜리 분포 |dist|로, 길이 |nn|짜리 마법 표를 짓는다. 표를
채우는 순서는 뒤에 쓰일 |RandomGraph|·|RandomLengths|의 재현성과는 무관하다
--- 표 자체가 정점 뽑기의 확률을 결정하므로, \CEE/ 원본과 자리 하나 어긋나지
않아야 훗날 {\sc TEST\_SAMPLE}에서 같은 그래프가 나온다.

@<Walker의 별칭법@>=
func walker(n, nn int64, dist []int64) []magicEntry {
	table := make([]magicEntry, nn)
	t := probUnit / nn // 이 나눗셈은 나머지 없이 떨어진다
	@<|hi|와 |lo| 뭉치를 마련한다@>
	@<|hi| 뭉치가 남은 동안 |lo|와 짝지어 마법 표를 채운다@>
	@<|lo|에 남은, 확률이 |t|인 자리들을 채운다@>
	return table
}

@ |nn|이 |n|보다 크면(즉 |n|이 2의 거듭제곱이 아니면), 남는 자리는 확률
0으로 |lo|에 채운다. 그런 다음 실제 분포 |dist|를 큰 번호부터 훑어 |hi|나
|lo|에 나눠 담는다 --- \CEE/이 앞으로 밀어 넣는 차례를, 나중에 뒤에서 당길
Go 슬라이스에서는 그대로 뒤로 밀어 넣는 차례로 옮긴 것이다.

@<|hi|와 |lo| 뭉치를 마련한다@>=
var hi, lo []walkerNode
for j := nn - 1; j >= n; j-- {
	lo = append(lo, walkerNode{key: 0, j: j})
}
for j := n - 1; j >= 0; j-- {
	node := walkerNode{key: dist[j], j: j}
	if dist[j] > t {
		hi = append(hi, node)
	} else {
		lo = append(lo, node)
	}
}

@ |hi|에서 자리 |p|를, |lo|에서 자리 |q|를 하나씩 꺼낸다. |q|가 뽑힐 확률은
그대로 표에 담고, 그 나머지(|t-q.key|)는 |p|가 차지한다 --- 그래서 |p|의
남은 확률을 그만큼 덜어낸 뒤, 아직 평균보다 크면 |hi|로, 아니면 |lo|로
되돌린다. 스케일을 $2^{30}$에서 $2^{31}$로 바꾸는 과정에서 넘침이 없도록
|x|를 거친다.

@<|hi| 뭉치가 남은 동안 |lo|와 짝지어 마법 표를 채운다@>=
for len(hi) > 0 {
	p := hi[len(hi)-1]
	hi = hi[:len(hi)-1]
	q := lo[len(lo)-1]
	lo = lo[:len(lo)-1]
	x := t*q.j + q.key - 1
	table[q.j] = magicEntry{prob: x + x + 1, inx: p.j}
	@<|p|의 남은 확률을 덜어내, 아직 크면 |hi|로 아니면 |lo|로 되돌린다@>
}

@ @<|p|의 남은 확률을 덜어내, 아직 크면 |hi|로 아니면 |lo|로 되돌린다@>=
p.key -= t - q.key
if p.key > t {
	hi = append(hi, p)
} else {
	lo = append(lo, p)
}

@ |hi|가 다 떨어지면, 남은 |lo| 자리들은 이미 확률이 정확히 |t|다 --- 더 나눠
줄 여윳돈도, 받을 빚도 없다는 뜻이다. 그래서 |inx|는 결코 쓰이지 않는다.

@<|lo|에 남은, 확률이 |t|인 자리들을 채운다@>=
for len(lo) > 0 {
	q := lo[len(lo)-1]
	lo = lo[:len(lo)-1]
	x := t*q.j + t - 1
	table[q.j] = magicEntry{prob: x + x + 1}
}

@* 랜덤 그래프들. 이제껏 마련한 도구로 본론을 짓는다. 매개변수를 다듬고, 빈
그래프에 |"0"|부터 |"n-1"|까지 이름 붙은 정점을 마련하고, |distFrom|이나
|distTo|가 있으면 필요한 별칭 표를 짓고, 마지막으로 무작위 호(또는 간선)를
|m|개 채운다.

@<랜덤 함수들@>=
// |RandomGraph|는 정점 |n|개, 호(또는 간선) |m|개짜리 무작위 그래프를 짓는다.
func RandomGraph(n, m, multi int64, self, directed bool, distFrom, distTo []int64,
	minLen, maxLen, seed int64) (*gbgraph.Graph, error) {
	@<|RandomGraph|의 매개변수를 확인한다@>
	rng := gbflip.New(seed)
	g := gbgraph.NewGraph(n)
	for k := int64(0); k < n; k++ {
		g.Vertices[k].Name = strconv.FormatInt(k, 10)
	}
	g.ID = fmt.Sprintf("random_graph(%d,%d,%d,%d,%d,%s,%s,%d,%d,%d)",
		n, m, normMulti(multi), boolInt(self), boolInt(directed),
		distCode(distFrom), distCode(distTo), minLen, maxLen, seed)
	@<필요하면 |distFrom|·|distTo|의 별칭 표를 짓는다@>
	@<무작위 호나 간선을 |m|개 채운다@>
	return g, nil
}

@ |n|은 0일 수 없고, 길이 범위는 거꾸로거나 너무 넓으면 안 된다. 두 분포도
올바라야 한다.

@<|RandomGraph|의 매개변수를 확인한다@>=
if n == 0 {
	return nil, gbgraph.BadSpecs // 정점이 하나는 있어야 한다
}
if minLen > maxLen {
	return nil, gbgraph.VeryBadSpecs // 대체 뭘 하려는 건가
}
if maxLen-minLen >= maxSpan {
	return nil, gbgraph.BadSpecs + 1 // 범위가 너무 넓다
}
if err := checkDist(distFrom, gbgraph.InvalidOperand); err != nil {
	return nil, err
}
if err := checkDist(distTo, gbgraph.InvalidOperand+5); err != nil {
	return nil, err
}

@ |kk|는 $31-\lceil\lg n\rceil$이다: 31비트 균등 난수의 위쪽 비트들을 오른쪽으로
|kk|만큼 밀면, |nn|(|n| 이상인 가장 작은 2의 거듭제곱) 미만의 균등한 색인을
얻는다. 두 분포가 있어도 |n|이 같으므로 표 하나의 |nn|·|kk|를 함께 쓴다.

@<필요하면 |distFrom|·|distTo|의 별칭 표를 짓는다@>=
var fromTable, toTable []magicEntry
nn, kk := int64(1), int64(31)
for nn < n {
	nn += nn
	kk--
}
if distFrom != nil {
	fromTable = walker(n, nn, distFrom)
}
if distTo != nil {
	toTable = walker(n, nn, distTo)
}

@ 매 걸음, |distFrom|·|distTo|가 있으면 별칭 표로, 없으면 고르게 정점 |u|·|v|를
뽑는다. |u==v|인데 자기 고리를 허용하지 않으면 다시 뽑는다. |multi<=0|이면 이미
있는 호를 찾아본다 --- |multi==0|이면 다시 뽑고, |multi<0|이면 둘 중 짧은 길이로
합친다. 그도 아니면 새 호(또는 간선)를 보탠다.

@<무작위 호나 간선을 |m|개 채운다@>=
@<정점 뽑기와 길이 뽑기 잔심부름을 마련한다@>
for mm := m; mm > 0; mm-- {
	@<무작위 정점 |u|·|v|를 뽑아 호나 간선 하나를 보탠다@>
}

@ |pick|은 별칭 표 하나로 정점을 뽑고, |randLen|은 |minLen|·|maxLen| 사이의
길이를 뽑는다.

@<정점 뽑기와 길이 뽑기 잔심부름을 마련한다@>=
pick := func(table []magicEntry) *gbgraph.Vertex {
	uu := rng.Next()
	k := uu >> kk
	magic := table[k]
	if uu <= magic.prob {
		return &g.Vertices[k]
	}
	return &g.Vertices[magic.inx]
}
randLen := func() int64 {
	if minLen == maxLen {
		return minLen
	}
	return minLen + rng.Unif(maxLen-minLen+1)
}

@ @<무작위 정점 |u|·|v|를 뽑아 호나 간선 하나를 보탠다@>=
for {
	var u, v *gbgraph.Vertex
	if distFrom != nil {
		u = pick(fromTable)
	} else {
		u = &g.Vertices[rng.Unif(n)]
	}
	if distTo != nil {
		v = pick(toTable)
	} else {
		v = &g.Vertices[rng.Unif(n)]
	}
	if u == v && !self {
		continue // 자기 고리는 안 된다 --- 다시 뽑는다
	}
	@<|multi<=0|이면 이미 있는 호를 찾아 다루고, 처리했으면 |continue| 또는
	  |break|한다@>
	if directed {
		g.NewArc(u, v, randLen())
	} else {
		g.NewEdge(u, v, randLen())
	}
	break
}

@ 길이를 줄이며 합칠 때, 짝지어진 두 호가 나란히 있다는 사실 대신 |Partner|로
짝을 또렷이 찾는다(\CEE/의 |edge_trick| 포인터 산술은 필요 없다).

@<|multi<=0|이면 이미 있는 호를 찾아 다루고, 처리했으면 |continue| 또는
  |break|한다@>=
if multi <= 0 {
	var dup *gbgraph.Arc
	for a := u.Arcs; a != nil; a = a.Next {
		if a.Tip == v {
			dup = a
			break
		}
	}
	if dup != nil {
		if multi == 0 {
			continue // 중복은 마다한다 --- 다시 뽑는다
		}
		length := randLen()
		if length < dup.Len {
			dup.Len = length
			if !directed {
				dup.Partner.Len = length
			}
		}
		break // 합쳤으니 이걸로 됐다
	}
}

@ |RandomBigraph|. |random_graph|의 특수한 경우로, 두 갈래 |n1|·|n2|개의
정점 사이에 간선 |m|개를 무작위로 놓는다. |dist1|은 |distFrom|의 앞
|n1|자리로, |dist2|는 |distTo|의 뒤 |n2|자리로 옮기고, 나머지는 0으로 채운다.
|dist1|(또는 |dist2|)이 |nil|이면, 그 갈래의 정점들에 고르게(반올림 오차를
$k$로 나눠 메워) 확률을 지어낸다.
@<랜덤 함수들@>=
// |RandomBigraph|는 두 갈래 |n1|·|n2|개 정점, 간선 |m|개짜리 무작위 이분
// 그래프를 짓는다.
func RandomBigraph(n1, n2, m, multi int64, dist1, dist2 []int64,
	minLen, maxLen, seed int64) (*gbgraph.Graph, error) {
	if n1 == 0 || n2 == 0 {
		return nil, gbgraph.BadSpecs // 두 갈래 다 정점이 있어야 한다
	}
	if minLen > maxLen {
		return nil, gbgraph.VeryBadSpecs
	}
	if maxLen-minLen >= maxSpan {
		return nil, gbgraph.BadSpecs + 1
	}
	n := n1 + n2
	@<|dist1|·|dist2|를 |distFrom|·|distTo|로 옮기거나 지어낸다@>
	g, err := RandomGraph(n, m, multi, false, false, distFrom, distTo, minLen, maxLen, seed)
	if err != nil {
		return nil, err
	}
	g.ID = fmt.Sprintf("random_bigraph(%d,%d,%d,%d,%s,%s,%d,%d,%d)",
		n1, n2, m, normMulti(multi), distCode(dist1), distCode(dist2), minLen, maxLen, seed)
	g.MarkBipartite(n1)
	return g, nil
}

@ $\lfloor x/n\rfloor+\lfloor(x+1)/n\rfloor+\cdots+\lfloor(x+n-1)/n\rfloor=\lfloor x\rfloor$
라는 항등식 덕에, |(probUnit+k)/n1|(|k=0,\dots,n1-1|)을 더하면 정확히
|probUnit|이 된다.

@<|dist1|·|dist2|를 |distFrom|·|distTo|로 옮기거나 지어낸다@>=
distFrom := make([]int64, n)
distTo := make([]int64, n)
if dist1 != nil {
	copy(distFrom, dist1)
} else {
	for k := int64(0); k < n1; k++ {
		distFrom[k] = (probUnit + k) / n1
	}
}
if dist2 != nil {
	copy(distTo[n1:], dist2)
} else {
	for k := int64(0); k < n2; k++ {
		distTo[n1+k] = (probUnit + k) / n2
	}
}

@ |RandomLengths|. 기존 그래프 |g|의 모든 호에 새 길이를 매긴다. |directed|가
거짓이면, $u\to v$와 $v\to u$ 호 한 쌍을 간선 하나로 보아 같은 길이를 준다.
@<랜덤 함수들@>=
// |RandomLengths|는 그래프 |g|의 모든 호에 새 무작위 길이를 매긴다.
func RandomLengths(g *gbgraph.Graph, directed bool, minLen, maxLen int64,
	dist []int64, seed int64) error {
	if g == nil {
		return gbgraph.MissingOperand // |g|가 어디 있나
	}
	if minLen > maxLen {
		return gbgraph.VeryBadSpecs
	}
	if maxLen-minLen >= maxSpan {
		return gbgraph.BadSpecs
	}
	rng := gbflip.New(seed)
	@<필요하면 |dist|를 살피고 별칭 표를 짓는다@>
	g.MakeCompoundID("random_lengths(", g, fmt.Sprintf(",%d,%d,%d,%s,%d)",
		boolInt(directed), minLen, maxLen, distCode(dist), seed))
	@<모든 호를 훑어 새 길이를 매긴다@>
	return nil
}

@ 여기서는 \CEE/ 원본처럼 어긋난 자리마다 다른 임시 수(|-1|,|1|,|2|)를 돌려주지
않는다 --- 우리 판은 |gbgraph.PanicCode|로 오류를 통일하는 편이 나머지 모듈과
어울린다.

@<필요하면 |dist|를 살피고 별칭 표를 짓는다@>=
var distTable []magicEntry
kk := int64(31)
if dist != nil {
	n := maxLen - minLen + 1
	if err := checkDist(dist, gbgraph.InvalidOperand); err != nil {
		return err
	}
	nn := int64(1)
	for nn < n {
		nn += nn
		kk--
	}
	distTable = walker(n, nn, dist)
}

@ 무향 그래프에서 |u|가 |v|보다 나중 정점이면(즉 이미 |v|를 훑을 때 이 간선의
길이를 정했으면), 그 짝의 길이를 그대로 베낀다. 아니면 새로 뽑는다. 자기
고리의 첫 호(|a.Next==a.Partner|로 알아본다)라면, 짝의 길이도 함께 매기고
그 짝은 건너뛴다 --- 안 그러면 자기 고리 하나에 난수를 두 번 쓰게 된다.

@<모든 호를 훑어 새 길이를 매긴다@>=
randLen := func() int64 {
	if minLen == maxLen {
		return minLen
	}
	return minLen + rng.Unif(maxLen-minLen+1)
}
for i := int64(0); i < g.N; i++ {
	u := &g.Vertices[i]
	for a := u.Arcs; a != nil; a = a.Next {
		v := a.Tip
		if !directed && g.Index(u) > g.Index(v) {
			a.Len = a.Partner.Len
			continue
		}
		var length int64
		if dist == nil {
			length = randLen()
		} else {
			uu := rng.Next()
			k := uu >> kk
			magic := distTable[k]
			if uu <= magic.prob {
				length = minLen + k
			} else {
				length = minLen + magic.inx
			}
		}
		a.Len = length
		if !directed && u == v && a.Next == a.Partner {
			a.Partner.Len = length
			a = a.Next // 짝을 건너뛴다
		}
	}
}

@* 시험.

@(gbrand_test.go@>=
package gbrand

import "testing"

@<기본 무향 그래프 시험@>
@<방향·자기고리·중복 시험@>
@<고르지 않은 분포 시험@>
@<이분 그래프 시험@>
@<|RandomLengths| 시험@>

@ 들어가며 절의 예시 그대로다: 정점 1000개, 간선 5000개(호 10000개), 중복도
자기 고리도 없다.

@<기본 무향 그래프 시험@>=
func TestBasicUndirected(t *testing.T) {
	g, err := RandomGraph(1000, 5000, 0, false, false, nil, nil, 1, 1, 0)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 1000 {
		t.Errorf("N = %d, 원함 1000", g.N)
	}
	if g.M != 10000 {
		t.Errorf("M = %d, 원함 10000", g.M)
	}
	if g.ID != "random_graph(1000,5000,0,0,0,0,0,1,1,0)" {
		t.Errorf("ID = %q", g.ID)
	}
	seen := make(map[[2]int64]bool)
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if a.Tip == &g.Vertices[i] {
				t.Fatalf("자기 고리가 있으면 안 된다: 정점 %d", i)
			}
			key := [2]int64{i, g.Index(a.Tip)}
			if seen[key] {
				t.Fatalf("중복 호가 있으면 안 된다: %v", key)
			}
			seen[key] = true
		}
	}
}

@ 같은 씨앗이면 그래프가 결정적이어야 한다.

@<기본 무향 그래프 시험@>=
func TestDeterministic(t *testing.T) {
	g1, err := RandomGraph(50, 100, 1, true, true, nil, nil, 1, 10, 42)
	if err != nil {
		t.Fatal(err)
	}
	g2, err := RandomGraph(50, 100, 1, true, true, nil, nil, 1, 10, 42)
	if err != nil {
		t.Fatal(err)
	}
	for i := int64(0); i < g1.N; i++ {
		a1, a2 := g1.Vertices[i].Arcs, g2.Vertices[i].Arcs
		for a1 != nil || a2 != nil {
			if a1 == nil || a2 == nil {
				t.Fatalf("정점 %d의 호 수가 다르다", i)
			}
			if g1.Index(a1.Tip) != g2.Index(a2.Tip) || a1.Len != a2.Len {
				t.Fatalf("정점 %d의 호가 다르다", i)
			}
			a1, a2 = a1.Next, a2.Next
		}
	}
}

@ |directed|와 |self|를 함께 켜면 자기 고리가 나올 수 있다. |multi|를 켜면
같은 방향 호가 두 번 이상 나올 수 있다 --- 정점이 둘뿐이고 호가 많으면
사실상 반드시 그렇게 된다.

@<방향·자기고리·중복 시험@>=
func TestDirectedSelfMulti(t *testing.T) {
	g, err := RandomGraph(2, 500, 1, true, true, nil, nil, 1, 1, 7)
	if err != nil {
		t.Fatal(err)
	}
	if g.M != 500 {
		t.Errorf("M = %d, 원함 500", g.M)
	}
	sawSelfLoop, sawDup := false, false
	for i := int64(0); i < g.N; i++ {
		seen := make(map[int64]int)
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if a.Tip == &g.Vertices[i] {
				sawSelfLoop = true
			}
			seen[g.Index(a.Tip)]++
			if seen[g.Index(a.Tip)] > 1 {
				sawDup = true
			}
		}
	}
	if !sawSelfLoop {
		t.Error("500개 호에 자기 고리가 하나도 없다 --- 못 믿을 우연이다")
	}
	if !sawDup {
		t.Error("500개 호에 중복이 하나도 없다 --- 못 믿을 우연이다")
	}
}

@ |multi=0|으로 중복을 금지하면, 두 정점 사이의 방향 호는 많아야 하나다.

@<방향·자기고리·중복 시험@>=
func TestNoDuplicates(t *testing.T) {
	g, err := RandomGraph(5, 15, 0, false, true, nil, nil, 1, 1, 3)
	if err != nil {
		t.Fatal(err)
	}
	for i := int64(0); i < g.N; i++ {
		seen := make(map[int64]bool)
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			key := g.Index(a.Tip)
			if seen[key] {
				t.Fatalf("정점 %d에서 %d로 가는 호가 중복됐다", i, key)
			}
			seen[key] = true
		}
	}
}

@ \.{gb\_rand.w}의 예시를 본떠, 정점 |k|가 |k+1|보다 출발점으로는 두 배
뽑히기 쉽게 만든다. 기하수열 $2^{29},2^{28},\dots,2^{23},2^{23}$(마지막 둘은
같다)은 나머지 없이 정확히 |probUnit|으로 합해진다. |distTo|는 그 순서를
뒤집어, 정점 |k|가 도착점으로는 절반만큼만 뽑히기 쉽게 한다. 그러면 |0|에서
|n-1|로 가는 호가 |n-1|에서 |0|으로 가는 호보다 훨씬 흔해야 한다.

@<고르지 않은 분포 시험@>=
func TestNonuniformDistribution(t *testing.T) {
	const n = 8
	var distFrom, distTo [n]int64
	for k := 0; k < n; k++ {
		shift := k + 1
		if shift == n {
			shift = n - 1 // 마지막 두 자리는 무게가 같다
		}
		distFrom[k] = probUnit >> shift
	}
	for k := 0; k < n; k++ {
		distTo[k] = distFrom[n-1-k]
	}
	g, err := RandomGraph(n, 20000, 1, false, true,
		distFrom[:], distTo[:], 1, 1, 1)
	if err != nil {
		t.Fatal(err)
	}
	forward, backward := 0, 0
	for a := g.Vertices[0].Arcs; a != nil; a = a.Next {
		if g.Index(a.Tip) == n-1 {
			forward++
		}
	}
	for a := g.Vertices[n-1].Arcs; a != nil; a = a.Next {
		if g.Index(a.Tip) == 0 {
			backward++
		}
	}
	if forward <= backward {
		t.Errorf("0->%d(%d개)가 %d->0(%d개)보다 흔해야 한다", n-1, forward, n-1, backward)
	}
}

@ \.{test\_sample.w}가 쓰는 것과 같은 분포([0x20000000,0x10000000,0x10000000])로
석 점짜리 그래프를 지어, 별칭 표 경로가 부수지 않고 도는지 확인한다.

@<고르지 않은 분포 시험@>=
func TestWalkerTableRuns(t *testing.T) {
	dist := []int64{0x20000000, 0x10000000, 0x10000000}
	g, err := RandomGraph(3, 10, 1, true, false, nil, dist, 1, 2, 1)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 3 {
		t.Fatalf("N = %d, 원함 3", g.N)
	}
	for i := int64(0); i < g.N; i++ {
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if a.Len < 1 || a.Len > 2 {
				t.Errorf("길이 %d가 [1,2] 밖이다", a.Len)
			}
		}
	}
}

@ |RandomBigraph(50,30,200,...)|는 정점 $50+30$개짜리 이분 그래프를 짓는다.
모든 간선이 두 갈래를 잇는지 확인한다.

@<이분 그래프 시험@>=
func TestRandomBigraph(t *testing.T) {
	g, err := RandomBigraph(50, 30, 200, 1, nil, nil, 1, 5, 9)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 80 {
		t.Fatalf("N = %d, 원함 80", g.N)
	}
	if g.N1() != 50 {
		t.Errorf("N1 = %d, 원함 50", g.N1())
	}
	if g.M != 400 {
		t.Errorf("M = %d, 원함 400", g.M)
	}
	n1 := g.N1()
	for i := int64(0); i < g.N; i++ {
		left := i < n1
		for a := g.Vertices[i].Arcs; a != nil; a = a.Next {
			if (g.Index(a.Tip) < n1) == left {
				t.Fatalf("간선이 두 갈래를 잇지 않는다: %d -> %d", i, g.Index(a.Tip))
			}
		}
	}
}

@ 기존 그래프의 길이를 |RandomLengths|로 바꾼다. 무향 그래프이므로 간선의
두 호는 늘 길이가 같아야 한다.

@<|RandomLengths| 시험@>=
func TestRandomLengths(t *testing.T) {
	g, err := RandomGraph(20, 40, 1, false, false, nil, nil, 1, 1, 2)
	if err != nil {
		t.Fatal(err)
	}
	if err := RandomLengths(g, false, 100, 200, nil, 5); err != nil {
		t.Fatal(err)
	}
	for i := int64(0); i < g.N; i++ {
		u := &g.Vertices[i]
		for a := u.Arcs; a != nil; a = a.Next {
			if a.Len < 100 || a.Len > 200 {
				t.Errorf("길이 %d가 [100,200] 밖이다", a.Len)
			}
			if a.Len != a.Partner.Len {
				t.Errorf("짝의 길이가 다르다: %d != %d", a.Len, a.Partner.Len)
			}
		}
	}
}

@* 찾아보기.
