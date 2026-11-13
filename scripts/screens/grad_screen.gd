class_name GradScreen
extends ScreenBase
## 졸업장 (새 흐름의 마지막 화면).
## - 칭호: 내가 준 상과 벌에 따라 붙는 이름 (순위표는 없다)
## - 처음 상자와 지금 상자를 나란히: 첫 상자의 구슬이 실제로 어떻게 바뀌었나
## - "이게 강화학습이에요": 여기서 처음 이 낱말이 나온다. 요즘 AI와 잇는다
## - 한 문제: "AI가 진 다음, 그 칸의 구슬은?" (평가 지표의 원리 이해 문항)
## - 한 번 더 / 더 알아보기(1961년 이야기) / 처음으로

signal home
signal again
signal more
signal answered(choice: String, correct: bool)

const START := [4, 4, 4, 4, 4, 4, 4, 4, 4]
const CHOICES := [["늘어난다", "up"], ["줄어든다", "down"], ["그대로다", "same"]]

var score: Dictionary
var now_beads: Array
var exam: String
var trained: int
var percent: bool

var _title: Label
var _sub: Label
var _pills: Array[Label] = []
var _left: Drawn
var _left_line: Label
var _right: Panel
var _right_items: Array[Label] = []
var _quiz: Panel
var _quiz_q: Label
var _quiz_buttons: Array[Button] = []
var _quiz_a: Label
var _bs := Kit.R * 9.0
var _again: Button
var _more: Button
var _home: Button
var _gone := false


func _init(s: Dictionary, beads: Array, exam_outcome: String, trained_games: int, show_percent: bool) -> void:
	score = s
	now_beads = beads
	exam = exam_outcome
	trained = trained_games
	percent = show_percent


## 내가 준 상과 벌로 정하는 칭호
func nickname() -> String:
	if score.kid >= 2:
		return "엄한 선생님"
	if score.ai >= 2:
		return "칭찬 많은 선생님"
	if score.draw >= 2:
		return "끈기 있는 선생님"
	return "골고루 가르친 선생님"


## 첫 상자에서 가장 많이 바뀐 칸을 실제 수로 말한다
func _change_line() -> String:
	var best := 0
	for i in 9:
		if absi(now_beads[i] - START[i]) > absi(now_beads[best] - START[best]):
			best = i
	var a: int = START[best]
	var b: int = now_beads[best]
	if b > a:
		return "%s 칸 구슬이 %d개에서 %d개로 늘었어요. AI가 이 칸을 좋아하게 됐어요." % [Ttt.CELL_NAMES[best], a, b]
	if b < a:
		return "%s 칸 구슬이 %d개에서 %d개로 줄었어요. AI가 이 칸을 피하게 됐어요." % [Ttt.CELL_NAMES[best], a, b]
	return "첫 상자의 구슬은 그대로예요."


func build() -> void:
	var R := Kit.R
	_title = Kit.label("AI 졸업장", Kit.F_TITLE, R * 2.2, Kit.NAVY, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_title)
	var sub := "AI가 졸업 시험에서 이겼어요. 내가 잘 가르쳤어요. "
	if exam == "draw":
		sub = "졸업 시험에서 AI와 비겼어요. 아주 잘한 거예요. "
	elif exam == "kid":
		sub = "졸업 시험에서 AI를 이겼어요. 정말 대단해요. "
	_sub = Kit.label(sub + "나는 \"%s\"이에요." % nickname(), Kit.F_BODY, R * 1.3, Kit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	add_child(_sub)
	for p in [["나 %d" % score.kid, "kid"], ["비김 %d" % score.draw, "draw"], ["AI %d" % score.ai, "ai"]]:
		var l := Kit.pill(p[0], p[1], 1.3)
		_pills.append(l)
		add_child(l)
	_left = Drawn.new(_paint_left)
	add_child(_left)
	_left_line = Kit.label(_change_line(), Kit.F_BODY, R * 1.15, Kit.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	_left.add_child(_left_line)
	_right = Panel.new()
	var st := Kit.box(Kit.NAVY, R * 0.8)
	st.shadow_color = Kit.LINE
	st.shadow_offset = Vector2(0, R * 0.4)
	_right.add_theme_stylebox_override("panel", st)
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_right)
	var lines := [
		["이게 강화학습이에요", Kit.F_TITLE, 1.6, Kit.MUSTARD],
		["AI는 정답을 배운 게 아니에요. 해 보고, 결과가 좋으면 더 하고, 나쁘면 덜 해요.", Kit.F_BODY, 1.2, Kit.CREAM],
		["요즘 게임 AI도 구슬 대신 숫자로 똑같이 배워요. 그래서 상을 잘못 주면 AI도 잘못 배워요.", Kit.F_BODY, 1.2, Kit.CREAM],
	]
	if percent:
		lines.append(["판 모양은 \"상태\", 둔 칸은 \"행동\", 구슬로 주는 상과 벌은 \"보상\"이라고 불러요.", Kit.F_BODY, 1.1, Kit.CREAM])
	for ln in lines:
		var l := Kit.label(ln[0], ln[1], R * ln[2], ln[3], HORIZONTAL_ALIGNMENT_LEFT, true)
		l.label_settings.line_spacing = R * 0.45
		_right.add_child(l)
		_right_items.append(l)
	_quiz = Panel.new()
	var qs := Kit.box(Kit.CREAM, R * 0.8, R * 0.11, Kit.LINE)
	_quiz.add_theme_stylebox_override("panel", qs)
	add_child(_quiz)
	_quiz_q = Kit.label("한 문제! AI가 진 다음, AI가 둔 칸의 구슬은 어떻게 될까요?", Kit.F_BOLD, R * 1.25, Kit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	_quiz.add_child(_quiz_q)
	for c in CHOICES:
		var b := Kit.button(c[0], "soft")
		b.custom_minimum_size.x = R * 7.5
		b.pressed.connect(_answer.bind(c[1], b))
		_quiz.add_child(b)
		_quiz_buttons.append(b)
	_quiz_a = Kit.label("", Kit.F_BODY, R * 1.2, Kit.TEAL, HORIZONTAL_ALIGNMENT_CENTER, true)
	_quiz_a.visible = false
	_quiz.add_child(_quiz_a)
	var hint := Kit.label("다음에는 일부러 져 볼까요? 그러면 AI는 무엇을 배울까요?", Kit.F_BODY, R * 1.1, Kit.MUSTARD, HORIZONTAL_ALIGNMENT_LEFT, true)
	_right.add_child(hint)
	_right_items.append(hint)
	_again = Kit.button("한 번 더 하기", "soft", true)
	_again.pressed.connect(_leave.bind(again))
	add_child(_again)
	_more = Kit.button("1961년 이야기 보기", "soft", true)
	_more.pressed.connect(_leave.bind(more))
	add_child(_more)
	_home = Kit.button("처음으로", "primary", true)
	_home.pressed.connect(_leave.bind(home))
	add_child(_home)


func _answer(choice: String, pressed: Button) -> void:
	if _quiz_a.visible:
		return
	var ok := choice == "down"
	for b in _quiz_buttons:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.modulate.a = 1.0 if b == pressed or b == _quiz_buttons[1] else 0.45
	Kit.set_text(_quiz_a, ("맞아요. " if ok else "") + "AI가 지면 그 칸의 구슬을 1개 빼요. 그래서 줄어들어요.")
	_quiz_a.visible = true
	Sfx.learn()
	answered.emit(choice, ok)
	relayout()


func _leave(sig: Signal) -> void:
	if _gone:
		return
	_gone = true
	sig.emit()


func relayout() -> void:
	var R := Kit.R
	var w := minf(size.x - pad.x * 2, R * 62)
	var x0 := (size.x - w) / 2
	var vertical := portrait()
	var y := pad.y + R * (2.0 if vertical else 0.6)
	y += Kit.place(_title, Vector2(pad.x, y), size.x - pad.x * 2) + R * 0.2
	y += Kit.place(_sub, Vector2(x0, y), w) + R * 0.6
	var pw := 0.0
	for l in _pills:
		l.size = l.get_combined_minimum_size()
		pw += l.size.x
	pw += R * 0.6 * (_pills.size() - 1)
	var px := (size.x - pw) / 2
	for l in _pills:
		l.position = Vector2(px, y)
		px += l.size.x + R * 0.6
	y += _pills[0].size.y + R * 0.9
	# 두 카드: 처음·지금 상자 / 강화학습
	var gap := R * 1.2
	var cw := w if vertical else (w - gap) / 2
	# 상자 그림은 자리가 되는 만큼 크게 (세로 화면은 더 크게)
	_bs = minf(R * (12.0 if vertical else 9.0), (cw - R * 5.0) / 2)
	var box_h := _bs
	var left_h := R * 1.0 + box_h + R * 0.7 + Kit.wrapped_height(_left_line, cw - R * 2.4) + R * 1.0
	var ry := R * 1.2
	for l in _right_items:
		ry += Kit.place(l, Vector2(R * 1.4, ry), cw - R * 2.8) + R * 0.6
	var right_h := ry + R * 0.5
	var ch := maxf(left_h, right_h)
	_left.position = Vector2(x0, y)
	_left.size = Vector2(cw, left_h if vertical else ch)
	Kit.place(_left_line, Vector2(R * 1.2, R * 1.0 + box_h + R * 0.7), cw - R * 2.4)
	_right.position = Vector2(x0, y + left_h + gap) if vertical else Vector2(x0 + cw + gap, y)
	_right.size = Vector2(cw, right_h if vertical else ch)
	y += (left_h + gap + right_h) if vertical else ch
	y += R * 1.1
	# 한 문제
	var qy := R * 0.8
	var bw := 0.0
	for b in _quiz_buttons:
		b.size = b.get_combined_minimum_size()
		bw += b.size.x
	bw += R * 1.0 * (_quiz_buttons.size() - 1)
	var bh: float = _quiz_buttons[0].size.y
	var bx := (w - bw) / 2
	if vertical:
		qy += Kit.place(_quiz_q, Vector2(R * 1.2, qy), w - R * 2.4) + R * 0.6
	else:
		# 가로 화면: 왼쪽에 물음, 오른쪽에 단추 (세로로 자리를 덜 쓴다)
		var qw := w - bw - R * 3.6
		var qh := Kit.wrapped_height(_quiz_q, qw)
		var row := maxf(qh, bh)
		Kit.place(_quiz_q, Vector2(R * 1.2, qy + (row - qh) / 2), qw)
		bx = w - bw - R * 1.2
		qy += (row - bh) / 2
	for b in _quiz_buttons:
		b.position = Vector2(bx, qy)
		bx += b.size.x + R * 1.0
	qy += bh + R * 0.7
	if _quiz_a.visible:
		qy += Kit.place(_quiz_a, Vector2(R * 1.2, qy), w - R * 2.4) + R * 0.5
	_quiz.position = Vector2(x0, y)
	_quiz.size = Vector2(w, qy + R * 0.3)
	y += _quiz.size.y + R * 0.7
	var buttons: Array[Button] = [_again, _more, _home]
	var tw := 0.0
	for b in buttons:
		b.size = b.get_combined_minimum_size()
		tw += b.size.x
	tw += R * 1.0 * (buttons.size() - 1)
	var hx := (size.x - tw) / 2
	for b in buttons:
		b.position = Vector2(hx, y)
		hx += b.size.x + R * 1.0


func enter() -> void:
	Sfx.grad()
	rise_in(_title)
	rise_in(_sub, 0.1)
	for l in _pills:
		rise_in(l, 0.15)
	rise_in(_left, 0.25)
	rise_in(_right, 0.35)
	rise_in(_quiz, 0.5)
	for b in [_again, _more, _home]:
		rise_in(b, 0.7)
	later(50.0, _leave.bind(home))


## 처음 상자와 지금 상자 (가운데 세모가 "처음에서 지금으로"를 가리킨다)
func _paint_left(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	Kit.rrect(ci, Rect2(r.position + Vector2(0, R * 0.4), r.size), Kit.LINE, R * 0.8)
	Kit.rrect(ci, r, Kit.CREAM, R * 0.8)
	var bs := _bs
	var arrow := R * 2.6
	var x := (r.size.x - bs * 2 - arrow) / 2
	TrainScreen.paint_first_box(ci, Rect2(x, R * 1.0, bs, bs), START, "처음 첫 상자")
	TrainScreen.paint_first_box(ci, Rect2(x + bs + arrow, R * 1.0, bs, bs), now_beads, "지금 첫 상자")
	var ac := Vector2(x + bs + arrow / 2, R * 1.0 + bs / 2)
	ci.draw_colored_polygon(PackedVector2Array([ac + Vector2(-R * 0.5, -R * 0.7), ac + Vector2(R * 0.7, 0), ac + Vector2(-R * 0.5, R * 0.7)]), Kit.MUSTARD)
