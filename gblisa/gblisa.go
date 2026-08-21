//line gblisa.w:103
package gblisa

import (
	"fmt"
	"path/filepath"
	"strconv"

	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
)

const (
	maxM = 360 // 입력 자료의 전체 행 수
	maxN = 250 // 입력 자료의 전체 열 수
	maxD = 255 // 입력 자료의 최대 픽셀 값
)

// |Region|은 그림에서 이름난 부분을 가리키는 입력 구간이다.
// 구간은 $[M0,M1)$행, $[N0,N1)$열로 오른쪽이 열려 있다.
//
//line gblisa.w:87
//line gblisa.w:88
//line gblisa.w:89
type Region struct{ M0, M1, N0, N1 int64 }

var (
	Smile = Region{94, 110, 97, 129} // $16\times32$짜리 미소
	Eyes  = Region{61, 80, 91, 140}  // $19\times49$짜리 두 눈
)

//line gblisa.w:128
type Matrix struct {
	M, N           int64   // 기본값 적용 뒤의 행·열 수
	D              int64   // 기본값 적용 뒤의 최대 픽셀 값
	M0, M1, N0, N1 int64   // 실제 쓰인 입력 구간
	Pix            []int64 // 길이 |M*N|의 픽셀 행렬
	ID             string  // \.{"lisa(...)"} 꼴의 식별 문자열
}

//line gblisa.w:162
func Lisa(m, n, d, m0, m1, n0, n1, d0, d1 int64, dir string) (*Matrix, error) {

//line gblisa.w:174
	if m1 == 0 || m1 > maxM {
		m1 = maxM
	}
	if m1 <= m0 {
		return nil, gbgraph.BadSpecs + 1 // |m0|는 |m1|보다 작아야 한다
	}
	if n1 == 0 || n1 > maxN {
		n1 = maxN
	}
	if n1 <= n0 {
		return nil, gbgraph.BadSpecs + 2 // |n0|는 |n1|보다 작아야 한다
	}
	capM, capN := m1-m0, n1-n0
	if m == 0 {
		m = capM
	}
	if n == 0 {
		n = capN
	}
	if d == 0 {
		d = maxD
	}
	if d1 == 0 {
		d1 = maxD * capM * capN
	}
	if d1 <= d0 {
		return nil, gbgraph.BadSpecs + 3 // |d0|는 |d1|보다 작아야 한다
	}
	if d1 >= 0x80000000 {
		return nil, gbgraph.BadSpecs + 4 // |d1|은 $2^{31}$보다 작아야 한다
	}
	capD := d1 - d0
	id := fmt.Sprintf("lisa(%d,%d,%d,%d,%d,%d,%d,%d,%d)",
		m, n, d, m0, m1, n0, n1, d0, d1)

//line gblisa.w:164
	matx := make([]int64, m*n)

//line gblisa.w:214
	df, err := gbio.Open(filepath.Join(dir, "lisa.dat"))
	if err != nil {
		return nil, gbgraph.EarlyDataFault // 파일을 열 수 없다
	}
	for i := int64(0); i < m0; i++ {
		for j := 0; j < 5; j++ {
			df.NextLine() // 입력 한 행을 건너뛴다
		}
	}
	inRow := make([]int64, maxN)

//line gblisa.w:245
	kappa, kap := int64(0), int64(0)
	for k := int64(0); k < m; k++ {
		base := k * n
		for l := int64(0); l < n; l++ {
			matx[base+l] = 0 // 합의 벡터를 지운다
		}
		nextKap := kap + capM
		for {
			if kap >= kappa {

//line gblisa.w:325
				j := int64(15)
				p := int64(0)
				var dd int64
				for {
					dd = df.Digit(85)
					dd = dd*85 + df.Digit(85)
					dd = dd*85 + df.Digit(85)
					if p == maxN-2 {
						break
					}
					dd = dd*85 + df.Digit(85)
					dd = dd*85 + df.Digit(85)
					inRow[p+3] = dd & 0xff
					dd = (dd >> 8) & 0xffffff
					inRow[p+2] = dd & 0xff
					dd >>= 8
					inRow[p+1] = dd & 0xff
					inRow[p] = dd >> 8
					if j--; j == 0 {
						df.NextLine()
						j = 15
					}
					p += 4
				}
				inRow[p+1] = dd & 0xff
				inRow[p] = dd >> 8
				df.NextLine()

//line gblisa.w:255
				kappa += m
			}
			nk := kappa
			if nextKap < nk {
				nk = nextKap
			}
			fac := nk - kap

//line gblisa.w:276
			lambda := n
			curPix := n0
			lam := int64(0)
			for l := int64(0); l < n; l++ {
				sum := int64(0)
				nextLam := lam + capN
				for {
					if lam >= lambda {
						curPix++
						lambda += n
					}
					nl := lambda
					if nextLam < nl {
						nl = nextLam
					}
					sum += (nl - lam) * inRow[curPix]
					lam = nl
					if lam >= nextLam {
						break
					}
				}
				matx[base+l] += fac * sum
			}

//line gblisa.w:263
			kap = nk
			if kap >= nextKap {
				break
			}
		}

//line gblisa.w:304
		for l := int64(0); l < n; l++ {
			switch s := matx[base+l]; {
			case s <= d0:
				matx[base+l] = 0
			case s >= d1:
				matx[base+l] = d
			default:
				matx[base+l] = d * (s - d0) / capD
			}
		}

//line gblisa.w:269
	}

//line gblisa.w:225
	for i := m1; i < maxM; i++ {
		for j := 0; j < 5; j++ {
			df.NextLine() // 입력 한 행을 건너뛴다
		}
	}
	if df.Close() != nil {
		return nil, gbgraph.LateDataFault // 검사합 따위의 오류
	}

//line gblisa.w:166
	return &Matrix{M: m, N: n, D: d, M0: m0, M1: m1, N0: n0, N1: n1,
		Pix: matx, ID: id}, nil
}

//line gblisa.w:391
func PlaneLisa(m, n, d, m0, m1, n0, n1, d0, d1 int64, dir string) (*gbgraph.Graph, error) {
	mx, err := Lisa(m, n, d, m0, m1, n0, n1, d0, d1, dir)
	if err != nil {
		return nil, err // |Lisa|가 이미 사정을 알렸다
	}
	a := mx.Pix
	m, n = mx.M, mx.N

//line gblisa.w:433
	f := make([]int64, n)
	regs := int64(0)
	apos := n*(m+1) - 1
	for k := m; k >= 0; k-- {
		for l := n - 1; l >= 0; l-- {

//line gblisa.w:452
			if k < m {
				switch {
				case k > 0 && a[apos-n] == a[apos]:
					j := l
					for f[j] != j {
						j = f[j] // 이 영역의 첫 원소를 찾는다
					}
					f[j] = l // 새 첫 원소에 잇는다
					a[apos] = l
				case f[l] == l:
					a[apos] = -1 - a[apos]
					regs++ // 새 영역을 찾았다
				default:
					a[apos] = f[l]
				}
			}

//line gblisa.w:439
			if k > 0 && l < n-1 && a[apos-n] == a[apos-n+1] {
				f[l+1] = l
			}
			f[l] = l
			apos--
		}
	}

//line gblisa.w:399

//line gblisa.w:470
	g := gbgraph.NewGraph(regs)
	g.ID = "plane_" + mx.ID
	g.UtilTypes = "ZZZIIIZZIIZZZZ"
	g.UU.I = m // |matrix_rows|
	g.VV.I = n // |matrix_cols|

//line gblisa.w:400

//line gblisa.w:483
	regs = 0
	u := make([]*gbgraph.Vertex, n)
	ap, aloc := int64(0), int64(0)
	for k := int64(0); k < m; k++ {
		for l := int64(0); l < n; l++ {
			w := u[l] // 자리 |[k-1,l]|의 정점
			var v *gbgraph.Vertex

//line gblisa.w:508
			if a[ap] < 0 {
				v = &g.Vertices[regs]
				v.Name = strconv.FormatInt(regs, 10)
				v.X.I = -a[ap] - 1 // |pixel_value|
				v.Y.I = aloc       // |first_pixel|
				regs++
			} else {
				v = u[a[ap]]
			}

//line gblisa.w:491
			u[l] = v
			v.Z.I = aloc // |last_pixel|
			if k > 0 && v != w {
				adjac(g, v, w)
			}
			if l > 0 && v != u[l-1] {
				adjac(g, v, u[l-1])
			}
			ap++
			aloc++
		}
	}

//line gblisa.w:401
	return g, nil
}

//line gblisa.w:524
func adjac(g *gbgraph.Graph, u, v *gbgraph.Vertex) {
	for a := range u.AllArcs() {
		if a.Tip == v {
			return // 이미 이웃이다
		}
	}
	g.NewEdge(u, v, 1)
}

//line gblisa.w:551
func BiLisa(m, n, m0, m1, n0, n1, thresh int64, c bool, dir string) (*gbgraph.Graph, error) {
	mx, err := Lisa(m, n, 65535, m0, m1, n0, n1, 0, 0, dir)
	if err != nil {
		return nil, err // |Lisa|가 이미 사정을 알렸다
	}
	m, n = mx.M, mx.N
	m0, m1, n0, n1 = mx.M0, mx.M1, mx.N0, mx.N1

//line gblisa.w:567
	g := gbgraph.NewGraph(m + n)
	cflag := byte('0')
	if c {
		cflag = '1'
	}
	g.ID = fmt.Sprintf("bi_lisa(%d,%d,%d,%d,%d,%d,%d,%c)",
		m, n, m0, m1, n0, n1, thresh, cflag)
	g.SetUtilType(7, 'I') // 호의 |B.I| 필드를 켠다
	g.MarkBipartite(m)
	for k := int64(0); k < m; k++ {
		g.Vertices[k].Name = "r" + strconv.FormatInt(k, 10)
	}
	for l := int64(0); l < n; l++ {
		g.Vertices[m+l].Name = "c" + strconv.FormatInt(l, 10)
	}

//line gblisa.w:559

//line gblisa.w:584
	ap := int64(0)
	for k := int64(0); k < m; k++ {
		uu := &g.Vertices[k]
		for l := int64(0); l < n; l++ {
			v := &g.Vertices[m+l]
			pix := mx.Pix[ap]
			adj := pix >= thresh
			if c {
				adj = pix < thresh
			}
			if adj {
				g.NewEdge(uu, v, 1)
				uu.Arcs.B.I = pix // 두 짝 호에 픽셀 값을 새긴다
				v.Arcs.B.I = pix
			}
			ap++
		}
	}

//line gblisa.w:560
	return g, nil
}
