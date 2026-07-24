% go-sgb: Knuth의 Stanford GraphBase를 한글 GWEB로 옮긴 것.
% 이 파일은 gb_words.w를 Go로 이식한다.
@i ../gbtypes.w

\input kotexgweb
\def\title{GB\_\,WORDS}
\font\logosl=logosl10

@* 들어가며. 이 모듈은 \.{GWEB} 생성기 층의 첫 주자다. 앞선 네 커널 모듈
(|gbflip|, |gbio|, |gbgraph|, |gbsort|)이 지금까지 각자의 자리에서 조용히
기다리고 있었다면, 여기서 비로소 넷이 한자리에 모여 일을 벌인다. 난수는
|gbflip|에서, 파일 읽기는 |gbio|에서, 그래프 자료 구조는 |gbgraph|에서,
그리고 무게순 정렬은 |gbsort|에서 빌려 온다. 이 모듈은 그것들을 엮어 영어
다섯 글자 낱말들의 그래프를 짓는다.

패키지 |gbwords|는 바깥에 두 함수를 내놓는다.

$$\vbox{\halign{\indent#\hfil\cr
|Words|, 다섯 글자 낱말들로 그래프를 짓는 함수;\cr
|FindWord|, 그런 그래프에서 주어진 정점을 찾는 함수.\cr}}$$

이 함수들의 쓰임새는 두 데모 프로그램 {\sc WORD\_COMPONENTS}와
{\sc LADDERS}에서 볼 수 있다. 특히 {\sc LADDERS}는 유서 깊은 놀이를
푸는데, 바로 Lewis Carroll이 1877년에 고안한 ``doublets''다. 한 낱말에서
한 번에 한 글자씩만 바꾸어 다른 낱말로 건너가는 사다리 놀이인데, 예컨대
`\.{words}'에서 `\.{cords}', `\.{wards}', `\.{woods}', `\.{worms},
`\.{wordy}' 따위로 한 걸음씩 옮겨 갈 수 있다. 우리가 지금 짓는 그래프는 바로 이
``한 글자만 다른'' 관계를 간선으로 삼는다.

@ |Words(n, wtVector, wtThreshold, seed, dir)|은 |dir|
디렉터리의 \.{words.dat}에 담긴 다섯 글자 낱말들로 그래프를 짓는다. 그래프의
정점 하나가 낱말 하나에 대응하며, 두 낱말이 정확히 한 글자 자리에서만 다르면
그래프에서 서로 이웃한다.

그래프는 많아야 |n|개의 정점을 가진다. 자격을 갖춘 낱말이 넉넉하다면 딱 |n|개다.
낱말은 그 ``무게''가 |wtThreshold| 이상일 때 자격을 얻는데, 무게는
|wtVector|가 가리키는 표에 따라 계산한다(잠시 뒤에 규칙을 설명한다). |wtVector|가
|nil|이면 기본 무게를 쓴다. 마지막에서 둘째 인자 |seed|는 난수 씨앗이다.

\.{words.dat}의 모든 낱말은 무게순으로 정렬된다. 그래프의 첫 정점은 무게가 가장
큰 낱말이고, 둘째 정점은 그다음, 이런 식이다. 무게가 같은 낱말들은 |seed|가
정하는 유사난수 차례로 나타나며, 그 차례는 어느 컴퓨터에서나 똑같다. 무게가 큰
쪽부터 |n|개를 골라 정점으로 삼는다. 다만 무게 |wtThreshold| 이상인 낱말이
|n|개보다 적으면, 그래프에는 자격을 갖춘 낱말만 담긴다---그런 경우 정점 수는
|n|보다 적을 수 있고, 어쩌면 하나도 없을 수도 있다.

예외: 특별한 경우 |n=0|은 |n|을 가능한 최대값으로 놓은 것과 같다. 자격을 갖춘
모든 낱말이 나타나게 한다.

@ \.{words.dat}의 낱말들은 저마다 `흔함'(\.*), `고급'(\.+), `드묾'(빈칸)으로
분류돼 있다. 낱말마다 일곱 개의 빈도수 $c_1,\ldots,c_7$이 쉼표로 나뉘어 붙어
있는데, 그 낱말이 서로 다른 출판 맥락에서 얼마나 자주 나타났는지를 보여 준다.

$$\vbox{\halign{$c_#$번 나타남:\quad&#\hfil\cr
1&미국 초등 교재 American Heritage Intermediate Corpus;\cr
2&미국 읽기 자료 Brown Corpus;\cr
3&영국 읽기 자료 Lancaster-Oslo/Bergen Corpus;\cr
4&오스트레일리아 신문 Melbourne-Surrey Corpus;\cr
5&개정 표준역 성경(RSV);\cr
6&Knuth의 {\sl The \TeX book\/}과 {\sl The {\logosl METAFONT\kern1pt}book\/};\cr
7&Graham, Knuth, Patashnik의 {\sl Concrete Mathematics\/}.\cr}}$$

예컨대 \.{words.dat}의 한 항목은 $$\.{happy*774,92,121,2,26,8,1}$$
인데, 이는 $c_1=774,\ldots,c_7=1$인 흔한 낱말임을 뜻한다.

|wtVector|는 아홉 정수 $(a,b,w_1,\ldots,w_7)$의 배열을 가리킨다. 각 낱말의
무게는 이 아홉 수로부터 다음 식으로 계산한다.
$$c_1w_1+\cdots+c_7w_7+
 \cases{a,&낱말이 `흔함'이면;\cr
        b,&낱말이 `고급'이면;\cr
        0,&낱말이 `드묾'이면.\cr}$$
|wtVector|의 성분은 반드시
$$\max\bigl(\vert a\vert, \vert b\vert\bigr)
 + C_1\vert w_1\vert + \cdots +C_7\vert w_7\vert < 2^{30}$$
를 지키도록 골라야 한다. 여기서 $C_j$는 파일 안 $c_j$의 최대값이다. 이 제약
덕분에 |Words|는 어느 컴퓨터에서나 똑같은 결과를 낸다.

@ 실제로 나타나는 최대 빈도수는 $C_1=15194$, $C_2=3560$, $C_3=4467$,
$C_4=460$, $C_5=6976$, $C_6=756$, $C_7=362$이다. 이 값들은 흔한 낱말
`\.{shall}', `\.{there}', `\.{which}', `\.{would}'의 항목에서 찾을 수 있다.

기본 무게는 $a=100$, $b=10$, $c_1=4$, $c_2=c_3=2$, $c_4=c_5=c_6=c_7=1$이다.

\.{words.dat}에는 5757개의 낱말이 있다. 그중 3300개가 `흔함', 1194개가
`고급', 1263개가 `드묾'이다. 드문 낱말 가운데 891개는
$c_1=\cdots=c_7=0$이라서, 무게 벡터가 무엇이든 무게가 늘 0이다.

@ 보기를 들어 보자. |Words(2000,nil,0,0,dir)|을 부르면 기본 무게를 써서 영어에서
가장 흔한 다섯 글자 낱말 2000개의 그래프를 얻는다. GraphBase 프로그램들은 시스템에
상관없이 같은 결과를 내도록 설계돼 있으므로, |Words(2000,nil,0,0,dir)|을 청한
사람은 누구나 똑같은 그래프를 얻는다. 그래서 세계 어디에 있는 연구자든 그래프
알고리즘에 대해 동등한 실험을 해 볼 수 있다.

|Words(2000,nil,0,s,dir)|은 씨앗 |s|에 따라 조금씩 다른 그래프를 낸다. 무게가 같은
낱말들이 있기 때문이다. 그렇더라도 |s| 값 하나를 정하면 그 그래프는 어느
컴퓨터에서나 같다. 씨앗은 $0\le s<2^{31}$ 범위의 아무 정수나 된다.

@ 이번에는 |wtVector|를 직접 주는 보기들이다. |w|를
$$|w := []int64{1}| \hbox{\rm (나머지는 0)}$$
로 두고 |Words(0,w,1,0,dir)|을 부른다고 하자. 이는 $a=1$이고
$b=w_1=\cdots=w_7=0$이라는 뜻이므로, `흔함'으로 분류된 3300개 낱말만 담은 그래프를
얻는다. 마찬가지로 무게 벡터를
$$|w := []int64{1, 1}| \hbox{\rm (나머지는 0)}$$
로 주면 $a=b=1$이고 $w_1=\cdots=w_7=0$이 되어, `드묾'이 아닌
$3300+1194=4494$개 낱말을 얻는다. 이 두 보기에서는 자격을 갖춘 낱말의 무게가 모두
1이므로, 그래프의 정점들이 유사난수 차례로 나타난다.

|w|가 0 아홉 개의 배열을 가리키면 |Words(n,w,0,s,dir)|은 |n|개 낱말의 무작위
표본을 주는데, 그 표본은 시스템에 상관없이 |s|에만 달려 있다.

무게 벡터의 성분이 모두 음이 아니고 무게 문턱이 0이면 \.{words.dat}의 모든 낱말이
자격을 얻으므로, 정점이 $\min(n,5757)$개인 그래프를 얻는다.

|w|가 {\sl 음의\/} 무게를 담은 배열을 가리키면
|Words(n,w,-0x7fffffff,0,dir)|은 \.{words.dat}에서 {\sl 가장 덜\/} 흔한 낱말
|n|개를 고른다.

@ 두 표는 이 패키지 안에만 두는 사적인 자료다. |maxC|는 방금 말한 최대
빈도수이고, |defaultWtVector|는 |wtVector|가 |nil|일 때 쓰는 기본 무게 벡터다.
정렬 키는 음수가 아니어야 하므로(이는 |gbsort|의 요구다) 무게에 $2^{30}$을
더해 |weightBias|만큼 띄운다. |hashPrime|은 곧 만들 다섯 해시 표의 크기로,
낱말 총수보다 조금 큰 소수를 골랐다.

@<상수, 표, 자료 구조@>=
const (
	weightBias = 1 << 30 // 정렬 키는 가중치에 $2^{30}$을 더한 값
	hashPrime  = 6997    // 낱말 총수보다 조금 큰 소수
)

var maxC = [7]int64{15194, 3560, 4467, 460, 6976, 756, 362} // 최대 빈도수 $C_j$

var defaultWtVector = []int64{100, 10, 4, 2, 2, 1, 1, 1, 1} // |wtVector|가 |nil|일 때

@ 프로그램의 뼈대는 다음과 같다. 커널 네 패키지를 모두 끌어와, 상수와 자료
구조를 두고, 보조 함수들을 정의한 뒤, 바깥에 내놓을 두 서브루틴 |Words|와
|FindWord|를 짓는다.
@c
package gbwords

import (
	"fmt"
	"math"
	"path/filepath"
	@#
	"github.com/sjnam/go-sgb/gbflip"
	"github.com/sjnam/go-sgb/gbgraph"
	"github.com/sjnam/go-sgb/gbio"
	"github.com/sjnam/go-sgb/gbsort"
)

const DataDirectory = "/usr/local/sgb/data"

@<상수, 표, 자료 구조@>
@<보조 함수@>
@<입력을 읽는 함수@>
@<그래프를 짓는 |Words|@>
@<낱말을 찾는 |FindWord|@>

@ 이제 본론이다. |Words|는 씨앗으로 난수 스트림을 하나 열고, 무게 벡터가
올바른지 확인한 다음, 자격을 갖춘 낱말들을 연결 리스트로 읽어들이고, 끝으로
그것들을 정렬해 그래프로 뽑아낸다. \CEE/ 원본은 오류가 나면 \.{NULL}을
돌려주며 전역 |panic_code|에 코드를 남겼지만, 우리는 그 코드를 |gbgraph|의
|PanicCode| 오류값으로 그대로 돌려준다.

|usedDefault|는 나중에 표식 문자열을 지을 때 쓰려고, |wtVector|를 기본값으로
바꾸기 전에 미리 기억해 둔다. \CEE/는 포인터가 |default_wt_vector|와 같은지
견주었지만, 여기서는 |nil| 여부를 한 번 적어 두는 편이 깔끔하다.

@<그래프를 짓는 |Words|@>=
func Words(n int64, wtVector []int64, wtThreshold, seed int64, dir string) (
	*gbgraph.Graph, error,
) {
	if dir == "" {
		dir = DataDirectory
	}
	rng := gbflip.New(seed)
	usedDefault := wtVector == nil
	@<가중치 벡터가 올바른지 검증한다@>
	@<자격을 갖춘 낱말들을 연결 리스트로 읽어들인다@>
	@<낱말들을 정렬해 그래프로 출력한다@>
	return g, nil
}

@* 무게를 검증한다. |Words|가 맨 먼저 할 일은 견주어 보면 사소하다. 우리는 조건
$$\max\bigl(\vert a\vert, \vert b\vert\bigr)
 + C_1\vert w_1\vert + \cdots +C_7\vert w_7\vert < 2^{30}\eqno(*)$$
이 성립하는지 확인하려 한다. \CEE/ 원본에서 이는 ``이식성 있는 프로그래밍''의
흥미로운 연습 문제였다. 정수 넘침의 위험을 무릅쓰고 싶지 않았기 때문이다.
그래서 먼저 부동소수점으로 대충 걸러 낸 뒤, 그 관문을 통과한 것만 정수
연산으로 정확히 시험했다.

\GO/의 |int64|는 넘침 걱정이 \CEE/의 |long|보다 훨씬 덜하지만, 그렇다고
방심할 일은 아니다. 누군가 $2^{60}$쯤 되는 터무니없는 무게를 넘기면
|maxC[j]*w|가 |int64|의 한계를 넘어 돌아 버릴 수 있다. Knuth의 부동소수점
체는 바로 그런 병적인 입력을 정수 산술에 닿기 전에 걸러 주므로, 우리도 그
지혜를 그대로 물려받는다.

@<가중치 벡터가 올바른지 검증한다@>=
if wtVector == nil {
	wtVector = defaultWtVector
} else {
	@<아홉보다 짧은 |wtVector|를 0으로 채운다@>
	@<부동소수점으로 |wtVector|가 터무니없지 않은지 본다@>
	@<정수 연산으로 |wtVector|가 정말 괜찮은지 확인한다@>
}

@ \CEE/에서 |long w[9] = {1};|은 나머지 여덟 성분이 0으로 채워진 아홉 원소
배열이다. 그런데 \GO/에서 |[]int64{1}|은 원소가 하나뿐인 조각이라, 앞의 보기들을
적힌 그대로 옮겨 쓰면 나머지 성분을 읽다가 프로그램이 죽어 버린다. 그래서 아홉보다
짧은 무게 벡터는 0으로 채워 \CEE/의 뜻과 맞춘다. 그러면 |[]int64{1}|이 정확히
|long w[9] = {1};|을 뜻하고, |[]int64{1,1}|이 |long w[9] = {1,1};|을 뜻한다.
아홉보다 긴 벡터의 남는 성분은 \CEE/에서와 마찬가지로 거들떠보지 않는다.

@<아홉보다 짧은 |wtVector|를 0으로 채운다@>=
if len(wtVector) < 9 {
	padded := make([]int64, 9)
	copy(padded, wtVector)
	wtVector = padded
}

@ 부동소수점 산술은 시스템마다 다르지만, 적어도 16비트의 정밀도는 쓴다고
믿어도 좋다. 그러면 조건 $(*)$이 성립할 때 아래 합의 부동소수점 값은
$2^{30}+2^{29}$보다 작다. 그래서 이 시험은 올바른 무게 벡터를 결코 물리치지
않는다. 상수 $\.{0x60000000}=6\times2^{28}=2^{30}+2^{29}$이 그 문턱이다.

@<부동소수점으로 |wtVector|가 터무니없지 않은지 본다@>=
flacc := math.Abs(float64(wtVector[0]))
if b := math.Abs(float64(wtVector[1])); flacc < b {
	flacc = b // 이제 |flacc|는 $\max(\vert a\vert,\vert b\vert)$
}
for j := 0; j < 7; j++ {
	flacc += float64(maxC[j]) * math.Abs(float64(wtVector[2+j]))
}
if flacc >= float64(0x60000000) {
	return nil, gbgraph.VeryBadSpecs // 무게 벡터가 한참 벗어났다
}

@ 거꾸로, 방금 한 부동소수점 시험을 통과했다면 참값의 합은
$2^{30}+2^{29}+2^{29}=2^{31}$보다 작다. 따라서 다음의 더 정밀한 정수 시험에서
넘침은 결코 일어나지 않는다. 문턱은 $|0x40000000|=2^{30}$이다.

@<정수 연산으로 |wtVector|가 정말 괜찮은지 확인한다@>=
acc := iabs(wtVector[0])
if b := iabs(wtVector[1]); acc < b {
	acc = b // 이제 |acc|는 $\max(\vert a\vert,\vert b\vert)$
}
for j := 0; j < 7; j++ {
	acc += maxC[j] * iabs(wtVector[2+j])
}
if acc >= 0x40000000 {
	return nil, gbgraph.BadSpecs // 무게 벡터가 조금 크다
}

@ 정수의 절댓값을 구하는 소박한 도우미다. \GO/ 표준 라이브러리의 |math.Abs|는
|float64| 전용이라, |int64|에는 이 한 줄짜리를 따로 둔다.

@<보조 함수@>=
func iabs(x int64) int64 {
	if x >= 0 {
		return x
	}
	return -x
}

@* 입력 단계. 이제 \.{words.dat}를 읽을 차례다. \CEE/ 원본은 111개씩
노드 블록을 손수 할당하고 나중에 되돌려주는 살림을 했지만, Go에서는 가비지
컬렉터가 그 몫을 대신하므로 우리는 그냥 노드를 하나씩 앞에 이어 붙여 스택을
쌓으면 된다. 노드는 |gbsort.Node|를 그대로 쓴다. 정렬 키에는 무게에
|weightBias|를 더한 값을 넣고, 딸린 데이터에는 다섯 글자 낱말을 담는다.

파일을 여는 데 실패하면 |EarlyDataFault|, 닫는 데 실패하면 |LateDataFault|다.
\CEE/의 |panic|은 파일을 닫지 않고 그냥 빠져나갔지만, 우리는 어떤 경로로든
파일을 닫아 파일 서술자를 흘리지 않는다.

@<자격을 갖춘 낱말들을 연결 리스트로 읽어들인다@>=
f, err := gbio.Open(filepath.Join(dir, "words.dat"))
if err != nil {
	return nil, gbgraph.EarlyDataFault
}
stack, nn, err := readWords(f, wtVector, wtThreshold)
if cerr := f.Close(); err == nil && cerr != nil {
	err = gbgraph.LateDataFault
}
if err != nil {
	return nil, err
}

@ |readWords|는 파일을 한 줄씩 훑으며 자격을 갖춘 낱말을 스택에 쌓는다. 조기
반환은 오로지 구문 오류를 위층으로 알리려는 것이라, 이 경계는 함수로 두어야
뜻이 산다---오류가 나면 |Words|가 파일을 닫고 그 오류를 그대로 돌려줄 수
있도록.

각 줄은 다섯 글자 낱말로 시작한다. \.{words.dat}의 낱말 |"aargh"|처럼 뒤에
아무 표식 없이 줄이 끝나기도 하는데, 그럴 때 |Char|는 |'\n'|을 준다.

@<입력을 읽는 함수@>=
func readWords(f *gbio.File, wtVector []int64, wtThreshold int64) (
stack *gbsort.Node[string], nn int64, err error,
) {
	for {
		var word [5]byte
		for j := range word {
			word[j] = f.Char()
		}
		var wt int64
		@<이 낱말의 무게 |wt|를 계산한다@>
		if wt >= wtThreshold { // 자격을 갖췄다
			stack = &gbsort.Node[string]{Key: wt + weightBias, Data: string(word[:]), Link: stack}
			nn++
		}
		f.NextLine()
		if f.EOF() {
			break
		}
	}
	return stack, nn, nil
}

@ |Number|는 현재 자리에 숫자가 없으면 오류 없이 0을 준다. 그 덕분에
\.{words.dat}는 0인 빈도수를 굳이 적지 않아도 되고, 어떤 줄에서 뒤따르는
빈도수가 모두 0이면 쉼표까지 생략할 수 있다.

낱말의 종류를 나타내는 표식 문자를 먼저 읽어 기본 무게를 정한 뒤, 쉼표로
이어지는 빈도수를 차례로 더한다. 빈도수가 일곱 개를 넘거나 최대값 $C_j$를
넘으면 구문 오류다. 여기서 |return|은 감싸는 |readWords|를 끝내며 오류를
위로 실어 나른다.

@<이 낱말의 무게 |wt|를 계산한다@>=
switch f.Char() {
case '*':
	wt = wtVector[0] // `흔함'
case '+':
	wt = wtVector[1] // `고급'
case ' ', '\n':
	wt = 0 // `드묾'
default:
	return nil, 0, gbgraph.SyntaxError // 알 수 없는 종류
}
for j := 0; ; j++ {
	if j == 7 {
		return nil, 0, gbgraph.SyntaxError + 1 // 빈도수가 너무 많다
	}
	c := f.Number(10)
	if c > maxC[j] {
		return nil, 0, gbgraph.SyntaxError + 2 // 빈도수가 너무 크다
	}
	wt += c * wtVector[2+j]
	if f.Char() != ',' {
		break
	}
}

@* 출력 단계. 입력 단계가 \.{words.dat}를 다 훑고 나면, 자격을 갖춘 |nn|개의
낱말이 |stack|에서 시작하는 스택에 쌓여 있다.

다음 걸음은 |gbsort.LinkSort|를 부르는 것이다. 이 함수는 낱말들을 128개의
리스트로 나눠 담는데, 우리는 |sorted[127]|부터 |sorted[0]|까지 거슬러 읽으며
무게가 큰 차례로 낱말을 얻는다. 씨앗으로 연 난수 스트림 |rng|를 그대로
넘기므로, 무게가 같은 낱말들의 순서는 어느 컴퓨터에서나 똑같다.

@<낱말들을 정렬해 그래프로 출력한다@>=
sorted := gbsort.LinkSort(stack, rng)
@<새 그래프의 저장 공간을 마련하고 |n|을 조정한다@>
ht := makeWordHash()
var added int64
Outer:
for j := 127; j >= 0; j-- {
	for p := sorted[j]; p != nil; p = p.Link {
		@<낱말 |p.Data|를 그래프에 더한다@>
		added++
		if added == n {
			break Outer
		}
	}
}

@ 자격을 갖춘 낱말이 |n|개보다 적거나 |n=0|이면 |n|을 실제 개수 |nn|으로
맞춘다. 그런 다음 그래프를 만들고 표식 문자열을 짓는다. \CEE/는
|sprintf|로 |id| 배열에 찍었지만, 우리는 |fmt.Sprintf|로 한다. 유틸리티
필드의 쓰임새를 적은 |UtilTypes|는 |"IZZZZZIZZZZZZZ"|인데, 0번 자리(정점의
|U|)에 무게를 정수로 두고, 6번 자리(호의 |A|)에 차이 나는 글자 자리를 정수로
둔다는 뜻이다.

@<새 그래프의 저장 공간을 마련하고 |n|을 조정한다@>=
if n == 0 || nn < n {
	n = nn
}
g := gbgraph.NewGraph(n)
if usedDefault {
	g.ID = fmt.Sprintf("words(%d,0,%d,%d)", n, wtThreshold, seed)
} else {
	g.ID = fmt.Sprintf("words(%d,{%d,%d,%d,%d,%d,%d,%d,%d,%d},%d,%d)",
		n, wtVector[0], wtVector[1], wtVector[2], wtVector[3], wtVector[4],
		wtVector[5], wtVector[6], wtVector[7], wtVector[8], wtThreshold, seed)
}
g.UtilTypes = "IZZZZZIZZZZZZZ"

@ 낱말 하나를 그래프에 더하는 일은, 정점에 이름과 무게를 적고, 이미 자리잡은
낱말 가운데 한 글자만 다른 것들과 간선을 잇는 것이다. 무게는 정점의 |U.I|에,
간선의 길이는 1로, 차이 나는 글자 자리는 두 호의 |A.I|에 각각 적는다. 간선을
새로 이으면 |v.Arcs|가 그 호이고 |v.Arcs.Partner|가 짝이므로, 둘 다에 자리를
적어 두면 된다(\CEE/의 |edge_trick| 포인터 산술이 하던 일을 |Partner|가
또렷이 대신한다).

이웃을 찾는 궂은일은 |wordHash|의 |insert|에게 맡긴다. 새 낱말을 다섯 해시
표에 넣으면서, 한 글자만 다른 이웃을 만날 때마다 우리가 건넨 클로저를
불러 준다.

@<낱말 |p.Data|를 그래프에 더한다@>=
v := &g.Vertices[added]
v.Name = p.Data
v.U.I = p.Key - weightBias
ht.insert(v, func(k int, r *gbgraph.Vertex) {
	g.NewEdge(v, r, 1)
	v.Arcs.A.I = int64(k)
	v.Arcs.Partner.A.I = int64(k)
})

@* 다섯 해시 표. 조금 색다른 자료 구조라야 할 것은 다섯 개의 해시 표뿐이다.
다섯 글자 낱말에서 한 글자 자리를 지워 얻는 네 글자 무늬마다 하나씩이다. 예컨대
|"words"|는 |"·ords"|, |"w·rds"|, |"wo·ds"|, |"wor·s"|, |"word·"| 다섯
무늬의 표에 각각 자리를 남긴다. 한 글자만 다른 두 낱말은 어느 한 무늬가
똑같으므로, 그 무늬의 표에서 서로를 만난다.

@<상수, 표, 자료 구조@>=
type wordHash [5][]*gbgraph.Vertex

@ 다섯 글자 낱말 |q|의 다섯 글자를 5비트씩 쌓아 만든 원시 해시가 |rawHash|다.
|blanked|는 거기서 |k|번째 글자의 몫을 빼, 그 자리를 지운 네 글자 무늬의
해시를 준다. 그렇게 얻은 값을 |hashPrime|으로 나눈 나머지가 표에서 훑기를
시작할 자리다. 표를 훑을 때는 |down|으로 한 칸씩 물러서되, 처음을 지나면
끝으로 감아 돈다---\CEE/는 다섯 표를 메모리에 잇달아 두고 포인터로 이
휘돎을 부렸지만, 우리는 인덱스 산술로 또렷이 적는다.

@<보조 함수@>=
func rawHash(q string) int64 {
	var h int64
	for i := 0; i < 5; i++ {
		h = (h << 5) + int64(q[i])
	}
	return h
}

func blanked(rh int64, q string, k int) int64 {
	return rh - (int64(q[k]) << ((4 - k) * 5))
}

func down(idx int) int {
	if idx == 0 {
		return hashPrime - 1
	}
	return idx - 1
}

@ |matchExcept|는 두 낱말이 |k|번째 자리를 뺀 네 자리에서 모두 같은지 본다.
서로 다른 두 낱말이 이 시험을 통과하면, 그들은 정확히 |k|번째 자리 하나에서만
다른 것이다.

@<보조 함수@>=
func matchExcept(q, r string, k int) bool {
	for i := 0; i < 5; i++ {
		if i != k && q[i] != r[i] {
			return false
		}
	}
	return true
}

@ |makeWordHash|는 다섯 표를 각각 |hashPrime| 칸으로 마련한다. |insert|는
낱말 |v|를 다섯 표 모두에 넣되, 각 자리 |k|에서 이미 자리잡은 낱말 |r|가 |v|와
그 자리 하나만 다르면 |near(k, r)|를 부른다. 훑기는 선형 조사(linear probing)라,
빈 칸을 만나면 거기에 |v|를 놓는다.

@<보조 함수@>=
func makeWordHash() wordHash {
	var ht wordHash
	for i := range ht {
		ht[i] = make([]*gbgraph.Vertex, hashPrime)
	}
	return ht
}

func (ht wordHash) insert(v *gbgraph.Vertex, near func(k int, r *gbgraph.Vertex)) {
	q := v.Name
	rh := rawHash(q)
	for k := 0; k < 5; k++ {
		idx := int(blanked(rh, q, k) % hashPrime)
		for ht[k][idx] != nil {
			if near != nil {
				if r := ht[k][idx]; matchExcept(q, r.Name, k) {
					near(k, r)
				}
			}
			idx = down(idx)
		}
		ht[k][idx] = v
	}
}

@* 낱말 찾기. |Words|가 그래프 |g|를 만든 뒤에는, 또 다른 함수로 주어진 낱말과
꼭 맞거나 거의 맞는 정점을 찾을 수 있다.

|FindWord(g, q, f)|는 다섯 글자 낱말 |q|와 꼭 맞는 정점이 그래프에 있으면 그것을
돌려준다. 없으면 |nil|을 돌려주되, 그 전에 |q|와 한 글자만 다른 정점 |v|마다
|f(v)|를 부른다(|f|가 |nil|이면 부르지 않는다).

\CEE/ 원본은 |words|가 마지막으로 만든 그래프의 해시 표를 정적 전역 변수에
붙들어 두고 |find_word|가 그것을 훔쳐보았다. 그러나 우리 관례는 패키지 수준
가변 상태를 금하므로, |FindWord|는 그래프 스스로가 기억하는 낱말들로부터 다섯
해시 표를 그때그때 다시 짓는다. 낱말 찾기는 자주 하는 일이 아니니(|LADDERS|는
사람이 한 번 물어볼 때마다 한 번 찾는다) 이 다시 짓기의 값은 치를 만하다.

@<낱말을 찾는 |FindWord|@>=
// |FindWord|는 다섯 글자 낱말 |q|와 꼭 맞는 정점을 |g|에서 찾는다. 없으면
// |nil|을 돌려주되, 그 전에 |q|와 한 자리만 다른 정점마다 |f|를 부른다.
func FindWord(g *gbgraph.Graph, q string, f func(*gbgraph.Vertex)) *gbgraph.Vertex {
	if len(q) != 5 {
		return nil
	}
	ht := makeWordHash()
	for v := range g.AllVertices() {
		ht.insert(v, nil)
	}
	@<꼭 맞는 낱말이 있으면 돌려준다@>
	@<|q|와 이웃한 낱말마다 |f|를 부른다@>
	return nil
}

@ 꼭 맞는 낱말은 0번 표에서 찾는다. 그 표에서 |q|와 0번 자리까지 포함해 다섯
자리가 모두 같은 낱말을 만나면 바로 그것이다.

@<꼭 맞는 낱말이 있으면 돌려준다@>=
rh := rawHash(q)
for idx := int(blanked(rh, q, 0) % hashPrime); ht[0][idx] != nil; idx = down(idx) {
	if r := ht[0][idx]; q[0] == r.Name[0] && matchExcept(q, r.Name, 0) {
		return r
	}
}

@ 꼭 맞는 낱말이 없었다면, 다섯 표를 차례로 훑으며 |q|와 한 자리만 다른
낱말마다 |f|를 부른다.

@<|q|와 이웃한 낱말마다 |f|를 부른다@>=
if f != nil {
	for k := 0; k < 5; k++ {
		for idx := int(blanked(rh, q, k) % hashPrime); ht[k][idx] != nil; idx = down(idx) {
			if r := ht[k][idx]; matchExcept(q, r.Name, k) {
				f(r)
			}
		}
	}
}

@* 시험. 아래 시험들은 \.{words.dat}가 \.{../data}에 있다고 보고 그래프를 지어,
Knuth가 발표한 여러 값과 대조한다. 자격을 갖춘 낱말의 수---흔한 낱말 3300개,
흔하거나 고급인 낱말 4494개, 모든 낱말 5757개---는 훌륭한 닻이다.

@(gbwords_test.go@>=
package gbwords

import (
	"testing"

	"github.com/sjnam/go-sgb/gbgraph"
)

const dataDir = "../data"

@<개수를 대조하는 시험@>
@<구조를 확인하는 시험@>
@<결정성을 확인하는 시험@>
@<|FindWord| 시험@>
@<무게 검증 오류 시험@>

@ 무게 벡터 |{1}|은 $a=1$, 나머지 0을 뜻하니, 문턱 1로 거르면 흔한 낱말 3300개만
남는다. |{1,1}|은 $a=b=1$이라 흔하거나 고급인 4494개다. 기본 무게에 문턱 0이면
모든 낱말이 자격을 얻어 5757개다.

@<개수를 대조하는 시험@>=
func TestWordCounts(t *testing.T) {
	cases := []struct {
		name      string
		wt        []int64
		threshold int64
		want      int64
	}{
		{"흔함", []int64{1, 0, 0, 0, 0, 0, 0, 0, 0}, 1, 3300},
		{"흔함+고급", []int64{1, 1, 0, 0, 0, 0, 0, 0, 0}, 1, 4494},
		{"모두", nil, 0, 5757},
	}
	for _, c := range cases {
		g, err := Words(0, c.wt, c.threshold, 0, dataDir)
		if err != nil {
			t.Fatalf("%s: Words 실패: %v", c.name, err)
		}
		if g.N != c.want {
			t.Errorf("%s: 정점 수 = %d, 원함 %d", c.name, g.N, c.want)
		}
	}
}

@ 지어진 그래프의 속성을 하나하나 확인한다. 표식과 유틸리티 쓰임새가 맞는지,
무게가 정점 차례대로 안 커지는지, 모든 호의 길이가 1이고 차이 나는 자리가
$0$에서 $4$ 사이이며 두 끝점이 정말 그 자리 하나에서만 다른지 본다.

@<구조를 확인하는 시험@>=
func TestWordStructure(t *testing.T) {
	g, err := Words(2000, nil, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if g.ID != "words(2000,0,0,0)" {
		t.Errorf("ID = %q", g.ID)
	}
	if g.UtilTypes != "IZZZZZIZZZZZZZ" {
		t.Errorf("UtilTypes = %q", g.UtilTypes)
	}
	if g.N != 2000 {
		t.Fatalf("정점 수 = %d, 원함 2000", g.N)
	}
	for i := int64(1); i < g.N; i++ {
		if g.Vertices[i-1].U.I < g.Vertices[i].U.I {
			t.Fatalf("무게가 오름: 정점 %d(%d) < 정점 %d(%d)",
				i-1, g.Vertices[i-1].U.I, i, g.Vertices[i].U.I)
		}
	}
	@<모든 호를 확인한다@>
}

@ @<모든 호를 확인한다@>=
for v := range g.AllVertices() {
	for a := range v.AllArcs() {
		if a.Len != 1 {
			t.Fatalf("호 길이 = %d, 원함 1", a.Len)
		}
		k := a.A.I
		if k < 0 || k > 4 {
			t.Fatalf("차이 자리 = %d, 범위 밖", k)
		}
		diff := 0
		for p := 0; p < 5; p++ {
			if v.Name[p] != a.Tip.Name[p] {
				diff++
			}
		}
		if diff != 1 || v.Name[k] == a.Tip.Name[k] {
			t.Fatalf("%q와 %q는 자리 %d에서 한 글자만 다르지 않다",
				v.Name, a.Tip.Name, k)
		}
	}
}

@ 같은 인자로 두 번 부르면 정점 이름이 차례까지 똑같아야 한다. 씨앗을 바꾸면
같은 낱말 집합이되 무게가 같은 낱말들의 차례만 달라진다.

@<결정성을 확인하는 시험@>=
func TestWordDeterminism(t *testing.T) {
	g1, err := Words(500, nil, 0, 7, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	g2, err := Words(500, nil, 0, 7, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	for i := int64(0); i < g1.N; i++ {
		if g1.Vertices[i].Name != g2.Vertices[i].Name {
			t.Fatalf("정점 %d: %q != %q", i, g1.Vertices[i].Name, g2.Vertices[i].Name)
		}
	}
}

@ 들어가며에서 든 보기들이 정말 그 값을 내는지 확인한다. 짧은 무게 벡터를
그대로 넘겨 \CEE/의 |long w[9] = {1};|과 같은 뜻이 되는지도 함께 본다.

@<개수를 대조하는 시험@>=
func TestDocumentedExamples(t *testing.T) {
	cases := []struct {
		name string
		w    []int64
		th   int64
		want int64
	}{
		{"흔함", []int64{1}, 1, 3300},
		{"드묾 아님", []int64{1, 1}, 1, 4494},
		{"모두", make([]int64, 9), 0, 5757},
	}
	for _, c := range cases {
		g, err := Words(0, c.w, c.th, 0, dataDir)
		if err != nil {
			t.Fatalf("%s: %v", c.name, err)
		}
		if g.N != c.want {
			t.Errorf("%s: 정점 수 = %d, 원함 %d", c.name, g.N, c.want)
		}
	}
}

@ 음의 무게로는 가장 덜 흔한 낱말을 고른다. 그렇게 고른 낱말들은 기본 무게로
고른 흔한 낱말들과 겹치지 않아야 한다.

@<개수를 대조하는 시험@>=
func TestLeastCommon(t *testing.T) {
	neg := []int64{-1, -1, -1, -1, -1, -1, -1, -1, -1}
	rare, err := Words(10, neg, -0x7fffffff, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	if rare.N != 10 {
		t.Fatalf("정점 수 = %d, 원함 10", rare.N)
	}
	common, err := Words(2000, nil, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	for i := int64(0); i < rare.N; i++ {
		if FindWord(common, rare.Vertices[i].Name, nil) != nil {
			t.Errorf("%q가 흔한 2000개에도 있다", rare.Vertices[i].Name)
		}
	}
}

@ |FindWord|로 그래프의 첫 정점(무게가 가장 큰 낱말)을 그 이름으로 되찾아
본다. 그래프에 없을 낱말 |"22222"|는 |nil|이라야 한다. 이웃을 모으는 |f|를
건네면, 모인 정점마다 정말 한 글자만 다른지 확인한다.

@<|FindWord| 시험@>=
func TestFindWord(t *testing.T) {
	g, err := Words(2000, nil, 0, 0, dataDir)
	if err != nil {
		t.Fatal(err)
	}
	top := g.Vertices[0].Name
	if v := FindWord(g, top, nil); v != &g.Vertices[0] {
		t.Fatalf("FindWord(%q) = %v, 원함 첫 정점", top, v)
	}
	if v := FindWord(g, "22222", nil); v != nil {
		t.Errorf("FindWord(\"22222\") = %v, 원함 nil", v)
	}
	var neighbors []*gbgraph.Vertex
	FindWord(g, top, func(v *gbgraph.Vertex) { neighbors = append(neighbors, v) })
	for _, v := range neighbors {
		diff := 0
		for p := 0; p < 5; p++ {
			if top[p] != v.Name[p] {
				diff++
			}
		}
		if diff != 1 {
			t.Errorf("이웃 %q는 %q와 한 글자만 다르지 않다", v.Name, top)
		}
	}
}

@ 너무 큰 무게 벡터는 걸러져야 한다. $w_1=100000$이면 $C_1\cdot w_1$이 $2^{30}$을
넘어 |BadSpecs|, $w_1=200000$이면 $\.{0x60000000}$까지 넘어 |VeryBadSpecs|다.

@<무게 검증 오류 시험@>=
func TestWordBadSpecs(t *testing.T) {
	if _, err := Words(10, []int64{0, 0, 100000, 0, 0, 0, 0, 0, 0}, 0, 0, dataDir); err != gbgraph.BadSpecs {
		t.Errorf("err = %v, 원함 BadSpecs", err)
	}
	if _, err := Words(10, []int64{0, 0, 200000, 0, 0, 0, 0, 0, 0}, 0, 0, dataDir); err != gbgraph.VeryBadSpecs {
		t.Errorf("err = %v, 원함 VeryBadSpecs", err)
	}
}

@* 찾아보기.
