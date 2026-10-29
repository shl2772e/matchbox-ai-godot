class_name PlayScreen
extends ScreenBase
## 놀이 한 판. AI가 먼저 둔다. AI 차례 연출은 1.2초 안 (뜸 들이기·번쩍임 없음):
## 서랍이 열림(0.45초) → 고른 칸의 구슬이 떠오름(0.2초) → 구슬이 판으로 날아가 ○가 됨(0.4초).

signal round_end(result: Dictionary)

const OPEN_S := 0.45
const LIFT_S := 0.2
const FLY_S := 0.4
const END_S := 1.3

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
var _box: MatchboxView
var _foot: Drawn
var _fly: Drawn


func _init(b: Dictionary, r: int, total: int, s: Dictionary, games: int, show_percent: bool) -> void:
	brain = b
	round_i = r
	rounds = total
	score = s
	today_games = games
	percent = show_percent


func build() -> void:
	_brand = Drawn.new(paint_brand)
	add_child(_brand)
	_round = Kit.label("%d판째 / %d판" % [round_i, rounds], Kit.F_LABEL, Kit.R * 1.3)
	add_child(_round)
	for p in [["나 %d" % score.kid, "kid"], ["비김 %d" % score.draw, "draw"], ["AI %d" % score.ai, "ai"]]:
		var l := Kit.pill(p[0], p[1])
		_pills.append(l)
		add_child(l)
	_view = BoardView.new()
	_view.cell_tapped.connect(_kid_tap)
	add_child(_view)
	_message = Kit.label("AI 차례예요. 성냥갑을 열어요.", Kit.F_BODY, Kit.R * 1.25, Kit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	add_child(_message)
	_box = MatchboxView.new()
	_box.percent = percent
	_box.shape = _board
	add_child(_box)
	_foot = Drawn.new(_paint_foot)
	add_child(_foot)
	_fly = Drawn.new(_paint_fly)
	_fly.visible = false
	add_child(_fly)


func relayout() -> void:
	var R := Kit.R
	var w := size.x - pad.x * 2
	# 머리: 이름표 왼쪽, 판 수와 점수 오른쪽
	var head_h := R * 3.4
	_brand.position = pad + Vector2(R * 0.4, R * 0.2)
	_brand.size = Vector2(R * 13, head_h - R * 0.4)
	var x := size.x - pad.x
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
	# 가운데: 판 + 성냥갑
	var top := pad.y + head_h + R
	var bottom := _foot.position.y - R
	var msg_h := R * 3.4
	if portrait():
		var bs := minf(w * 0.82, (bottom - top) * 0.45)
		_view.position = Vector2((size.x - bs) / 2, top)
		_view.size = Vector2(bs, bs)
		Kit.place(_message, Vector2(pad.x, top + bs + R * 1.2), w)
		var by := top + bs + R * 1.2 + msg_h + R
		_box.position = Vector2(pad.x, by)
		_box.size = Vector2(w, bottom - by)
	else:
		var col := R * 26
		var bs := minf(R * 24, bottom - top - msg_h - R * 0.8)
		var bt := top + (bottom - top - bs - msg_h - R * 0.8) / 2
		_view.position = Vector2(pad.x + (col - bs) / 2, bt)
		_view.size = Vector2(bs, bs)
		Kit.place(_message, Vector2(pad.x, bt + bs + R * 1.2), col)
		_box.position = Vector2(pad.x + col + R * 2, top)
		_box.size = Vector2(size.x - pad.x - _box.position.x, bottom - top)
	_fly.size = size


func enter() -> void:
	later(0.5, _ai_turn.bind(Ttt.empty_board()))


func _say(s: String) -> void:
	Kit.set_text(_message, s)
	_message.modulate.a = 0.35
	create_tween().tween_property(_message, "modulate:a", 1.0, 0.25)


func _ai_turn(b: Array) -> void:
	phase = "ai"
	_view.locked = true
	var c := Menace.choose_move(brain, b, _rng)
	if c.kind == "forced":
		_say("마지막 한 칸이라 성냥갑을 열지 않고 바로 둬요.")
		later(0.7, _place_ai.bind(b, c.cell, {}))
		return
	_box.title = "지금 판 모양의 성냥갑"
	_box.show_box(b, c.beads, Menace.box_number(Ttt.canonical(b).key))
	create_tween().tween_property(_box, "open_t", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.open()
	if c.kind == "resign":
		_say("이 판 모양의 상자에 구슬이 하나도 없어요. 어떻게 둬도 질 것 같대요. AI가 기권했어요.")
		later(2.6, _finish.bind(b, "kid", true))
		return
	_say("AI가 성냥갑을 열었어요. 구슬이 많은 칸일수록 잘 나와요.")
	later(OPEN_S, _lift_bead.bind(b, c.move))


func _lift_bead(b: Array, move: Dictionary) -> void:
	var cell: int = move.cell
	_box.picked = cell
	_view.chosen = cell
	create_tween().tween_property(_box, "pick_t", 1.0, LIFT_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_say("구슬 하나가 나왔어요. AI는 %s에 둬요." % Ttt.CELL_NAMES[cell])
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
		_say("AI 차례예요.")
		later(0.45, _ai_turn.bind(nb))


func _finish(b: Array, o: String, resigned := false) -> void:
	phase = "end"
	_view.locked = true
	_view.show_line(Ttt.win_line(b))
	Sfx.done()
	if not resigned:
		_say({"kid": "내가 이겼어요.", "ai": "AI가 이겼어요.", "draw": "비겼어요."}[o])
	later(END_S, round_end.emit.bind({"outcome": o, "moves": _moves, "resigned": resigned}))


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


## 이름표 "성냥갑 AI · MENACE 1961" (결과·배우기 화면에서도 쓴다)
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
	var a := "오늘 AI가 배운 판"
	Kit.text(ci, Kit.F_LABEL, fs, a, Rect2(x, 0, R * 20, h), Kit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	x += Kit.F_LABEL.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x + R * 0.4
	Kit.text(ci, Kit.F_LABEL, R * 1.35, str(today_games), Rect2(x, 0, R * 5, h), Kit.RED_INK, HORIZONTAL_ALIGNMENT_LEFT)
	x += R * 3.2
	Kit.mark_o(ci, Vector2(x + R * 0.6, h / 2), R * 3.2)
	Kit.text(ci, Kit.F_LABEL, fs, "AI", Rect2(x + R * 1.7, 0, R * 3, h), Kit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	x += R * 3.6
	Kit.mark_x(ci, Vector2(x + R * 0.6, h / 2), R * 3.2)
	Kit.text(ci, Kit.F_LABEL, fs, "나", Rect2(x + R * 1.7, 0, R * 3, h), Kit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	Kit.text(ci, Kit.F_LABEL, fs, "구슬이 많은 칸일수록 AI가 자주 골라요", Rect2(0, 0, r.size.x - R * 1.0, h), Kit.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
