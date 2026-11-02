class_name MachineView
extends Control
## 성냥갑 기계 캐릭터 ("AI"). 생각 풍선의 주인이다.
## 작은 성냥갑 + 맞물린 톱니바퀴 둘. working이면 톱니가 돌고 서랍 속 구슬이 흔들린다
## (AI가 상자를 열어 구슬을 꺼내는 동안만). 속도는 천천히 올랐다가 천천히 멈춘다.

var working := false:
	set(v):
		working = v
		set_process(true)

var _angle := 0.0
var _speed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var target := 1.0 if working else 0.0
	_speed = move_toward(_speed, target, delta * (3.0 if working else 1.5))
	if _speed <= 0.0:
		set_process(false)
		queue_redraw()
		return
	_angle += delta * TAU * 0.3 * _speed
	queue_redraw()


## 풍선 꼬리가 닿을 자리 (이 노드 좌표): 톱니바퀴 오른쪽 옆
func head() -> Vector2:
	return Vector2(Kit.R * 10.4, Kit.R * 2.5)


func _draw() -> void:
	var R := Kit.R
	Kit.matchbox_art(self, Rect2(0, R * 0.6, R * 5.9, R * 4.0), 1.0, _angle / TAU)
	# 톱니바퀴 둘 (큰 것 8개 이, 작은 것 6개 이, 서로 반대로 돈다)
	var big := Vector2(R * 7.0, R * 1.7)
	var small := Vector2(R * 8.75, R * 3.0)
	_gear(big, R * 1.25, 8, _angle, Kit.NAVY)
	_gear(small, R * 0.85, 6, -_angle * 8.0 / 6.0 + PI / 6, Kit.RED)
	Kit.text(self, Kit.F_TITLE, R * 1.2, "AI", Rect2(R * 5.9, R * 3.6, R * 2.4, R * 1.2), Kit.INK)


func _gear(c: Vector2, r: float, teeth: int, angle: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var n := teeth * 4
	for i in n:
		var a := angle + TAU * i / n
		# 이 하나 = 바깥 두 점 + 안쪽 두 점
		var rr := r if (i % 4) < 2 else r * 0.78
		pts.append(c + Vector2.from_angle(a) * rr)
	draw_colored_polygon(pts, color)
	draw_circle(c, r * 0.55, Kit.CREAM, true, -1.0, true)
	draw_circle(c, r * 0.18, color, true, -1.0, true)
	# 바퀴살 셋
	for i in 3:
		var a := angle + TAU * i / 3
		draw_line(c + Vector2.from_angle(a) * r * 0.2, c + Vector2.from_angle(a) * r * 0.5, color, r * 0.14, true)
