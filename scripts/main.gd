extends Control
## 화면 흐름: 대기 → 안내 → (놀이 → 배우는 순간) × 판 수 → 결과 → 대기.
## AI 두뇌(구슬)는 학생이 바뀌어도 이어진다. 처음 켜면 "조금 배운 AI"로 시작한다.
## F11: 전체화면 켜고 끄기. 60초 동안 아무도 누르지 않으면 대기 화면으로 돌아간다.
## 오른쪽 위 자물쇠는 선생님 메뉴(TeacherLayer)다.

const IDLE_MS := 60000

var brain: Dictionary
var today: Dictionary
var settings: Dictionary
var screen: ScreenBase
var round_i := 1
var score := {"kid": 0, "draw": 0, "ai": 0}
var session_changes := []
var teacher: TeacherLayer
var _last_touch := 0


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
	if OS.has_feature("template"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa=") and ResourceLoader.exists("res://tests/qa.gd"):
			var qa: Node = load("res://tests/qa.gd").new()
			qa.set("out_dir", a.substr(5))
			add_child(qa)


func _on_resized() -> void:
	queue_redraw()
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
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _last_touch > IDLE_MS and not (screen is IdleScreen) and not teacher.busy():
		_last_touch = Time.get_ticks_msec()
		to_idle()


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
	today = Today.roll(today)
	var s := IdleScreen.new(today)
	s.start.connect(start_session)
	_show(s)


func start_session() -> void:
	round_i = 1
	score = {"kid": 0, "draw": 0, "ai": 0}
	session_changes = []
	if settings.intro:
		var s := IntroScreen.new()
		s.done.connect(start_play)
		_show(s)
	else:
		start_play()


func start_play() -> void:
	var s := PlayScreen.new(brain, round_i, settings.rounds, score, today.games, settings.percent)
	s.round_end.connect(_on_round_end)
	_show(s)


func _on_round_end(end: Dictionary) -> void:
	var changes := Menace.learn(brain, end.moves, end.outcome)
	Store.save_brain(brain)
	today = Today.add_result(today, end.outcome)
	Store.save_today(today)
	score = score.duplicate()
	score[end.outcome] += 1
	session_changes.append_array(changes)
	teacher.brain_games = brain.games
	var s := LearnScreen.new(end.outcome, changes, end.resigned, round_i >= settings.rounds)
	s.next.connect(_after_learn)
	_show(s)


func _after_learn() -> void:
	if round_i >= settings.rounds:
		var s := ResultScreen.new(score, session_changes, today.games)
		s.home.connect(to_idle)
		_show(s)
	else:
		round_i += 1
		start_play()


# ---------- 선생님 메뉴 ----------

## AI 고르기: 새 두뇌로 바꾸고 오늘 기록도 새로 시작한다 (웹 앱 replaceBrain과 같음)
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


func _on_clear_today() -> void:
	today = Today.fresh()
	Store.save_today(today)
	if screen is IdleScreen:
		to_idle()
