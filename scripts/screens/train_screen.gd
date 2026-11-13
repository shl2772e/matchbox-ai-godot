class_name TrainScreen
extends ScreenBase
## 빨리 감기: 단추를 누르고 있는 동안 AI가 혼자 판을 둔다 (한 판이 끝날 때마다 스스로 상과 벌을 받는다).
## 3판으로는 보이지 않는 "조금씩 수백 번 고치면 실력이 된다"를 눈앞에서 보여 준다.
## 왼쪽: 10판씩 묶은 막대(이긴 판·비긴 판·진 판). 오른쪽: 첫 상자의 구슬이 바뀌는 모습과 기계.
##
## 판 수와 연습 상대는 tests/sim_difficulty.gd 로 정했다 (SelfPlay.TRAIN_GAMES, TRAIN_OPPONENT):
## 잘 두는 상대·대충 두는 상대와 섞어 1500판을 두면 졸업 시험에서 학생이 거의 못 이긴다 (비기기가 목표가 된다).
## 화면에 보이는 판 수만큼 실제로 둔다 (보이는 것과 다르게 몰래 더 두지 않는다).

signal done(info: Dictionary)

const GAMES := SelfPlay.TRAIN_GAMES
const OPPONENT := SelfPlay.TRAIN_OPPONENT
## 누르고 있으면 다 두는 데 걸리는 시간
const HOLD_S := 10.0
## 이만큼 손대지 않으면 저절로 돈다
const AUTO_S := 6.0
const BUCKETS := 20

var brain: Dictionary

var _rng := SeededRng.for_game()
var _played := 0
var _acc := 0.0
var _holding := false
var _auto := false
var _idle := 0.0
var _held_ms := 0.0
var _finished := false
var _armed := false
var _gone := false
var _buckets: Array = []
var _time := 0.0
var _shown := -1

var _brand: Drawn
var _stage: Label
var _title: Label
var _line: Label
var _graph: Drawn
var _box: Drawn
var _machine: MachineView
var _button: Button


func _init(b: Dictionary) -> void:
	brain = b
	for i in BUCKETS:
		_buckets.append({"ai": 0, "draw": 0, "kid": 0})


func build() -> void:
	# 가장 잘 두는 상대의 수읽기를 미리 해 둔다 (첫 판에서 멈칫하지 않게)
	SelfPlay.perfect_kid(Ttt.place(Ttt.empty_board(), 4, Ttt.AI), _rng)
	var R := Kit.R
	_brand = Drawn.new(PlayScreen.paint_brand)
	add_child(_brand)
	_stage = Kit.label("빨리 감기", Kit.F_LABEL, R * 1.3)
	add_child(_stage)
	_title = Kit.label("AI가 혼자 연습해요", Kit.F_TITLE, R * 2.4, Kit.NAVY, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_title)
	_line = Kit.label("단추를 누르고 있으면 AI가 혼자 둬요. 한 판이 끝날 때마다 스스로 상과 벌을 받아요.", Kit.F_BODY, R * 1.3, Kit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	add_child(_line)
	_graph = Drawn.new(_paint_graph)
	add_child(_graph)
	_box = Drawn.new(_paint_box)
	add_child(_box)
	_machine = MachineView.new()
	add_child(_machine)
	_button = Kit.button("꾹 누르고 있어요", "primary", true)
	_button.custom_minimum_size.x = R * 16
	_button.button_down.connect(_on_down)
	_button.button_up.connect(_on_up)
	_button.pressed.connect(_on_pressed)
	add_child(_button)


func relayout() -> void:
	var R := Kit.R
	var w := size.x - pad.x * 2
	var head_h := R * 3.4
	_brand.position = pad + Vector2(R * 0.4, R * 0.2)
	_brand.size = Vector2(R * 13, head_h - R * 0.4)
	_stage.size = _stage.get_combined_minimum_size()
	_stage.position = Vector2(size.x - pad.x - R * 3.8 - _stage.size.x, pad.y + (head_h - _stage.size.y) / 2)
	var y := pad.y + head_h + R * 0.2
	y += Kit.place(_title, Vector2(pad.x, y), w) + R * 0.3
	var lw := minf(w, R * 46)
	y += Kit.place(_line, Vector2((size.x - lw) / 2, y), lw) + R * 0.9
	_button.size = _button.get_combined_minimum_size()
	_button.position = Vector2((size.x - _button.size.x) / 2, size.y - pad.y - _button.size.y - R * 0.5)
	var bottom := _button.position.y - R * 1.1
	var machine_size := Vector2(R * 10.0, R * 4.8)
	if portrait():
		var gh := (bottom - y) * 0.45
		_graph.position = Vector2(pad.x, y)
		_graph.size = Vector2(w, gh)
		var by := y + gh + R
		var bs := minf(w - machine_size.x - R, bottom - by)
		_box.position = Vector2(pad.x, by)
		_box.size = Vector2(bs, bs)
		_machine.position = Vector2(pad.x + bs + R, by + (bs - machine_size.y) / 2)
	else:
		var gap := R * 1.6
		var rw := R * 20.0
		_graph.position = Vector2(pad.x, y)
		_graph.size = Vector2(w - rw - gap, bottom - y)
		var bs := minf(rw, bottom - y - machine_size.y - R * 0.6)
		var rx := pad.x + w - rw
		_box.position = Vector2(rx + (rw - bs) / 2, y)
		_box.size = Vector2(bs, bs)
		_machine.position = Vector2(rx + (rw - machine_size.x) / 2, bottom - machine_size.y)
	_machine.size = machine_size


func enter() -> void:
	rise_in(_title)
	rise_in(_line, 0.1)
	rise_in(_graph, 0.2)
	rise_in(_box, 0.3)
	rise_in(_button, 0.4)


func _on_down() -> void:
	_idle = 0.0
	if _finished:
		_armed = true
	else:
		_holding = true


func _on_up() -> void:
	_holding = false


## 다 둔 뒤에 새로 누른 것만 "다음"으로 친다 (누르고 있던 손을 떼는 것은 아니다)
func _on_pressed() -> void:
	if _finished and _armed:
		_go()


func _go() -> void:
	if _gone:
		return
	_gone = true
	var half := BUCKETS / 2
	var first := 0
	var last := 0
	for i in BUCKETS:
		if i < half:
			first += _buckets[i].kid
		else:
			last += _buckets[i].kid
	done.emit({"games": _played, "held_ms": roundi(_held_ms), "auto": _auto, "loss_first": first, "loss_last": last})


func _process(delta: float) -> void:
	_time += delta
	# 판 수가 바뀔 때만 그래프와 상자를 다시 그린다
	if _played != _shown:
		_shown = _played
		_graph.queue_redraw()
		_box.queue_redraw()
	if _finished:
		return
	var running := _holding or _auto
	_machine.working = running
	if running and _machine.mood != "think":
		_machine.mood = "think"
	if running:
		if _holding:
			_held_ms += delta * 1000.0
		_acc += delta * GAMES / HOLD_S
		while _acc >= 1.0 and _played < GAMES:
			_acc -= 1.0
			_play_one()
		if _played >= GAMES:
			_finish()
	else:
		_idle += delta
		if _idle >= AUTO_S:
			_auto = true
			Kit.set_text(_line, "AI가 혼자 두기 시작했어요. 막대가 어떻게 바뀌는지 보세요.")


func _play_one() -> void:
	var o := SelfPlay.play_one(brain, OPPONENT, _rng)
	_buckets[_played * BUCKETS / GAMES][o] += 1
	_played += 1
	if _played % 10 == 0:
		Sfx.tick()


func _finish() -> void:
	_finished = true
	_holding = false
	_machine.working = false
	var half := BUCKETS / 2
	var first := 0
	var last := 0
	for i in BUCKETS:
		if i < half:
			first += _buckets[i].kid
		else:
			last += _buckets[i].kid
	var n := GAMES / 2
	var s := "처음 %d판에서는 %d판을 졌고, 나중 %d판에서는 %d판을 졌어요." % [n, first, n, last]
	if last < first:
		s += " 조금씩 수백 번 고친 것이 실력이 됐어요."
		_machine.mood = "happy"
	else:
		s += " 아직 많이 져요. 배우려면 더 많은 판이 필요해요."
		_machine.mood = "calm"
	Kit.set_text(_title, "%d판을 뒀어요" % GAMES)
	Kit.set_text(_line, s)
	_button.text = "졸업 시험 보러 가기"
	Sfx.done()
	relayout()
	later(9.0, _go)


## 10판씩 묶은 막대. 아래부터 AI가 이긴 판(빨강)·비긴 판(겨자)·진 판(남색). 왼쪽이 처음, 오른쪽이 나중
func _paint_graph(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	Kit.rrect(ci, Rect2(r.position + Vector2(0, R * 0.35), r.size), Kit.LINE, R * 0.8)
	Kit.rrect(ci, r, Kit.CREAM, R * 0.8)
	Kit.text(ci, Kit.F_LABEL, R * 1.25, "혼자 둔 판", Rect2(R * 1.4, R * 0.7, R * 8, R * 1.8), Kit.INK, HORIZONTAL_ALIGNMENT_LEFT)
	Kit.text(ci, Kit.F_TITLE, R * 1.7, "%d / %d" % [_played, GAMES], Rect2(R * 7.2, R * 0.6, R * 12, R * 2.0), Kit.RED_INK, HORIZONTAL_ALIGNMENT_LEFT)
	# 범례 (색 + 자리: 막대와 같은 순서로 위에서 아래)
	var legend := [["AI가 진 판", Kit.NAVY], ["비긴 판", Kit.MUSTARD], ["AI가 이긴 판", Kit.RED]]
	var lx := r.size.x - R * 1.4
	for i in range(legend.size() - 1, -1, -1):
		var word: String = legend[i][0]
		var tw := Kit.F_LABEL.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, int(R * 1.0)).x
		lx -= tw
		Kit.text(ci, Kit.F_LABEL, R * 1.0, word, Rect2(lx, R * 0.7, tw + R, R * 1.8), Kit.INK, HORIZONTAL_ALIGNMENT_LEFT)
		lx -= R * 1.2
		Kit.rrect(ci, Rect2(lx, R * 1.2, R * 0.8, R * 0.8), legend[i][1], R * 0.15)
		lx -= R * 1.0
	var area := Rect2(R * 1.6, R * 3.4, r.size.x - R * 3.2, r.size.y - R * 6.6)
	ci.draw_line(Vector2(area.position.x, area.end.y), area.end, Kit.LINE, R * 0.1)
	var per := GAMES / BUCKETS
	var bw := area.size.x / BUCKETS
	for i in BUCKETS:
		var b: Dictionary = _buckets[i]
		var x := area.position.x + i * bw + bw * 0.14
		var y := area.end.y
		# 아직 안 둔 묶음은 빈 자리만 보인다
		ci.draw_rect(Rect2(x, area.position.y, bw * 0.72, area.size.y), Color(Kit.LINE, 0.18))
		for part in [["ai", Kit.RED], ["draw", Kit.MUSTARD], ["kid", Kit.NAVY]]:
			var h: float = area.size.y * b[part[0]] / per
			if h > 0.0:
				ci.draw_rect(Rect2(x, y - h, bw * 0.72, h), part[1])
				y -= h
	Kit.text(ci, Kit.F_LABEL, R * 0.95, "처음", Rect2(area.position.x, area.end.y + R * 0.3, R * 4, R * 1.2), Kit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	Kit.text(ci, Kit.F_LABEL, R * 0.95, "나중", Rect2(area.end.x - R * 4, area.end.y + R * 0.3, R * 4, R * 1.2), Kit.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
	Kit.text(ci, Kit.F_BODY, R * 1.05, "막대 하나가 %d판이에요. 남색(진 판)이 줄어드는지 보세요." % per, Rect2(0, r.size.y - R * 2.0, r.size.x, R * 1.5), Kit.INK_SOFT)


## 첫 상자(빈 판에서 여는 상자)의 칸별 구슬 수
func _paint_box(ci: Drawn) -> void:
	paint_first_box(ci, Rect2(Vector2.ZERO, ci.size), Menace.beads_on_board(brain, Ttt.empty_board()), "첫 상자 속 구슬")


## 3×3 칸에 구슬 수를 그린다 (졸업장도 쓴다). 구슬은 칸마다 6개까지 그리고 수는 숫자로 적는다
static func paint_first_box(ci: CanvasItem, r: Rect2, beads: Array, title: String) -> void:
	var R := Kit.R
	Kit.rrect(ci, Rect2(r.position + Vector2(0, R * 0.3), r.size), Kit.LINE, R * 0.7)
	Kit.rrect(ci, r, Kit.KRAFT, R * 0.7)
	var head := R * 1.9
	Kit.text(ci, Kit.F_LABEL, minf(R * 1.1, r.size.x * 0.085), title, Rect2(r.position, Vector2(r.size.x, head)), Kit.INK)
	var m := R * 0.5
	var gap := R * 0.3
	var cs := (minf(r.size.x, r.size.y - head) - m * 2 - gap * 2) / 3.0
	var ox := r.position.x + (r.size.x - cs * 3 - gap * 2) / 2
	var oy := r.position.y + head
	var top := 0
	for n in beads:
		top = maxi(top, n)
	for i in 9:
		var cr := Rect2(ox + (i % 3) * (cs + gap), oy + (i / 3) * (cs + gap), cs, cs)
		Kit.rrect(ci, cr, Kit.PICK if beads[i] == top and top > 0 else Kit.TRAY, R * 0.35)
		var n: int = mini(beads[i], 6)
		var br := cs * 0.085
		for k in n:
			var p := Vector2(cr.position.x + cs * 0.5 + (k % 3 - 1) * br * 2.4, cr.position.y + cs * 0.2 + (k / 3) * br * 2.4)
			Kit.bead(ci, p, br, i)
		Kit.text(ci, Kit.F_TITLE, cs * 0.4, str(beads[i]), Rect2(cr.position.x, cr.position.y + cs * 0.46, cs, cs * 0.5), Kit.INK)
