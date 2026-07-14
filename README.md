# go-sgb

Donald Knuth의 [Stanford GraphBase](https://www-cs-faculty.stanford.edu/~knuth/sgb.html)
(SGB)를 **한글 GWEB 문학적 프로그램**으로 옮겨 Go로 짜는 프로젝트다.
`.w` 문서가 일차 산출물이고, 여기서 `gtangle`로 Go 소스를, `gweave`+`luatex`로
한글 PDF 문서를 뽑아낸다.

module: `github.com/sjnam/go-sgb` · Go 1.26.5

## 원본과의 관계

`cweb-sgb/`에 SGB 원본 배포판(CWEB 소스, `.dat` 데이터 파일, 검증용
`test.correct`/`sample.correct`)을 그대로 두고 참조한다. SGB 라이선스가 수정을
금지하므로 이 디렉터리는 **읽기 전용**이며 통째로 gitignore되어 있다. 데이터
파일만 무수정 복사로 `data/`에 두고 커밋한다.

이 저장소는 예전에 순수 Go로 한 번 이식했던 것을 폐기하고, 원본 CWEB의
전통을 이어받아 문학적 프로그램으로 다시 쓴 결과다.

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
| | [gbgames](gbgames/gbgames.w) | 미식축구 점수 그래프 |
| | [gbmiles](gbmiles/gbmiles.w) | 북아메리카 도시 간 거리 그래프 |
| | [gbrand](gbrand/gbrand.w) | 무작위 그래프 |
| | [gbroget](gbroget/gbroget.w) | Roget 유의어 사전 그래프 |
| | [gbsave](gbsave/gbsave.w) | 그래프 저장·복원 |
| | [gbwords](gbwords/gbwords.w) | 다섯 글자 낱말 그래프 |
| | [gbdijk](gbdijk/gbdijk.w) | Dijkstra 최단경로 + 우선순위 큐 |
| 데모 | [demos/book_components](demos/book_components/book_components.w) | 이중연결 성분 |
| | [demos/chains](demos/chains/chains.w) | Knuth의 사슬 도전 문제 |
| | [demos/football](demos/football/football.w) | 팀 사이 승리 사슬 찾기 |
| | [demos/ladders](demos/ladders/ladders.w) | 낱말 사다리 |
| | [demos/miles_span](demos/miles_span/miles_span.w) | 최소 신장 트리 |
| | [demos/queen](demos/queen/queen.w) | 퀸의 행마 |
| | [demos/roget_components](demos/roget_components/roget_components.w) | Roget 그래프의 강한 성분 |
| | [demos/word_components](demos/word_components/word_components.w) | 낱말 그래프 연결 성분 |

남은 것: gb_lisa, gb_econ, gb_gates, gb_plane, gb_raman, test_sample.

패키지 디렉터리 이름은 패키지명과 같다(`gbflip/gbflip.w` → package `gbflip`).
각 패키지 `.w`는 본문(`패키지.go`)과 시험(`패키지_test.go`)을 함께 뽑는다 —
`demos/`의 시연 프로그램에는 시험이 없다. 공유하는 \.{GWEB} 서식 힌트는
루트 [types.w](types.w)에 모아 `@i`로 끌어와 쓴다.

**tangle로 생성되는 `.go`·`.tex`·`.pdf`는 커밋하지 않는다** — `.gitignore`
참고. 일차 산출물은 어디까지나 `.w`다.

## 빌드

\.{GWEB} 문학적 프로그래밍 도구(`gtangle`, `gweave`)와 한글 조판용
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
`cweb-sgb/sample.correct`에 대조해 확인한다.
