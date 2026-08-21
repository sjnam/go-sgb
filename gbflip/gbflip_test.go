//line gbflip.w:227
package gbflip

import "testing"

func TestFlip(t *testing.T) {
	r := New(-314159)
	if v := r.Next(); v != 119318998 {
		t.Fatalf("첫 시도에서 실패! (%d)", v)
	}
	for range 133 {
		r.Next()
	}
	if v := r.Unif(0x55555555); v != 748103812 {
		t.Fatalf("두 번째 시도에서 실패! (%d)", v)
	}
}

//line gbflip.w:249
func TestIndependentStreams(t *testing.T) {
	r1, r2 := New(-314159), New(271828)
	want := New(-314159)
	for i := range 1000 {
		r2.Next()
		if v, w := r1.Next(), want.Next(); v != w {
			t.Fatalf("%d번째에서 스트림이 엇갈렸다: %d != %d", i, v, w)
		}
	}
}

//line gbflip.w:265
func TestUnifRejectionTrace(t *testing.T) {
	const m = int64(0x55555555)
	if thr := twoToThe31 - twoToThe31%m; thr != m {
		t.Fatalf("t = %d, 원함 %d", thr, m)
	}
	r := New(-314159)
	r.Next()
	for range 133 {
		r.Next()
	}

//line gbflip.w:279
	for _, want := range []int64{2081307921, 1621414801, 1469108743} {
		if v := r.Next(); v != want {
			t.Fatalf("물리쳐야 할 값 %d, 얻음 %d", want, v)
		}
	}
	if v := r.Next(); v != 748103812 {
		t.Fatalf("받아들일 값 748103812, 얻음 %d", v)
	}

//line gbflip.w:276
}
