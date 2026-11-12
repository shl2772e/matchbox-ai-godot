class_name ThoughtBubble
extends Control
## 생각 풍선: 구름 모양 테두리 + 꼬리 동그라미 셋. 성냥갑 서랍(MatchboxView)을 이 안에 놓아
## "여기는 AI 머릿속"임을 보여 준다. tail_to는 풍선 주인(성냥갑 기계)의 머리 자리 (이 노드 좌표).

var tail_to := Vector2.ZERO:
	set(v):
		tail_to = v
		queue_redraw()


## 꼬리의 큰 동그라미가 놓일 가로 자리 (이 노드 좌표). 0보다 작으면 풍선 가운데
var tail_from_x := -1.0:
	set(v):
		tail_from_x = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 풍선 몸통 (꼬리 빼고). 서랍은 이 안쪽에 놓는다
func body() -> Rect2:
	return Rect2(Vector2.ZERO, size)


func _draw() -> void:
	var R := Kit.R
	var r := body()
	var bump := R * 1.4
	var border := R * 0.14
	var inner := r.grow(-bump * 0.55)
	# 테두리 선 → 속 크림 순으로 겹쳐 그려 구름 윤곽을 만든다
	var centers := _bumps(inner, bump * 1.6)
	for c in centers:
		draw_circle(c + Vector2(0, R * 0.35), bump, Color(Kit.INK, 0.08), true, -1.0, true)
	Kit.rrect(self, Rect2(inner.position + Vector2(0, R * 0.35), inner.size), Color(Kit.INK, 0.08), R * 2)
	for c in centers:
		draw_circle(c, bump, Kit.LINE, true, -1.0, true)
	Kit.rrect(self, inner, Kit.LINE, R * 2)
	for c in centers:
		draw_circle(c, bump - border, Kit.CREAM, true, -1.0, true)
	Kit.rrect(self, inner.grow(-border), Kit.CREAM, R * 2)
	# 꼬리: 풍선 아래(위) 가운데 빈 공간에 큰 동그라미, 주인 쪽으로 중간·작은 동그라미가 이어진다 (테두리와 안 겹치게)
	var sizes: Array[float] = [R * 1.3, R * 0.9, R * 0.5]
	var below := tail_to.y > inner.end.y
	var gap: float = bump + sizes[0] + R * 0.3
	var from := Vector2(tail_from_x if tail_from_x >= 0.0 else inner.get_center().x, inner.end.y + gap if below else inner.position.y - gap)
	for k in 3:
		var p := from.lerp(tail_to, [0.0, 0.5, 0.95][k])
		var rad: float = sizes[k]
		draw_circle(p + Vector2(0, R * 0.25), rad, Color(Kit.INK, 0.08), true, -1.0, true)
		draw_circle(p, rad, Kit.LINE, true, -1.0, true)
		draw_circle(p, rad - border, Kit.CREAM, true, -1.0, true)


## 테두리를 따라 고르게 놓은 혹 중심점들
static func _bumps(rect: Rect2, step: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var n := maxi(1, roundi(a.distance_to(b) / step))
		for k in n:
			out.append(a.lerp(b, float(k) / n))
	return out
