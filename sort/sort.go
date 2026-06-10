// Package sort implements the GB_SORT radix-sort utility from Stanford
// GraphBase. It provides LinksSort, which sorts a linked list of generic
// nodes into 256 buckets in decreasing key order with random tiebreaking.
package sort

import "github.com/sjnam/go-sgb/flip"

// Node is a generic linked-list node for LinksSort.
// Store application-specific data in the Val field:
//
//	type CityData struct { Name string; Pop int64 }
//	type CityNode = gbsort.Node[CityData]   // node.Val.Name, node.Val.Pop
//
// The Key field must be a nonnegative integer less than 2^31.
type Node[T any] struct {
	Key  int64
	Link *Node[T]
	Val  T // application data
}

// LinksSort sorts the linked list l into 256 buckets using six passes of
// radix-256 sort. The first two passes use random numbers from rng so that
// nodes with equal keys appear in random order.
//
// The returned [256]*Node[T] satisfies: bucket[j] holds all nodes whose
// keys are in [j·2^24, (j+1)·2^24). Traverse from bucket[127] down to
// bucket[0] to visit nodes in non-increasing key order.
func LinksSort[T any](l *Node[T], rng *flip.RNG) [256]*Node[T] {
	var sorted, alt [256]*Node[T]

	// Pass 1: l → alt  (random bucket = top 8 bits of rng.Next())
	for p := l; p != nil; {
		q := p.Link
		k := rng.Next() >> 23
		p.Link = alt[k]
		alt[k] = p
		p = q
	}

	// Pass 2: alt → sorted  (random, traverse alt 255→0)
	for i := 255; i >= 0; i-- {
		for p := alt[i]; p != nil; {
			q := p.Link
			k := rng.Next() >> 23
			p.Link = sorted[k]
			sorted[k] = p
			p = q
		}
	}

	// Pass 3: sorted → alt  by key byte 0 (LSB), traverse 255→0
	alt = [256]*Node[T]{}
	for i := 255; i >= 0; i-- {
		for p := sorted[i]; p != nil; {
			q := p.Link
			k := p.Key & 0xff
			p.Link = alt[k]
			alt[k] = p
			p = q
		}
	}

	// Pass 4: alt → sorted  by key byte 1, traverse 0→255
	sorted = [256]*Node[T]{}
	for i := 0; i < 256; i++ {
		for p := alt[i]; p != nil; {
			q := p.Link
			k := (p.Key >> 8) & 0xff
			p.Link = sorted[k]
			sorted[k] = p
			p = q
		}
	}

	// Pass 5: sorted → alt  by key byte 2, traverse 255→0
	alt = [256]*Node[T]{}
	for i := 255; i >= 0; i-- {
		for p := sorted[i]; p != nil; {
			q := p.Link
			k := (p.Key >> 16) & 0xff
			p.Link = alt[k]
			alt[k] = p
			p = q
		}
	}

	// Pass 6: alt → sorted  by key byte 3 (MSB, 0-127), traverse 0→255
	sorted = [256]*Node[T]{}
	for i := 0; i < 256; i++ {
		for p := alt[i]; p != nil; {
			q := p.Link
			k := (p.Key >> 24) & 0xff
			p.Link = sorted[k]
			sorted[k] = p
			p = q
		}
	}

	return sorted
}
