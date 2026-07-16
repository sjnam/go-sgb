% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_roget.w를 Go로 이식한다.
@i ../types.w

\input kotexgweb
\def\title{GB\_\,ROGET}

@* 들어가며. 이 모듈은 Roget의 유의어 사전에 바탕한 그래프 집안을 짓는
|Roget| 서브루틴을 담는다. 정점은 1879년판 Peter Mark Roget의 {\sl Thesaurus
of English Words and Phrases\/}(John Lewis Roget 편)에 실린 1022개의 범주에
하나씩 대응한다. 한 범주에서 다른 범주로 가는 호는, Roget이 앞 범주의 낱말과
어구 사이에 뒤 범주를 참조로 걸어 두었거나, 두 범주가 책 속 배치로 직접
관계 지어졌을 때 생긴다. 예컨대 312번 범주(`ascent')에는 224번(`obliquity'),
313번(`descent'), 316번(`leap')으로 가는 호가 있다---Roget이 312에서 224와
316으로 명시적 상호참조를 달았고, 312가 그의 짜임에서 313과 암묵적으로 짝지어져
있었기 때문이다. 이 서브루틴의 쓰임새는 데모 {\sc ROGET\_\,COMPONENTS}에서
볼 수 있다.

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
가능하다---오직 |seed| 값에만 달렸다. |Roget(1000,3,32768,50)|을 청하는 사람은
누구나, 어느 컴퓨터에서든 똑같은 그래프를 얻는다. |prob|을 바꾸어도 정점의
선택이나 차례는 그대로이고 호만 달라진다.

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

@ |prob| 관문은 \CEE/의 짧은회로 그대로다: |gb_next_rand|은 |mapping[j]|와
거리 조건을 이미 통과하고 |prob|이 0이 아닐 때에만 뽑힌다. 이 호출 시점이
그래프의 재현성을 정하므로, 순서를 글자 그대로 지킨다.

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

@* 찾아보기.
