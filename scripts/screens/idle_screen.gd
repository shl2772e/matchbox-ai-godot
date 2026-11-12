class_name IdleScreen
extends ScreenBase
## 대기 화면. 성냥갑 서랍이 천천히 열렸다 닫히고, 화면 어디를 눌러도 시작한다.

signal start

var today: Dictionary
var _badge: Drawn
var _lead: Label
var _go: Label
var _today: Drawn
var _time := 0.0
var _started := false


## 새 흐름이면 오늘 기록을 "선생님 몇 명, AI 졸업 몇 번"으로 보여 준다 (다음 친구가 이어받는 우리 반 기록)
var newflow := false


func _init(t: Dictionary, new_flow := false) -> void:
	today = t
	newflow = new_flow


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_badge = Drawn.new(_paint_badge)
	add_child(_badge)
	_lead = Kit.label("이 AI는 이기는 법을 모른 채 태어났어요. 오늘 내가 가르쳐 볼까요?", Kit.F_BODY, Kit.R * 1.6, Kit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	add_child(_lead)
	_go = Kit.pill("화면을 누르면 시작해요", "kid", 1.7)
	_go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_go)
	_today = Drawn.new(_paint_today)
	add_child(_today)


func relayout() -> void:
	var R := Kit.R
	var bw := R * 14.5 + Kit.F_TITLE.get_string_size("성냥갑 AI", HORIZONTAL_ALIGNMENT_LEFT, -1, int(R * 4.6)).x
	var bh := R * 9.0
	var lead_w := minf(size.x - pad.x * 2, R * 50)
	_lead.size = Vector2(lead_w, 0)
	var lead_h := Kit.wrapped_height(_lead, lead_w)
	var go_size := _go.get_combined_minimum_size()
	var today_h := R * 3.0
	var gap := R * 1.6
	var total := bh + gap * 1.6 + lead_h + gap + go_size.y + gap * 1.4 + today_h
	var y := (size.y - total) / 2
	_badge.position = Vector2((size.x - bw) / 2, y)
	_badge.size = Vector2(bw, bh)
	y += bh + gap * 1.6
	Kit.place(_lead, Vector2((size.x - lead_w) / 2, y), lead_w)
	y += lead_h + gap
	_go.size = go_size
	_go.position = Vector2((size.x - go_size.x) / 2, y)
	_go.pivot_offset = go_size / 2
	y += go_size.y + gap * 1.4
	_today.position = Vector2((size.x - R * 32) / 2, y)
	_today.size = Vector2(R * 32, today_h)


func enter() -> void:
	rise_in(_badge, 0.0)
	rise_in(_lead, 0.15)
	rise_in(_go, 0.3)
	rise_in(_today, 0.45)


func _process(delta: float) -> void:
	_time += delta
	_badge.t = _time
	# 시작 안내는 숨 쉬듯 조금 옅어졌다 돌아온다 (2.4초)
	_go.self_modulate.a = 0.875 + 0.125 * cos(_time * TAU / 2.4)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _started:
		_started = true
		start.emit()
		accept_event()


func _paint_badge(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	Kit.rrect(ci, r.grow(R * 0.6), Kit.RED, R * 1.5)
	Kit.rrect(ci, r.grow(R * 0.35), Kit.CREAM, R * 1.25)
	Kit.rrect(ci, r, Kit.RED, R * 0.9)
	# 서랍이 4초에 한 번 나왔다 들어간다
	var cyc := fmod(ci.t, 4.0)
	var open := 0.0
	if cyc < 0.8:
		open = ease_out(cyc / 0.8)
	elif cyc < 2.8:
		open = 1.0
	elif cyc < 3.6:
		open = 1.0 - ease_out((cyc - 2.8) / 0.8)
	Kit.matchbox_art(ci, Rect2(R * 1.0, R * 0.8, R * 11.0, ci.size.y - R * 1.6), open, ci.t / 1.6)
	var tx := R * 13.0
	Kit.text(ci, Kit.F_TITLE, R * 4.6, "성냥갑 AI", Rect2(tx, R * 1.2, ci.size.x - tx, R * 5.0), Kit.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	Kit.text(ci, Kit.F_LABEL, R * 1.3, "M E N A C E  ·  1 9 6 1", Rect2(tx + R * 0.2, R * 6.0, ci.size.x - tx, R * 1.6), Kit.CREAM, HORIZONTAL_ALIGNMENT_LEFT)


func _paint_today(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	Kit.rrect(ci, r, Kit.CREAM, R * 0.6)
	_dashed_frame(ci, r, R * 0.11)
	var items := [
		["오늘 AI를 가르친 판", str(today.games), Kit.INK, Kit.RED_INK],
		["학생 승", str(today.kid), Kit.NAVY, Kit.NAVY],
		["비김", str(today.draw), Kit.INK_SOFT, Kit.INK],
		["AI 승", str(today.ai), Kit.RED_INK, Kit.RED_INK],
	]
	var widths := [11.0, 6.5, 5.5, 6.0]
	if newflow:
		items = [
			["오늘 선생님", "%d명" % today.get("teachers", 0), Kit.INK, Kit.NAVY],
			["우리 AI 졸업", "%d번" % today.get("grads", 0), Kit.INK, Kit.RED_INK],
			["함께 가르친 판", str(today.games), Kit.INK, Kit.RED_INK],
		]
		widths = [9.5, 10.5, 10.0]
	var x := R * 1.2
	for i in items.size():
		var it: Array = items[i]
		var w: float = widths[i] * R
		var lw := Kit.F_LABEL.get_string_size(it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(R * 1.2)).x
		Kit.text(ci, Kit.F_LABEL, R * 1.2, it[0], Rect2(x, 0, w, ci.size.y), it[2], HORIZONTAL_ALIGNMENT_LEFT)
		Kit.text(ci, Kit.F_LABEL, R * 1.5, it[1], Rect2(x + lw + R * 0.4, 0, w, ci.size.y), it[3], HORIZONTAL_ALIGNMENT_LEFT)
		x += w


static func _dashed_frame(ci: CanvasItem, r: Rect2, w: float) -> void:
	var g := r.grow(-w)
	var c := Kit.LINE
	var dash := Kit.R * 0.35
	ci.draw_dashed_line(g.position, Vector2(g.end.x, g.position.y), c, w, dash)
	ci.draw_dashed_line(Vector2(g.position.x, g.end.y), g.end, c, w, dash)
	ci.draw_dashed_line(g.position, Vector2(g.position.x, g.end.y), c, w, dash)
	ci.draw_dashed_line(Vector2(g.end.x, g.position.y), g.end, c, w, dash)
