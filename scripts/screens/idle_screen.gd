class_name IdleScreen
extends ScreenBase
## 첫 화면. 왼쪽에 이름표와 메뉴 단추 셋, 오른쪽에 오늘의 순위.
##   AI 가르치기 (start): AI는 어떻게 배울까? 처음 온 학생은 여기부터
##   AI 키우기 대회 (contest): 연습 계획을 세워 점수를 받고 순위표에 이름을 올린다. 반복해서 하는 곳
##   1961년 성냥갑 이야기 (story): 안내 4장
## 그대로 두면 main이 순위표와 이야기를 번갈아 보여 준다 (기다리는 학생이 본다).

signal start
signal contest
signal story

var today: Dictionary
var newflow := false
var ranking: Array = []

var _badge: Drawn
var _lead: Label
var _teach: Button
var _contest: Button
var _story: Button
var _first: Label
var _board: Drawn
var _today: Drawn
var _time := 0.0
var _gone := false


func _init(t: Dictionary, new_flow := false, rank_list: Array = []) -> void:
	today = t
	newflow = new_flow
	ranking = rank_list


func build() -> void:
	var R := Kit.R
	_badge = Drawn.new(_paint_badge)
	add_child(_badge)
	_lead = Kit.label("이기는 법을 모르는 AI예요. 내가 가르쳐 볼까요?", Kit.F_BODY, R * 1.35, Kit.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	add_child(_lead)
	_teach = _menu_button("AI 가르치기", "AI는 어떻게 배울까요?", Kit.RED, Kit.RED_DARK)
	_teach.pressed.connect(_pick.bind(start))
	add_child(_teach)
	_first = Kit.pill("처음이라면 여기부터", "draw", 0.95)
	_first.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_first)
	_contest = _menu_button("AI 키우기 대회", "연습 계획을 세워 점수에 도전해요", Kit.NAVY, Kit.INK)
	_contest.pressed.connect(_pick.bind(contest))
	add_child(_contest)
	_story = Kit.button("1961년 성냥갑 이야기", "soft", true)
	_story.pressed.connect(_pick.bind(story))
	add_child(_story)
	_board = Drawn.new(_paint_board)
	add_child(_board)
	_today = Drawn.new(_paint_today)
	add_child(_today)


## 큰 메뉴 단추: 제목 한 줄 + 작은 설명 한 줄
func _menu_button(title: String, sub: String, bg: Color, shadow: Color) -> Button:
	var R := Kit.R
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		var st := Kit.box(bg, R * 0.8)
		var down: bool = state == "pressed"
		st.shadow_color = shadow
		st.shadow_size = 0
		st.shadow_offset = Vector2(0, R * (0.1 if down else 0.35))
		st.expand_margin_top = -R * 0.2 if down else 0.0
		b.add_theme_stylebox_override(state, st)
	var t := Kit.label(title, Kit.F_TITLE, R * 2.0, Kit.CREAM)
	t.name = "T"
	b.add_child(t)
	var s := Kit.label(sub, Kit.F_BODY, R * 1.1, Kit.CREAM)
	s.name = "S"
	b.add_child(s)
	return b


func _place_menu(b: Button, pos: Vector2, sz: Vector2) -> void:
	var R := Kit.R
	b.position = pos
	b.size = sz
	var t: Label = b.get_node("T")
	var s: Label = b.get_node("S")
	t.size = t.get_combined_minimum_size()
	s.size = s.get_combined_minimum_size()
	var h := t.size.y + s.size.y
	t.position = Vector2(R * 1.6, (sz.y - h) / 2)
	s.position = Vector2(R * 1.6, t.position.y + t.size.y)


func _pick(sig: Signal) -> void:
	if _gone:
		return
	_gone = true
	Sfx.tap()
	sig.emit()


func relayout() -> void:
	var R := Kit.R
	var w := minf(size.x - pad.x * 2, R * 64)
	var x0 := (size.x - w) / 2
	var gap := R * 2.4
	var vertical := portrait()
	var lw := w if vertical else (w - gap) * 0.56
	var bw := R * 12.5 + Kit.F_TITLE.get_string_size("성냥갑 AI", HORIZONTAL_ALIGNMENT_LEFT, -1, int(R * 3.6)).x
	var bh := R * 7.0
	var lead_h := Kit.wrapped_height(_lead, lw)
	var mh := R * 5.4
	_story.size = _story.get_combined_minimum_size()
	var left_h := bh + R * 1.2 + lead_h + R * 1.4 + mh * 2 + R * 1.0 + R * 1.0 + _story.size.y
	var today_h := R * 2.6
	var total := left_h + R * 1.6 + today_h
	var y := maxf(pad.y, (size.y - total) / 2)
	var top := y
	_badge.position = Vector2(x0, y)
	_badge.size = Vector2(minf(bw, lw), bh)
	y += bh + R * 1.2
	Kit.place(_lead, Vector2(x0, y), lw)
	y += lead_h + R * 1.4
	_place_menu(_teach, Vector2(x0, y), Vector2(lw, mh))
	_first.size = _first.get_combined_minimum_size()
	_first.position = Vector2(x0 + lw - _first.size.x - R * 1.2, y + (mh - _first.size.y) / 2)
	y += mh + R * 1.0
	_place_menu(_contest, Vector2(x0, y), Vector2(lw, mh))
	y += mh + R * 1.0
	_story.position = Vector2(x0, y)
	y += _story.size.y
	if vertical:
		_board.position = Vector2(x0, y + R * 1.6)
		_board.size = Vector2(w, R * 16)
		y = _board.position.y + _board.size.y
	else:
		_board.position = Vector2(x0 + lw + gap, top)
		_board.size = Vector2(w - lw - gap, y - top)
	_today.position = Vector2(x0, y + R * 1.6)
	_today.size = Vector2(w, today_h)


func enter() -> void:
	rise_in(_badge, 0.0)
	rise_in(_lead, 0.1)
	rise_in(_teach, 0.2)
	rise_in(_first, 0.2)
	rise_in(_contest, 0.3)
	rise_in(_story, 0.4)
	rise_in(_board, 0.3)
	rise_in(_today, 0.5)


func _process(delta: float) -> void:
	_time += delta
	_badge.t = _time


func _paint_badge(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	Kit.rrect(ci, r.grow(R * 0.5), Kit.RED, R * 1.3)
	Kit.rrect(ci, r.grow(R * 0.28), Kit.CREAM, R * 1.1)
	Kit.rrect(ci, r, Kit.RED, R * 0.8)
	# 서랍이 4초에 한 번 나왔다 들어간다
	var cyc := fmod(ci.t, 4.0)
	var open := 0.0
	if cyc < 0.8:
		open = ease_out(cyc / 0.8)
	elif cyc < 2.8:
		open = 1.0
	elif cyc < 3.6:
		open = 1.0 - ease_out((cyc - 2.8) / 0.8)
	Kit.matchbox_art(ci, Rect2(R * 0.8, R * 0.6, R * 9.0, ci.size.y - R * 1.2), open, ci.t / 1.6)
	var tx := R * 10.6
	Kit.text(ci, Kit.F_TITLE, R * 3.6, "성냥갑 AI", Rect2(tx, R * 0.9, ci.size.x - tx, R * 4.0), Kit.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	Kit.text(ci, Kit.F_LABEL, R * 1.1, "M E N A C E  ·  1 9 6 1", Rect2(tx + R * 0.2, R * 4.7, ci.size.x - tx, R * 1.4), Kit.CREAM, HORIZONTAL_ALIGNMENT_LEFT)


func _paint_board(ci: Drawn) -> void:
	RankBoard.paint(ci, Rect2(Vector2.ZERO, ci.size), RankBoard.today(ranking), 7, "오늘의 순위  AI 키우기 대회")


func _paint_today(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	Kit.rrect(ci, r, Kit.CREAM, R * 0.6)
	_dashed_frame(ci, r, R * 0.11)
	var items := [
		["오늘 선생님", "%d명" % today.get("teachers", 0), Kit.INK, Kit.NAVY],
		["우리 AI 졸업", "%d번" % today.get("grads", 0), Kit.INK, Kit.RED_INK],
	]
	if not newflow:
		items = [
			["오늘 AI를 가르친 판", str(today.games), Kit.INK, Kit.RED_INK],
			["학생 승", str(today.kid), Kit.NAVY, Kit.NAVY],
			["비김", str(today.draw), Kit.INK_SOFT, Kit.INK],
			["AI 승", str(today.ai), Kit.RED_INK, Kit.RED_INK],
		]
	var x := R * 1.4
	for it in items:
		var lw := Kit.F_LABEL.get_string_size(it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(R * 1.15)).x
		Kit.text(ci, Kit.F_LABEL, R * 1.15, it[0], Rect2(x, 0, lw + R, ci.size.y), it[2], HORIZONTAL_ALIGNMENT_LEFT)
		var vw := Kit.F_LABEL.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(R * 1.4)).x
		Kit.text(ci, Kit.F_LABEL, R * 1.4, it[1], Rect2(x + lw + R * 0.4, 0, vw + R, ci.size.y), it[3], HORIZONTAL_ALIGNMENT_LEFT)
		x += lw + vw + R * 2.6


static func _dashed_frame(ci: CanvasItem, r: Rect2, w: float) -> void:
	var g := r.grow(-w)
	var c := Kit.LINE
	var dash := Kit.R * 0.35
	ci.draw_dashed_line(g.position, Vector2(g.end.x, g.position.y), c, w, dash)
	ci.draw_dashed_line(Vector2(g.position.x, g.end.y), g.end, c, w, dash)
	ci.draw_dashed_line(g.position, Vector2(g.position.x, g.end.y), c, w, dash)
	ci.draw_dashed_line(Vector2(g.end.x, g.position.y), g.end, c, w, dash)
