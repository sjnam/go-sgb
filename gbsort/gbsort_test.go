//line gbsort.w:187
package gbsort

import (
	"testing"

	"github.com/sjnam/go-sgb/gbflip"
)

func collect[T any](s [128]*Node[T]) []*Node[T] {
	var out []*Node[T]
	for j := 127; j >= 0; j-- {
		for p := s[j]; p != nil; p = p.Link {
			out = append(out, p)
		}
	}
	return out
}

//line gbsort.w:206
func TestLinkSortOrder(t *testing.T) {
	r := gbflip.New(-314159)
	const n = 1000
	var head *Node[int]
	for i := range n {
		head = &Node[int]{Key: r.Unif(1 << 30), Data: i, Link: head}
	}
	out := collect(LinkSort(head, r))
	if len(out) != n {
		t.Fatalf("노드 %d개가 나왔다(기대 %d)", len(out), n)
	}
	for i := 1; i < len(out); i++ {
		if out[i-1].Key < out[i].Key {
			t.Fatalf("%d번째에서 순서가 어긋났다: %d < %d",
				i, out[i-1].Key, out[i].Key)
		}
	}
}

//line gbsort.w:229
func TestLinkSortBuckets(t *testing.T) {
	r := gbflip.New(271828)
	const n = 500
	seen := map[int]bool{}
	var head *Node[int]
	for i := range n {
		head = &Node[int]{Key: r.Unif(1 << 31), Data: i, Link: head}
	}
	s := LinkSort(head, r)
	count := 0
	for j := 127; j >= 0; j-- {
		for p := s[j]; p != nil; p = p.Link {
			if got := int(p.Key >> 24); got != j {
				t.Fatalf("키 %d가 통 %d에 있다(기대 %d)", p.Key, j, got)
			}
			seen[p.Data] = true
			count++
		}
	}
	if count != n || len(seen) != n {
		t.Fatalf("노드 보존 실패: count=%d, 유일=%d", count, len(seen))
	}
}

//line gbsort.w:259
func shuffleOrder(seed int64) []int {
	r := gbflip.New(seed)
	var head *Node[int]
	for i := range 50 {
		head = &Node[int]{Key: 7, Data: i, Link: head} // 무게가 모두 같다
	}
	var order []int
	for _, p := range collect(LinkSort(head, r)) {
		order = append(order, p.Data)
	}
	return order
}

func TestLinkSortRandomTies(t *testing.T) {
	a := shuffleOrder(42)
	if !slicesEqual(a, shuffleOrder(42)) {
		t.Fatal("같은 시드가 다른 순서를 냈다(재현성 실패)")
	}
	if slicesEqual(a, shuffleOrder(43)) {
		t.Fatal("다른 시드가 같은 순서를 냈다(뒤섞이지 않았다)")
	}
}

func slicesEqual(a, b []int) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
