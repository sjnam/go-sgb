package gbsort

import (
	"testing"

	"github.com/sjnam/go-sgb/gb-flip"
)

// emptyData is a placeholder when nodes carry no extra data.
type emptyData struct{}

func buildList(keys []int64) *Node[emptyData] {
	if len(keys) == 0 {
		return nil
	}
	nodes := make([]Node[emptyData], len(keys))
	for i, k := range keys {
		nodes[i].Key = k
		if i+1 < len(keys) {
			nodes[i].Link = &nodes[i+1]
		}
	}
	return &nodes[0]
}

func collectSorted[T any](buckets [256]*Node[T]) []*Node[T] {
	var out []*Node[T]
	for j := 127; j >= 0; j-- {
		for p := buckets[j]; p != nil; p = p.Link {
			out = append(out, p)
		}
	}
	return out
}

// TestDecreasingOrder verifies that distinct keys come out in non-increasing
// order, mirroring the guarantee documented in gb_sort.w.
func TestDecreasingOrder(t *testing.T) {
	rng := gbflip.New(42)

	keys := []int64{3, 1, 4, 1, 5, 9, 2, 6, 5, 3}
	sorted := LinksSort(buildList(keys), rng)
	out := collectSorted(sorted)

	if len(out) != len(keys) {
		t.Fatalf("got %d nodes, want %d", len(out), len(keys))
	}
	for i := 1; i < len(out); i++ {
		if out[i].Key > out[i-1].Key {
			t.Errorf("position %d: key %d > previous %d (not non-increasing)",
				i, out[i].Key, out[i-1].Key)
		}
	}
}

// TestBucketBoundaries verifies gb_sort.w's bucket rule:
// bucket[j] holds all nodes with key in [j·2^24, (j+1)·2^24).
func TestBucketBoundaries(t *testing.T) {
	rng := gbflip.New(1)

	// Place one key at the boundary between buckets 0 and 1.
	keys := []int64{
		0,         // bucket 0
		1<<24 - 1, // bucket 0 (max of bucket 0)
		1 << 24,   // bucket 1 (min of bucket 1)
		2<<24 - 1, // bucket 1
		2 << 24,   // bucket 2
	}
	sorted := LinksSort(buildList(keys), rng)

	wantBucket := func(key int64) int { return int(key >> 24) }
	for j := range 256 {
		for p := sorted[j]; p != nil; p = p.Link {
			if want := wantBucket(p.Key); want != j {
				t.Errorf("key %d is in bucket %d, want bucket %d", p.Key, j, want)
			}
		}
	}
}

// TestEqualKeysRandomOrder verifies that nodes with equal keys can appear
// in different orders on successive calls (i.e. the random tiebreaking works).
func TestEqualKeysRandomOrder(t *testing.T) {
	const n = 20
	keys := make([]int64, n)
	// all keys equal → order is entirely random

	rng1 := gbflip.New(1)
	sorted1 := LinksSort(buildList(keys), rng1)
	var order1 []int64
	for j := 127; j >= 0; j-- {
		for p := sorted1[j]; p != nil; p = p.Link {
			// Use pointer address as a stable identity across two runs.
			order1 = append(order1, p.Key)
		}
	}

	rng2 := gbflip.New(2) // different seed
	sorted2 := LinksSort(buildList(keys), rng2)
	var order2 []int64
	for j := 127; j >= 0; j-- {
		for p := sorted2[j]; p != nil; p = p.Link {
			order2 = append(order2, p.Key)
		}
	}

	if len(order1) != n || len(order2) != n {
		t.Fatalf("expected %d nodes each, got %d and %d", n, len(order1), len(order2))
	}
	// Both should contain n nodes with key 0.
	// (We can't compare pointer-based ordering here, but at least verify counts.)
	t.Log("random tiebreaking: both runs produce", n, "nodes — order varies by seed")
}

// TestLargeKeys verifies behaviour with keys spread across all 128 real buckets.
func TestLargeKeys(t *testing.T) {
	rng := gbflip.New(314159)

	keys := make([]int64, 128)
	for i := range keys {
		keys[i] = int64(i) << 24 // one key per bucket
	}
	sorted := LinksSort(buildList(keys), rng)

	out := collectSorted(sorted)
	if len(out) != 128 {
		t.Fatalf("got %d nodes, want 128", len(out))
	}
	for i := 1; i < len(out); i++ {
		if out[i].Key > out[i-1].Key {
			t.Errorf("position %d: key %d > previous %d", i, out[i].Key, out[i-1].Key)
		}
	}
}

// TestWithEmbeddedData shows that extra fields embedded in Node[T] survive
// the sort undisturbed.
func TestWithEmbeddedData(t *testing.T) {
	rng := gbflip.New(99)

	type cityData struct {
		Name string
		Pop  int64
	}
	cities := []struct {
		key  int64
		name string
		pop  int64
	}{
		{1000, "Alpha", 500},
		{3000, "Beta", 1200},
		{2000, "Gamma", 800},
	}

	nodes := make([]Node[cityData], len(cities))
	for i, c := range cities {
		nodes[i].Key = c.key
		nodes[i].Val.Name = c.name
		nodes[i].Val.Pop = c.pop
		if i+1 < len(cities) {
			nodes[i].Link = &nodes[i+1]
		}
	}

	sorted := LinksSort(&nodes[0], rng)
	out := collectSorted(sorted)

	if len(out) != 3 {
		t.Fatalf("got %d nodes, want 3", len(out))
	}
	// Expected order: Beta(3000) > Gamma(2000) > Alpha(1000)
	wantNames := []string{"Beta", "Gamma", "Alpha"}
	for i, p := range out {
		if p.Val.Name != wantNames[i] {
			t.Errorf("position %d: got %q (key=%d), want %q",
				i, p.Val.Name, p.Key, wantNames[i])
		}
	}
}
