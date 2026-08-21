//line gbroget.w:69
package gbroget

import (
	"fmt"
	"path/filepath"

	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
)

const maxN = 1022 // Roget 책의 범주 수

//line gbroget.w:89
func Roget(n, minDistance, prob, seed int64, dir string) (*gbgraph.Graph, error) {
	rng := gbflip.New(seed)
	if n == 0 || n > maxN {
		n = maxN
	}

//line gbroget.w:105
	g := gbgraph.NewGraph(n)
	g.ID = fmt.Sprintf("roget(%d,%d,%d,%d)", n, minDistance, prob, seed)
	g.SetUtilType(0, 'I') // |cat_no|는 정수 유틸리티 필드다

//line gbroget.w:95

//line gbroget.w:125
	cats := make([]int64, maxN)
	mapping := make([]*gbgraph.Vertex, maxN+1)
	for i := int64(0); i < maxN; i++ {
		cats[i] = i + 1
	}
	pool := int64(maxN)
	for vi := n - 1; vi >= 0; vi-- {
		j := rng.Unif(pool)
		mapping[cats[j]] = &g.Vertices[vi]
		pool--
		cats[j] = cats[pool]
	}

//line gbroget.w:96

//line gbroget.w:151
	f, err := gbio.Open(filepath.Join(dir, "roget.dat"))
	if err != nil {
		return nil, gbgraph.EarlyDataFault // \.{roget.dat}을 열 수 없다
	}
	k := int64(1)
	for ; !f.EOF(); k++ {

//line gbroget.w:170
		if v := mapping[k]; v != nil { // 이 범주가 뽑혔다
			if f.Number(10) != k {
				return nil, gbgraph.SyntaxError // 동기가 어긋났다
			}
			name := f.String(':')
			if f.Char() != ':' {
				return nil, gbgraph.SyntaxError + 1 // 콜론이 없다
			}
			v.Name = name
			v.U.I = k // 범주 번호를 |cat_no|에 담는다

//line gbroget.w:191
			j := f.Number(10)
			if j != 0 {
			arcs:
				for {
					if j > maxN {
						return nil, gbgraph.SyntaxError + 2 // 범주 번호가 범위 밖이다
					}

//line gbroget.w:229
					dist := j - k
					if dist < 0 {
						dist = -dist
					}
					if mapping[j] != nil && dist >= minDistance &&
						(prob == 0 || (rng.Next()>>15) >= prob) {
						g.NewArc(v, mapping[j], 1)
					}

//line gbroget.w:199
					switch f.Char() {
					case '\\':
						f.NextLine()
						if f.Char() != ' ' {
							return nil, gbgraph.SyntaxError + 3 // 이어짐 줄은 빈칸으로 시작해야 한다
						}
						j = f.Number(10)
					case ' ':
						j = f.Number(10)
					case '\n':
						break arcs
					default:
						return nil, gbgraph.SyntaxError + 4 // 범주 번호 뒤에 엉뚱한 문자
					}
				}
			}
			f.NextLine()

//line gbroget.w:181
		} else {

//line gbroget.w:244
			s := f.String('\n')
			if len(s) > 0 && s[len(s)-1] == '\\' {
				f.NextLine() // 첫 줄이 백슬래시로 끝났다
			}
			f.NextLine()

//line gbroget.w:183
		}

//line gbroget.w:158
	}
	if f.Close() != nil {
		return nil, gbgraph.LateDataFault // \.{roget.dat}에 탈이 있다
	}
	if k != maxN+1 {
		return nil, gbgraph.Impossible // |maxN| 값이 틀렸다
	}

//line gbroget.w:97
	return g, nil
}
