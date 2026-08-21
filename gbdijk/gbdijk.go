//line gbdijk.w:40
package gbdijk

import (
	"fmt"
	"io"

	"github.com/sjnam/go-sgb/gbgraph"
)

//line gbdijk.w:253
type PriorityQueue interface {
	Init(d int64)
	Enqueue(v *gbgraph.Vertex, d int64)
	Requeue(v *gbgraph.Vertex, d int64)
	DelMin() *gbgraph.Vertex
}

//line gbdijk.w:266
func llink(v *gbgraph.Vertex) *gbgraph.Vertex { return v.V.V }

//line gbdijk.w:267
func rlink(v *gbgraph.Vertex) *gbgraph.Vertex { return v.W.V }

//line gbdijk.w:268
func setLlink(v, x *gbgraph.Vertex) { v.V.V = x }

//line gbdijk.w:269
func setRlink(v, x *gbgraph.Vertex) { v.W.V = x }

func insertRight(t, v *gbgraph.Vertex) { // |v|를 |t|와 그 |rlink| 사이에
	r := rlink(t)
	setLlink(v, t)
	setRlink(v, r)
	setLlink(r, v)
	setRlink(t, v)
}

func insertLeft(u, v *gbgraph.Vertex) { // |v|를 |u|의 |llink|와 |u| 사이에
	l := llink(u)
	setLlink(v, l)
	setRlink(l, v)
	setRlink(v, u)
	setLlink(u, v)
}

func unlink(v *gbgraph.Vertex) { // |v|를 두 이웃으로부터 떼어낸다
	setRlink(llink(v), rlink(v))
	setLlink(rlink(v), llink(v))
}

//line gbdijk.w:109
func Dijkstra(uu, vv *gbgraph.Vertex, gg *gbgraph.Graph,
	hh func(*gbgraph.Vertex) int64,
	pq PriorityQueue, trace io.Writer) int64 {
	hasHH := hh != nil
	if hh == nil {
		hh = func(*gbgraph.Vertex) int64 { return 0 }
	}
	if pq == nil {
		pq = NewDList()
	}

//line gbdijk.w:141
	for v := range gg.AllVertices() {
		v.Y.V = nil // |backlink|를 지운다
	}
	uu.Y.V = uu     // |backlink|
	uu.Z.I = 0      // |dist|
	uu.X.I = hh(uu) // |hh| 값
	pq.Init(0)      // 큐를 비운다

//line gbdijk.w:120
	t := uu
	if trace != nil {

//line gbdijk.w:174
		fmt.Fprintf(trace, "Distances from %s", uu.Name)
		if hasHH {
			fmt.Fprintf(trace, " [%d]", uu.X.I)
		}
		fmt.Fprint(trace, ":\n")

//line gbdijk.w:123
	}
	for t != vv {

//line gbdijk.w:153
		d := t.Z.I - t.X.I // |dist|에서 |hh| 값을 뺀 값
		for a := range t.AllArcs() {
			v := a.Tip
			if v.Y.V != nil { // |v|를 이미 보았다
				dd := d + a.Len + v.X.I
				if dd < v.Z.I {
					v.Y.V = t
					pq.Requeue(v, dd) // 더 나은 길을 찾았다
				}
			} else { // |v|를 처음 본다
				v.X.I = hh(v)
				v.Y.V = t
				pq.Enqueue(v, d+a.Len+v.X.I)
			}
		}

//line gbdijk.w:126
		t = pq.DelMin()
		if t == nil {
			return -1 // 큐가 비면 |vv|로 갈 길이 없다
		}
		if trace != nil {

//line gbdijk.w:181
			fmt.Fprintf(trace, " %d to %s", t.Z.I-t.X.I+uu.X.I, t.Name)
			if hasHH {
				fmt.Fprintf(trace, " [%d]", t.X.I)
			}
			fmt.Fprintf(trace, " via %s\n", t.Y.V.Name)

//line gbdijk.w:132
		}
	}
	return vv.Z.I - vv.X.I + uu.X.I // |uu|에서 |vv|까지의 참거리
}

//line gbdijk.w:299
type dlist struct {
	head gbgraph.Vertex // 늘 있는 리스트 머리
}

// |NewDList|는 빈 이중 연결 리스트 큐를 만든다.
//
//line gbdijk.w:303
//line gbdijk.w:304
func NewDList() PriorityQueue { return new(dlist) }

func (q *dlist) Init(d int64) {
	h := &q.head
	setLlink(h, h)
	setRlink(h, h)
	h.Z.I = d - 1
}

//line gbdijk.w:319
func (q *dlist) Enqueue(v *gbgraph.Vertex, d int64) {
	t := llink(&q.head)
	v.Z.I = d
	for d < t.Z.I {
		t = llink(t)
	}
	insertRight(t, v)
}

func (q *dlist) DelMin() *gbgraph.Vertex {
	h := &q.head
	t := rlink(h)
	if t == h {
		return nil
	}
	unlink(t)
	return t
}

//line gbdijk.w:342
func (q *dlist) Requeue(v *gbgraph.Vertex, d int64) {
	t := llink(v)
	unlink(v)
	v.Z.I = d
	for d < t.Z.I {
		t = llink(t)
	}
	insertRight(t, v)
}

//line gbdijk.w:373
type list128 struct {
	head      [128]gbgraph.Vertex // 128개의 리스트 머리
	masterKey int64               // 큐에 있을 수 있는 가장 작은 키
}

// |NewList128|은 호 길이가 128 미만일 때 쓰는 빠른 큐를 만든다.
//
//line gbdijk.w:378
//line gbdijk.w:379
func NewList128() PriorityQueue { return new(list128) }

func (q *list128) Init(d int64) {
	q.masterKey = d
	for i := range q.head {
		u := &q.head[i]
		setLlink(u, u)
		setRlink(u, u)
	}
}

//line gbdijk.w:395
func (q *list128) DelMin() *gbgraph.Vertex {
	for d := q.masterKey; d < q.masterKey+128; d++ {
		u := &q.head[d&0x7f] // |d % 128|
		t := rlink(u)
		if t != u { // 키가 최소인 비지 않은 열을 찾았다
			q.masterKey = d
			unlink(t)
			return t
		}
	}
	return nil // 128개 열이 모두 비었다
}

//line gbdijk.w:416
func (q *list128) Enqueue(v *gbgraph.Vertex, d int64) {
	v.Z.I = d
	insertLeft(&q.head[d&0x7f], v)
}

func (q *list128) Requeue(v *gbgraph.Vertex, d int64) {
	unlink(v)
	v.Z.I = d
	insertLeft(&q.head[d&0x7f], v)
	if d < q.masterKey {
		q.masterKey = d // Dijkstra에는 필요 없다
	}
}

//line gbdijk.w:193
func PrintResult(vv *gbgraph.Vertex, out io.Writer) {
	if vv.Y.V == nil {
		fmt.Fprintf(out, "Sorry, %s is unreachable.\n", vv.Name)
		return
	}

//line gbdijk.w:207
	var t *gbgraph.Vertex
	p := vv
	for {
		q := p.Y.V
		p.Y.V = t
		t = p
		p = q
		if t == p {
			break
		}
	}

//line gbdijk.w:199

//line gbdijk.w:223
	for s := t; s != nil; s = s.Y.V {
		fmt.Fprintf(out, "%10d %s\n", s.Z.I-s.X.I+p.X.I, s.Name)
	}

//line gbdijk.w:200

//line gbdijk.w:231
	t = p
	for {
		q := t.Y.V
		t.Y.V = p
		p = t
		t = q
		if p == vv {
			break
		}
	}

//line gbdijk.w:201
}
