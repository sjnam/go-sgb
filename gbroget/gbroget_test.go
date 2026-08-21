//line gbroget.w:254
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

//line gbroget.w:284
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

//line gbroget.w:323
func TestArcCounts(t *testing.T) {
	full, err := Roget(0, 0, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if full.M != 5075 {
		t.Errorf("M = %d, 원함 5075", full.M)
	}

//line gbroget.w:344
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

//line gbroget.w:332
	far, err := Roget(0, 3, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if far.M != 5075-1252 {
		t.Errorf("minDistance=3일 때 M = %d, 원함 %d", far.M, 5075-1252)
	}
}
