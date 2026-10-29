class_name Drawn
extends Control
## 그리는 함수(painter)를 받아 그리는 칸. t는 애니메이션 시간(초)이고 바뀌면 다시 그린다.

var painter: Callable
var t := 0.0:
	set(v):
		t = v
		queue_redraw()


func _init(p: Callable = Callable()) -> void:
	painter = p
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
