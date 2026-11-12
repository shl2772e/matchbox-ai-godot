class_name MatchboxView
extends Control
## 성냥갑: 뚜껑 상표(상자 번호 + 판 모양) + 판과 같은 3×3 서랍.
## open_t(0~1)에 따라 구슬 서랍이 뚜껑 밑에서 미끄러져 나온다. 고른 칸의 구슬은 살짝 떠오른다(pick_t).

const MAX_BEADS := 8

var shape: Array = Ttt.empty_board()
var beads: Array = []
var box_no := 0
var title := "지금 판 모양의 성냥갑"
var percent := false
var wait_text := "내 차례예요. 빈칸을 눌러 ×를 둬요."
var picked := -1
## 고른 구슬이 서랍을 떠났는지 (날아가는 구슬은 놀이 화면이 그린다)
var bead_out := false

## 맞혀 보기: pickable이면 빈칸을 눌러 "어디가 나올까"를 고를 수 있다. guess는 고른 칸
signal slot_tapped(cell: int)
var pickable := false:
	set(v):
		pickable = v
		mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE
		set_process(v)
		queue_redraw()
var guess := -1:
	set(v):
		guess = v
		queue_redraw()
var _pick_time := 0.0

var open_t := 0.0:
	set(v):
		open_t = v
		queue_redraw()
var pick_t := 0.0:
	set(v):
		pick_t = v
		queue_redraw()


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _process(delta: float) -> void:
	_pick_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if pickable and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for i in 9:
			if shape[i] == 0 and _slot_rect(i).has_point(event.position):
				slot_tapped.emit(i)
				break
		accept_event()


func show_box(board_shape: Array, box_beads: Array, number: int) -> void:
	shape = board_shape.duplicate()
	beads = box_beads.duplicate()
	box_no = number
	guess = -1
	picked = -1
	pick_t = 0.0
	bead_out = false
	queue_redraw()


func _lid_h() -> float:
	return Kit.R * 6.1


## 서랍 안 칸 자리 (열린 상태 기준, 이 노드 좌표)
func _slot_rect(i: int) -> Rect2:
	var top := _lid_h() + Kit.R * (0.55 + 0.8) + Kit.R * 1.4
	var left := Kit.R * 1.2
	var w := size.x - left * 2
	var h := size.y - top - Kit.R * 1.1
	var gap := Kit.R * 0.45
	var sw := (w - gap * 2) / 3.0
	var sh := (h - gap * 2) / 3.0
	return Rect2(Vector2(left + (i % 3) * (sw + gap), top + (i / 3) * (sh + gap)), Vector2(sw, sh))


func _slide() -> float:
	return -(1.0 - open_t) * (size.y - _lid_h())


func _bead_r() -> float:
	var s := _slot_rect(0).size
	return clampf(minf(s.y * 0.14, s.x * 0.085), Kit.R * 0.4, Kit.R * 0.85)


## 칸 i의 k번째 구슬 자리 (열린 상태, 이 노드 좌표)
func _bead_pos(i: int, k: int, n: int) -> Vector2:
	var r := _bead_r()
	var sr := _slot_rect(i)
	var per_row := 4
	var rows := ceili(n / float(per_row))
	var row := k / per_row
	var in_row := mini(per_row, n - row * per_row)
	var step := r * 2.25
	var count_h := Kit.R * 1.5
	var block_h := rows * step + count_h
	var top := sr.position.y + (sr.size.y - block_h) / 2 + r * 1.1
	var x := sr.get_center().x + (k % per_row - (in_row - 1) / 2.0) * step
	# 자리마다 조금씩 다르게 놓아 손으로 담은 느낌을 낸다
	var j := Vector2(sin(i * 7.1 + k * 3.3), cos(i * 5.3 + k * 2.1)) * r * 0.12
	return Vector2(x, top + row * step) + j


func picked_bead_global() -> Vector2:
	var n := mini(beads[picked], MAX_BEADS)
	var p := _bead_pos(picked, n - 1, n) + Vector2(0, _slide() - Kit.R * 0.6 * pick_t)
	return get_global_transform() * p


func bead_r_global() -> float:
	return _bead_r() * get_global_transform().get_scale().x


func _draw() -> void:
	var w := size.x
	var lid := _lid_h()
	var R := Kit.R
	# 서랍 몸통
	var drawer := Kit.box(Kit.KRAFT, 0)
	drawer.corner_radius_bottom_left = int(R * 0.8)
	drawer.corner_radius_bottom_right = int(R * 0.8)
	draw_style_box(drawer, Rect2(0, lid - R, w, size.y - lid + R))
	draw_rect(Rect2(0, lid, w, R * 0.55), Kit.KRAFT_DARK)

	# 닫혔을 때 안내
	if open_t < 1.0:
		var wait := Rect2(R, lid + R, w - R * 2, size.y - lid - R * 2)
		Kit.text(self, Kit.F_BODY, R * 1.3, wait_text, wait, Color(Kit.INK_SOFT, 1.0 - open_t))

	# 구슬 서랍 (뚜껑 밑에서 나온다)
	if open_t > 0.0 and beads.size() == 9:
		var dy := _slide()
		var a := clampf(open_t * 1.6, 0.0, 1.0)
		var inner := Rect2(R * 0.6, lid + R * 0.55 + R * 0.3 + dy, w - R * 1.2, size.y - lid - R * 1.35)
		Kit.rrect(self, inner, Color(Kit.KRAFT_DARK, 0.55 * a), R * 0.6)
		Kit.text(self, Kit.F_LABEL, R * 1.05, "구슬이 많을수록 AI가 좋아하는 칸", Rect2(R * 1.25, lid + R * 1.15 + dy, w, R * 1.3), Color(Kit.INK_SOFT, a), HORIZONTAL_ALIGNMENT_LEFT)
		var total := 0
		for n in beads:
			total += n
		for i in 9:
			var sr := _slot_rect(i)
			sr.position.y += dy
			var full: bool = shape[i] != 0
			var bg := Kit.TRAY
			if full:
				bg = Color(Kit.NAVY, 0.13)
			elif beads[i] == 0:
				bg = Color(1, 1, 1, 0.25)
			if i == picked:
				bg = Kit.TRAY.lerp(Kit.PICK, pick_t)
			Kit.rrect(self, sr, Color(bg, bg.a * a), R * 0.45)
			if i == picked and pick_t > 0.0:
				Kit.rrect(self, sr, Color.TRANSPARENT, R * 0.45, R * 0.22, Color(Kit.MUSTARD, pick_t * a))
			if full:
				Kit.text(self, Kit.F_BODY, R * 0.95, "찼어요", sr, Color(Kit.INK_SOFT, a))
				continue
			# 맞혀 보기: 누를 수 있는 칸은 테두리가 숨 쉬고, 내가 고른 칸은 남색 테두리와 "내 생각" 표가 붙는다
			if pickable:
				var pulse := 0.45 + 0.35 * sin(_pick_time * TAU / 1.4)
				Kit.rrect(self, sr, Color.TRANSPARENT, R * 0.45, R * 0.16, Color(Kit.NAVY, pulse * a))
			if i == guess:
				Kit.rrect(self, sr, Color.TRANSPARENT, R * 0.45, R * 0.2, Color(Kit.NAVY, a))
				var tag := Rect2(sr.position + Vector2(R * 0.3, R * 0.25), Vector2(R * 3.6, R * 1.15))
				Kit.rrect(self, tag, Color(Kit.NAVY, a), R * 0.5)
				Kit.text(self, Kit.F_LABEL, R * 0.8, "내 생각", tag, Color(Kit.CREAM, a))
			var n := mini(beads[i], MAX_BEADS)
			for k in n:
				var lifted := i == picked and k == n - 1
				if lifted and bead_out:
					continue
				var p := _bead_pos(i, k, n) + Vector2(0, dy)
				var r := _bead_r()
				if lifted:
					p.y -= R * 0.6 * pick_t
					r *= 1.0 + 0.15 * pick_t
					draw_circle(p, r * 1.35, Color(Kit.MUSTARD, pick_t * a), true, -1.0, true)
					draw_circle(p, r * 1.18, Color(Kit.CREAM, pick_t * a), true, -1.0, true)
				Kit.bead(self, p, r, i, a)
			var label := str(beads[i])
			if percent and total > 0:
				label += "  ·  %d%%" % roundi(beads[i] * 100.0 / total)
			var rows := ceili(n / 4.0)
			var cy := sr.get_center().y + (rows * _bead_r() * 2.25 + R * 1.5) / 2 - R * 0.75
			if n == 0:
				cy = sr.get_center().y
			Kit.text(self, Kit.F_LABEL, R * 1.35, label, Rect2(sr.position.x, cy - R * 0.75, sr.size.x, R * 1.5), Color(Kit.INK, a))

	# 뚜껑: 상표 + 줄무늬 (서랍 위에 그려서 서랍이 밑에서 나오는 것처럼 보이게)
	var lw := minf(R * 21.0, w * 0.62)
	var lab := Kit.box(Kit.NAVY, 0)
	lab.corner_radius_top_left = int(R * 0.55)
	draw_style_box(lab, Rect2(0, 0, lw, lid))
	var stripe_w := R * 0.8
	var x := lw
	var red := true
	while x < w:
		draw_rect(Rect2(x, 0, minf(stripe_w, w - x), lid), Color(Kit.RED if red else Kit.CREAM, 0.9))
		x += stripe_w
		red = not red
	draw_line(Vector2(lw, lid), Vector2(w, lid), Kit.KRAFT_DARK, 2.0)
	var mb := lid - R * 1.1
	Kit.mini_board(self, Rect2(R * 0.55, (lid - mb) / 2, mb, mb), shape)
	var tx := R * 0.55 + mb + R * 0.7
	Kit.text(self, Kit.F_LABEL, R * 0.95, "BOX No. %d" % box_no if box_no > 0 else "BOX", Rect2(tx, lid * 0.5 - R * 1.55, lw - tx, R * 1.2), Kit.MUSTARD, HORIZONTAL_ALIGNMENT_LEFT)
	Kit.text(self, Kit.F_TITLE, R * 1.35, title if open_t > 0.5 else "성냥갑은 쉬는 중", Rect2(tx, lid * 0.5 - R * 0.35, lw - tx, R * 1.6), Kit.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
