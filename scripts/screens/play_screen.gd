class_name PlayScreen
extends ScreenBase
## 놀이 한 판. AI가 먼저 둔다. AI 차례 연출은 1.2초 안 (뜸 들이기·번쩍임 없음):
## 서랍이 열림(0.45초) → 고른 칸의 구슬이 떠오름(0.2초) → 구슬이 판으로 날아가 ○가 됨(0.4초).
##
## 성냥갑 서랍은 생각 풍선 안에 있고, 풍선 꼬리는 성냥갑 기계 캐릭터("AI")로 이어진다 (여기는 AI 머릿속).
## 무대 조명: 내 차례엔 풍선이 흐려지고 판이 밝아지며 손가락 안내가 뜬다. AI 차례엔 반대.
## AI가 구슬을 꺼내는 동안 기계의 톱니바퀴가 돈다.

signal round_end(result: Dictionary)

const OPEN_S := 0.45
const LIFT_S := 0.2
const FLY_S := 0.4
const END_S := 1.3
## 내 차례에 풍선(AI 머릿속)이 흐려지는 정도
const MIND_DIM := 0.55

var brain: Dictionary
var round_i: int
var rounds: int
var score: Dictionary
var today_games: int
var percent: bool

## "ai" / "kid" / "end"
var phase := "ai"
var _board := Ttt.empty_board()
var _moves := []
var _rng := SeededRng.for_game()

var _brand: Drawn
var _round: Label
var _pills: Array[Label] = []
var _view: BoardView
var _message: Label
## 풍선 + 서랍 묶음과, 내 차례에 그 위를 덮어 흐리게 하는 종이색 덮개
var _mind: Control
var _dimmer: ColorRect
var _bubble: ThoughtBubble
var _box: MatchboxView
var _machine: MachineView
var _foot: Drawn
var _fly: Drawn

## 새 흐름 "AI 졸업시키기" (opts.newflow). 단계마다 하는 일이 다르다:
## 1단계 새내기(보기) → 2단계 연습생(맞혀 보기) → 3단계 졸업 시험(도전). 판이 끝나면 내 손으로 상과 벌을 준다.
const STAGES := ["1단계 · 새내기 AI", "2단계 · 연습생 AI", "3단계 · 졸업 시험"]
const STAGE_OPEN := [
	"AI는 틱택토가 처음이에요. 판과 같은 모양의 성냥갑을 찾아 구슬을 꺼내요.",
	"2단계예요. 이번에는 AI가 둘 칸을 한 번 맞혀 봐요.",
	"졸업 시험이에요. 혼자 %d판을 연습한 AI예요. 이길 수 있을까요?",
]
## 맞혀 보기에서 기다리는 시간. 지나면 그냥 넘어간다 (뜸 들이는 연출이 아니라 학생이 고를 시간)
const PREDICT_WAIT := 4.0
var opts := {}
## 풍선 꼬리가 닿을 자리 (기계 좌표)
var _tail_at := Vector2.ZERO
var _predicted := false
var _asked_now := false
var _predict_tw: Tween
var _predict := {"offered": false, "answered": false, "guess_max": false, "hit": false}
var _teach: TeachPanel
var _teach_info := {"manual": 0, "total": 0}
var _end := {}


func _init(b: Dictionary, r: int, total: int, s: Dictionary, games: int, show_percent: bool, options := {}) -> void:
	brain = b
	round_i = r
	rounds = total
	score = s
	today_games = games
	percent = show_percent
	opts = options


func _newflow() -> bool:
	return opts.get("newflow", false)


func build() -> void:
	_brand = Drawn.new(paint_brand)
	add_child(_brand)
	_round = Kit.label(STAGES[round_i - 1] if _newflow() else "%d판째 / %d판" % [round_i, rounds], Kit.F_LABEL, Kit.R * 1.3)
	add_child(_round)
	for p in [["나 %d" % score.kid, "kid"], ["비김 %d" % score.draw, "draw"], ["AI %d" % score.ai, "ai"]]:
		var l := Kit.pill(p[0], p[1])
		_pills.append(l)
		add_child(l)
	_view = BoardView.new()
	_view.cell_tapped.connect(_kid_tap)
	add_child(_view)
	_message = Kit.label("AI 차례예요. 지금 판 모양의 성냥갑을 찾아요.", Kit.F_BODY, Kit.R * 1.25, Kit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	add_child(_message)
	_mind = Control.new()
	_mind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mind)
	_bubble = ThoughtBubble.new()
	_mind.add_child(_bubble)
	_box = MatchboxView.new()
	_box.percent = percent
	_box.shape = _board
	_mind.add_child(_box)
	_dimmer = ColorRect.new()
	_dimmer.color = Color(Kit.PAPER, 0.0)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dimmer)
	_machine = MachineView.new()
	add_child(_machine)
	_foot = Drawn.new(_paint_foot)
	add_child(_foot)
	_fly = Drawn.new(_paint_fly)
	_fly.visible = false
	add_child(_fly)


func relayout() -> void:
	var R := Kit.R
	var w := size.x - pad.x * 2
	# 머리: 이름표 왼쪽, 판 수와 점수 오른쪽 (오른쪽 끝 3.2R는 선생님 버튼 자리)
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
	# 발: 오늘 기록과 그림 설명
	var foot_h := R * 2.4
	_foot.position = Vector2(pad.x, size.y - pad.y - foot_h)
	_foot.size = Vector2(w, foot_h)
	# 가운데: 판 + 생각 풍선(서랍) + 기계
	var top := pad.y + head_h + R
	var bottom := _foot.position.y - R
	var msg_h := R * (3.4 if portrait() else 4.0)  # 설명은 언제나 두 줄까지 (_fit_message가 맞춘다)
	var machine_size := Vector2(R * 10.0, R * 4.8)
	var bubble_pad := R * 1.3
	if portrait():
		var bs := minf(w * 0.82, (bottom - top) * 0.45)
		_view.position = Vector2((size.x - bs) / 2, top)
		_view.size = Vector2(bs, bs)
		_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Kit.place(_message, Vector2(pad.x, top + bs + R * 1.2), w)
		_bubble.tail_from_x = -1.0
		_tail_at = _machine.head()
		# 기계는 왼쪽 위, 풍선은 그 아래 (꼬리가 위로 올라간다)
		var my := top + bs + R * 1.2 + msg_h + R * 0.6
		_machine.position = Vector2(pad.x, my)
		_machine.size = machine_size
		var by := my + machine_size.y + R * 1.6
		_bubble.position = Vector2(pad.x, by)
		_bubble.size = Vector2(w, bottom - by)
	else:
		var col := R * 26
		var bs := minf(R * 24, bottom - top - msg_h - R * 0.8)
		var bt := top + (bottom - top - bs - msg_h - R * 0.8) / 2
		_view.position = Vector2(pad.x + (col - bs) / 2, bt)
		_view.size = Vector2(bs, bs)
		# 풍선은 오른쪽 위, 기계는 풍선 아래 오른쪽 끝 (꼬리가 기계 왼쪽으로 내려간다).
		# 기계를 오른쪽 끝에 두어 설명줄이 판 아래에서 꼬리 앞까지 넓게 쓴다 (두 줄에 다 들어가게)
		var rx := pad.x + col + R * 2
		_bubble.position = Vector2(rx, top)
		_bubble.size = Vector2(size.x - pad.x - rx, bottom - top - machine_size.y - R * 1.2)
		_machine.position = Vector2(size.x - pad.x - machine_size.x - R * 0.4, bottom - machine_size.y)
		_machine.size = machine_size
		var tail_x := _machine.position.x - R * 3.6
		_bubble.tail_from_x = tail_x - rx
		_tail_at = Vector2(-R * 0.5, R * 2.7)
		_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var mx := _view.position.x
		Kit.place(_message, Vector2(mx, bt + bs + R * 1.2), tail_x - R * 2.4 - mx)
	_fit_message()
	_box.position = _bubble.position + Vector2(bubble_pad, bubble_pad)
	_box.size = _bubble.size - Vector2(bubble_pad, bubble_pad) * 2
	_bubble.tail_to = _machine.position + _tail_at - _bubble.position
	_dimmer.position = _bubble.position - Vector2(Kit.R * 1.6, Kit.R * 1.6)
	_dimmer.size = _bubble.size + Vector2(Kit.R * 3.2, Kit.R * 3.2)
	_fly.size = size
	_place_teach()


func enter() -> void:
	if not _newflow():
		later(0.5, _ai_turn.bind(Ttt.empty_board()))
		return
	# 단계를 여는 한마디를 읽을 시간을 주고 시작한다
	var line: String = STAGE_OPEN[round_i - 1]
	if round_i == 3:
		line = line % opts.get("trained", 0)
	_say(line)
	_machine.mood = "lost" if round_i == 1 else "calm"
	_box.wait_text = "AI가 곧 상자를 열어요."
	later(0.9 if round_i == 1 else 1.8, _ai_turn.bind(Ttt.empty_board()))


## 설명줄은 언제나 두 줄까지. 넘치면 글자를 조금씩 줄여 두 줄에 맞춘다 (세 줄이 되면 어색하다)
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


## 무대 조명: 내 차례면 풍선이 흐려지고 판이 밝아진다
func _spotlight(kid: bool) -> void:
	_view.active = kid
	create_tween().tween_property(_dimmer, "color:a", 1.0 - MIND_DIM if kid else 0.0, 0.35).set_trans(Tween.TRANS_SINE)


func _ai_turn(b: Array) -> void:
	phase = "ai"
	_view.locked = true
	_spotlight(false)
	var c := Menace.choose_move(brain, b, _rng)
	if c.kind == "forced":
		_say("마지막 한 칸이라 성냥갑을 열지 않고 바로 둬요.")
		later(0.7, _place_ai.bind(b, c.cell, {}))
		return
	_box.title = "지금 판 모양의 성냥갑"
	_box.wait_text = "내 차례예요. 빈칸을 눌러 ×를 둬요."
	_box.show_box(b, c.beads, Menace.box_number(Ttt.canonical(b).key))
	# 판과 상표의 작은 판에 같은 테두리가 함께 켜진다: "판과 같은 모양의 성냥갑"
	_box.flash_match()
	_view.flash_match()
	create_tween().tween_property(_box, "open_t", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_machine.working = true
	if _machine.mood != "lost":
		_machine.mood = "think"
	Sfx.open()
	Sfx.slide()
	if c.kind == "resign":
		_say("이 판 모양의 상자에 구슬이 하나도 없어요. 어떻게 둬도 질 것 같대요. AI가 기권했어요.")
		_machine.working = false
		_machine.mood = "resign"
		later(2.6, _finish.bind(b, "kid", true))
		return
	if _should_predict(c.beads):
		_predicted = true
		later(OPEN_S, _ask_predict.bind(b, c.move))
		return
	if not (_newflow() and round_i == 1 and _moves.is_empty()):
		if not _newflow():
			_say("구슬이 많은 칸이 더 자주 나와요. 이번엔 어디가 나올까요?")
		else:
			_say("AI는 눈을 감고 상자에서 구슬 하나를 꺼내요. 구슬이 많은 칸이 더 잘 나와요.")
	later(OPEN_S, _lift_bead.bind(b, c.move))


## 맞혀 보기는 한 판에 한 번. 칸마다 구슬 수가 다른 상자에서 묻는다 (다 같으면 읽을 것이 없다).
## 첫 상자가 고르면 둘째 상자에서 묻는다
func _should_predict(beads: Array) -> bool:
	if not opts.get("predict", false) or _predicted:
		return false
	var lo := 999
	var hi := 0
	for i in 9:
		if _box.shape[i] == 0:
			lo = mini(lo, beads[i])
			hi = maxi(hi, beads[i])
	return hi > lo or not _moves.is_empty()


func _ask_predict(b: Array, move: Dictionary) -> void:
	phase = "predict"
	_predict.offered = true
	_say("어디가 나올까요? 서랍에서 한 칸을 눌러 맞혀 봐요.")
	_asked_now = true
	_box.pickable = true
	_box.slot_tapped.connect(_on_guess.bind(b, move))
	_predict_tw = create_tween()
	_predict_tw.tween_interval(PREDICT_WAIT)
	_predict_tw.tween_callback(_on_guess.bind(-1, b, move))


func _on_guess(cell: int, b: Array, move: Dictionary) -> void:
	if phase != "predict":
		return
	phase = "ai"
	if _predict_tw:
		_predict_tw.kill()
	_box.pickable = false
	if cell >= 0:
		Sfx.tap()
		_box.guess = cell
		_predict.answered = true
		_predict.guess_max = _box.beads[cell] == _box.beads.max()
		_predict.hit = cell == move.cell
	_lift_bead(b, move)


func _lift_bead(b: Array, move: Dictionary) -> void:
	var cell: int = move.cell
	_box.picked = cell
	_view.chosen = cell
	create_tween().tween_property(_box, "pick_t", 1.0, LIFT_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var line := "구슬 하나가 나왔어요. AI는 %s에 둬요." % Ttt.CELL_NAMES[cell]
	var guessed := _box.guess >= 0
	if _asked_now:
		_asked_now = false
		# 맞혀 본 차례: 맞고 틀림을 크게 알리지 않고 구슬 수만 말한다
		var total := 0
		for n in _box.beads:
			total += n
		line = "구슬 %d개 가운데 %d개가 있던 %s 칸이 나왔어요." % [total, _box.beads[cell], Ttt.CELL_NAMES[cell]]
		if guessed and _box.guess == cell:
			line += " 내가 고른 칸이에요."
		elif guessed:
			line += " 내가 고른 칸에는 %d개가 있었어요." % _box.beads[_box.guess]
	# 제일 많은 칸이 아니면: 적은 칸도 가끔 나온다는 걸 짚어 준다 (무작위로 꺼내는 게 규칙)
	if _box.beads.size() == 9 and _box.beads[cell] < _box.beads.max():
		line += " 구슬이 적은 칸도 가끔 나와요. AI가 다른 수를 시험해 보는 거예요."
	# 1단계 첫 수에서는 여는 한마디를 그대로 둔다 (금방 지나가므로 말을 바꾸지 않는다)
	if not (_newflow() and round_i == 1 and _moves.is_empty()):
		_say(line)
	later(LIFT_S, _fly_bead.bind(b, move))


## 고른 구슬이 서랍에서 판의 칸까지 둥글게 날아간다
func _fly_bead(b: Array, move: Dictionary) -> void:
	var inv := get_global_transform().affine_inverse()
	var from := inv * _box.picked_bead_global()
	var to := inv * _view.cell_center_global(move.cell)
	var r0 := _box.bead_r_global() * 1.15 / get_global_transform().get_scale().x
	var r1 := _view.cell_size_global() * 0.2 / get_global_transform().get_scale().x
	_box.bead_out = true
	_box.queue_redraw()
	_fly.set_meta("cell", move.cell)
	_fly.set_meta("path", [from, to, r0, r1])
	_fly.t = 0.0
	_fly.visible = true
	var tw := create_tween()
	tw.tween_property(_fly, "t", 1.0, FLY_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_place_ai.bind(b, move.cell, move))


func _place_ai(b: Array, cell: int, move: Dictionary) -> void:
	_fly.visible = false
	_machine.working = false
	if _machine.mood == "think":
		_machine.mood = "calm"
	var nb := Ttt.place(b, cell, Ttt.AI)
	if not move.is_empty():
		_moves.append(move)
	_board = nb
	_view.chosen = -1
	_view.put(cell, nb)
	Sfx.bead()
	_box.title = "AI가 방금 연 성냥갑"
	_box.queue_redraw()
	var o := Ttt.outcome(nb)
	if o != "":
		_finish(nb, o)
	else:
		phase = "kid"
		_view.locked = false
		_spotlight(true)
		# 1단계의 내 차례 문구는 학생이 둘 때까지 남아 있으므로, 여기서 한 가지씩 쉬운 말로 설명한다
		if _newflow() and round_i == 1 and _moves.size() == 1:
			_say("AI가 판과 같은 모양의 성냥갑에서 구슬을 꺼내 뒀어요. 이제 내 차례예요. 빈칸을 눌러 ×를 둬요.")
		elif _newflow() and round_i == 1 and _moves.size() == 2:
			_say("AI는 눈을 감고 구슬 하나를 꺼내요. 그래서 구슬이 많은 칸이 더 잘 나와요.")
		elif _newflow() and round_i == 1 and _moves.size() == 3:
			_say("사탕 주머니에 딸기 맛이 많으면 딸기 맛이 잘 나오죠? 구슬도 똑같아요.")
		else:
			_say("내 차례예요. 빈칸을 눌러 ×를 둬요.")


func _kid_tap(cell: int) -> void:
	if phase != "kid":
		return
	var nb := Ttt.place(_board, cell, Ttt.KID)
	_board = nb
	_view.locked = true
	_view.put(cell, nb)
	Sfx.tap()
	create_tween().tween_property(_box, "open_t", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var o := Ttt.outcome(nb)
	if o != "":
		_finish(nb, o)
	else:
		phase = "ai"
		_spotlight(false)
		_say("AI 차례예요. 지금 판 모양의 성냥갑을 찾아요.")
		later(0.45, _ai_turn.bind(nb))


func _finish(b: Array, o: String, resigned := false) -> void:
	phase = "end"
	_view.locked = true
	_spotlight(false)
	_view.show_line(Ttt.win_line(b))
	Sfx.done()
	if not resigned:
		_say({"kid": "내가 이겼어요. AI가 지는 수를 배울 차례예요.", "ai": "AI가 이겼어요. 이 수를 더 좋아하게 돼요.", "draw": "비겼어요. 비기는 것도 AI에겐 작은 상이에요."}[o])
		_machine.mood = {"kid": "sad", "ai": "happy", "draw": "calm"}[o]
	_end = {"outcome": o, "moves": _moves, "resigned": resigned, "predict": _predict, "teach": _teach_info}
	if opts.get("teach", false) and not _moves.is_empty():
		later(END_S, _start_teach)
	else:
		later(END_S, round_end.emit.bind(_end))


# ---------- 내 손으로 상과 벌 주기 ----------

const TEACH_ASK := {
	"kid": "AI가 졌어요. AI가 쓴 상자를 눌러 구슬을 1개씩 빼요. 이게 벌이에요.",
	"ai": "AI가 이겼어요. AI가 쓴 상자를 눌러 구슬을 3개씩 넣어요. 이게 상이에요.",
	"draw": "비겼어요. AI가 쓴 상자를 눌러 구슬을 1개씩 넣어요. 작은 상이에요.",
}
const TEACH_DONE := {
	"kid": "이제 이 칸들은 조금 덜 나와요. 내가 AI에게 \"그 수는 안 돼\"를 가르쳤어요.",
	"ai": "이제 이 칸들은 더 자주 나와요. 내가 AI에게 \"그 수는 좋아\"를 가르쳤어요.",
	"draw": "이제 이 칸들은 조금 더 나와요. 지지 않는 것도 AI에겐 배울 거리예요.",
}


## 판이 끝난 자리에서 바로: 풍선(서랍)이 물러나고, 이번 판에 연 상자들이 줄지어 선다
func _start_teach() -> void:
	phase = "teach"
	# 실제 두뇌는 main이 round_end에서 바꾼다. 여기서는 복사본으로 바뀔 수만 미리 알아낸다
	var changes := Menace.learn(Menace.clone_brain(brain), _moves, _end.outcome)
	_say(TEACH_ASK[_end.outcome] + (" 한 판에 쓴 상자가 모두 함께 바뀌어요." if round_i >= 2 and changes.size() > 1 else ""))
	_teach = TeachPanel.new(changes, _end.outcome)
	_teach.finished.connect(_on_taught)
	_teach.modulate.a = 0.0
	add_child(_teach)
	_place_teach()
	var tw := create_tween().set_parallel()
	tw.tween_property(_mind, "modulate:a", 0.0, 0.3)
	tw.tween_property(_dimmer, "color:a", 0.0, 0.3)
	tw.tween_property(_teach, "modulate:a", 1.0, 0.35).set_delay(0.15)


func _place_teach() -> void:
	if _teach:
		_teach.position = _bubble.position
		_teach.size = _bubble.size


func _on_taught(manual: int, total: int) -> void:
	_teach_info.manual = manual
	_teach_info.total = total
	_say(TEACH_DONE[_end.outcome])
	Sfx.learn()
	later(2.2, round_end.emit.bind(_end))


func _paint_fly(ci: Drawn) -> void:
	if not ci.has_meta("path"):
		return
	var p: Array = ci.get_meta("path")
	var from: Vector2 = p[0]
	var to: Vector2 = p[1]
	var t := ci.t
	# 위로 볼록한 곡선 (두 점 사이 거리의 25%만큼)
	var mid := (from + to) / 2 + Vector2(0, -from.distance_to(to) * 0.25)
	var pos := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
	var r := lerpf(p[2], p[3], t)
	Kit.bead(ci, pos, r, ci.get_meta("cell"), 1.0 - maxf(t - 0.85, 0.0) / 0.15 * 0.6)


## 이름표 "성냥갑 AI · MENACE 1961"
static func paint_brand(ci: Control) -> void:
	var R := Kit.R
	var tw := Kit.F_TITLE.get_string_size("성냥갑 AI", HORIZONTAL_ALIGNMENT_LEFT, -1, int(R * 1.85)).x
	var r := Rect2(Vector2.ZERO, Vector2(R * 0.75 + R * 2.3 + R * 0.75 + tw + R * 1.2, ci.size.y))
	Kit.rrect(ci, r.grow(R * 0.39), Kit.RED, R * 0.9)
	Kit.rrect(ci, r.grow(R * 0.22), Kit.CREAM, R * 0.75)
	Kit.rrect(ci, r, Kit.RED, R * 0.55)
	var m := Rect2(Vector2(R * 0.75, (r.size.y - R * 1.35) / 2), Vector2(R * 2.3, R * 1.35))
	Kit.rrect(ci, m, Kit.CREAM, R * 0.2)
	ci.draw_rect(Rect2(m.position, Vector2(m.size.x, R * 0.4)), Kit.MUSTARD)
	ci.draw_circle(m.get_center() + Vector2(-R * 0.4, R * 0.2), R * 0.23, Kit.RED, true, -1.0, true)
	ci.draw_circle(m.get_center() + Vector2(R * 0.4, R * 0.2), R * 0.23, Kit.NAVY, true, -1.0, true)
	var tx := R * 3.8
	Kit.text(ci, Kit.F_TITLE, R * 1.85, "성냥갑 AI", Rect2(tx, R * 0.15, tw + R, r.size.y * 0.62), Kit.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	Kit.text(ci, Kit.F_LABEL, R * 0.85, "MENACE  ·  1961", Rect2(tx, r.size.y * 0.62, tw + R, r.size.y * 0.3), Kit.CREAM, HORIZONTAL_ALIGNMENT_LEFT)


func _paint_foot(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	Kit.rrect(ci, r, Kit.CREAM, R * 0.55)
	IdleScreen._dashed_frame(ci, r, R * 0.11)
	var h := r.size.y
	var fs := R * 1.05
	var x := R * 1.0
	var a := "오늘 함께 가르친 판" if _newflow() else "오늘 AI가 배운 판"
	Kit.text(ci, Kit.F_LABEL, fs, a, Rect2(x, 0, R * 20, h), Kit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	x += Kit.F_LABEL.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x + R * 0.4
	Kit.text(ci, Kit.F_LABEL, R * 1.35, str(today_games), Rect2(x, 0, R * 5, h), Kit.RED_INK, HORIZONTAL_ALIGNMENT_LEFT)
	x += R * 3.2
	Kit.mark_o(ci, Vector2(x + R * 0.6, h / 2), R * 3.2)
	Kit.text(ci, Kit.F_LABEL, fs, "AI", Rect2(x + R * 1.7, 0, R * 3, h), Kit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	x += R * 3.6
	Kit.mark_x(ci, Vector2(x + R * 0.6, h / 2), R * 3.2)
	Kit.text(ci, Kit.F_LABEL, fs, "나", Rect2(x + R * 1.7, 0, R * 3, h), Kit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	Kit.text(ci, Kit.F_LABEL, fs, "구슬 수 = AI가 그 칸을 좋아하는 정도", Rect2(0, 0, r.size.x - R * 1.0, h), Kit.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
