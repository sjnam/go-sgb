// Package lisa implements GB_LISA from Stanford GraphBase.
//
// Lisa returns a pixel matrix derived from the Mona Lisa image (lisa.dat,
// 360×250 pixels, values 0–255). PlaneLisa builds an undirected planar graph
// whose vertices are connected pixel regions. BiLisa builds an undirected
// bipartite graph whose vertices are image rows and columns.
//
// Vertex utility fields for PlaneLisa (UtilTypes "ZZZIIIZZIIZZZZ"):
//
//	X = pixel_value (int64: grey value of this region)
//	Y = first_pixel (int64: k*n+l for topmost-leftmost pixel)
//	Z = last_pixel  (int64: k*n+l for bottommost-rightmost pixel)
//
// Graph utility fields for PlaneLisa:
//
//	UU = matrix_rows (int64: m)
//	VV = matrix_cols (int64: n)
//
// Arc utility fields for BiLisa (UtilTypes "ZZZZZZZIIZZZZZ"):
//
//	B = pixel_val (int64: scaled pixel value in [0,65535])
package gblisa

import (
	"fmt"

	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
)

const (
	MaxM = 360 // total rows in lisa.dat
	MaxN = 250 // total columns in lisa.dat
	MaxD = 255 // maximum pixel value in lisa.dat
)

// lisaParams holds the parameters of a Lisa call after default substitution.
type lisaParams struct {
	m, n, d, m0, m1, n0, n1, d0, d1 int64
}

// id returns the identification string for these parameters, matching the
// lisa_id string of the original SGB.
func (p lisaParams) id() string {
	return fmt.Sprintf("lisa(%d,%d,%d,%d,%d,%d,%d,%d,%d)",
		p.m, p.n, p.d, p.m0, p.m1, p.n0, p.n1, p.d0, p.d1)
}

// normalizeLisa validates the parameters of a Lisa call and applies the
// documented default substitutions.
func normalizeLisa(m, n, d, m0, m1, n0, n1, d0, d1 int64) (lisaParams, error) {
	if m1 == 0 || m1 > MaxM {
		m1 = MaxM
	}
	if m1 <= m0 {
		return lisaParams{}, gbgraph.ErrBadSpecs
	}
	if n1 == 0 || n1 > MaxN {
		n1 = MaxN
	}
	if n1 <= n0 {
		return lisaParams{}, gbgraph.ErrBadSpecs
	}
	if m == 0 {
		m = m1 - m0
	}
	if n == 0 {
		n = n1 - n0
	}
	if d == 0 {
		d = MaxD
	}
	if d1 == 0 {
		d1 = MaxD * (m1 - m0) * (n1 - n0)
	}
	if d1 <= d0 {
		return lisaParams{}, gbgraph.ErrBadSpecs
	}
	if d1 >= 0x80000000 {
		return lisaParams{}, gbgraph.ErrBadSpecs
	}
	return lisaParams{m, n, d, m0, m1, n0, n1, d0, d1}, nil
}

// Vertex utility-field accessors for PlaneLisa.
func PixelValue(v *gbgraph.Vertex) int64 { i, _ := v.X.(int64); return i }
func FirstPixel(v *gbgraph.Vertex) int64 { i, _ := v.Y.(int64); return i }
func LastPixel(v *gbgraph.Vertex) int64  { i, _ := v.Z.(int64); return i }

// Graph utility-field accessors for PlaneLisa.
func MatrixRows(g *gbgraph.Graph) int64 { i, _ := g.UU.(int64); return i }
func MatrixCols(g *gbgraph.Graph) int64 { i, _ := g.VV.(int64); return i }

// PixelVal returns the scaled pixel value stored in an arc of a BiLisa graph.
func PixelVal(a *gbgraph.Arc) int64 { i, _ := a.B.(int64); return i }

// Package-level pixel-row buffer (one row at a time from the data file).

// ---- na_over_b: ⌊n·a/b⌋ without overflow, 0 < a ≤ b ----

const elGordo = int64(0x7fffffff)

func naOverB(n, a, b int64) int64 {
	nmax := elGordo / a
	if n <= nmax {
		return (n * a) / b
	}
	aThresh := b - a
	bThresh := (b + 1) >> 1 // ⌈b/2⌉
	var bit [30]int64
	k := 0
	for n > nmax {
		bit[k] = n & 1
		n >>= 1
		k++
	}
	r := n * a
	q := r / b
	r = r - q*b
	for k > 0 {
		k--
		q <<= 1
		if r < bThresh {
			r <<= 1
		} else {
			q++
			br := (b - r) << 1
			r = b - br
		}
		if bit[k] != 0 {
			if r < aThresh {
				r += a
			} else {
				q++
				r -= aThresh
			}
		}
	}
	return q
}

// ---- lisa.dat row reader ----

// readLisaRow fills inRow[0..MaxN-1] from the current position in lisa.dat.
// Each row occupies 5 data lines: the first 4 lines have 15 groups of 5
// radix-85 digits (60 pixels per line), and the 5th line has 5+5+3 digits
// (10 more pixels).
func readLisaRow(r *gbio.Reader, inRow []int64) {
	j := 15
	var dd int64
	for cp := 0; ; cp += 4 {
		dd = r.GbDigit(85)
		dd = dd*85 + r.GbDigit(85)
		dd = dd*85 + r.GbDigit(85)
		if cp == MaxN-2 { // last group: only 2 pixels (3 digits already read)
			break
		}
		dd = dd*85 + r.GbDigit(85)
		dd = dd*85 + r.GbDigit(85)
		inRow[cp+3] = dd & 0xff
		dd = (dd >> 8) & 0xffffff
		inRow[cp+2] = dd & 0xff
		dd >>= 8
		inRow[cp+1] = dd & 0xff
		inRow[cp] = dd >> 8
		j--
		if j == 0 {
			r.GbNewline()
			j = 15
		}
	}
	inRow[MaxN-1] = dd & 0xff
	inRow[MaxN-2] = dd >> 8
	r.GbNewline()
}

// ---- Lisa ----

// Lisa constructs an m×n matrix of pixel values in [0..d], sampled from the
// region rows [m0..m1) × columns [n0..n1) of lisa.dat.
// Returns (nil, error) on bad parameters or I/O error.
func Lisa(m, n, d, m0, m1, n0, n1, d0, d1 int64) ([]int64, error) {
	p, err := normalizeLisa(m, n, d, m0, m1, n0, n1, d0, d1)
	if err != nil {
		return nil, err
	}
	return lisa(p)
}

// lisa builds the pixel matrix for already-normalized parameters.
func lisa(p lisaParams) ([]int64, error) {
	var inRow [MaxN]int64

	m, n, d := p.m, p.n, p.d
	m0, m1, n0, n1 := p.m0, p.m1, p.n0, p.n1
	d0, d1 := p.d0, p.d1
	capM := m1 - m0
	capN := n1 - n0
	capD := d1 - d0

	r, err := gbio.Open("lisa.dat")
	if err != nil {
		return nil, gbgraph.ErrEarlyDataFault
	}

	// Skip the first m0 rows (each row = 5 lines).
	for i := int64(0); i < m0; i++ {
		for j := 0; j < 5; j++ {
			r.GbNewline()
		}
	}

	matx := make([]int64, m*n)
	outRow := int64(0) // index of first element of current output row

	kappa := int64(0) // bottom boundary in giant for the current input row
	kap := int64(0)   // first giant row not yet used

	for k := int64(0); k < m; k++ {
		// Clear output row.
		for l := int64(0); l < n; l++ {
			matx[outRow+l] = 0
		}
		nextKap := kap + capM

		for kap < nextKap {
			if kap >= kappa {
				readLisaRow(r, inRow[:])
				kappa += m
			}
			var nk int64
			if kappa < nextKap {
				nk = kappa
			} else {
				nk = nextKap
			}
			f := nk - kap // replication factor for this slice of rows

			// Process one row: accumulate f * pixel into each output column.
			lambda := n  // right boundary in giant for current input pixel
			curPix := n0 // index into inRow
			for l, lam := int64(0), int64(0); l < n; l++ {
				sum := int64(0)
				nextLam := lam + capN
				for lam < nextLam {
					if lam >= lambda {
						curPix++
						lambda += n
					}
					var nl int64
					if lambda < nextLam {
						nl = lambda
					} else {
						nl = nextLam
					}
					sum += (nl - lam) * inRow[curPix]
					lam = nl
				}
				matx[outRow+l] += f * sum
			}
			kap = nk
		}

		// Scale each output pixel.
		for l := int64(0); l < n; l++ {
			v := matx[outRow+l]
			if v <= d0 {
				matx[outRow+l] = 0
			} else if v >= d1 {
				matx[outRow+l] = d
			} else {
				matx[outRow+l] = naOverB(d, v-d0, capD)
			}
		}
		outRow += n
	}

	// Skip remaining rows up to the end.
	for i := m1; i < MaxM; i++ {
		for j := 0; j < 5; j++ {
			r.GbNewline()
		}
	}

	if err := r.Close(); err != nil {
		return nil, gbgraph.ErrLateDataFault
	}
	return matx, nil
}

// ---- PlaneLisa ----

// PlaneLisa constructs an undirected planar graph whose vertices are connected
// regions of equal pixel value in the m×n digitization produced by Lisa.
// UtilTypes = "ZZZIIIZZIIZZZZ".
func PlaneLisa(m, n, d, m0, m1, n0, n1, d0, d1 int64) (*gbgraph.Graph, error) {
	p, err := normalizeLisa(m, n, d, m0, m1, n0, n1, d0, d1)
	if err != nil {
		return nil, err
	}
	a, err := lisa(p)
	if err != nil {
		return nil, err
	}
	m, n = p.m, p.n // actual dimensions after default substitution

	// ---- Pass 1: bottom-right to top-left, label regions ----

	f := make([]int64, n)
	regs := int64(0)

	// Initialize f for k=m (the virtual row beyond the matrix).
	for l := n - 1; l >= 0; l-- {
		if l < n-1 && a[(m-1)*n+l] == a[(m-1)*n+l+1] {
			f[l+1] = l
		}
		f[l] = l
	}

	// Process actual rows m-1 down to 0.
	for k := m - 1; k >= 0; k-- {
		for l := n - 1; l >= 0; l-- {
			ai := k*n + l
			if k > 0 && a[ai-n] == a[ai] {
				// Pixel above has the same value: find root of the chain.
				j := l
				for f[j] != j {
					j = f[j]
				}
				f[j] = l
				a[ai] = l
			} else if f[l] == l {
				// New region head.
				a[ai] = -1 - a[ai]
				regs++
			} else {
				a[ai] = f[l]
			}
			if k > 0 && l < n-1 && a[ai-n] == a[ai-n+1] {
				f[l+1] = l
			}
			f[l] = l
		}
	}

	// ---- Set up the graph ----
	g := gbgraph.NewGraph(regs)
	g.ID = "plane_" + p.id()
	g.UtilTypes = "ZZZIIIZZIIZZZZ"
	g.UU = m
	g.VV = n

	// ---- Pass 2: top-left to bottom-right, assign vertices and edges ----
	u := make([]*gbgraph.Vertex, n)
	regs = 0
	for k := int64(0); k < m; k++ {
		for l := int64(0); l < n; l++ {
			ai := k*n + l
			aloc := ai
			w := u[l]
			var v *gbgraph.Vertex
			if a[ai] < 0 {
				// Region head: create new vertex.
				v = &g.Vertices[regs]
				v.Name = fmt.Sprintf("%d", regs)
				v.X = -a[ai] - 1 // pixel_value
				v.Y = aloc       // first_pixel
				regs++
			} else {
				v = u[a[ai]]
			}
			u[l] = v
			v.Z = aloc // last_pixel (updated each time we visit the region)
			if k > 0 && v != w {
				adjac(g, v, w)
			}
			if l > 0 && v != u[l-1] {
				adjac(g, v, u[l-1])
			}
		}
	}
	return g, nil
}

// adjac adds an undirected edge of length 1 between u and v, unless it already exists.
func adjac(g *gbgraph.Graph, u, v *gbgraph.Vertex) {
	for a := range u.AllArcs() {
		if a.Tip == v {
			return
		}
	}
	g.NewEdge(u, v, 1)
}

// ---- BiLisa ----

// BiLisa constructs an undirected bipartite graph with m row-vertices and
// n column-vertices. Row k and column l are adjacent when the pixel value
// in the m×n digitization is >= thresh (or < thresh when c is true).
// UtilTypes = "ZZZZZZZIIZZZZZ".
func BiLisa(m, n, m0, m1, n0, n1, thresh int64, c bool) (*gbgraph.Graph, error) {
	p, err := normalizeLisa(m, n, 65535, m0, m1, n0, n1, 0, 0)
	if err != nil {
		return nil, err
	}
	a, err := lisa(p)
	if err != nil {
		return nil, err
	}
	// Actual parameters after default substitution.
	m, n, m0, m1, n0, n1 = p.m, p.n, p.m0, p.m1, p.n0, p.n1

	g := gbgraph.NewGraph(m + n)
	cChar := byte('0')
	if c {
		cChar = '1'
	}
	g.ID = fmt.Sprintf("bi_lisa(%d,%d,%d,%d,%d,%d,%d,%c)", m, n, m0, m1, n0, n1, thresh, cChar)
	g.MarkBipartite(m)
	// Also mark arc B field as int.
	ut := []byte(g.UtilTypes)
	ut[7] = 'I'
	g.UtilTypes = string(ut)

	// Name row vertices r0..r(m-1) and column vertices c0..c(n-1).
	for k := int64(0); k < m; k++ {
		g.Vertices[k].Name = fmt.Sprintf("r%d", k)
	}
	for l := int64(0); l < n; l++ {
		g.Vertices[m+l].Name = fmt.Sprintf("c%d", l)
	}

	// Add edges.
	for k := int64(0); k < m; k++ {
		u := &g.Vertices[k]
		for l := int64(0); l < n; l++ {
			pix := a[k*n+l]
			include := pix >= thresh
			if c {
				include = pix < thresh
			}
			if include {
				v := &g.Vertices[m+l]
				g.NewEdge(u, v, 1)
				u.Arcs.B = pix
				v.Arcs.B = pix
			}
		}
	}
	return g, nil
}
