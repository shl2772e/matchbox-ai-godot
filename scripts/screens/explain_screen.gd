class_name ExplainScreen
extends ScreenBase
## 세 판 묶음이 끝난 뒤의 설명 한 장. 놀이 중에는 글을 거의 띄우지 않고, 방금 본 것을 여기서 한 가지만 설명한다.
##   "pick"   1단계 뒤: AI는 구슬을 집어서 둔다 (움직이는 그림) + 판이 끝나면 구슬 수가 바뀐다
##   "change" 2단계 뒤: 내가 준 상과 벌로 첫 상자의 구슬이 이렇게 달라졌다 → 수백 번 하면? (빨리 감기로)
## 왼쪽에 그림, 오른쪽에 짧은 글 세 줄, 아래에 단추 하나.

signal done

const DEMO := [5, 0, 2, 0, 0, 1, 0, 0, 0]
const DEMO_BOARD := [0, 2, 0, 1, 0, 0, 0, 0, 0]
const START := [4, 4, 4, 4, 4, 4, 4, 4, 4]

var kind: String
var now_beads: Array
var train_games: int
## 지금까지 학생이 둔 판 수 (설명에 실제 수를 적는다)
var played := 0

var _title: Label
var _art: Drawn
var _lines: Array[Label] = []
var _next: Button
var _time := 0.0
var _gone := false


func _init(k: String, beads: Array = [], games := 0, played_games := 0) -> void:
	played = played_games
	kind = k
	now_beads = beads
	train_games = games


func _texts() -> Array:
	if kind == "pick":
		return [
			"AI는 생각하지 않아요. 칸마다 든 구슬을 보고 둬요. 구슬이 많은 칸일수록 더 잘 골라요.",
			"판이 끝나면 구슬 수가 바뀌어요. AI가 이기면 3개 늘고, 비기면 1개 늘고, 지면 1개 줄어요.",
			"그래서 이긴 수는 자주 두고, 진 수는 점점 안 두게 돼요. 이제 내 손으로 구슬을 넣고 빼 봐요.",
		]
	return [
		_change_line(),
		"구슬이 늘어난 칸은 더 잘 고르고, 줄어든 칸은 덜 골라요. 그래서 이긴 수는 자주 두고, 진 수는 점점 안 두게 돼요.",
		"이 일을 아주 많이 하면 어떻게 될까요? 이제 AI가 혼자 %d판을 연습해요." % train_games,
	]


## 첫 상자에서 가장 많이 바뀐 칸을 실제 수로 말한다
func _change_line() -> String:
	var best := 0
	for i in 9:
		if absi(now_beads[i] - START[i]) > absi(now_beads[best] - START[best]):
			best = i
	var a: int = START[best]
	var b: int = now_beads[best]
	if b > a:
		return "지금까지 %d판을 두는 동안 %s 칸의 구슬이 %d개에서 %d개로 늘었어요." % [played, Ttt.CELL_NAMES[best], a, b]
	if b < a:
		return "지금까지 %d판을 두는 동안 %s 칸의 구슬이 %d개에서 %d개로 줄었어요." % [played, Ttt.CELL_NAMES[best], a, b]
	return "지금까지 %d판을 두는 동안 AI의 구슬이 조금씩 바뀌었어요." % played


func build() -> void:
	var R := Kit.R
	var title := "AI는 이렇게 둬요" if kind == "pick" else "내가 준 상과 벌로 AI가 달라졌어요"
	_title = Kit.label(title, Kit.F_TITLE, R * 2.4, Kit.NAVY, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_title)
	_art = Drawn.new(_paint_pick if kind == "pick" else _paint_change)
	add_child(_art)
	for s in _texts():
		var l := Kit.label(s, Kit.F_BODY, R * 1.35, Kit.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
		l.label_settings.line_spacing = R * 0.5
		add_child(l)
		_lines.append(l)
	_next = Kit.button("내가 가르쳐 보기" if kind == "pick" else "빨리 감기 하러 가기", "primary", true)
	_next.pressed.connect(_go)
	add_child(_next)


func _go() -> void:
	if _gone:
		return
	_gone = true
	done.emit()


func relayout() -> void:
	var R := Kit.R
	var w := minf(size.x - pad.x * 2, R * 60)
	var x0 := (size.x - w) / 2
	_next.size = _next.get_combined_minimum_size()
	var vertical := portrait()
	var ah := R * (21.0 if kind == "pick" else 13.5)
	var art := Vector2(minf(w, R * (21.0 if kind == "pick" else 26.0)), ah)
	var tw := w - art.x - R * 2.4 if not vertical else w
	var th := 0.0
	for l in _lines:
		th += Kit.wrapped_height(l, tw - R * 2.2) + R * 1.3
	th -= R * 1.3
	var title_h := _title.get_combined_minimum_size().y
	var body_h := maxf(art.y, th) if not vertical else art.y + R * 1.6 + th
	var total := title_h + R * 1.4 + body_h + R * 1.8 + _next.size.y
	var y := maxf(pad.y, (size.y - total) / 2)
	Kit.place(_title, Vector2(pad.x, y), size.x - pad.x * 2)
	y += title_h + R * 1.4
	_art.position = Vector2(x0 if not vertical else (size.x - art.x) / 2, y)
	_art.size = art
	var tx := x0 + art.x + R * 2.4 if not vertical else x0
	var ty := y + (body_h - th) / 2 if not vertical else y + art.y + R * 1.6
	for i in _lines.size():
		var l := _lines[i]
		ty += Kit.place(l, Vector2(tx + R * 2.2, ty), tw - R * 2.2) + R * 1.3
	y += body_h + R * 1.8
	_next.position = Vector2((size.x - _next.size.x) / 2, y)
	queue_redraw()


## 글줄 앞의 번호 동그라미 (1, 2, 3)
func _draw() -> void:
	var R := Kit.R
	for i in _lines.size():
		var l := _lines[i]
		var c := l.position + Vector2(-R * 1.3, R * 0.95)
		draw_circle(c, R * 0.8, Kit.NAVY, true, -1.0, true)
		Kit.text(self, Kit.F_TITLE, R * 0.95, str(i + 1), Rect2(c - Vector2(R, R * 0.75), Vector2(R * 2, R * 1.5)), Kit.CREAM)


func enter() -> void:
	rise_in(_title)
	rise_in(_art, 0.1)
	for i in _lines.size():
		rise_in(_lines[i], 0.2 + i * 0.12)
	rise_in(_next, 0.6)
	later(40.0, _go)


func _process(delta: float) -> void:
	_time += delta
	if kind == "pick":
		_art.t = _time


## 움직이는 그림: 빈칸의 구슬 → 집게가 하나를 집음 → 그 칸에 ○ (3.6초마다 되풀이)
func _paint_pick(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	Kit.rrect(ci, Rect2(r.position + Vector2(0, R * 0.35), r.size), Kit.LINE, R * 0.8)
	Kit.rrect(ci, r, Kit.CREAM, R * 0.8)
	var s := minf(r.size.x, r.size.y) - R * 2.4
	var o := Vector2((r.size.x - s) / 2, (r.size.y - s) / 2)
	Kit.rrect(ci, Rect2(o, Vector2(s, s)), Kit.NAVY, s * 0.02)
	var gap := s * 0.02
	var cs := (s - gap * 2) / 3.0
	var cyc := fmod(ci.t, 3.6)
	var pick := 0
	var claw := clampf((cyc - 1.0) / 0.6, 0.0, 1.0)
	var placed := cyc > 1.8
	var total := 0
	for n in DEMO:
		total += n
	for i in 9:
		var cr := Rect2(o + Vector2((i % 3) * (cs + gap), (i / 3) * (cs + gap)), Vector2(cs, cs))
		ci.draw_rect(cr, Kit.CREAM)
		if DEMO_BOARD[i] == Ttt.KID:
			Kit.mark_x(ci, cr.get_center(), cs)
			continue
		if DEMO_BOARD[i] == Ttt.AI:
			Kit.mark_o(ci, cr.get_center(), cs)
			continue
		if placed and i == pick:
			ci.draw_rect(cr, Kit.PICK)
			Kit.mark_o(ci, cr.get_center(), cs, clampf((cyc - 1.8) / 0.4, 0.0, 1.0))
			continue
		var a := 1.0 if not placed else maxf(0.0, 1.0 - (cyc - 1.8) / 0.4)
		if a <= 0.0:
			continue
		ci.draw_rect(cr, Color(Kit.PICK if i == pick and claw > 0.0 else Kit.TRAY, a))
		var br := cs * 0.075
		var n: int = DEMO[i]
		for k in n:
			var row := k / 3
			var in_row := mini(3, n - row * 3)
			var p := Vector2(cr.get_center().x + (k % 3 - (in_row - 1) / 2.0) * br * 2.4, cr.position.y + cs * 0.2 + row * br * 2.4)
			Kit.bead(ci, p, br, i, a)
		var word := "%d%%" % roundi(n * 100.0 / total)
		Kit.text(ci, Kit.F_LABEL, cs * 0.16, word, Rect2(cr.position.x, cr.end.y - cs * 0.27, cs, cs * 0.22), Color(Kit.INK, a))
	# 집게: 구슬이 가장 많은 칸(왼쪽 위)으로 내려온다
	if claw > 0.0 and not placed:
		var cr := Rect2(o, Vector2(cs, cs))
		var br := cs * 0.075
		var target := Vector2(cr.get_center().x + br * 2.4, cr.position.y + cs * 0.2 + br * 2.4)
		var head := Vector2(target.x, lerpf(o.y - cs * 0.25, target.y - br * 2.1, ease_out(claw)))
		ci.draw_line(Vector2(head.x, o.y - cs * 0.3), head, Kit.NAVY, cs * 0.04, true)
		for side in [-1.0, 1.0]:
			var open := lerpf(br * 1.7, br * 1.05, claw)
			var elbow := head + Vector2(side * open * 1.15, br)
			ci.draw_line(head + Vector2(side * br * 0.7, 0), elbow, Kit.NAVY, cs * 0.03, true)
			ci.draw_line(elbow, head + Vector2(side * open * 0.8, br * 2.5), Kit.NAVY, cs * 0.03, true)
		Kit.rrect(ci, Rect2(head - Vector2(br * 1.3, br * 0.55), Vector2(br * 2.6, br * 1.1)), Kit.NAVY, br * 0.4)
		ci.draw_circle(head, br * 0.32, Kit.RED, true, -1.0, true)


## 처음 첫 상자와 지금 첫 상자 (위아래로)
func _paint_change(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	Kit.rrect(ci, Rect2(r.position + Vector2(0, R * 0.35), r.size), Kit.LINE, R * 0.8)
	Kit.rrect(ci, r, Kit.CREAM, R * 0.8)
	var bs := minf((r.size.x - R * 4.6) / 2, r.size.y - R * 3.0)
	var arrow := R * 2.6
	var x := (r.size.x - bs * 2 - arrow) / 2
	var y := (r.size.y - bs) / 2
	TrainScreen.paint_first_box(ci, Rect2(x, y, bs, bs), START, "처음 (빈 판의 구슬)")
	TrainScreen.paint_first_box(ci, Rect2(x + bs + arrow, y, bs, bs), now_beads, "지금")
	var ac := Vector2(x + bs + arrow / 2, y + bs / 2)
	ci.draw_colored_polygon(PackedVector2Array([ac + Vector2(-R * 0.5, -R * 0.7), ac + Vector2(R * 0.7, 0), ac + Vector2(-R * 0.5, R * 0.7)]), Kit.MUSTARD)
