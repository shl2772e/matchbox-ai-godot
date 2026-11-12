extends Node
## 화면 점검: 앱을 끝까지 저절로 진행하며 화면을 찍는다. 학생 수는 무작위.
## 실행: godot --path . --resolution 1920x1080 -- --qa=<저장 폴더>
## 저장한 두뇌를 건드리지 않도록 처음에 두뇌를 복사해 두고 끝나면 되돌린다.

var out_dir := ""
var _shots := {}
var _wait := 0.0
var _brain_backup: Dictionary
var _today_backup: Dictionary
var _last_screen: Node
var _last_phase := ""
var _pt := 0.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main := get_parent()
	_brain_backup = Menace.clone_brain(main.brain)
	_today_backup = main.today.duplicate(true)


func _shot(name: String) -> void:
	if _shots.has(name):
		return
	_shots[name] = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _process(delta: float) -> void:
	_wait += delta
	# 점검 중에는 누르는 입력이 없으므로 60초 대기 시계가 돌지 않게 한다
	get_parent()._last_touch = Time.get_ticks_msec()
	var s: Node = get_parent().screen
	if s != _last_screen:
		_last_screen = s
		_wait = 0.0
	if s is IdleScreen:
		if _wait > 1.5 and not _shots.has("1-idle"):
			_shot("1-idle")
		elif _shots.has("1-idle") and not _shots.has("0-teacher-done"):
			_teacher_shots(get_parent().teacher)
		elif _wait > 2.0 and _shots.has("1-idle"):
			if _shots.has("9-result") and not _shots.has("attract-started"):
				# 마지막으로 대기 화면의 소개 돌려 보기를 한 바퀴 찍는다
				_shots["attract-started"] = true
				get_parent()._show_attract()
				return
			if _shots.has("9-result"):
				_finish()
				return
			_wait = 0.0
			s.start.emit()
	elif s is IntroScreen:
		var page: int = s._page
		if _wait > 1.6:
			_shot("2-intro-%d" % page)
			if _wait > 1.9:
				_wait = 0.0
				s._on_next()
	elif s is PlayScreen:
		var name := "3-play-r%d" % s.round_i
		if s._fly.visible:
			_shot(name + "-fly")
		if s.phase == "kid" and _wait > 0.6:
			if not _shots.has(name + "-kid"):
				_shot(name + "-kid")
			elif _wait < 3.4:
				pass  # 손가락 안내가 나올 때까지 기다린다
			elif not _shots.has(name + "-hint"):
				_shot(name + "-hint")
			else:
				_wait = 0.0
				var empties := Ttt.empty_cells(s._board)
				s._kid_tap(empties[randi() % empties.size()])
		if s.phase == "end":
			_shot(name + "-end")
		# 새 흐름: 맞혀 보기(서랍의 빈칸 하나를 누른다)와 내 손으로 상벌 주기(상자를 모두 누른다)
		if s.phase != _last_phase:
			_last_phase = s.phase
			_pt = 0.0
		_pt += delta
		if s.phase == "predict" and _pt > 1.0:
			if not _shots.has(name + "-predict"):
				_shot(name + "-predict")
			elif _pt > 1.4:
				s._box.slot_tapped.emit(Ttt.empty_cells(s._box.shape)[0])
		if s.phase == "teach" and s._teach != null:
			if _pt > 1.0 and not _shots.has(name + "-teach"):
				_shot(name + "-teach")
			elif _pt > 1.5 and not _shots.has(name + "-applied"):
				_shots[name + "-applied"] = true
				for i in s._teach.changes.size():
					s._teach._apply(i, true)
			elif _pt > 2.9:
				_shot(name + "-taught")
	elif s is TrainScreen:
		if _wait > 1.2 and not _shots.has("5-train-start"):
			_shot("5-train-start")
			s._on_down()
		elif s._played > SelfPlay.TRAIN_GAMES / 2 and not _shots.has("5-train-half"):
			_shot("5-train-half")
		elif s._finished and not _shots.has("5-train-done"):
			_wait = 0.0
			_shot("5-train-done")
		elif s._finished and _wait > 1.5:
			_wait = 0.0
			s._go()
	elif s is GradScreen:
		if _wait > 1.6 and not _shots.has("8-grad"):
			_shot("8-grad")
			s._answer("down", s._quiz_buttons[1])
		elif _wait > 2.6 and _shots.has("8-grad"):
			_shot("9-result")
			if _wait > 3.0:
				_wait = 0.0
				s._leave(s.home)
	elif s is LearnScreen:
		if _wait > 2.8:
			_shot("4-learn-%d" % get_parent().round_i)
			if _wait > 3.1:
				_wait = 0.0
				s._go()
	elif s is ResultScreen:
		if _wait > 1.8:
			_shot("9-result")
			if _wait > 2.1:
				_wait = 0.0
				s._go()


func _finish() -> void:
	set_process(false)
	Store.save_brain(_brain_backup)
	Store.save_today(_today_backup)
	print("QA 끝: ", out_dir)
	get_tree().quit()


## 선생님 메뉴: 비밀번호 창 → 메뉴 → AI 고르기 순서로 찍고 닫는다 (비밀번호는 안 바꾼다)
func _teacher_shots(t: TeacherLayer) -> void:
	if _wait > 1.8 and not _shots.has("0-teacher-password"):
		t._open_password("login")
		t._pw_key("a")
		_shot("0-teacher-password")
	elif _wait > 2.6 and not _shots.has("0-teacher-menu"):
		t._close()
		t._unlocked_until = Time.get_ticks_msec() + 60000
		t._open_menu()
		_shot("0-teacher-menu")
	elif _wait > 3.4 and not _shots.has("0-teacher-picker"):
		t._open_picker()
		_shot("0-teacher-picker")
	elif _wait > 4.2 and not _shots.has("0-teacher-guide"):
		t._open_guide()
		_shot("0-teacher-guide")
	elif _wait > 5.0 and _shots.has("0-teacher-guide"):
		t._close()
		t._unlocked_until = 0
		_shots["0-teacher-done"] = true
		_wait = 0.0
