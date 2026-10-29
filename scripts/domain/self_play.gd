class_name SelfPlay
extends RefCounted
## 혼자 두기: 앱이 AI를 미리 연습시킨다. 상대는 무작위 학생 70% + 이길 수 있으면 이기고 막을 수 있으면 막는 학생 30%.
## 상대는 "random" / "careful" / "mixed".

const LEVELS := {"fresh": 0, "some": 300, "lots": 3000}
const LEVEL_NAMES := {"fresh": "처음부터 (아무것도 모르는 AI)", "some": "조금 배운 AI (300판 연습)", "lots": "많이 배운 AI (3000판 연습)"}


static func _finishing(b: Array, mark: int) -> int:
	for line in Ttt.LINES:
		var marks := [b[line[0]], b[line[1]], b[line[2]]]
		if marks.count(mark) == 2 and marks.has(0):
			return line[marks.find(0)]
	return -1


static func random_kid(b: Array, rng: SeededRng) -> int:
	var e := Ttt.empty_cells(b)
	return e[floori(rng.next() * e.size())]


static func careful_kid(b: Array, rng: SeededRng) -> int:
	var win := _finishing(b, Ttt.KID)
	if win >= 0:
		return win
	var block := _finishing(b, Ttt.AI)
	if block >= 0:
		return block
	return random_kid(b, rng)


static func kid_move(opp: String, b: Array, rng: SeededRng) -> int:
	match opp:
		"careful":
			return careful_kid(b, rng)
		"mixed":
			return careful_kid(b, rng) if rng.next() < 0.3 else random_kid(b, rng)
	return random_kid(b, rng)


## AI와 상대가 한 판을 둔다. learn_it이면 배운다
static func play_one(brain: Dictionary, opp: String, rng: SeededRng, learn_it := true) -> String:
	var b := Ttt.empty_board()
	var moves := []
	while true:
		var c := Menace.choose_move(brain, b, rng)
		if c.kind == "resign":
			if learn_it:
				Menace.learn(brain, moves, "kid")
			return "kid"
		if c.kind == "move":
			moves.append(c.move)
		b = Ttt.place(b, c.move.cell if c.kind == "move" else c.cell, Ttt.AI)
		var o := Ttt.outcome(b)
		if o == "":
			b = Ttt.place(b, kid_move(opp, b, rng), Ttt.KID)
			o = Ttt.outcome(b)
		if o != "":
			if learn_it:
				Menace.learn(brain, moves, o)
			return o
	return "draw"


## 연습시킨 새 AI
static func trained_brain(level: String, seed := 1961) -> Dictionary:
	var brain := Menace.new_brain()
	var rng := SeededRng.new(seed)
	for i in LEVELS[level]:
		play_one(brain, "mixed", rng)
	brain.games = 0
	return brain
