//line gbrand.w:66
package gbrand

import (
	"fmt"
	"strconv"

	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
)

//line gbrand.w:84
const (
	probUnit = 1 << 30 // 확률의 단위, $2^{30}$
	maxSpan  = 1 << 31 // |maxLen-minLen|의 상한, $2^{31}$
)

//line gbrand.w:96
func distCode(dist []int64) string {
	if dist != nil {
		return "dist"
	}
	return "0"
}

func boolInt(b bool) int64 {
	if b {
		return 1
	}
	return 0
}

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

//line gbrand.w:127
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

//line gbrand.w:157
type magicEntry struct {
	prob int64
	inx  int64
}

//line gbrand.w:169
type walkerNode struct {
	key int64 // 확률(다듬어지는 중)
	j   int64 // 뽑힐 정점 번호
}

//line gbrand.w:180
func walker(n, nn int64, dist []int64) []magicEntry {
	table := make([]magicEntry, nn)
	t := probUnit / nn // 이 나눗셈은 나머지 없이 떨어진다

//line gbrand.w:195
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

//line gbrand.w:184

//line gbrand.w:215
	for len(hi) > 0 {
		p := hi[len(hi)-1]
		hi = hi[:len(hi)-1]
		q := lo[len(lo)-1]
		lo = lo[:len(lo)-1]
		x := t*q.j + q.key - 1
		table[q.j] = magicEntry{prob: x + x + 1, inx: p.j}

//line gbrand.w:226
		p.key -= t - q.key
		if p.key > t {
			hi = append(hi, p)
		} else {
			lo = append(lo, p)
		}

//line gbrand.w:223
	}

//line gbrand.w:185

//line gbrand.w:237
	for len(lo) > 0 {
		q := lo[len(lo)-1]
		lo = lo[:len(lo)-1]
		x := t*q.j + t - 1
		table[q.j] = magicEntry{prob: x + x + 1}
	}

//line gbrand.w:186
	return table
}

//line gbrand.w:250
func RandomGraph(n, m, multi int64, self, directed bool, distFrom, distTo []int64,
	minLen, maxLen, seed int64) (*gbgraph.Graph, error) {

//line gbrand.w:269
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

//line gbrand.w:253
	rng := gbflip.New(seed)
	g := gbgraph.NewGraph(n)
	for k := int64(0); k < n; k++ {
		g.Vertices[k].Name = strconv.FormatInt(k, 10)
	}
	g.ID = fmt.Sprintf("random_graph(%d,%d,%d,%d,%d,%s,%s,%d,%d,%d)",
		n, m, normMulti(multi), boolInt(self), boolInt(directed),
		distCode(distFrom), distCode(distTo), minLen, maxLen, seed)

//line gbrand.w:290
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

//line gbrand.w:262

//line gbrand.w:318
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

//line gbrand.w:310
	for mm := m; mm > 0; mm-- {

//line gbrand.w:335
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
				continue // 자기 고리는 안 된다---다시 뽑는다
			}

//line gbrand.w:365
			if multi <= 0 {
				var dup *gbgraph.Arc
				for a := range u.AllArcs() {
					if a.Tip == v {
						dup = a
						break
					}
				}
				if dup != nil {
					if multi == 0 {
						continue // 중복은 마다한다---다시 뽑는다
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

//line gbrand.w:351
			if directed {
				g.NewArc(u, v, randLen())
			} else {
				g.NewEdge(u, v, randLen())
			}
			break
		}

//line gbrand.w:312
	}

//line gbrand.w:263
	return g, nil
}

// |RandomBigraph|는 두 갈래 |n1|·|n2|개 정점, 간선 |m|개짜리 무작위 이분
// 그래프를 짓는다.
//
//line gbrand.w:394
//line gbrand.w:395
//line gbrand.w:396
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

//line gbrand.w:424
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

//line gbrand.w:409
	g, err := RandomGraph(n, m, multi, false, false, distFrom, distTo, minLen, maxLen, seed)
	if err != nil {
		return nil, err
	}
	g.ID = fmt.Sprintf("random_bigraph(%d,%d,%d,%d,%s,%s,%d,%d,%d)",
		n1, n2, m, normMulti(multi), distCode(dist1), distCode(dist2), minLen, maxLen, seed)
	g.MarkBipartite(n1)
	return g, nil
}

// |RandomLengths|는 그래프 |g|의 모든 호에 새 무작위 길이를 매긴다.
//
//line gbrand.w:444
//line gbrand.w:445
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

//line gbrand.w:469
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

//line gbrand.w:458
	g.MakeCompoundID("random_lengths(", g, fmt.Sprintf(",%d,%d,%d,%s,%d)",
		boolInt(directed), minLen, maxLen, distCode(dist), seed))

//line gbrand.w:490
	randLen := func() int64 {
		if minLen == maxLen {
			return minLen
		}
		return minLen + rng.Unif(maxLen-minLen+1)
	}
	for u := range g.AllVertices() {
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

//line gbrand.w:461
	return nil
}
