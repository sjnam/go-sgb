package gbflip

import "testing"

// TestFlip mirrors the test_flip.c validation from gb_flip.w:
//
//	gb_init_rand(-314159) → gb_next_rand() == 119318998
//	skip 133 values      → gb_unif_rand(0x55555555) == 748103812
func TestFlip(t *testing.T) {
	rng := New(-314159)

	if got := rng.Next(); got != 119318998 {
		t.Fatalf("first Next: got %d, want 119318998", got)
	}

	for j := 1; j <= 133; j++ {
		rng.Next()
	}

	if got := rng.Unif(0x55555555); got != 748103812 {
		t.Fatalf("Unif: got %d, want 748103812", got)
	}
}

// TestInitIntermediate checks the intermediate values documented in gb_flip.w.
// These are values set during the initialization loop, captured before the
// five warmup cycle() calls overwrite the array.
func TestInitIntermediate(t *testing.T) {
	// Replicate only the setup portion of New(-314159), without warmup.
	seed := int64(-314159)
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

	cases := []struct {
		idx  int
		want int64
	}{
		{42, 2147326568},
		{8, 1073977445},
		{29, 536517481},
	}
	for _, c := range cases {
		if got := r.a[c.idx]; got != c.want {
			t.Errorf("a[%d] = %d, want %d", c.idx, got, c.want)
		}
	}
}
