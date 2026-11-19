class_name BoardView
extends Control
## 틱택토 판. 빈칸을 누르면 cell_tapped. 새로 둔 수는 획을 긋듯 그려지고, 이긴 줄에는 선이 그어진다.
## active(내 차례)면 테두리가 숨 쉬듯 밝아지고, 잠시 뒤 손가락이 빈칸을 톡 두드리는 안내가 나온다.
##
## 새 흐름(GameScreen)에서는 서랍을 따로 그리지 않고 AI의 구슬을 이 판의 빈칸에 바로 보여 준다:
##   show_beads() 빈칸마다 구슬과 뽑힐 확률(%) → bead_pick/pick_t 기계 집게가 구슬 하나를 집는다 → put() 그 칸에 ○
##   guessing 맞혀 보기(빈칸을 누르면 guess_tapped), start_teach() 판이 끝난 뒤 AI가 둔 칸마다 구슬이 늘거나 준다

signal cell_tapped(cell: int)
signal guess_tapped(cell: int)
signal teach_done(manual: int, total: int)

## 손가락 안내가 나오기까지 기다리는 시간 (빨리 두는 학생은 안 본다)
const HINT_DELAY := 1.0
const HINT_CYCLE := 2.0
## 안내 손가락이 돌아다니는 순서 (가운데에서 시작해 멀리 떨어진 칸으로)
const HINT_ORDER := [4, 0, 8, 2, 6, 1, 7, 3, 5]

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
		_update_process()
		queue_redraw()
var _active_t := 0.0
var _drawn := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
var _line: Array = []
var _line_t := 0.0
var _press := -1

## "판과 같은 모양" 표시: 판과 성냥갑 상표의 작은 판에 같은 겨자색 테두리가 잠깐 켜졌다 꺼진다
var match_t := 0.0:
	set(v):
		match_t = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func _update_process() -> void:
	set_process(active or guessing or _teaching)


func _process(delta: float) -> void:
	_active_t += delta
	_anim_t += delta
	if _teaching:
		_teach_step(delta)
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


func flash_match() -> void:
	match_t = 1.0
	create_tween().tween_property(self, "match_t", 0.0, 0.7).set_delay(0.45)


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
		if event.pressed and (_teaching or guessing):
			for i in 9:
				if cell_rect(i).has_point(event.position):
					if _teaching:
						_teach_tap(i)
					elif board[i] == 0:
						guess_tapped.emit(i)
			accept_event()
			return
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
	if match_t > 0.0:
		Kit.rrect(self, Rect2(Vector2(pad, pad), Vector2(s - pad * 2, s - pad * 2)).grow(s * 0.012), Color.TRANSPARENT, s * 0.025, s * 0.012, Color(Kit.MUSTARD, match_t))
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
		if board[i] == 0 and beads.size() == 9 and beads_a > 0.0:
			_draw_cell_beads(i)
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
	if bead_pick >= 0 and pick_t > 0.0 and beads.size() == 9 and beads_a > 0.0:
		_draw_claw()
	if not _teach.is_empty():
		_draw_teach()
	if active and _active_t > HINT_DELAY:
		# 빈칸마다 옅은 ×가 숨 쉰다: "빈칸이면 어디든 둘 수 있어요" (한 칸만 누르라는 뜻으로 보이지 않게)
		var empties := _hint_cells()
		for k in empties.size():
			var a := 0.13 + 0.07 * sin(_active_t * TAU / 1.8 - k * 0.9)
			_ghost_x(cell_rect(empties[k]).get_center(), cell_rect(0).size.x * 0.8, a)
		# 손가락은 두드릴 때마다 다른 빈칸으로 옮겨 간다
		if not empties.is_empty():
			var n := int((_active_t - HINT_DELAY) / HINT_CYCLE)
			_draw_hand(cell_rect(empties[n % empties.size()]).get_center(), cell_rect(0).size.x, fmod(_active_t - HINT_DELAY, HINT_CYCLE))


## 손가락이 돌아다닐 빈칸들 (가운데에서 시작해 멀리 떨어진 칸으로 건너뛰는 순서)
func _hint_cells() -> Array:
	var out := []
	for i in HINT_ORDER:
		if board[i] == 0:
			out.append(i)
	return out


## 손가락이 칸을 톡 두드린다. t는 한 주기(초) 안의 시간: 내려감 → 닿음(물결) → 올라감 → 쉼
func _draw_hand(c: Vector2, cs: float, t: float) -> void:
	var down := 0.0
	if t < 0.35:
		down = pow(t / 0.35, 2)
	elif t < 0.85:
		down = 1.0
	elif t < 1.2:
		down = 1.0 - (t - 0.85) / 0.35
	# 옮겨 갈 때는 옅어졌다가 새 칸에서 다시 나타난다
	var fade := clampf(minf(t / 0.2, (HINT_CYCLE - t) / 0.3), 0.0, 1.0)
	if t >= 0.35 and t < 0.95:
		var q := (t - 0.35) / 0.6
		draw_arc(c, cs * (0.1 + 0.3 * q), 0, TAU, 40, Color(Kit.MUSTARD, 1.0 - q), cs * 0.025, true)
	var tip := c + Vector2(cs * 0.04, cs * 0.06) - Vector2(0, (1.0 - down) * cs * 0.28)
	var u := cs * 0.11
	draw_set_transform(tip, deg_to_rad(-18.0), Vector2.ONE)
	# 먹색 바깥선을 먼저 그리고 그 위를 크림색으로 덮어 한 덩어리 손으로 보이게 한다.
	# 손가락 사이에 선을 긋지 않는다 (집게손가락 + 엄지 + 둥근 주먹)
	var palm := Rect2(Vector2(-0.75 * u, 2.5 * u), Vector2(3.2 * u, 2.9 * u))
	for layer in 2:
		var grow := 0.0 if layer == 1 else 0.32 * u
		var col := Color(Kit.CREAM if layer == 1 else Kit.INK, fade)
		_capsule(Vector2.ZERO, Vector2(0, 3.0 * u), 1.0 * u + grow, col)
		_capsule(Vector2(-0.9 * u, 3.9 * u), Vector2(-1.6 * u, 3.1 * u), 0.85 * u + grow, col)
		Kit.rrect(self, palm.grow(grow / 2), col, 1.1 * u)
	draw_set_transform(Vector2.ZERO)


func _capsule(a: Vector2, b: Vector2, w: float, color: Color) -> void:
	draw_line(a, b, color, w, true)
	draw_circle(a, w / 2, color, true, -1.0, true)
	draw_circle(b, w / 2, color, true, -1.0, true)


## 옅은 × (빈칸 안내). 겹쳐서 얼룩지지 않게 선 두 개만 긋는다
func _ghost_x(c: Vector2, cell_size: float, alpha: float) -> void:
	var d := cell_size * 0.208
	var w := cell_size * 0.0946
	var col := Color(Kit.NAVY, alpha)
	draw_line(c + Vector2(-d, -d), c + Vector2(d, d), col, w, true)
	# 둘째 획은 가운데 겹치는 곳을 비우고 양쪽으로 나눠 긋는다
	var g := w / (d * 2.0 * sqrt(2.0))
	draw_line(c + Vector2(d, -d), c + Vector2(d, -d).lerp(Vector2(-d, d), 0.5 - g * 0.5), col, w, true)
	draw_line(c + Vector2(d, -d).lerp(Vector2(-d, d), 0.5 + g * 0.5), c + Vector2(-d, d), col, w, true)


# ---------- AI의 구슬을 판의 빈칸에 (새 흐름) ----------

const MAX_BEADS := 12

## 빈칸마다 든 구슬 수 9개 (비어 있으면 안 보임)
var beads: Array = []
## 칸마다 실제로 뽑힐 확률 (합 1). 화면의 %는 이것을 그대로 적는다
var chances: Array = []
var percent := false
var beads_a := 0.0:
	set(v):
		beads_a = v
		queue_redraw()
## 기계 집게가 집는 칸과 내려온 정도
var bead_pick := -1
var pick_t := 0.0:
	set(v):
		pick_t = v
		queue_redraw()
## 맞혀 보기: 빈칸을 누르면 guess_tapped
var guessing := false:
	set(v):
		guessing = v
		_update_process()
		queue_redraw()
var guess := -1:
	set(v):
		guess = v
		queue_redraw()
var _anim_t := 0.0


func show_beads(counts: Array, probs: Array = []) -> void:
	beads = counts.duplicate()
	chances = probs if probs.size() == 9 else Menace.chances(counts)
	guess = -1
	bead_pick = -1
	pick_t = 0.0
	create_tween().tween_property(self, "beads_a", 1.0, 0.35).from(0.0).set_trans(Tween.TRANS_SINE)


func hide_beads() -> void:
	create_tween().tween_property(self, "beads_a", 0.0, 0.25)


func _bead_r() -> float:
	return cell_rect(0).size.x * 0.072


## 칸 i의 k번째 구슬 자리 (4개씩 세 줄까지)
func _cell_bead_pos(i: int, k: int, n: int) -> Vector2:
	var r := cell_rect(i)
	var cs := r.size.x
	var step := _bead_r() * 2.3
	var row := k / 4
	var in_row := mini(4, n - row * 4)
	var j := Vector2(sin(i * 7.1 + k * 3.3), cos(i * 5.3 + k * 2.1)) * _bead_r() * 0.12
	return Vector2(r.get_center().x + (k % 4 - (in_row - 1) / 2.0) * step, r.position.y + cs * 0.17 + row * step) + j


## 그 칸이 뽑힐 확률 (학생과 둘 때는 구슬이 많은 칸으로 쏠린 실제 확률)
func _chance_text(i: int) -> String:
	if chances.size() != 9:
		return "0%"
	return "%d%%" % roundi(chances[i] * 100.0)


func _draw_cell_beads(i: int) -> void:
	var r := cell_rect(i)
	var cs := r.size.x
	var a := beads_a
	var bg := Kit.TRAY
	if i == bead_pick:
		bg = Kit.TRAY.lerp(Kit.PICK, pick_t)
	draw_rect(r, Color(bg, a))
	if i == bead_pick and pick_t > 0.0:
		var w := cs * 0.035
		draw_rect(r.grow(-w / 2), Color(Kit.MUSTARD, pick_t * a), false, w)
	if guessing:
		var pulse := 0.4 + 0.35 * sin(_anim_t * TAU / 1.4)
		var w := cs * 0.03
		draw_rect(r.grow(-w / 2), Color(Kit.NAVY, pulse * a), false, w)
	if i == guess:
		var w := cs * 0.035
		draw_rect(r.grow(-w / 2), Color(Kit.NAVY, a), false, w)
	var n := mini(beads[i], MAX_BEADS)
	for k in n:
		var p := _cell_bead_pos(i, k, n)
		var lifted := i == bead_pick and k == n - 1
		if lifted:
			p.y -= cs * 0.05 * pick_t
			draw_circle(p, _bead_r() * 1.4, Color(Kit.MUSTARD, pick_t * a), true, -1.0, true)
		Kit.bead(self, p, _bead_r() * (1.0 + (0.15 * pick_t if lifted else 0.0)), i, a)
	# 아래 한 줄: 이 칸이 나올 확률 (글자는 이것 하나만)
	Kit.text(self, Kit.F_LABEL, cs * 0.16, _chance_text(i), Rect2(r.position.x, r.end.y - cs * 0.27, cs, cs * 0.22), Color(Kit.INK, a))
	if i == guess:
		var tag := Rect2(Vector2(r.get_center().x - cs * 0.21, r.end.y - cs * 0.45), Vector2(cs * 0.42, cs * 0.15))
		Kit.rrect(self, tag, Color(Kit.NAVY, a), cs * 0.06)
		Kit.text(self, Kit.F_LABEL, cs * 0.1, "내 생각", tag, Color(Kit.CREAM, a))


## AI의 손: 위에서 내려오는 기계 집게 (학생의 손과 모양과 색이 다르다)
func _draw_claw() -> void:
	var r := cell_rect(bead_pick)
	var cs := r.size.x
	var n := mini(beads[bead_pick], MAX_BEADS)
	if n <= 0:
		return
	var a := beads_a
	var p := ScreenBase.ease_out(pick_t)
	var bead := _cell_bead_pos(bead_pick, n - 1, n) - Vector2(0, cs * 0.05 * pick_t)
	var br := _bead_r()
	var head := Vector2(bead.x, lerpf(r.position.y + br * 0.6, bead.y - br * 2.1, p))
	var navy := Color(Kit.NAVY, a)
	# 팔 (그 칸의 위쪽 가장자리에서 내려온다. 다른 칸의 구슬과 숫자를 가리지 않게)
	draw_line(Vector2(head.x, r.position.y), head, navy, cs * 0.04, true)
	# 집게 두 가닥: 내려올수록 오므린다
	var open := lerpf(br * 1.7, br * 1.05, p)
	for side in [-1.0, 1.0]:
		var elbow := head + Vector2(side * open * 1.15, br * 1.0)
		var tip := head + Vector2(side * open * 0.8, br * 2.5)
		draw_line(head + Vector2(side * br * 0.7, 0), elbow, navy, cs * 0.03, true)
		draw_line(elbow, tip, navy, cs * 0.03, true)
		draw_circle(tip, cs * 0.018, navy, true, -1.0, true)
	Kit.rrect(self, Rect2(head - Vector2(br * 1.3, br * 0.55), Vector2(br * 2.6, br * 1.1)), navy, br * 0.4)
	draw_circle(head, br * 0.32, Color(Kit.RED, a), true, -1.0, true)


# ---------- 판이 끝난 뒤: AI가 둔 칸마다 구슬이 늘거나 준다 (상과 벌) ----------

const TEACH_AUTO_S := 6.0
const TEACH_FLY := 0.45
const TEACH_GAP := 0.16
const TEACH_SHOW := 10

## Menace.learn이 돌려준 것: [{cell, before, after, ...}]
var _teach: Array = []
var _teach_at: Array[float] = []
var _teach_reward := true
var _teach_by_hand := false
var _teach_manual := 0
var _teach_time := 0.0
var _teach_idle := 0.0
var _teaching := false


## by_hand면 학생이 칸을 눌러야 구슬이 움직인다 (6초 손대지 않으면 저절로). 아니면 차례로 저절로 바뀐다
func start_teach(changes: Array, reward: bool, by_hand: bool) -> void:
	_teach = changes
	_teach_at.clear()
	for c in changes:
		_teach_at.append(-1.0)
	_teach_reward = reward
	_teach_by_hand = by_hand
	_teach_manual = 0
	_teach_time = 0.0
	_teach_idle = 0.0
	_teaching = true
	_update_process()
	queue_redraw()


func _teach_tap(cell: int) -> void:
	_teach_idle = 0.0
	if not _teach_by_hand:
		return
	for k in _teach.size():
		if _teach[k].cell == cell:
			_teach_apply(k, true)


func _teach_apply(k: int, by_hand: bool) -> void:
	if _teach_at[k] >= 0.0:
		return
	_teach_at[k] = _teach_time
	if by_hand:
		_teach_manual += 1
	var n: int = absi(_teach[k].after - _teach[k].before)
	for j in maxi(n, 1):
		Sfx.clink(j * TEACH_GAP + (TEACH_FLY if _teach_reward else 0.0))


func _teach_step(delta: float) -> void:
	_teach_time += delta
	_teach_idle += delta
	var left := _teach_at.find(-1.0)
	if left >= 0:
		if _teach_by_hand:
			if _teach_idle >= TEACH_AUTO_S:
				_teach_apply(left, false)
				_teach_idle = TEACH_AUTO_S - 0.55
		elif _teach_time >= 0.5 + left * 0.45:
			_teach_apply(left, false)
		return
	var last := 0.0
	for t in _teach_at:
		last = maxf(last, t)
	if _teach_time - last > TEACH_FLY + TEACH_GAP * 3 + 0.5:
		_teaching = false
		_update_process()
		teach_done.emit(_teach_manual, _teach.size())


func _teach_bead_pos(cell: int, k: int, shown: int) -> Vector2:
	var r := cell_rect(cell)
	var cs := r.size.x
	var br := cs * 0.062
	var step := br * 2.3
	var row := k / 5
	var cnt := mini(5, shown - row * 5)
	return Vector2(r.get_center().x + (k % 5 - (cnt - 1) / 2.0) * step, r.position.y + cs * 0.4 + row * step)


func _draw_teach() -> void:
	var cs := cell_rect(0).size.x
	var br := cs * 0.062
	var flying: Array = []
	for k in _teach.size():
		var c: Dictionary = _teach[k]
		var r := cell_rect(c.cell)
		var ct: float = _teach_time - _teach_at[k] if _teach_at[k] >= 0.0 else -1.0
		var before: int = c.before
		var after: int = c.after
		var n := absi(after - before)
		var shown := mini(maxi(before, after), TEACH_SHOW)
		# ○는 옅게 남기고 그 위에 그 칸의 구슬을 보여 준다
		draw_rect(r, Color(Kit.CREAM, 0.88))
		var todo := ct < 0.0
		if todo and _teach_by_hand:
			var pulse := 0.5 + 0.5 * sin(_teach_time * TAU / 1.4 - k * 0.6)
			var w := cs * 0.04
			draw_rect(r.grow(-w / 2), Color(Kit.MUSTARD, 0.45 + 0.5 * pulse), false, w)
			var tag := Rect2(r.position + Vector2(cs * 0.08, cs * 0.07), Vector2(cs * 0.84, cs * 0.2))
			var ask := "눌러서 %d개 넣기" % n if _teach_reward else "눌러서 %d개 빼기" % n
			if n == 0:
				ask = "눌러서 확인하기"
			Kit.rrect(self, tag, Kit.RED, cs * 0.06)
			Kit.text(self, Kit.F_LABEL, cs * 0.105, ask, tag, Kit.CREAM)
		# 바깥 자리: 구슬이 들어오거나 나가는 곳 (판 오른쪽 밖)
		var out := Vector2(size.x + cs * 0.3, r.get_center().y)
		for b in shown:
			var pos := _teach_bead_pos(c.cell, b, shown)
			if b < mini(before, after):
				Kit.bead(self, pos, br, c.cell)
			elif b >= before:
				var p := (ct - (b - before) * TEACH_GAP) / TEACH_FLY if ct >= 0.0 else -1.0
				if p >= 1.0:
					Kit.bead(self, pos, br, c.cell)
				elif p >= 0.0:
					flying.append([_arc(out, pos, p), c.cell])
			else:
				var p := (ct - (before - 1 - b) * TEACH_GAP) / TEACH_FLY if ct >= 0.0 else -1.0
				if p < 0.0:
					Kit.bead(self, pos, br, c.cell)
				elif p < 1.0:
					flying.append([_arc(pos, out, p), c.cell])
		# 아래: 몇 개에서 몇 개로
		var done := ct >= TEACH_FLY + TEACH_GAP * maxi(n - 1, 0)
		var left := "%d개" % before
		var right := "%d개" % after if done else "..."
		var col := Kit.INK_SOFT
		if done:
			col = Kit.TEAL if after > before else (Kit.RED_INK if after < before else Kit.INK)
		var fs := cs * 0.14
		var lw := Kit.F_TITLE.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
		var rw := Kit.F_TITLE.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
		var arrow := cs * 0.16
		var x0 := r.position.x + (cs - lw - arrow - rw) / 2
		var fy := r.end.y - cs * 0.26
		Kit.text(self, Kit.F_TITLE, fs, left, Rect2(x0, fy, lw, cs * 0.2), Kit.INK, HORIZONTAL_ALIGNMENT_LEFT)
		var ac := Vector2(x0 + lw + arrow / 2, fy + cs * 0.1)
		draw_colored_polygon(PackedVector2Array([ac + Vector2(-cs * 0.03, -cs * 0.04), ac + Vector2(cs * 0.04, 0), ac + Vector2(-cs * 0.03, cs * 0.04)]), Kit.MUSTARD)
		Kit.text(self, Kit.F_TITLE, fs, right, Rect2(x0 + lw + arrow, fy, rw + cs * 0.1, cs * 0.2), col, HORIZONTAL_ALIGNMENT_LEFT)
	for f in flying:
		Kit.bead(self, f[0], br * 1.1, f[1])
	# 2초 동안 누르지 않으면 손가락이 아직 안 누른 칸을 두드려 보인다 (어느 칸을 눌러야 하는지)
	var todo_k := _teach_at.find(-1.0)
	if _teach_by_hand and todo_k >= 0 and _teach_idle > 2.0:
		_draw_hand(cell_rect(_teach[todo_k].cell).get_center() + Vector2(0, cs * 0.12), cs, fmod(_teach_idle - 2.0, HINT_CYCLE))


static func _arc(from: Vector2, to: Vector2, p: float) -> Vector2:
	var q := ScreenBase.ease_out(p)
	var mid := (from + to) / 2 + Vector2(0, -from.distance_to(to) * 0.25)
	return from.lerp(mid, q).lerp(mid.lerp(to, q), q)
