extends Control
## 화면 흐름.
##
## 새 흐름 "AI 졸업시키기" (settings.newflow, 기본):
##   대기 → 1단계 새내기(보기) → 내 손으로 상벌 → 2단계 연습생(맞혀 보기) → 상벌
##        → 빨리 감기(AI 혼자 200판) → 3단계 졸업 시험 → 상벌 → 졸업장 → 대기
##   학생마다 아무것도 모르는 새 AI(session_brain)로 시작한다. 학생이 둔 판은 "우리 반 AI"(brain, 저장됨)에도 쌓인다.
##
## 예전 흐름 (선생님 메뉴에서 바꿈, 비교용):
##   대기 → 안내 4장 → (놀이 → 배우는 순간) × 판 수 → 결과 → 대기. 우리 반 AI와 둔다.
##
## F11: 전체화면 켜고 끄기. 60초 동안 아무도 누르지 않으면 대기 화면으로 돌아간다.
## 오른쪽 위 자물쇠는 선생님 메뉴(TeacherLayer)다. 체험 기록은 Telemetry가 남긴다.

const IDLE_MS := 60000
## 대기 화면을 이만큼 그대로 두면 1961년 이야기가 저절로 넘어간다 (기다리는 학생이 본다)
const ATTRACT_MS := 20000

var brain: Dictionary
var today: Dictionary
var settings: Dictionary
var screen: ScreenBase
var round_i := 1
var score := {"kid": 0, "draw": 0, "ai": 0}
var session_changes := []
var teacher: TeacherLayer
## 이번 학생의 AI (새 흐름). 빨리 감기로 연습한 판 수가 trained
var session_brain: Dictionary
var trained := 0
## 이번 체험이 새 흐름인지 (도중에 설정을 바꿔도 끝까지 같은 흐름)
var _flow_new := false
var _last_touch := 0
var _vignette: TextureRect


func _ready() -> void:
	settings = Store.load_settings()
	Sfx.enabled = settings.sound
	brain = Store.load_brain()
	if brain.is_empty():
		if FileAccess.file_exists(Store.BRAIN):
			push_warning("저장된 두뇌를 읽을 수 없어 조금 배운 AI로 새로 시작해요.")
		brain = SelfPlay.trained_brain("some")
		Store.save_brain(brain)
	today = Store.load_today()
	resized.connect(_on_resized)
	_last_touch = Time.get_ticks_msec()
	_make_vignette()
	teacher = TeacherLayer.new()
	teacher.settings = settings
	teacher.brain_games = brain.games
	teacher.version = ProjectSettings.get_setting("application/config/version", "")
	teacher.go_home.connect(to_idle)
	teacher.level_picked.connect(_on_level_picked)
	teacher.setting_changed.connect(_on_setting_changed)
	teacher.clear_today.connect(_on_clear_today)
	add_child(teacher)
	to_idle.call_deferred()
	# 내보낸 실행 파일은 전체화면으로 시작한다 (편집기에서 실행할 때는 창)
	if OS.has_feature("template") and not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa=") and ResourceLoader.exists("res://tests/qa.gd"):
			Telemetry.enabled = false
			Store.frozen = true
			var qa: Node = load("res://tests/qa.gd").new()
			qa.set("out_dir", a.substr(5))
			add_child(qa)


## 화면 가장자리를 살짝 어둡게 (책상 위 스탠드 불빛처럼). 화면들 위, 선생님 메뉴 아래
func _make_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(Kit.INK, 0.0))
	g.set_color(1, Color(Kit.INK, 0.2))
	g.set_offset(0, 0.55)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.z_index = 5
	_vignette.size = size
	add_child(_vignette)


func _on_resized() -> void:
	queue_redraw()
	_vignette.size = size
	for c in get_children():
		if c is ScreenBase:
			c.size = size


## 누런 종이 바탕 + 점무늬
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Kit.PAPER)
	var step := Kit.R * 0.8
	var y := step / 2
	while y < size.y:
		var x := step / 2
		while x < size.x:
			draw_circle(Vector2(x, y), 1.4, Kit.PAPER_DOT)
			x += step
		y += step


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		_last_touch = Time.get_ticks_msec()
		if event is InputEventMouseButton and event.pressed:
			Telemetry.tap()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _last_touch > IDLE_MS and not (screen is IdleScreen) and not teacher.busy():
		_last_touch = Time.get_ticks_msec()
		Telemetry.end("timeout")
		to_idle()
	elif screen is IdleScreen and Time.get_ticks_msec() - _last_touch > ATTRACT_MS and not teacher.busy():
		_show_attract()


## 새 화면으로 바꾼다. 앞 화면은 옅어지며 사라진다
func _show(s: ScreenBase) -> void:
	if screen:
		var old := screen
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		old.process_mode = Node.PROCESS_MODE_DISABLED
		var tw := create_tween()
		tw.tween_property(old, "modulate:a", 0.0, 0.2)
		tw.tween_callback(old.queue_free)
	screen = s
	s.size = size
	add_child(s)
	s.modulate.a = 0.0
	create_tween().tween_property(s, "modulate:a", 1.0, 0.25)


func to_idle() -> void:
	# 끝까지 못 가고 돌아온 체험 (선생님이 처음으로 보냄). 이미 끝난 기록이면 아무 일도 없다
	Telemetry.end("left")
	_last_touch = Time.get_ticks_msec()
	today = Today.roll(today)
	var s := IdleScreen.new(today, settings.newflow)
	s.start.connect(start_session)
	_show(s)


## 대기 화면의 소개 돌려 보기: 안내 4장이 한 장씩 넘어가고, 누르면 바로 체험을 시작한다
func _show_attract() -> void:
	_last_touch = Time.get_ticks_msec()
	var s := IntroScreen.new()
	s.attract = true
	s.done.connect(to_idle)
	s.start.connect(start_session)
	_show(s)


func start_session() -> void:
	round_i = 1
	score = {"kid": 0, "draw": 0, "ai": 0}
	session_changes = []
	_flow_new = settings.newflow
	Telemetry.begin({"flow": "new" if _flow_new else "old", "percent": settings.percent})
	if _flow_new:
		session_brain = Menace.new_brain()
		trained = 0
		today = Today.add_teacher(today)
		Store.save_today(today)
		start_play()
	elif settings.intro:
		Telemetry.stage("intro")
		var s := IntroScreen.new()
		s.done.connect(start_play)
		_show(s)
	else:
		start_play()


func start_play() -> void:
	Telemetry.stage("play%d" % round_i)
	var s: PlayScreen
	if _flow_new:
		s = PlayScreen.new(session_brain, round_i, 3, score, today.games, settings.percent, {"newflow": true, "predict": round_i >= 2, "teach": true, "trained": trained})
	else:
		s = PlayScreen.new(brain, round_i, settings.rounds, score, today.games, settings.percent)
	s.round_end.connect(_on_round_end)
	_show(s)


func _on_round_end(end: Dictionary) -> void:
	if _flow_new:
		_on_stage_end(end)
		return
	var changes := Menace.learn(brain, end.moves, end.outcome)
	Store.save_brain(brain)
	today = Today.add_result(today, end.outcome)
	Store.save_today(today)
	score = score.duplicate()
	score[end.outcome] += 1
	session_changes.append_array(changes)
	teacher.brain_games = brain.games
	Telemetry.add_round({"stage": round_i, "outcome": end.outcome, "moves": end.moves.size(), "resigned": end.resigned})
	Telemetry.stage("learn%d" % round_i)
	var s := LearnScreen.new(end.outcome, changes, end.resigned, round_i >= settings.rounds)
	s.next.connect(_after_learn)
	_show(s)


func _after_learn() -> void:
	if round_i >= settings.rounds:
		Telemetry.stage("result")
		var s := ResultScreen.new(score, session_changes, today.games)
		s.home.connect(_on_result_home)
		_show(s)
	else:
		round_i += 1
		start_play()


func _on_result_home() -> void:
	Telemetry.end("result")
	to_idle()


# ---------- 새 흐름 ----------

## 한 단계가 끝났다 (학생은 이미 놀이 화면에서 제 손으로 상과 벌을 줬다). 구슬을 실제로 고친다
func _on_stage_end(end: Dictionary) -> void:
	Menace.learn(session_brain, end.moves, end.outcome)
	# 우리 반 AI도 같은 판에서 배운다 (다음 친구가 이어받는 기록)
	Menace.learn(brain, end.moves, end.outcome)
	Store.save_brain(brain)
	teacher.brain_games = brain.games
	today = Today.add_result(today, end.outcome)
	score = score.duplicate()
	score[end.outcome] += 1
	Telemetry.add_round({"stage": round_i, "outcome": end.outcome, "moves": end.moves.size(), "resigned": end.resigned, "predict": end.predict, "teach": end.teach})
	if round_i == 3:
		_show_grad(end.outcome)
		return
	Store.save_today(today)
	if round_i == 1:
		round_i = 2
		start_play()
	else:
		Telemetry.stage("train")
		var s := TrainScreen.new(session_brain)
		s.done.connect(_on_trained)
		_show(s)


func _on_trained(info: Dictionary) -> void:
	trained = info.games
	Telemetry.put("train", info)
	round_i = 3
	start_play()


func _show_grad(exam: String) -> void:
	if exam != "kid":
		today = Today.add_grad(today)
	Store.save_today(today)
	Telemetry.stage("grad")
	var s := GradScreen.new(score, Menace.beads_on_board(session_brain, Ttt.empty_board()), exam, trained, settings.percent)
	s.answered.connect(_on_quiz)
	s.home.connect(_on_grad_leave.bind("home"))
	s.again.connect(_on_grad_leave.bind("again"))
	s.more.connect(_on_grad_leave.bind("more"))
	_show(s)


func _on_quiz(choice: String, correct: bool) -> void:
	Telemetry.put("quiz", {"choice": choice, "correct": correct})


func _on_grad_leave(where: String) -> void:
	Telemetry.put("after", where)
	Telemetry.end("grad")
	if where == "again":
		start_session()
	elif where == "more":
		# 1961년 이야기 (사진과 출처는 이 화면에 있다). 다 보면 처음으로
		var s := IntroScreen.new()
		s.last_text = "처음으로"
		s.done.connect(to_idle)
		_show(s)
	else:
		to_idle()


# ---------- 선생님 메뉴 ----------

## AI 고르기: 우리 반 AI를 새 두뇌로 바꾸고 오늘 기록도 새로 시작한다 (웹 앱 replaceBrain과 같음)
func _on_level_picked(level: String) -> void:
	brain = SelfPlay.trained_brain(level)
	Store.save_brain(brain)
	today = Today.fresh()
	Store.save_today(today)
	teacher.brain_games = brain.games
	to_idle()


func _on_setting_changed(key: String, value: Variant) -> void:
	settings[key] = value
	Store.save_settings(settings)
	if key == "sound":
		Sfx.enabled = value
	elif key == "percent" and screen is PlayScreen:
		screen._box.percent = value
		screen._box.queue_redraw()
	elif key == "newflow" and screen is IdleScreen:
		to_idle()


func _on_clear_today() -> void:
	today = Today.fresh()
	Store.save_today(today)
	if screen is IdleScreen:
		to_idle()
