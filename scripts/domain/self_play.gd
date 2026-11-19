class_name SelfPlay
extends RefCounted
## 혼자 두기: 앱이 AI를 미리 연습시킨다. 상대는 무작위 학생 70% + 이길 수 있으면 이기고 막을 수 있으면 막는 학생 30%.
## 상대는 "random" / "careful" / "mixed".

const LEVELS := {"fresh": 0, "some": 300, "lots": 3000}
## 빨리 감기(새 흐름): 새내기 AI가 혼자 두는 판 수와 연습 상대. tests/sim_difficulty.gd 로 정했다.
## "tough2"(가장 잘 두는 상대 40% + 꼼꼼한 상대 30% + 아무 데나 두는 상대 30%) 1500판이면 졸업 시험에서 학생이 거의 못 이긴다:
## 아무 데나 두는 학생부터 꼼꼼한 학생까지 2.5~3%, 함정까지 파는 가장 잘 두는 학생 0.3%. (아무 데나 두는 상대를 빼면 대충 두는 학생이 10%쯤 이기고, 꼼꼼한 상대와 300판이면 가장 잘 두는 학생이 36% 이긴다)
const TRAIN_GAMES := 1500
const TRAIN_OPPONENT := "tough2"
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


## 그 칸들 가운데 빈칸 하나 (없으면 -1)
static func _pick_of(b: Array, cells: Array, rng: SeededRng) -> int:
	var e := []
	for c in cells:
		if b[c] == 0:
			e.append(c)
	return e[floori(rng.next() * e.size())] if not e.is_empty() else -1


## 공격만 하는 친구: 이길 수 있으면 이기고, 아니면 제 돌 옆에 둬서 두 개를 나란히 만든다. 막지는 않는다
static func attack_kid(b: Array, rng: SeededRng) -> int:
	var win := _finishing(b, Ttt.KID)
	if win >= 0:
		return win
	var good := []
	for line in Ttt.LINES:
		var marks := [b[line[0]], b[line[1]], b[line[2]]]
		if marks.count(Ttt.KID) == 1 and marks.count(0) == 2:
			for c in line:
				if b[c] == 0 and not good.has(c):
					good.append(c)
	var c2 := _pick_of(b, good, rng)
	return c2 if c2 >= 0 else random_kid(b, rng)


## 막기만 하는 친구: AI가 두 개를 나란히 두면 막고, 아니면 아무 데나 둔다. 이길 수 있어도 모른다
static func defend_kid(b: Array, rng: SeededRng) -> int:
	var block := _finishing(b, Ttt.AI)
	return block if block >= 0 else random_kid(b, rng)


static func kid_move(opp: String, b: Array, rng: SeededRng) -> int:
	match opp:
		"corner":
			# 모서리를 좋아하는 친구: 빈 모서리가 있으면 거기, 없으면 아무 데나
			var c := _pick_of(b, [0, 2, 6, 8], rng)
			return c if c >= 0 else random_kid(b, rng)
		"center":
			# 가운데를 좋아하는 친구: 가운데, 그다음 변(가운데 줄), 없으면 아무 데나
			if b[4] == 0:
				return 4
			var c := _pick_of(b, [1, 3, 5, 7], rng)
			return c if c >= 0 else random_kid(b, rng)
		"attack":
			return attack_kid(b, rng)
		"defend":
			return defend_kid(b, rng)
		"careful":
			return careful_kid(b, rng)
		"perfect":
			return perfect_kid(b, rng)
		"tough":
			# 가장 잘 두는 상대 반, 꼼꼼한 상대 반 (여러 판 모양을 두루 겪게)
			return perfect_kid(b, rng) if rng.next() < 0.5 else careful_kid(b, rng)
		"tough2":
			# 가장 잘 두는 상대 40% + 꼼꼼한 상대 30% + 아무 데나 두는 상대 30% (대충 두는 학생이 만드는 판 모양도 겪게)
			var r := rng.next()
			if r < 0.4:
				return perfect_kid(b, rng)
			return careful_kid(b, rng) if r < 0.7 else random_kid(b, rng)
		"mixed":
			return careful_kid(b, rng) if rng.next() < 0.3 else random_kid(b, rng)
	return random_kid(b, rng)


## AI와 상대가 한 판을 둔다. learn_it이면 배운다
static func play_one(brain: Dictionary, opp: String, rng: SeededRng, learn_it := true, focus := 1.0) -> String:
	var b := Ttt.empty_board()
	var moves := []
	while true:
		var c := Menace.choose_move(brain, b, rng, focus)
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


## 실력을 정할 수 있는 학생: p의 확률로 꼼꼼하게(이기거나 막기), 아니면 아무 데나 둔다
static func skilled_kid(b: Array, rng: SeededRng, p: float) -> int:
	return careful_kid(b, rng) if rng.next() < p else random_kid(b, rng)


## AI와 실력 p인 학생이 배우지 않고 n판을 둔 결과 {"kid", "draw", "ai"} (난이도 시뮬레이션)
static func evaluate(brain: Dictionary, p: float, n: int, rng: SeededRng, focus := Menace.FOCUS_KID) -> Dictionary:
	var out := {"kid": 0, "draw": 0, "ai": 0}
	for i in n:
		var work := Menace.clone_brain(brain)
		var b := Ttt.empty_board()
		var o := ""
		while o == "":
			var c := Menace.choose_move(work, b, rng, focus)
			if c.kind == "resign":
				o = "kid"
				break
			b = Ttt.place(b, c.move.cell if c.kind == "move" else c.cell, Ttt.AI)
			o = Ttt.outcome(b)
			if o == "":
				b = Ttt.place(b, skilled_kid(b, rng, p), Ttt.KID)
				o = Ttt.outcome(b)
		out[o] += 1
	return out


# ---------- 가장 잘 두는 상대 (빨리 감기의 연습 상대, 난이도 시뮬레이션) ----------

## 판 모양 → 그 판에서 둘 사람이 끝까지 잘 뒀을 때의 결과 (학생 쪽에서 본 값: 1 학생 승, 0 비김, -1 AI 승)
static var _value_cache := {}
## 판 모양 → 학생이 둘 가장 좋은 칸들
static var _best_cache := {}


static func _value(b: Array) -> int:
	var key := Ttt.key_of(b)
	if _value_cache.has(key):
		return _value_cache[key]
	var o := Ttt.outcome(b)
	var v := 0
	if o != "":
		v = 1 if o == "kid" else (-1 if o == "ai" else 0)
	else:
		var ai_turn := Ttt.count(b, Ttt.AI) == Ttt.count(b, Ttt.KID)
		v = 2 if ai_turn else -2
		for c in Ttt.empty_cells(b):
			var w := _value(Ttt.place(b, c, Ttt.AI if ai_turn else Ttt.KID))
			v = mini(v, w) if ai_turn else maxi(v, w)
	_value_cache[key] = v
	return v


## 가장 잘 두는 학생: 지지 않는 수 가운데, AI가 실수할 길이 가장 많은 수를 고른다 (함정을 파는 학생)
static func perfect_kid(b: Array, rng: SeededRng) -> int:
	var key := Ttt.key_of(b)
	if not _best_cache.has(key):
		var best_v := -2
		var best_traps := -1
		var best := []
		for c in Ttt.empty_cells(b):
			var nb := Ttt.place(b, c, Ttt.KID)
			var v := _value(nb)
			# 이 수 다음에 AI가 둘 수 있는 칸 가운데 학생이 이기게 되는 칸의 수
			var traps := 0
			if Ttt.outcome(nb) == "":
				for a in Ttt.empty_cells(nb):
					if _value(Ttt.place(nb, a, Ttt.AI)) == 1:
						traps += 1
			if v > best_v or (v == best_v and traps > best_traps):
				best_v = v
				best_traps = traps
				best = [c]
			elif v == best_v and traps == best_traps:
				best.append(c)
		_best_cache[key] = best
	var moves: Array = _best_cache[key]
	return moves[floori(rng.next() * moves.size())]


# ---------- AI 키우기 대회 (연습 계획 세우기) ----------
## 학생이 연습 1000판을 5판 단위로 여섯 친구에게 나눠 준다. 그 계획대로 연습한 AI 다섯 대가
## 시험관 세 종류와 100판씩 둬서 이기면 3점, 비기면 1점. 점수는 다섯 대의 평균
## (최고 700점: 절대 지지 않는 시험관에게는 비기는 것이 최선).
## 같은 계획이면 언제나 같은 점수가 나온다 (contest_seed로 난수를 정한다). 점수를 올리려면 계획을 바꿔야 한다.
const CONTEST_GAMES := 1000
const CONTEST_STEP := 5
## 연습 친구 (계획의 칸 순서). 시험관(CONTEST_KINDS)과는 다르다
const CONTEST_FRIENDS := ["random", "corner", "center", "attack", "defend", "perfect"]
const FRIEND_NAMES := {"random": "아무 데나 두는 친구", "corner": "모서리를 좋아하는 친구", "center": "가운데를 좋아하는 친구", "attack": "공격만 하는 친구", "defend": "막기만 하는 친구", "perfect": "아주 잘 두는 친구"}
const FRIEND_TRAITS := {"random": "어디에 둘지 몰라요", "corner": "모서리부터 둬요", "center": "가운데부터 둬요", "attack": "이기려고만 해요", "defend": "막으려고만 해요", "perfect": "절대 지지 않아요"}
## 친구마다 구슬 색 번호 (Kit.bead_color)
const FRIEND_COLOR := {"random": 0, "corner": 5, "center": 4, "attack": 3, "defend": 1, "perfect": 2}
const CONTEST_EXAM_EACH := 100
## 운을 줄이려고 같은 계획으로 AI를 여러 대 키워 평균을 낸다. 점수 흔들림은 시험이 아니라 연습에서 온다:
## 같은 AI를 다시 시험하면 ±9점, 같은 계획으로 새로 키우면 ±40점. 다섯 대 평균이면 ±18점쯤으로 준다
const CONTEST_TEAM := 5
## 대회 시험에서는 구슬이 가장 많은 칸을 둔다 (쏠림을 아주 크게: 가장 많은 칸들 가운데 아무거나)
const CONTEST_FOCUS := 1000.0
const CONTEST_KINDS := ["random", "careful", "perfect"]
const CONTEST_NAMES := {"random": "아무 데나 두는 친구", "careful": "막을 줄 아는 친구", "perfect": "아주 잘 두는 친구"}


## 시험 한 판 (배우지 않고, 구슬이 가장 많은 칸을 고른다). 점수를 돌려준다: 이김 3, 비김 1, 짐 0
static func contest_point(brain: Dictionary, kind: String, rng: SeededRng) -> int:
	var o := play_one(brain, kind, rng, false, CONTEST_FOCUS)
	return 3 if o == "ai" else (1 if o == "draw" else 0)


## 계획(친구마다 준 판 수) → 연습 상대 목록 (CONTEST_STEP판마다 한 칸). 여기서 하나씩 뽑아 둔다
static func contest_plan(counts: Array) -> Array:
	var plan := []
	for i in mini(counts.size(), CONTEST_FRIENDS.size()):
		for n in int(counts[i]) / CONTEST_STEP:
			plan.append(CONTEST_FRIENDS[i])
	return plan


## 계획마다 정해진 난수 씨앗. 같은 계획이면 같은 연습, 같은 시험, 같은 점수가 된다
static func contest_seed(counts: Array) -> int:
	var h := 1961
	for c in counts:
		h = (h * 1009 + int(c) + 7) % 2147483647
	return h


## 계획 하나의 점수를 화면 없이 계산한다 (화면과 같은 순서: AI마다 연습 → 시험관 셋과 시험). 시뮬레이션과 테스트용
static func contest_score(counts: Array) -> int:
	var plan := contest_plan(counts)
	var points := 0
	for ai in CONTEST_TEAM:
		var rng := SeededRng.new(contest_seed(counts) + ai)
		var brain := Menace.new_brain()
		for i in CONTEST_GAMES:
			play_one(brain, plan[floori(rng.next() * plan.size())], rng)
		for kind in CONTEST_KINDS:
			for i in CONTEST_EXAM_EACH:
				points += contest_point(brain, kind, rng)
	return roundi(points / float(CONTEST_TEAM))
