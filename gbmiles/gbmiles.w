% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_miles.w를 Go로 이식한다.
@i ../types.w

\input kotexgweb
\def\title{GB\_\,MILES}

@* 들어가며. 이 모듈은 |Miles| 서브루틴을 담는다. 북아메리카 도시들 사이의
고속도로 거리 자료를 바탕으로 무향 그래프의 한 갈래를 짓는다. 쓰임새는
{\sc MILES\_SPAN}과 {\sc GB\_PLANE} 데모에서 볼 수 있다.

|Miles(n, northWeight, westWeight, popWeight, maxDistance, maxDegree, seed, dir)|은
\.{miles.dat}의 정보로 그래프를 짓는다. 각 정점은 1949년판 Rand McNally사의
{\sl Standard Highway Mileage Guide\/}에서 이름이 `Ravenna, Ohio' 이상인 128개
도시 가운데 하나에 대응한다. 간선의 길이는 두 도시 사이의 거리(마일)다. 이
거리들은 삼각 부등식을 지키도록 손보아졌다 --- 곧 |u|에서 |v|를 거쳐 |w|로
가는 거리가 |u|에서 |w|로 곧장 가는 거리 이상이다.

그래프는 $\min(n,128)$개의 정점을 가지며, |n=0|이면 기본값 128을 쓴다. |n|이
128보다 작으면, 각 도시에 무게를 매겨 가장 무거운 |n|개를 고른다(같은 무게는
난수로 가른다). 무게는
$$|northWeight|\cdot|lat|+|westWeight|\cdot|lon|+|popWeight|\cdot|pop|$$
로 셈하는데, |lat|은 위도, |lon|은 경도(둘 다 100분의 1도 단위), |pop|은 1980년
인구다. 무게 계수는 $\vert|northWeight|\vert\le100000$,
$\vert|westWeight|\vert\le100000$, $\vert|popWeight|\vert\le100$을 지켜야 한다.

|maxDistance|가 0이 아니면 그보다 먼 간선은 빠지고, |maxDegree|가 0이 아니면
각 정점은 가장 짧은 간선 |maxDegree|개까지만 갖는다. 둘 다 특별한 값이
아니면 그래프는 ``완전''(complete)하다 --- 모든 도시 쌍 사이에 간선이 있다.

@ 예: |Miles(100, 0, 0, 1, 0, 0, 0, dir)|은 자료의 가장 인구 많은 100개
도시로 완전 그래프를 짓는다. 이 기준의 승자는 인구 875,538의 San Diego이고,
San Antonio(786,023), San Francisco(678,974), Washington D.C.(638,432)가
뒤를 잇는다.

서부 도시들을 얻으려면 $|Miles|(n,0,1,0,\ldots)$, 북동부는 $(n,1,-1,0,\ldots)$
꼴로 부른다. |Miles(n,a,b,c,0,1,0,dir)|처럼 |maxDegree=1|이면, 두 도시가
서로에게 가장 가까운 이웃일 때에만 간선이 생긴다. |seed|가 다르면 다른
무작위 선택을 얻되, 같은 매개변수로는 어느 컴퓨터에서나 같은 결과를 얻는다.

@ 프로그램의 뼈대다. \CEE/ 원본의 전역 |gb_flip| 스트림 대신, |Miles|는
씨앗으로 스트림을 하나 열어 쓴다. 다만 {\sc GB\_PLANE}의 |plane_miles|처럼
스트림을 이어 쓰려는 호출자를 위해, 난수 생성기를 직접 받는 |MilesRNG| 변형도
함께 내놓는다. |Miles|는 그저 |MilesRNG|를 |New(seed)|로 감싼 것이다.
@d DataInputDirectory
@c
package gbmiles

import (
	"fmt"
	"path/filepath"
	@#
	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/gbsort"
)

const DataInputDirectory = "/usr/local/sgb/data"

@<상수와 자료 구조@>@;
@<도시 자료를 읽는 함수@>@;
@<그래프를 짓는 |MilesRNG|@>@;

// |Miles|는 씨앗 |seed|로 난수 스트림을 열어 도시 그래프를 짓는다.
func Miles(n, northWeight, westWeight, popWeight,
	maxDistance, maxDegree, seed int64, dir string) (*gbgraph.Graph, error) {
	return MilesRNG(n, northWeight, westWeight, popWeight,
		maxDistance, maxDegree, seed, gbflip.New(seed), dir)
}

@ 도시 하나의 자료를 담는 것이 |cityInfo|다. 이것을 |gbsort.Node|의 딸림
데이터로 실어, 무게순 정렬에 부친다. 상수들은 \.{miles.dat}의 실제 자료에서
뽑은 것으로, 이 루틴은 완전히 일반적일 필요가 없어 이렇게 못 박아 둔다.
|maxN|은 도시의 최대·기본 수다.

@<상수와 자료 구조@>=
const maxN = 128 // 도시의 최대이자 기본 수

const (
	minLat = 2672   // 자료 항목들의 빠듯한 경계
	maxLat = 5042
	minLon = 7180
	maxLon = 12312
	minPop = 2521
	maxPop = 875538
)

type cityInfo struct {
	kk       int64  // 원래 데이터베이스에서의 도시 번호(0..127)
	lat, lon int64  // 위도, 경도
	pop      int64  // 인구
	name     string // |"City Name, ST"|
}

@ 이제 본론이다. 매개변수를 다듬고, 그래프를 마련하고, 자료를 읽고, 쓸 도시를
고르고, 간선을 넣는다. 표식 문자열과 유틸리티 쓰임새를 짓는데, |UtilTypes|가
|"ZZIIIIZZZZZZZZ"|인 것은 정점의 |W|에 인구, |X|에 |x| 좌표, |Y|에 |y| 좌표,
|Z|에 도시 번호를 정수로 둔다는 뜻이다.

@<그래프를 짓는 |MilesRNG|@>=
// |MilesRNG|는 |Miles|와 같되 난수 생성기 |rng|를 직접 받는다.
func MilesRNG(n, northWeight, westWeight, popWeight, maxDistance, maxDegree, seed int64,
	rng *gbflip.RNG, dir string) (*gbgraph.Graph, error) {
	@<매개변수가 올바른지 확인한다@>@;
	g := gbgraph.NewGraph(n)
	g.ID = fmt.Sprintf("miles(%d,%d,%d,%d,%d,%d,%d)",
		n, northWeight, westWeight, popWeight, maxDistance, maxDegree, seed)
	g.UtilTypes = "ZZIIIIZZZZZZZZ"
	nodes := make([]gbsort.Node[cityInfo], maxN)
	dist := make([]int64, maxN*maxN)
	@<\.{miles.dat}을 읽어 도시 무게를 셈한다@>@;
	@<쓸 |n|개 도시를 정한다@>@;
	@<알맞은 간선을 그래프에 넣는다@>@;
	return g, nil
}

@ 매개변수 다듬기와 검증이다. |n|은 1과 128 사이로, |maxDegree|는 0이거나
|n| 이상이면 |n-1|로 맞춘다. 무게 계수의 크기가 한도를 넘으면 |BadSpecs|다.
표식 문자열은 이렇게 다듬은 뒤의 |n|과 |maxDegree|를 담는다.

@<매개변수가 올바른지 확인한다@>=
if dir == "" {
	dir = DataInputDirectory
}
if n == 0 || n > maxN {
	n = maxN
}
if maxDegree == 0 || maxDegree >= n {
	maxDegree = n - 1
}
if northWeight > 100000 || westWeight > 100000 || popWeight > 100 ||
	northWeight < -100000 || westWeight < -100000 || popWeight < -100 {
	return nil, gbgraph.BadSpecs // 무게 하나의 크기가 너무 크다
}

@* 정점. 자료를 읽으며 도시마다 이름·위도·경도·인구·무게를 담은 노드를
엮는다. \.{miles.dat}은 128개 도시가 알파벳 역순으로 놓인 묶음들로 이루어지며,
각 묶음은
$$\vbox{\halign{\.{#}\hfil\cr
City Name, ST[lat,lon]pop\cr
d1 d2 d3 d4 d5 d6 \dots\ (여러 줄일 수도)\cr}}$$
꼴이다. \.{d1}, \.{d2}, \dots\ 는 앞서 이름난 도시들까지의 거리를 역순으로
적은 것으로, 빈칸이나 줄바꿈으로 나뉜다. 예컨대 Worcester의 거리 줄
\.{2964 1520 604}에서, Worcester에서 Yakima까지가 2964마일, Youngstown까지가
604마일임을 안다.

파일을 열고, 도시들을 읽고, 닫는다. 여는 데 실패하면 |EarlyDataFault|,
닫는 데 실패하면 |LateDataFault|다.

@<\.{miles.dat}을 읽어 도시 무게를 셈한다@>=
f, err := gbio.Open(filepath.Join(dir, "miles.dat"))
if err != nil {
	return nil, gbgraph.EarlyDataFault
}
err = readCities(f, nodes, dist, northWeight, westWeight, popWeight)
if cerr := f.Close(); err == nil && cerr != nil {
	err = gbgraph.LateDataFault
}
if err != nil {
	return nil, err
}

@ |readCities|는 도시들을 |k=127|부터 0까지 역순으로 읽는다(파일 차례가 그렇다).
도시 |k|를 |nodes[k]|에 담고, |nodes[k].Link|을 |nodes[k-1]|로 이어 정렬용
리스트를 엮는다. 조기 반환은 구문 오류를 위로 알리려는 것이라 함수로 둔다.

@<도시 자료를 읽는 함수@>=
func readCities(f *gbio.File, nodes []gbsort.Node[cityInfo], dist []int64,
	northWeight, westWeight, popWeight int64) error {
	for k := int64(maxN - 1); k >= 0; k-- {
		@<도시 |k|의 자료를 읽어 저장한다@>@;
	}
	return nil
}

@ 이름을 |'['| 직전까지 읽고, 위도·경도·인구를 차례로 읽으며 경계를 벗어나면
구문 오류다. 무게는 \.{gb\_words}에서처럼 음수가 아니도록 $2^{30}$을 더한
정렬 키로 둔다. 매개변수의 한도가 그 키를 0과 $2^{31}$ 사이로 보장한다.

@<도시 |k|의 자료를 읽어 저장한다@>=
p := &nodes[k]
p.Data.kk = k
if k > 0 {
	p.Link = &nodes[k-1]
}
p.Data.name = f.String('[')
if f.Char() != '[' {
	return gbgraph.SyntaxError // \.{miles.dat}과 어긋났다
}
p.Data.lat = f.Number(10)
if p.Data.lat < minLat || p.Data.lat > maxLat || f.Char() != ',' {
	return gbgraph.SyntaxError + 1 // 위도 자료가 망가졌다
}
p.Data.lon = f.Number(10)
if p.Data.lon < minLon || p.Data.lon > maxLon || f.Char() != ']' {
	return gbgraph.SyntaxError + 2 // 경도 자료가 망가졌다
}
p.Data.pop = f.Number(10)
if p.Data.pop < minPop || p.Data.pop > maxPop {
	return gbgraph.SyntaxError + 3 // 인구 자료가 망가졌다
}
p.Key = northWeight*(p.Data.lat-minLat) + westWeight*(p.Data.lon-minLon) +
	popWeight*(p.Data.pop-minPop) + (1 << 30)
@<도시 |k|의 거리 자료를 읽는다@>@;
f.NextLine()

@ 도시 |k|의 거리 줄에서 앞서 읽은 도시들(|k+1|부터 127까지)까지의 거리를
읽어, 대칭 거리 행렬 |dist|에 넣는다. 다음 글자가 빈칸이 아니면 줄이 바뀐
것이니 다음 줄로 넘어간다.

@<도시 |k|의 거리 자료를 읽는다@>=
for j := k + 1; j < maxN; j++ {
	if f.Char() != ' ' {
		f.NextLine()
	}
	dd := f.Number(10)
	dist[maxN*j+k] = dd
	dist[maxN*k+j] = dd
}

@ 노드가 다 갖춰지면 |gbsort.LinkSort|로 무게순 정렬한다. 128개 리스트에서
무게가 큰 차례로 도시를 꺼내 앞 |n|개를 정점으로 삼고, 못 뽑힌 도시는 인구를
0으로 두어 나중에 간선에서 빠지게 한다.

@<쓸 |n|개 도시를 정한다@>=
sorted := gbsort.LinkSort(&nodes[maxN-1], rng)
var filled int64
for j := 127; j >= 0; j-- {
	for p := sorted[j]; p != nil; p = p.Link {
		if filled < n {
			@<도시 |p|를 그래프에 더한다@>@;
			filled++
		} else {
			p.Data.pop = 0 // 이 도시는 안 쓴다
		}
	}
}

@ 정점의 |x|·|y| 좌표는 위도·경도를 소박하게 선형 변환한 것으로, 기하 계산에
쓸 수 있다($0\le x\le5132$, $0\le y\le3555$). |x|는 경도의 여값,
|y|는 위도의 1.5배다. |z|에는 도시 번호를, |w|에는 인구를 둔다.

@<도시 |p|를 그래프에 더한다@>=
v := &g.Vertices[filled]
v.X.I = maxLon - p.Data.lon // |x| 좌표는 경도의 여값
y := p.Data.lat - minLat
v.Y.I = y + (y >> 1) // |y| 좌표는 위도의 1.5배
v.Z.I = p.Data.kk
v.W.I = p.Data.pop
v.Name = p.Data.name

@* 간선. 넣지 않을 간선은 거리 행렬 항목의 부호를 음으로 바꿔 쳐낸다.
|maxDistance|나 |maxDegree|가 특별한 값일 때만 쳐낼 일이 생긴다. 그런 다음
모든 도시 쌍을 훑어, 양방향 거리가 모두 양수인 쌍에만 간선을 놓는다.

@<알맞은 간선을 그래프에 넣는다@>=
if maxDistance > 0 || maxDegree > 0 {
	@<원치 않는 간선을 부호를 바꿔 쳐낸다@>@;
}
for ui := int64(0); ui < n; ui++ {
	u := &g.Vertices[ui]
	j := u.Z.I
	for vi := ui + 1; vi < n; vi++ {
		v := &g.Vertices[vi]
		k := v.Z.I
		if dist[maxN*j+k] > 0 && dist[maxN*k+j] > 0 {
			g.NewEdge(u, v, dist[maxN*j+k])
		}
	}
}

@ 쳐내기다. 쓰이는(인구가 0이 아닌) 도시마다, 그 도시에서 나가는 원치 않는
간선을 지운다.

@<원치 않는 간선을 부호를 바꿔 쳐낸다@>=
pruneDeg := maxDegree
if pruneDeg == 0 {
	pruneDeg = maxN
}
pruneDist := maxDistance
if pruneDist == 0 {
	pruneDist = 30000
}
for i := int64(0); i < maxN; i++ {
	p := &nodes[i]
	if p.Data.pop != 0 {
		@<도시 |p|의 원치 않는 간선을 지운다@>@;
	}
}

@ 여기서 노드의 키 필드를 되쓴다 --- 무게 대신 여거리(|pruneDist|에서 거리를
뺀 값)를 넣고, 정렬 루틴이 이음 필드를 바꾸게 둔다. 인구 등 다른 필드는
그대로다. 저자도 이게 좀 얍삽한 줄 알지만, 안 될 게 뭐람? |pruneDist|보다 먼
간선은 곧장 부호를 바꾸고, 나머지는 리스트로 엮어 정렬한다. 정렬 뒤 |sorted[0]|
에는 살아남은 간선이 가까운 차례로 놓이니, |pruneDeg|번째를 넘는 것들의 부호를
바꾼다.

@<도시 |p|의 원치 않는 간선을 지운다@>=
k := p.Data.kk
var s *gbsort.Node[cityInfo]
for jj := int64(0); jj < maxN; jj++ {
	q := &nodes[jj]
	if q.Data.pop == 0 || q == p {
		continue
	}
	dd := dist[maxN*k+q.Data.kk] // |p|에서 |q|까지의 거리
	if dd > pruneDist {
		dist[maxN*k+q.Data.kk] = -dd
	} else {
		q.Key = pruneDist - dd
		q.Link = s
		s = q
	}
}
sorted := gbsort.LinkSort(s, rng)
var cnt int64
for q := sorted[0]; q != nil; q = q.Link {
	cnt++
	if cnt > pruneDeg {
		dist[maxN*k+q.Data.kk] = -dist[maxN*k+q.Data.kk]
	}
}

@* 시험. \.{miles.dat}이 |../data|에 있다고 보고 그래프를 지어 Knuth가 발표한
값들과 대조한다. 인구로 무게를 매기면 San Diego가 으뜸이고, Worcester에서
Youngstown까지는 604마일이다.

@(gbmiles_test.go@>=
package gbmiles

import (
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
)

const dataDir = "../data"

@<인구 순위 시험@>@;
@<완전 그래프 시험@>@;
@<거리 시험@>@;
@<최근접 이웃 시험@>@;
@<무게 검증 오류 시험@>@;

@ |Miles(100,0,0,1,0,0,0)|은 인구가 많은 100개 도시의 완전 그래프다. 무게를
인구로만 매기므로 정점은 인구 내림차순이다. 표식 문자열의 |maxDegree|는
0에서 |n-1=99|로 다듬어진 값이라야 한다.

@<인구 순위 시험@>=
func TestPopulationOrder(t *testing.T) {
	g, err := Miles(100, 0, 0, 1, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.ID != "miles(100,0,0,1,0,99,0)" {
		t.Errorf("ID = %q", g.ID)
	}
	if g.UtilTypes != "ZZIIIIZZZZZZZZ" {
		t.Errorf("UtilTypes = %q", g.UtilTypes)
	}
	want := []struct {
		name string
		pop  int64
	}{
		{"San Diego, CA", 875538},
		{"San Antonio, TX", 786023},
		{"San Francisco, CA", 678974},
		{"Washington, DC", 638432},
	}
	for i, w := range want {
		if g.Vertices[i].Name != w.name || g.Vertices[i].W.I != w.pop {
			t.Errorf("정점 %d = %q(%d), 원함 %q(%d)",
				i, g.Vertices[i].Name, g.Vertices[i].W.I, w.name, w.pop)
		}
	}
}

@ |maxDistance=maxDegree=0|이면 그래프는 완전하다. 128개 도시면 간선이
${128 \choose 2}=8128$개다. 모든 간선의 길이는 양수이고, 짝 호는 길이가 같다.

@<완전 그래프 시험@>=
func TestCompleteGraph(t *testing.T) {
	g, err := Miles(0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 128 {
		t.Fatalf("정점 수 = %d, 원함 128", g.N)
	}
	if g.M != 2*8128 {
		t.Errorf("호 수 = %d, 원함 %d", g.M, 2*8128)
	}
	for v := range g.AllVertices() {
		for a := range v.AllArcs() {
			if a.Len <= 0 {
				t.Fatalf("간선 길이 = %d", a.Len)
			}
			if a.Len != a.Partner.Len {
				t.Fatalf("짝 호 길이가 다름: %d != %d", a.Len, a.Partner.Len)
			}
		}
	}
}

@ 완전 그래프에서 Worcester와 Youngstown 사이 간선의 길이는 604마일이라야
한다.

@<거리 시험@>=
func vertexNamed(g *gbgraph.Graph, name string) *gbgraph.Vertex {
	for v := range g.AllVertices() {
		if v.Name == name {
			return v
		}
	}
	return nil
}

func TestKnownDistance(t *testing.T) {
	g, err := Miles(0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	w := vertexNamed(g, "Worcester, MA")
	y := vertexNamed(g, "Youngstown, OH")
	if w == nil || y == nil {
		t.Fatal("Worcester나 Youngstown을 찾지 못함")
	}
	for a := range w.AllArcs() {
		if a.Tip == y {
			if a.Len != 604 {
				t.Errorf("Worcester-Youngstown = %d, 원함 604", a.Len)
			}
			return
		}
	}
	t.Error("Worcester-Youngstown 간선이 없다")
}

@ |maxDegree=1|이면 각 도시는 가장 가까운 이웃 하나만 향한다. 간선은 두 도시가
서로에게 가장 가까울 때에만 생기므로, 그래프는 성기다 --- 완전 그래프보다
간선이 훨씬 적어야 한다.

@<최근접 이웃 시험@>=
func TestMutualNearest(t *testing.T) {
	g, err := Miles(50, 0, 0, 0, 0, 1, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.ID != "miles(50,0,0,0,0,1,0)" {
		t.Errorf("ID = %q", g.ID)
	}
	if g.M/2 >= 50 { // 성긴 그래프: 간선이 정점 수보다 적다
		t.Errorf("간선 수 = %d, 너무 많다", g.M/2)
	}
	if g.M == 0 {
		t.Error("간선이 하나도 없다")
	}
}

@ 무게 계수가 한도를 넘으면 |BadSpecs|다.

@<무게 검증 오류 시험@>=
func TestMilesBadSpecs(t *testing.T) {
	if _, err := Miles(10, 200000, 0, 0, 0, 0, 0, dataDir); err != gbgraph.BadSpecs {
		t.Errorf("err = %v, 원함 BadSpecs", err)
	}
	if _, err := Miles(10, 0, 0, 200, 0, 0, 0, dataDir); err != gbgraph.BadSpecs {
		t.Errorf("err = %v, 원함 BadSpecs", err)
	}
}

@* 찾아보기.
