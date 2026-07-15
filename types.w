% go-sgb의 여러 .w가 공유하는 gweave 서식 힌트.
% 각 모듈 .w의 첫 줄에서 @i ../types.w 로 끌어온다.
@d DataInputDirectory
@d os.Stdout
@d os.Stderr
@d io.Discard

@s unsigned int
@s long int

@s Reader int
@s Writer int
@s iter.Seq int
@s testing.T int
@s testing.B int
@s strings.Builder int

@s RNG int
@s File int
@s IOErrors int
@s Util int
@s Vertex int
@s Arc int
@s Graph int
@s PanicCode int
@s Node int
@s PriorityQueue int
