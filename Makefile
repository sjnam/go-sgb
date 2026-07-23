# go-sgb 빌드용 Makefile.
#
#   make            # tangle + go vet + go test
#   make tangle     # 각 .w -> .go (패키지는 + _test.go; demos/는 시험 없음)
#   make doc        # 각 .w의 .pdf 조판 (한글이라 luatex)
#   make test       # go vet + go test
#   make clean      # 생성물 삭제 (.w 원본과 data/는 남김)
#
# 생성된 .go는 커밋하지 않는다 — 일차 산출물은 .w다.

GTANGLE ?= gtangle
GWEAVE  ?= gweave

# 포팅이 진행되면서 여기에 패키지가 하나씩 늘어난다.
PKGS  := gbflip gbio gbgraph gbsort gbwords gbdijk gbmiles gbsave gbbasic gbbooks gbgames gbrand gbroget gblisa gbecon gbplane gbgates gbraman
DEMOS := demos/word_components demos/ladders demos/miles_span demos/queen demos/book_components demos/football demos/chains demos/chain_bound demos/chain_bound_ko demos/sham demos/roget_components demos/assign_lisa demos/econ_order demos/take_risc demos/multiply demos/girth
# 설치 검증 프로그램은 데모가 아니라서 원본처럼 저장소 루트에 둔다.
ROOTS := test_sample

.PHONY: all tangle doc test clean queen_wrap $(PKGS) $(DEMOS) $(ROOTS)
.DEFAULT_GOAL := all

all: tangle test

tangle: $(PKGS) $(DEMOS) $(ROOTS) queen_wrap

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

clean:
	rm -f */*.go */*.tex */*.idx */*.scn */*.toc */*.log */*.pdf */*.dvi
	rm -f demos/*/*.go demos/*/*.tex demos/*/*.idx demos/*/*.scn demos/*/*.toc demos/*/*.log demos/*/*.pdf demos/*/*.dvi
	for r in $(ROOTS); do \
	  rm -f $$r.go $$r.tex $$r.idx $$r.scn $$r.toc $$r.log $$r.pdf; \
	done
