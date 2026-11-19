class_name GameScreen
extends ScreenBase
## 새 흐름의 놀이 한 판. 판이 하나뿐이다: AI의 구슬을 서랍이 아니라 틱택토 판의 빈칸에 바로 보여 준다.
##   AI 차례: 빈칸마다 구슬과 %가 나타남 → 기계 집게가 구슬 하나를 집음 → 그 칸에 ○.
##     1·2단계(개념을 익히는 판)는 읽을 시간을 넉넉히 준다(구슬 1.6초 + 집게 0.7초). 졸업 시험은 빠르게(0.4초 + 0.35초)
##   판이 끝나면 같은 판 위에서 AI가 둔 칸마다 구슬이 늘거나 준다 (상과 벌).
## 놀이 중에는 글을 거의 띄우지 않는다. 설명은 세 판 묶음이 끝난 뒤 ExplainScreen이 한다.
##
## 묶음(set)마다 하는 일이 다르다:
##   1 새내기 AI: 보기만 한다. 상과 벌은 저절로 바뀌는 것을 본다
##   2 내가 가르치는 AI: 한 판에 한 번 맞혀 보기 + 내 손으로 상과 벌 주기
##   3 졸업 시험: 혼자 연습한 AI와 둔다. 상과 벌은 저절로
## 왼쪽에는 "지금 판과 같은 모양의 성냥갑" 이름표, 오른쪽에는 성냥갑 기계가 있다.

signal round_end(result: Dictionary)

const OPEN_S := 0.4
const OPEN_SLOW_S := 1.6
const PICK_SLOW_S := 0.7
const EXPLORE_LINE := "이번에는 구슬이 적은 칸이 뽑혔어요. 적어도 가끔은 뽑혀요."
const PICK_S := 0.35
const END_S := 1.1
const PREDICT_WAIT := 8.0
const SET_NAMES := ["1단계", "2단계", "졸업 시험"]

const TEACH_HAND := {
	"kid": "AI가 졌어요. AI가 둔 칸을 눌러 구슬을 1개씩 빼요.",
	"ai": "AI가 이겼어요. AI가 둔 칸을 눌러 구슬을 3개씩 넣어요.",
	"draw": "비겼어요. AI가 둔 칸을 눌러 구슬을 1개씩 넣어요.",
}
const TEACH_AUTO := {
	"kid": "AI가 졌어요. AI가 둔 칸마다 구슬이 1개씩 줄어요.",
	"ai": "AI가 이겼어요. AI가 둔 칸마다 구슬이 3개씩 늘어요.",
	"draw": "비겼어요. AI가 둔 칸마다 구슬이 1개씩 늘어요.",
}
const TEACH_DONE := {
	"kid": "이제 AI는 이 칸들을 덜 골라요.",
	"ai": "이제 AI는 이 칸들을 더 자주 골라요.",
	"draw": "이제 AI는 이 칸들을 조금 더 골라요.",
}

var brain: Dictionary
var set_i: int
var game_i: int
var games: int
var score: Dictionary
var today_games: int
var percent: bool
var trained: int

## "ai" / "predict" / "kid" / "end" / "teach"
var phase := "ai"
var _board := Ttt.empty_board()
var _moves := []
var _rng := SeededRng.for_game()
var _predicted := false
var _asked_now := false
var _keep_line := false
var _explored := 0
## 내 차례가 시작된 때와 한 수마다 걸린 시간(ms). 체험 통계에 쓴다 (이름 없이)
var _turn_t := 0
var _kid_ms := []
var _predict_tw: Tween
var _predict := {"offered": false, "answered": false, "guess_max": false, "hit": false}
var _teach_info := {"manual": 0, "total": 0}
var _end := {}

var _brand: Drawn
var _round: Label
var _pills: Array[Label] = []
var _view: BoardView
var _message: Label
var _tag: Drawn
var _tag_board := Ttt.empty_board()
var _tag_no := 0
var _machine: MachineView


func _init(b: Dictionary, info: Dictionary, s: Dictionary, today: int) -> void:
	brain = b
	set_i = info.set
	game_i = info.game
	games = info.games
	trained = info.get("trained", 0)
	percent = info.get("percent", false)
	score = s
	today_games = today


func build() -> void:
	_brand = Drawn.new(PlayScreen.paint_brand)
	add_child(_brand)
	_round = Kit.label("%s   %d / %d" % [SET_NAMES[set_i - 1], game_i, games], Kit.F_LABEL, Kit.R * 1.3)
	add_child(_round)
	for p in [["나 %d" % score.kid, "kid"], ["비김 %d" % score.draw, "draw"], ["AI %d" % score.ai, "ai"]]:
		var l := Kit.pill(p[0], p[1])
		_pills.append(l)
		add_child(l)
	_tag = Drawn.new(_paint_tag)
	add_child(_tag)
	_machine = MachineView.new()
	add_child(_machine)
	_view = BoardView.new()
	_view.percent = percent
	_view.cell_tapped.connect(_kid_tap)
	_view.guess_tapped.connect(_on_guess_tap)
	_view.teach_done.connect(_on_taught)
	add_child(_view)
	_message = Kit.label("", Kit.F_BODY, Kit.R * 1.25, Kit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	add_child(_message)


func relayout() -> void:
	var R := Kit.R
	var w := size.x - pad.x * 2
	var head_h := R * 3.4
	_brand.position = pad + Vector2(R * 0.4, R * 0.2)
	_brand.size = Vector2(R * 13, head_h - R * 0.4)
	var x := size.x - pad.x - R * 3.2
	for i in range(_pills.size() - 1, -1, -1):
		var l := _pills[i]
		l.size = l.get_combined_minimum_size()
		x -= l.size.x
		l.position = Vector2(x, pad.y + (head_h - l.size.y) / 2)
		x -= R * 0.5
	_round.size = _round.get_combined_minimum_size()
	_round.position = Vector2(x - R * 0.6 - _round.size.x, pad.y + (head_h - _round.size.y) / 2)
	var top := pad.y + head_h + R * 0.8
	var bottom := size.y - pad.y
	var msg_h := R * 4.0
	var machine_size := Vector2(R * 10.0, R * 4.8)
	_machine.size = machine_size
	if portrait():
		# 세로: 머리 줄이 좁으므로 단계 이름은 이름표 아래 줄에 둔다
		_round.position = Vector2(pad.x + R * 0.4, pad.y + head_h + R * 0.2)
		top += R * 2.2
		var bs := minf(w * 0.92, bottom - top - msg_h - R * 12)
		_view.position = Vector2((size.x - bs) / 2, top)
		_view.size = Vector2(bs, bs)
		Kit.place(_message, Vector2(pad.x, top + bs + R * 1.2), w)
		var y := top + bs + R * 1.2 + msg_h + R * 0.8
		var tw := minf(w * 0.5, R * 17)
		_tag.position = Vector2(pad.x, y)
		_tag.size = Vector2(tw, R * 10)
		_machine.scale = Vector2.ONE
		_machine.position = Vector2(pad.x + tw + (w - tw - machine_size.x) / 2, y + R * 2.6)
	else:
		var bs := minf(R * 27, bottom - top - msg_h - R * 0.8)
		var bx := (size.x - bs) / 2
		_view.position = Vector2(bx, top)
		_view.size = Vector2(bs, bs)
		var mw := minf(size.x - pad.x * 2, bs + R * 22)
		Kit.place(_message, Vector2((size.x - mw) / 2, top + bs + R * 1.0), mw)
		# 왼쪽: 성냥갑 이름표, 오른쪽: 기계 (조금 크게)
		var side := bx - pad.x - R * 2.4
		var tw := minf(side, R * 11)
		_tag.size = Vector2(tw, R * 11.5)
		_tag.position = Vector2(pad.x + (side - tw) / 2 + R * 0.4, top + (bs - _tag.size.y) / 2)
		var k := clampf(side / (machine_size.x + R * 2), 1.0, 1.5)
		_machine.scale = Vector2(k, k)
		_machine.position = Vector2(bx + bs + R * 2.0 + (side - machine_size.x * k) / 2, top + (bs - machine_size.y * k) / 2)
	_fit_message()


func enter() -> void:
	var line := ""
	match set_i:
		1:
			line = "AI는 구슬이 많은 칸을 더 잘 골라요." if game_i == 1 else ""
			_machine.mood = "lost"
		2:
			line = "AI가 고를 칸을 맞혀 보고, 내 손으로 상과 벌을 줘요." if game_i == 1 else ""
		_:
			line = "졸업 시험이에요. 비기기만 해도 잘한 거예요." if game_i == 1 else ""
	_say(line)
	var wait := 0.9
	if game_i == 1 and set_i > 1:
		wait = 2.0
	later(wait, _ai_turn.bind(Ttt.empty_board()))


## 설명줄은 언제나 두 줄까지. 넘치면 글자를 조금씩 줄여 두 줄에 맞춘다
func _fit_message() -> void:
	var w := _message.size.x
	if w <= 0.0:
		return
	var ls := _message.label_settings
	var fs := int(Kit.R * 1.25)
	var smallest := int(Kit.R * 0.9)
	while true:
		ls.font_size = fs
		ls.line_spacing = fs * 0.3
		if Kit.wrapped_lines(_message, w) <= 2 or fs <= smallest:
			break
		fs -= 1
	_message.size.y = Kit.wrapped_height(_message, w)


func _say(s: String) -> void:
	Kit.set_text(_message, s)
	_fit_message()
	_message.modulate.a = 0.35
	create_tween().tween_property(_message, "modulate:a", 1.0, 0.25)


func _ai_turn(b: Array) -> void:
	phase = "ai"
	_view.locked = true
	_view.active = false
	# 학생과 둘 때는 구슬이 많은 칸으로 쏠리게 고른다 (맞히기 쉽게). 화면의 %는 구슬 수 그대로의 비율이다 (원래 규칙)
	var c := Menace.choose_move(brain, b, _rng, Menace.FOCUS_KID)
	if c.kind == "forced":
		_say("마지막 한 칸이라 바로 둬요.")
		later(0.7, _place_ai.bind(b, c.cell, {}))
		return
	# 왼쪽 이름표가 지금 판과 같은 모양의 성냥갑으로 바뀌고, 판과 이름표에 같은 테두리가 켜진다
	_tag_board = b.duplicate()
	_tag_no = Menace.box_number(Ttt.canonical(b).key)
	_tag.t = 1.0
	create_tween().tween_property(_tag, "t", 0.0, 0.7).set_delay(0.45)
	_view.flash_match()
	_view.show_beads(c.beads)
	_machine.working = true
	if _machine.mood != "lost":
		_machine.mood = "think"
	Sfx.open()
	if c.kind == "resign":
		_say("어느 칸에도 구슬이 없어요. AI가 기권했어요.")
		_machine.working = false
		_machine.mood = "resign"
		later(2.6, _finish.bind(b, "kid", true))
		return
	if _should_predict(c.beads, b):
		_predicted = true
		later(_open_s(), _ask_predict.bind(b, c.move, c.top))
		return
	later(_open_s(), _pick.bind(b, c.move, c.top))


## 맞혀 보기는 2단계에서 한 판에 한 번. 칸마다 구슬 수가 다를 때 묻는다 (다 같으면 읽을 것이 없다).
## 첫 수의 구슬이 모두 같으면 둘째 수에서 묻는다
func _should_predict(beads: Array, b: Array) -> bool:
	if set_i != 2 or _predicted:
		return false
	var lo := 999
	var hi := 0
	for i in 9:
		if b[i] == 0:
			lo = mini(lo, beads[i])
			hi = maxi(hi, beads[i])
	return hi > lo or not _moves.is_empty()


func _ask_predict(b: Array, move: Dictionary, top: bool) -> void:
	phase = "predict"
	_predict.offered = true
	_turn_t = Time.get_ticks_msec()
	_asked_now = true
	_say("AI가 어느 칸을 고를까요? 한 칸을 눌러 봐요.")
	_view.set_meta("pending", [b, move, top])
	_view.guessing = true
	_predict_tw = create_tween()
	_predict_tw.tween_interval(PREDICT_WAIT)
	_predict_tw.tween_callback(_on_guess_tap.bind(-1))


func _on_guess_tap(cell: int) -> void:
	if phase != "predict":
		return
	phase = "ai"
	if _predict_tw:
		_predict_tw.kill()
	_view.guessing = false
	var pending: Array = _view.get_meta("pending")
	var move: Dictionary = pending[1]
	if cell >= 0:
		Sfx.tap()
		_view.guess = cell
		_predict.answered = true
		_predict.ms = Time.get_ticks_msec() - _turn_t
		_predict.guess_max = _view.beads[cell] == _view.beads.max()
		_predict.hit = cell == move.cell
	_pick(pending[0], move, pending[2])


## 기계 집게가 내려와 구슬 하나를 집는다
func _pick(b: Array, move: Dictionary, top: bool) -> void:
	var cell: int = move.cell
	var pick_s := PICK_SLOW_S if set_i <= 2 else PICK_S
	_view.bead_pick = cell
	create_tween().tween_property(_view, "pick_t", 1.0, pick_s - 0.05).from(0.0)
	var hold := 0.0
	if not top:
		# 확률이 가장 높지 않은 칸을 골랐다: 헷갈리지 않게 까닭을 말하고 읽을 시간을 준다
		_explored += 1
		_asked_now = false
		_say(EXPLORE_LINE)
		_keep_line = true
		hold = 1.6
	elif _asked_now:
		_asked_now = false
		# 맞혀 본 차례: 맞고 틀림을 크게 알리지 않고 사실만 말한다
		var most: int = _view.beads.max()
		var line := "AI는 구슬이 많은 칸을 골랐어요."
		if _view.beads.count(most) > 1:
			line = "구슬 수가 같은 칸이 여럿이라 그 가운데 하나를 골랐어요."
		if _view.guess == cell:
			line += " 내가 고른 칸이에요."
		_say(line)
		_keep_line = true
	later(pick_s + hold, _place_ai.bind(b, cell, move))


## 구슬과 %가 나타나서 집게가 내려오기까지. 개념을 익히는 1·2단계에서는 읽을 시간을 넉넉히 준다
func _open_s() -> float:
	return OPEN_SLOW_S if set_i <= 2 else OPEN_S


func _place_ai(b: Array, cell: int, move: Dictionary) -> void:
	_machine.working = false
	if _machine.mood == "think":
		_machine.mood = "calm"
	_view.hide_beads()
	var nb := Ttt.place(b, cell, Ttt.AI)
	if not move.is_empty():
		_moves.append(move)
	_board = nb
	_view.put(cell, nb)
	Sfx.bead()
	var o := Ttt.outcome(nb)
	if o != "":
		_finish(nb, o)
		return
	phase = "kid"
	_turn_t = Time.get_ticks_msec()
	_view.locked = false
	_view.active = true
	# 맞혀 본 직후에는 구슬 수를 말한 줄을 그대로 둔다 (읽을 시간)
	if _keep_line:
		_keep_line = false
		return
	if set_i == 1 and game_i == 1 and _moves.size() == 1:
		_say("내 차례예요. 빈칸을 눌러 ×를 둬요.")
	else:
		_say("내 차례예요.")


func _kid_tap(cell: int) -> void:
	if phase != "kid":
		return
	_kid_ms.append(Time.get_ticks_msec() - _turn_t)
	var nb := Ttt.place(_board, cell, Ttt.KID)
	_board = nb
	_view.locked = true
	_view.active = false
	_view.guess = -1
	_view.put(cell, nb)
	Sfx.tap()
	var o := Ttt.outcome(nb)
	if o != "":
		_finish(nb, o)
	else:
		phase = "ai"
		later(0.45, _ai_turn.bind(nb))


func _finish(b: Array, o: String, resigned := false) -> void:
	phase = "end"
	_view.locked = true
	_view.active = false
	_view.hide_beads()
	_view.show_line(Ttt.win_line(b))
	Sfx.done()
	if not resigned:
		_say({"kid": "내가 이겼어요.", "ai": "AI가 이겼어요.", "draw": "비겼어요."}[o])
		_machine.mood = {"kid": "sad", "ai": "happy", "draw": "calm"}[o]
	_end = {"outcome": o, "moves": _moves, "resigned": resigned, "predict": _predict, "teach": _teach_info, "explored": _explored, "kid_ms": _kid_ms}
	if _moves.is_empty():
		later(END_S, round_end.emit.bind(_end))
	else:
		later(END_S, _start_teach)


## 판이 끝난 자리에서 바로, 같은 판 위에서: AI가 둔 칸마다 구슬이 늘거나 준다
func _start_teach() -> void:
	phase = "teach"
	# 실제 두뇌는 main이 round_end에서 바꾼다. 여기서는 복사본으로 바뀔 수만 미리 알아낸다
	var changes := Menace.learn(Menace.clone_brain(brain), _moves, _end.outcome)
	var by_hand := set_i == 2
	_say((TEACH_HAND if by_hand else TEACH_AUTO)[_end.outcome])
	_view.start_teach(changes, _end.outcome != "kid", by_hand)


func _on_taught(manual: int, total: int) -> void:
	_teach_info.manual = manual
	_teach_info.total = total
	if set_i == 2:
		_say(TEACH_DONE[_end.outcome])
		Sfx.learn()
		later(2.0, round_end.emit.bind(_end))
	else:
		later(0.9, round_end.emit.bind(_end))


## 왼쪽 이름표: 지금 판과 같은 모양이 그려진 성냥갑 (그림 + 한마디). t(1→0)는 "같은 모양" 테두리
func _paint_tag(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	# 성냥갑 뚜껑: 빨간 띠 + 남색 상표 + 판 그림
	var lid := Rect2(0, 0, r.size.x, r.size.y - R * 2.2)
	Kit.rrect(ci, Rect2(lid.position + Vector2(0, R * 0.35), lid.size), Kit.LINE, R * 0.6)
	Kit.rrect(ci, lid, Kit.NAVY, R * 0.6)
	ci.draw_rect(Rect2(lid.position + Vector2(0, R * 0.6), Vector2(lid.size.x, R * 0.55)), Kit.RED)
	var mb := minf(lid.size.y - R * 2.6, lid.size.x - R * 2.0)
	var mr := Rect2(lid.position + Vector2((lid.size.x - mb) / 2, R * 1.7), Vector2(mb, mb))
	Kit.mini_board(ci, mr, _tag_board)
	if ci.t > 0.0:
		Kit.rrect(ci, mr.grow(R * 0.22), Color.TRANSPARENT, R * 0.4, R * 0.2, Color(Kit.MUSTARD, ci.t))
	Kit.text(ci, Kit.F_LABEL, R * 1.05, "판과 같은 모양의 성냥갑", Rect2(0, lid.end.y + R * 0.6, r.size.x, R * 1.5), Kit.INK_SOFT)
