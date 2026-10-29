class_name SeededRng
extends RefCounted
## 같은 시드면 같은 수열이 나오는 작은 난수 생성기 (mulberry32).
## 웹 앱(matchbox-ai)의 rng.ts와 같은 수열을 낸다. 난수는 여기서만 만든다.

var _a: int


func _init(seed: int) -> void:
	_a = seed & 0xFFFFFFFF


## 게임에서 쓰는 난수: 시드를 그때그때 정한다
static func for_game() -> SeededRng:
	return SeededRng.new(randi())


## 32비트 곱셈의 아래 32비트 (JS Math.imul)
static func _imul(x: int, y: int) -> int:
	var lo := (x & 0xFFFF) * y
	var hi := (((x >> 16) & 0xFFFF) * y) & 0xFFFF
	return (lo + (hi << 16)) & 0xFFFFFFFF


func next() -> float:
	_a = (_a + 0x6D2B79F5) & 0xFFFFFFFF
	var t := _a
	t = _imul(t ^ (t >> 15), t | 1)
	t = t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0
