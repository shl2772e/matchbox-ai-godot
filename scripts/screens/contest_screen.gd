class_name ContestScreen
extends ScreenBase
## AI 키우기 대회 2: 시험 → 점수 → 이름 적기 → 순위표.
## 같은 계획으로 키운 AI 다섯 대(첫 대는 연습 화면에서 키운 것)가 시험관 세 명과 100판씩 둔다.
## 이기면 3점, 비기면 1점. 점수는 다섯 대의 평균 (최고 900점). 여러 대의 평균을 내는 것은 운을 줄이기 위해서다.
## 시험 때 AI는 배우지 않고, 구슬이 가장 많은 칸을 고른다.

signal home
signal again
signal scored(score: int)

var counts: Array
var ranking: Array
var phase := "exam"
var score := 0
var my_rank := -1

var _plan: Array = []
var _brain: Dictionary
var _rng := SeededRng.for_game()
var _ai := 0
var _train_left := 0
var _kind_i := 0
var _exam_left := SelfPlay.CONTEST_EXAM_EACH
var _points := 0
var _games_done := 0
var _games_all := 0
var _tally := {}

var _title: Label
var _sub: Label
var _tally_view: Drawn
var _score: Label
var _rank: Label
var _name: Label
var _pad: HangulPad
var _save: Button
var _skip: Button
var _board: Drawn
var _again: Button
var _home: Button
var _gone := false


func _init(first_brain: Dictionary, plan_counts: Array, rank_list: Array) -> void:
	_brain = first_brain
	counts = plan_counts
	ranking = rank_list
	for i in 3:
		for n in int(counts[i]):
			_plan.append(SelfPlay.CONTEST_KINDS[i])
	for kind in SelfPlay.CONTEST_KINDS:
		_tally[kind] = {"ai": 0, "draw": 0, "kid": 0}
	var team := SelfPlay.CONTEST_TEAM
	_games_all = (team - 1) * SelfPlay.CONTEST_GAMES + team * 3 * SelfPlay.CONTEST_EXAM_EACH


func build() -> void:
	var R := Kit.R
	_title = Kit.label("시험을 보고 있어요", Kit.F_TITLE, R * 2.4, Kit.NAVY, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_title)
	_sub = Kit.label("같은 계획으로 키운 AI %d대가 시험관 세 명과 %d판씩 둬요. 이기면 3점, 비기면 1점이에요." % [SelfPlay.CONTEST_TEAM, SelfPlay.CONTEST_EXAM_EACH], Kit.F_BODY, R * 1.25, Kit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	add_child(_sub)
	_tally_view = Drawn.new(_paint_tally)
	add_child(_tally_view)
	_score = Kit.label("", Kit.F_TITLE, R * 4.6, Kit.RED_INK, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_score)
	_rank = Kit.label("", Kit.F_LABEL, R * 1.5, Kit.NAVY, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_rank)
	_name = Kit.label("", Kit.F_BOLD, R * 1.8, Kit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	var st := Kit.box(Kit.CREAM, R * 0.6, R * 0.14, Kit.NAVY)
	_name.add_theme_stylebox_override("normal", st)
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_name)
	_pad = HangulPad.new()
	_pad.changed.connect(_on_name)
	add_child(_pad)
	_save = Kit.button("순위표에 올리기", "primary", true)
	_save.pressed.connect(_submit.bind(true))
	add_child(_save)
	_skip = Kit.button("이름 없이 넘어가기", "soft")
	_skip.pressed.connect(_submit.bind(false))
	add_child(_skip)
	_board = Drawn.new(_paint_board)
	add_child(_board)
	_again = Kit.button("다시 도전", "primary", true)
	_again.pressed.connect(_leave.bind(again))
	add_child(_again)
	_home = Kit.button("처음으로", "soft", true)
	_home.pressed.connect(_leave.bind(home))
	add_child(_home)
	_on_name("")
	_show_phase()


func _show_phase() -> void:
	var s := phase == "score"
	var b := phase == "board"
	_sub.visible = not b
	_tally_view.visible = not b
	_score.visible = s
	_rank.visible = s
	_name.visible = s
	_pad.visible = s
	_save.visible = s
	_skip.visible = s
	_board.visible = b
	_again.visible = b
	_home.visible = b
	if _built:
		relayout()


func _on_name(t: String) -> void:
	_name.text = t if t != "" else "이름을 적어요"
	_name.label_settings.font_color = Kit.INK if t != "" else Kit.INK_SOFT
	_save.disabled = t == ""
	_save.modulate.a = 0.45 if t == "" else 1.0


func relayout() -> void:
	var R := Kit.R
	var w := minf(size.x - pad.x * 2, R * 62)
	var x0 := (size.x - w) / 2
	var y := pad.y + R * 0.8
	y += Kit.place(_title, Vector2(pad.x, y), size.x - pad.x * 2) + R * 0.3
	if phase == "board":
		var bw := minf(w, R * 40)
		_again.size = _again.get_combined_minimum_size()
		_home.size = _home.get_combined_minimum_size()
		var by := size.y - pad.y - _again.size.y - R * 0.6
		_board.position = Vector2((size.x - bw) / 2, y + R * 0.6)
		_board.size = Vector2(bw, by - R * 1.2 - _board.position.y)
		var tw := _home.size.x + R + _again.size.x
		_home.position = Vector2((size.x - tw) / 2, by + (_again.size.y - _home.size.y) / 2)
		_again.position = Vector2(_home.position.x + _home.size.x + R, by)
		return
	var lw := minf(w, R * 50)
	y += Kit.place(_sub, Vector2((size.x - lw) / 2, y), lw) + R * 1.0
	if phase == "exam":
		var tw := minf(w, R * 46)
		_tally_view.position = Vector2((size.x - tw) / 2, y + R * 1.0)
		_tally_view.size = Vector2(tw, R * 15)
		return
	# 점수: 왼쪽에 점수와 시험 결과, 오른쪽에 이름 자판
	var ps := HangulPad.wanted_size()
	var left_w := w - ps.x - R * 2.4
	_score.size = Vector2(left_w, R * 6.0)
	_score.position = Vector2(x0, y)
	_rank.size = Vector2(left_w, R * 2.0)
	_rank.position = Vector2(x0, y + R * 6.0)
	_tally_view.position = Vector2(x0, y + R * 8.6)
	_tally_view.size = Vector2(left_w, R * 12)
	var rx := x0 + left_w + R * 2.4
	_name.position = Vector2(rx, y + R * 0.6)
	_name.size = Vector2(ps.x, R * 3.2)
	_pad.position = Vector2(rx, y + R * 4.6)
	_pad.size = ps
	_save.size = _save.get_combined_minimum_size()
	_skip.size = _skip.get_combined_minimum_size()
	var by := _pad.position.y + ps.y + R * 1.0
	_save.position = Vector2(rx + ps.x - _save.size.x, by)
	_skip.position = Vector2(rx, by + (_save.size.y - _skip.size.y) / 2)


func enter() -> void:
	rise_in(_title)
	rise_in(_sub, 0.1)
	rise_in(_tally_view, 0.2)


## 장면마다 8밀리초만큼만 판을 둔다 (느린 기계에서도 화면이 멈추지 않게)
func _process(_delta: float) -> void:
	if phase != "exam":
		return
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 8000:
		if not _step():
			_finish_exam()
			break
	_tally_view.queue_redraw()


## 판 하나를 둔다. 다 끝났으면 false
func _step() -> bool:
	if _train_left > 0:
		SelfPlay.play_one(_brain, _plan[floori(_rng.next() * _plan.size())], _rng)
		_train_left -= 1
		_games_done += 1
		return true
	if _exam_left <= 0:
		_kind_i += 1
		_exam_left = SelfPlay.CONTEST_EXAM_EACH
		if _kind_i >= 3:
			# 다음 AI: 같은 계획으로 처음부터 새로 키운다
			_ai += 1
			if _ai >= SelfPlay.CONTEST_TEAM:
				return false
			_kind_i = 0
			_brain = Menace.new_brain()
			_train_left = SelfPlay.CONTEST_GAMES
			return true
	var kind: String = SelfPlay.CONTEST_KINDS[_kind_i]
	var p := SelfPlay.contest_point(_brain, kind, _rng)
	_points += p
	_tally[kind]["ai" if p == 3 else ("draw" if p == 1 else "kid")] += 1
	_exam_left -= 1
	_games_done += 1
	return true


func _finish_exam() -> void:
	score = roundi(_points / float(SelfPlay.CONTEST_TEAM))
	phase = "score"
	Kit.set_text(_title, "내 AI의 점수")
	Kit.set_text(_sub, "AI %d대의 평균 점수예요. 이긴 판 3점, 비긴 판 1점, 가장 높은 점수는 900점이에요." % SelfPlay.CONTEST_TEAM)
	var place := 1
	for e in RankBoard.today(ranking):
		if e.score >= score:
			place += 1
	_rank.text = "오늘 %d등이에요" % place
	Sfx.grad()
	scored.emit(score)
	_show_phase()
	create_tween().tween_method(_count_up, 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _count_up(p: float) -> void:
	_score.text = "%d점" % roundi(score * p)


func _submit(with_name: bool) -> void:
	if phase != "score":
		return
	if with_name and _pad.text() != "":
		var entry := {"name": _pad.text(), "score": score, "plan": counts.duplicate(), "date": Today.date_key()}
		Store.add_ranking(ranking, entry)
		my_rank = RankBoard.today(ranking).find(entry)
	phase = "board"
	Kit.set_text(_title, "AI 키우기 대회")
	_show_phase()
	later(40.0, _leave.bind(home))


func _leave(sig: Signal) -> void:
	if _gone:
		return
	_gone = true
	sig.emit()


## 시험관마다 한 줄: 이름, 이긴 판·비긴 판·진 판 막대. 시험 중에는 맨 아래에 진행 막대
func _paint_tally(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	Kit.rrect(ci, Rect2(r.position + Vector2(0, R * 0.35), r.size), Kit.LINE, R * 0.8)
	Kit.rrect(ci, r, Kit.CREAM, R * 0.8)
	var foot := R * 2.6
	var row_h := (r.size.y - R * 1.2 - foot) / 3
	var name_w := minf(R * 12, r.size.x * 0.36)
	var all := SelfPlay.CONTEST_TEAM * SelfPlay.CONTEST_EXAM_EACH
	for i in 3:
		var kind: String = SelfPlay.CONTEST_KINDS[i]
		var t: Dictionary = _tally[kind]
		var y := R * 0.8 + i * row_h
		Kit.text(ci, Kit.F_LABEL, minf(R * 1.1, name_w * 0.085), SelfPlay.CONTEST_NAMES[kind], Rect2(R * 1.2, y, name_w, row_h), Kit.INK, HORIZONTAL_ALIGNMENT_LEFT)
		var bar := Rect2(R * 1.2 + name_w, y + row_h * 0.25, r.size.x - name_w - R * 2.4, row_h * 0.5)
		Kit.rrect(ci, bar, Kit.TRAY, R * 0.3)
		var x := bar.position.x
		for part in [["ai", Kit.RED], ["draw", Kit.MUSTARD], ["kid", Kit.NAVY]]:
			var pw: float = bar.size.x * t[part[0]] / all
			if pw > 0.5:
				ci.draw_rect(Rect2(x, bar.position.y, pw, bar.size.y), part[1])
				if pw > R * 2.2:
					Kit.text(ci, Kit.F_LABEL, R * 0.95, str(t[part[0]]), Rect2(x, bar.position.y, pw, bar.size.y), Kit.CREAM)
				x += pw
	var fy := r.size.y - foot
	if phase == "exam":
		var bar := Rect2(R * 1.2, fy + R * 0.7, r.size.x - R * 2.4, R * 0.8)
		Kit.rrect(ci, bar, Kit.TRAY, R * 0.4)
		Kit.rrect(ci, Rect2(bar.position, Vector2(maxf(bar.size.y, bar.size.x * _games_done / maxi(_games_all, 1)), bar.size.y)), Kit.TEAL, R * 0.4)
	else:
		var x := R * 1.2
		for part in [["AI가 이긴 판", Kit.RED], ["비긴 판", Kit.MUSTARD], ["AI가 진 판", Kit.NAVY]]:
			Kit.rrect(ci, Rect2(x, fy + R * 0.8, R * 0.8, R * 0.8), part[1], R * 0.15)
			var word: String = part[0]
			var tw := Kit.F_LABEL.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, int(R * 0.95)).x
			Kit.text(ci, Kit.F_LABEL, R * 0.95, word, Rect2(x + R * 1.1, fy + R * 0.4, tw + R, R * 1.6), Kit.INK, HORIZONTAL_ALIGNMENT_LEFT)
			x += R * 2.4 + tw


func _paint_board(ci: Drawn) -> void:
	RankBoard.paint(ci, Rect2(Vector2.ZERO, ci.size), RankBoard.today(ranking), 10, "오늘의 순위", my_rank)
