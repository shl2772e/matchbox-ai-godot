class_name TeachPanel
extends Control
## 내 손으로 상과 벌 주기. 이번 판에 AI가 연 상자가 첫 수부터 차례로 줄지어 서고,
## 학생이 상자를 누르면(또는 구슬 접시에서 끌어다 놓으면) 그 상자의 구슬이 바뀐다.
##   AI가 이김: 접시의 구슬 3개가 상자로 들어간다 (상)
##   비김: 1개가 들어간다 (작은 상)
##   AI가 짐: 상자의 구슬 1개가 접시로 나온다 (벌)
## AUTO_S 동안 손대지 않으면 남은 상자는 저절로 끝난다 (줄이 밀리지 않게).
## 실제 두뇌는 여기서 바꾸지 않는다. changes(Menace.learn이 돌려준 before/after)를 보여 줄 뿐이다.

signal finished(manual: int, total: int)

const AUTO_S := 6.0
const AUTO_STEP := 0.55
const SHOW_BEADS := 10
## 구슬 하나가 접시와 상자 사이를 나는 시간, 구슬 사이 간격
const FLY_S := 0.45
const FLY_GAP := 0.16

var changes: Array
var outcome: String

var _time := 0.0
var _idle := 0.0
## 상자마다 바뀌기 시작한 시각 (-1이면 아직)
var _applied: Array[float] = []
var _manual := 0
var _done := false
var _drag := false
var _drag_pos := Vector2.ZERO
var _press_card := -1


func _init(ch: Array, o: String) -> void:
	changes = ch
	outcome = o
	for c in changes:
		_applied.append(-1.0)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _reward() -> bool:
	return outcome != "kid"


func _card_size() -> Vector2:
	var gap := Kit.R * 0.9
	var n := maxi(changes.size(), 1)
	return Vector2(minf(Kit.R * 10.5, (size.x - gap * (n - 1)) / n), Kit.R * 15.0)


func _card_rect(i: int) -> Rect2:
	var cs := _card_size()
	var gap := Kit.R * 0.9
	var n := changes.size()
	var total := n * cs.x + (n - 1) * gap
	return Rect2(Vector2((size.x - total) / 2 + i * (cs.x + gap), Kit.R * 2.0), cs)


## 구슬 접시 (상으로 줄 구슬이 놓여 있거나, 빼낸 구슬을 놓는 곳)
func _tray_rect() -> Rect2:
	var w := minf(size.x, Kit.R * 22)
	return Rect2(Vector2((size.x - w) / 2, Kit.R * 2.0 + _card_size().y + Kit.R * 1.0), Vector2(w, Kit.R * 3.6))


func _card_at(p: Vector2) -> int:
	for i in changes.size():
		if _card_rect(i).grow(Kit.R * 0.3).has_point(p):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_idle = 0.0
		if event.pressed:
			_press_card = _card_at(event.position)
			if _press_card < 0 and _reward() and _tray_rect().has_point(event.position):
				_drag = true
				_drag_pos = event.position
		else:
			var over := _card_at(event.position)
			if _drag:
				_drag = false
				if over >= 0:
					_apply(over, true)
			elif over >= 0 and over == _press_card:
				_apply(over, true)
			_press_card = -1
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _drag:
		_drag_pos = event.position
		_idle = 0.0
		queue_redraw()


func _apply(i: int, by_hand: bool) -> void:
	if _applied[i] >= 0.0:
		return
	_applied[i] = _time
	if by_hand:
		_manual += 1
	var c: Dictionary = changes[i]
	var n: int = absi(c.after - c.before)
	for k in maxi(n, 1):
		Sfx.clink(k * FLY_GAP + (FLY_S if _reward() else 0.0))


func _process(delta: float) -> void:
	_time += delta
	_idle += delta
	queue_redraw()
	if _done:
		return
	if changes.is_empty():
		_done = true
		finished.emit(0, 0)
		return
	var left := _applied.find(-1.0)
	if left >= 0:
		if _idle >= AUTO_S:
			_apply(left, false)
			_idle = AUTO_S - AUTO_STEP
		return
	# 모두 끝났고 마지막 구슬까지 자리를 잡았으면 알린다
	var last: float = _applied.max()
	if _time - last > FLY_S + FLY_GAP * 3 + 0.5:
		_done = true
		finished.emit(_manual, changes.size())


## 상자 i의 k번째 구슬 자리 (5개씩 두 줄)
func _bead_pos(i: int, k: int, shown: int) -> Vector2:
	var r := _card_rect(i)
	var br := Kit.R * 0.45
	var step := br * 2.3
	var row := k / 5
	var cnt := mini(5, shown - row * 5)
	return Vector2(r.position.x + r.size.x / 2 + (k % 5 - (cnt - 1) / 2.0) * step, r.position.y + Kit.R * 10.3 + row * step)


## 접시 위 n번째 구슬 자리
func _tray_pos(n: int) -> Vector2:
	var tr := _tray_rect()
	var step := Kit.R * 1.05
	return Vector2(tr.position.x + tr.size.x - Kit.R * 1.6 - (n % 12) * step, tr.get_center().y + (Kit.R * 0.5 if n >= 12 else 0.0))


func _draw() -> void:
	var R := Kit.R
	Kit.text(self, Kit.F_LABEL, R * 1.15, "이번 판에 AI가 연 상자 (첫 수부터 차례로)", Rect2(0, 0, size.x, R * 1.6), Kit.INK_SOFT)
	# 접시
	var tr := _tray_rect()
	Kit.rrect(self, Rect2(tr.position + Vector2(0, R * 0.25), tr.size), Kit.LINE, R * 0.7)
	Kit.rrect(self, tr, Kit.KRAFT, R * 0.7)
	Kit.rrect(self, tr.grow(-R * 0.35), Kit.TRAY, R * 0.5)
	var label := "상으로 줄 구슬" if _reward() else "빼낸 구슬"
	Kit.text(self, Kit.F_LABEL, R * 1.1, label, Rect2(tr.position.x + R * 1.0, tr.position.y, R * 8, tr.size.y), Kit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	var slot := 0
	var flying: Array = []  # [pos, cell, alpha]
	for i in changes.size():
		var c: Dictionary = changes[i]
		var n: int = absi(c.after - c.before)
		var ct: float = _time - _applied[i] if _applied[i] >= 0.0 else -1.0
		var shown := mini(maxi(c.before, c.after), SHOW_BEADS)
		_paint_card(i, ct, shown)
		for k in n:
			var tp := _tray_pos(slot)
			slot += 1
			if _reward():
				# 접시에 있다가 상자로 날아간다
				var dst_k: int = c.before + k
				if dst_k >= SHOW_BEADS:
					if ct < 0.0:
						Kit.bead(self, tp, R * 0.45, c.cell)
					continue
				var p := (ct - k * FLY_GAP) / FLY_S if ct >= 0.0 else -1.0
				if p < 0.0:
					Kit.bead(self, tp, R * 0.45, c.cell)
				elif p < 1.0:
					flying.append([_arc(tp, _bead_pos(i, dst_k, shown), p), c.cell])
			else:
				# 상자에서 접시로 나온다 (맨 끝 구슬부터)
				var src_k: int = c.before - 1 - k
				if ct < 0.0 or src_k >= SHOW_BEADS:
					continue
				var p := (ct - k * FLY_GAP) / FLY_S
				if p >= 1.0:
					Kit.bead(self, tp, R * 0.45, c.cell)
				elif p >= 0.0:
					flying.append([_arc(_bead_pos(i, src_k, shown), tp, p), c.cell])
	for f in flying:
		Kit.bead(self, f[0], R * 0.5, f[1])
	if _drag:
		Kit.bead(self, _drag_pos, R * 0.6, changes[0].cell)


static func _arc(from: Vector2, to: Vector2, p: float) -> Vector2:
	var q := ScreenBase.ease_out(p)
	var mid := (from + to) / 2 + Vector2(0, -from.distance_to(to) * 0.3)
	return from.lerp(mid, q).lerp(mid.lerp(to, q), q)


func _paint_card(i: int, ct: float, shown: int) -> void:
	var R := Kit.R
	var c: Dictionary = changes[i]
	var r := _card_rect(i)
	var todo := ct < 0.0
	# 아직 안 한 상자는 숨 쉬는 테두리와 "눌러요" 표로 부른다
	Kit.rrect(self, Rect2(r.position + Vector2(0, R * 0.4), r.size), Kit.LINE, R * 0.8)
	Kit.rrect(self, r, Kit.CREAM, R * 0.8)
	if todo:
		var pulse := 0.5 + 0.5 * sin(_time * TAU / 1.4 - i * 0.6)
		Kit.rrect(self, r.grow(R * 0.12), Color.TRANSPARENT, R * 0.9, R * 0.22, Color(Kit.MUSTARD, 0.45 + 0.5 * pulse))
	var head := Rect2(r.position, Vector2(r.size.x, R * 2.0))
	var hs := Kit.box(Kit.NAVY, 0)
	hs.corner_radius_top_left = int(R * 0.8)
	hs.corner_radius_top_right = int(R * 0.8)
	draw_style_box(hs, head)
	Kit.text(self, Kit.F_LABEL, minf(R * 1.0, r.size.x * 0.095), "%d번째 수 · BOX No. %d" % [i + 1, Menace.box_number(c.key)], head, Kit.MUSTARD)
	var mb := minf(R * 5.2, r.size.x - R * 2.0)
	Kit.mini_board(self, Rect2(r.position + Vector2((r.size.x - mb) / 2, R * 2.6), Vector2(mb, mb)), c.board, c.cell)
	Kit.text(self, Kit.F_BOLD, R * 1.1, Ttt.CELL_NAMES[c.cell], Rect2(r.position + Vector2(0, R * 8.0), Vector2(r.size.x, R * 1.5)), Kit.INK)
	# 상자 속 구슬 (그 칸의 구슬만, 10개까지)
	var before: int = c.before
	var after: int = c.after
	for k in shown:
		var pos := _bead_pos(i, k, shown)
		if k < mini(before, after):
			Kit.bead(self, pos, R * 0.45, c.cell)
		elif k >= before:
			# 들어온 구슬: 날아와 닿은 뒤에 보인다
			if ct >= 0.0 and (ct - (k - before) * FLY_GAP) / FLY_S >= 1.0:
				Kit.bead(self, pos, R * 0.45, c.cell)
		else:
			# 나갈 구슬: 떠나기 전까지 보인다
			if ct < 0.0 or (ct - (before - 1 - k) * FLY_GAP) / FLY_S < 0.0:
				Kit.bead(self, pos, R * 0.45, c.cell)
	# 아래: 할 일 또는 바뀐 수
	var foot := Rect2(r.position + Vector2(0, r.size.y - R * 2.6), Vector2(r.size.x, R * 2.2))
	var n: int = absi(after - before)
	var settle := FLY_S + FLY_GAP * maxi(n - 1, 0)
	if todo:
		var ask := "눌러서 %d개 넣기" % n if _reward() else "눌러서 %d개 빼기" % n
		if n == 0:
			ask = "눌러서 확인하기"
		var tag := foot.grow_individual(-R * 0.7, -R * 0.25, -R * 0.7, -R * 0.25)
		Kit.rrect(self, tag, Kit.RED, R * 0.5)
		Kit.text(self, Kit.F_LABEL, R * 1.0, ask, tag, Kit.CREAM)
	else:
		var done := ct >= settle
		var left := "%d개" % before
		var right := "%d개" % after if done else "..."
		var col := Kit.INK_SOFT
		if done:
			col = Kit.TEAL if after > before else (Kit.RED_INK if after < before else Kit.INK)
		var fs := R * 1.5
		var lw := Kit.F_TITLE.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
		var rw := Kit.F_TITLE.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
		var arrow := R * 1.8
		var x0 := r.position.x + (r.size.x - lw - arrow - rw) / 2
		Kit.text(self, Kit.F_TITLE, fs, left, Rect2(x0, foot.position.y, lw, foot.size.y), Kit.INK, HORIZONTAL_ALIGNMENT_LEFT)
		var ac := Vector2(x0 + lw + arrow / 2, foot.get_center().y)
		draw_colored_polygon(PackedVector2Array([ac + Vector2(-R * 0.3, -R * 0.4), ac + Vector2(R * 0.4, 0), ac + Vector2(-R * 0.3, R * 0.4)]), Kit.MUSTARD)
		Kit.text(self, Kit.F_TITLE, fs, right, Rect2(x0 + lw + arrow, foot.position.y, rw + R, foot.size.y), col, HORIZONTAL_ALIGNMENT_LEFT)
