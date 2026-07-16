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
PKGS  := gbflip gbio gbgraph gbsort gbwords gbdijk gbmiles gbsave gbbasic gbbooks gbgames gbrand gbroget gblisa gbecon gbplane gbgates
DEMOS := demos/word_components demos/ladders demos/miles_span demos/queen demos/book_components demos/football demos/chains demos/sham demos/roget_components demos/assign_lisa demos/econ_order demos/take_risc

.PHONY: all tangle doc test clean $(PKGS) $(DEMOS)
.DEFAULT_GOAL := all

all: tangle test

tangle: $(PKGS) $(DEMOS)

$(PKGS) $(DEMOS):
	cd $@ && $(GTANGLE) $(notdir $@).w

test:
	go vet ./...
	go test ./...

doc:
	for p in $(PKGS) $(DEMOS); do \
	  (cd $$p && $(GWEAVE) $$(basename $$p).w && luatex $$(basename $$p).tex </dev/null); \
	done

clean:
	rm -f */*.go */*.tex */*.idx */*.scn */*.toc */*.log */*.pdf
	rm -f demos/*/*.go demos/*/*.tex demos/*/*.idx demos/*/*.scn demos/*/*.toc demos/*/*.log demos/*/*.pdf
