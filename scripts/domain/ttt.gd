class_name Ttt
extends RefCounted
## 틱택토 판. 칸 번호는 왼쪽 위부터 0~8. AI가 먼저 두고 ○(1), 학생은 ×(2).
## 승부는 "ai" / "kid" / "draw", 안 끝났으면 "".

const AI := 1
const KID := 2

const LINES := [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]

## 위에서 본 칸 이름 (학생에게 보여 줄 말)
const CELL_NAMES := ["왼쪽 위", "위 가운데", "오른쪽 위", "왼쪽 가운데", "가운데", "오른쪽 가운데", "왼쪽 아래", "아래 가운데", "오른쪽 아래"]

## 대칭: SYMS[s][i] = 바꾼 판의 i칸에 들어갈 원래 판의 칸 번호. 회전 4가지 × 뒤집기 2가지 = 8가지.
static var SYMS: Array = _make_syms()


static func _make_syms() -> Array:
	var rot := [6, 3, 0, 7, 4, 1, 8, 5, 2]
	var flip := [2, 1, 0, 5, 4, 3, 8, 7, 6]
	var rots := [[0, 1, 2, 3, 4, 5, 6, 7, 8]]
	for r in range(1, 4):
		rots.append(_apply(rots[r - 1], rot))
	var out := rots.duplicate()
	for r in rots:
		out.append(_apply(r, flip))
	return out


static func _apply(arr: Array, perm: Array) -> Array:
	var out := []
	for i in perm:
		out.append(arr[i])
	return out


static func empty_board() -> Array:
	return [0, 0, 0, 0, 0, 0, 0, 0, 0]


static func empty_cells(b: Array) -> Array:
	var out := []
	for i in 9:
		if b[i] == 0:
			out.append(i)
	return out


static func count(b: Array, mark: int) -> int:
	return b.count(mark)


static func place(b: Array, cell: int, mark: int) -> Array:
	assert(b[cell] == 0, "이미 찬 칸이에요: %d" % cell)
	var next := b.duplicate()
	next[cell] = mark
	return next


## 세 칸이 이어진 줄 (없으면 빈 배열)
static func win_line(b: Array) -> Array:
	for line in LINES:
		var m: int = b[line[0]]
		if m != 0 and m == b[line[1]] and m == b[line[2]]:
			return line
	return []


static func outcome(b: Array) -> String:
	var w := win_line(b)
	if not w.is_empty():
		return "ai" if b[w[0]] == AI else "kid"
	return "draw" if empty_cells(b).is_empty() else ""


static func key_of(b: Array) -> String:
	var s := ""
	for m in b:
		s += str(m)
	return s


## 대표 모양: 8가지로 바꾼 판 중 글자로 가장 앞선 것. sym[i] = 대표 모양 i칸의 원래 칸 번호
static func canonical(b: Array) -> Dictionary:
	var best := ""
	var best_sym: Array = SYMS[0]
	for sym in SYMS:
		var key := ""
		for i in sym:
			key += str(b[i])
		if best == "" or key < best:
			best = key
			best_sym = sym
	return {"key": best, "sym": best_sym}
