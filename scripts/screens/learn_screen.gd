class_name LearnScreen
extends ScreenBase
## 배우는 순간. 이번 판에 AI가 연 상자마다 카드 한 장.
## 이기거나 비기면 새 구슬이 위에서 떨어져 담기고, 지면 구슬 하나가 떠올라 사라진다.

signal next

const LINE := {
	"kid": "AI가 졌어요. 이번에 둔 수의 구슬을 하나씩 뺐어요. 다음엔 그 수를 덜 둬요.",
	"ai": "AI가 이겼어요. 이번에 둔 수에 구슬을 3개씩 넣었어요. 그 수가 더 자주 나와요.",
	"draw": "비겼어요. 이번에 둔 수에 구슬을 1개씩 넣었어요.",
}
const SHOW_BEADS := 10
const CHANGE_AT := 0.7
const CARD_STEP := 0.3

var outcome: String
var changes: Array
var resigned: bool
var last: bool

var _title: Label
var _line: Label
var _cards: Array[Drawn] = []
var _next: Button
var _time := 0.0
var _sounded := {}
var _gone := false


func _init(o: String, ch: Array, res: bool, is_last: bool) -> void:
	outcome = o
	changes = ch
	resigned = res
	last = is_last


func build() -> void:
	_title = Kit.label("배우는 순간", Kit.F_TITLE, Kit.R * 2.6, Kit.NAVY, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_title)
	var s: String = ("상자가 비어서 AI가 기권했어요. " if resigned else "") + (LINE[outcome] if not changes.is_empty() else "이번 판은 AI가 상자를 쓰지 않아서 바뀐 구슬이 없어요.")
	_line = Kit.label(s, Kit.F_BODY, Kit.R * 1.4, Kit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	add_child(_line)
	for i in changes.size():
		var d := Drawn.new(_paint_card.bind(i))
		_cards.append(d)
		add_child(d)
	_next = Kit.button("결과 보기" if last else "다음 판", "primary", true)
	_next.pressed.connect(_go)
	add_child(_next)


func _go() -> void:
	if _gone:
		return
	_gone = true
	next.emit()


func relayout() -> void:
	var R := Kit.R
	var w := size.x - pad.x * 2
	var cw := R * 12.5
	var chh := R * 17.5
	var gap := R * 1.2
	var per_row := maxi(1, mini(changes.size(), floori((w + gap) / (cw + gap))))
	var rows := ceili(changes.size() / float(per_row)) if not changes.is_empty() else 0
	var title_h := _title.get_combined_minimum_size().y
	_line.size = Vector2(minf(w, R * 50), 0)
	var line_h := Kit.wrapped_height(_line, _line.size.x)
	var bh := _next.get_combined_minimum_size().y
	var total := title_h + R * 0.8 + line_h + R * 1.6 + rows * chh + maxi(rows - 1, 0) * gap + R * 1.8 + bh
	var y := (size.y - total) / 2
	Kit.place(_title, Vector2(pad.x, y), w)
	y += title_h + R * 0.8
	Kit.place(_line, Vector2((size.x - _line.size.x) / 2, y), _line.size.x)
	y += line_h + R * 1.6
	for i in _cards.size():
		var row := i / per_row
		var in_row := mini(per_row, changes.size() - row * per_row)
		var col := i % per_row
		var rw := in_row * cw + (in_row - 1) * gap
		_cards[i].position = Vector2((size.x - rw) / 2 + col * (cw + gap), y + row * (chh + gap))
		_cards[i].size = Vector2(cw, chh)
	y += rows * chh + maxi(rows - 1, 0) * gap + R * 1.8
	_next.size = _next.get_combined_minimum_size()
	_next.position = Vector2((size.x - _next.size.x) / 2, y)


func enter() -> void:
	rise_in(_title)
	rise_in(_line, 0.1)
	rise_in(_next, 0.3)
	later(9.0, _go)


func _process(delta: float) -> void:
	_time += delta
	for i in _cards.size():
		_cards[i].t = _time
		if not _sounded.has(i) and _time >= CHANGE_AT + i * CARD_STEP:
			_sounded[i] = true
			Sfx.learn()


func _paint_card(ci: Drawn, i: int) -> void:
	var R := Kit.R
	var c: Dictionary = changes[i]
	var t := ci.t
	# 카드가 차례로 올라온다
	var enter_p := ease_out((t - i * 0.12) / 0.4)
	if enter_p <= 0.0:
		return
	var a := enter_p
	var off := Vector2(0, (1.0 - enter_p) * R * 1.5)
	var r := Rect2(off, ci.size)
	Kit.rrect(ci, Rect2(r.position + Vector2(0, R * 0.4), r.size), Color(Kit.LINE, a), R * 0.8)
	Kit.rrect(ci, r, Color(Kit.CREAM, a), R * 0.8)
	var head := Rect2(r.position, Vector2(r.size.x, R * 2.2))
	var hs := Kit.box(Color(Kit.NAVY, a), 0)
	hs.corner_radius_top_left = int(R * 0.8)
	hs.corner_radius_top_right = int(R * 0.8)
	ci.draw_style_box(hs, head)
	Kit.text(ci, Kit.F_LABEL, R * 1.05, "BOX No. %d" % Menace.box_number(c.key), head, Color(Kit.MUSTARD, a))
	var mb := R * 6.0
	Kit.mini_board(ci, Rect2(r.position + Vector2((r.size.x - mb) / 2, R * 3.0), Vector2(mb, mb)), c.board, c.cell)
	Kit.text(ci, Kit.F_BOLD, R * 1.2, Ttt.CELL_NAMES[c.cell], Rect2(r.position + Vector2(0, R * 9.4), Vector2(r.size.x, R * 1.6)), Color(Kit.INK, a))

	# 구슬 줄: 5개씩 두 줄, 10개까지 그린다
	var ct := t - CHANGE_AT - i * CARD_STEP
	var before: int = c.before
	var after: int = c.after
	var br := R * 0.5
	var step := br * 2.3
	var area_top := r.position.y + R * 11.5
	var shown := mini(maxi(before, after), SHOW_BEADS)
	for k in shown:
		var row := k / 5
		var cnt := mini(5, shown - row * 5)
		var pos := Vector2(r.position.x + r.size.x / 2 + (k % 5 - (cnt - 1) / 2.0) * step, area_top + row * step)
		if k < before and k < after:
			Kit.bead(ci, pos, br, c.cell, a)
		elif k >= before:
			# 새로 넣는 구슬: 차례로 위에서 떨어진다
			var p := (ct - (k - before) * 0.14) / 0.5
			if p > 0.0:
				var y := lerpf(pos.y - R * 4.0, pos.y, bounce(p))
				Kit.bead(ci, Vector2(pos.x, y), br, c.cell, a * clampf(p * 3.0, 0.0, 1.0))
		else:
			# 빼는 구슬: 떠오르며 사라진다
			var p := clampf(ct / 0.6, 0.0, 1.0)
			Kit.bead(ci, pos - Vector2(0, R * 2.0 * ease_out(p)), br, c.cell, a * (1.0 - p))
	if before > SHOW_BEADS or after > SHOW_BEADS:
		Kit.text(ci, Kit.F_LABEL, R * 0.8, "구슬은 10개까지만 그려요", Rect2(r.position + Vector2(0, R * 13.6), Vector2(r.size.x, R)), Color(Kit.INK_SOFT, a))

	# 숫자: 바뀌기 전에는 ?, 바뀌면 새 수
	var done := ct >= 0.0
	var num_rect := Rect2(r.position + Vector2(0, r.size.y - R * 2.6), Vector2(r.size.x, R * 2.0))
	var left := str(before)
	var right := str(after) if done else "?"
	var col := Kit.INK_SOFT
	if done:
		col = Kit.TEAL if after > before else (Kit.RED_INK if after < before else Kit.INK)
	var fs := R * 2.0
	var lw := Kit.F_TITLE.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
	var rw := Kit.F_TITLE.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
	var arrow := R * 2.2
	var x0 := r.position.x + (r.size.x - lw - arrow - rw) / 2
	Kit.text(ci, Kit.F_TITLE, fs, left, Rect2(x0, num_rect.position.y, lw, num_rect.size.y), Color(Kit.INK, a), HORIZONTAL_ALIGNMENT_LEFT)
	var ac := Vector2(x0 + lw + arrow / 2, num_rect.get_center().y)
	ci.draw_colored_polygon(PackedVector2Array([ac + Vector2(-R * 0.3, -R * 0.4), ac + Vector2(R * 0.4, 0), ac + Vector2(-R * 0.3, R * 0.4)]), Color(Kit.MUSTARD, a))
	var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - ct / 0.3) if done else 1.0
	Kit.text(ci, Kit.F_TITLE, fs * pop, right, Rect2(x0 + lw + arrow, num_rect.position.y, rw * pop + R, num_rect.size.y), Color(col, a), HORIZONTAL_ALIGNMENT_LEFT)
