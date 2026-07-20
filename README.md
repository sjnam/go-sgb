# go-sgb

Donald Knuth의 [Stanford GraphBase](https://www-cs-faculty.stanford.edu/~knuth/sgb.html)
(SGB)를 **한글 GWEB 문학적 프로그램**으로 옮겨 Go로 짜는 프로젝트다.
`.w` 문서가 일차 산출물이고, 여기서 `gtangle`로 Go 소스를, `gweave`+`luatex`로
한글 PDF 문서를 뽑아낸다.

module: `github.com/sjnam/go-sgb` · Go 1.26.5

## 구조

SGB는 세 층으로 구성되고, 이식도 그 구조를 따른다.

| 층 | 패키지/디렉터리 | 비고 |
| --- | --- | --- |
| 커널 | [gbflip](gbflip/gbflip.w) | 난수 |
| | [gbio](gbio/gbio.w) | 데이터 파일 입출력 |
| | [gbgraph](gbgraph/gbgraph.w) | 그래프 자료구조 |
| | [gbsort](gbsort/gbsort.w) | 연결 리스트 정렬 |
| 생성기·유틸리티 | [gbbasic](gbbasic/gbbasic.w) | 표준 그래프 여섯 생성기 |
| | [gbbooks](gbbooks/gbbooks.w) | 문학 작품 인물 관계 그래프 |
| | [gbecon](gbecon/gbecon.w) | 미국 경제 부문 간 흐름 그래프 |
| | [gbgames](gbgames/gbgames.w) | 미식축구 점수 그래프 |
| | [gbgates](gbgates/gbgates.w) | 논리 회로(RISC·곱셈기) 게이트 그래프 |
| | [gblisa](gblisa/gblisa.w) | 모나리자 픽셀 행렬·평면·이분 그래프 |
| | [gbmiles](gbmiles/gbmiles.w) | 북아메리카 도시 간 거리 그래프 |
| | [gbplane](gbplane/gbplane.w) | 델로네 삼각분할 기반 평면 그래프 |
| | [gbraman](gbraman/gbraman.w) | Ramanujan 그래프(사원수 기반) |
| | [gbrand](gbrand/gbrand.w) | 무작위 그래프 |
| | [gbroget](gbroget/gbroget.w) | Roget 유의어 사전 그래프 |
| | [gbsave](gbsave/gbsave.w) | 그래프 저장·복원 |
| | [gbwords](gbwords/gbwords.w) | 다섯 글자 낱말 그래프 |
| | [gbdijk](gbdijk/gbdijk.w) | Dijkstra 최단경로 + 우선순위 큐 |
| 데모 | [demos/assign_lisa](demos/assign_lisa/assign_lisa.w) | 배정 문제(헝가리 알고리즘) |
| | [demos/book_components](demos/book_components/book_components.w) | 이중연결 성분 |
| | [demos/chains](demos/chains/chains.w) | Knuth의 사슬 도전 문제(최적값 2473 증명) |
| | [demos/econ_order](demos/econ_order/econ_order.w) | 경제 부문 준삼각 순서 |
| | [demos/football](demos/football/football.w) | 팀 사이 승리 사슬 찾기 |
| | [demos/girth](demos/girth/girth.w) | Ramanujan 그래프의 둘레·지름 |
| | [demos/ladders](demos/ladders/ladders.w) | 낱말 사다리 |
| | [demos/miles_span](demos/miles_span/miles_span.w) | 최소 신장 트리 |
| | [demos/multiply](demos/multiply/multiply.w) | 곱셈 회로로 큰 수 곱하기 |
| | [demos/queen](demos/queen/queen.w) | 퀸의 행마 |
| | [demos/roget_components](demos/roget_components/roget_components.w) | Roget 그래프의 강한 성분 |
| | [demos/take_risc](demos/take_risc/take_risc.w) | RISC 회로로 곱셈·나눗셈 |
| | [demos/test_sample](demos/test_sample/test_sample.w) | 설치 검증(모든 생성기 표본) |
| | [demos/word_components](demos/word_components/word_components.w) | 낱말 그래프 연결 성분 |

SGB 전 모듈 이식 완료.

패키지 디렉터리 이름은 패키지명과 같다(`gbflip/gbflip.w` → package `gbflip`).
각 패키지 `.w`는 본문(`패키지.go`)과 시험(`패키지_test.go`)을 함께 뽑는다 —
`demos/`의 시연 프로그램에는 시험이 없다. 공유하는 \.{GWEB} 서식 힌트는
루트 [gbtypes.w](gbtypes.w)에 모아 `@i`로 끌어와 쓴다.

**tangle로 생성되는 `.go`·`.tex`·`.pdf`는 커밋하지 않는다** — `.gitignore`
참고. 일차 산출물은 어디까지나 `.w`다.

## 빌드

GWEB 문학적 프로그래밍 도구(`gtangle`, `gweave`)와 한글 조판용
`luatex`(`kotexgweb`)가 설치되어 있어야 한다.

```sh
make            # tangle + go vet + go test
make tangle     # 각 .w -> .go (패키지는 + _test.go)
make test       # go vet + go test
make doc        # 각 .w를 조판해 .pdf로
make clean      # 생성물 삭제 (.w 원본과 data/는 남김)
```

표준 Go 도구도 그대로 쓸 수 있다(단, 먼저 `make tangle`로 `.go`를 생성해야
한다):

```sh
go build ./...
go test ./...
go test ./<pkg> -run TestName
go vet ./...
```

## 검증

데모 출력은 Knuth가 발표한 값과 `cweb-sgb/test.correct`,
`cweb-sgb/sample.correct`에 대조해 확인한다. `demos/test_sample`은 거의 모든
생성기를 불러 그 표준 출력이 `sample.correct`와 **바이트 단위로 일치**하고, 부차
산출물 `test.gb`도 `test.correct`와 **바이트 단위로 일치**함을 확인했다(자료는
`/usr/local/sgb/data`에서 읽는다).

원본이 `gb_typed_alloc`으로 만들어 정점 배열 바로 뒤(`vertices[7]`)에 얹는 stray
정점("Testing")은, `gbgraph`에 `AllocVertex`(SGB의 `gb_typed_alloc`에 대응)를
두어 재현했다. `NewGraph`가 정점 슬라이스에 여분 용량을 잡아 두므로 이 정점이
제자리로 이어 붙어, 기존 정점·호 포인터를 깨지 않으면서 `Index`로 참조되고
`gbsave`가 함께 저장한다.
