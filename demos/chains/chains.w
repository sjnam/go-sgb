% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 Knuth의 도전 문제(최장 점수 사슬)에 대한 우리의 답이다.
@i ../../gbtypes.w

\input kotexgweb
\def\title{CHAINS}

@* 들어가며. Knuth는 Stanford GraphBase의 도전 문제 하나를 이렇게 소개했다:
1990년 미식축구 시즌의 경기 결과를 단순 사슬로 이어, 스탠퍼드가 하버드를 몇 점
차까지 앞선다고 ``증명''할 수 있는가? Knuth 자신의 최고 기록은 2279였고, Buel
Chandler가 유전 프로그래밍으로 2448까지 끌어올렸으며, 2001년 11월 Mark Cooke가
2473짜리 사슬을 찾아냈다. Cooke는 2002년 2월에 그와 일치하는 상계까지 찾았으므로,
$2473$은 증명된 최적값이다. 아울러 하버드가 스탠퍼드를 앞서는 최적값은 2358,
모든 팀 쌍을 통틀어 가장 큰 값은 펜실베이니아 주립이 컬럼비아를 앞서는 2542다.

이 프로그램은 그 도전에 대한 우리의 답이다. {\sc FOOTBALL} 데모의 계층 탐욕
알고리즘은 너비 4000에서 2185에 그쳤지만, 여기서 쓰는 반복 국소 탐색은 150초
안에 2466까지 다다라 Knuth와 Chandler의 기록을 모두 넘고, 엘리트 사슬들을
접합하는 경로 재연결까지 더해 2468에 다다랐다. 그리고 마지막 장의 배정 완화
분지한정이 최적 사슬 2473을 직접 찾아 최적임을 증명하며 도전을 끝냈다.
하버드$\to$스탠퍼드의 2358과 펜실베이니아 주립$\to$컬럼비아의 2542도 같은
방법으로 증명된다---세 판 모두 일 초 안에.

@ 사용법은 이렇다:
$$\hbox{\tt chains [-from=팀] [-to=팀] [-t=시간] [-w=일꾼] [-s=씨앗]
 [-c] [-u=시간] [-D=디렉터리]}$$
\.{-from}과 \.{-to}의 기본값은 \.{Stanford}와 \.{Harvard}이고, 팀 이름은
\.{games.dat}의 표기 그대로여야 한다. \.{-t}는 탐색 시간(기본 30초), \.{-w}는
병렬 탐색 수(기본 CPU 수), \.{-s}는 난수 씨앗, \.{-c}는 찾은 사슬 전체를
찍는다. \.{-u}는 탐색이 끝난 뒤 배정 완화 분지한정으로 상계를 탐사하는
시간이다(기본 0, 안 함).

@ 프로그램의 뼈대다. 문제를 준비하고, 여러 일꾼이 나란히 탐색한 뒤, 가장 좋은
사슬을 한 번 더 연마해 찍는다.

@c
package main

@<내포하는 패키지들@>

@<자료 구조@>
@<문제 준비@>
@<경로 이동들@>
@<창 수선@>
@<경로 재연결@>
@<상계 탐사@>
@<반복 국소 탐색@>

func main() {
	@<명령줄 옵션을 읽는다@>
	p, err := buildProblem(*dir, *from, *to)
	if err != nil {
		log.Fatal(err)
	}
	deadline := time.Now().Add(*limit)
	@<일꾼들을 풀어 탐색한다@>
	@<최고 사슬을 연마한다@>
	@<결과를 검사하고 찍는다@>
	@<상계를 탐사해 찍는다@>
}

@ 이 프로그램은 SGB 이식이 아니라 우리가 새로 짓는 것이라, 난수도 \CEE/ 원본과
맞출 일이 없다. 그래서 |gbflip| 대신 표준 |math/rand/v2|의 PCG를 쓴다 ---
일꾼마다 독립 스트림을 얻기 좋다.

@<내포하는 패키지들@>=
import (
	"container/heap"
	"flag"
	"fmt"
	"log"
	"math"
	"math/rand/v2"
	"runtime"
	"slices"
	"sync"
	"time"
	@#
	"github.com/sjnam/go-sgb/gbgames"
)

@ @<명령줄 옵션을 읽는다@>=
from := flag.String("from", "Stanford", "시작 팀")
to := flag.String("to", "Harvard", "목표 팀")
dir := flag.String("D", "/usr/local/sgb/data", "자료 디렉터리")
limit := flag.Duration("t", 30*time.Second, "탐색 시간")
workers := flag.Int("w", runtime.NumCPU(), "병렬 탐색 수")
seed := flag.Uint64("s", 1, "난수 씨앗")
chain := flag.Bool("c", false, "사슬 전체를 찍는다")
ubound := flag.Duration("u", 0, "상계 탐사 시간")
flag.Parse()

@* 문제 준비. {\sc GB\_GAMES}의 그래프를 우리 문제에 맞는 꼴로 바꾼다. 사슬은
팀(정점)을 두 번 지나지 않는 단순 경로이고, |u| 다음에 |v|가 오면 그 경기의 점수
차 $|del|[u][v]$를 번다. 그러니 문제는: |start|에서 |goal|로 가는 단순 경로 가운데
$\sum|del|$이 가장 큰 것을 찾아라. 이는 최장 경로 문제라 NP-난해이지만, 정점이
120개뿐이고 목표값이 알려져 있으니 좋은 휴리스틱으로 답의 코앞까지 갈 수 있다.

|exists|와 |del|은 인접 행렬, |adj|는 인접 리스트다. 두 팀이 두 번 겨뤘으면(보울
재대결) |del|은 더 큰 점수 차를 취한다---사슬을 최대화할 때는 언제나 더 좋은
경기를 쓰면 되기 때문이다.

@<자료 구조@>=
type problem struct {
	n      int
	names  []string
	nick   []string  // 별명(|Y.S|); 사슬을 찍을 때만 쓴다
	exists [][]bool
	del    [][]int64
	uScore [][]int64 // 앞 팀(|u|)이 낸 점수
	vScore [][]int64 // 뒤 팀(|v|)이 낸 점수
	date   [][]int64 // 경기 날짜(|B.I|)
	adj    [][]int
	start  int
	goal   int
}

@ 음의 무한대 구실을 하는 파수꾼이다. 점수 차의 절댓값은 아무리 커도 수백이므로
$-2^{31}$이면 넉넉하고, 이득 셈에서 몇 번 더해도 넘치지 않는다.

@<자료 구조@>=
const negInf = int64(math.MinInt32)

@ |buildProblem|은 |gbgames.Games|로 1990년 시즌 전체 그래프를 짓고 행렬을 채운다.

@<문제 준비@>=
func buildProblem(dir, from, to string) (*problem, error) {
	g, err := gbgames.Games(0, 0, 0, 0, 0, 0, 0, 0, dir)
	if err != nil {
		return nil, err
	}
	n := int(g.N)
	p := &problem{n: n, names: make([]string, n), nick: make([]string, n),
		start: -1, goal: -1}
	@<행렬과 리스트를 채운다@>
	if p.start < 0 || p.goal < 0 {
		return nil, fmt.Errorf("모르는 팀: %q 또는 %q", from, to)
	}
	return p, nil
}

@ 세 단계다: 행렬을 잡고, 정점과 호를 훑어 채운 뒤, 인접 리스트를 짓는다.

@<행렬과 리스트를 채운다@>=
@<행렬을 할당한다@>
@<정점과 호에서 행렬을 채운다@>
@<인접 리스트를 짓는다@>

@ |del|만 음의 무한대로 초기화하고, 나머지는 |0|값 그대로 둔다.

@<행렬을 할당한다@>=
p.exists = make([][]bool, n)
p.del = make([][]int64, n)
p.uScore = make([][]int64, n)
p.vScore = make([][]int64, n)
p.date = make([][]int64, n)
p.adj = make([][]int, n)
for i := 0; i < n; i++ {
	p.exists[i] = make([]bool, n)
	p.del[i] = make([]int64, n)
	p.uScore[i] = make([]int64, n)
	p.vScore[i] = make([]int64, n)
	p.date[i] = make([]int64, n)
	for j := range p.del[i] {
		p.del[i][j] = negInf
	}
}

@ 호 |a|의 |a.Len|은 |i|가 낸 점수, |a.Partner.Len|은 상대가 낸 점수다. 점수
차가 여태 본 것보다 크면 그 경기의 점수·날짜까지 함께 새긴다.

@<정점과 호에서 행렬을 채운다@>=
for i := 0; i < n; i++ {
	v := &g.Vertices[i]
	p.names[i] = v.Name
	p.nick[i] = v.Y.S
	if v.Name == from {
		p.start = i
	}
	if v.Name == to {
		p.goal = i
	}
	for a := range v.AllArcs() {
		j := int(g.Index(a.Tip))
		if d := a.Len - a.Partner.Len; d > p.del[i][j] {
			p.del[i][j] = d
			p.uScore[i][j] = a.Len         // |i|가 낸 점수
			p.vScore[i][j] = a.Partner.Len // |j|가 낸 점수
			p.date[i][j] = a.B.I           // 경기 날짜
		}
		p.exists[i][j] = true
	}
}

@ 인접 행렬을 훑어 이웃 리스트를 만든다.

@<인접 리스트를 짓는다@>=
for i := 0; i < n; i++ {
	for j := 0; j < n; j++ {
		if p.exists[i][j] {
			p.adj[i] = append(p.adj[i], j)
		}
	}
}

@ 탐색의 출발점이 될 아무 단순 경로 하나를 무작위 깊이 우선 탐색으로 얻는다.
품질은 아무래도 좋다---국소 탐색이 곧 수천 점을 벌어 준다. 경로가 없으면
|nil|을 준다(뒤의 간선 금기가 시작과 목표를 끊어 버렸을 때 생길 수 있는 일이다).

@<문제 준비@>=
func (p *problem) randomPath(rng *rand.Rand) []int {
	visited := make([]bool, p.n)
	var path []int
	var dfs func(v int) bool
	dfs = func(v int) bool {
		visited[v] = true
		path = append(path, v)
		if v == p.goal {
			return true
		}
		nbr := append([]int(nil), p.adj[v]...)
		rng.Shuffle(len(nbr), func(i, j int) { nbr[i], nbr[j] = nbr[j], nbr[i] })
		for _, u := range nbr {
			if !visited[u] && dfs(u) {
				return true
			}
		}
		path = path[:len(path)-1]
		return false
	}
	if !dfs(p.start) {
		return nil
	}
	return path
}

@ 경로의 총 점수 차를 그대로 셈하는 잔심부름이다. 검사용으로도 쓴다.

@<문제 준비@>=
func (p *problem) total(path []int) int64 {
	var t int64
	for k := 0; k+1 < len(path); k++ {
		t += p.del[path[k]][path[k+1]]
	}
	return t
}

@* 경로 상태. 이동의 이득을 빨리 셈하려면 경로 자체 말고도 색인 둘이 필요하다.
|pos[v]|는 정점 |v|의 경로 위 위치($-1$이면 경로 밖), |pre[k]|는 |path[0..k]|까지
쌓인 |del|의 누적 합이다(|pre[0]=0|). 구간 $[i..j]$의 |del| 합은
$|pre|[j]-|pre|[i]$로 단박에 나온다.

@<자료 구조@>=
type state struct {
	path []int
	pos  []int
	pre  []int64
	tot  int64
}

func newState(p *problem, path []int) *state {
	s := &state{path: append([]int(nil), path...), pos: make([]int, p.n)}
	s.reindex(p)
	return s
}

@ 이동을 적용한 뒤에는 |reindex|로 색인을 몽땅 다시 셈한다. 경로 길이가 많아야
120이라, 영리한 증분 갱신보다 이 우직한 방법이 더 낫다(빠르고, 틀릴 수가 없다).

@<자료 구조@>=
func (s *state) reindex(p *problem) {
	for i := range s.pos {
		s.pos[i] = -1
	}
	if cap(s.pre) < len(s.path) {
		s.pre = make([]int64, 0, 2*len(s.path))
	}
	s.pre = s.pre[:len(s.path)]
	s.pre[0] = 0
	for k, v := range s.path {
		s.pos[v] = k
		if k > 0 {
			s.pre[k] = s.pre[k-1] + p.del[s.path[k-1]][v]
		}
	}
	s.tot = s.pre[len(s.path)-1]
}

func (s *state) copyFrom(o *state) {
	s.path = append(s.path[:0], o.path...)
	s.pos = append(s.pos[:0], o.pos...)
	s.pre = append(s.pre[:0], o.pre...)
	s.tot = o.tot
}

@ 일꾼들이 나누는 전역 최고해와 엘리트 풀이다. 뮤텍스 하나면 충분하다---발표와
조회가 드물어서 다툼이 없다. 엘리트 풀은 뒤의 경로 재연결이 쓴다.

@<자료 구조@>=
type shared struct {
	mu    sync.Mutex
	path  []int
	tot   int64
	elite []eliteEntry
}

func (sh *shared) publish(s *state) {
	sh.mu.Lock()
	defer sh.mu.Unlock()
	if sh.path == nil || s.tot > sh.tot {
		sh.path = append(sh.path[:0], s.path...)
		sh.tot = s.tot
	}
	@<엘리트 풀에도 |s|를 넣는다@>
}

func (sh *shared) snapshot() ([]int, int64) {
	sh.mu.Lock()
	defer sh.mu.Unlock()
	if sh.path == nil {
		return nil, 0
	}
	return append([]int(nil), sh.path...), sh.tot
}

@ |searcher|는 일꾼 하나의 탐색 상태다. |explorer| 일꾼은 전역 최고해로 갈아타지
않고 저 혼자 헤맨다---모두가 같은 골짜기로 몰리는 조기 수렴을 막는 다양성
담당이다.

@<자료 구조@>=
type searcher struct {
	p        *problem
	s        *state
	best     *state
	rng      *rand.Rand
	sh       *shared
	explorer bool
	bans     [][2]int // 금기 재시작이 지금 금지해 둔 간선들
}

@* 경로 이동들. 국소 탐색의 이동 다섯 가지를 마련한다: 삽입, 삭제, 교환, 반전,
구간 재배치. 각 |improveX|는 이득이 양인 이동 하나를 찾아 적용하면 참을 준다
--- 첫 개선(first improvement) 전략이다. 뒤의 교란 단계에서는 같은 이동을
무작위로, 이득과 무관하게 적용한다.

먼저 삽입: 경로의 간선 $(a,b)$ 사이에 바깥 정점 |x|를 끼운다. 이득은
$|del|[a][x]+|del|[x][b]-|del|[a][b]$다.

@<경로 이동들@>=
func (sr *searcher) applyInsert(k, x int) {
	s := sr.s
	s.path = append(s.path, 0)
	copy(s.path[k+2:], s.path[k+1:])
	s.path[k+1] = x
	s.reindex(sr.p)
}

func (sr *searcher) improveInsert() bool {
	p, s := sr.p, sr.s
	for k := 0; k+1 < len(s.path); k++ {
		a, b := s.path[k], s.path[k+1]
		for _, x := range p.adj[a] {
			if s.pos[x] < 0 && p.exists[x][b] &&
				p.del[a][x]+p.del[x][b]-p.del[a][b] > 0 {
				sr.applyInsert(k, x)
				return true
			}
		}
	}
	return false
}

@ 삭제는 삽입의 반대다: 안쪽 정점 |x|를 빼고 양옆 $(a,b)$를 직접 잇는다.
지는 경기 둘로 이어진 정점을 치울 때 이득이 난다.

@<경로 이동들@>=
func (sr *searcher) applyDelete(k int) {
	s := sr.s
	s.pos[s.path[k]] = -1
	copy(s.path[k:], s.path[k+1:])
	s.path = s.path[:len(s.path)-1]
	s.reindex(sr.p)
}

func (sr *searcher) improveDelete() bool {
	p, s := sr.p, sr.s
	for k := 1; k+1 < len(s.path); k++ {
		a, x, b := s.path[k-1], s.path[k], s.path[k+1]
		if p.exists[a][b] && p.del[a][b]-p.del[a][x]-p.del[x][b] > 0 {
			sr.applyDelete(k)
			return true
		}
	}
	return false
}

@ 교환은 삽입과 삭제를 한 번에: 안쪽 정점 |x|를 바깥 정점 |y|로 바꿔치기한다.

@<경로 이동들@>=
func (sr *searcher) improveExchange() bool {
	p, s := sr.p, sr.s
	for k := 1; k+1 < len(s.path); k++ {
		a, x, b := s.path[k-1], s.path[k], s.path[k+1]
		for _, y := range p.adj[a] {
			if s.pos[y] < 0 && p.exists[y][b] &&
				p.del[a][y]+p.del[y][b]-p.del[a][x]-p.del[x][b] > 0 {
				s.path[k] = y
				s.reindex(p)
				return true
			}
		}
	}
	return false
}

@ 반전(2-opt)은 이 문제 특유의 묘미가 있다. 안쪽 구간 $[i..j]$를 뒤집으면 그
구간을 반대로 걷게 되는데, $|del|[u][v]=-|del|[v][u]$이므로 구간 안에서 벌던
점수의 부호가 몽땅 뒤집힌다! 구간 합 $S=|pre|[j]-|pre|[i]$를 쓰면 이득은
$$|del|[b][p_j]+|del|[p_i][a]-|del|[b][p_i]-|del|[p_j][a]-2S$$
꼴로 $O(1)$에 나온다(여기서 $b$·$a$는 구간 바로 앞뒤의 정점).
그래서 지는 걸음이 많은 구간은 뒤집는 것만으로 큰 이득이 된다.

@<경로 이동들@>=
func (sr *searcher) reverseGain(i, j int) int64 {
	p, s := sr.p, sr.s
	before, pa := s.path[i-1], s.path[i]
	pb, after := s.path[j], s.path[j+1]
	if !p.exists[before][pb] || !p.exists[pa][after] {
		return negInf
	}
	seg := s.pre[j] - s.pre[i]
	return p.del[before][pb] + p.del[pa][after] -
		p.del[before][pa] - p.del[pb][after] - 2*seg
}

func (sr *searcher) applyReverse(i, j int) {
	s := sr.s
	for l, r := i, j; l < r; l, r = l+1, r-1 {
		s.path[l], s.path[r] = s.path[r], s.path[l]
	}
	s.reindex(sr.p)
}

@ 반전 후보를 훑을 때 $(i,j)$ 쌍을 다 보면 대부분 간선이 없어 헛수고다. 대신
구간 앞 정점 |before|의 이웃 가운데 경로 위에 있는 것을 |j|로 삼으면, 반전의 첫
새 간선이 반드시 실제 간선이 된다.

@<경로 이동들@>=
func (sr *searcher) improveReverse() bool {
	p, s := sr.p, sr.s
	m := len(s.path)
	for i := 1; i+1 < m; i++ {
		for _, pb := range p.adj[s.path[i-1]] {
			j := s.pos[pb]
			if j >= i && j+1 < m && sr.reverseGain(i, j) > 0 {
				sr.applyReverse(i, j)
				return true
			}
		}
	}
	return false
}

@ 구간 재배치(Or-opt): 길이 1--6의 구간 $[i..j]$를 잘라 딴 간선 $(c,d)$ 사이로
옮긴다. 그대로 옮기거나(정방향), 뒤집어 옮긴다(역방향---이때도 구간 합의
부호가 바뀐다). 이득은 구멍을 메우는 값과 새 자리에 끼우는 값의 합이다.

@<경로 이동들@>=
func (sr *searcher) orOptGain(i, j, k int, reversed bool) int64 {
	p, s := sr.p, sr.s
	pi1, pi := s.path[i-1], s.path[i]
	pj, pj1 := s.path[j], s.path[j+1]
	c, d := s.path[k], s.path[k+1]
	if !p.exists[pi1][pj1] {
		return negInf
	}
	gap := p.del[pi1][pj1] - p.del[pi1][pi] - p.del[pj][pj1]
	if !reversed {
		if !p.exists[c][pi] || !p.exists[pj][d] {
			return negInf
		}
		return gap + p.del[c][pi] + p.del[pj][d] - p.del[c][d]
	}
	if !p.exists[c][pj] || !p.exists[pi][d] {
		return negInf
	}
	seg := s.pre[j] - s.pre[i]
	return gap + p.del[c][pj] + p.del[pi][d] - p.del[c][d] - 2*seg
}

@ 재배치의 적용은 새 경로를 이어 붙여 만드는 것이 가장 또렷하다.

@<경로 이동들@>=
func (sr *searcher) applyOrOpt(i, j, k int, reversed bool) {
	s := sr.s
	seg := append([]int(nil), s.path[i:j+1]...)
	if reversed {
		for l, r := 0, len(seg)-1; l < r; l, r = l+1, r-1 {
			seg[l], seg[r] = seg[r], seg[l]
		}
	}
	rest := append([]int(nil), s.path[:i]...)
	rest = append(rest, s.path[j+1:]...)
	c := s.path[k]
	var out []int
	for _, v := range rest {
		out = append(out, v)
		if v == c { // |c| 바로 뒤에 구간을 끼운다
			out = append(out, seg...)
		}
	}
	s.path = out
	s.reindex(sr.p)
}

@ @<경로 이동들@>=
func (sr *searcher) improveOrOpt() bool {
	s := sr.s
	m := len(s.path)
	for L := 1; L <= 6; L++ {
		for i := 1; i+L < m; i++ {
			j := i + L - 1
			for k := 0; k+1 < m; k++ {
				if k >= i-1 && k <= j {
					continue // 구간과 겹치는 자리
				}
				if sr.orOptGain(i, j, k, false) > 0 {
					sr.applyOrOpt(i, j, k, false)
					return true
				}
				if sr.orOptGain(i, j, k, true) > 0 {
					sr.applyOrOpt(i, j, k, true)
					return true
				}
			}
		}
	}
	return false
}

@* 창 수선. 위의 값싼 이동들만으로는 2200대에서 멈춘다. 벽을 넘게 해 준 것은
대형 이웃 탐색(large neighborhood search)이다: 경로에서 창 $[i..i{+}w{-}1]$을
통째로 뜯어내고, 뜯긴 정점들과 경로 밖 정점들을 풀(pool)로 삼아, 창의 두 끝점
$A=|path|[i{-}1]$와 $B=|path|[i{+}w]$를 잇는 최대 무게 단순 경로를 분기한정
탐색으로 정확히 다시 짠다. 창이 12개 정점쯤이면 풀이 20개 남짓이라 감당이 된다.

@<창 수선@>=
func (sr *searcher) improveLNS(i, w, budget int) bool {
	p, s := sr.p, sr.s
	m := len(s.path)
	if i < 1 || i+w >= m {
		return false
	}
	a, b := s.path[i-1], s.path[i+w]
	oldSeg := s.pre[i+w-1] - s.pre[i-1] + p.del[s.path[i+w-1]][b]
	@<풀을 모아 |pool|에 담는다@>
	r := &repairer{p: p, pool: pool, b: b, budget: budget, bestVal: oldSeg}
	r.prepBounds(a)
	r.dfs(a, 0, 0)
	if r.bestSeq == nil || r.bestVal <= oldSeg {
		return false
	}
	@<창을 |r.bestSeq|로 갈아 끼운다@>
	return true
}

@ 풀은 창의 정점들에 경로 밖 정점들을 더한 것이다. 비트마스크 하나로 쓴 정점을
표시하려고 64개로 제한한다(실제로는 창 12 + 바깥 몇 개라 늘 넉넉하다).

@<풀을 모아 |pool|에 담는다@>=
var pool []int
pool = append(pool, s.path[i:i+w]...)
for v := 0; v < p.n; v++ {
	if s.pos[v] < 0 {
		pool = append(pool, v)
	}
}
if len(pool) > 64 {
	return false
}

@ @<창을 |r.bestSeq|로 갈아 끼운다@>=
newPath := make([]int, 0, m-w+len(r.bestSeq))
newPath = append(newPath, s.path[:i]...)
newPath = append(newPath, r.bestSeq...)
newPath = append(newPath, s.path[i+w:]...)
s.path = newPath
s.reindex(p)

@ 경로를 따라 창을 밀며 수선을 거는 청소 도우미다.

@<창 수선@>=
func (sr *searcher) improveLNSSweep(w, budget int) bool {
	improved := false
	for i := 1; i+w <= len(sr.s.path); i += w / 2 {
		if sr.improveLNS(i, w, budget) {
			improved = true
		}
	}
	return improved
}

@ |repairer|가 분기한정 탐색을 맡는다. |bestVal|의 초깃값은 낡은 구간의 값이라,
그보다 나은 해만 |bestSeq|에 남는다. |budget|은 탐색 노드 수의 상한이다 ---
예산이 다하면 그때까지의 최선으로 만족한다.

@<자료 구조@>=
type repairer struct {
	p       *problem
	pool    []int
	b       int
	budget  int
	bestVal int64
	bestSeq []int   // 중간 정점 나열 (|A|·|B| 제외)
	thr     []int64 // |pool[k]|의 통과 이득 상한
	maxInB  int64   // |B|로 들어오는 최대 |del|
	seq     []int   // 현재 탐색 경로
}

@ 가지치기의 재료를 마련한다. 풀 정점 |v|의 ``통과 이득'' $|thr|[k]$는 |v|로
들어오는 최대 |del|과 |v|에서 나가는 최대 |del|의 합이다(풀과 양 끝점 안에서만).

가지치기의 근거는 이렇다. 지금 정점에서 $B$까지 남은 걸음의 이득을 $R$라 하자.
경로의 각 간선은 그 양 끝 정점의 ``나가는 몫''과 ``들어오는 몫''으로 두 번
세어지므로, 남은 중간 정점들의 통과 이득을 다 더하면 $2R$에서 첫 간선과 마지막
간선의 몫 하나씩이 빠진 것 이상이 된다. 곧
$$2R \le \\{maxOut}(현재) + \sum_{v\ 미사용}\max(0,|thr|[v])
   + \\{maxInB}$$
이고, 이 상한이 지금까지의 최고에 못 미치면 그 가지는 통째로 버린다.

@<창 수선@>=
func (r *repairer) prepBounds(a int) {
	p := r.p
	member := make(map[int]bool, len(r.pool)+2)
	for _, v := range r.pool {
		member[v] = true
	}
	member[a], member[r.b] = true, true
	r.thr = make([]int64, len(r.pool))
	for k, v := range r.pool {
		in, out := negInf, negInf
		for _, u := range p.adj[v] {
			if member[u] {
				if p.del[u][v] > in {
					in = p.del[u][v]
				}
				if p.del[v][u] > out {
					out = p.del[v][u]
				}
			}
		}
		r.thr[k] = in + out
	}
	r.maxInB = negInf
	for _, u := range p.adj[r.b] {
		if member[u] && p.del[u][r.b] > r.maxInB {
			r.maxInB = p.del[u][r.b]
		}
	}
}

@ 탐색 본체다. |mask|는 쓴 풀 정점들의 비트마스크, |val|은 지금까지 번 값이다.
아무 때나 $B$로 끝맺을 수 있으므로, 후보 갱신을 먼저 하고 상한 검사를 한 뒤
가지를 뻗는다.

@<창 수선@>=
func (r *repairer) dfs(cur int, mask uint64, val int64) {
	if r.budget <= 0 {
		return
	}
	r.budget--
	p := r.p
	if p.exists[cur][r.b] { // 지금 바로 |B|로 끝맺는 후보
		if v := val + p.del[cur][r.b]; v > r.bestVal {
			r.bestVal = v
			r.bestSeq = append([]int(nil), r.seq...)
		}
	}
	@<상한을 셈해 가망 없으면 돌아간다@>
	for k, v := range r.pool {
		if mask&(1<<k) != 0 || !p.exists[cur][v] {
			continue
		}
		r.seq = append(r.seq, v)
		r.dfs(v, mask|(1<<k), val+p.del[cur][v])
		r.seq = r.seq[:len(r.seq)-1]
	}
}

@ @<상한을 셈해 가망 없으면 돌아간다@>=
var slack int64
maxOut := negInf
for k, v := range r.pool {
	if mask&(1<<k) != 0 {
		continue
	}
	if r.thr[k] > 0 {
		slack += r.thr[k]
	}
	if p.exists[cur][v] && p.del[cur][v] > maxOut {
		maxOut = p.del[cur][v]
	}
}
if p.exists[cur][r.b] && p.del[cur][r.b] > maxOut {
	maxOut = p.del[cur][r.b]
}
if maxOut == negInf {
	return // 나아갈 곳이 없다
}
if val+(maxOut+slack+r.maxInB)/2+1 <= r.bestVal {
	return
}

@* 반복 국소 탐색. 이제 부품을 엮는다. |localSearch|는 어떤 이동으로도 나아지지
않을 때까지 첫 개선을 되풀이하고, 값싼 이동이 소진되면 창 수선을 청소차처럼
민다.

@<반복 국소 탐색@>=
func (sr *searcher) localSearch() {
	for {
		if sr.improveDelete() || sr.improveInsert() || sr.improveExchange() ||
			sr.improveReverse() || sr.improveOrOpt() {
			continue
		}
		if sr.improveLNSSweep(8, 500_000) {
			continue
		}
		if sr.improveLNSSweep(12, 500_000) {
			continue
		}
		return
	}
}

@ 교란: 무작위 이동 |strength|개를 이득과 무관하게 적용해 국소 최적의 우물에서
벗어난다.

@<반복 국소 탐색@>=
func (sr *searcher) perturb(strength int) {
	p, s, rng := sr.p, sr.s, sr.rng
	for done := 0; done < strength; {
		m := len(s.path)
		switch rng.IntN(4) {
		case 0:
			@<무작위 반전을 시도한다@>
		case 1:
			@<무작위 삽입을 시도한다@>
		case 2:
			@<무작위 삭제를 시도한다@>
		case 3:
			@<무작위 교환을 시도한다@>
		}
	}
}

@ @<무작위 반전을 시도한다@>=
i := 1 + rng.IntN(m-2)
nbr := p.adj[s.path[i-1]]
pb := nbr[rng.IntN(len(nbr))]
j := s.pos[pb]
if j >= i && j+1 < m && sr.reverseGain(i, j) > negInf/2 {
	sr.applyReverse(i, j)
	done++
}

@ @<무작위 삽입을 시도한다@>=
k := rng.IntN(m - 1)
a, b := s.path[k], s.path[k+1]
nbr := p.adj[a]
x := nbr[rng.IntN(len(nbr))]
if s.pos[x] < 0 && p.exists[x][b] {
	sr.applyInsert(k, x)
	done++
}

@ @<무작위 삭제를 시도한다@>=
if m < 4 {
	continue
}
k := 1 + rng.IntN(m-2)
if p.exists[s.path[k-1]][s.path[k+1]] {
	sr.applyDelete(k)
	done++
}

@ @<무작위 교환을 시도한다@>=
k := 1 + rng.IntN(m-2)
a, b := s.path[k-1], s.path[k+1]
nbr := p.adj[a]
y := nbr[rng.IntN(len(nbr))]
if s.pos[y] < 0 && p.exists[y][b] {
	s.path[k] = y
	s.reindex(p)
	done++
}

@ 파괴-재건: 창 $[i..i{+}w{-}1]$을 뜯어내고 분기한정 탐색이 찾은 최선으로 무조건
갈아 끼운다. 국소 최적의 골짜기를 통째로 건너뛰는 가장 강한 교란이다. |kickAt|은
자리를 받아 일하고, |kick|은 무작위 자리에 건다.

@<반복 국소 탐색@>=
func (sr *searcher) kickAt(i, w int) bool {
	p, s := sr.p, sr.s
	m := len(s.path)
	if i < 1 || i+w >= m {
		return false
	}
	a, b := s.path[i-1], s.path[i+w]
	@<풀을 모아 |pool|에 담는다@>
	r := &repairer{p: p, pool: pool, b: b, budget: 400_000, bestVal: negInf}
	r.prepBounds(a)
	r.dfs(a, 0, 0)
	if r.bestSeq == nil {
		return false // 재건 실패---낡은 창을 그대로 둔다
	}
	@<창을 |r.bestSeq|로 갈아 끼운다@>
	return true
}

func (sr *searcher) kick() bool {
	m := len(sr.s.path)
	w := 15 + sr.rng.IntN(11)
	if w > m-2 {
		w = m - 2
	}
	return sr.kickAt(1+sr.rng.IntN(m-1-w), w)
}

@ 간선 금기 재시작. 실험해 보면 2466 같은 깊은 국소 최적은 위의 어떤 교란으로도
잘 벗어나지 못한다---좋은 사슬들이 몇몇 고득점 간선을 공유하는 넓은 분지를
이루기 때문이다. 그 분지를 벗어나는 확실한 방법은, 지금 최고 사슬이 쓰는 간선
몇 개를 아예 **금지**한 채 처음부터 다시 탐색하는 것이다. 금기는 현 분지로
돌아가는 길을 끊으므로, 탐색은 어쩔 수 없이 딴 분지를 개척한다. 금기 아래에서
찾은 사슬은 (간선을 빼기만 했으니) 원래 문제에서도 유효하다.

일꾼마다 |problem|의 사본을 갖고 있어야 서로의 금기가 충돌하지 않는다. |clone|은
|exists|·|adj|만 깊이 복사한다(|del|·|names|는 읽기 전용이라 나눠 쓴다).

@<자료 구조@>=
func (p *problem) clone() *problem {
	q := &problem{n: p.n, names: p.names, del: p.del,
		start: p.start, goal: p.goal}
	q.exists = make([][]bool, p.n)
	q.adj = make([][]int, p.n)
	for i := 0; i < p.n; i++ {
		q.exists[i] = append([]bool(nil), p.exists[i]...)
		q.adj[i] = append([]int(nil), p.adj[i]...)
	}
	return q
}

@ 간선 하나를 금지하거나 풀 때는 |exists|를 고치고 양 끝 정점의 인접 리스트만
다시 만든다. 모든 이동과 창 수선이 |exists|·|adj|를 거치므로 이것으로 충분하다.

@<자료 구조@>=
func (p *problem) rebuildAdj(u int) {
	p.adj[u] = p.adj[u][:0]
	for v := 0; v < p.n; v++ {
		if p.exists[u][v] {
			p.adj[u] = append(p.adj[u], v)
		}
	}
}

@ @<반복 국소 탐색@>=
func (sr *searcher) banEdge(u, v int) {
	sr.p.exists[u][v], sr.p.exists[v][u] = false, false
	sr.p.rebuildAdj(u)
	sr.p.rebuildAdj(v)
}

func (sr *searcher) unbanAll() {
	for _, e := range sr.bans {
		sr.p.exists[e[0]][e[1]], sr.p.exists[e[1]][e[0]] = true, true
		sr.p.rebuildAdj(e[0])
		sr.p.rebuildAdj(e[1])
	}
	sr.bans = sr.bans[:0]
}

@ |tabuRestart|가 금기 재시작 한 판이다: 최고 사슬의 간선을 무작위로 3--8개
금지하고, 최고 사슬에서 출발하되 금지된 간선이 놓인 창들만 강제로 다시 짠 뒤,
금기 아래에서 |rounds|판의 미니 반복 탐색을 돌리고, 금기를 풀고 마지막 손질을
한다. 처음에는 금기 아래에서 맨바닥부터 새로 출발해 봤지만, 미니 탐색이 최고
수준(2450+)까지 되오르기엔 판이 턱없이 모자라 늘 헛수고였다---좋은 사슬의
99\%는 그대로 두고 금지된 자리만 우회시키는 지금 방식이 옳다.

정직하게 적어 두자면: 이 장치로도 2466의 벽은 못 넘었다. 금기 몇 개로
끊어 낸 우회로가 도로 같은 분지로 굴러떨어질 만큼 그 분지가 넓다는 뜻이다.
그래도 탐색의 다양성을 해치지는 않으므로 장치는 남겨 둔다. 그 벽을 처음
넘어 준 것은 다음의 경로 재연결이다.

@<반복 국소 탐색@>=
func (sr *searcher) tabuRestart(rounds int) bool {
	@<최고 사슬의 간선 몇 개를 금지한다@>
	sr.s.copyFrom(sr.best)
	@<금지된 간선이 놓인 창들을 강제로 다시 짠다@>
	sr.localSearch()
	@<금기 아래에서 |rounds|판을 돈다@>
	sr.unbanAll()
	sr.localSearch() // 금기가 풀렸으니 그 간선들도 다시 쓸 수 있다
	if sr.s.tot > sr.best.tot {
		sr.best.copyFrom(sr.s)
		sr.sh.publish(sr.best)
		return true
	}
	return false
}

@ 금지된 간선 $(u,v)$가 아직 경로 위에 있으면(양 방향 다 살핀다), 그 간선을
품는 너비 12의 창을 |kickAt|으로 다시 짠다---분기한정 탐색은 |exists|를
따르므로 금지된 간선을 절대 다시 쓰지 않는다. 창 하나를 갈아 끼우면 위치들이
밀리므로, 금기마다 위치를 새로 찾는다. 재건이 안 되는 금기가 하나라도 있으면
이번 판은 포기한다.

@<금지된 간선이 놓인 창들을 강제로 다시 짠다@>=
for _, e := range sr.bans {
	s := sr.s
	pos := -1
	if pu := s.pos[e[0]]; pu >= 0 && pu+1 < len(s.path) && s.path[pu+1] == e[1] {
		pos = pu
	} else if pv := s.pos[e[1]]; pv >= 0 && pv+1 < len(s.path) && s.path[pv+1] == e[0] {
		pos = pv
	}
	if pos < 0 {
		continue // 이 간선은 벌써 우회됐다
	}
	@<위치 |pos|의 간선을 품는 창을 다시 짠다@>
}

@ 창은 간선의 양 끝(위치 |pos|·|pos+1|)을 안에 품어야 한다. 경로 끝에
몰렸으면 안쪽으로 밀어 넣는다.

@<위치 |pos|의 간선을 품는 창을 다시 짠다@>=
w := 12
m := len(sr.s.path)
if w > m-2 {
	w = m - 2
}
i := pos - w/2
if i < 1 {
	i = 1
}
if i+w >= m {
	i = m - 1 - w
}
if pos+1 > i+w-1 { // 창이 간선을 다 못 품으면 오른쪽으로 당긴다
	i = pos + 2 - w
	if i < 1 {
		i = 1
	}
}
if !sr.kickAt(i, w) {
	sr.unbanAll()
	return false // 우회로를 못 찾았다---이번 판은 포기
}

@ 무엇을 금지할까? 분지의 {\it 척추\/}---엘리트 풀의 모든 사슬이 공유하는
간선---를 겨냥해 끊는 것이 분지를 벗어나는 확실한 길처럼 보여 실제로 시험해
봤지만, 여덟 씨앗 평균이 2445에서 2420으로 곤두박질쳤다. 척추는 분지의 버릇이
아니라 좋은 사슬이면 무엇이든 갖춰야 하는 필수 부품이었던 것이다: 그것을
서너 개씩 끊으면 미니 탐색이 회복할 수 없는 가난한 땅으로 쫓겨난다. 그래서
최고 사슬에서 무작위로 뽑는다---엉뚱해 보여도 실측이 고른 방법이다.

@<최고 사슬의 간선 몇 개를 금지한다@>=
for t, k := 0, 3+sr.rng.IntN(6); t < k; t++ {
	e := sr.rng.IntN(len(sr.best.path) - 1)
	u, v := sr.best.path[e], sr.best.path[e+1]
	if sr.p.exists[u][v] {
		sr.bans = append(sr.bans, [2]int{u, v})
		sr.banEdge(u, v)
	}
}

@ @<금기 아래에서 |rounds|판을 돈다@>=
inner := newState(sr.p, sr.s.path)
for r := 0; r < rounds; r++ {
	sr.perturb(3 + sr.rng.IntN(6))
	sr.localSearch()
	if sr.s.tot > inner.tot {
		inner.copyFrom(sr.s)
	} else if sr.s.tot < inner.tot-60 {
		sr.s.copyFrom(inner)
	}
}
sr.s.copyFrom(inner)

@ |run|이 한 일꾼의 전체 여정이다. 마감까지 돈다. 개선이 없는 판이 이어질수록
교란을 세게 걸고, 이따금 전역 최고해와 견주어 크게 뒤처졌으면 그리로 갈아탄다.

@<반복 국소 탐색@>=
func (sr *searcher) run(deadline time.Time) {
	sr.localSearch()
	sr.best.copyFrom(sr.s)
	sr.sh.publish(sr.best)
	stale := 0
	for round := 0; time.Now().Before(deadline); round++ {
		@<교란하거나 파괴-재건한다@>
		sr.localSearch()
		@<결과에 따라 최고해와 정체 계수를 손본다@>
		@<이따금 전역 최고해로 갈아탄다@>
		@<이따금 엘리트와 재연결한다@>
		@<정체가 깊으면 대청소하거나 새로 출발한다@>
	}
}

@ @<교란하거나 파괴-재건한다@>=
if stale > 200 && sr.rng.IntN(2) == 0 {
	kicks := 1 + stale/400 // 정체가 깊을수록 연달아 흔든다
	if kicks > 3 {
		kicks = 3
	}
	for K := 0; K < kicks; K++ {
		sr.kick()
	}
} else {
	strength := 3 + sr.rng.IntN(6)
	if stale > 300 {
		strength = 12 + sr.rng.IntN(12)
	}
	sr.perturb(strength)
}

@ 조금 나쁜 곳은 그대로 두고 탐험을 잇되, 너무 나빠졌으면 최고해로 돌아온다.

@<결과에 따라 최고해와 정체 계수를 손본다@>=
switch {
case sr.s.tot > sr.best.tot:
	sr.best.copyFrom(sr.s)
	sr.sh.publish(sr.best)
	stale = 0
case sr.s.tot < sr.best.tot-60:
	sr.s.copyFrom(sr.best)
	stale++
default:
	stale++
}

@ @<이따금 전역 최고해로 갈아탄다@>=
if !sr.explorer && round%64 == 0 {
	if gp, gt := sr.sh.snapshot(); gp != nil && gt > sr.best.tot+15 {
		sr.s = newState(sr.p, gp)
		sr.best.copyFrom(sr.s)
		stale = 0
	}
}

@ @<정체가 깊으면 대청소하거나 새로 출발한다@>=
if stale > 0 && stale%120 == 0 { // 큰 창 대청소
	sr.s.copyFrom(sr.best)
	if sr.improveLNSSweep(16, 3_000_000) {
		sr.localSearch()
		if sr.s.tot > sr.best.tot {
			sr.best.copyFrom(sr.s)
			sr.sh.publish(sr.best)
			stale = 0
		}
	}
}
if stale > 150 && stale%150 == 0 { // 금기 재시작으로 딴 분지를 개척한다
	if sr.tabuRestart(120) {
		stale = 0
	}
}

@* 경로 재연결. 산재 탐색(scatter search) 진영의 경로 재연결(path relinking)은
좋은 해 둘 사이를 잇는 길 위에서 더 좋은 해를 찾는 기법이다. 간선 금기가 가르쳐
준 것은 좋은 사슬들이 고득점 간선을 공유하는 넓은 분지를 이룬다는 사실이었으니,
서로 다른 분지에서 자란 사슬 둘의 좋은 조각을 한 사슬에 모으는 것이 남은
무기다. 우리의 두 사슬은 같은 정점을 많이 지나므로, 잇는 길을 끝까지 걷는 대신
한 걸음으로 줄인다: 공통 정점에서 한쪽의 앞토막과 다른 쪽의 뒤토막을 접합하는
것이다---유전 알고리즘의 교차(crossover)와 같은 발상이다.

재료가 되는 좋은 사슬들이 필요하니, 전역 최고해 하나만 나누던 |shared|에
엘리트 풀을 두었다. 풀은 여태 발표된 서로 다른 사슬 가운데 가장 좋은
|eliteMax|개를 총점 내림차순으로 간직한다.

@<자료 구조@>=
type eliteEntry struct {
	path []int
	tot  int64
}

const eliteMax = 10     // 풀의 크기
const eliteMinDiff = 8  // 별개의 엘리트로 치는 최소 간선 차이

@ 발표되는 사슬마다 풀에 넣어 본다. 거의 같은 사슬들로 풀이 가득 차면 재연결이
헛돌므로, 간선이 |eliteMinDiff|개 미만으로 다른 기존 엘리트가 있으면 새로 넣지
않고---더 좋을 때만---그 자리를 갈아 치운다. |next|는 |s|의 간선들을 담은
표라, 엘리트의 간선 가운데 |s|에 없는 것을 셀 수 있다. 풀이 작으니 삽입
정렬이면 족하다.

@<엘리트 풀에도 |s|를 넣는다@>=
next := make(map[int]int, len(s.path))
for k := 0; k+1 < len(s.path); k++ {
	next[s.path[k]] = s.path[k+1]
}
for i := range sh.elite {
	@<|sh.elite[i]|가 |s|와 거의 같으면 갈아 치우고 물러난다@>
}
if len(sh.elite) == eliteMax && s.tot <= sh.elite[eliteMax-1].tot {
	return
}
sh.elite = append(sh.elite, eliteEntry{path: append([]int(nil), s.path...), tot: s.tot})
for i := len(sh.elite) - 1; i > 0 && sh.elite[i].tot > sh.elite[i-1].tot; i-- {
	sh.elite[i], sh.elite[i-1] = sh.elite[i-1], sh.elite[i]
}
if len(sh.elite) > eliteMax {
	sh.elite = sh.elite[:eliteMax]
}

@ 간선 차이 |d|를 세고, |eliteMinDiff|에 못 미치면 같은 엘리트로 본다. 새
사슬이 더 좋으면 그 자리를 차지하고 제자리로 밀어 올린다.

@<|sh.elite[i]|가 |s|와 거의 같으면 갈아 치우고 물러난다@>=
d := 0
for k := 0; k+1 < len(sh.elite[i].path); k++ {
	if w, in := next[sh.elite[i].path[k]]; !in || w != sh.elite[i].path[k+1] {
		d++
	}
}
if d < eliteMinDiff {
	if s.tot > sh.elite[i].tot {
		sh.elite[i] = eliteEntry{path: append([]int(nil), s.path...), tot: s.tot}
		for ; i > 0 && sh.elite[i].tot > sh.elite[i-1].tot; i-- {
			sh.elite[i], sh.elite[i-1] = sh.elite[i-1], sh.elite[i]
		}
	}
	return
}

@ 일꾼은 무작위 엘리트 하나를 뽑아 가고, 마지막 연마는 풀 전체를 가져간다.

@<경로 재연결@>=
func (sh *shared) eliteSample(rng *rand.Rand) []int {
	sh.mu.Lock()
	defer sh.mu.Unlock()
	if len(sh.elite) == 0 {
		return nil
	}
	return append([]int(nil), sh.elite[rng.IntN(len(sh.elite))].path...)
}

func (sh *shared) elitePaths() [][]int {
	sh.mu.Lock()
	defer sh.mu.Unlock()
	out := make([][]int, len(sh.elite))
	for i, e := range sh.elite {
		out[i] = append([]int(nil), e.path...)
	}
	return out
}

@ 접합 자체는 |splice|가 맡는다. 사슬 |s|의 안쪽 공통 정점마다, |s|에서 거기까지
가는 앞토막에 |t|에서 그다음부터 가는 뒤토막을 이어 후보를 만들고, 그중 총점이
가장 큰 것을 돌려준다. 뒤토막의 정점이 벌써 앞토막에 있으면 그냥 건너뛰는데,
건너뛴 자리를 이을 간선이 없으면 그 후보는 버린다.

@<경로 재연결@>=
func (p *problem) splice(s, t []int) ([]int, int64) {
	posT := make([]int, p.n)
	for i := range posT {
		posT[i] = -1
	}
	for k, v := range t {
		posT[v] = k
	}
	used := make([]bool, p.n)
	var bestPath []int
	bestTot := negInf
	for i := 1; i+1 < len(s); i++ {
		j := posT[s[i]]
		if j < 1 || j+1 >= len(t) {
			continue
		}
		@<앞토막과 뒤토막을 접합해 |bestPath|와 견준다@>
	}
	return bestPath, bestTot
}

@ @<앞토막과 뒤토막을 접합해 |bestPath|와 견준다@>=
cand := append([]int(nil), s[:i+1]...)
for k := range used {
	used[k] = false
}
for _, v := range cand {
	used[v] = true
}
prev := s[i]
ok := true
for _, v := range t[j+1:] {
	if used[v] {
		continue // 벌써 앞토막에 있는 정점은 건너뛴다
	}
	if !p.exists[prev][v] {
		ok = false // 건너뛴 자리를 이을 간선이 없다
		break
	}
	cand = append(cand, v)
	used[v] = true
	prev = v
}
if ok && prev == p.goal {
	if tot := p.total(cand); tot > bestTot {
		bestPath, bestTot = cand, tot
	}
}

@ 탐색 중의 재연결이다. 처음에는 판수를 세어 마흔여덟 판마다 걸었는데, 그렇게
자주 갈아타니 일꾼들이 서로 닮아 가 오히려 손해였다(네 씨앗 평균 2451
대 2436). 그래서 교란이 잘 듣고 있는 동안은 건드리지 않고, 정체가 길어졌을
때만---대청소(120)·금기 재시작(150)과 어긋난 주기로---한 번씩 건다. 엘리트
하나를 뽑아 내 최고 사슬과 두 방향으로 접합해 보고, 후보의 원점수가 최고해의
80점 안쪽일 때만 국소 탐색으로 다듬는다(형편없는 접합에 값비싼 탐색을 낭비하지
않도록). 결과 처리는 여느 판과 같은 절을 그대로 쓴다. 탐험가는 풀에 끌려가지
않도록 여기서도 빠진다.

@<이따금 엘리트와 재연결한다@>=
if !sr.explorer && stale > 0 && stale%90 == 45 {
	if gp := sr.sh.eliteSample(sr.rng); gp != nil {
		c1, t1 := sr.p.splice(sr.best.path, gp)
		if c2, t2 := sr.p.splice(gp, sr.best.path); c1 == nil || (c2 != nil && t2 > t1) {
			c1, t1 = c2, t2
		}
		if c1 != nil && t1 > sr.best.tot-80 && !slices.Equal(c1, sr.best.path) {
			sr.s = newState(sr.p, c1)
			sr.localSearch()
			@<결과에 따라 최고해와 정체 계수를 손본다@>
		}
	}
}

@ 마지막 연마 직전에도 재연결을 한 번 더 건다: 전역 최고해를 풀의 엘리트마다
두 방향으로 접합해 보고, 국소 탐색으로 다듬어 나아지면 갈아탄다.

이 장치의 성적표도 정직하게 적어 둔다. 씨앗 여덟 개로 잰 150초 실험에서
재연결이 평균을 밀어 올리지는 못했다(2445 대 2438---차이가 잡음 안이다).
그러나 한 판에서 2468짜리 사슬을 찾아 우리 기록을 두 점 올렸고, 증명된
최적값과의 거리를 다섯 점으로 좁혔다. 재연결도 금기처럼 남는다---다만
이번에는 신기록 하나를 들고서. 마지막 다섯 점은 다음 장의 상계가 갚는다.

@<엘리트들을 재연결해 출발점을 고른다@>=
for _, ep := range sh.elitePaths() {
	for _, duo := range [][2][]int{{b.path, ep}, {ep, b.path}} {
		c, _ := p.splice(duo[0], duo[1])
		if c == nil || slices.Equal(c, b.path) {
			continue
		}
		pol.s = newState(p, c)
		pol.localSearch()
		if pol.s.tot > b.tot {
			b.copyFrom(pol.s)
		}
	}
}
pol.s = b

@* 상계. 여기까지의 모든 장치는 하계를 밀어 올리는 것이었다---아무리 좋은
사슬을 찾아도 "이보다 좋은 사슬은 없다"는 말은 못 한다. 그 말을 하려면 상계가
필요하다. Cooke가 2473을 증명한 것도 일치하는 상계를 찾아서였다.

사슬의 제약을 조금 풀어 보자. 사슬에서 시작점은 나가는 간선 하나, 목표점은
들어오는 간선 하나를 쓰고, 중간 정점은 지나가거나(들고 남이 하나씩) 안
쓰거나다. 이 차수 제약만 남기고 "한 줄로 이어져야 한다"는 조건을 버리면,
최적해는 시작점에서 목표점으로 가는 경로 하나에 서로소인 순환 몇 개가 얹힌
꼴이 된다. 이 완화는 배정 문제(assignment problem)이므로 헝가리안 알고리즘으로
정확히---그리고 빨리---풀 수 있고, 사슬 자체도 완화의 해이므로 완화의 최적값은
참 최적값의 상계다.

완화 해에 양의 순환이 없으면 그 경로가 곧 완화 값을 통째로 달성하는 사슬이라
상계와 하계가 만난다(총점 0인 순환은 값에 보태는 게 없다). 양의 순환이 있으면?
사슬은 순환을 못 품으니 순환의 간선 $e_1,\ldots,e_m$ 가운데 적어도 하나는
버려야 한다. 그래서 "$e_k$를 금지하고 $e_1,\ldots,e_{k-1}$을 강제한다"는 부분
문제 $m$개로 갈라 치는 분지한정을 돌린다---빠지는 첫 간선의 번호로 가르므로
부분문제들이 서로소가 되는, 외판원 문제의 고전 수법이다. 상계가 가장 큰
노드부터 꺼내는 최선 우선 탐색이라 힙 꼭대기가 언제나 전체 문제의 유효한
상계이고, 시간이 다해 멈춰도 그때까지 좁혀진 상계를 정직하게 보고할 수 있다.

@ 분지한정의 노드는 금지·강제 간선 목록과, 그 제약 아래 완화 해의 후계 사상
|succ|·상계를 담는다. |bounder|는 문제와 기본 비용 행렬, 현직 하계를 든다.

@<자료 구조@>=
type bbNode struct {
	bound  int64
	banned [][2]int
	forced [][2]int
	succ   []int
}

type bounder struct {
	p       *problem
	rows    []int // 행 번호 → 정점 (목표점 제외)
	cols    []int // 열 번호 → 정점 (시작점 제외)
	rowOf   []int
	colOf   []int
	base    [][]int64
	inc     int64 // 현직 하계
	incPath []int
}

const forbid = int64(1) << 40

@ 상계 큰 노드가 먼저 나오는 최대 힙은 |container/heap|의 인터페이스 다섯
개로 만든다.

@<자료 구조@>=
type bbHeap []*bbNode

func (h bbHeap) Len() int           { return len(h) }
func (h bbHeap) Less(i, j int) bool { return h[i].bound > h[j].bound }
func (h bbHeap) Swap(i, j int)      { h[i], h[j] = h[j], h[i] }
func (h *bbHeap) Push(x any)        { *h = append(*h, x.(*bbNode)) }
func (h *bbHeap) Pop() any {
	old := *h
	n := len(old)
	x := old[n-1]
	*h = old[:n-1]
	return x
}

@ 비용 행렬의 행은 목표점 아닌 정점(나가는 간선을 고를 자), 열은 시작점 아닌
정점(들어오는 간선을 고를 자)이다. 중간 정점 |u|의 대각 원소는 값 0의 "안
쓴다" 선택지다. 시작점은 열에 없어 그 행에 대각 원소가 없으므로 반드시 진짜
간선을 골라야 하고, 목표점 열도 마찬가지다. 최대화를 최소화로 바꾸려고 부호를
뒤집고, 없는 간선은 |forbid|로 막는다.

@<행과 열의 사상과 기본 행렬을 만든다@>=
bd.rowOf = make([]int, p.n)
bd.colOf = make([]int, p.n)
for v := 0; v < p.n; v++ {
	bd.rowOf[v], bd.colOf[v] = -1, -1
	if v != p.goal {
		bd.rowOf[v] = len(bd.rows)
		bd.rows = append(bd.rows, v)
	}
	if v != p.start {
		bd.colOf[v] = len(bd.cols)
		bd.cols = append(bd.cols, v)
	}
}
bd.base = make([][]int64, len(bd.rows))
for r, uu := range bd.rows {
	bd.base[r] = make([]int64, len(bd.cols))
	for c, vv := range bd.cols {
		switch {
		case uu == vv:
			bd.base[r][c] = 0 // 안 쓴다
		case p.exists[uu][vv]:
			bd.base[r][c] = -p.del[uu][vv]
		default:
			bd.base[r][c] = forbid
		}
	}
}

@ 배정 문제는 포텐셜을 쓰는 $O(n^3)$ 헝가리안 알고리즘으로 푼다.
({\sc ASSIGN\_\,LISA} 데모에도 헝가리안이 있지만 그쪽은 직사각 행렬에 특화된
독립 프로그램이라, 여기서는 정방 행렬용의 짧은 판을 따로 둔다.) |match[j]|는
열 |j|를 맡은 행(1부터 셈)이고, 반환값은 행마다 맡은 열과 총비용이다.

@<상계 탐사@>=
func hungarian(a [][]int64) ([]int, int64) {
	n := len(a)
	const inf = int64(math.MaxInt64 / 8)
	u := make([]int64, n+1)
	v := make([]int64, n+1)
	match := make([]int, n+1)
	way := make([]int, n+1) // 증가 경로에서 이전 열
	minv := make([]int64, n+1)
	used := make([]bool, n+1)
	for i := 1; i <= n; i++ {
		@<행 |i|의 증가 경로를 찾아 배정을 갱신한다@>
	}
	res := make([]int, n)
	total := int64(0)
	for j := 1; j <= n; j++ {
		res[match[j]-1] = j - 1
		total += a[match[j]-1][j-1]
	}
	return res, total
}

@ 고전적인 포텐셜 갱신이다: 아직 안 쓴 열 가운데 여유 비용이 가장 작은 열로
옮겨 가고, 빈 열에 닿으면 |way|를 따라 배정을 되감는다.

@<행 |i|의 증가 경로를 찾아 배정을 갱신한다@>=
match[0] = i
j0 := 0
for j := 0; j <= n; j++ {
	minv[j] = inf
	used[j] = false
}
for {
	@<여유가 가장 작은 열로 한 걸음 나아간다@>
	if match[j0] == 0 {
		break
	}
}
@<|way|를 따라 배정을 되감는다@>

@ 지금 열 |j0|의 행 |i0|에서 아직 안 쓴 모든 열의 여유를 갱신하고, 여유가
가장 작은 열 |j1|만큼 포텐셜을 옮긴 뒤 그리로 나아간다.

@<여유가 가장 작은 열로 한 걸음 나아간다@>=
used[j0] = true
i0, j1, delta := match[j0], 0, inf
for j := 1; j <= n; j++ {
	if used[j] {
		continue
	}
	if cur := a[i0-1][j-1] - u[i0] - v[j]; cur < minv[j] {
		minv[j] = cur
		way[j] = j0
	}
	if minv[j] < delta {
		delta = minv[j]
		j1 = j
	}
}
for j := 0; j <= n; j++ {
	if used[j] {
		u[match[j]] += delta
		v[j] -= delta
	} else {
		minv[j] -= delta
	}
}
j0 = j1

@ 빈 열에 닿았으면 걸어온 길을 되짚으며 열마다 새 행을 배정한다.

@<|way|를 따라 배정을 되감는다@>=
for j0 != 0 {
	j1 := way[j0]
	match[j0] = match[j1]
	j0 = j1
}

@ 한 노드를 푼다: 기본 행렬을 복사해 금지·강제를 얹고 헝가리안을 돌린다.
강제 간선은 그 행의 다른 열과 그 열의 다른 행을 몽땅 금지하는 것으로
구현한다. 금지된 간선이 배정에 남았으면(총비용이 |forbid| 이상) 그 노드는
실행 불가능이다.

@<상계 탐사@>=
func (bd *bounder) solve(banned, forced [][2]int) *bbNode {
	m := make([][]int64, len(bd.base))
	for r := range m {
		m[r] = append([]int64(nil), bd.base[r]...)
	}
	for _, e := range banned {
		m[bd.rowOf[e[0]]][bd.colOf[e[1]]] = forbid
	}
	for _, e := range forced {
		r, c := bd.rowOf[e[0]], bd.colOf[e[1]]
		for cc := range m[r] {
			if cc != c {
				m[r][cc] = forbid
			}
		}
		for rr := range m {
			if rr != r {
				m[rr][c] = forbid
			}
		}
	}
	res, total := hungarian(m)
	if total >= forbid {
		return nil
	}
	succ := make([]int, bd.p.n)
	for r, uu := range bd.rows {
		succ[uu] = bd.cols[res[r]]
	}
	return &bbNode{bound: -total, banned: banned, forced: forced, succ: succ}
}

@ 완화 해에서 양의 순환을 찾는다. 경로 위의 정점과 안 쓴 정점(자기 자신을
가리키는)을 거르고 남는 것이 순환들이다. 분지 폭을 줄이려고 가장 짧은 양의
순환을 고른다.

@<상계 탐사@>=
func (bd *bounder) posCycle(succ []int) []int {
	p := bd.p
	seen := make([]bool, p.n)
	for v := p.start; v != p.goal; v = succ[v] {
		seen[v] = true
	}
	seen[p.goal] = true
	var best []int
	for s := 0; s < p.n; s++ {
		if seen[s] || succ[s] == s {
			continue
		}
		var cyc []int
		tot := int64(0)
		for v := s; !seen[v]; v = succ[v] {
			seen[v] = true
			cyc = append(cyc, v)
			tot += p.del[v][succ[v]]
		}
		if tot > 0 && (best == nil || len(cyc) < len(best)) {
			best = cyc
		}
	}
	return best
}

@ 탐사의 몸통이다. 힙이 비거나 꼭대기의 상계가 하계에 닿으면 하계의 사슬이
최적임이 증명된 것이고, 시간이 다하면 그때의 상계를 보고한다.

@<상계 탐사@>=
func upperBound(p *problem, chain []int, limit time.Duration) (int64, int64, []int, int, bool) {
	bd := &bounder{p: p, inc: p.total(chain), incPath: append([]int(nil), chain...)}
	@<행과 열의 사상과 기본 행렬을 만든다@>
	root := bd.solve(nil, nil)
	fmt.Printf("배정 완화의 상계: %d\n", root.bound)
	h := &bbHeap{root}
	heap.Init(h)
	nodes := 0
	proven := false
	deadline := time.Now().Add(limit)
	for h.Len() > 0 {
		if time.Now().After(deadline) {
			break
		}
		nd := heap.Pop(h).(*bbNode)
		if nd.bound <= bd.inc {
			proven = true
			break
		}
		nodes++
		@<양의 순환이 없으면 하계를 올리고, 있으면 분지한다@>
	}
	ub := bd.inc
	if !proven && h.Len() > 0 {
		if top := (*h)[0].bound; top > ub {
			ub = top
		}
	} else {
		proven = true
	}
	return ub, bd.inc, bd.incPath, nodes, proven
}

@ 순환이 없는 노드의 경로는 상계값을 통째로 달성하는 진짜 사슬이므로 하계
후보가 되고, 그 노드는 끝난 것이다. 순환이 있으면 간선마다 부분문제를 만들어,
실행 가능하고 하계보다 나은 것만 힙에 넣는다.

@<양의 순환이 없으면 하계를 올리고, 있으면 분지한다@>=
cyc := bd.posCycle(nd.succ)
if cyc == nil {
	if nd.bound > bd.inc {
		bd.inc = nd.bound
		bd.incPath = bd.incPath[:0]
		for v := p.start; ; v = nd.succ[v] {
			bd.incPath = append(bd.incPath, v)
			if v == p.goal {
				break
			}
		}
	}
	continue
}
for k := range cyc {
	banned := append(append([][2]int(nil), nd.banned...),
		[2]int{cyc[k], cyc[(k+1)%len(cyc)]})
	forced := append([][2]int(nil), nd.forced...)
	for j := 0; j < k; j++ {
		forced = append(forced, [2]int{cyc[j], cyc[j+1]})
	}
	if child := bd.solve(banned, forced); child != nil && child.bound > bd.inc {
		heap.Push(h, child)
	}
}

@ 주 프로그램에서는 휴리스틱이 찾은 사슬을 현직 하계 삼아 탐사를 건다.
분지한정이 그보다 좋은 사슬을 만났으면 그것도 자랑스레 찍는다.

성적표가 이 프로그램의 대단원이다: 스탠퍼드$\to$하버드는 353노드 만에 2473이,
하버드$\to$스탠퍼드는 51노드 만에 2358이, 펜실베이니아 주립$\to$컬럼비아는 단
한 노드 만에 2542가 증명됐다---세 판 모두 일 초 안이고, Cooke가 발표한 세
최적값과 정확히 일치하며, 최적 사슬 자체도 분지한정이 직접 찾아냈다. 온갖
교란으로도 다섯 점이 모자라던 자리를 배정 완화와 헝가리안 알고리즘이 단숨에
넘어선 셈이다. 배정 완화의 뿌리 상계부터 2498(참값과 25점 차)로 날카로웠으니,
애초에 이 문제의 어려움은 우리가 생각한 것보다 훨씬 작았던 것이다.

@<상계를 탐사해 찍는다@>=
if *ubound > 0 {
	ub, lb, lbChain, nodes, proven := upperBound(p, b.path, *ubound)
	if lb > b.tot {
		fmt.Println("분지한정이 하계도 올렸다:")
		for _, v := range lbChain {
			fmt.Printf(" %s", p.names[v])
		}
		fmt.Println()
	}
	verdict := "증명은 미완"
	if proven {
		verdict = "하계의 사슬이 최적임이 증명됐다"
	}
	fmt.Printf("상계 %d, 하계 %d (%d 노드, %s).\n", ub, lb, nodes, verdict)
}

@* 주 프로그램. 일꾼들을 고루틴으로 풀어놓는다. 홀수 번째 일꾼은 탐험가다.
일꾼마다 |problem|을 복제해 주어, 저마다의 간선 금기가 남에게 새지 않게 한다.

@<일꾼들을 풀어 탐색한다@>=
sh := &shared{}
var wg sync.WaitGroup
for w := 0; w < *workers; w++ {
	wg.Add(1)
	go func(id int) {
		defer wg.Done()
		wp := p.clone()
		rng := rand.New(rand.NewPCG(*seed, uint64(id)))
		s := newState(wp, wp.randomPath(rng))
		sr := &searcher{p: wp, s: s, best: newState(wp, s.path), rng: rng,
			sh: sh, explorer: id%2 == 1}
		sr.run(deadline)
	}(w)
}
wg.Wait()

@ 최종 연마: 전역 최고해에 큰 창(14--22)·고예산 수선을 개선이 멎을 때까지 건다.
최적 근처에서는 상한이 세게 가지를 치므로 큰 창도 감당이 된다.

@<최고 사슬을 연마한다@>=
bp, _ := sh.snapshot()
b := newState(p, bp)
pol := &searcher{p: p, s: b, best: newState(p, b.path),
	rng: rand.New(rand.NewPCG(*seed, 999)), sh: sh}
@<엘리트들을 재연결해 출발점을 고른다@>
for {
	improved := false
	for w := 14; w <= 22; w += 2 {
		if pol.improveLNSSweep(w, 20_000_000) {
			pol.localSearch()
			improved = true
		}
	}
	if !improved {
		break
	}
}
b = pol.s

@ 답이 참말 단순 사슬인지---정점이 겹치지 않고, 간선이 실제 있고, 합이 맞는지%
--- 기계적으로 검사한 뒤 찍는다.
@<결과를 검사하고 찍는다@>=
seen := make(map[int]bool)
for k, v := range b.path {
	if seen[v] {
		log.Fatalf("정점 %s 중복!", p.names[v])
	}
	seen[v] = true
	if k+1 < len(b.path) && !p.exists[v][b.path[k+1]] {
		log.Fatalf("없는 간선 %s-%s!", p.names[v], p.names[b.path[k+1]])
	}
}
if p.total(b.path) != b.tot {
	log.Fatalf("합이 안 맞다: %d != %d", p.total(b.path), b.tot)
}
fmt.Printf("%s → %s: 최고 %+d (사슬 길이 %d경기)\n",
	*from, *to, b.tot, len(b.path)-1)
if *chain {
	var run int64
	for k := 0; k+1 < len(b.path); k++ {
		u, v := b.path[k], b.path[k+1]
		run += p.del[u][v]
		@<경기 하나를 |football|과 같은 꼴로 찍는다@>
	}
}

@ 사슬의 각 경기를 {\sc FOOTBALL} 데모와 똑같은 꼴로 찍는다: 날짜에 이어
앞 팀 |u|와 뒤 팀 |v|의 이름·별명·점수, 그리고 괄호 안에 사슬을 따라 쌓인
점수 차 |run|이다. 최장 경로라 |u|가 진 경기도 사슬에 들 수 있어 |run|이 잠깐
줄기도 한다.

@<경기 하나를 |football|과 같은 꼴로 찍는다@>=
d := p.date[u][v]
@<날짜 |d|를 달 이름 |mon|과 날 |day|로 옮긴다@>
fmt.Printf(" %s %02d: %s %s %d, %s %s %d (%+d)\n",
	mon, day,
	p.names[u], p.nick[u], p.uScore[u][v],
	p.names[v], p.nick[v], p.vScore[u][v], run)

@ 0일은 8월 26일이다. 날짜 |d|를 달 이름과 그달의 날로 옮긴다({\sc FOOTBALL}과
같은 셈이다).

@<날짜 |d|를 달 이름 |mon|과 날 |day|로 옮긴다@>=
var mon string
var day int64
switch {
case d <= 5:
	mon, day = "Aug", d+26
case d <= 35:
	mon, day = "Sep", d-5
case d <= 66:
	mon, day = "Oct", d-35
case d <= 96:
	mon, day = "Nov", d-66
case d <= 127:
	mon, day = "Dec", d-96
default:
	mon, day = "Jan", 1 // |d=128|
}

@* 찾아보기.
