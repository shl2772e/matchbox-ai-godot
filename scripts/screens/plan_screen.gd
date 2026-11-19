class_name PlanScreen
extends ScreenBase
## AI 키우기 대회 1: 연습 계획 세우기. 연습 600판을 칸 6개(100판씩)로 나눠 세 친구에게 준다.
## 누구와 연습했느냐에 따라 AI 실력이 달라진다는 것을 점수로 겪게 한다.
## (시뮬레이션: 아주 잘 두는 친구하고만 연습하면 꼴찌에 가깝고, 여러 친구를 섞은 계획이 1위다)

signal start(counts: Array)
signal home

const TRAITS := {
	"random": "어디에 둘지 아무도 몰라요",
	"careful": "이길 수 있으면 이기고, 막을 수 있으면 막아요",
	"perfect": "절대 지지 않고, 함정도 파요",
}
const COLORS := {"random": Kit.MUSTARD, "careful": Kit.TEAL, "perfect": Kit.RED}

var counts := [2, 2, 2]

var _title: Label
var _line: Label
var _cards: Array[Drawn] = []
var _minus: Array[Button] = []
var _plus: Array[Button] = []
var _left: Label
var _start: Button
var _home: Button
var _gone := false


func build() -> void:
	var R := Kit.R
	_title = Kit.label("AI 키우기 대회", Kit.F_TITLE, R * 2.6, Kit.NAVY, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_title)
	_line = Kit.label("새내기 AI가 %d판을 연습해요. 누구와 연습할지 내가 정해요. 칸 %d개를 세 친구에게 나눠 주세요." % [SelfPlay.CONTEST_GAMES, SelfPlay.CONTEST_SLOTS], Kit.F_BODY, R * 1.3, Kit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	add_child(_line)
	for i in 3:
		var d := Drawn.new(_paint_card.bind(i))
		add_child(d)
		_cards.append(d)
		var m := Kit.button("빼기", "danger")
		m.pressed.connect(_change.bind(i, -1))
		d.add_child(m)
		_minus.append(m)
		var p := Kit.button("더하기", "primary")
		p.pressed.connect(_change.bind(i, 1))
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
	return SelfPlay.CONTEST_SLOTS - counts[0] - counts[1] - counts[2]


func _change(i: int, d: int) -> void:
	if d > 0 and _remaining() <= 0:
		return
	if d < 0 and counts[i] <= 0:
		return
	counts[i] += d
	Sfx.tap()
	_refresh()


func _refresh() -> void:
	var left := _remaining()
	_left.text = "남은 칸 %d개" % left if left > 0 else "칸을 모두 나눠 줬어요"
	_left.label_settings.font_color = Kit.RED_INK if left > 0 else Kit.TEAL
	_start.disabled = left > 0
	_start.modulate.a = 0.45 if left > 0 else 1.0
	for i in 3:
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
	var w := minf(size.x - pad.x * 2, R * 60)
	var x0 := (size.x - w) / 2
	var gap := R * 1.4
	var cw := (w - gap * 2) / 3
	var ch := R * 15.5
	var title_h := _title.get_combined_minimum_size().y
	var lw := minf(w, R * 48)
	var line_h := Kit.wrapped_height(_line, lw)
	_start.size = _start.get_combined_minimum_size()
	_home.size = _home.get_combined_minimum_size()
	var total := title_h + R * 0.6 + line_h + R * 1.4 + ch + R * 1.2 + R * 2.0 + R * 1.0 + _start.size.y
	var y := maxf(pad.y, (size.y - total) / 2)
	Kit.place(_title, Vector2(pad.x, y), size.x - pad.x * 2)
	y += title_h + R * 0.6
	Kit.place(_line, Vector2((size.x - lw) / 2, y), lw)
	y += line_h + R * 1.4
	for i in 3:
		var d := _cards[i]
		d.position = Vector2(x0 + i * (cw + gap), y)
		d.size = Vector2(cw, ch)
		var bw := (cw - R * 3.0) / 2
		_minus[i].size = Vector2(bw, R * 2.6)
		_minus[i].position = Vector2(R * 1.2, ch - R * 3.8)
		_plus[i].size = Vector2(bw, R * 2.6)
		_plus[i].position = Vector2(R * 1.8 + bw, ch - R * 3.8)
	y += ch + R * 1.2
	Kit.place(_left, Vector2(pad.x, y), size.x - pad.x * 2)
	y += R * 2.0 + R * 1.0
	var bw2 := _home.size.x + R * 1.0 + _start.size.x
	_home.position = Vector2((size.x - bw2) / 2, y + (_start.size.y - _home.size.y) / 2)
	_start.position = Vector2(_home.position.x + _home.size.x + R * 1.0, y)


func enter() -> void:
	rise_in(_title)
	rise_in(_line, 0.1)
	for i in 3:
		rise_in(_cards[i], 0.2 + i * 0.1)
	rise_in(_left, 0.5)
	rise_in(_start, 0.6)
	rise_in(_home, 0.6)


## 친구 카드: 이름, 한 줄 소개, 준 칸(네모 6개 가운데 몇 개), 판 수
func _paint_card(ci: Drawn, i: int) -> void:
	var R := Kit.R
	var kind: String = SelfPlay.CONTEST_KINDS[i]
	var col: Color = COLORS[kind]
	var r := Rect2(Vector2.ZERO, ci.size)
	Kit.rrect(ci, Rect2(r.position + Vector2(0, R * 0.4), r.size), Kit.LINE, R * 0.8)
	Kit.rrect(ci, r, Kit.CREAM, R * 0.8)
	var head := Rect2(r.position, Vector2(r.size.x, R * 2.6))
	var hs := Kit.box(col, 0)
	hs.corner_radius_top_left = int(R * 0.8)
	hs.corner_radius_top_right = int(R * 0.8)
	ci.draw_style_box(hs, head)
	Kit.text(ci, Kit.F_TITLE, minf(R * 1.3, r.size.x * 0.075), SelfPlay.CONTEST_NAMES[kind], head, Kit.CREAM)
	Kit.text(ci, Kit.F_BODY, minf(R * 1.0, r.size.x * 0.052), TRAITS[kind], Rect2(0, R * 3.0, r.size.x, R * 1.6), Kit.INK_SOFT)
	# 네모 6개: 이 친구에게 준 칸만 색이 찬다
	var n: int = counts[i]
	var sq := R * 1.9
	var sgap := R * 0.4
	var sw := SelfPlay.CONTEST_SLOTS * sq + (SelfPlay.CONTEST_SLOTS - 1) * sgap
	var sx := (r.size.x - sw) / 2
	for k in SelfPlay.CONTEST_SLOTS:
		var cell := Rect2(sx + k * (sq + sgap), R * 5.4, sq, sq)
		Kit.rrect(ci, cell, col if k < n else Kit.TRAY, R * 0.3)
	var per := SelfPlay.CONTEST_GAMES / SelfPlay.CONTEST_SLOTS
	Kit.text(ci, Kit.F_TITLE, R * 2.2, "%d판" % (n * per), Rect2(0, R * 8.0, r.size.x, R * 2.8), Kit.INK)
