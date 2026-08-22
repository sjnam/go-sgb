//line gbwords.w:147
package gbwords

import (
	"fmt"
	"math"
	"path/filepath"

	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/gbsort"
)

type (
	Graph  = gbgraph.Graph
	Vertex = gbgraph.Vertex

//line gbwords.w:163
)

//line gbwords.w:123
const (
	weightBias = 1 << 30 // 정렬 키는 가중치에 $2^{30}$을 더한 값
	hashPrime  = 6997    // 낱말 총수보다 조금 큰 소수
)

var maxC = [7]int64{15194, 3560, 4467, 460, 6976, 756, 362} // 최대 빈도수 $C_j$

var defaultWtVector = []int64{100, 10, 4, 2, 2, 1, 1, 1, 1} // |wtVector == nil|일 때

//line gbwords.w:419
type wordHash [5][]*Vertex

//line gbwords.w:251
func iabs(x int64) int64 {
	if x >= 0 {
		return x
	}
	return -x
}

//line gbwords.w:290
func readWords(f *gbio.File, wtVector []int64, wtThreshold int64) (
	stack *gbsort.Node[string], nn int64, err error,
) {
	for {
		var word [5]byte
		for j := range word {
			word[j] = f.Char()
		}
		var wt int64

//line gbwords.w:322
		switch f.Char() {
		case '*':
			wt = wtVector[0] // `흔함'
		case '+':
			wt = wtVector[1] // `고급'
		case ' ', '\n':
			wt = 0 // `드묾'
		default:
			return nil, 0, gbgraph.SyntaxError // 알 수 없는 종류
		}
		for j := 0; ; j++ {
			if j == 7 {
				return nil, 0, gbgraph.SyntaxError + 1 // 빈도수가 너무 많다
			}
			c := f.Number(10)
			if c > maxC[j] {
				return nil, 0, gbgraph.SyntaxError + 2 // 빈도수가 너무 크다
			}
			wt += c * wtVector[2+j]
			if f.Char() != ',' {
				break
			}
		}

//line gbwords.w:300
		if wt >= wtThreshold { // 자격을 갖췄다
			stack = &gbsort.Node[string]{Key: wt + weightBias, Data: string(word[:]), Link: stack}
			nn++
		}
		f.NextLine()
		if f.EOF() {
			break
		}
	}
	return stack, nn, nil
}

//line gbwords.w:429
func rawHash(q string) int64 {
	var h int64
	for i := 0; i < 5; i++ {
		h = (h << 5) + int64(q[i])
	}
	return h
}

func blanked(rh int64, q string, k int) int64 {
	return rh - (int64(q[k]) << ((4 - k) * 5))
}

func down(idx int) int {
	if idx == 0 {
		return hashPrime - 1
	}
	return idx - 1
}

//line gbwords.w:453
func matchExcept(q, r string, k int) bool {
	for i := 0; i < 5; i++ {
		if i != k && q[i] != r[i] {
			return false
		}
	}
	return true
}

//line gbwords.w:468
func makeWordHash() wordHash {
	var ht wordHash
	for i := range ht {
		ht[i] = make([]*Vertex, hashPrime)
	}
	return ht
}

func (ht wordHash) insert(v *Vertex, near func(k int, r *Vertex)) {
	q := v.Name
	rh := rawHash(q)
	for k := 0; k < 5; k++ {
		idx := int(blanked(rh, q, k) % hashPrime)
		for ht[k][idx] != nil {
			if near != nil {
				if r := ht[k][idx]; matchExcept(q, r.Name, k) {
					near(k, r)
				}
			}
			idx = down(idx)
		}
		ht[k][idx] = v
	}
}

//line gbwords.w:168
func Words(n int64, wtVector []int64, wtThreshold, seed int64, dir string) (*Graph, error) {
	rng := gbflip.New(seed)
	usedDefault := wtVector == nil

//line gbwords.w:192
	if wtVector == nil {
		wtVector = defaultWtVector
	} else {

//line gbwords.w:208
		if len(wtVector) < 9 {
			padded := make([]int64, 9)
			copy(padded, wtVector)
			wtVector = padded
		}

//line gbwords.w:196

//line gbwords.w:220
		flacc := math.Abs(float64(wtVector[0]))
		if b := math.Abs(float64(wtVector[1])); flacc < b {
			flacc = b // 이제 |flacc|는 $\max(\vert a\vert,\vert b\vert)$
		}
		for j := 0; j < 7; j++ {
			flacc += float64(maxC[j]) * math.Abs(float64(wtVector[2+j]))
		}
		if flacc >= float64(0x60000000) { // 이 상수는 $6\times2^{28}=2^{30}+2^{29}$ 이다
			return nil, gbgraph.VeryBadSpecs // 무게 벡터가 한참 벗어났다
		}

//line gbwords.w:197

//line gbwords.w:236
		acc := iabs(wtVector[0])
		if b := iabs(wtVector[1]); acc < b {
			acc = b // 이제 |acc|는 $\max(\vert a\vert,\vert b\vert)$
		}
		for j := 0; j < 7; j++ {
			acc += maxC[j] * iabs(wtVector[2+j])
		}
		if acc >= 0x40000000 {
			return nil, gbgraph.BadSpecs // 무게 벡터가 조금 크다
		}

//line gbwords.w:198
	}

//line gbwords.w:172

//line gbwords.w:269
	f, err := gbio.Open(filepath.Join(dir, "words.dat"))
	if err != nil {
		return nil, gbgraph.EarlyDataFault
	}
	stack, nn, err := readWords(f, wtVector, wtThreshold)
	if cerr := f.Close(); err == nil && cerr != nil {
		err = gbgraph.LateDataFault
	}
	if err != nil {
		return nil, err
	}

//line gbwords.w:173

//line gbwords.w:355
	sorted := gbsort.LinkSort(stack, rng)

//line gbwords.w:378
	if n == 0 || nn < n {
		n = nn
	}
	g := gbgraph.NewGraph(n)
	if usedDefault {
		g.ID = fmt.Sprintf("words(%d,0,%d,%d)", n, wtThreshold, seed)
	} else {
		g.ID = fmt.Sprintf("words(%d,{%d,%d,%d,%d,%d,%d,%d,%d,%d},%d,%d)",
			n, wtVector[0], wtVector[1], wtVector[2], wtVector[3], wtVector[4],
			wtVector[5], wtVector[6], wtVector[7], wtVector[8], wtThreshold, seed)
	}
	g.UtilTypes = "IZZZZZIZZZZZZZ"

//line gbwords.w:357
	ht := makeWordHash()
	var added int64
Outer:
	for j := 127; j >= 0; j-- {
		for p := sorted[j]; p != nil; p = p.Link {

//line gbwords.w:403
			v := &g.Vertices[added]
			v.Name = p.Data
			v.U.I = p.Key - weightBias
			ht.insert(v, func(k int, r *Vertex) {
				g.NewEdge(v, r, 1)
				v.Arcs.A.I = int64(k)
				v.Arcs.Partner.A.I = int64(k)
			})

//line gbwords.w:363
			added++
			if added == n {
				break Outer
			}
		}
	}

//line gbwords.w:174
	return g, nil
}

//line gbwords.w:506
func FindWord(g *Graph, q string, f func(*Vertex)) *Vertex {
	if len(q) != 5 {
		return nil
	}
	ht := makeWordHash()
	for v := range g.AllVertices() {
		ht.insert(v, nil)
	}

//line gbwords.w:523
	rh := rawHash(q)
	for idx := int(blanked(rh, q, 0) % hashPrime); ht[0][idx] != nil; idx = down(idx) {
		if r := ht[0][idx]; q[0] == r.Name[0] && matchExcept(q, r.Name, 0) {
			return r
		}
	}

//line gbwords.w:515

//line gbwords.w:534
	if f != nil {
		for k := 0; k < 5; k++ {
			for idx := int(blanked(rh, q, k) % hashPrime); ht[k][idx] != nil; idx = down(idx) {
				if r := ht[k][idx]; matchExcept(q, r.Name, k) {
					f(r)
				}
			}
		}
	}

//line gbwords.w:516
	return nil
}
