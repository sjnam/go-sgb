//line gbflip.w:34
package gbflip

//line gbflip.w:57
type RNG struct {
	a    [56]int64 // 유사난수 값들; |a[0]|은 파수꾼 $-1$
	fptr int       // 다음에 내놓을 |a|의 위치
}

//line gbflip.w:74
func (r *RNG) Next() int64 {
	if r.a[r.fptr] >= 0 {
		v := r.a[r.fptr]
		r.fptr--
		return v
	}
	return r.cycle()
}

//line gbflip.w:97
func modDiff(x, y int64) int64 { return (x - y) & 0x7fffffff } // $2^{31}$을 법으로 한 차

func (r *RNG) cycle() int64 {
	i := 1
	for j := 32; j <= 55; i, j = i+1, j+1 {
		r.a[i] = modDiff(r.a[i], r.a[j])
	}
	for j := 1; i <= 55; i, j = i+1, j+1 {
		r.a[i] = modDiff(r.a[i], r.a[j])
	}
	r.fptr = 54
	return r.a[55]
}

//line gbflip.w:122
func New(seed int64) *RNG {
	r := new(RNG)
	r.a[0] = -1 // 파수꾼
	prev, next := seed, int64(1)
	seed = modDiff(prev, 0) // 부호를 벗긴다
	prev = seed
	r.a[55] = prev
	for i := 21; i != 0; i = (i + 21) % 55 {
		r.a[i] = next

//line gbflip.w:148
		next = modDiff(prev, next)
		if seed&1 != 0 {
			seed = 0x40000000 + (seed >> 1)
		} else {
			seed >>= 1 // 오른쪽으로 한 칸 순환 이동
		}
		next = modDiff(next, seed)

//line gbflip.w:132
		prev = r.a[i]
	}

//line gbflip.w:180
	for range 5 {
		r.cycle()
	}

//line gbflip.w:135
	return r
}

//line gbflip.w:206
const twoToThe31 = int64(1) << 31

func (r *RNG) Unif(m int64) int64 {
	t := twoToThe31 - twoToThe31%m
	x := r.Next()
	for x >= t {
		x = r.Next()
	}
	return x % m
}
