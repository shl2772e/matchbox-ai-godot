class_name ResultScreen
extends ScreenBase
## 결과: 오늘의 대결 점수, 바뀐 구슬 수(세며 올라감), 강화학습 한 줄 설명.

signal home

var score: Dictionary
var changes: Array
var today_games: int

var _title: Label
var _pills: Array[Label] = []
var _cards: Array[Panel] = []
var _texts: Array = []
var _up: Label
var _down: Label
var _home: Button
var _plus := 0
var _minus := 0
var _gone := false


func _init(s: Dictionary, ch: Array, games: int) -> void:
	score = s
	changes = ch
	today_games = games
	for c in changes:
		_plus += maxi(0, c.after - c.before)
		_minus += maxi(0, c.before - c.after)


func build() -> void:
	var R := Kit.R
	_title = Kit.label("오늘의 대결 결과", Kit.F_TITLE, R * 2.8, Kit.NAVY, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_title)
	for p in [["나 %d" % score.kid, "kid"], ["비김 %d" % score.draw, "draw"], ["AI %d" % score.ai, "ai"]]:
		var l := Kit.pill(p[0], p[1], 1.6)
		_pills.append(l)
		add_child(l)
	var principle := "비긴 수에도 구슬이 하나씩 늘어요. AI는 지지 않는 법부터 배워요."
	if score.kid > 0:
		principle = "네가 이긴 판에서 AI는 그 수의 구슬을 잃었어요. 다음 친구에게는 그 수를 덜 둘 거예요."
	elif score.ai > 0:
		principle = "AI가 이긴 수에는 구슬이 3개씩 늘었어요. 그 수는 점점 더 자주 나와요."
	_up = Kit.label("늘어난 구슬 0개", Kit.F_LABEL, R * 1.6, Kit.TEAL)
	_down = Kit.label("빠진 구슬 0개", Kit.F_LABEL, R * 1.6, Kit.RED_INK)
	var specs := [
		[Kit.CREAM, "너와 둔 판으로 바뀐 구슬", Kit.NAVY, Kit.INK, [principle]],
		[Kit.NAVY, "이게 강화학습이에요", Kit.MUSTARD, Kit.CREAM, ["AI는 정답을 미리 아는 게 아니라, 해 보고 결과로 배워요. 잘된 선택은 더 자주, 안된 선택은 덜 하도록 스스로 고쳐요.", "오늘 %d번째 판까지 여러분이 함께 AI를 가르쳤어요." % today_games]],
	]
	for i in specs.size():
		var sp: Array = specs[i]
		var p := Panel.new()
		var st := Kit.box(sp[0], R * 0.8)
		st.shadow_color = Kit.LINE
		st.shadow_offset = Vector2(0, R * 0.4)
		p.add_theme_stylebox_override("panel", st)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		_cards.append(p)
		var items: Array = [Kit.label(sp[1], Kit.F_TITLE, R * 1.7, sp[2], HORIZONTAL_ALIGNMENT_LEFT, true)]
		if i == 0:
			items.append(_up)
			items.append(_down)
		for s in sp[4]:
			var l := Kit.label(s, Kit.F_BODY, R * (1.35 if s != sp[4][-1] or i == 0 else 1.15), sp[3], HORIZONTAL_ALIGNMENT_LEFT, true)
			l.label_settings.line_spacing = R * 0.55
			items.append(l)
		for l in items:
			p.add_child(l)
		_texts.append(items)
	_home = Kit.button("처음으로", "primary", true)
	_home.pressed.connect(_go)
	add_child(_home)


func _go() -> void:
	if _gone:
		return
	_gone = true
	home.emit()


func relayout() -> void:
	var R := Kit.R
	var w := minf(size.x - pad.x * 2, R * 60)
	var vertical := portrait()
	var gap := R * 1.4
	var cw := w if vertical else (w - gap) / 2
	var inner := cw - R * 3.2
	var heights := []
	for i in _cards.size():
		var items: Array = _texts[i]
		var y := R * 1.5
		for l in items:
			if l == _up:
				_up.size = _up.get_combined_minimum_size()
				_up.position = Vector2(R * 1.6, y)
				_down.size = _down.get_combined_minimum_size()
				_down.position = Vector2(R * 1.6 + R * 11, y)
				continue
			if l == _down:
				y += _up.size.y + R * 0.8
				continue
			y += Kit.place(l, Vector2(R * 1.6, y), inner) + R * 0.8
		heights.append(y + R * 0.7)
	var ch: float = heights.max() if not vertical else 0.0
	var title_h := _title.get_combined_minimum_size().y
	var pill_h := _pills[0].get_combined_minimum_size().y
	var bh := _home.get_combined_minimum_size().y
	var body_h: float = ch if not vertical else heights[0] + gap + heights[1]
	var total := title_h + R * 1.0 + pill_h + R * 1.6 + body_h + R * 2.0 + bh
	var y0 := (size.y - total) / 2
	Kit.place(_title, Vector2(pad.x, y0), size.x - pad.x * 2)
	y0 += title_h + R * 1.0
	var pw := 0.0
	for l in _pills:
		l.size = l.get_combined_minimum_size()
		pw += l.size.x
	pw += R * 0.7 * (_pills.size() - 1)
	var px := (size.x - pw) / 2
	for l in _pills:
		l.position = Vector2(px, y0)
		px += l.size.x + R * 0.7
	y0 += pill_h + R * 1.6
	var x0 := (size.x - w) / 2
	for i in _cards.size():
		var h: float = heights[i] if vertical else ch
		if vertical:
			_cards[i].position = Vector2(x0, y0 + (0.0 if i == 0 else heights[0] + gap))
		else:
			_cards[i].position = Vector2(x0 + i * (cw + gap), y0)
		_cards[i].size = Vector2(cw, h)
	y0 += body_h + R * 2.0
	_home.size = _home.get_combined_minimum_size()
	_home.position = Vector2((size.x - _home.size.x) / 2, y0)


func enter() -> void:
	rise_in(_title)
	for l in _pills:
		rise_in(l, 0.1)
	rise_in(_cards[0], 0.25)
	rise_in(_cards[1], 0.4)
	rise_in(_home, 0.55)
	var tw := create_tween().set_parallel()
	tw.tween_method(_count_up, 0.0, 1.0, 1.0).set_delay(0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	later(20.0, _go)


func _count_up(p: float) -> void:
	_up.text = "늘어난 구슬 %d개" % roundi(_plus * p)
	_down.text = "빠진 구슬 %d개" % roundi(_minus * p)
