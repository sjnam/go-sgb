// Package miles implements GB_MILES from Stanford GraphBase.
// Miles constructs graphs based on highway mileage data between 128 North
// American cities, returning the graph together with a DistanceMatrix that
// provides direct access to the mileage data.
package gbmiles

import (
	"fmt"

	gbflip "github.com/sjnam/go-sgb/gb-flip"
	gbgraph "github.com/sjnam/go-sgb/gb-graph"
	gbio "github.com/sjnam/go-sgb/gb-io"
	gbsort "github.com/sjnam/go-sgb/gb-sort"
)

// MaxN is the number of cities in miles.dat (also the default value of n).
const MaxN = 128

// Extreme values present in miles.dat, used to validate the data.
const (
	minLat, maxLat int64 = 2672, 5042
	minLon, maxLon int64 = 7180, 12312
	minPop, maxPop int64 = 2521, 875538
)

// DistanceMatrix records the highway distances (in miles) between the cities
// of miles.dat for one Miles graph. Entry [MaxN*j+k] is the distance between
// cities j and k; negative values indicate edges suppressed by the
// maxDistance or maxDegree constraints of the Miles call that produced it.
type DistanceMatrix [MaxN * MaxN]int64

type cityData struct {
	kk       int64
	lat, lon int64
	pop      int64
	name     string
}
type cityNode = gbsort.Node[cityData]

// Vertex utility-field accessors (UtilTypes = "ZZIIIIZZZZZZZZ"):
//
//	W = people (population), X = x_coord, Y = y_coord, Z = index_no.
func People(v *gbgraph.Vertex) int64  { i, _ := v.W.(int64); return i }
func XCoord(v *gbgraph.Vertex) int64  { i, _ := v.X.(int64); return i }
func YCoord(v *gbgraph.Vertex) int64  { i, _ := v.Y.(int64); return i }
func IndexNo(v *gbgraph.Vertex) int64 { i, _ := v.Z.(int64); return i }

// Distance returns the recorded highway distance between u and v, which must
// be vertices of the graph this matrix was returned with.
func (d *DistanceMatrix) Distance(u, v *gbgraph.Vertex) int64 {
	return d[MaxN*IndexNo(u)+IndexNo(v)]
}

// Miles constructs a graph based on highway distances between North American cities.
//
// Parameters:
//   - n: number of cities to include (0 or >128 → use 128).
//   - northWeight: weight coefficient for latitude (|northWeight| ≤ 100000).
//   - westWeight:  weight coefficient for longitude (|westWeight| ≤ 100000).
//   - popWeight:   weight coefficient for population (|popWeight| ≤ 100).
//   - maxDistance: if >0, omit edges longer than this many miles.
//   - maxDegree:   if >0, keep at most this many edges per vertex (shortest first).
//   - seed:        random seed for breaking ties.
//
// Vertex utility fields: W=population(I), X=x_coord(I), Y=y_coord(I), Z=index(I).
// Edge lengths equal highway distances in miles.
// UtilTypes = "ZZIIIIZZZZZZZZ".
//
// The returned DistanceMatrix records the mileage data for the new graph,
// including distances suppressed by maxDistance or maxDegree.
func Miles(n, northWeight, westWeight, popWeight, maxDistance, maxDegree, seed int64) (*gbgraph.Graph, *DistanceMatrix, error) {
	return MilesRNG(n, northWeight, westWeight, popWeight, maxDistance, maxDegree, seed, gbflip.New(seed))
}

// MilesRNG is Miles using a caller-supplied random generator, so the caller can
// continue the same gb_flip stream afterward — as plane_miles does for its edge
// rejection, where the original relies on miles and the Delaunay pass sharing
// one stream.  seed is used only for the graph ID.
func MilesRNG(n, northWeight, westWeight, popWeight, maxDistance, maxDegree, seed int64, rng *gbflip.RNG) (*gbgraph.Graph, *DistanceMatrix, error) {
	var nodeBlock [MaxN]cityNode
	dm := &DistanceMatrix{}

	if n == 0 || n > MaxN {
		n = MaxN
	}
	origMaxDegree := maxDegree
	if maxDegree == 0 || maxDegree >= n {
		maxDegree = n - 1
	}
	if northWeight > 100000 || northWeight < -100000 ||
		westWeight > 100000 || westWeight < -100000 ||
		popWeight > 100 || popWeight < -100 {
		return nil, nil, gbgraph.ErrBadSpecs
	}

	g := gbgraph.NewGraph(n)
	g.ID = fmt.Sprintf("miles(%d,%d,%d,%d,%d,%d,%d)",
		n, northWeight, westWeight, popWeight, maxDistance, origMaxDegree, seed)
	g.UtilTypes = "ZZIIIIZZZZZZZZ"

	// Read miles.dat. Cities appear in reverse alphabetical order (k=127 first).
	r, err := gbio.Open("miles.dat")
	if err != nil {
		return nil, nil, gbgraph.ErrEarlyDataFault
	}

	for k := int64(MaxN - 1); k >= 0; k-- {
		p := &nodeBlock[k]
		p.Val.kk = k
		if k > 0 {
			p.Link = &nodeBlock[k-1]
		} else {
			p.Link = nil
		}

		p.Val.name = r.GbString('[')
		if r.GbChar() != '[' {
			r.RawClose()
			return nil, nil, gbgraph.ErrSyntaxError
		}
		p.Val.lat = int64(r.GbNumber(10))
		if p.Val.lat < minLat || p.Val.lat > maxLat || r.GbChar() != ',' {
			r.RawClose()
			return nil, nil, gbgraph.ErrSyntaxError
		}
		p.Val.lon = int64(r.GbNumber(10))
		if p.Val.lon < minLon || p.Val.lon > maxLon || r.GbChar() != ']' {
			r.RawClose()
			return nil, nil, gbgraph.ErrSyntaxError
		}
		p.Val.pop = int64(r.GbNumber(10))
		if p.Val.pop < minPop || p.Val.pop > maxPop {
			r.RawClose()
			return nil, nil, gbgraph.ErrSyntaxError
		}

		p.Key = northWeight*(p.Val.lat-minLat) +
			westWeight*(p.Val.lon-minLon) +
			popWeight*(p.Val.pop-minPop) + 0x40000000

		// Read distances to cities already read (k+1 .. MaxN-1).
		// Each distance is preceded by either a space (same line) or a newline.
		for j := k + 1; j < MaxN; j++ {
			if r.GbChar() != ' ' {
				r.GbNewline()
			}
			dist := int64(r.GbNumber(10))
			dm[MaxN*j+k] = dist
			dm[MaxN*k+j] = dist
		}
		r.GbNewline()
	}

	if err := r.Close(); err != nil {
		return nil, nil, gbgraph.ErrLateDataFault
	}

	// Sort cities by weight; assign the top n to graph vertices.
	sorted := gbsort.LinksSort(&nodeBlock[MaxN-1], rng)
	vi := int64(0)
	for j := 127; j >= 0; j-- {
		for p := sorted[j]; p != nil; p = p.Link {
			if vi < n {
				v := &g.Vertices[vi]
				v.Name = p.Val.name
				v.W = p.Val.pop
				v.X = maxLon - p.Val.lon
				yc := p.Val.lat - minLat
				v.Y = yc + (yc >> 1) // ×1.5
				v.Z = p.Val.kk
				vi++
			} else {
				// Exclude this city from edge consideration.
				p.Val.pop = 0
			}
		}
	}

	// Prune edges if max_distance or max_degree was specified.
	if maxDistance > 0 || origMaxDegree > 0 {
		pruneEdges(dm, nodeBlock[:], maxDistance, maxDegree, origMaxDegree, rng)
	}

	// Add edges between every pair of selected vertices with positive distances.
	for ui := int64(0); ui < n; ui++ {
		u := &g.Vertices[ui]
		j := IndexNo(u)
		for vi2 := ui + 1; vi2 < n; vi2++ {
			v := &g.Vertices[vi2]
			k := IndexNo(v)
			if dm[MaxN*j+k] > 0 && dm[MaxN*k+j] > 0 {
				g.NewEdge(u, v, dm[MaxN*j+k])
			}
		}
	}

	return g, dm, nil
}

// pruneEdges negates distances for edges that exceed maxDist or fall outside
// the top maxDeg closest neighbors of each city.
func pruneEdges(dm *DistanceMatrix, nodeBlock []cityNode, maxDist, maxDeg, origMaxDeg int64, rng *gbflip.RNG) {
	localMaxDist := maxDist
	localMaxDeg := maxDeg
	if origMaxDeg == 0 {
		localMaxDeg = MaxN
	}
	if maxDist == 0 {
		localMaxDist = 30000
	}

	for k := range int64(MaxN) {
		p := &nodeBlock[k]
		if p.Val.pop == 0 {
			continue // city not selected
		}
		cityK := p.Val.kk

		// Build a list of nearby cities; negate distances that exceed localMaxDist.
		var s *cityNode
		for qi := range int64(MaxN) {
			q := &nodeBlock[qi]
			if q.Val.pop == 0 || q == p {
				continue
			}
			j := dm[MaxN*cityK+q.Val.kk]
			if j > localMaxDist {
				dm[MaxN*cityK+q.Val.kk] = -j
			} else {
				q.Key = localMaxDist - j
				q.Link = s
				s = q
			}
		}

		// Sort nearby cities by increasing distance (decreasing complementary key).
		if s != nil {
			nearby := gbsort.LinksSort(s, rng)
			// Iterate through sorted list; negate distances beyond localMaxDeg.
			count := int64(0)
			for qi := range 256 {
				for q := nearby[qi]; q != nil; q = q.Link {
					count++
					if count > localMaxDeg {
						dm[MaxN*cityK+q.Val.kk] = -dm[MaxN*cityK+q.Val.kk]
					}
				}
			}
		}
	}
}
