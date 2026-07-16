% 이 문서는 Stanford GraphBase의 gb_sort.w((c) 1993 Stanford University)를
% 한글 GWEB(Go)로 옮긴 것으로, Stanford GraphBase의 일부가 아니다.
@i ../types.w

\input kotexgweb
\def\title{GB\_\,SORT}

@* 들어가며. 이 짧은 GraphBase 모듈은 다른 여러 프로그램이 쓰는 소박한
도우미 |LinkSort| 하나를 내놓는다. 원본의 이름은 |gb_linksort|였다.

GraphBase 데이터에서 얻는 그래프는 대개 매개변수로 조절된다. 같은 밑천에서
다른 그래프를 손쉽게 뽑아내려는 것이다. 흔한 방식은 어떤 ``무게(weight)''를
기준으로 ``가장 무거운'' 정점들을 고르거나, 정점을 무작위로 표집하는
것이다. 예컨대 원본의 |words| 생성기는 영어에서 가장 흔한 다섯 글자 단어 |n|개로
그래프를 만드는데, 흔한 정도는 주어진 무게 벡터가 정한다. 무게가 같은
단어가 여럿이면 그중에서 무작위로 고르고 싶다 — 무게 벡터가 모든 단어에
같은 무게를 준다면 완전히 무작위한 단어 선택을 얻는다는 뜻이기도 하다.

|LinkSort|가 바로 이 일에 맞춤한 연장이다. 노드들의 링크드 리스트를 받아
그 |Link| 필드들을 뒤섞어서, 노드를 무게의 감소 순서로 읽을 수 있게 하되
무게가 같은 노드끼리는 무작위 순서로 나타나게 한다. {\sl 주의: 난수
스트림은 |LinkSort|에 넘기기 전에 미리 초기화되어 있어야 한다.} \CEE/
원본은 {\sc GB\_\,FLIP}의 전역 스트림을 썼지만, 우리는 |*gbflip.RNG|를
매개변수로 받는다.

@ 원본은 노드를 임의의 구조체 타입으로 두었다. 첫 필드가 |long key|,
둘째가 자기 타입 포인터 |link|이기만 하면, 그 뒤에 어떤 필드가 오든
상관없이 정렬했다 — 포인터를 {\bf node}|*|로 캐스팅하는 \CEE/의 오랜 재주다.
\GO/에는 그런 캐스팅이 없으므로, 노드를 제네릭 타입 |Node[T]|로 만들어
딸린 데이터를 |Data| 필드에 담는다. 이러면 캐스팅도, typed-|nil| 함정도
없다.

정렬은 |Key| 필드로 하며, 키는 저마다 $2^{31}$보다 작은 음이 아닌
정수라야 한다.

정렬이 끝나면 데이터는 128개의 링크드 리스트 |s[127]|, |s[126]|, \dots,
|s[0]|에 담겨 나온다. 무게의 감소 순서로 훑으려면 다음처럼 읽으면 된다:
$$\vbox{\halign{#\hfil\cr
|for j := 127; j >= 0; j-- {|\cr
\quad|for p := s[j]; p != nil; p = p.Link {|\cr
\qquad|lookAt(p)|\cr
\quad|}|\cr
|}|\cr}}$$
키가 $j\cdot2^{24}\le|key|<(j+1)\cdot2^{24}$ 범위인 노드는 모두
리스트 |s[j]|에 들어간다. 따라서 키가 모두 $2^{24}$보다 작으면 결과는
전부 |s[0]| 하나에 모인다.
@c
package gbsort

import "github.com/sjnam/go-sgb/gbflip"

@<노드 타입@>
@<정렬 루틴@>

@ |Node|의 |Data| 필드가 원본의 ``뒤따르는 임의의 필드들''을 대신한다.
원본의 |words| 생성기라면 |Data|에 다섯 글자 단어를 담을 것이다.

@<노드 타입@>=
// |Node|는 |LinkSort|가 정렬하는 링크드 리스트의 노드다.
type Node[T any] struct {
	Key  int64    // 정렬 키; 0 이상 $2^{31}$ 미만
	Data T        // 딸린 데이터
	Link *Node[T] // 리스트의 다음 노드
}

@* 기수 정렬. 기수 256의 기수 정렬(radix sort) 여섯 번이면 원하는 바를
꽤 빠르게 이룬다({\sl Sorting and Searching\/}의 알고리즘 5.2.5R을 보라).
뒤의 네 번은 키의 네 바이트를 최하위부터 훑는 예사로운 최하위 자리
우선(LSD) 기수 정렬이고, 앞의 두 번은 키 대신 난수를 본다. 이렇게 하면
키가 사실상 늘어나서, 키가 같은 노드들이 그런대로 무작위한 순서로 놓인다.

노드는 두 벌의 리스트 배열 사이를 오간다. \CEE/ 원본은 하나는 전역
|gb_sorted|, 하나는 내부 |alt_sorted|였지만, 우리에겐 지역 배열 둘이면
된다. 한 배열에서 읽어 다른 배열의 256개 통에 다시 나누는 일을 여섯 번
되풀이한다.

먼저 리스트에서 통으로 나누는 기본 도우미다. 각 노드를 키 함수 |keyOf|가
주는 여덟 비트 값의 통에 앞쪽으로 끼워 넣는다(prepend). 원본은 이 재분배를
여섯 번 펼쳐 썼지만, 되풀이되는 논리이므로 함수로 묶는다.

@<정렬 루틴@>=
// |bucketize|는 리스트 |l|의 노드들을 |keyOf|가 주는 값으로 256개 통에 나눈다.
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

@ 둘째 pass부터는 소스가 하나의 리스트가 아니라 256개 통이므로, 통들을
순서대로 훑으며 다시 나눈다. 여기에 한 가지 미묘함이 있다: 각 pass는
리스트의 순서를 뒤집으므로, 통을 어느 방향으로 읽느냐가 최종 순서를
좌우한다. |forward|면 통을 0에서 255로, 아니면 255에서 0으로 읽는다.
원본의 주석대로, ``까다롭지만 잘 된다.''

@<정렬 루틴@>=
// |rebucket|은 통 배열 |src|를 |keyOf|로 다시 256개 통에 나눈다.
// |forward|면 0..255, 아니면 255..0 방향으로 읽는다.
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

@ 이제 여섯 번의 pass를 순서대로 엮는다. 앞의 두 pass는 난수의 상위
여덟 비트(31비트 중 위쪽)를 키로 쓰고, 뒤의 네 pass는 키의 바이트를
최하위부터 뽑는다. 통을 읽는 방향이 pass마다 다른 데 유의하라 —
넷째와 여섯째만 앞으로, 나머지는 뒤로 읽는다. 이 방향의 춤이 여섯 번의
순서 반전을 상쇄해, 결국 무거운 노드가 앞선 통의 앞자리에 놓이게 한다.

마지막 pass에서 뽑는 최상위 바이트는 0과 127 사이다. 키가 음이 아니고
$2^{31}$보다 작다고 가정했기 때문이다. 그래서 결과는 128개 통이면
충분하다.

@<정렬 루틴@>=
// |LinkSort|는 헤드 |l|에서 시작하는 리스트를 정렬해, 128개 리스트로 나눈
// 결과를 준다. |r|은 미리 초기화된 난수 스트림이라야 한다.
func LinkSort[T any](l *Node[T], r *gbflip.RNG) [128]*Node[T] {
	randKey := func(*Node[T]) int { return int(r.Next() >> 23) }
	byteKey := func(shift uint) func(*Node[T]) int {
		return func(p *Node[T]) int { return int((p.Key >> shift) & 0xff) }
	}
	a := bucketize(l, randKey)               // pass 1: 난수
	b := rebucket(&a, false, randKey)        // pass 2: 난수
	a = rebucket(&b, false, byteKey(0))      // pass 3: 최하위 바이트
	b = rebucket(&a, true, byteKey(8))       // pass 4: 둘째 바이트
	a = rebucket(&b, false, byteKey(16))     // pass 5: 셋째 바이트
	b = rebucket(&a, true, byteKey(24))      // pass 6: 최상위 바이트
	return [128]*Node[T](b[:128])
}

@* 시험. 원본에는 시험 프로그램이 딸려 있지 않았지만, 정렬은 눈으로
믿기 어려운 물건이니 몇 가지를 확인해 둔다. 무작위 키를 가진 노드
여럿을 정렬해서, 통을 |j=127|부터 |0|까지 훑으며 나오는 키가 감소
순서인지, 그리고 넣은 노드가 하나도 잃거나 겹치지 않고 모두 나오는지를
본다.

@(gbsort_test.go@>=
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

@ @(gbsort_test.go@>=
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

@ 통 |j|에는 키가 $[j\cdot2^{24},(j+1)\cdot2^{24})$ 범위인 노드만 들어가야
한다. 큰 키로 이 버킷 배정을 확인하고, 겸사겸사 노드 보존도 다시 센다.

@(gbsort_test.go@>=
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

@ 마지막으로, 무게가 모두 같으면 순서는 오로지 난수가 정한다. 같은
스트림을 두 번 세우면 같은 뒤섞임이 나와야 하고(재현성), 다른 스트림이면
대개 다른 뒤섞임이 나와야 한다. 이 성질이 |words| 같은 생성기의 무작위
표집을 떠받친다.

@(gbsort_test.go@>=
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

@* 찾아보기.
