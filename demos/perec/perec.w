% perec: Georges Perec's Life A User's Manual reconstructed with the
% Stanford GraphBase, as a GWEB literate program in Go.
@i ../../gbtypes.w

\input pic
\input luamplib.sty
\def\verbatim{\begingroup
  \def\do##1{\catcode`##1=12 } \dospecials
  \parskip 0pt \parindent 2em \let\!=!
  \catcode`\ =13 \catcode`\^^M=13
  \tt \catcode`\!=0 \verbatimdefs \verbatimgobble}
{\catcode`\^^M=13{\catcode`\ =13\gdef\verbatimdefs{\def^^M{\ \par}\let =\ }} %
  \gdef\verbatimgobble#1^^M{}}

\def\FrameBG{\vbox to 0pt{\vskip-.72in
  \moveleft.63in\hbox{\pic width 7.55in height 11.05in{decoframe.pdf}}\vss}%
  \nointerlineskip}
\def\plainoutput{\shipout\vbox{\FrameBG\makeheadline\pagebody\makefootline}%
  \advancepageno \ifnum\outputpenalty>-20000 \else\dosupereject\fi}
\def\coloutput{%
  \if L\lr
    \global\setbox\lbox=\box255 \gdef\lr{R}%
  \else
    \shipout\vbox{\FrameBG\runheadline
      \vbox to\pageheight{\boxmaxdepth=\maxdimen
        \box\sbox\vss
        \hbox to\pagewidth{\box\lbox\hfil\box255}}}%
    \global\advance\pageno by1
    \global\setbox\sbox=\vbox{}\global\vsize=\pageheight \gdef\lr{L}%
  \fi}

@** The knight's tour. Georges Perec's novel ``{\sl Life A User's Manual\/}
({\it La Vie mode d'emploi\/}, 1978)'' is set in an apartment building at 11 rue
Simon-Crubellier in Paris. Perec cut the building's facade away like a doll's
house, imagining a $10\times10=100$-cell grid from the cellars to the attic.
Each chapter of the novel dwells in one of those 100 cells and tells the story
unfolding in that room.

The question is the order in which the narrative moves from room to room. Perec
fixed it by the {\it knight's move\/} of chess: he chose a knight's tour of the
$10\times10$ board---a path that steps by knight's moves through all 100 cells,
never landing on one twice---and let the chapters travel in that order. The
first chapter begins at the central landing |(6,6)|.

Yet the novel has 99 chapters, not 100. Partway through the tour Perec
deliberately skipped a cell: the cellar at the bottom-left corner |(1,10)|.
Borrowing a word from Lucretius, he called this deliberate flaw the {\it
clinamen\/} (the slight swerve of an atom from its ordained path). Because of
it, the move from the 65th chapter to the 66th is not a knight's move but an
illegal diagonal step of one cell---the single blemish on an otherwise perfect
tour.

Here is a picture. The facade is cut away like a doll's house so that all 100
rooms lie open at once; each cell is stamped with its chapter number, and
consecutive chapters are joined by a line. The first chapter is the ringed |1|
at the center, and the bottom-left corner---the unvisited clinamen---is left
empty with a cross. The dashed line from $65$ to $66$ is that one illegal,
non-knight move.
\bigskip
$$
\mplibcode
beginfig(1);
  numeric u; u := 28;              % cell size in bp
  pair p[];                        % p[k] is the cell the (k)th chapter sits in (x=col, y=floor)
  p[1]:=(6,6); p[2]:=(8,7); p[3]:=(10,6); p[4]:=(8,5); p[5]:=(10,4); p[6]:=(9,2); p[7]:=(7,1);
  p[8]:=(8,3); p[9]:=(6,2); p[10]:=(4,1); p[11]:=(2,2); p[12]:=(1,4); p[13]:=(3,5); p[14]:=(4,3);
  p[15]:=(3,1); p[16]:=(5,2); p[17]:=(6,4); p[18]:=(4,5); p[19]:=(5,7); p[20]:=(3,8); p[21]:=(4,10);
  p[22]:=(6,9); p[23]:=(4,8); p[24]:=(2,9); p[25]:=(1,7); p[26]:=(3,6); p[27]:=(5,5); p[28]:=(7,4);
  p[29]:=(8,6); p[30]:=(10,5); p[31]:=(9,7); p[32]:=(10,9); p[33]:=(8,10); p[34]:=(7,8); p[35]:=(5,9);
  p[36]:=(6,7); p[37]:=(8,8); p[38]:=(7,10); p[39]:=(9,9); p[40]:=(10,7); p[41]:=(9,5); p[42]:=(7,6);
  p[43]:=(8,4); p[44]:=(10,3); p[45]:=(9,1); p[46]:=(7,2); p[47]:=(5,3); p[48]:=(6,1); p[49]:=(7,3);
  p[50]:=(9,4); p[51]:=(10,2); p[52]:=(8,1); p[53]:=(9,3); p[54]:=(10,1); p[55]:=(8,2); p[56]:=(6,3);
  p[57]:=(5,1); p[58]:=(3,2); p[59]:=(1,1); p[60]:=(2,3); p[61]:=(1,5); p[62]:=(2,7); p[63]:=(1,9);
  p[64]:=(3,10); p[65]:=(2,8); p[66]:=(3,9); p[67]:=(5,10); p[68]:=(6,8); p[69]:=(4,7); p[70]:=(2,6);
  p[71]:=(1,8); p[72]:=(2,10); p[73]:=(4,9); p[74]:=(6,10); p[75]:=(8,9); p[76]:=(10,10); p[77]:=(9,8);
  p[78]:=(7,7); p[79]:=(6,5); p[80]:=(4,6); p[81]:=(3,4); p[82]:=(4,2); p[83]:=(2,1); p[84]:=(1,3);
  p[85]:=(2,5); p[86]:=(4,4); p[87]:=(5,6); p[88]:=(3,7); p[89]:=(5,8); p[90]:=(7,9); p[91]:=(9,10);
  p[92]:=(10,8); p[93]:=(9,6); p[94]:=(7,5); p[95]:=(5,4); p[96]:=(3,3); p[97]:=(1,2); p[98]:=(2,4);
  p[99]:=(1,6);

  % map cell (x,y) to a screen point; y grows downward (top row is the attic).
  def C(expr c) = ((xpart c)*u, -(ypart c)*u) enddef;

  % clinamen: shade the unvisited bottom-left corner (1,10) lightly.
  fill C((0.5,9.5))--C((1.5,9.5))--C((1.5,10.5))--C((0.5,10.5))--cycle
    withcolor 0.86white;

  % room partitions (thin) and the facade border (thick).
  pickup pencircle scaled 0.3bp;
  for i=0 upto 10:
    draw C((0.5,0.5+i))--C((10.5,0.5+i));
    draw C((0.5+i,0.5))--C((0.5+i,10.5));
  endfor;
  pickup pencircle scaled 1.1bp;
  draw C((0.5,0.5))--C((10.5,0.5))--C((10.5,10.5))--C((0.5,10.5))--cycle;

  % a doll's-house roof, set atop the cut-away facade.
  pickup pencircle scaled 1.1bp;
  draw C((0.5,0.5))--(5.5u,0.2u)--C((10.5,0.5));

  % the knight's tour: join consecutive chapters; only 65->66 is a non-knight move.
  pickup pencircle scaled 0.7bp;
  for k=1 upto 98:
    if k=65:
      draw C(p[k])--C(p[k+1]) dashed evenly scaled 0.6 withcolor 0.35white;
    else:
      draw C(p[k])--C(p[k+1]) withcolor 0.55white;
    fi
  endfor;

  % stamp each cell with its chapter number.
  defaultscale := 0.62;
  for k=1 upto 99:
    label(decimal k, C(p[k]));
  endfor;

  % ring the first chapter (6,6); mark the clinamen cell with an x.
  pickup pencircle scaled 0.6bp;
  draw fullcircle scaled 0.78u shifted C(p[1]);
  draw C((0.68,9.68))--C((1.32,10.32));
  draw C((1.32,9.68))--C((0.68,10.32));
endfig;
\endmplibcode
$$
\bigskip\noindent
Perec had a second constraint. He gathered 42 lists of ten items into
twenty-one pairs and, by an order-10 Graeco-Latin square, assigned to each
chapter a combination of items. If the knight's tour decides {\it where to
write}, this square decides {\it what to write}. This starred section builds and
verifies the {\it knight's tour}; the square that distributes the material is
treated in a later starred section.

@ Here is what the program does. Using {\sc GB\_\,BASIC}'s |Board| it builds the
$10\times10$ knight board, lays Perec's actual chapter order on it, and
verifies---by asking the board's own arcs---that the order really is a walk of
knight's moves, with the clinamen as its one exception. Finally it prints a grid
of chapter numbers and a diagnosis.

The chapter-order data is transcribed from the |sqs| array in
\.{scripts/knights-tour.js}, published by Thomas Guest at
\.{wordaligned.org/knights-tour}. Whether the transcription is faithful the
program checks for itself, on the board.

@c
package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	@#
	"github.com/sjnam/go-sgb/gbbasic"
)

@<Types and data@>

func main() {
	@<Build the knight board@>
	@<Extract the board's adjacency@>
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	@<Verify and print the tour@>
	@<Generate and print a complete tour@>
	@<Verify the square and print the assignment@>
}

@ A cell of the board is a |cell|. Here |x| is the column (1 at the left, 10 at
the right) and |y| the floor (1 at the top, 10 at the bottom). |tour[k]| is the
cell the $(k+1)$th chapter sits in.
@<Types and data@>=
type cell struct{ x, y int }

var tour = []cell{
	{6, 6}, {8, 7}, {10, 6}, {8, 5}, {10, 4}, {9, 2}, {7, 1}, {8, 3}, {6, 2}, {4, 1},
	{2, 2}, {1, 4}, {3, 5}, {4, 3}, {3, 1}, {5, 2}, {6, 4}, {4, 5}, {5, 7}, {3, 8},
	{4, 10}, {6, 9}, {4, 8}, {2, 9}, {1, 7}, {3, 6}, {5, 5}, {7, 4}, {8, 6}, {10, 5},
	{9, 7}, {10, 9}, {8, 10}, {7, 8}, {5, 9}, {6, 7}, {8, 8}, {7, 10}, {9, 9}, {10, 7},
	{9, 5}, {7, 6}, {8, 4}, {10, 3}, {9, 1}, {7, 2}, {5, 3}, {6, 1}, {7, 3}, {9, 4},
	{10, 2}, {8, 1}, {9, 3}, {10, 1}, {8, 2}, {6, 3}, {5, 1}, {3, 2}, {1, 1}, {2, 3},
	{1, 5}, {2, 7}, {1, 9}, {3, 10}, {2, 8}, {3, 9}, {5, 10}, {6, 8}, {4, 7}, {2, 6},
	{1, 8}, {2, 10}, {4, 9}, {6, 10}, {8, 9}, {10, 10}, {9, 8}, {7, 7}, {6, 5}, {4, 6},
	{3, 4}, {4, 2}, {2, 1}, {1, 3}, {2, 5}, {4, 4}, {5, 6}, {3, 7}, {5, 8}, {7, 9},
	{9, 10}, {10, 8}, {9, 6}, {7, 5}, {5, 4}, {3, 3}, {1, 2}, {2, 4}, {1, 6},
}

@ |Board| builds a board graph from the moves of a generalized chess piece. Its
first four arguments are the board's dimensions; a zero dimension is unused, so
|10,10,0,0| is a two-dimensional $10\times10$ board. The fifth argument
|piece=5| is the knight---a knight's move is exactly the one whose Euclidean
distance between two cells is $\sqrt5$. The last two arguments are wrapping and
directedness, both unused here.
@<Build the knight board@>=
g, err := gbbasic.Board(10, 10, 0, 0, 5, 0, false)
if err != nil {
	log.Fatalf("couldn't build the knight board: %v", err)
}

@ The vertices |Board| makes are named by coordinate |"row.col"|, so the cell at
floor |y| and column |x| is |"y-1.x-1"| (both counted from 0). Verification needs
not the vertices themselves but only whether two cells are neighbors on the
board, so we sweep all of the board's arcs into a single set of name pairs. Then
one lookup tells whether two cells are joined by a knight's move.
@<Extract the board's adjacency@>=
adj := make(map[[2]string]bool)
for v := range g.AllVertices() {
	for a := range v.AllArcs() {
		adj[[2]string{v.Name, a.Tip.Name}] = true
	}
}

@ This |name| is the bridge from a coordinate to a vertex name: floor |y| first,
column |x| second, each decremented to count from 0.
@<Types and data@>=
func name(c cell) string { return fmt.Sprintf("%d.%d", c.y-1, c.x-1) }

@ Now the heart of it. First we sweep Perec's chapter order as a walk on the
board, collecting the links that are not neighbors and the cells stepped on
twice. Then we pick out the cell, among the 100, that is never stepped on. If
Perec's tour is right, the only non-adjacent link is the clinamen, and the only
unvisited cell is the cellar corner.
@<Verify and print the tour@>=
fmt.Fprint(out, "PEREC: the knight's tour of Life A User's Manual\n\n")
fmt.Fprintf(out, "  The board's official name is\n  %s\n", g.ID)
fmt.Fprintf(out, "  with %d vertices and %d arcs.\n\n", g.N, g.M)
@<Find non-adjacent links and repeated cells@>
@<Find the unvisited cell@>
@<Print the chapter-number grid@>
@<Print the verification result@>

@ For each consecutive pair of chapters we ask |adj| whether their cells are
neighbors on the board. If not, we record the link in |breaks|. We also record
in |chapterAt| the first chapter to step on each cell, so a cell stepped on
twice shows up at once.
@<Find non-adjacent links and repeated cells@>=
chapterAt := make(map[string]int)
var breaks [][2]int // (earlier chapter, later chapter) of a non-adjacent link
var repeats int
for k, c := range tour {
	if _, seen := chapterAt[name(c)]; seen {
		repeats++
	}
	chapterAt[name(c)] = k + 1
	if k > 0 && !adj[[2]string{name(tour[k-1]), name(c)}] {
		breaks = append(breaks, [2]int{k, k + 1})
	}
}

@ We walk all 100 cells of the board and gather those not in |chapterAt|,
forming the coordinates by |Board|'s naming rule from floor |y| and column |x|.
@<Find the unvisited cell@>=
var missing []cell
for y := 1; y <= 10; y++ {
	for x := 1; x <= 10; x++ {
		if _, seen := chapterAt[name(cell{x, y})]; !seen {
			missing = append(missing, cell{x, y})
		}
	}
}

@ The chapter-number grid is a copy of the novel's facade. From the top-left
|(1,1)| to the bottom-right |(10,10)|, each cell is stamped with the chapter
that treats that room. The unvisited cellar corner is left blank with three dots.
@<Print the chapter-number grid@>=
fmt.Fprint(out, "  Chapter-number grid (top-left is (1,1), top row is the attic):\n\n")
for y := 1; y <= 10; y++ {
	fmt.Fprint(out, "   ")
	for x := 1; x <= 10; x++ {
		if ch, seen := chapterAt[name(cell{x, y})]; seen {
			fmt.Fprintf(out, " %3d", ch)
		} else {
			fmt.Fprint(out, " ...")
		}
	}
	fmt.Fprint(out, "\n")
}
fmt.Fprint(out, "\n")

@ Finally we put the verification into words a reader can follow. For each
non-adjacent link we tell between which chapters, and to which cell, it strayed,
and whether the stray is a single diagonal step. Perec's clinamen is exactly
that one move from the 65th chapter to the 66th.
@<Print the verification result@>=
fmt.Fprintf(out, "  chapters: %d, repeated cells: %d\n", len(tour), repeats)
for _, m := range missing {
	fmt.Fprintf(out, "  unvisited cell: (%d,%d)  <- clinamen\n", m.x, m.y)
}
for _, b := range breaks {
	p, q := tour[b[0]-1], tour[b[1]-1]
	dx, dy := abs(p.x-q.x), abs(p.y-q.y)
	fmt.Fprintf(out,
		"  non-knight move: ch.%d (%d,%d) -> ch.%d (%d,%d), offset (%d,%d)\n",
		b[0], p.x, p.y, b[1], q.x, q.y, dx, dy)
}

@ A small hand for the absolute value of a coordinate difference.
@<Types and data@>=
func abs(n int) int {
	if n < 0 {
		return -n
	}
	return n
}

@ Run the program and it prints this for the tour: the board's official name and
its vertex and arc counts, the chapter-number grid modeled on the novel's
facade, and then the verification result.
\medskip
\begingroup
\verbatim
PEREC: the knight's tour of Life A User's Manual

  The board's official name is
  board(10,10,0,0,5,0,0)
  with 100 vertices and 576 arcs.

  Chapter-number grid (top-left is (1,1), top row is the attic):

     59  83  15  10  57  48   7  52  45  54
     97  11  58  82  16   9  46  55   6  51
     84  60  96  14  47  56  49   8  53  44
     12  98  81  86  95  17  28  43  50   5
     61  85  13  18  27  79  94   4  41  30
     99  70  26  80  87   1  42  29  93   3
     25  62  88  69  19  36  78   2  31  40
     71  65  20  23  89  68  34  37  77  92
     63  24  66  73  35  22  90  75  39  32
    ...  72  64  21  67  74  38  33  91  76

  chapters: 99, repeated cells: 0
  unvisited cell: (1,10)  <- clinamen
  non-knight move: ch.65 (2,8) -> ch.66 (3,9), offset (1,1)
!endgroup
\endgroup

@* A genuine complete tour. Perec's path is a knight's tour with a deliberate
scar: ninety-nine cells, one illegal diagonal step, one room left forever empty.
It is fair to ask whether the board forced his hand---whether a $10\times10$
board admits any flawless tour of all one hundred cells at all. It does, and to
see it we now set the novel aside and let the program find such a tour on its
own, on the very same board.

The oldest and simplest rule for the purpose is {\it Warnsdorff's\/} (1823):
from the cell you stand on, always step to the unvisited cell that has the fewest
unvisited neighbors of its own. The idea is to visit the awkward, hard-to-reach
cells early, while reaching them is still easy, and to save the roomy ones for
last. On the $10\times10$ board the rule walks clean through all hundred cells
without ever having to turn back; so, fittingly, we start it at Perec's own
central landing |(6,6)| and let it finish what he chose to leave undone.

@ The rule needs, for each cell, the list of its knight-neighbors, which we read
straight off the board's arcs. Vertex names are coordinates |"row.col"|, so a
small reverse map |rev| turns a name back into a |cell|, and |nbr[c]| collects
the cells a knight can reach from~|c|.
@<Generate and print a complete tour@>=
fmt.Fprint(out, "\nPEREC: a genuine complete knight's tour (Warnsdorff)\n\n")
@<Build the neighbor lists from the board@>
@<Grow a tour by Warnsdorff's rule@>
@<Verify and print the complete tour@>

@ @<Build the neighbor lists from the board@>=
rev := make(map[string]cell)
for y := 1; y <= 10; y++ {
	for x := 1; x <= 10; x++ {
		rev[name(cell{x, y})] = cell{x, y}
	}
}
nbr := make(map[cell][]cell)
for v := range g.AllVertices() {
	for a := range v.AllArcs() {
		nbr[rev[v.Name]] = append(nbr[rev[v.Name]], rev[a.Tip.Name])
	}
}

@ We start at |(6,6)|, mark it walked, and grow the path one cell at a time. At
each step we scan the unvisited neighbors of the current cell and keep the one
with the |fewest| onward moves. Should the scan ever find nothing, Warnsdorff has
run into a dead end and we stop; but on this board it never does.
@<Grow a tour by Warnsdorff's rule@>=
start := cell{6, 6}
walked := map[cell]bool{start: true}
full := []cell{start}
for len(full) < 100 {
	cur := full[len(full)-1]
	next, fewest, found := cell{}, 99, false
	for _, n := range nbr[cur] {
		if walked[n] {
			continue
		}
		@<Let |onward| count |n|'s unvisited neighbors@>
		if onward < fewest {
			fewest, next, found = onward, n, true
		}
	}
	if !found {
		break
	}
	walked[next] = true
	full = append(full, next)
}

@ This is the crux of the rule: how crowded the cell~|n| still is, measured as
the number of its neighbors not yet walked.
@<Let |onward| count |n|'s unvisited neighbors@>=
onward := 0
for _, m := range nbr[n] {
	if !walked[m] {
		onward++
	}
}

@ We verify the finished tour on the board's own arcs, exactly as we did Perec's,
and this time expect no flaw at all: a hundred cells, every step a knight's move,
and---unlike the novel---no clinamen. The step-number grid is laid out like the
facade, so it can be read against the chapter grid above.
@<Verify and print the complete tour@>=
grid := make(map[cell]int)
var flaws int
for k, c := range full {
	grid[c] = k + 1
	if k > 0 && !adj[[2]string{name(full[k-1]), name(c)}] {
		flaws++
	}
}
@<Print the complete-tour grid@>
fmt.Fprintf(out, "  cells visited: %d, non-knight moves: %d\n", len(full), flaws)
if len(full) == 100 && flaws == 0 {
	fmt.Fprint(out, "  => a flawless knight's tour of all 100 cells (no clinamen).\n")
}

@ @<Print the complete-tour grid@>=
fmt.Fprint(out, "  Step-number grid (top-left is (1,1), top row is the attic):\n\n")
for y := 1; y <= 10; y++ {
	fmt.Fprint(out, "   ")
	for x := 1; x <= 10; x++ {
		fmt.Fprintf(out, " %3d", grid[cell{x, y}])
	}
	fmt.Fprint(out, "\n")
}
fmt.Fprint(out, "\n")

@ Run it and the program prints this for the complete tour: the step-number grid,
then a line confirming that all hundred cells were visited with not one
non-knight move. The |1| sits at the central landing |(6,6)|, right where Perec
began; from there the rule reaches every room, the bottom-left cellar included.
\medskip
\begingroup
\verbatim
PEREC: a genuine complete knight's tour (Warnsdorff)

  Step-number grid (top-left is (1,1), top row is the attic):

     27   8  41  96  25  10  23  64  57  12
     40  93  26   9  42  75  58  11  22  63
      7  28  95  76  97  24  65  62  13  56
     94  39  92  43  78  59  74  55  66  21
     29   6  77  98  45 100  79  20  61  14
     38  89  44  91  84   1  60  73  54  67
      5  30  85  46  99  80  19  82  15  50
     88  37  90  33   2  83  72  51  68  53
     31   4  35  86  47  18  81  70  49  16
     36  87  32   3  34  71  48  17  52  69

  cells visited: 100, non-knight moves: 0
  => a flawless knight's tour of all 100 cells (no clinamen).
!endgroup
\endgroup

@ And here is that tour drawn out. This time the grid is plain, not a doll's
house cut away for a novel: this tour belongs to no story, only to the board. The
hundred cells are joined in the order Warnsdorff's rule visited them; the start
|(6,6)|, Perec's central landing, is ringed with a solid circle, and the finish
|(6,5)| with a dashed one. Every link is a true knight's move, and no cell is
left out---the flawless tour of which Perec's is the deliberate scarring.
\bigskip
$$
\mplibcode
beginfig(3);
  numeric u; u := 28;
  pair q[];                        % q[k] is the cell visited at step k (x=col, y=floor)
  q[1]:=(6,6); q[2]:=(5,8); q[3]:=(4,10); q[4]:=(2,9); q[5]:=(1,7); q[6]:=(2,5); q[7]:=(1,3);
  q[8]:=(2,1); q[9]:=(4,2); q[10]:=(6,1); q[11]:=(8,2); q[12]:=(10,1); q[13]:=(9,3); q[14]:=(10,5);
  q[15]:=(9,7); q[16]:=(10,9); q[17]:=(8,10); q[18]:=(6,9); q[19]:=(7,7); q[20]:=(8,5); q[21]:=(10,4);
  q[22]:=(9,2); q[23]:=(7,1); q[24]:=(6,3); q[25]:=(5,1); q[26]:=(3,2); q[27]:=(1,1); q[28]:=(2,3);
  q[29]:=(1,5); q[30]:=(2,7); q[31]:=(1,9); q[32]:=(3,10); q[33]:=(4,8); q[34]:=(5,10); q[35]:=(3,9);
  q[36]:=(1,10); q[37]:=(2,8); q[38]:=(1,6); q[39]:=(2,4); q[40]:=(1,2); q[41]:=(3,1); q[42]:=(5,2);
  q[43]:=(4,4); q[44]:=(3,6); q[45]:=(5,5); q[46]:=(4,7); q[47]:=(5,9); q[48]:=(7,10); q[49]:=(9,9);
  q[50]:=(10,7); q[51]:=(8,8); q[52]:=(9,10); q[53]:=(10,8); q[54]:=(9,6); q[55]:=(8,4); q[56]:=(10,3);
  q[57]:=(9,1); q[58]:=(7,2); q[59]:=(6,4); q[60]:=(7,6); q[61]:=(9,5); q[62]:=(8,3); q[63]:=(10,2);
  q[64]:=(8,1); q[65]:=(7,3); q[66]:=(9,4); q[67]:=(10,6); q[68]:=(9,8); q[69]:=(10,10); q[70]:=(8,9);
  q[71]:=(6,10); q[72]:=(7,8); q[73]:=(8,6); q[74]:=(7,4); q[75]:=(6,2); q[76]:=(4,3); q[77]:=(3,5);
  q[78]:=(5,4); q[79]:=(7,5); q[80]:=(6,7); q[81]:=(7,9); q[82]:=(8,7); q[83]:=(6,8); q[84]:=(5,6);
  q[85]:=(3,7); q[86]:=(4,9); q[87]:=(2,10); q[88]:=(1,8); q[89]:=(2,6); q[90]:=(3,8); q[91]:=(4,6);
  q[92]:=(3,4); q[93]:=(2,2); q[94]:=(1,4); q[95]:=(3,3); q[96]:=(4,1); q[97]:=(5,3); q[98]:=(4,5);
  q[99]:=(5,7); q[100]:=(6,5);

  def C(expr c) = ((xpart c)*u, -(ypart c)*u) enddef;

  % room partitions (thin) and the border (thick).
  pickup pencircle scaled 0.3bp;
  for i=0 upto 10:
    draw C((0.5,0.5+i))--C((10.5,0.5+i));
    draw C((0.5+i,0.5))--C((0.5+i,10.5));
  endfor;
  pickup pencircle scaled 1.1bp;
  draw C((0.5,0.5))--C((10.5,0.5))--C((10.5,10.5))--C((0.5,10.5))--cycle;

  % the tour: join consecutive cells; every link is a knight's move.
  pickup pencircle scaled 0.7bp;
  for k=1 upto 99:
    draw C(q[k])--C(q[k+1]) withcolor 0.55white;
  endfor;

  % stamp each cell with its step number.
  defaultscale := 0.62;
  for k=1 upto 100:
    label(decimal k, C(q[k]));
  endfor;

  % ring the start (6,6) solid, the finish (6,5) dashed.
  pickup pencircle scaled 0.6bp;
  draw fullcircle scaled 0.78u shifted C(q[1]);
  draw fullcircle scaled 0.78u shifted C(q[100]) dashed evenly scaled 0.5;
endfig;
\endmplibcode
$$

@** A Graeco-Latin square. If the knight's tour decides {\it where to write},
{\it what to write} is decided by Perec's second constraint. As we said, he
gathered 42 lists of material into twenty-one pairs and, by a $10\times10$
Graeco-Latin square, assigned to each chapter its combination of material. But
why order 10? Behind that number lies two centuries of mathematical drama, and
Perec chose this square knowing the story.

A Graeco-Latin square is two Latin squares laid one over the other, each cell
holding a pair of symbols, so that all the pairs are distinct. The story begins
in 1782 with Euler's {\it problem of the 36 officers\/}. Can thirty-six
officers, one of each of six ranks and six regiments, be drawn up in a
$6\times6$ array so that every row and every column shows each rank once and
each regiment once? That is precisely an order-6 Graeco-Latin square. Euler
could not build one however he tried, and finally conjectured that no such
square exists whenever the order is of the form $4k+2$ (that is,
$2,6,10,14,\dots$).

Euler's conjecture was half right and half wrong. In 1900 Gaston Tarry proved,
by counting every case by hand, that the order-6 square really is
impossible---so for 6 Euler was right. But not beyond it. At the April 1959
meeting of the American Mathematical Society in New York, Bose, Shrikhande and
Parker announced that for every order of the form $4k+2$ except $2$ and
$6$---that is, $10,14,18,\dots$---a Graeco-Latin square exists. Parker found an
order-10 square in about an hour's search on a UNIVAC 1206 military computer, one
of the earliest combinatorial problems solved on a digital computer. The three
were nicknamed {\it Euler's spoilers\/}, and that November the cover of {\it
Scientific American\/} carried their order-10 square in full colour.

So order 10 is no ordinary number. The very order Euler declared impossible,
overturned only two centuries later---the square whose existence had just been
proved---is the one Perec took for the skeleton of his novel. It is a choice
worthy of a member of Oulipo, who prized the beauty of constraint above all.
Now it is time to build the square in earnest and, as Perec did, assign the
material to each chapter.

@ For an order that is odd or a prime power, a square is built by a simple
formula. For a prime $p$, say, |L1(i,j) = (i+j) mod p| and |L2(i,j) = (i+2j) mod
p| are already two orthogonal Latin squares. But 10 is even and the formula
breaks---which is just what fooled Euler and set Parker to his computer. So we
do exactly as Parker did: we run a search that builds a random Latin square and
hunts for its orthogonal mate, obtain one square (a matter of seconds on today's
machines), and set the result down here as |square|. Each cell is a
two-component |[2]int{a, b}|.
@<Types and data@>=
var square = [10][10][2]int{
	{{4, 0}, {2, 1}, {5, 2}, {1, 3}, {3, 4}, {6, 5}, {9, 6}, {0, 7}, {7, 8}, {8, 9}},
	{{3, 3}, {7, 9}, {8, 8}, {0, 4}, {6, 6}, {9, 1}, {2, 5}, {1, 2}, {4, 7}, {5, 0}},
	{{0, 1}, {9, 5}, {6, 3}, {7, 0}, {4, 8}, {1, 9}, {3, 2}, {5, 4}, {8, 6}, {2, 7}},
	{{7, 6}, {3, 7}, {9, 4}, {8, 2}, {0, 9}, {2, 8}, {1, 1}, {6, 0}, {5, 3}, {4, 5}},
	{{2, 4}, {1, 8}, {7, 1}, {6, 7}, {8, 5}, {3, 0}, {5, 9}, {4, 6}, {0, 2}, {9, 3}},
	{{5, 8}, {8, 0}, {0, 5}, {3, 9}, {9, 7}, {7, 2}, {4, 4}, {2, 3}, {6, 1}, {1, 6}},
	{{8, 7}, {4, 2}, {2, 0}, {5, 5}, {7, 3}, {0, 6}, {6, 8}, {9, 9}, {1, 4}, {3, 1}},
	{{1, 5}, {0, 3}, {4, 9}, {2, 6}, {5, 1}, {8, 4}, {7, 7}, {3, 8}, {9, 0}, {6, 2}},
	{{9, 2}, {6, 4}, {3, 6}, {4, 1}, {1, 0}, {5, 7}, {8, 3}, {7, 5}, {2, 9}, {0, 8}},
	{{6, 9}, {5, 6}, {1, 7}, {9, 8}, {2, 2}, {4, 3}, {0, 0}, {8, 1}, {3, 5}, {7, 4}},
}

@ Here it is in colour. Like that famous {\it Scientific American\/} cover, each
cell is split on its diagonal, the upper triangle coloured by the first
component and the lower by the second. Because each component is Latin, the ten
colours each appear once in every row and column; because the two are
orthogonal, no upper-lower pair of colours repeats across the hundred cells.
That is the visible proof that this picture is a genuine Graeco-Latin square.
\bigskip
$$
\mplibcode
beginfig(2);
  numeric u; u := 34;
  numeric AA[][], BB[][];
  AA[0][0]:=4; AA[0][1]:=2; AA[0][2]:=5; AA[0][3]:=1; AA[0][4]:=3; AA[0][5]:=6; AA[0][6]:=9; AA[0][7]:=0; AA[0][8]:=7; AA[0][9]:=8;
  AA[1][0]:=3; AA[1][1]:=7; AA[1][2]:=8; AA[1][3]:=0; AA[1][4]:=6; AA[1][5]:=9; AA[1][6]:=2; AA[1][7]:=1; AA[1][8]:=4; AA[1][9]:=5;
  AA[2][0]:=0; AA[2][1]:=9; AA[2][2]:=6; AA[2][3]:=7; AA[2][4]:=4; AA[2][5]:=1; AA[2][6]:=3; AA[2][7]:=5; AA[2][8]:=8; AA[2][9]:=2;
  AA[3][0]:=7; AA[3][1]:=3; AA[3][2]:=9; AA[3][3]:=8; AA[3][4]:=0; AA[3][5]:=2; AA[3][6]:=1; AA[3][7]:=6; AA[3][8]:=5; AA[3][9]:=4;
  AA[4][0]:=2; AA[4][1]:=1; AA[4][2]:=7; AA[4][3]:=6; AA[4][4]:=8; AA[4][5]:=3; AA[4][6]:=5; AA[4][7]:=4; AA[4][8]:=0; AA[4][9]:=9;
  AA[5][0]:=5; AA[5][1]:=8; AA[5][2]:=0; AA[5][3]:=3; AA[5][4]:=9; AA[5][5]:=7; AA[5][6]:=4; AA[5][7]:=2; AA[5][8]:=6; AA[5][9]:=1;
  AA[6][0]:=8; AA[6][1]:=4; AA[6][2]:=2; AA[6][3]:=5; AA[6][4]:=7; AA[6][5]:=0; AA[6][6]:=6; AA[6][7]:=9; AA[6][8]:=1; AA[6][9]:=3;
  AA[7][0]:=1; AA[7][1]:=0; AA[7][2]:=4; AA[7][3]:=2; AA[7][4]:=5; AA[7][5]:=8; AA[7][6]:=7; AA[7][7]:=3; AA[7][8]:=9; AA[7][9]:=6;
  AA[8][0]:=9; AA[8][1]:=6; AA[8][2]:=3; AA[8][3]:=4; AA[8][4]:=1; AA[8][5]:=5; AA[8][6]:=8; AA[8][7]:=7; AA[8][8]:=2; AA[8][9]:=0;
  AA[9][0]:=6; AA[9][1]:=5; AA[9][2]:=1; AA[9][3]:=9; AA[9][4]:=2; AA[9][5]:=4; AA[9][6]:=0; AA[9][7]:=8; AA[9][8]:=3; AA[9][9]:=7;
  BB[0][0]:=0; BB[0][1]:=1; BB[0][2]:=2; BB[0][3]:=3; BB[0][4]:=4; BB[0][5]:=5; BB[0][6]:=6; BB[0][7]:=7; BB[0][8]:=8; BB[0][9]:=9;
  BB[1][0]:=3; BB[1][1]:=9; BB[1][2]:=8; BB[1][3]:=4; BB[1][4]:=6; BB[1][5]:=1; BB[1][6]:=5; BB[1][7]:=2; BB[1][8]:=7; BB[1][9]:=0;
  BB[2][0]:=1; BB[2][1]:=5; BB[2][2]:=3; BB[2][3]:=0; BB[2][4]:=8; BB[2][5]:=9; BB[2][6]:=2; BB[2][7]:=4; BB[2][8]:=6; BB[2][9]:=7;
  BB[3][0]:=6; BB[3][1]:=7; BB[3][2]:=4; BB[3][3]:=2; BB[3][4]:=9; BB[3][5]:=8; BB[3][6]:=1; BB[3][7]:=0; BB[3][8]:=3; BB[3][9]:=5;
  BB[4][0]:=4; BB[4][1]:=8; BB[4][2]:=1; BB[4][3]:=7; BB[4][4]:=5; BB[4][5]:=0; BB[4][6]:=9; BB[4][7]:=6; BB[4][8]:=2; BB[4][9]:=3;
  BB[5][0]:=8; BB[5][1]:=0; BB[5][2]:=5; BB[5][3]:=9; BB[5][4]:=7; BB[5][5]:=2; BB[5][6]:=4; BB[5][7]:=3; BB[5][8]:=1; BB[5][9]:=6;
  BB[6][0]:=7; BB[6][1]:=2; BB[6][2]:=0; BB[6][3]:=5; BB[6][4]:=3; BB[6][5]:=6; BB[6][6]:=8; BB[6][7]:=9; BB[6][8]:=4; BB[6][9]:=1;
  BB[7][0]:=5; BB[7][1]:=3; BB[7][2]:=9; BB[7][3]:=6; BB[7][4]:=1; BB[7][5]:=4; BB[7][6]:=7; BB[7][7]:=8; BB[7][8]:=0; BB[7][9]:=2;
  BB[8][0]:=2; BB[8][1]:=4; BB[8][2]:=6; BB[8][3]:=1; BB[8][4]:=0; BB[8][5]:=7; BB[8][6]:=3; BB[8][7]:=5; BB[8][8]:=9; BB[8][9]:=8;
  BB[9][0]:=9; BB[9][1]:=6; BB[9][2]:=7; BB[9][3]:=8; BB[9][4]:=2; BB[9][5]:=3; BB[9][6]:=0; BB[9][7]:=1; BB[9][8]:=5; BB[9][9]:=4;
  color col[];
  col[0]:=(0.95,0.56,0.54); col[1]:=(0.98,0.73,0.42); col[2]:=(0.97,0.90,0.46);
  col[3]:=(0.62,0.85,0.55); col[4]:=(0.55,0.86,0.83); col[5]:=(0.62,0.73,0.96);
  col[6]:=(0.76,0.63,0.91); col[7]:=(0.97,0.71,0.86); col[8]:=(0.81,0.66,0.51);
  col[9]:=(0.82,0.82,0.84);
  pair TL, TR, BL, BR;
  defaultscale := 0.5;
  for i=0 upto 9:
    for j=0 upto 9:
      TL := (j*u, -i*u); TR := ((j+1)*u, -i*u);
      BL := (j*u, -(i+1)*u); BR := ((j+1)*u, -(i+1)*u);
      fill TL--TR--BR--cycle withcolor col[AA[i][j]];
      fill TL--BR--BL--cycle withcolor col[BB[i][j]];
      draw TL--BR withcolor 0.6white withpen pencircle scaled 0.2bp;
      label(decimal AA[i][j], (j*u+0.70u, -i*u-0.30u));
      label(decimal BB[i][j], (j*u+0.30u, -i*u-0.70u));
    endfor;
  endfor;
  pickup pencircle scaled 0.3bp;
  for k=0 upto 10:
    draw (0,-k*u)--(10u,-k*u);
    draw (k*u,0)--(k*u,-10u);
  endfor;
  pickup pencircle scaled 1.1bp;
  draw (0,0)--(10u,0)--(10u,-10u)--(0,-10u)--cycle;
  currentpicture := currentpicture scaled (10cm/(10u));
endfig;
\endmplibcode
$$

@ We do not take on trust that the square we set down is really Graeco-Latin; we
check, in the same spirit as for the knight's tour. Three things: is the first
component Latin, is the second Latin, and are all 100 pairs distinct (which is
exactly the orthogonality of the two components). If all three hold, we hold in
our hands the very thing Euler said could not exist.
@<Verify the square and print the assignment@>=
fmt.Fprint(out, "\nPEREC: an order-10 Graeco-Latin square\n\n")
@<Check that the square is Graeco-Latin@>
@<Print the square as a grid@>
@<Assign one couple of lists to chapters@>

@ For a component to be Latin means that in each of the ten rows and columns the
symbols $0$ through $9$ each appear once, so it is enough to OR ten bits and see
whether they make |1023|. Orthogonality we check by putting the 100 pairs into a
set and seeing that its size is 100.
@<Check that the square is Graeco-Latin@>=
latinA, latinB := true, true
for i := 0; i < 10; i++ {
	var rA, cA, rB, cB int
	for j := 0; j < 10; j++ {
		rA |= 1 << square[i][j][0]
		cA |= 1 << square[j][i][0]
		rB |= 1 << square[i][j][1]
		cB |= 1 << square[j][i][1]
	}
	if rA != 1023 || cA != 1023 {
		latinA = false
	}
	if rB != 1023 || cB != 1023 {
		latinB = false
	}
}
seen := make(map[[2]int]bool)
for i := 0; i < 10; i++ {
	for j := 0; j < 10; j++ {
		seen[square[i][j]] = true
	}
}
fmt.Fprintf(out, "  Are both components Latin squares?  A: %v, B: %v\n", latinA, latinB)
fmt.Fprintf(out, "  Are all 100 pairs distinct (orthogonal)?  %v (%d distinct pairs)\n",
	len(seen) == 100, len(seen))
if latinA && latinB && len(seen) == 100 {
	fmt.Fprint(out, "  => here is the order-10 square Euler said could not exist.\n\n")
}

@ To show the square itself, we print each cell as two digits |ab|. That these
hundred pairs run over $00$ through $99$ exactly once each is guaranteed by the
check above.
@<Print the square as a grid@>=
fmt.Fprint(out, "  The square (each cell is two components ab):\n\n")
for i := 0; i < 10; i++ {
	fmt.Fprint(out, "   ")
	for j := 0; j < 10; j++ {
		fmt.Fprintf(out, " %d%d", square[i][j][0], square[i][j][1])
	}
	fmt.Fprint(out, "\n")
}
fmt.Fprint(out, "\n")

@ Now the two constraints meet. Each cell $(x,y)$ of the building is given a pair
$(a,b)$ by the square. Perec bundled his lists of material ten at a time into a
couple, and put the $a$th item of the one list and the $b$th of the other into
the chapter of that room. Because the square is orthogonal, the hundred cells
show a hundred combinations exactly once each---any pairing of the two lists
meets in the novel exactly once.

Perec kept twenty-one such couples, but his lists in full and their cell-by-cell
assignment fill the vast material of his working notebook (the {\it cahier des
charges\/}). Here, only to show the structure, we use one illustrative couple:
ten animals and ten colours.
@<Assign one couple of lists to chapters@>=
animals := [10]string{"cat", "dog", "horse", "fox", "bear", "deer", "rabbit", "wolf", "hawk", "mouse"}
colours := [10]string{"red", "orange", "yellow", "green", "blue", "indigo", "violet", "black", "white", "gray"}
fmt.Fprint(out, "  One couple (animal, colour) assigned to chapters (first eight):\n\n")
used := make(map[[2]int]bool)
for k, c := range tour {
	p := square[c.y-1][c.x-1]
	used[p] = true
	if k < 8 {
		fmt.Fprintf(out, "  ch.%2d (%d,%d): %s, %s\n",
			k+1, c.x, c.y, animals[p[0]], colours[p[1]])
	}
}
@<Show the missing combination is the clinamen's@>

@ The ninety-nine chapters use ninety-nine distinct combinations. Exactly one of
the hundred is missing---the combination the unvisited clinamen cell $(1,10)$
would have held. The blemish in the tour that fixes the order has taken away one
of the things to write as well.
@<Show the missing combination is the clinamen's@>=
fmt.Fprintf(out, "\n  combinations used: %d (of 100)\n", len(used))
q := square[9][0] // |square[10-1][1-1]|, clinamen cell $(1,10)$
fmt.Fprintf(out, "  missing combination: %s, %s  <- the share of clinamen cell (1,10)\n",
	animals[q[0]], colours[q[1]])

@ The output for the square continues like this: the verification result, the
square itself, and one illustrative couple assigned to chapters. Ninety-nine
combinations are used, and the last two lines confirm that the one share of the
clinamen cell is missing.
\medskip
\begingroup
\verbatim
PEREC: an order-10 Graeco-Latin square

  Are both components Latin squares?  A: true, B: true
  Are all 100 pairs distinct (orthogonal)?  true (100 distinct pairs)
  => here is the order-10 square Euler said could not exist.

  The square (each cell is two components ab):

    40 21 52 13 34 65 96 07 78 89
    33 79 88 04 66 91 25 12 47 50
    01 95 63 70 48 19 32 54 86 27
    76 37 94 82 09 28 11 60 53 45
    24 18 71 67 85 30 59 46 02 93
    58 80 05 39 97 72 44 23 61 16
    87 42 20 55 73 06 68 99 14 31
    15 03 49 26 51 84 77 38 90 62
    92 64 36 41 10 57 83 75 29 08
    69 56 17 98 22 43 00 81 35 74

  One couple (animal, colour) assigned to chapters (first eight):

  ch. 1 (6,6): wolf, yellow
  ch. 2 (8,7): mouse, gray
  ch. 3 (10,6): dog, violet
  ch. 4 (8,5): bear, violet
  ch. 5 (10,4): bear, indigo
  ch. 6 (9,2): bear, black
  ch. 7 (7,1): mouse, violet
  ch. 8 (8,3): deer, blue

  combinations used: 99 (of 100)
  missing combination: rabbit, gray  <- the share of clinamen cell (1,10)
!endgroup
\endgroup

@* Index.
