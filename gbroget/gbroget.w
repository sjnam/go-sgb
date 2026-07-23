% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_roget.w를 Go로 이식한다.
@i ../gbtypes.w

\input kotexgweb
\def\title{GB\_\,ROGET}

@* 들어가며. 이 모듈은 Roget의 유의어 사전에 바탕한 그래프 집안을 짓는
|Roget| 서브루틴을 담는다. 정점은 1879년판 Peter Mark Roget의 {\sl Thesaurus
@^Roget, Peter Mark@>@^Roget, John Lewis@>
of English Words and Phrases\/}(John Lewis Roget 편)에 실린 1022개의 범주에
하나씩 대응한다. 한 범주에서 다른 범주로 가는 호는, Roget이 앞 범주의 낱말과
어구 사이에 뒤 범주를 참조로 걸어 두었거나, 두 범주가 책 속 배치로 직접
관계 지어졌을 때 생긴다. 예컨대 312번 범주(`ascent')에는 224번(`obliquity'),
313번(`descent'), 316번(`leap')으로 가는 호가 있다---Roget이 312에서 224와
316으로 명시적 상호참조를 달았고, 312가 그의 짜임에서 313과 암묵적으로 짝지어져
있었기 때문이다. 이 서브루틴의 쓰임새는 데모 {\sc ROGET\_\,COMPONENTS}에서
볼 수 있다.

@ ``책 속 배치로 직접 관계 지어졌다''는 말은 설명이 좀 필요하다. Roget의
사전은 낱말을 알파벳순으로 늘어놓은 것이 아니라, 관념을 1000개 남짓한 범주로
나누어 갈래지은 분류표다. 그리고 그 배열의 큰 원리 하나가 {\it 대립하는 관념을
나란히 놓는 것\/}이다. 그래서 1번은 `existence'이고 2번은 `inexistence',
5번은 `intrinsicality'이고 6번은 `extrinsicality', 312번은 `ascent'이고
313번은 `descent'이다. 312와 313을 잇는 호는 Roget이 그 자리에 참조를 적어
넣어서가 아니라, 둘이 이렇게 짝을 이루고 있어서 생긴 것이다.

이 짝짓기가 자료에 얼마나 짙게 배어 있는지는 세어 보면 안다. 1022개 범주 가운데
839개가 바로 옆 번호를 참조하고, 서로 마주 참조하는 이웃 쌍이 416개다. 전체
5075개의 호 가운데 번호 차가 1인 것이 887개, 2인 것이 364개다. 그러니
|minDistance|를 3으로 두면 호의 약 4분의 1이 한꺼번에 사라진다. Roget이
이따금 서로 얽힌 범주를 둘이 아니라 셋씩 묶었기 때문에, 그런 덩이 안의
상호참조까지 모두 떨쳐 내려면 2가 아니라 3이 필요하다.

번호 차가 0인 호도 딱 하나 있다. 400번 `pungency'가 자기 자신을 참조한다.
|minDistance|가 1 이상이면 이 자기 고리도 함께 떨어져 나가므로, 거리가 3 미만인
호는 모두 $1+887+364=1252$개다.

@ 이 그래프는 무향이 아니라 {\it 유향\/}이다. Roget의 참조는 한쪽으로만 나 있기
일쑤여서, 312는 316(`leap')을 참조하지만 316이 참조하는 것은 317·322·857이지
312가 아니다. 마찬가지로 312가 가리키는 224(`obliquity')도 312를 되가리키지
않는다. 그래서 {\sc ROGET\_\,COMPONENTS} 데모가 찾는 것이 그냥 연결 성분이
아니라 {\it 강한\/} 연결 성분이다---서로 오갈 수 있는 범주끼리만 한 덩이로
친다.

@ |Roget(n, minDistance, prob, seed, dir)|은 |dir| 디렉터리의 \.{roget.dat}에
담긴 정보로 그래프를 짓는다. 만든 그래프의 정점 수는 $\min(n,1022)$이되,
|n=0|이면 기본값 |n=1022|를 쓴다. |n|이 1022보다 작으면 |n|개의 범주를 무작위로
고르고, 뽑히지 않은 범주로 가는 호는 모두 뺀다. 번호 차가 |minDistance|보다
작은 두 범주 사이의 호도 뺀다---예컨대 |minDistance>1|이면 312와 313 사이의
호는 들어가지 않는다. (Roget은 이따금 서로 얽힌 범주 셋을 한 덩이로 묶었는데,
그런 덩이 안의 상호참조를 모두 피하려면 |minDistance=3|으로 두면 된다.)

|prob>0|이면, 원래 같으면 들어갔을 호를 |prob/65536|의 확률로 물리친다.
성긴 그래프를 얻는 방법이다.

정점은 무작위 차례로 나타난다. 다만 GraphBase의 모든 ``무작위성''은 재현
가능하다---오직 |seed| 값에만 달렸고, |seed|는 0 이상 $2^{31}$ 미만의 정수면
무엇이든 좋다. |Roget(1000,3,32768,50)|을 청하는 사람은 누구나, 어느
컴퓨터에서든 똑같은 그래프를 얻는다. |prob|을 바꾸어도 정점의 선택이나 차례는
그대로이고 호만 달라진다.

@ 문제가 생기면 |Roget|은 |nil| 그래프와 함께 무엇이 잘못됐는지 알리는
|error|(곧 |gbgraph.PanicCode|)를 돌려준다. 이 규약과 자료구조는
{\sc GB\_\,GRAPH}이 정한 대로다. \CEE/ 원본은 |calloc| 실패를 |alloc_fault|로
따로 챙겼지만, \GO/에서는 |make|가 실패를 모르므로 그 경로는 사라졌다.

@c
package gbroget

import (
	"fmt"
	"path/filepath"
	@#
	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
)

const maxN = 1022 // Roget 책의 범주 수
const DataDirectory = "/usr/local/sgb/data"

@<Roget 서브루틴@>

@ |Roget|의 뼈대는 \CEE/ 원본을 그대로 따른다: 난수를 앉히고, 정점 수를
가다듬고, 빈 그래프를 세운 뒤, 어느 범주를 쓸지 정하고, \.{roget.dat}을 읽어
호를 채운다.

@<Roget 서브루틴@>=
func Roget(n, minDistance, prob, seed int64, dir string) (*gbgraph.Graph, error) {
	if dir == "" {
		dir = DataDirectory
	}
	rng := gbflip.New(seed)
	if n == 0 || n > maxN {
		n = maxN
	}
	@<정점 |n|개짜리 그래프를 세운다@>
	@<그래프에 넣을 |n|개 범주를 정한다@>
	@<\.{roget.dat}을 읽어 그래프를 짓는다@>
	return g, nil
}

@* 정점. 새 그래프의 정점은 |n|개다. \CEE/ 원본은 범주 번호를 정점의 유틸리티
필드 |u|(우리의 |U.I|)에 담아 두었는데, 나중에 누군가 그것을 보고 싶어할 수
있기 때문이다. 그 쓰임을 |UtilTypes|의 첫 자리를 \.I로 표시한다.

@<정점 |n|개짜리 그래프를 세운다@>=
g := gbgraph.NewGraph(n)
g.ID = fmt.Sprintf("roget(%d,%d,%d,%d)", n, minDistance, prob, seed)
g.SetUtilType(0, 'I') // |cat_no|는 정수 유틸리티 필드다

@ 첫 번째 할 일은 정점 |n|개를 무작위로 골라 뒤섞는 것이다. |mapping| 표를
꾸려, 정확히 |n|개의 무작위 범주 번호 |k|에 대해서만 |mapping[k]|가 |nil|이
아니게 한다. 그리고 그 |nil| 아닌 값들이 그래프 정점의 무작위 순열이 되게 한다.

|cats|는 아직 쓰이지 않은 범주 번호들의 표다. |pool|은 |mapping| 값이 아직
|nil|인 범주의 수이며, |cats|의 앞쪽 |pool|개가 바로 그 번호들을 (어떤 차례로든)
담는다. \CEE/ 원본이 정점 포인터를 뒤에서 앞으로 훑으며 뽑던 것을 그대로 옮긴다.

이것은 Fisher와 Yates의 뒤섞기를 |n|걸음만 하다 만 것이다. 매 걸음마다 아직
남은 |pool|개 가운데 하나를 고르게 뽑아 정점 하나에 붙이고, 뽑힌 번호가 있던
자리에는 맨 뒤의 번호를 옮겨 담아 구멍을 메운다. 그러니 |cats|의 앞쪽
|pool|개는 언제나 ``아직 안 쓴 번호들''이라는 뜻을 그대로 지킨다. 이렇게 뽑으면
어느 |n|개 부분집합이 뽑힐 확률도 같고, 그것들이 정점에 붙는 차례 또한 고르게
뒤섞인다---그래서 ``정점은 무작위 차례로 나타난다''가 성립한다.

@<그래프에 넣을 |n|개 범주를 정한다@>=
cats := make([]int64, maxN)
mapping := make([]*gbgraph.Vertex, maxN+1)
for i := int64(0); i < maxN; i++ {
	cats[i] = i + 1
}
pool := int64(maxN)
for vi := n - 1; vi >= 0; vi-- {
	j := rng.Unif(pool)
	mapping[cats[j]] = &g.Vertices[vi]
	pool--
	cats[j] = cats[pool]
}

@* 호. \.{roget.dat}의 자료는 범주마다 한 줄씩, 모두 1022줄이다. 예컨대
$$\hbox{\tt 312ascent:224 313 316}$$
은 앞서 설명한 312번 범주의 호들을 적은 것이다. 먼저 범주 번호, 다음에 범주
이름, 콜론, 그리고 다른 범주로 가는 호를 나타내는 번호 0개 이상이 빈칸으로
나뉘어 온다. 호가 너무 많아 한 줄에 안 들어가는 범주는 두 줄에 걸치는데, 첫
줄이 백슬래시로 끝나고 둘째 줄이 빈칸으로 시작한다.

``0개 이상''과 ``두 줄''은 둘 다 실제로 일어나는 일이다. 콜론 뒤가 텅 빈
범주---호가 하나도 없는 범주---가 25개 있고, 백슬래시로 이어지는 줄이 11개
있다. 그래서 \.{roget.dat}의 자료 줄은 1022줄이 아니라 1033줄이며, 아래 읽기
루프의 두 갈래(|j==0|과 |'\\'|)는 장식이 아니다.

@<\.{roget.dat}을 읽어 그래프를 짓는다@>=
f, err := gbio.Open(filepath.Join(dir, "roget.dat"))
if err != nil {
	return nil, gbgraph.EarlyDataFault // \.{roget.dat}을 열 수 없다
}
k := int64(1)
for ; !f.EOF(); k++ {
	@<범주 |k|의 자료를 읽어, 뽑혔으면 그래프에 넣는다@>
}
if f.Close() != nil {
	return nil, gbgraph.LateDataFault // \.{roget.dat}에 탈이 있다
}
if k != maxN+1 {
	return nil, gbgraph.Impossible // |maxN| 값이 틀렸다
}

@ 자료가 뒤틀리지 않았는지 확인한다. 다만 뽑히지 않은 범주는 굳이 살피지 않고
건너뛴다.

@<범주 |k|의 자료를 읽어, 뽑혔으면 그래프에 넣는다@>=
if v := mapping[k]; v != nil { // 이 범주가 뽑혔다
	if f.Number(10) != k {
		return nil, gbgraph.SyntaxError // 동기가 어긋났다
	}
	name := f.String(':')
	if f.Char() != ':' {
		return nil, gbgraph.SyntaxError + 1 // 콜론이 없다
	}
	v.Name = name
	v.U.I = k // 범주 번호를 |cat_no|에 담는다
	@<줄에 적혔으면서 뽑히기도 한 범주마다 |v|에서 호를 낸다@>
} else {
	@<범주 하나의 자료를 건너뛴다@>
}

@ 콜론 뒤의 번호들을 차례로 읽는다. |j==0|이면 이 범주에는 호가 하나도 없다.
백슬래시를 만나면 이어짐 줄로 넘어가고, 줄 끝(개행)을 만나면 이 범주를
끝맺는다. 목표 범주 |j|가 뽑혔고, |k|와의 거리가 |minDistance| 이상이며,
|prob| 관문(있다면)을 통과할 때만 호를 하나 낸다.

@<줄에 적혔으면서 뽑히기도 한 범주마다 |v|에서 호를 낸다@>=
j := f.Number(10)
if j != 0 {
arcs:
	for {
		if j > maxN {
			return nil, gbgraph.SyntaxError + 2 // 범주 번호가 범위 밖이다
		}
		@<범주 |j|가 자격을 갖추면 |v|에서 호를 하나 낸다@>
		switch f.Char() {
		case '\\':
			f.NextLine()
			if f.Char() != ' ' {
				return nil, gbgraph.SyntaxError + 3 // 이어짐 줄은 빈칸으로 시작해야 한다
			}
			j = f.Number(10)
		case ' ':
			j = f.Number(10)
		case '\n':
			break arcs
		default:
			return nil, gbgraph.SyntaxError + 4 // 범주 번호 뒤에 엉뚱한 문자
		}
	}
}
f.NextLine()

@ 여기서 |prob|이 왜 ``65536분의 몇''인지가 드러난다. |Next|는 0 이상
$2^{31}$ 미만의 난수를 고르게 내놓으므로, 이것을 15비트 오른쪽으로 밀면 0 이상
$2^{16}=65536$ 미만의 고른 난수가 된다. 그 값이 |prob| 미만일 때 호를 물리치니,
물리칠 확률이 정확히 |prob|$/65536$이다. |prob|$=32768$이면 반, |prob|$=0$이면
하나도 물리치지 않는다.

|prob| 관문은 \CEE/의 짧은회로 그대로다: 난수는 |mapping[j]|와 거리 조건을
이미 통과하고 |prob|이 0이 아닐 때에만 뽑힌다. 이 호출 시점이 그래프의
재현성을 정하므로, 조건의 순서를 글자 그대로 지킨다---하나라도 앞뒤를 바꾸면
난수를 소비하는 횟수가 달라져 다른 그래프가 나온다.

@<범주 |j|가 자격을 갖추면 |v|에서 호를 하나 낸다@>=
dist := j - k
if dist < 0 {
	dist = -dist
}
if mapping[j] != nil && dist >= minDistance &&
	(prob == 0 || (rng.Next()>>15) >= prob) {
	g.NewArc(v, mapping[j], 1)
}

@ 뽑히지 않은 범주는 자료를 그냥 지나친다. 줄 전체를 개행까지 읽어 버리고,
백슬래시로 끝났으면(이어짐 줄이 있으면) 개행을 한 번 더 넘긴다. \CEE/ 원본은
|gb_string|이 돌려주는 포인터의 두 칸 앞을 들여다보는 ``구식 충동''을 부렸다고
저자가 사과했는데, \GO/에서는 읽어 온 문자열의 마지막 글자만 보면 그만이다.

@<범주 하나의 자료를 건너뛴다@>=
s := f.String('\n')
if len(s) > 0 && s[len(s)-1] == '\\' {
	f.NextLine() // 첫 줄이 백슬래시로 끝났다
}
f.NextLine()

@* 시험. \.{roget.dat}이 |../data|에 있다고 보고, 두 가지를 확인한다. 먼저
|Roget(0,...)|이 기본값 1022개 정점을 내는지 본다.

@(gbroget_test.go@>=
package gbroget

import (
	"reflect"
	"testing"
)

const dataDir = "../data"

func TestRogetDefault(t *testing.T) {
	g, err := Roget(0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != maxN {
		t.Fatalf("N = %d, 원함 %d", g.N, maxN)
	}
	if g.UtilTypes[0] != 'I' {
		t.Errorf("UtilTypes = %q, 첫 자가 I라야 한다", g.UtilTypes)
	}
}

@ 두 번째는 진짜 대조다. {\sc GB\_\,SAMPLE}이 내놓는 |sample.correct|에 따르면
|roget(1000,3,1009,1009)|은 정점 1000개·호 3573개짜리 그래프이고, 그 40번 정점은
``thought''(범주 461)이며 다섯 호가 각각 imagination(527)·memory(517)·
inquiry(471)·inattention(468)·attention(467)로 간다. 정점 차례와 호 차례까지
글자 그대로 맞아떨어져야 |gbflip|의 난수열과 |Roget|의 선택·읽기가 \CEE/와
비트까지 같다는 뜻이다.

@(gbroget_test.go@>=
func TestRogetSample(t *testing.T) {
	g, err := Roget(1000, 3, 1009, 1009, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.ID != "roget(1000,3,1009,1009)" {
		t.Errorf("ID = %q", g.ID)
	}
	if g.N != 1000 || g.M != 3573 {
		t.Fatalf("N=%d M=%d, 원함 N=1000 M=3573", g.N, g.M)
	}
	v := &g.Vertices[40]
	if v.Name != "thought" || v.U.I != 461 {
		t.Fatalf("정점 40 = %q[%d], 원함 thought[461]", v.Name, v.U.I)
	}
	type arc struct {
		name string
		cat  int64
	}
	var got []arc
	for a := range v.AllArcs() {
		got = append(got, arc{a.Tip.Name, a.Tip.U.I})
	}
	want := []arc{
		{"imagination", 527}, {"memory", 517}, {"inquiry", 471},
		{"inattention", 468}, {"attention", 467},
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("정점 40의 호 = %v, 원함 %v", got, want)
	}
}

@ 들어가며에서 센 자료의 성질들도 못박아 둔다. 전체 그래프에는 호가 5075개
있고, 그중 번호 차가 0인 것이 1개(400번 `pungency'의 자기 고리), 1인 것이
887개, 2인 것이 364개다. 그러니 |minDistance=3|이면 호가 $5075-1252=3823$개만
남아야 한다. 호가 하나도 없는 범주가 25개라는 것도 함께 본다---그 25개가
|j==0| 갈래를 밟는다.

@(gbroget_test.go@>=
func TestArcCounts(t *testing.T) {
	full, err := Roget(0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if full.M != 5075 {
		t.Errorf("M = %d, 원함 5075", full.M)
	}
	@<거리별 호 수를 세어 대조한다@>
	far, err := Roget(0, 3, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if far.M != 5075-1252 {
		t.Errorf("minDistance=3일 때 M = %d, 원함 %d", far.M, 5075-1252)
	}
}

@ 정점의 |U.I|가 범주 번호이므로, 호 양 끝의 번호 차를 곧바로 잴 수 있다.

@<거리별 호 수를 세어 대조한다@>=
var d0, d1, d2, isolated int64
for i := int64(0); i < full.N; i++ {
	v := &full.Vertices[i]
	if v.Arcs == nil {
		isolated++
	}
	for a := range v.AllArcs() {
		switch d := v.U.I - a.Tip.U.I; {
		case d == 0:
			d0++
			if v.Name != "pungency" {
				t.Errorf("자기 고리가 %q에 있다", v.Name)
			}
		case d == 1 || d == -1:
			d1++
		case d == 2 || d == -2:
			d2++
		}
	}
}
if d0 != 1 || d1 != 887 || d2 != 364 {
	t.Errorf("거리 0·1·2인 호 = %d·%d·%d, 원함 1·887·364", d0, d1, d2)
}
if isolated != 25 {
	t.Errorf("호가 없는 범주 = %d, 원함 25", isolated)
}

@* 찾아보기.
