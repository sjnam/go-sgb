# go-sgb 빌드용 Makefile.
#
#   make            # tangle + go vet + go test
#   make tangle     # 라이브러리 패키지의 .w -> .go (+ _test.go)
#   make doc        # 각 .w의 .pdf 조판 (한글이라 luatex)
#   make twill      # gtwill로 오른쪽 쪽마다 미니 색인을 단 책꼴 .pdf 조판
#   make test       # go vet + go test
#   make clean      # 생성물 삭제 (.w 원본과 data/는 남김)
#
# 라이브러리 패키지의 .go는 go get이 되도록 커밋한다(일차 산출물은 .w). 데모와
# 루트 설치 검증 프로그램의 .go는 커밋하지 않는다.

GTANGLE ?= gtangle
GWEAVE  ?= gweave
GTWILL  ?= gtwill
REFSORT ?= gtwill-refsort
LUATEX  ?= luatex
WARNS   := 'Overfull\|Underfull\|Error\|Missing\|Undefined'

# 포팅이 진행되면서 여기에 패키지가 하나씩 늘어난다.
PKGS  := gbflip gbio gbgraph gbsort gbwords gbdijk gbmiles gbsave gbbasic gbbooks gbgames gbrand gbroget gblisa gbecon gbplane gbgates gbraman
DEMOS := demos/word_components demos/ladders demos/miles_span demos/queen demos/book_components demos/football demos/chain_bound demos/roget_components demos/assign_lisa demos/econ_order demos/take_risc demos/multiply demos/girth
# 설치 검증 프로그램은 데모가 아니라서 원본처럼 저장소 루트에 둔다.
ROOTS := test_sample

.PHONY: all tangle doc twill test clean queen_wrap $(PKGS) $(DEMOS) $(ROOTS)
.DEFAULT_GOAL := all

all: tangle $(DEMOS) $(ROOTS) queen_wrap test

tangle: $(PKGS)

$(PKGS) $(DEMOS):
	cd $@ && $(GTANGLE) $(notdir $@).w

$(ROOTS):
	$(GTANGLE) $@.w

# queen_wrap은 .w가 따로 없다 — 변경 파일 queen_wrap.ch를 queen.w에 물려 얻는다.
# 출력이 queen.go라는 이름으로 나오므로 원본과 겹치지 않게 다른 디렉터리에 둔다.
queen_wrap:
	mkdir -p demos/queen_wrap
	cd demos/queen && $(GTANGLE) -o ../queen_wrap queen.w queen_wrap.ch

test:
	go vet ./...
	go test ./...

# luatex은 nonstopmode라야 오류가 나도 멈추지 않고 .log에 다 남긴다.
doc:
	for p in $(PKGS) $(DEMOS); do \
	  (cd $$p && $(GWEAVE) $$(basename $$p).w && \
	   luatex --interaction=nonstopmode $$(basename $$p).tex); \
	done
	for r in $(ROOTS); do \
	  $(GWEAVE) $$r.w && luatex --interaction=nonstopmode $$r.tex; \
	done
	mkdir -p demos/queen_wrap
	cd demos/queen && $(GWEAVE) -o ../queen_wrap queen.w queen_wrap.ch
	cd demos/queen_wrap && luatex --interaction=nonstopmode queen.tex

# 원본 SGB 책은 CTWILL로 조판했다. gtwill이 그 GWEB판이다: gtwill이 .tex와 .aux를
# 쓰고, TeX 첫 판이 미니 색인 항목을 .mref로 내놓으면 gtwill-refsort가 그것을
# 가나다순으로 .smref에 갈무리하고, TeX 둘째 판이 그것을 읽어 미니 색인을 짠다.
# 묵은 .smref는 이제 없는 쪽을 가리키므로 첫 판 전에 지운다. 출력 이름이 gweave와
# 같아서(foo.tex, foo.pdf) make doc과 make twill은 서로의 결과를 덮어쓴다.
# 셸 변수 j에 웹 이름을 두고 그 디렉터리에서 부른다. luatex이 치명적 오류로 죽으면
# 로그에는 소문자 `error'만 남아 WARNS에 걸리지 않으니, PDF가 생겼는지도 따로 본다.
TWILL_TEX = rm -f $$j.smref; \
	  $(LUATEX) --interaction=nonstopmode $$j.tex >/dev/null; \
	  $(REFSORT) < $$j.mref > $$j.smref && \
	  $(LUATEX) --interaction=nonstopmode $$j.tex >/dev/null; \
	  if [ -s $$j.pdf ]; then echo "$$j.pdf: `grep -ac $(WARNS) $$j.log` warnings"; \
	  else echo "$$j.pdf: NOT PRODUCED (see $$j.log)"; fi

# chain_bound는 뺀다. 커밋해 둔 그 PDF는 커누스에게 보이는 gweave판이고, 바깥의
# decoframe.pdf를 그림으로 읽어야 조판된다.
TWILL_DEMOS := $(filter-out demos/chain_bound,$(DEMOS))

# 웹마다 gtwill 앞에서 twill/bux.py가 그 디렉터리에 system.bux(가져온 패키지의
# 이름)와 웹이름.bux(twill/hints.txt의 힌트)를 쓴다. 무엇을 어떻게 고르는지는 그
# 두 파일에 적혀 있다. 힌트는 다른 웹의 .aux를 빌려 쓰기도 하는데 그 웹이 차례상
# 뒤에 올 수도 있으므로, 먼저 모든 웹에 gtwill을 한 번씩 돌려 .aux를 마련한다.
# 셸 변수 j는 웹 이름이다.
BUX = python3 $(CURDIR)/twill/bux.py

twill:
	@for p in $(PKGS) $(TWILL_DEMOS); do \
	  (cd $$p && $(GTWILL) $$(basename $$p).w >/dev/null 2>&1); \
	done; \
	for j in $(ROOTS); do $(GTWILL) $$j.w >/dev/null 2>&1; done
	for p in $(PKGS) $(TWILL_DEMOS); do \
	  (cd $$p && j=$$(basename $$p) && $(BUX) $$j $$j.w && \
	   $(GTWILL) $$j.w && { $(TWILL_TEX); }); \
	done
	for j in $(ROOTS); do \
	  $(BUX) $$j $$j.w && $(GTWILL) $$j.w && { $(TWILL_TEX); }; \
	done
	mkdir -p demos/queen_wrap
	cd demos/queen && $(BUX) queen queen.w queen_wrap.ch && \
	  $(GTWILL) -o ../queen_wrap queen.w queen_wrap.ch
	cd demos/queen_wrap && j=queen && { $(TWILL_TEX); }

clean:
	rm -f */*.tex */*.idx */*.scn */*.toc */*.log */*.pdf */*.dvi
	rm -f demos/*/*.go demos/*/*.tex demos/*/*.idx demos/*/*.scn demos/*/*.toc demos/*/*.log demos/*/*.dvi
	rm -f */*.aux */*.mref */*.smref demos/*/*.aux demos/*/*.mref demos/*/*.smref  # gtwill 생성물
	rm -f */*.bux demos/*/*.bux *.bux    # make twill이 twill/bux.py로 만든 것
	# 커밋된 PDF(.gitignore에서 !로 예외 처리한 chain_bound.pdf)는 남기고
	# 재생성 가능한 나머지 데모 PDF만 지운다.
	find demos -mindepth 2 -maxdepth 2 -name '*.pdf' \
	  ! -name chain_bound.pdf -delete
	rm -f demos/*/*.mpx demos/*/*.[0-9]*        # MetaPost 중간물 (pic.tex, *.mp 원본은 남김)
	for r in $(ROOTS); do \
	  rm -f $$r.go $$r.tex $$r.idx $$r.scn $$r.toc $$r.log $$r.pdf $$r.aux $$r.mref $$r.smref; \
	done
