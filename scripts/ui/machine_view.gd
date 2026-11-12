class_name MachineView
extends Control
## 성냥갑 기계 캐릭터 ("AI"). 생각 풍선의 주인이다.
## 작은 성냥갑 + 맞물린 톱니바퀴 둘. working이면 톱니가 돌고 서랍 속 구슬이 흔들린다
## (AI가 상자를 열어 구슬을 꺼내는 동안만). 속도는 천천히 올랐다가 천천히 멈춘다.
##
## mood(표정): 상표 자리에 눈과 입을 그린다.
##   "calm" 보통 / "lost" 헤맴(눈이 따로 놀고 물음표) / "think" 궁리(서랍 쪽을 본다)
##   "happy" 기쁨 / "sad" 시무룩 / "resign" 기권(흰 깃발)

var working := false:
	set(v):
		working = v
		set_process(true)

var mood := "calm":
	set(v):
		mood = v
		_mood_t = 0.0
		set_process(true)
		queue_redraw()

var _angle := 0.0
var _speed := 0.0
var _mood_t := 0.0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	_mood_t += delta
	var target := 1.0 if working else 0.0
	_speed = move_toward(_speed, target, delta * (3.0 if working else 1.5))
	_angle += delta * TAU * 0.3 * _speed
	queue_redraw()


## 풍선 꼬리가 닿을 자리 (이 노드 좌표): 톱니바퀴 오른쪽 옆
func head() -> Vector2:
	return Vector2(Kit.R * 10.4, Kit.R * 2.5)


func _draw() -> void:
	var R := Kit.R
	var box := Rect2(0, R * 0.6, R * 5.9, R * 4.0)
	# 기쁘면 살짝 통통 뛰고, 시무룩하면 조금 내려앉는다
	var hop := 0.0
	if mood == "happy":
		hop = -absf(sin(_mood_t * TAU * 1.4)) * R * 0.25 * maxf(0.0, 1.0 - _mood_t / 1.6)
	elif mood == "sad" or mood == "resign":
		hop = R * 0.12 * minf(_mood_t / 0.4, 1.0)
	box.position.y += hop
	Kit.matchbox_art(self, box, 1.0, _angle / TAU)
	_face(box)
	# 톱니바퀴 둘 (큰 것 8개 이, 작은 것 6개 이, 서로 반대로 돈다)
	var big := Vector2(R * 7.0, R * 1.7)
	var small := Vector2(R * 8.75, R * 3.0)
	_gear(big, R * 1.25, 8, _angle, Kit.NAVY)
	_gear(small, R * 0.85, 6, -_angle * 8.0 / 6.0 + PI / 6, Kit.RED)
	Kit.text(self, Kit.F_TITLE, R * 1.2, "AI", Rect2(R * 5.9, R * 3.6, R * 2.4, R * 1.2), Kit.INK)
	if mood == "resign":
		# 흰 깃발
		var pole := Vector2(R * 5.6, R * 0.9 + hop)
		draw_line(pole, pole + Vector2(0, -R * 1.6), Kit.INK, R * 0.1, true)
		var wave := sin(_time * TAU * 0.8) * R * 0.08
		draw_colored_polygon(PackedVector2Array([pole + Vector2(0, -R * 1.6), pole + Vector2(R * 1.1, -R * 1.35 + wave), pole + Vector2(0, -R * 0.95)]), Kit.CREAM)
		draw_polyline(PackedVector2Array([pole + Vector2(0, -R * 1.6), pole + Vector2(R * 1.1, -R * 1.35 + wave), pole + Vector2(0, -R * 0.95)]), Kit.INK, R * 0.06, true)
	elif mood == "lost":
		var q := 0.5 + 0.5 * sin(_time * TAU * 0.6)
		Kit.text(self, Kit.F_TITLE, R * 1.3, "?", Rect2(R * 4.6, -R * 0.3 - q * R * 0.15, R * 1.4, R * 1.4), Kit.RED_INK)


## 상표의 글줄 자리(성냥갑 그림의 88~144, 70~116)를 덮고 눈과 입을 그린다
func _face(box: Rect2) -> void:
	var k := minf(box.size.x / 220.0, box.size.y / 150.0)
	var o := box.position + (box.size - Vector2(220, 150) * k) / 2
	draw_rect(Rect2(o + Vector2(84, 68) * k, Vector2(66, 54) * k), Kit.NAVY)
	var le := o + Vector2(100, 86) * k
	var re := o + Vector2(132, 86) * k
	var er := 7.5 * k
	var mouth := o + Vector2(116, 108) * k
	var blink := fmod(_time, 3.6) > 3.45
	match mood:
		"happy":
			# 웃는 눈 (위로 볼록한 선) + 웃는 입
			for e in [le, re]:
				draw_arc(e + Vector2(0, er * 0.5), er, PI * 1.15, PI * 1.85, 12, Kit.CREAM, 3.0 * k, true)
			draw_arc(mouth - Vector2(0, 6 * k), 9 * k, PI * 0.15, PI * 0.85, 12, Kit.CREAM, 3.0 * k, true)
		"sad", "resign":
			for e in [le, re]:
				draw_circle(e, er, Kit.CREAM, true, -1.0, true)
				draw_circle(e + Vector2(0, er * 0.35), er * 0.45, Kit.INK, true, -1.0, true)
			# 처진 눈썹
			draw_line(le + Vector2(-er, -er * 1.1), le + Vector2(er, -er * 1.7), Kit.CREAM, 2.5 * k, true)
			draw_line(re + Vector2(er, -er * 1.1), re + Vector2(-er, -er * 1.7), Kit.CREAM, 2.5 * k, true)
			draw_arc(mouth + Vector2(0, 7 * k), 8 * k, PI * 1.2, PI * 1.8, 12, Kit.CREAM, 3.0 * k, true)
		_:
			var look := Vector2.ZERO
			if mood == "think" or working:
				look = Vector2(er * 0.4, er * 0.15)
			for i in 2:
				var e: Vector2 = [le, re][i]
				if blink:
					draw_line(e - Vector2(er, 0), e + Vector2(er, 0), Kit.CREAM, 3.0 * k, true)
					continue
				draw_circle(e, er, Kit.CREAM, true, -1.0, true)
				var p := look
				if mood == "lost":
					# 두 눈이 따로 돈다
					p = Vector2.from_angle(_time * 2.2 * (1.0 if i == 0 else -1.3) + i * 2.0) * er * 0.4
				draw_circle(e + p, er * 0.45, Kit.INK, true, -1.0, true)
			if mood == "lost":
				draw_arc(mouth, 4 * k, 0, TAU, 12, Kit.CREAM, 2.5 * k, true)
			else:
				draw_line(mouth + Vector2(-7 * k, 0), mouth + Vector2(7 * k, 0), Kit.CREAM, 3.0 * k, true)


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
