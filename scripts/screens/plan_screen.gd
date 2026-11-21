class_name PlanScreen
extends ScreenBase
## AI 키우기 대회 1: 연습 계획 세우기. 연습 1000판을 여섯 친구에게 5판 단위로 나눠 준다.
## 누구와 연습했느냐에 따라 AI 실력이 달라진다는 것을 점수로 겪게 한다.
## 같은 계획이면 언제나 같은 점수가 나온다(SelfPlay.contest_seed). 점수를 올리려면 계획을 바꿔야 한다.
## 단추를 한 번 누르면 5판, 누르고 있으면 점점 빨리 바뀐다.

signal start(counts: Array)
signal home

## 누르고 있을 때: 처음 0.35초 뒤부터 되풀이, 1.2초 뒤부터는 25판씩
const HOLD_WAIT := 0.35
const HOLD_EVERY := 0.07
const HOLD_FAST := 1.2

## 친구마다 준 판 수 (합이 SelfPlay.CONTEST_GAMES가 되어야 시작할 수 있다)
var counts := [0, 0, 0, 0, 0, 0]

var _title: Label
var _line: Label
var _cards: Array[Drawn] = []
var _minus: Array[Button] = []
var _plus: Array[Button] = []
var _left: Label
var _start: Button
var _home: Button
var _gone := false
## 누르고 있는 단추: 친구 번호와 방향(+1, -1). 없으면 -1
var _held := -1
var _held_dir := 0
var _held_t := 0.0
var _held_next := 0.0


func build() -> void:
	var R := Kit.R
	_title = Kit.label("AI 키우기 대회", Kit.F_TITLE, R * 2.4, Kit.NAVY, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_title)
	_line = Kit.label("AI가 누구와 연습할까요? 연습 %d판을 친구들에게 나눠 줘요." % SelfPlay.CONTEST_GAMES, Kit.F_BODY, R * 1.25, Kit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	add_child(_line)
	for i in SelfPlay.CONTEST_FRIENDS.size():
		var d := Drawn.new(_paint_card.bind(i))
		add_child(d)
		_cards.append(d)
		var m := Kit.button("빼기", "danger")
		m.button_down.connect(_press.bind(i, -1))
		m.button_up.connect(_release)
		d.add_child(m)
		_minus.append(m)
		var p := Kit.button("더하기", "primary")
		p.button_down.connect(_press.bind(i, 1))
		p.button_up.connect(_release)
		d.add_child(p)
		_plus.append(p)
	_left = Kit.label("", Kit.F_LABEL, R * 1.4, Kit.RED_INK, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_left)
	_home = Kit.button("처음으로", "soft", true)
	_home.pressed.connect(_leave.bind(false))
	add_child(_home)
	_start = Kit.button("이 계획으로 연습 시작", "primary", true)
	_start.pressed.connect(_leave.bind(true))
	add_child(_start)
	_refresh()


func _remaining() -> int:
	var left := SelfPlay.CONTEST_GAMES
	for n in counts:
		left -= n
	return left


func _press(i: int, dir: int) -> void:
	_held = i
	_held_dir = dir
	_held_t = 0.0
	_held_next = HOLD_WAIT
	_change(i, dir * SelfPlay.CONTEST_STEP)


func _release() -> void:
	_held = -1


func _process(delta: float) -> void:
	if _held < 0:
		return
	_held_t += delta
	if _held_t >= _held_next:
		_held_next += HOLD_EVERY
		_change(_held, _held_dir * SelfPlay.CONTEST_STEP * (5 if _held_t > HOLD_FAST else 1))


## d판을 더하거나 뺀다. 남은 판보다 많이 더하면 남은 만큼만, 가진 것보다 많이 빼면 0까지만
func _change(i: int, d: int) -> void:
	var real := mini(d, _remaining()) if d > 0 else -mini(-d, counts[i])
	if real == 0:
		return
	counts[i] += real
	Sfx.tap()
	_refresh()


func _refresh() -> void:
	var left := _remaining()
	_left.text = "남은 연습 %d판" % left if left > 0 else "%d판을 모두 나눠 줬어요" % SelfPlay.CONTEST_GAMES
	_left.label_settings.font_color = Kit.RED_INK if left > 0 else Kit.TEAL
	_start.disabled = left > 0
	_start.modulate.a = 0.45 if left > 0 else 1.0
	for i in counts.size():
		_minus[i].modulate.a = 1.0 if counts[i] > 0 else 0.4
		_plus[i].modulate.a = 1.0 if left > 0 else 0.4
		_cards[i].queue_redraw()


func _leave(go: bool) -> void:
	if _gone or (go and _remaining() > 0):
		return
	_gone = true
	if go:
		start.emit(counts.duplicate())
	else:
		home.emit()


func relayout() -> void:
	var R := Kit.R
	var w := minf(size.x - pad.x * 2, R * 62)
	var x0 := (size.x - w) / 2
	var gap := R * 1.0
	var cols := 2 if portrait() else 3
	var rows := ceili(counts.size() / float(cols))
	var cw := (w - gap * (cols - 1)) / cols
	var ch := R * 10.3
	var title_h := _title.get_combined_minimum_size().y
	var lw := minf(w, R * 50)
	var line_h := Kit.wrapped_height(_line, lw)
	_start.size = _start.get_combined_minimum_size()
	_home.size = _home.get_combined_minimum_size()
	var total := title_h + R * 0.3 + line_h + R * 0.9 + rows * ch + (rows - 1) * gap + R * 0.8 + R * 2.0 + R * 0.5 + _start.size.y
	var y := maxf(pad.y, (size.y - total) / 2)
	Kit.place(_title, Vector2(pad.x, y), size.x - pad.x * 2)
	y += title_h + R * 0.3
	Kit.place(_line, Vector2((size.x - lw) / 2, y), lw)
	y += line_h + R * 0.9
	for i in counts.size():
		var d := _cards[i]
		d.position = Vector2(x0 + (i % cols) * (cw + gap), y + (i / cols) * (ch + gap))
		d.size = Vector2(cw, ch)
		var bw := (cw - R * 2.6) / 2
		# 단추는 제 최소 높이가 있어 적어 준 높이보다 커진다. 실제 높이로 카드 아랫선에서 띄운다
		_minus[i].size = Vector2(bw, R * 2.3)
		_plus[i].size = Vector2(bw, R * 2.3)
		var by := ch - _minus[i].size.y - R * 0.9
		_minus[i].position = Vector2(R * 1.0, by)
		_plus[i].position = Vector2(R * 1.6 + bw, by)
	y += rows * ch + (rows - 1) * gap + R * 0.8
	Kit.place(_left, Vector2(pad.x, y), size.x - pad.x * 2)
	y += R * 2.0 + R * 0.5
	var bw2 := _home.size.x + R * 1.0 + _start.size.x
	_home.position = Vector2((size.x - bw2) / 2, y + (_start.size.y - _home.size.y) / 2)
	_start.position = Vector2(_home.position.x + _home.size.x + R * 1.0, y)


func enter() -> void:
	rise_in(_title)
	rise_in(_line, 0.1)
	for i in _cards.size():
		rise_in(_cards[i], 0.15 + i * 0.05)
	rise_in(_left, 0.5)
	rise_in(_start, 0.6)
	rise_in(_home, 0.6)


## 친구 카드: 이름 띠, 한 줄 소개와 준 판 수, 전체 가운데 얼마인지 막대
func _paint_card(ci: Drawn, i: int) -> void:
	var R := Kit.R
	var kind: String = SelfPlay.CONTEST_FRIENDS[i]
	var col := RankBoard.friend_color(kind)
	var r := Rect2(Vector2.ZERO, ci.size)
	Kit.rrect(ci, Rect2(r.position + Vector2(0, R * 0.35), r.size), Kit.LINE, R * 0.7)
	Kit.rrect(ci, r, Kit.CREAM, R * 0.7)
	var head := Rect2(r.position, Vector2(r.size.x, R * 2.1))
	var hs := Kit.box(col, 0)
	hs.corner_radius_top_left = int(R * 0.7)
	hs.corner_radius_top_right = int(R * 0.7)
	ci.draw_style_box(hs, head)
	Kit.text(ci, Kit.F_TITLE, minf(R * 1.15, r.size.x * 0.068), SelfPlay.FRIEND_NAMES[kind], head, Kit.CREAM)
	var n: int = counts[i]
	Kit.text(ci, Kit.F_BODY, minf(R * 0.95, r.size.x * 0.05), SelfPlay.FRIEND_TRAITS[kind], Rect2(R * 1.0, R * 2.4, r.size.x * 0.5, R * 2.2), Kit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	Kit.text(ci, Kit.F_TITLE, R * 1.9, "%d판" % n, Rect2(r.size.x * 0.5, R * 2.3, r.size.x * 0.5 - R * 1.0, R * 2.4), Kit.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	# 막대: 연습 전체 가운데 이 친구 몫
	var bar := Rect2(R * 1.0, R * 5.0, r.size.x - R * 2.0, R * 0.7)
	Kit.rrect(ci, bar, Kit.TRAY, R * 0.35)
	if n > 0:
		Kit.rrect(ci, Rect2(bar.position, Vector2(maxf(bar.size.y, bar.size.x * n / SelfPlay.CONTEST_GAMES), bar.size.y)), col, R * 0.35)
