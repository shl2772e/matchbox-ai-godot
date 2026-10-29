class_name BoardView
extends Control
## 틱택토 판. 빈칸을 누르면 cell_tapped. 새로 둔 수는 획을 긋듯 그려지고, 이긴 줄에는 선이 그어진다.

signal cell_tapped(cell: int)

var board: Array = Ttt.empty_board()
var locked := true
## AI가 고른 칸 (구슬이 날아오는 동안 점선 ○)
var chosen := -1:
	set(v):
		chosen = v
		queue_redraw()
var _drawn := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
var _line: Array = []
var _line_t := 0.0
var _press := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


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
