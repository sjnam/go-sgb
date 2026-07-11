# go-sgb 빌드용 Makefile.
#
#   make            # tangle + go vet + go test
#   make tangle     # 각 패키지의 .w -> .go (+ _test.go)
#   make doc        # 각 패키지의 .pdf 조판 (한글이라 luatex)
#   make test       # go vet + go test
#   make clean      # 생성물 삭제 (.w 원본과 data/는 남김)
#
# 생성된 .go는 커밋하지 않는다 — 일차 산출물은 .w다.

GTANGLE ?= gtangle
GWEAVE  ?= gweave

# 포팅이 진행되면서 여기에 패키지가 하나씩 늘어난다.
PKGS := gbflip gbio gbgraph gbsort

.PHONY: all tangle doc test clean $(PKGS)
.DEFAULT_GOAL := all

all: tangle test

tangle: $(PKGS)

$(PKGS):
	cd $@ && $(GTANGLE) $@.w

test:
	go vet ./...
	go test ./...

doc:
	for p in $(PKGS); do (cd $$p && $(GWEAVE) $$p.w && luatex $$p.tex </dev/null); done

clean:
	rm -f */*.go */*.tex */*.idx */*.scn */*.toc */*.log */*.pdf
