% perec_en.mp -- figures for perec_en.w.
%   fig 1: the facade of 11 rue Simon-Crubellier cut away like a doll's house
%          into a 10x10 grid, with Perec's knight's tour laid on it. Each cell
%          bears its chapter number; consecutive chapters are joined by a line.
%          The bottom-left corner is the empty clinamen; the 65->66 step, a
%          non-knight diagonal move, is dashed.
%   fig 2: the embedded order-10 Graeco-Latin square, coloured like the
%          Scientific American cover (upper triangle = first component,
%          lower = second), with small digits.
% Build with: mptopdf perec_en.mp  (-> perec_en-1.pdf, perec_en-2.pdf)
% Every label is a plain digit, so no btex/LaTeX preamble is needed.

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

% fig 2: the order-10 Graeco-Latin square embedded in the program, drawn like
% the Scientific American cover: each cell is split on its diagonal, the upper
% triangle coloured by the first component, the lower by the second. Both are
% Latin, so each colour appears once per row/column; orthogonal, so no upper-lower colour pair repeats.
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
endfig;

end.
