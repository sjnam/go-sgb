% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_games.w를 Go로 이식한다.
@i ../types.w

\input kotexgweb
\def\title{GB\_\,GAMES}

@* 들어가며. 이 모듈은 미국 대학 미식축구 점수에 바탕한 무향 그래프 집안을 짓는
|Games| 서브루틴을 담는다. 쓰임새는 {\sc FOOTBALL} 데모에서 볼 수 있다.

|Games(n, ap0Weight, upi0Weight, ap1Weight, upi1Weight, firstDay, lastDay, seed, dir)|은
\.{games.dat}의 정보로 그래프를 짓는다. 각 정점은 미국 대학의 미식축구 팀
120개(\\{I-A} 106팀에 아이비리그와 패트리엇리그의 \\{I-AA} 14팀을 더한 것)
가운데 하나이고, 각 간선은 1990년 시즌에 그 팀들이 치른 638경기 가운데 하나다.

@ |u|에서 |v|로 가는 호에는 |u|가 |v|와 겨뤄 낸 점수가 길이로 매겨진다. 그래서
이 그래프는 사실 완전한 ``무향''은 아니지만, 호는 짝을 이룬다(|u|가 |v|와 겨뤘다면
|v|도 |u|와 겨뤘다). {\sc GB\_BASIC}의 |Complement|를 쓰면 같은 정점·간선의 참된
무향 그래프를 얻는다.

그래프는 $\min(n,120)$개의 정점을 갖는다. |n|이 120보다 작으면 각 팀에 무게를
매겨 가장 무거운 |n|개를 고르고, 무게가 같으면 난수로 가른다. 무게는
$$|ap0Weight|\cdot|ap0|+|upi0Weight|\cdot|upi0|
   +|ap1Weight|\cdot|ap1|+|upi1Weight|\cdot|upi1|$$
로 셈한다. |ap0|·|upi0|은 시즌 초 \\{AP}(Associated Press)와 \\{UPI}(United
Press International) 여론조사 점수이고, |ap1|·|upi1|은 시즌 끝 점수다. 네 무게
계수는 절댓값이 $2^{17}=131072$ 이하여야 한다.

@ |firstDay|과 |lastDay| 사이(양끝 포함)에 치른 경기만 간선으로 넣어 간선 수를
조절할 수 있다. 0일은 1990년 8월 26일, 128일은 1991년 1월 1일(마지막 보울
경기)이다. |lastDay|가 0이면 128로 올린다. 여느 GraphBase 루틴처럼 $n=0$은 최대치
120을 뜻한다. 이를테면 |Games(53,1,1,1,1,0,0,0)|은 어느 여론조사에서든 한 번은
뽑힌 53팀을, |Games(67,-1,-1,-1,-1,0,0,0)|은 한 번도 안 뽑힌 67팀을 고른다.

@ 프로그램의 뼈대다. \CEE/ 원본은 정적 전역 |node_block|·|hash_block|·
|conf_block|에 기대지만, 우리는 패키지 수준 가변 상태를 피해 이들을
|gamesBuilder| 구조체에 담는다. 해시 코드 대신 \GO/의 |map|을 쓴다.
@d DataInputDirectory
@c
package gbgames

import (
	"fmt"
	"path/filepath"
	"strings"
	@#
	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/gbsort"
)

const DataInputDirectory = "/usr/local/sgb/data"

@<상수 정의@>@;
@<자료 구조@>@;
@<|Games| 함수@>@;
@<그래프를 짓는 도우미들@>@;

@ 자료에서 관찰된 상한들이다. |ma0|·|mu0|·|ma1|·|mu1|은 각 여론조사 점수의
최댓값으로, 자료가 망가졌는지 살피는 데 쓴다. 호의 |venue|(|A.I|)는 |home|이면
|v|가 홈팀, |away|이면 |u|가 홈팀, |neutral|이면 중립 경기장이다.
@d maxN maxDay maxWeight
@<상수 정의@>=
const (
	maxN       = 120     // 팀 수
	maxDay     = 128     // 마지막 경기일
	maxWeight  = 131072  // $2^{17}$, 무게 계수의 절댓값 상한
	weightBias = 1 << 30 // 무게를 음이 아닌 정렬 키로 만드는 치우침
	home       = 1       // |v|가 홈팀
	neutral    = 2       // 중립 경기장(|home|과 |away|의 한가운데)
	away       = 3       // |u|가 홈팀
	ma0        = 1451    // 시즌 초 \\{AP} 점수 최댓값
	mu0        = 666     // 시즌 초 \\{UPI} 점수 최댓값
	ma1        = 1475    // 시즌 끝 \\{AP} 점수 최댓값
	mu1        = 847     // 시즌 끝 \\{UPI} 점수 최댓값
)

@ 팀 하나를 |teamInfo|로 나타낸다. 이것을 |gbsort.Node|의 딸림 데이터로 실어
무게순 정렬에 부친다. |a0|·|u0|·|a1|·|u1|은 여론조사 점수, |conf|는 소속
컨퍼런스 이름(독립이면 빈 문자열), |vert|는 이 팀에 배정된 정점이다.

@<자료 구조@>=
type teamInfo struct {
	name, nick, abb string
	a0, u0, a1, u1  int64
	conf            string
	vert            *gbgraph.Vertex
}

@ |gamesBuilder|는 짓고 있는 그래프와 작업 상태를 한데 묶는다. |nodes|는 용량을
|maxN+2|로 미리 잡아, 뒤에 원소를 더해도 재할당되지 않게 한다 --- 그래야
|lookup|이 담은 포인터가 그대로 유효하다. |lookup|은 약칭(\.{ABBR}) 코드로 노드를
찾는 map이다.

@<자료 구조@>=
type gamesBuilder struct {
	g      *gbgraph.Graph
	rng    *gbflip.RNG
	nodes  []gbsort.Node[teamInfo]
	lookup map[string]*gbsort.Node[teamInfo]

	fileName string
	seed     int64
	n, ap0Weight, upi0Weight, ap1Weight, upi1Weight, firstDay, lastDay int64
}

@ 함수 |Games|는 씨앗으로 난수 스트림을 열고, 매개변수를 다듬고, 자료 파일을 한 번
훑어 그래프를 짓는다. 파일의 앞 120줄은 팀 정보, 나머지는 경기 점수다.

@<|Games|...@>=
// |Games|는 대학 미식축구 점수를 무향 그래프로 짓는다.
func Games(n, ap0Weight, upi0Weight, ap1Weight, upi1Weight,
	firstDay, lastDay, seed int64, dir string) (*gbgraph.Graph, error) {
	b := &gamesBuilder{
		rng:        gbflip.New(seed),
		seed:       seed,
		nodes:      make([]gbsort.Node[teamInfo], 0, maxN+2),
		lookup:     make(map[string]*gbsort.Node[teamInfo]),
		n:          n,
		ap0Weight:  ap0Weight,
		upi0Weight: upi0Weight,
		ap1Weight:  ap1Weight,
		upi1Weight: upi1Weight,
		firstDay:   firstDay,
		lastDay:    lastDay,
	}
	if dir == "" {
		dir = DataInputDirectory
	}
	b.fileName = filepath.Join(dir, "games.dat")
	@<매개변수가 올바른지 확인한다@>@;
	@<파일을 열어 그래프를 짓는다@>@;
	return b.g, nil
}

@ |n==0|이거나 120을 넘으면 120으로, |firstDay<0|이면 0으로, |lastDay==0|이거나
128을 넘으면 128로 바로잡는다. 무게 계수가 너무 크면 물러난다.

@<매개변수가 올바른지 확인한다@>=
if b.n == 0 || b.n > maxN {
	b.n = maxN
}
if b.ap0Weight > maxWeight || b.ap0Weight < -maxWeight ||
	b.upi0Weight > maxWeight || b.upi0Weight < -maxWeight ||
	b.ap1Weight > maxWeight || b.ap1Weight < -maxWeight ||
	b.upi1Weight > maxWeight || b.upi1Weight < -maxWeight {
	return nil, gbgraph.BadSpecs // 무게가 너무 크다
}
if b.firstDay < 0 {
	b.firstDay = 0
}
if b.lastDay == 0 || b.lastDay > maxDay {
	b.lastDay = maxDay
}

@ 파일을 열고, 팀을 읽고, 그래프를 마련한 뒤 간선을 넣고 파일을 닫는다.

@<파일을 열어 그래프를 짓는다@>=
f, err := gbio.Open(b.fileName)
if err != nil {
	return nil, gbgraph.EarlyDataFault // 파일을 열 수 없다
}
if err := b.readTeams(f); err != nil {
	return nil, err
}
@<빈 그래프를 마련하고 팀을 고른다@>@;
if err := b.readGames(f); err != nil {
	return nil, err
}
if f.Close() != nil {
	return nil, gbgraph.LateDataFault // 검사합 등 실패
}

@* 정점. 자료를 읽으며 팀마다 노드를 만든다. 각 노드는 팀 이름·별명·컨퍼런스와
무게를 담는다. 무게순으로 정렬한 뒤 위 |n|개가 새 그래프의 정점이 된다.

|readTeams|는 앞 120줄을 읽어 노드를 만들고, 무게(정렬 키)를 셈해 리스트로 엮는다.
정렬 리스트는 \CEE/처럼 마지막 노드가 머리이고 |Link|가 앞 노드를 가리키게 한다.

@<그래프를 짓는 도우미들@>=
func (b *gamesBuilder) readTeams(f *gbio.File) error {
	for k := 0; k < maxN; k++ {
		if err := b.readTeam(f); err != nil {
			return err
		}
	}
	return nil
}

@ 팀 자료 한 줄의 꼴은
$$\hbox{\tt ABBR College Name(Team Nickname)Conference;a0,u0;a1,u1}$$
이다. \.{ABBR}은 둘째 부분에서 팀을 가리키는 내부 약칭이다.

@<그래프를 짓는 도우미들@>=
func (b *gamesBuilder) readTeam(f *gbio.File) error {
	var t teamInfo
	@<약칭·이름·별명·컨퍼런스를 읽는다@>@;
	@<여론조사 점수를 읽고 무게를 셈한다@>@;
	@<노드를 만들어 리스트와 map에 엮는다@>@;
	f.NextLine()
	return nil
}

@ 약칭은 빈칸까지, 이름은 |'('|까지, 별명은 |')'|까지, 컨퍼런스는 |';'|까지
읽는다. 컨퍼런스가 |"Independent"|이면 빈 문자열로 둔다.

@<약칭·이름·별명·컨퍼런스를 읽는다@>=
t.abb = f.String(' ')
if len(t.abb) > 5 || f.Char() != ' ' {
	return gbgraph.SyntaxError // 자료가 어긋났다
}
t.name = f.String('(')
if len(t.name) > 23 || f.Char() != '(' {
	return gbgraph.SyntaxError + 1 // 팀 이름이 너무 길다
}
t.nick = f.String(')')
if len(t.nick) > 21 || f.Char() != ')' {
	return gbgraph.SyntaxError + 2 // 별명이 너무 길다
}
t.conf = f.String(';')
if f.Char() != ';' {
	return gbgraph.SyntaxError + 3 // 컨퍼런스 이름이 망가졌다
}
if t.conf == "Independent" {
	t.conf = ""
}

@ 네 점수는 |','|와 |';'|로 갈린다. 각 점수가 관찰된 최댓값을 넘거나 구분자가
어긋나면 물러난다. 무게에 |weightBias|를 더해 음이 아닌 정렬 키로 만든다.

@<여론조사 점수를 읽고 무게를 셈한다@>=
t.a0 = f.Number(10)
if t.a0 > ma0 || f.Char() != ',' {
	return gbgraph.SyntaxError + 4
}
t.u0 = f.Number(10)
if t.u0 > mu0 || f.Char() != ';' {
	return gbgraph.SyntaxError + 5
}
t.a1 = f.Number(10)
if t.a1 > ma1 || f.Char() != ',' {
	return gbgraph.SyntaxError + 6
}
t.u1 = f.Number(10)
if t.u1 > mu1 || f.Char() != '\n' {
	return gbgraph.SyntaxError + 7
}
key := b.ap0Weight*t.a0 + b.upi0Weight*t.u0 +
	b.ap1Weight*t.a1 + b.upi1Weight*t.u1 + weightBias

@ 노드를 만들어 |nodes| 리스트 끝에 붙이고, |Link|로 앞 노드를 가리키게 하고,
약칭을 열쇠로 map에 넣는다.

@<노드를 만들어 리스트와 map에 엮는다@>=
b.nodes = append(b.nodes, gbsort.Node[teamInfo]{Key: key, Data: t})
i := len(b.nodes) - 1
if i > 0 {
	b.nodes[i].Link = &b.nodes[i-1]
}
b.lookup[t.abb] = &b.nodes[i]

@ 그래프를 마련할 차례다. 정점 수 |n|의 빈 그래프를 짓고, 표식과 |UtilTypes|를
못박는다. |"IIZSSSIIZZZZZZ"|는 정점의 |U.I|에 |ap|($($|a0|$\ll16)+$|a1|$)$,
|V.I|에 |upi|, |X.S|에 |abbr|, |Y.S|에 |nickname|, |Z.S|에 |conference|를,
호의 |A.I|에 |venue|, |B.I|에 |date|를 둔다는 뜻이다.

@<빈 그래프를 마련하고 팀을 고른다@>=
b.g = gbgraph.NewGraph(b.n)
b.g.UtilTypes = "IIZSSSIIZZZZZZ"
b.g.ID = fmt.Sprintf("games(%d,%d,%d,%d,%d,%d,%d,%d)",
	b.n, b.ap0Weight, b.upi0Weight, b.ap1Weight, b.upi1Weight,
	b.firstDay, b.lastDay, b.seed)
@<무게순으로 정렬해 위 |n|개 팀에 정점을 배정한다@>@;

@ |gbsort.LinkSort|로 128개 통에 정렬한 뒤, 무게가 큰 차례로 훑어 앞 |n|개 팀에
정점을 배정한다. 고르지 못한 팀은 |vert|가 |nil|로 남아, 아래에서 간선을 만들 때
걸러진다.

@<무게순으로 정렬해 위 |n|개 팀에 정점을 배정한다@>=
buckets := gbsort.LinkSort(&b.nodes[maxN-1], b.rng)
vi := int64(0)
Outer:
for j := 127; j >= 0; j-- {
	for p := buckets[j]; p != nil; p = p.Link {
		if vi >= b.n {
			break Outer
		}
		b.addTeam(&b.g.Vertices[vi], p)
		vi++
	}
}

@ 팀 |p|를 정점 |v|에 배정한다: 여론조사 점수를 |ap|·|upi|로 꾸리고, 약칭·별명·
컨퍼런스·이름을 옮기고, |vert|를 |v|로 둔다.

@<그래프를 짓는 도우미들@>=
func (b *gamesBuilder) addTeam(v *gbgraph.Vertex, p *gbsort.Node[teamInfo]) {
	d := &p.Data
	v.U.I = (d.a0 << 16) + d.a1 // |ap|
	v.V.I = (d.u0 << 16) + d.u1 // |upi|
	v.X.S = d.abb               // |abbr|
	v.Y.S = d.nick              // |nickname|
	v.Z.S = d.conf              // |conference|
	v.Name = d.name
	d.vert = v
}

@* 호. 끝으로 \.{games.dat}의 나머지를 읽어, 고른 시간 구간에 놓이고 고른 두 팀이
치른 경기마다 호 한 쌍을 더한다.

|readGames|는 파일이 끝날 때까지 경기 줄을 읽는다. |'>'|로 시작하는 줄은 현재
날짜를 바꾼다.

@<그래프를 짓는 도우미들@>=
func (b *gamesBuilder) readGames(f *gbio.File) error {
	today := int64(0)
	for !f.EOF() {
		if f.Char() == '>' {
			if err := b.changeDate(f, &today); err != nil {
				return err
			}
		} else {
			f.Backup()
		}
		if err := b.readOneGame(f, today); err != nil {
			return err
		}
		f.NextLine()
	}
	return nil
}

@ 날짜 줄은 한 글자 월 코드에 그달의 날을 붙인 것이다. 코드를 시즌 일수로 옮기고
날을 더한다. 이 절은 다음 경기 줄을 읽을 채비까지 마친다(|NextLine|).

@<그래프를 짓는 도우미들@>=
func (b *gamesBuilder) changeDate(f *gbio.File, today *int64) error {
	var d int64
	switch f.Char() { // 월 코드
	case 'A':
		d = -26 // 8월
	case 'S':
		d = 5 // 9월
	case 'O':
		d = 35 // 10월
	case 'N':
		d = 66 // 11월
	case 'D':
		d = 96 // 12월
	case 'J':
		d = 127 // 1월
	default:
		d = 1000
	}
	d += f.Number(10)
	if d < 0 || d > maxDay {
		return gbgraph.SyntaxError - 1 // 날짜가 망가졌다
	}
	*today = d
	f.NextLine() // 이제 날짜 아닌 줄을 읽을 채비가 됐다
	return nil
}

@ 경기 줄 하나는 두 팀의 약칭과 점수를 담는다. 점수 사이의 |'@@'|는 둘째 팀이
홈팀임을, |','|는 중립 경기임을 뜻한다. 두 팀이 다 고른 팀이고 날짜가 구간 안이면
간선을 넣는다.

@<그래프를 짓는 도우미들@>=
func (b *gamesBuilder) readOneGame(f *gbio.File, today int64) error {
	u := b.teamLookup(f)
	su := f.Number(10)
	var venue int64
	switch f.Char() {
	case '@@':
		venue = home
	case ',':
		venue = neutral
	default:
		return gbgraph.SyntaxError + 8 // 경기 줄 문법 오류
	}
	v := b.teamLookup(f)
	sv := f.Number(10)
	if f.Char() != '\n' {
		return gbgraph.SyntaxError + 9 // 경기 줄 문법 오류
	}
	if u != nil && v != nil && today >= b.firstDay && today <= b.lastDay {
		b.newGame(u, v, su, sv, venue, today)
	}
	return nil
}

@ 약칭을 읽어 정점을 찾는다. 숫자(점수)를 만날 때까지 글자를 모으고, 그 숫자는
되돌려 놓는다. 고르지 못한 팀이거나 모르는 약칭이면 |nil|을 준다.

@<그래프를 짓는 도우미들@>=
func (b *gamesBuilder) teamLookup(f *gbio.File) *gbgraph.Vertex {
	var sb strings.Builder
	for f.Digit(10) < 0 {
		sb.WriteByte(f.Char())
	}
	f.Backup() // 약칭 뒤 숫자를 다시 읽도록 물러선다
	if p := b.lookup[sb.String()]; p != nil {
		return p.Data.vert
	}
	return nil
}

@ 간선을 이루는 두 호를 만든다. |u|에서 |v|로 가는 호의 길이는 |su|, 그 짝의 길이는
|sv|다. |venue|와 |date|를 두 호에 적는다. \CEE/ 원본은 |edge_trick|을 위해 |u<v|가
되도록 두 팀을 맞바꾸지만, 우리는 |Partner| 필드로 짝을 밝히므로 맞바꿀 필요가 없다.

@<그래프를 짓는 도우미들@>=
func (b *gamesBuilder) newGame(u, v *gbgraph.Vertex, su, sv, venue, today int64) {
	b.g.NewEdge(u, v, su)
	a := u.Arcs // 방금 만든 |u|에서 |v|로 가는 호
	a.Partner.Len = sv
	a.A.I = venue                 // |venue|
	a.Partner.A.I = home + away - venue
	a.B.I, a.Partner.B.I = today, today // |date|
}

@* 시험. 기본 |Games(0,0,0,0,0,0,0,0)|은 120팀 638경기를 모두 담는다. Knuth의
발표값과 대조한다.

@(gbgames_test.go@>=
package gbgames

import "testing"

const dataDir = "../data"

@<전체 그래프 시험@>@;
@<팀 선택 시험@>@;
@<호 필드 시험@>@;

@ |Games(0,0,0,0,0,0,0,0)|은 정점 120개, 간선 638개짜리 그래프를 짓는다. 표식과
정점·간선 수를 확인한다. |lastDay|는 0에서 128로 올라가야 한다.

@<전체 그래프 시험@>=
func TestFullGraph(t *testing.T) {
	g, err := Games(0, 0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 120 {
		t.Fatalf("N = %d, 원함 120", g.N)
	}
	if g.M != 2*638 {
		t.Errorf("M = %d, 원함 %d", g.M, 2*638)
	}
	if g.ID != "games(120,0,0,0,0,0,128,0)" {
		t.Errorf("ID = %q", g.ID)
	}
}

@ |firstDay=50|으로 시즌 후반만 담으면 간선이 줄어든다.

@<전체 그래프 시험@>=
func TestLatterHalf(t *testing.T) {
	full, err := Games(0, 0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	half, err := Games(0, 0, 0, 0, 0, 50, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if half.M >= full.M {
		t.Errorf("후반 간선이 안 줄었다: %d >= %d", half.M, full.M)
	}
	if half.ID != "games(120,0,0,0,0,50,128,0)" {
		t.Errorf("ID = %q", half.ID)
	}
}

@ 무게를 주면 여론조사에 뽑힌 팀만 고를 수 있다. |Games(53,1,1,1,1,0,0,0)|은
한 번은 뽑힌 53팀을, |Games(67,-1,-1,-1,-1,0,0,0)|은 안 뽑힌 67팀을 낸다.

@<팀 선택 시험@>=
func TestSelectByVotes(t *testing.T) {
	g, err := Games(53, 1, 1, 1, 1, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 53 {
		t.Fatalf("N = %d, 원함 53", g.N)
	}
	g2, err := Games(67, -1, -1, -1, -1, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g2.N != 67 {
		t.Fatalf("N = %d, 원함 67", g2.N)
	}
}

@ 고른 팀에는 약칭·별명·컨퍼런스와 여론조사 점수가 채워져야 한다.

@<팀 선택 시험@>=
func TestVertexFields(t *testing.T) {
	g, err := Games(30, 0, 0, 1, 2, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.N != 30 {
		t.Fatalf("N = %d, 원함 30", g.N)
	}
	for i := int64(0); i < g.N; i++ {
		v := &g.Vertices[i]
		if v.Name == "" || v.X.S == "" || v.Y.S == "" {
			t.Fatalf("정점 %d의 이름/약칭/별명이 비었다", i)
		}
	}
}

@ 각 호의 |venue|는 |home|·|neutral|·|away| 가운데 하나여야 하고, 짝의 |venue|는
|home+away|에서 뺀 값이어야 한다. |date|는 두 짝이 같아야 한다.

@<호 필드 시험@>=
func TestArcFields(t *testing.T) {
	g, err := Games(0, 0, 0, 0, 0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	v := &g.Vertices[0]
	for a := v.Arcs; a != nil; a = a.Next {
		if a.A.I < home || a.A.I > away {
			t.Fatalf("venue = %d, 범위 밖", a.A.I)
		}
		if a.A.I+a.Partner.A.I != home+away {
			t.Errorf("짝의 venue가 어긋났다: %d, %d", a.A.I, a.Partner.A.I)
		}
		if a.B.I != a.Partner.B.I {
			t.Errorf("짝의 date가 다르다: %d, %d", a.B.I, a.Partner.B.I)
		}
	}
}

@* 찾아보기.
