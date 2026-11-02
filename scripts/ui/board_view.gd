class_name BoardView
extends Control
## 틱택토 판. 빈칸을 누르면 cell_tapped. 새로 둔 수는 획을 긋듯 그려지고, 이긴 줄에는 선이 그어진다.
## active(내 차례)면 테두리가 숨 쉬듯 밝아지고, 잠시 뒤 손가락이 빈칸을 톡 두드리는 안내가 나온다.

signal cell_tapped(cell: int)

## 손가락 안내가 나오기까지 기다리는 시간 (빨리 두는 학생은 안 본다)
const HINT_DELAY := 1.0
const HINT_CYCLE := 2.0
## 안내 손가락이 가리킬 빈칸 고르는 순서 (가운데부터)
const HINT_ORDER := [4, 1, 3, 5, 7, 0, 2, 6, 8]

var board: Array = Ttt.empty_board()
var locked := true
## AI가 고른 칸 (구슬이 날아오는 동안 점선 ○)
var chosen := -1:
	set(v):
		chosen = v
		queue_redraw()
## 내 차례 (무대 조명 + 손가락 안내)
var active := false:
	set(v):
		if active == v:
			return
		active = v
		_active_t = 0.0
		set_process(active)
		queue_redraw()
var _active_t := 0.0
var _drawn := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
var _line: Array = []
var _line_t := 0.0
var _press := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func _process(delta: float) -> void:
	_active_t += delta
	queue_redraw()


func reset() -> void:
	board = Ttt.empty_board()
	_line = []
	_line_t = 0.0
	chosen = -1
	queue_redraw()


## 새 수를 놓고 그리는 애니메이션
func put(cell: int, new_board: Array) -> void:
	board = new_board
	_drawn[cell] = 0.0
	create_tween().tween_method(_set_drawn.bind(cell), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_drawn(v: float, cell: int) -> void:
	_drawn[cell] = v
	queue_redraw()


func show_line(line: Array) -> void:
	_line = line
	if line.is_empty():
		return
	create_tween().tween_method(_set_line_t, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_line_t(v: float) -> void:
	_line_t = v
	queue_redraw()


func _pad() -> float:
	return size.x * 0.0375


func _gap() -> float:
	return size.x * 0.019


func cell_rect(i: int) -> Rect2:
	var pad := _pad()
	var gap := _gap()
	var cs := (size.x - pad * 2 - gap * 2) / 3.0
	return Rect2(Vector2(pad + (i % 3) * (cs + gap), pad + (i / 3) * (cs + gap)), Vector2(cs, cs))


func cell_center_global(i: int) -> Vector2:
	return get_global_transform() * cell_rect(i).get_center()


func cell_size_global() -> float:
	return cell_rect(0).size.x * get_global_transform().get_scale().x


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = -1
			for i in 9:
				if cell_rect(i).has_point(event.position) and board[i] == 0 and not locked:
					_press = i
			queue_redraw()
			if _press >= 0:
				var c := _press
				_press = -1
				cell_tapped.emit(c)
		accept_event()


func _draw() -> void:
	var s := size.x
	Kit.rrect(self, Rect2(Vector2(0, s * 0.019), Vector2(s, s)), Kit.LINE, s * 0.033)
	Kit.rrect(self, Rect2(Vector2.ZERO, Vector2(s, s)), Kit.CREAM, s * 0.033)
	if active:
		# 숨 쉬듯 밝아지는 테두리 (1.6초)
		var glow := 0.4 + 0.45 * (0.5 + 0.5 * sin(_active_t * TAU / 1.6))
		Kit.rrect(self, Rect2(Vector2.ZERO, Vector2(s, s)).grow(s * 0.006), Color.TRANSPARENT, s * 0.04, s * 0.013, Color(Kit.MUSTARD, glow))
	var pad := _pad()
	Kit.rrect(self, Rect2(Vector2(pad, pad), Vector2(s - pad * 2, s - pad * 2)), Kit.NAVY, s * 0.015)
	for i in 9:
		var r := cell_rect(i)
		var bg := Kit.CREAM
		if _line.has(i):
			bg = Kit.CREAM.lerp(Kit.WIN_CELL, _line_t)
		elif i == chosen and board[i] == 0:
			bg = Kit.PICK
		elif i == _press:
			bg = Kit.TRAY
		draw_rect(r, bg)
		if i == chosen and board[i] == 0:
			var w := s * 0.009
			draw_rect(r.grow(-w / 2), Kit.MUSTARD, false, w)
			Kit.mark_o(self, r.get_center(), r.size.x, 1.0, true, 0.75)
		if board[i] == Ttt.AI:
			Kit.mark_o(self, r.get_center(), r.size.x, _drawn[i])
		elif board[i] == Ttt.KID:
			Kit.mark_x(self, r.get_center(), r.size.x, _drawn[i])
	if not _line.is_empty() and _line_t > 0.0:
		var a := cell_rect(_line[0]).get_center()
		var b := cell_rect(_line[2]).get_center()
		var ext := (b - a).normalized() * cell_rect(0).size.x * 0.32
		a -= ext
		b += ext
		var col := Color(Kit.RED if board[_line[0]] == Ttt.AI else Kit.NAVY, 0.55)
		draw_line(a, a.lerp(b, _line_t), col, s * 0.028, true)
	if active and _active_t > HINT_DELAY:
		var hint := _hint_cell()
		if hint >= 0:
			_draw_hand(cell_rect(hint).get_center(), cell_rect(0).size.x, fmod(_active_t - HINT_DELAY, HINT_CYCLE))


func _hint_cell() -> int:
	for i in HINT_ORDER:
		if board[i] == 0:
			return i
	return -1


## 손가락이 칸을 톡 두드린다. t는 한 주기(초) 안의 시간: 내려감 → 닿음(물결) → 올라감 → 쉼
func _draw_hand(c: Vector2, cs: float, t: float) -> void:
	var down := 0.0
	if t < 0.35:
		down = pow(t / 0.35, 2)
	elif t < 0.85:
		down = 1.0
	elif t < 1.2:
		down = 1.0 - (t - 0.85) / 0.35
	if t >= 0.35 and t < 0.95:
		var q := (t - 0.35) / 0.6
		draw_arc(c, cs * (0.1 + 0.3 * q), 0, TAU, 40, Color(Kit.MUSTARD, 1.0 - q), cs * 0.025, true)
	var tip := c + Vector2(cs * 0.04, cs * 0.06) - Vector2(0, (1.0 - down) * cs * 0.28)
	var u := cs * 0.11
	draw_set_transform(tip, deg_to_rad(-18.0), Vector2.ONE)
	# 집게손가락 (끝이 칸 가운데) + 쥔 손
	_capsule(Vector2.ZERO, Vector2(0, 3.2 * u), 1.3 * u, Kit.INK)
	_capsule(Vector2.ZERO, Vector2(0, 3.2 * u), 1.0 * u, Kit.CREAM)
	var palm := Rect2(Vector2(-0.65 * u, 2.4 * u), Vector2(3.6 * u, 3.1 * u))
	Kit.rrect(self, palm, Kit.INK, 1.1 * u)
	Kit.rrect(self, palm.grow(-0.15 * u), Kit.CREAM, 1.0 * u)
	for i in 3:
		var x := (0.95 + i * 0.85) * u
		draw_line(Vector2(x, 2.55 * u), Vector2(x, 3.4 * u), Kit.INK, 0.15 * u, true)
	draw_set_transform(Vector2.ZERO)


func _capsule(a: Vector2, b: Vector2, w: float, color: Color) -> void:
	draw_line(a, b, color, w, true)
	draw_circle(a, w / 2, color, true, -1.0, true)
	draw_circle(b, w / 2, color, true, -1.0, true)
