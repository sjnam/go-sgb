//line gbbasic.w:29
package gbbasic

import (
	"fmt"
	"strconv"
	"strings"
	"unsafe"

	"github.com/sjnam/go-sgb/gbgraph"
)

type (
	Graph  = gbgraph.Graph
	Vertex = gbgraph.Vertex

//line gbbasic.w:43
)

//line gbbasic.w:60
const (
	maxD    = 91         // 차원 수의 상한
	bufSize = 4096       // 이름 버퍼의 크기
	maxNNN  = 1000000000 // 정점 수의 상한($10^9$)
)

//line gbbasic.w:1085
const shortImap = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
	"abcdefghijklmnopqrstuvwxyz" +
	"_^~&@,;.:?!%#$+-*/|<=>()[]{}`'"

//line gbbasic.w:2588
const indGraph = 1000000000 // 유도 부호가 10억 이상이면 |subst|를 본다

//line gbbasic.w:80
type builder struct {
	g   *Graph          // 짓고 있는 그래프
	nn  [maxD + 2]int64 // 각 좌표의 크기
	wr  [maxD + 2]int64 // 이 좌표가 둘러 감기는가?
	del [maxD + 2]int64 // 현재 이동의 변위
	sig [maxD + 2]int64 // 변위 제곱의 부분합
	xx  [maxD + 2]int64 // 좌표값(이동 전)
	yy  [maxD + 2]int64 // 좌표값(이동 후)
}

//line gbbasic.w:94
func dotJoin(vals []int64, sep byte) string {
	var sb strings.Builder
	for i, x := range vals {
		if i > 0 {
			sb.WriteByte(sep)
		}
		sb.WriteString(strconv.FormatInt(x, 10))
	}
	return sb.String()
}

//line gbbasic.w:289
func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

//line gbbasic.w:1750
func ptrGeq(a, b *Vertex) bool {
	return uintptr(unsafe.Pointer(a)) >= uintptr(unsafe.Pointer(b))
}

// |newLikeG|는 |g|와 같은 정점(이름만 베낀)을 가진 빈 그래프를 만든다.
// |Complement|, |Gunion|, |Intersection|이 함께 쓴다.
//
//line gbbasic.w:1754
//line gbbasic.w:1755
//line gbbasic.w:1756
func newLikeG(g *Graph) *Graph {
	ng := gbgraph.NewGraph(g.N)
	for i := int64(0); i < g.N; i++ {
		ng.Vertices[i].Name = g.Vertices[i].Name
	}
	return ng
}

func ptrLess(a, b *Vertex) bool {
	return uintptr(unsafe.Pointer(a)) < uintptr(unsafe.Pointer(b))
}

// |inArray|는 |v|가 |verts|가 뒷받침하는 배열 안의 정점인지 말한다.
//
//line gbbasic.w:1768
//line gbbasic.w:1769
func inArray(v *Vertex, verts []Vertex) bool {
	if len(verts) == 0 {
		return false
	}
	p := uintptr(unsafe.Pointer(v))
	lo := uintptr(unsafe.Pointer(&verts[0]))
	hi := lo + uintptr(len(verts))*unsafe.Sizeof(Vertex{})
	return p >= lo && p < hi
}

//line gbbasic.w:2010
func lineName(a, b string, directed bool) string {
	if int64(len(a)) > (bufSize-3)/2 {
		a = a[:(bufSize-3)/2]
	}
	if int64(len(b)) > bufSize/2-1 {
		b = b[:bufSize/2-1]
	}
	sep := "-"
	if directed {
		sep = ">"
	}
	return a + "-" + sep + b
}

//line gbbasic.w:2142
func pairName(a, b string) string {
	if int64(len(a)) > bufSize/2-1 {
		a = a[:bufSize/2-1]
	}
	if int64(len(b)) > (bufSize-1)/2 {
		b = b[:(bufSize-1)/2]
	}
	return a + "," + b
}

//line gbbasic.w:608
func (b *builder) normalizeSimplex(n, n0, n1, n2, n3, n4 int64) (int64, [5]int64, error) {
	if n0 == 0 {
		n0 = -2
	}
	np := [5]int64{n0, n1, n2, n3, n4} // 표식에 쓸 정규화된 매개변수
	var k, d int64
	periodic := true
	if n0 < 0 {
		k, d = 2, -n0
		b.nn[0] = n
		np[1], np[2], np[3], np[4] = 0, 0, 0, 0
	} else {
		clamp := func(x int64) int64 {
			if x > n {
				return n
			}
			return x
		}
		np[0] = clamp(n0)
		b.nn[0] = np[0]

//line gbbasic.w:637
		done := false
		for i := 0; i < 4; i++ {
			if np[i+1] <= 0 {
				k, d = int64(i)+2, -np[i+1]
				for j := i + 2; j <= 4; j++ {
					np[j] = 0
				}
				done = true
				break
			}
			np[i+1] = clamp(np[i+1])
			b.nn[i+1] = np[i+1]
		}
		if !done {
			d, periodic = 4, false
		}

//line gbbasic.w:629
	}
	if periodic {

//line gbbasic.w:658
		if d == 0 {
			d = k - 2
		} else {
			if d > maxD {
				return 0, np, gbgraph.BadSpecs // 차원이 너무 많다
			}
			b.nn[k-1] = b.nn[0]
			for j := int64(1); k <= d; j, k = j+1, k+1 {
				b.nn[k] = b.nn[j]
			}
		}

//line gbbasic.w:632
	}
	return d, np, nil
}

//line gbbasic.w:677
func (b *builder) countSimplex(n, d int64) (int64, error) {
	coef := make([]int64, n+1)
	for k := int64(0); k <= b.nn[0]; k++ {
		coef[k] = 1
	}
	for j := int64(1); j <= d; j++ {
		for k, i := n, n-b.nn[j]-1; i >= 0; k, i = k-1, i-1 {
			coef[k] -= coef[i]
		}
		s := int64(1)
		for k := int64(1); k <= n; k++ {
			s += coef[k]
			if s > maxNNN {
				return 0, gbgraph.VeryBadSpecs // 너무 크다
			}
			coef[k] = s
		}
	}
	return coef[n], nil
}

//line gbbasic.w:703
func (b *builder) completePartial(k, d int64) error {
	s := b.sig[k] - b.xx[k]
	for k++; k <= d; k++ {
		b.sig[k] = s
		if s <= b.yy[k+1] {
			b.xx[k] = 0
		} else {
			b.xx[k] = s - b.yy[k+1]
		}
		s -= b.xx[k]
	}
	if s != 0 {
		return gbgraph.Impossible + 1 // 있을 수 없는 일
	}
	return nil
}

//line gbbasic.w:724
func (b *builder) advancePartial(d int64) (int64, bool) {
	for k := d - 1; ; k-- {
		if b.xx[k] < b.sig[k] && b.xx[k] < b.nn[k] {
			b.xx[k]++
			return k, true
		}
		if k == 0 {
			return 0, false
		}
	}
}

//line gbbasic.w:740
func (b *builder) assignSimplexName(v *Vertex, d int64) {
	v.Name = dotJoin(b.xx[0:d+1], '.')
	v.X.I, v.Y.I, v.Z.I = b.xx[0], b.xx[1], b.xx[2]
}

//line gbbasic.w:187
func Board(n1, n2, n3, n4, piece, wrap int64, directed bool) (*Graph, error) {
	b := &builder{}
	var d, n, k int64

//line gbbasic.w:200
	if piece == 0 {
		piece = 1
	}
	if n1 <= 0 {
		n1, n2, n3 = 8, 8, 0
	}
	b.nn[1] = n1
	periodic := true
	switch {
	case n2 <= 0:
		k, d, n3, n4 = 2, -n2, 0, 0
	case n3 <= 0:
		b.nn[2] = n2
		k, d, n4 = 3, -n3, 0
	case n4 <= 0:
		b.nn[2], b.nn[3] = n2, n3
		k, d = 4, -n4
	default:
		b.nn[2], b.nn[3], b.nn[4] = n2, n3, n4
		d, periodic = 4, false
	}

//line gbbasic.w:226
	if periodic {
		if d == 0 {
			d = k - 1
		} else {
			if d > maxD {
				return nil, gbgraph.BadSpecs // 차원이 너무 많다
			}
			for j := int64(1); k <= d; j, k = j+1, k+1 {
				b.nn[k] = b.nn[j]
			}
		}
	}

//line gbbasic.w:191

//line gbbasic.w:244
	nnn := 1.0
	n = 1
	for j := int64(1); j <= d; j++ {
		nnn *= float64(b.nn[j])
		if nnn > maxNNN {
			return nil, gbgraph.VeryBadSpecs // 너무 크다
		}
		n *= b.nn[j] // 이 곱셈은 정수 넘침을 일으킬 수 없다
	}
	b.g = gbgraph.NewGraph(n)
	b.g.ID = fmt.Sprintf("board(%d,%d,%d,%d,%d,%d,%d)",
		n1, n2, n3, n4, piece, wrap, boolInt(directed))
	b.g.UtilTypes = "ZZZIIIZZZZZZZZ"

//line gbbasic.w:268
	for j := int64(1); j <= d; j++ {
		b.xx[j] = 0
	}
	for vi := int64(0); ; vi++ {
		v := &b.g.Vertices[vi]
		v.Name = dotJoin(b.xx[1:d+1], '.')
		v.X.I, v.Y.I, v.Z.I = b.xx[1], b.xx[2], b.xx[3]
		kk := d
		for kk > 0 && b.xx[kk]+1 == b.nn[kk] {
			b.xx[kk] = 0
			kk--
		}
		if kk == 0 {
			break // 자리올림이 맨 왼쪽까지 갔다
		}
		b.xx[kk]++
	}

//line gbbasic.w:192

//line gbbasic.w:309
	w := wrap
	for k := int64(1); k <= d; k, w = k+1, w>>1 {
		b.wr[k] = w & 1
		b.del[k], b.sig[k] = 0, 0
	}
	b.sig[0], b.del[0], b.sig[d+1] = 0, 0, 0
	p := piece
	if p < 0 {
		p = -p
	}
Outer:
	for {

//line gbbasic.w:332
		kk := d
		for b.sig[kk]+(b.del[kk]+1)*(b.del[kk]+1) > p {
			b.del[kk] = 0
			kk--
		}
		if kk == 0 {
			break Outer
		}
		b.del[kk]++
		b.sig[kk+1] = b.sig[kk] + b.del[kk]*b.del[kk]
		for kk++; kk <= d; kk++ {
			b.sig[kk+1] = b.sig[kk]
		}
		if b.sig[d+1] < p {
			continue Outer
		}

//line gbbasic.w:322
		for {

//line gbbasic.w:363
			for k := int64(1); k <= d; k++ {
				b.xx[k] = 0
			}
			for vi := int64(0); ; vi++ {

//line gbbasic.w:390
				for k := int64(1); k <= d; k++ {
					b.yy[k] = b.xx[k] + b.del[k]
				}
				for l := int64(1); ; l++ {

//line gbbasic.w:408
					offBoard := false
					for k := int64(1); k <= d; k++ {
						if b.yy[k] < 0 {
							if b.wr[k] == 0 {
								offBoard = true
								break
							}
							for b.yy[k] < 0 {
								b.yy[k] += b.nn[k]
							}
						} else if b.yy[k] >= b.nn[k] {
							if b.wr[k] == 0 {
								offBoard = true
								break
							}
							for b.yy[k] >= b.nn[k] {
								b.yy[k] -= b.nn[k]
							}
						}
					}
					if offBoard {
						break
					}

//line gbbasic.w:395
					if piece < 0 {

//line gbbasic.w:433
						equal := true
						for k := int64(1); k <= d; k++ {
							if b.yy[k] != b.xx[k] {
								equal = false
								break
							}
						}
						if equal {
							break
						}

//line gbbasic.w:397
					}

//line gbbasic.w:445
					j := b.yy[1]
					for k := int64(2); k <= d; k++ {
						j = b.nn[k]*j + b.yy[k]
					}
					if directed {
						b.g.NewArc(&b.g.Vertices[vi], &b.g.Vertices[j], l)
					} else {
						b.g.NewEdge(&b.g.Vertices[vi], &b.g.Vertices[j], l)
					}

//line gbbasic.w:399
					if piece > 0 {
						break
					}
					for k := int64(1); k <= d; k++ {
						b.yy[k] += b.del[k]
					}
				}

//line gbbasic.w:368
				kk := d
				for kk > 0 && b.xx[kk]+1 == b.nn[kk] {
					b.xx[kk] = 0
					kk--
				}
				if kk == 0 {
					break
				}
				b.xx[kk]++
			}

//line gbbasic.w:324

//line gbbasic.w:350
			kk := d
			for b.del[kk] <= 0 {
				b.del[kk] = -b.del[kk]
				kk--
			}
			if b.sig[kk] == 0 {
				break // |del[kk]| 말고는 다 음수거나 0이었다
			}
			b.del[kk] = -b.del[kk] // |del[kk]| 앞의 어떤 성분이 양수다

//line gbbasic.w:325
		}
	}

//line gbbasic.w:193
	return b.g, nil
}

// |Complete|는 |n|개 정점의 완전 그래프다.
//
//line gbbasic.w:459
//line gbbasic.w:460
func Complete(n int64) (*Graph, error) { return Board(n, 0, 0, 0, -1, 0, false) }

// |Transitive|는 |n|개 정점의 추이 토너먼트다.
//
//line gbbasic.w:462
//line gbbasic.w:463
func Transitive(n int64) (*Graph, error) { return Board(n, 0, 0, 0, -1, 0, true) }

// |Empty|는 |n|개 정점에 간선이 없는 그래프다.
//
//line gbbasic.w:465
//line gbbasic.w:466
func Empty(n int64) (*Graph, error) { return Board(n, 0, 0, 0, 2, 0, false) }

// |Circuit|은 길이 |n|의 무향 회로다.
//
//line gbbasic.w:468
//line gbbasic.w:469
func Circuit(n int64) (*Graph, error) { return Board(n, 0, 0, 0, 1, 1, false) }

// |Cycle|은 길이 |n|의 유향 순환이다.
//
//line gbbasic.w:471
//line gbbasic.w:472
func Cycle(n int64) (*Graph, error) { return Board(n, 0, 0, 0, 1, 1, true) }

//line gbbasic.w:530
func Simplex(n, n0, n1, n2, n3, n4 int64, directed bool) (*Graph, error) {
	b := &builder{}

//line gbbasic.w:541
	d, np, err := b.normalizeSimplex(n, n0, n1, n2, n3, n4)
	if err != nil {
		return nil, err
	}
	nverts, err := b.countSimplex(n, d)
	if err != nil {
		return nil, err
	}
	b.g = gbgraph.NewGraph(nverts)
	b.g.ID = fmt.Sprintf("simplex(%d,%d,%d,%d,%d,%d,%d)",
		n, np[0], np[1], np[2], np[3], np[4], boolInt(directed))
	b.g.UtilTypes = "VVZIIIZZZZZZZZ" // 해시표를 쓴다

//line gbbasic.w:533

//line gbbasic.w:559
	b.yy[d+1] = 0
	b.sig[0] = n
	for k := d; k >= 0; k-- {
		b.yy[k] = b.yy[k+1] + b.nn[k]
	}
	vi := int64(0)

//line gbbasic.w:570
	if b.yy[0] >= n {
		k := int64(0)
		if b.yy[1] >= n {
			b.xx[0] = 0
		} else {
			b.xx[0] = n - b.yy[1]
		}
		for {

//line gbbasic.w:594
			if err := b.completePartial(k, d); err != nil {
				return nil, err
			}
			v := &b.g.Vertices[vi]
			b.assignSimplexName(v, d)
			b.g.HashIn(v)

//line gbbasic.w:749
			for j := int64(0); j < d; j++ {
				if b.xx[j] != 0 {
					b.xx[j]--
					for k := j + 1; k <= d; k++ {
						if b.xx[k] < b.nn[k] {
							b.xx[k]++
							u := b.g.HashLookup(dotJoin(b.xx[0:d+1], '.'))
							if u == nil {
								return nil, gbgraph.Impossible + 2
							}
							if directed {
								b.g.NewArc(u, v, 1)
							} else {
								b.g.NewEdge(u, v, 1)
							}
							b.xx[k]--
						}
					}
					b.xx[j]++
				}
			}

//line gbbasic.w:601
			vi++

//line gbbasic.w:579
			nk, ok := b.advancePartial(d)
			if !ok {
				break
			}
			k = nk
		}
	}
	if vi != b.g.N {
		return nil, gbgraph.Impossible // 있을 수 없는 일
	}

//line gbbasic.w:534
	return b.g, nil
}

//line gbbasic.w:810
func Subsets(n, n0, n1, n2, n3, n4 int64, sizeBits uint64, directed bool) (*Graph, error) {
	b := &builder{}
	d, np, err := b.normalizeSimplex(n, n0, n1, n2, n3, n4)
	if err != nil {
		return nil, err
	}
	nverts, err := b.countSimplex(n, d)
	if err != nil {
		return nil, err
	}
	b.g = gbgraph.NewGraph(nverts)
	b.g.ID = fmt.Sprintf("subsets(%d,%d,%d,%d,%d,%d,0x%x,%d)",
		n, np[0], np[1], np[2], np[3], np[4], sizeBits, boolInt(directed))
	b.g.UtilTypes = "ZZZIIIZZZZZZZZ" // 해시표를 쓰지 않는다

//line gbbasic.w:831
	b.yy[d+1] = 0
	b.sig[0] = n
	for k := d; k >= 0; k-- {
		b.yy[k] = b.yy[k+1] + b.nn[k]
	}
	vi := int64(0)

//line gbbasic.w:841
	if b.yy[0] >= n {
		k := int64(0)
		if b.yy[1] >= n {
			b.xx[0] = 0
		} else {
			b.xx[0] = n - b.yy[1]
		}
		for {
			if err := b.completePartial(k, d); err != nil {
				return nil, err
			}
			v := &b.g.Vertices[vi]
			b.assignSimplexName(v, d)

//line gbbasic.w:871
			for ui := int64(0); ui <= vi; ui++ {
				u := &b.g.Vertices[ui]
				parts := strings.Split(u.Name, ".")
				ss := int64(0)
				for j := int64(0); j <= d; j++ {
					s, _ := strconv.ParseInt(parts[j], 10, 64)
					if b.xx[j] < s {
						ss += b.xx[j]
					} else {
						ss += s
					}
				}
				if ss < 64 && sizeBits&(uint64(1)<<uint(ss)) != 0 {
					if directed {
						b.g.NewArc(u, v, 1)
					} else {
						b.g.NewEdge(u, v, 1)
					}
				}
			}

//line gbbasic.w:855
			vi++
			nk, ok := b.advancePartial(d)
			if !ok {
				break
			}
			k = nk
		}
	}
	if vi != b.g.N {
		return nil, gbgraph.Impossible
	}

//line gbbasic.w:825
	return b.g, nil
}

// |DisjointSubsets|는 $n$원소 집합의 서로소인 $k$-부분집합들을 잇는다.
//
//line gbbasic.w:895
//line gbbasic.w:896
func DisjointSubsets(n, k int64) (*Graph, error) {
	return Subsets(k, 1, 1-n, 0, 0, 0, 1, false)
}

// |Petersen|은 페테르센 그래프다.
//
//line gbbasic.w:900
//line gbbasic.w:901
func Petersen() (*Graph, error) { return DisjointSubsets(5, 2) }

//line gbbasic.w:968
func Perms(n0, n1, n2, n3, n4, maxInv int64, directed bool) (*Graph, error) {
	b := &builder{}
	if n0 == 0 {
		n0, n1 = 1, 0 // 빈 집합을 $\{0\}$으로
	} else if n0 < 0 {
		n1, n0 = n0, 1
	}
	d, np, err := b.normalizeSimplex(bufSize, n0, n1, n2, n3, n4)
	if err != nil {
		return nil, err
	}

//line gbbasic.w:990
	var n, ss, s int64
	for k := int64(0); k <= d; k++ {
		if b.nn[k] >= bufSize {
			return nil, gbgraph.BadSpecs // 다중집합에 원소가 너무 많다
		}
		ss += s * b.nn[k]
		s += b.nn[k]
	}
	if s >= bufSize {
		return nil, gbgraph.BadSpecs + 1
	}
	n = s
	if maxInv == 0 || maxInv > ss {
		maxInv = ss
	}

//line gbbasic.w:980

//line gbbasic.w:1011
	coef := make([]int64, maxInv+1)
	coef[0] = 1
	s = b.nn[0]
	for j := int64(1); j <= d; j++ {
		for k := int64(1); k <= b.nn[j]; k++ {
			for i, ii := maxInv, maxInv-k-s; ii >= 0; i, ii = i-1, ii-1 {
				coef[i] -= coef[ii]
			}
			for i, ii := k, int64(0); i <= maxInv; i, ii = i+1, ii+1 {
				coef[i] += coef[ii]
				if coef[i] > maxNNN {
					return nil, gbgraph.VeryBadSpecs + 1 // 너무 크다
				}
			}
		}
		s += b.nn[j]
	}
	nverts := int64(1)
	for k := int64(1); k <= maxInv; k++ {
		nverts += coef[k]
		if nverts > maxNNN {
			return nil, gbgraph.VeryBadSpecs
		}
	}
	b.g = gbgraph.NewGraph(nverts)
	b.g.ID = fmt.Sprintf("perms(%d,%d,%d,%d,%d,%d,%d)",
		np[0], np[1], np[2], np[3], np[4], maxInv, boolInt(directed))
	b.g.UtilTypes = "VVZZZZZZZZZZZZ" // 해시표를 쓴다

//line gbbasic.w:981

//line gbbasic.w:1044
	xtab := make([]int64, n+1)
	ytab := make([]int64, n+1)
	ztab := make([]int64, n+1)

//line gbbasic.w:1062
	j := int64(0)
	s = b.nn[0]
	for k := int64(1); ; k++ {
		xtab[k], ztab[k] = j, j
		if k == s {
			j++
			if j > d {
				break
			}
			s += b.nn[j]
		}
	}

//line gbbasic.w:1048
	buf := make([]byte, n)
	m := int64(0) // 현재 뒤바뀜 수
	vi := int64(0)
	for {

//line gbbasic.w:1090
		for i := int64(0); i < n; i++ {
			buf[i] = shortImap[xtab[i+1]]
		}
		v := &b.g.Vertices[vi]
		v.Name = string(buf)
		b.g.HashIn(v)

//line gbbasic.w:1053

//line gbbasic.w:1101
		for j := int64(1); j < n; j++ {
			if xtab[j] > xtab[j+1] {
				buf[j-1] = shortImap[xtab[j+1]]
				buf[j] = shortImap[xtab[j]]
				u := b.g.HashLookup(string(buf))
				if u == nil {
					return nil, gbgraph.Impossible + 2
				}
				if directed {
					b.g.NewArc(u, v, 1)
				} else {
					b.g.NewEdge(u, v, 1)
				}
				buf[j-1] = shortImap[xtab[j]]
				buf[j] = shortImap[xtab[j+1]]
			}
		}

//line gbbasic.w:1054
		vi++

//line gbbasic.w:1124
		moved := false
		var mk int64
		for k := n; k > 0; k-- {
			if m < maxInv && ytab[k] < k-1 {
				if ytab[k] < ytab[k-1] || ztab[k] > ztab[k-1] {
					mk, moved = k, true
					break
				}
			}
			if ytab[k] != 0 {
				for j := k - ytab[k]; j < k; j++ {
					xtab[j] = xtab[j+1]
				}
				m -= ytab[k]
				ytab[k] = 0
				xtab[k] = ztab[k]
			}
		}
		if !moved {
			break
		}
		j := mk - ytab[mk] // $k$번째 원소 $z_k$의 현재 위치
		xtab[j] = xtab[j-1]
		xtab[j-1] = ztab[mk]
		ytab[mk]++
		m++

//line gbbasic.w:1056
	}
	if vi != b.g.N {
		return nil, gbgraph.Impossible
	}

//line gbbasic.w:982
	return b.g, nil
}

// |AllPerms|는 $n$원소 집합의 $n!$개 순열을 다 낳는다.
//
//line gbbasic.w:1152
//line gbbasic.w:1153
func AllPerms(n int64, directed bool) (*Graph, error) {
	return Perms(1-n, 0, 0, 0, 0, 0, directed)
}

//line gbbasic.w:1168
func Parts(n, maxParts, maxSize int64, directed bool) (*Graph, error) {
	b := &builder{}
	if maxParts == 0 || maxParts > n {
		maxParts = n
	}
	if maxSize == 0 || maxSize > n {
		maxSize = n
	}
	if maxParts > maxD {
		return nil, gbgraph.BadSpecs // 부분이 너무 많다
	}

//line gbbasic.w:1185
	coef := make([]int64, n+1)
	coef[0] = 1
	for k := int64(1); k <= maxParts; k++ {
		for j, i := n, n-k-maxSize; i >= 0; i, j = i-1, j-1 {
			coef[j] -= coef[i]
		}
		for j, i := k, int64(0); j <= n; i, j = i+1, j+1 {
			coef[j] += coef[i]
			if coef[j] > maxNNN {
				return nil, gbgraph.VeryBadSpecs // 너무 크다
			}
		}
	}
	b.g = gbgraph.NewGraph(coef[n])
	b.g.ID = fmt.Sprintf("parts(%d,%d,%d,%d)", n, maxParts, maxSize, boolInt(directed))
	b.g.UtilTypes = "VVZZZZZZZZZZZZ" // 해시표를 쓴다

//line gbbasic.w:1180

//line gbbasic.w:1207
	b.xx[0] = maxSize
	b.sig[1] = n
	for k, s := maxParts, int64(1); k > 0; k, s = k-1, s+1 {
		b.yy[k] = s
	}
	var d int64
	vi := int64(0)
	if maxSize*maxParts >= n {
		k := int64(1)
		b.xx[1] = (n-1)/maxParts + 1 // $\lceil n/|maxParts|\rceil$
		for {

//line gbbasic.w:1230
			s := b.sig[k] - b.xx[k]
			k++
			for s != 0 {
				b.sig[k] = s
				b.xx[k] = (s-1)/b.yy[k] + 1
				s -= b.xx[k]
				k++
			}
			d = k - 1 // 가장 작은 부분이 $x_d$

//line gbbasic.w:1219

//line gbbasic.w:1241
			v := &b.g.Vertices[vi]
			v.Name = dotJoin(b.xx[1:d+1], '+')
			b.g.HashIn(v)

//line gbbasic.w:1220

//line gbbasic.w:1272
			if d < maxParts {
				b.xx[d+1] = 0
				for j := int64(1); j <= d; j++ {
					if b.xx[j] != b.xx[j+1] {
						for lo, hi := b.xx[j]/2, b.xx[j]-b.xx[j]/2; lo > 0; lo, hi = lo-1, hi+1 {

//line gbbasic.w:1285
							k := j + 1
							for b.xx[k] > hi {
								b.nn[k-1] = b.xx[k]
								k++
							}
							b.nn[k-1] = hi
							for b.xx[k] > lo {
								b.nn[k] = b.xx[k]
								k++
							}
							b.nn[k] = lo
							for ; k <= d; k++ {
								b.nn[k+1] = b.xx[k]
							}
							u := b.g.HashLookup(dotJoin(b.nn[1:d+2], '+'))
							if u == nil {
								return nil, gbgraph.Impossible + 2
							}
							if directed {
								b.g.NewArc(v, u, 1)
							} else {
								b.g.NewEdge(v, u, 1)
							}

//line gbbasic.w:1278
						}
					}
					b.nn[j] = b.xx[j]
				}
			}

//line gbbasic.w:1221
			vi++

//line gbbasic.w:1248
			if d == 1 {
				break
			}
			found := false
			for k = d - 1; ; k-- {
				if b.xx[k] < b.sig[k] && b.xx[k] < b.xx[k-1] {
					found = true
					break
				}
				if k == 1 {
					break
				}
			}
			if !found {
				break
			}
			b.xx[k]++

//line gbbasic.w:1223
		}
	}
	if vi != b.g.N {
		return nil, gbgraph.Impossible
	}

//line gbbasic.w:1181
	return b.g, nil
}

// |AllParts|는 |n|의 분할 $p(n)$개를 다 낳는다.
//
//line gbbasic.w:1310
//line gbbasic.w:1311
func AllParts(n int64, directed bool) (*Graph, error) {
	return Parts(n, 0, 0, directed)
}

//line gbbasic.w:1353
func Binary(n, maxHeight int64, directed bool) (*Graph, error) {
	if 2*n+2 > bufSize {
		return nil, gbgraph.BadSpecs // |n|이 우리에겐 너무 크다
	}
	if maxHeight == 0 || maxHeight > n {
		maxHeight = n
	}
	if maxHeight > 30 {
		return nil, gbgraph.VeryBadSpecs // 10억 정점이 넘는다
	}
	var g *Graph

//line gbbasic.w:1383
	cnt := make([]int64, n+2)
	var nverts int64
	if n >= 20 && maxHeight >= 6 {

//line gbbasic.w:1408
		dd := (int64(1) << maxHeight) - 1 - n
		if dd > 8 {
			return nil, gbgraph.BadSpecs + 1 // 정점이 너무 많다
		}
		if dd < 0 {
			nverts = 0
		} else {
			cnt[0], cnt[1] = 1, 1
			for j := int64(2); j <= maxHeight; j++ {
				for k := dd; k > 0; k-- {
					var ss float64
					for i := k; i >= 0; i-- {
						ss += float64(cnt[i]) * float64(cnt[k-i])
					}
					if ss > maxNNN {
						return nil, gbgraph.VeryBadSpecs + 1 // 너무 크다
					}
					var s int64
					for i := k; i >= 0; i-- {
						s += cnt[i] * cnt[k-i]
					}
					cnt[k] = s
				}
				if i := (int64(1) << j) - 1; i <= dd {
					cnt[i]++ // $z^{1-2^j}$을 더한다
				}
			}
			nverts = cnt[dd]
		}

//line gbbasic.w:1387
	} else {
		cnt[0], cnt[1] = 1, 1
		for j := int64(2); j <= maxHeight; j++ {
			for k := n - 1; k > 0; k-- {
				var s int64
				for i := k; i >= 0; i-- {
					s += cnt[i] * cnt[k-i]
				}
				cnt[k+1] = s
			}
		}
		nverts = cnt[n]
	}
	g = gbgraph.NewGraph(nverts)
	g.ID = fmt.Sprintf("binary(%d,%d,%d)", n, maxHeight, boolInt(directed))
	g.UtilTypes = "VVZZZZZZZZZZZZ" // 해시표를 쓴다

//line gbbasic.w:1365

//line gbbasic.w:1444
	d := n + n
	xtab := make([]int64, d+1)
	ytab := make([]int64, d+1)
	ltab := make([]int64, d+1)
	stab := make([]int64, d+1)
	ltab[0] = int64(1) << maxHeight
	stab[0] = n
	buf := make([]byte, d+1)
	vi := int64(0)
	if ltab[0] > n {
		k := int64(0)
		if n != 0 {
			xtab[0] = 1
		}
		for {

//line gbbasic.w:1474
			for j := k + 1; j <= d; j++ {
				if xtab[j-1] != 0 {
					ltab[j] = ltab[j-1] >> 1
					ytab[j] = ytab[j-1] + ltab[j]
					stab[j] = stab[j-1]
				} else {
					ytab[j] = ytab[j-1] & (ytab[j-1] - 1) // 최하위 1비트를 없앤다
					ltab[j] = ytab[j-1] - ytab[j]
					stab[j] = stab[j-1] - 1
				}
				if stab[j] <= ytab[j] {
					xtab[j] = 0
				} else {
					xtab[j] = 1
				}
			}

//line gbbasic.w:1460

//line gbbasic.w:1494
			for k := int64(0); k <= d; k++ {
				if xtab[k] != 0 {
					buf[k] = '.'
				} else {
					buf[k] = 'x'
				}
			}
			v := &g.Vertices[vi]
			v.Name = string(buf)
			g.HashIn(v)

//line gbbasic.w:1461

//line gbbasic.w:1510
			for j := int64(0); j < d; j++ {
				if xtab[j] == 1 && xtab[j+1] == 1 {
					i, s := j+1, int64(0)
					for s >= 0 {
						xtab[i] = xtab[i+1]
						s += (xtab[i+1] << 1) - 1
						i++
					}
					xtab[i] = 1
					for k := int64(0); k <= d; k++ {
						if xtab[k] != 0 {
							buf[k] = '.'
						} else {
							buf[k] = 'x'
						}
					}
					if u := g.HashLookup(string(buf)); u != nil {
						if directed {
							g.NewArc(v, u, 1)
						} else {
							g.NewEdge(v, u, 1)
						}
					}
					for i--; i > j; i-- {
						xtab[i+1] = xtab[i]
					}
					xtab[i+1] = 1
				}
			}

//line gbbasic.w:1462
			vi++

//line gbbasic.w:1543
			done := false
			for k = d - 1; ; k-- {
				if k <= 0 {
					done = true // |n<=1|일 때만 일어난다
					break
				}
				if xtab[k] == 1 {
					break // 오른쪽에서 가장 가까운 1
				}
			}
			if done {
				break
			}
			for k--; ; k-- {
				if xtab[k] == 0 && ltab[k] > 1 {
					break
				}
				if k == 0 {
					done = true
					break
				}
			}
			if done {
				break
			}
			xtab[k]++

//line gbbasic.w:1464
		}
	}
	if vi != g.N {
		return nil, gbgraph.Impossible
	}

//line gbbasic.w:1366
	return g, nil
}

// |AllTrees|는 |n|개 내부 노드의 이진 트리를 다 낳는다.
//
//line gbbasic.w:1571
//line gbbasic.w:1572
func AllTrees(n int64, directed bool) (*Graph, error) {
	return Binary(n, 0, directed)
}

//line gbbasic.w:1607
func Complement(g *Graph, cp, self, directed bool) (*Graph, error) {
	if g == nil {
		return nil, gbgraph.MissingOperand // |g|가 어디 있나?
	}
	n := g.N
	ng := newLikeG(g)
	ng.MakeCompoundID("complement(", g,
		fmt.Sprintf(",%d,%d,%d)", boolInt(cp), boolInt(self), boolInt(directed)))

//line gbbasic.w:1624
	for i := int64(0); i < n; i++ {
		v := &g.Vertices[i]
		u := &ng.Vertices[i]
		for a := range v.AllArcs() {
			ng.Vertices[g.Index(a.Tip)].U.V = u // |tmp|를 |u|로 찍는다
		}
		if directed {
			for j := int64(0); j < n; j++ {
				vv := &ng.Vertices[j]
				if (vv.U.V == u) == cp {
					if vv != u || self {
						ng.NewArc(u, vv, 1)
					}
				}
			}
		} else {
			j := i // |self|이면 |u|부터, 아니면 그다음부터
			if !self {
				j++
			}
			for ; j < n; j++ {
				vv := &ng.Vertices[j]
				if (vv.U.V == u) == cp {
					ng.NewEdge(u, vv, 1)
				}
			}
		}
	}
	for i := int64(0); i < n; i++ {
		ng.Vertices[i].U.V = nil
	}

//line gbbasic.w:1616
	return ng, nil
}

//line gbbasic.w:1686
func Gunion(g, gg *Graph, multi, directed bool) (*Graph, error) {
	if g == nil || gg == nil {
		return nil, gbgraph.MissingOperand
	}
	n := g.N
	ng := newLikeG(g)
	ng.MakeDoubleCompoundID("gunion(", g, ",", gg,
		fmt.Sprintf(",%d,%d)", boolInt(multi), boolInt(directed)))

//line gbbasic.w:1705
	for i := int64(0); i < n; i++ {
		v := &g.Vertices[i]
		vv := &ng.Vertices[i]
		for a := v.Arcs; a != nil; a = a.Next {
			u := &ng.Vertices[g.Index(a.Tip)]

//line gbbasic.w:1726
			if directed {
				if multi || u.U.V != vv {
					ng.NewArc(vv, u, a.Len)
				} else if bb := u.Z.A; a.Len < bb.Len {
					bb.Len = a.Len
				}
				u.U.V, u.Z.A = vv, vv.Arcs
			} else if ptrGeq(u, vv) {
				if multi || u.U.V != vv {
					ng.NewEdge(vv, u, a.Len)
				} else if bb := u.Z.A; a.Len < bb.Len {
					bb.Len, bb.Partner.Len = a.Len, a.Len
				}
				u.U.V, u.Z.A = vv, vv.Arcs
				if u == vv && a.Next == a.Partner {
					a = a.Partner // 자기 고리의 뒤 짝을 건너뛴다
				}
			}

//line gbbasic.w:1711
		}
		if i < gg.N {
			for a := gg.Vertices[i].Arcs; a != nil; a = a.Next {
				if ti := gg.Index(a.Tip); ti < n {
					u := &ng.Vertices[ti]

//line gbbasic.w:1726
					if directed {
						if multi || u.U.V != vv {
							ng.NewArc(vv, u, a.Len)
						} else if bb := u.Z.A; a.Len < bb.Len {
							bb.Len = a.Len
						}
						u.U.V, u.Z.A = vv, vv.Arcs
					} else if ptrGeq(u, vv) {
						if multi || u.U.V != vv {
							ng.NewEdge(vv, u, a.Len)
						} else if bb := u.Z.A; a.Len < bb.Len {
							bb.Len, bb.Partner.Len = a.Len, a.Len
						}
						u.U.V, u.Z.A = vv, vv.Arcs
						if u == vv && a.Next == a.Partner {
							a = a.Partner // 자기 고리의 뒤 짝을 건너뛴다
						}
					}

//line gbbasic.w:1717
				}
			}
		}
	}

//line gbbasic.w:1695
	for i := int64(0); i < n; i++ {
		ng.Vertices[i].U.V, ng.Vertices[i].Z.A = nil, nil
	}
	return ng, nil
}

//line gbbasic.w:1785
func Intersection(g, gg *Graph, multi, directed bool) (*Graph, error) {
	if g == nil || gg == nil {
		return nil, gbgraph.MissingOperand
	}
	n := g.N
	ng := newLikeG(g)
	ng.MakeDoubleCompoundID("intersection(", g, ",", gg,
		fmt.Sprintf(",%d,%d)", boolInt(multi), boolInt(directed)))

//line gbbasic.w:1805
	for i := int64(0); i < n; i++ {
		if i >= gg.N {
			continue
		}
		v := &g.Vertices[i]
		vv := &ng.Vertices[i]

//line gbbasic.w:1833
		for a := v.Arcs; a != nil; a = a.Next {
			u := &ng.Vertices[g.Index(a.Tip)]
			if u.U.V == vv {
				u.V.I++
				if a.Len < u.W.I {
					u.W.I = a.Len
				}
			} else {
				u.U.V, u.V.I, u.W.I = vv, 0, a.Len
			}
			if u == vv && !directed && a.Next == a.Partner {
				a = a.Partner // 자기 고리의 뒤 짝을 건너뛴다
			}
		}

//line gbbasic.w:1812
		for a := gg.Vertices[i].Arcs; a != nil; a = a.Next {
			ti := gg.Index(a.Tip)
			if ti >= n {
				continue
			}
			u := &ng.Vertices[ti]
			if u.U.V == vv {
				l := u.W.I
				if a.Len > l {
					l = a.Len
				}
				if u.V.I < 0 {

//line gbbasic.w:1871
					bb := u.Z.A // |vv|에서 |u|로 가는 이전 호나 간선
					if l < bb.Len {
						bb.Len = l
						if !directed {
							bb.Partner.Len = l
						}
					}

//line gbbasic.w:1825
				} else {

//line gbbasic.w:1852
					if directed {
						ng.NewArc(vv, u, l)
					} else {
						if ptrGeq(u, vv) {
							ng.NewEdge(vv, u, l)
						}
						if vv == u && a.Next == a.Partner {
							a = a.Partner
						}
					}
					if !multi {
						u.Z.A, u.V.I = vv.Arcs, -1
					} else if u.V.I == 0 {
						u.U.V = nil
					} else {
						u.V.I--
					}

//line gbbasic.w:1827
				}
			}
		}
	}

//line gbbasic.w:1794
	for i := int64(0); i < n; i++ {
		v := &ng.Vertices[i]
		v.U.V, v.Z.A, v.V.I, v.W.I = nil, nil, 0, 0
	}
	return ng, nil
}

//line gbbasic.w:1903
func Lines(g *Graph, directed bool) (*Graph, error) {
	if g == nil {
		return nil, gbgraph.MissingOperand
	}
	m := g.M
	if !directed {
		m = g.M / 2
	}
	ng := gbgraph.NewGraph(m)
	idTail := ",0)"
	if directed {
		idTail = ",1)"
	}
	ng.MakeCompoundID("lines(", g, idTail)

//line gbbasic.w:1933
	restore := func(cnt int64) {
		var prev *Vertex
		for ui := int64(0); ui < cnt; ui++ {
			u := &ng.Vertices[ui]
			if u.U.V != prev {
				prev = u.U.V
				prev.Z.V = u.Z.V // |v.Z|의 원래 값을 되돌린다
				u.Z.V = nil
			}
			if !directed {
				u.W.A.Partner.Tip = prev
			}
		}
	}

//line gbbasic.w:1918

//line gbbasic.w:1953
	ui := int64(0)
	for vidx := g.N - 1; vidx >= 0; vidx-- {
		v := &g.Vertices[vidx]
		mapped := false
		for a := v.Arcs; a != nil; a = a.Next {
			vv := a.Tip
			if !directed {
				if ptrLess(vv, v) {
					continue
				}
				if !inArray(vv, g.Vertices[:g.N]) {
					restore(ui)
					return nil, gbgraph.InvalidOperand // |g|가 무향이 아니다
				}
			}

//line gbbasic.w:1981
			if ui >= m {
				restore(ui)
				return nil, gbgraph.InvalidOperand
			}
			u := &ng.Vertices[ui]
			u.U.V, u.V.V, u.W.A = v, vv, a
			if !directed {
				if a.Partner == nil || a.Partner.Tip != v {
					restore(ui)
					return nil, gbgraph.InvalidOperand
				}
				if v == vv && a.Next == a.Partner {
					a = a.Partner // 자기 고리의 뒤 짝을 건너뛴다
				} else {
					a.Partner.Tip = u // 짝호의 |Tip|을 선그래프 정점으로
				}
			}
			u.Name = lineName(v.Name, vv.Name, directed)
			if !mapped {
				u.Z.V = v.Z.V
				v.Z.V = u
				mapped = true
			}
			ui++

//line gbbasic.w:1969
		}
	}
	if ui != m {
		restore(ui)
		return nil, gbgraph.InvalidOperand
	}

//line gbbasic.w:1919
	if directed {

//line gbbasic.w:2028
		for ui := int64(0); ui < m; ui++ {
			u := &ng.Vertices[ui]
			v := u.V.V
			if v.Arcs != nil {
				li := ng.Index(v.Z.V)
				for {
					ng.NewArc(u, &ng.Vertices[li], 1)
					li++
					if ng.Vertices[li].U.V != v {
						break
					}
				}
			}
		}

//line gbbasic.w:1921
	} else {

//line gbbasic.w:2047
		for ui := int64(0); ui < m; ui++ {
			u := &ng.Vertices[ui]
			mapped := false
			v := u.U.V // 첫 끝점에 닿는 앞선 선들
			for li := ng.Index(v.Z.V); li < ui; li++ {
				ng.NewEdge(u, &ng.Vertices[li], 1)
			}
			v = u.V.V // 이어서 둘째 끝점에 닿는 앞선 선들
			for a := range v.AllArcs() {
				vv := a.Tip
				if inArray(vv, ng.Vertices[:m]) && ptrLess(vv, u) {
					ng.NewEdge(u, vv, 1)
				} else if inArray(vv, g.Vertices[:g.N]) && ptrGeq(vv, v) {
					mapped = true
				}
			}
			if mapped && ptrLess(u.U.V, v) && v.Z.V != nil {
				for li := ng.Index(v.Z.V); ng.Vertices[li].U.V == v; li++ {
					ng.NewEdge(u, &ng.Vertices[li], 1)
				}
			}
		}

//line gbbasic.w:1923
	}
	restore(m)
	return ng, nil
}

// 곱의 종류.
//
//line gbbasic.w:2097
//line gbbasic.w:2098
const (
	Cartesian = 0
	Direct    = 1
	Strong    = 2

//line gbbasic.w:2102
)

func Product(g, gg *Graph, typ int64, directed bool) (*Graph, error) {
	if g == nil || gg == nil {
		return nil, gbgraph.MissingOperand
	}
	if float64(g.N)*float64(gg.N) > maxNNN {
		return nil, gbgraph.VeryBadSpecs // 정점이 너무 많다
	}
	gn := gg.N
	n := g.N * gn
	ng := gbgraph.NewGraph(n)

//line gbbasic.w:2128
	for i := int64(0); i < g.N; i++ {
		for j := int64(0); j < gn; j++ {
			ng.Vertices[i*gn+j].Name = pairName(g.Vertices[i].Name, gg.Vertices[j].Name)
		}
	}
	tf := 0
	if typ != 0 {
		tf = 2
	}
	tf -= int(typ & 1)
	ng.MakeDoubleCompoundID("product(", g, ",", gg,
		fmt.Sprintf(",%d,%d)", tf, boolInt(directed)))

//line gbbasic.w:2115
	if typ&1 == 0 {

//line gbbasic.w:2156
		for ju := int64(0); ju < gn; ju++ {
			for a := gg.Vertices[ju].Arcs; a != nil; a = a.Next {
				jv := gg.Index(a.Tip)
				if !directed {
					if ju > jv {
						continue
					}
					if ju == jv && a.Next == a.Partner {
						a = a.Partner
					}
				}
				for i := int64(0); i < g.N; i++ {

//line gbbasic.w:2190
					if directed {
						ng.NewArc(&ng.Vertices[i*gn+ju], &ng.Vertices[i*gn+jv], a.Len)
					} else {
						ng.NewEdge(&ng.Vertices[i*gn+ju], &ng.Vertices[i*gn+jv], a.Len)
					}

//line gbbasic.w:2169
				}
			}
		}
		for iu := int64(0); iu < g.N; iu++ {
			for a := g.Vertices[iu].Arcs; a != nil; a = a.Next {
				iv := g.Index(a.Tip)
				if !directed {
					if iu > iv {
						continue
					}
					if iu == iv && a.Next == a.Partner {
						a = a.Partner
					}
				}
				for j := int64(0); j < gn; j++ {

//line gbbasic.w:2197
					if directed {
						ng.NewArc(&ng.Vertices[iu*gn+j], &ng.Vertices[iv*gn+j], a.Len)
					} else {
						ng.NewEdge(&ng.Vertices[iu*gn+j], &ng.Vertices[iv*gn+j], a.Len)
					}

//line gbbasic.w:2185
				}
			}
		}

//line gbbasic.w:2117
	}
	if typ != 0 {

//line gbbasic.w:2206
		for iu := int64(0); iu < g.N; iu++ {
			for a := g.Vertices[iu].Arcs; a != nil; a = a.Next {
				iv := g.Index(a.Tip)
				if !directed {
					if iu > iv {
						continue
					}
					if iu == iv && a.Next == a.Partner {
						a = a.Partner
					}
				}
				for ju := int64(0); ju < gn; ju++ {
					for aa := gg.Vertices[ju].Arcs; aa != nil; aa = aa.Next {
						length := a.Len
						if length > aa.Len {
							length = aa.Len
						}
						jv := gg.Index(aa.Tip)
						pu := &ng.Vertices[iu*gn+ju]
						pv := &ng.Vertices[iv*gn+jv]
						if directed {
							ng.NewArc(pu, pv, length)
						} else {
							ng.NewEdge(pu, pv, length)
						}
					}
				}
			}
		}

//line gbbasic.w:2120
	}
	return ng, nil
}

//line gbbasic.w:2285
func Induced(g *Graph, description string, self, multi, directed bool) (*Graph, error) {
	if g == nil {
		return nil, gbgraph.MissingOperand
	}
	var n, nneg int64

//line gbbasic.w:2301
	for i := int64(0); i < g.N; i++ {
		ind := g.Vertices[i].Z.I
		if ind > 0 {
			if n > indGraph {
				return nil, gbgraph.VeryBadSpecs
			}
			if ind >= indGraph {
				if g.Vertices[i].Y.G == nil {
					return nil, gbgraph.MissingOperand + 1 // 치환 그래프가 없다
				}
				n += g.Vertices[i].Y.G.N
			} else {
				n += ind
			}
		} else if ind < -nneg {
			nneg = -ind
		}
	}
	if n > indGraph || nneg > indGraph {
		return nil, gbgraph.VeryBadSpecs + 1 // 거대하다
	}
	n += nneg

//line gbbasic.w:2291
	ng := gbgraph.NewGraph(n)

//line gbbasic.w:2329
	ui := int64(0)
	for k := int64(1); k <= nneg; k++ {
		ng.Vertices[ui].V.I = -k
		ng.Vertices[ui].Name = strconv.FormatInt(-k, 10)
		ui++
	}
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		k := v.Z.I
		if k < 0 {
			v.Z.V = &ng.Vertices[-(k + 1)]
		} else if k > 0 {
			u := &ng.Vertices[ui]
			u.V.I = k
			v.Z.V = u
			if k <= 2 {
				u.Name = v.Name
				ui++
				if k == 2 {
					ng.Vertices[ui].Name = v.Name + "'"
					ui++
				}
			} else if k >= indGraph {

//line gbbasic.w:2466
				gg := v.Y.G
				base := ui
				for j := int64(0); j < gg.N; j++ {
					fromV := &ng.Vertices[ui]
					sv := &gg.Vertices[j]
					fromV.Name = fmt.Sprintf("%s:%s", v.Name, sv.Name)
					for a := sv.Arcs; a != nil; a = a.Next {
						svv := a.Tip
						toV := &ng.Vertices[base+gg.Index(svv)]

//line gbbasic.w:2484
						if svv == sv && !self {
							continue
						}
						if toV.U.V == fromV && !multi {
							bb := toV.Z.A
							if a.Len < bb.Len {
								bb.Len = a.Len
								if !directed {
									bb.Partner.Len = a.Len
								}
							}
							continue
						}
						if !directed {
							if ptrLess(svv, sv) {
								continue
							}
							if svv == sv && a.Next == a.Partner {
								a = a.Partner
							}
							ng.NewEdge(fromV, toV, a.Len)
						} else {
							ng.NewArc(fromV, toV, a.Len)
						}
						toV.U.V = fromV
						if directed || ptrGeq(toV, fromV) {
							toV.Z.A = fromV.Arcs
						} else {
							toV.Z.A = toV.Arcs
						}

//line gbbasic.w:2476
					}
					ui++
				}

//line gbbasic.w:2353
			} else {
				for j := int64(0); j < k; j++ {
					ng.Vertices[ui].Name = fmt.Sprintf("%s:%d", v.Name, j)
					ui++
				}
			}
		}
	}

//line gbbasic.w:2293
	ng.MakeCompoundID("induced(", g,
		fmt.Sprintf(",%s,%d,%d,%d)", description, boolInt(self), boolInt(multi), boolInt(directed)))

//line gbbasic.w:2367
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		u0 := v.Z.V
		if u0 == nil {
			continue
		}
		k := u0.V.I // |v|의 복제본 수
		if k < 0 {
			k = 1
		} else if k >= indGraph {
			k = v.Y.G.N
		}
		ci := ng.Index(u0)
		for ; k > 0; k, ci = k-1, ci+1 {
			u := &ng.Vertices[ci]
			if !multi {

//line gbbasic.w:2392
				for a := range u.AllArcs() {
					tip := a.Tip
					tip.U.V = u
					if directed || ptrLess(u, tip) || a.Next == a.Partner {
						tip.Z.A = a
					} else {
						tip.Z.A = a.Partner
					}
				}

//line gbbasic.w:2384
			}
			for a := v.Arcs; a != nil; a = a.Next {

//line gbbasic.w:2403
				vv := a.Tip
				vvmap := vv.Z.V
				if vvmap == nil {
					continue
				}
				j := vvmap.V.I // |vv|의 복제본 수
				if j < 0 {
					j = 1
				} else if j >= indGraph {
					j = vv.Y.G.N
				}
				uui := ng.Index(vvmap)
				if !directed {
					if ptrLess(vv, v) {
						continue
					}
					if vv == v {
						if a.Next == a.Partner {
							a = a.Partner
						}
						j, uui = k, ci // 자기 고리의 중복 간선도 건너뛴다
					}
				}

//line gbbasic.w:2431
				for ; j > 0; j, uui = j-1, uui+1 {
					uu := &ng.Vertices[uui]
					if u == uu && !self {
						continue
					}
					if uu.U.V == u && !multi {

//line gbbasic.w:2453
						bb := uu.Z.A
						if a.Len < bb.Len {
							bb.Len = a.Len
							if !directed {
								bb.Partner.Len = a.Len
							}
						}
						continue

//line gbbasic.w:2438
					}
					if directed {
						ng.NewArc(u, uu, a.Len)
					} else {
						ng.NewEdge(u, uu, a.Len)
					}
					uu.U.V = u
					if directed || ptrGeq(uu, u) {
						uu.Z.A = u.Arcs
					} else {
						uu.Z.A = uu.Arcs
					}
				}

//line gbbasic.w:2387
			}
		}
	}

//line gbbasic.w:2296

//line gbbasic.w:2520
	for v := range g.AllVertices() {
		if v.Z.V != nil {
			v.Z.I = v.Z.V.V.I // |ind|를 되살린다
			v.Z.V = nil
		}
	}
	for i := int64(0); i < n; i++ {
		v := &ng.Vertices[i]
		v.U.V, v.V.I, v.Z.A = nil, 0, nil
	}

//line gbbasic.w:2297
	return ng, nil
}

// |BiComplete|는 크기 |n1|, |n2|의 완전 이분 그래프다.
//
//line gbbasic.w:2544
//line gbbasic.w:2545
func BiComplete(n1, n2 int64, directed bool) (*Graph, error) {
	ng, err := Board(2, 0, 0, 0, 1, 0, directed)
	if err != nil {
		return nil, err
	}
	ng.Vertices[0].Z.I = n1
	ng.Vertices[1].Z.I = n2
	ng, err = Induced(ng, "", false, false, directed)
	if err != nil {
		return nil, err
	}
	ng.ID = fmt.Sprintf("bi_complete(%d,%d,%d)", n1, n2, boolInt(directed))
	ng.MarkBipartite(n1)
	return ng, nil
}

// |Wheel|은 |n1|개 중심점에 이어진 |n|개 정점의 바퀴다.
//
//line gbbasic.w:2564
//line gbbasic.w:2565
func Wheel(n, n1 int64, directed bool) (*Graph, error) {
	ng, err := Board(2, 0, 0, 0, 1, 0, directed)
	if err != nil {
		return nil, err
	}
	ng.Vertices[0].Z.I = n1
	ng.Vertices[1].Z.I = indGraph
	cyc, err := Board(n, 0, 0, 0, 1, 1, directed) // 순환 또는 회로
	if err != nil {
		return nil, err
	}
	ng.Vertices[1].Y.G = cyc
	ng, err = Induced(ng, "", false, false, directed)
	if err != nil {
		return nil, err
	}
	ng.ID = fmt.Sprintf("wheel(%d,%d,%d)", n, n1, boolInt(directed))
	return ng, nil
}
