//line gbgames.w:85
package gbgames

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/gbsort"
)

//line gbgames.w:108
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

//line gbgames.w:126
type teamInfo struct {
	name, nick, abb string
	a0, u0, a1, u1  int64
	conf            string
	vert            *gbgraph.Vertex
}

//line gbgames.w:138
type gamesBuilder struct {
	g      *gbgraph.Graph
	rng    *gbflip.RNG
	nodes  []gbsort.Node[teamInfo]
	lookup map[string]*gbsort.Node[teamInfo]

	fileName                                                           string
	seed                                                               int64
	n, ap0Weight, upi0Weight, ap1Weight, upi1Weight, firstDay, lastDay int64
}

//line gbgames.w:159
func Games(n, ap0Weight, upi0Weight, ap1Weight, upi1Weight,
	firstDay, lastDay, seed int64, dir string) (*gbgraph.Graph, error) {
	return GamesRNG(n, ap0Weight, upi0Weight, ap1Weight, upi1Weight,
		firstDay, lastDay, seed, gbflip.New(seed), dir)
}

//line gbgames.w:167
func GamesRNG(n, ap0Weight, upi0Weight, ap1Weight, upi1Weight,
	firstDay, lastDay, seed int64, rng *gbflip.RNG, dir string) (*gbgraph.Graph, error) {
	b := &gamesBuilder{
		rng:        rng,
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

	b.fileName = filepath.Join(dir, "games.dat")

//line gbgames.w:192
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

//line gbgames.w:185

//line gbgames.w:210
	f, err := gbio.Open(b.fileName)
	if err != nil {
		return nil, gbgraph.EarlyDataFault // 파일을 열 수 없다
	}
	if err := b.readTeams(f); err != nil {
		return nil, err
	}

//line gbgames.w:315
	b.g = gbgraph.NewGraph(b.n)
	b.g.UtilTypes = "IIZSSSIIZZZZZZ"
	b.g.ID = fmt.Sprintf("games(%d,%d,%d,%d,%d,%d,%d,%d)",
		b.n, b.ap0Weight, b.upi0Weight, b.ap1Weight, b.upi1Weight,
		b.firstDay, b.lastDay, b.seed)

//line gbgames.w:327
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

//line gbgames.w:218
	if err := b.readGames(f); err != nil {
		return nil, err
	}
	if f.Close() != nil {
		return nil, gbgraph.LateDataFault // 검사합 등 실패
	}

//line gbgames.w:186
	return b.g, nil
}

//line gbgames.w:231
func (b *gamesBuilder) readTeams(f *gbio.File) error {
	for k := 0; k < maxN; k++ {
		if err := b.readTeam(f); err != nil {
			return err
		}
	}
	return nil
}

//line gbgames.w:245
func (b *gamesBuilder) readTeam(f *gbio.File) error {
	var t teamInfo

//line gbgames.w:257
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

//line gbgames.w:248

//line gbgames.w:281
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

//line gbgames.w:249

//line gbgames.w:303
	b.nodes = append(b.nodes, gbsort.Node[teamInfo]{Key: key, Data: t})
	i := len(b.nodes) - 1
	if i > 0 {
		b.nodes[i].Link = &b.nodes[i-1]
	}
	b.lookup[t.abb] = &b.nodes[i]

//line gbgames.w:250
	f.NextLine()
	return nil
}

//line gbgames.w:343
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

//line gbgames.w:375
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

//line gbgames.w:396
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

//line gbgames.w:427
func (b *gamesBuilder) readOneGame(f *gbio.File, today int64) error {
	u := b.teamLookup(f)
	su := f.Number(10)
	var venue int64
	switch f.Char() {
	case '@':
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

//line gbgames.w:453
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

//line gbgames.w:469
func (b *gamesBuilder) newGame(u, v *gbgraph.Vertex, su, sv, venue, today int64) {
	b.g.NewEdge(u, v, su)
	a := u.Arcs // 방금 만든 |u|에서 |v|로 가는 호
	a.Partner.Len = sv
	a.A.I = venue // |venue|
	a.Partner.A.I = home + away - venue
	a.B.I, a.Partner.B.I = today, today // |date|
}
