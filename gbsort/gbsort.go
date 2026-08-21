//line gbsort.w:63
package gbsort

import "github.com/sjnam/go-sgb/gbflip"

// |Node|는 |LinkSort|가 정렬하는 링크드 리스트의 노드다.
//
//line gbsort.w:74
//line gbsort.w:75
type Node[T any] struct {
	Key  int64    // 정렬 키; 0 이상 $2^{31}$ 미만
	Data T        // 딸린 데이터
	Link *Node[T] // 리스트의 다음 노드
}

// |bucketize|는 리스트 |l|의 노드들을 |keyOf|가 주는 값으로 256개 통에 나눈다.
//
//line gbsort.w:102
//line gbsort.w:103
func bucketize[T any](l *Node[T], keyOf func(*Node[T]) int) (b [256]*Node[T]) {
	for p := l; p != nil; {
		k := keyOf(p)
		q := p.Link
		p.Link = b[k]
		b[k] = p
		p = q
	}
	return
}

// |rebucket|은 통 배열 |src|를 |keyOf|로 다시 256개 통에 나눈다.
// |forward|면 0..255, 아니면 255..0 방향으로 읽는다.
//
//line gbsort.w:121
//line gbsort.w:122
//line gbsort.w:123
func rebucket[T any](
	src *[256]*Node[T],
	forward bool,
	keyOf func(*Node[T]) int,
) (b [256]*Node[T]) {
	spread := func(p *Node[T]) {
		for p != nil {
			k := keyOf(p)
			q := p.Link
			p.Link = b[k]
			b[k] = p
			p = q
		}
	}
	if forward {
		for i := range 256 {
			spread(src[i])
		}
	} else {
		for i := 255; i >= 0; i-- {
			spread(src[i])
		}
	}
	return
}

// |LinkSort|는 헤드 |l|에서 시작하는 리스트를 정렬해, 128개 리스트로 나눈
// 결과를 준다. |r|은 미리 초기화된 난수 스트림이라야 한다.
//
//line gbsort.w:164
//line gbsort.w:165
//line gbsort.w:166
func LinkSort[T any](l *Node[T], r *gbflip.RNG) [128]*Node[T] {
	randKey := func(*Node[T]) int { return int(r.Next() >> 23) }
	byteKey := func(shift uint) func(*Node[T]) int {
		return func(p *Node[T]) int { return int((p.Key >> shift) & 0xff) }
	}
	a := bucketize(l, randKey)           // pass 1: 난수
	b := rebucket(&a, false, randKey)    // pass 2: 난수
	a = rebucket(&b, false, byteKey(0))  // pass 3: 최하위 바이트
	b = rebucket(&a, true, byteKey(8))   // pass 4: 둘째 바이트
	a = rebucket(&b, false, byteKey(16)) // pass 5: 셋째 바이트
	b = rebucket(&a, true, byteKey(24))  // pass 6: 최상위 바이트
	return [128]*Node[T](b[:128])
}
