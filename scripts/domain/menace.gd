class_name Menace
extends RefCounted
## 성냥갑 AI (MENACE, 도널드 미치 1961). 웹 앱 PRD 8.2~8.4와 같은 규칙.
## - AI 차례인 판 모양마다 성냥갑이 하나. 돌리거나 뒤집으면 같은 판은 한 상자(대표 모양)로 합친다.
## - 상자 안 구슬은 빈칸마다 따로 둔다 (학생이 판과 서랍을 1:1로 맞춰 보게).
## - 처음 구슬: AI의 1·2·3·4번째 수 상자에 칸마다 4·3·2·1개.
## - 판이 끝나면 이번 판에 고른 칸마다 이김 +3, 비김 +1, 짐 −1 (0 아래로는 안 내려감).
## - 한 칸이 BEAD_MAX개를 넘으면 그 상자의 모든 칸 구슬을 반으로 줄인다(0이 아니면 최소 1개).
## - 상자가 비면 AI가 기권한다. 단 첫 상자(빈 판)는 다시 채운다.
##
## 두뇌(brain)는 {"boxes": {대표 모양: [칸별 구슬 9개]}, "games": 판 수} 사전이다.

const START_BEADS := [4, 3, 2, 1]
const REWARD := {"ai": 3, "draw": 1, "kid": -1}
const FIRST_KEY := "000000000"
const BEAD_MAX := 30

## AI 차례인 판 모양(대표 모양) 전체, 글자 순. 상자 번호(1번부터)를 정하는 데 쓴다
static var ALL_BOX_KEYS: Array = _all_box_keys()
static var _box_no: Dictionary = {}


static func _all_box_keys() -> Array:
	var keys := {}
	var seen := {}
	var stack := [Ttt.empty_board()]
	while not stack.is_empty():
		var b: Array = stack.pop_back()
		var k := Ttt.key_of(b)
		if seen.has(k):
			continue
		seen[k] = true
		if Ttt.outcome(b) != "":
			continue
		var ai_turn := Ttt.count(b, Ttt.AI) == Ttt.count(b, Ttt.KID)
		var empties := Ttt.empty_cells(b)
		if ai_turn and empties.size() >= 2:
			keys[Ttt.canonical(b).key] = true
		for c in empties:
			stack.append(Ttt.place(b, c, Ttt.AI if ai_turn else Ttt.KID))
	var out := keys.keys()
	out.sort()
	return out


static func box_number(key: String) -> int:
	if _box_no.is_empty():
		for i in ALL_BOX_KEYS.size():
			_box_no[ALL_BOX_KEYS[i]] = i + 1
	return _box_no.get(key, 0)


static func new_brain() -> Dictionary:
	return {"boxes": {}, "games": 0}


static func clone_brain(b: Dictionary) -> Dictionary:
	return b.duplicate(true)


static func start_beads(canon: String) -> Array:
	var turn := canon.count("1")
	var n: int = START_BEADS[mini(turn, 3)]
	var out := []
	for ch in canon:
		out.append(n if ch == "0" else 0)
	return out


## 그 판 모양의 상자 (없으면 처음 구슬로 만든다). beads는 두뇌 속 배열 그대로다
static func get_box(brain: Dictionary, b: Array) -> Dictionary:
	var c := Ttt.canonical(b)
	if not brain.boxes.has(c.key):
		brain.boxes[c.key] = start_beads(c.key)
	return {"key": c.key, "sym": c.sym, "beads": brain.boxes[c.key]}


## 화면에 보일 구슬: 지금 판 방향으로 되돌린 칸별 구슬 수 (상자를 만들지 않는다)
static func beads_on_board(brain: Dictionary, b: Array) -> Array:
	var c := Ttt.canonical(b)
	var beads: Array = brain.boxes[c.key] if brain.boxes.has(c.key) else start_beads(c.key)
	var out := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	for i in 9:
		out[c.sym[i]] = beads[i]
	return out


static func _sum(a: Array) -> int:
	var s := 0
	for n in a:
		s += n
	return s


## AI가 둘 칸을 고른다. kind는 "move" / "forced" / "resign".
## move = {key, canon, cell, board}
static func choose_move(brain: Dictionary, b: Array, rng: SeededRng) -> Dictionary:
	var empties := Ttt.empty_cells(b)
	if empties.size() == 1:
		return {"kind": "forced", "cell": empties[0]}
	var box := get_box(brain, b)
	var total := _sum(box.beads)
	if total == 0 and box.key == FIRST_KEY:
		brain.boxes[FIRST_KEY] = start_beads(FIRST_KEY)
		box.beads = brain.boxes[FIRST_KEY]
		total = _sum(box.beads)
	var shown := beads_on_board(brain, b)
	if total == 0:
		return {"kind": "resign", "beads": shown}
	var r := rng.next() * total
	var canon := -1
	for i in 9:
		r -= box.beads[i]
		if r < 0:
			canon = i
			break
	if canon < 0:
		for i in range(8, -1, -1):
			if box.beads[i] > 0:
				canon = i
				break
	var move := {"key": box.key, "canon": canon, "cell": box.sym[canon], "board": b.duplicate()}
	return {"kind": "move", "move": move, "beads": shown}


## 판이 끝난 뒤 배우기. 바뀐 내용(move + before, after)을 돌려준다
static func learn(brain: Dictionary, moves: Array, result: String) -> Array:
	var delta: int = REWARD[result]
	brain.games += 1
	var changes := []
	for m in moves:
		if not brain.boxes.has(m.key):
			brain.boxes[m.key] = start_beads(m.key)
		var beads: Array = brain.boxes[m.key]
		var before: int = beads[m.canon]
		var raw := maxi(0, before + delta)
		beads[m.canon] = raw
		if raw > BEAD_MAX:
			for i in 9:
				beads[i] = maxi(1, roundi(beads[i] / 2.0)) if beads[i] > 0 else 0
		var ch: Dictionary = m.duplicate()
		ch.before = before
		ch.after = mini(BEAD_MAX, raw)
		changes.append(ch)
	return changes


static func total_beads(brain: Dictionary) -> int:
	var s := 0
	for k in brain.boxes:
		s += _sum(brain.boxes[k])
	return s


## 저장한 JSON(숫자가 float로 돌아옴)을 두뇌로 되돌린다. 모양이 틀리면 빈 사전
static func brain_from_json(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY or not data.has("boxes"):
		return {}
	var brain := new_brain()
	brain.games = int(data.get("games", 0))
	for k in data.boxes:
		var arr: Array = data.boxes[k]
		if arr.size() != 9:
			return {}
		var beads := []
		for n in arr:
			beads.append(int(n))
		brain.boxes[str(k)] = beads
	return brain
