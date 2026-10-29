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
	var s: Node = get_parent().screen
	if s != _last_screen:
		_last_screen = s
		_wait = 0.0
	if s is IdleScreen:
		if _wait > 1.5 and not _shots.has("1-idle"):
			_shot("1-idle")
		elif _wait > 2.0 and _shots.has("1-idle"):
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
			else:
				_wait = 0.0
				var empties := Ttt.empty_cells(s._board)
				s._kid_tap(empties[randi() % empties.size()])
		if s.phase == "end":
			_shot(name + "-end")
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
