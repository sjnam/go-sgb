// Package flip implements the GB_FLIP random number generator from
// Stanford GraphBase. It provides a portable subtractive method with
// period length 2^85 - 2^30.
package flip

// RNG is a self-contained pseudo-random number generator.
// Create one with New; call its Next method to advance the sequence.
// The zero value is not usable; always call New.
type RNG struct {
	a    [56]int64 // a[0] = -1 sentinel; a[1..55] hold state
	fptr int       // index of next value to return
}

// modDiff computes (x-y) mod 2^31.
func modDiff(x, y int64) int64 { return (x - y) & 0x7fffffff }

// cycle runs one full pass of the subtractive recurrence over a[1..55],
// resets fptr to 54, and returns a[55].
func (r *RNG) cycle() int64 {
	ii := 1
	for jj := 32; jj <= 55; ii, jj = ii+1, jj+1 {
		r.a[ii] = modDiff(r.a[ii], r.a[jj])
	}
	for jj := 1; ii <= 55; ii, jj = ii+1, jj+1 {
		r.a[ii] = modDiff(r.a[ii], r.a[jj])
	}
	r.fptr = 54
	return r.a[55]
}

// New creates and initialises a new RNG with the given seed.
func New(seed int64) *RNG {
	r := &RNG{}
	r.a[0] = -1
	prev := modDiff(seed, 0)
	next := int64(1)
	seed = prev
	r.a[55] = prev
	for i := 21; i != 0; i = (i + 21) % 55 {
		r.a[i] = next
		next = modDiff(prev, next)
		if seed&1 != 0 {
			seed = 0x40000000 + (seed >> 1)
		} else {
			seed >>= 1
		}
		next = modDiff(next, seed)
		prev = r.a[i]
	}
	r.cycle()
	r.cycle()
	r.cycle()
	r.cycle()
	r.cycle()
	return r
}

// Next returns the next pseudo-random integer in [0, 2^31).
func (r *RNG) Next() int64 {
	if r.a[r.fptr] >= 0 {
		v := r.a[r.fptr]
		r.fptr--
		return v
	}
	return r.cycle()
}

// Unif returns a uniform random integer in [0, m).
// m must be positive and less than 2^31.
func (r *RNG) Unif(m int64) int64 {
	t := uint64(0x80000000) - uint64(0x80000000)%uint64(m)
	var v int64
	for {
		v = r.Next()
		if t > uint64(v) {
			break
		}
	}
	return v % m
}
