//line gbmiles.w:71
package gbmiles

import (
	"fmt"
	"path/filepath"

	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/gbsort"
)

//line gbmiles.w:100
const maxN = 128 // 도시의 최대이자 기본 수

const (
	minLat = 2672 // 자료 항목들의 빠듯한 경계
	maxLat = 5042
	minLon = 7180
	maxLon = 12312
	minPop = 2521
	maxPop = 875538

//line gbmiles.w:109
)

type cityInfo struct {
	kk       int64  // 원래 데이터베이스에서의 도시 번호(0..127)
	lat, lon int64  // 위도, 경도
	pop      int64  // 인구
	name     string // |"City Name, ST"|
}

//line gbmiles.w:221
func readCities(f *gbio.File, nodes []gbsort.Node[cityInfo], dist []int64,
	northWeight, westWeight, popWeight int64) error {
	for k := int64(maxN - 1); k >= 0; k-- {

//line gbmiles.w:234
		p := &nodes[k]
		p.Data.kk = k
		if k > 0 {
			p.Link = &nodes[k-1]
		}
		p.Data.name = f.String('[')
		if f.Char() != '[' {
			return gbgraph.SyntaxError // \.{miles.dat}과 어긋났다
		}
		p.Data.lat = f.Number(10)
		if p.Data.lat < minLat || p.Data.lat > maxLat || f.Char() != ',' {
			return gbgraph.SyntaxError + 1 // 위도 자료가 망가졌다
		}
		p.Data.lon = f.Number(10)
		if p.Data.lon < minLon || p.Data.lon > maxLon || f.Char() != ']' {
			return gbgraph.SyntaxError + 2 // 경도 자료가 망가졌다
		}
		p.Data.pop = f.Number(10)
		if p.Data.pop < minPop || p.Data.pop > maxPop {
			return gbgraph.SyntaxError + 3 // 인구 자료가 망가졌다
		}
		p.Key = northWeight*(p.Data.lat-minLat) + westWeight*(p.Data.lon-minLon) +
			popWeight*(p.Data.pop-minPop) + (1 << 30)

//line gbmiles.w:265
		for j := k + 1; j < maxN; j++ {
			if f.Char() != ' ' {
				f.NextLine()
			}
			dd := f.Number(10)
			dist[maxN*j+k] = dd
			dist[maxN*k+j] = dd
		}

//line gbmiles.w:258
		f.NextLine()

//line gbmiles.w:225
	}
	return nil
}

// |MilesRNG|는 |Miles|와 같되 난수 생성기 |rng|를 직접 받는다.
//
//line gbmiles.w:124
//line gbmiles.w:125
func MilesRNG(n, northWeight, westWeight, popWeight, maxDistance, maxDegree, seed int64,
	rng *gbflip.RNG, dir string) (*gbgraph.Graph, error) {
	g, _, err := MilesRNGDist(n, northWeight, westWeight, popWeight,
		maxDistance, maxDegree, seed, rng, dir)
	return g, err
}

// |MaxN|은 도시의 최대 수(거리 행렬의 변)다.
//
//line gbmiles.w:138
//line gbmiles.w:139
const MaxN = maxN

func MilesRNGDist(n, northWeight, westWeight, popWeight, maxDistance, maxDegree, seed int64,
	rng *gbflip.RNG, dir string) (*gbgraph.Graph, []int64, error) {

//line gbmiles.w:162
	if n == 0 || n > maxN {
		n = maxN
	}
	if maxDegree == 0 || maxDegree >= n {
		maxDegree = n - 1
	}
	if northWeight > 100000 || westWeight > 100000 || popWeight > 100 ||
		northWeight < -100000 || westWeight < -100000 || popWeight < -100 {
		return nil, nil, gbgraph.BadSpecs // 무게 하나의 크기가 너무 크다
	}

//line gbmiles.w:144
	g := gbgraph.NewGraph(n)
	g.ID = fmt.Sprintf("miles(%d,%d,%d,%d,%d,%d,%d)",
		n, northWeight, westWeight, popWeight, maxDistance, maxDegree, seed)
	g.UtilTypes = "ZZIIIIZZZZZZZZ"
	nodes := make([]gbsort.Node[cityInfo], maxN)
	dist := make([]int64, maxN*maxN)

//line gbmiles.w:204
	f, err := gbio.Open(filepath.Join(dir, "miles.dat"))
	if err != nil {
		return nil, nil, gbgraph.EarlyDataFault
	}
	err = readCities(f, nodes, dist, northWeight, westWeight, popWeight)
	if cerr := f.Close(); err == nil && cerr != nil {
		err = gbgraph.LateDataFault
	}
	if err != nil {
		return nil, nil, err
	}

//line gbmiles.w:151

//line gbmiles.w:279
	sorted := gbsort.LinkSort(&nodes[maxN-1], rng)
	var filled int64
	for j := 127; j >= 0; j-- {
		for p := sorted[j]; p != nil; p = p.Link {
			if filled < n {

//line gbmiles.w:297
				v := &g.Vertices[filled]
				v.X.I = maxLon - p.Data.lon // |x| 좌표는 경도의 여값
				y := p.Data.lat - minLat
				v.Y.I = y + (y >> 1) // |y| 좌표는 위도의 1.5배
				v.Z.I = p.Data.kk
				v.W.I = p.Data.pop
				v.Name = p.Data.name

//line gbmiles.w:285
				filled++
			} else {
				p.Data.pop = 0 // 이 도시는 안 쓴다
			}
		}
	}

//line gbmiles.w:152
	origDist := append([]int64(nil), dist...) // 가지치기로 바뀌기 전의 스냅샷

//line gbmiles.w:324
	if maxDistance > 0 || maxDegree > 0 {

//line gbmiles.w:343
		pruneDeg := maxDegree
		if pruneDeg == 0 {
			pruneDeg = maxN
		}
		pruneDist := maxDistance
		if pruneDist == 0 {
			pruneDist = 30000
		}
		for i := int64(0); i < maxN; i++ {
			p := &nodes[i]
			if p.Data.pop != 0 {

//line gbmiles.w:366
				k := p.Data.kk
				var s *gbsort.Node[cityInfo]
				for jj := int64(0); jj < maxN; jj++ {
					q := &nodes[jj]
					if q.Data.pop == 0 || q == p {
						continue
					}
					dd := dist[maxN*k+q.Data.kk] // |p|에서 |q|까지의 거리
					if dd > pruneDist {
						dist[maxN*k+q.Data.kk] = -dd
					} else {
						q.Key = pruneDist - dd
						q.Link = s
						s = q
					}
				}
				sorted := gbsort.LinkSort(s, rng)
				var cnt int64
				for q := sorted[0]; q != nil; q = q.Link {
					cnt++
					if cnt > pruneDeg {
						dist[maxN*k+q.Data.kk] = -dist[maxN*k+q.Data.kk]
					}
				}

//line gbmiles.w:355
			}
		}

//line gbmiles.w:326
	}
	for ui := int64(0); ui < n; ui++ {
		u := &g.Vertices[ui]
		j := u.Z.I
		for vi := ui + 1; vi < n; vi++ {
			v := &g.Vertices[vi]
			k := v.Z.I
			if dist[maxN*j+k] > 0 && dist[maxN*k+j] > 0 {
				g.NewEdge(u, v, dist[maxN*j+k])
			}
		}
	}

//line gbmiles.w:154
	return g, origDist, nil
}

// |Miles|는 씨앗 |seed|로 난수 스트림을 열어 도시 그래프를 짓는다.
//
//line gbmiles.w:87
//line gbmiles.w:88
func Miles(n, northWeight, westWeight, popWeight,
	maxDistance, maxDegree, seed int64, dir string) (*gbgraph.Graph, error) {
	return MilesRNG(n, northWeight, westWeight, popWeight,
		maxDistance, maxDegree, seed, gbflip.New(seed), dir)
}
