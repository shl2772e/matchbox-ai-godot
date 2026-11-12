class_name TeacherLayer
extends CanvasLayer
## 선생님 메뉴 (PRD TBL-5). 오른쪽 위 자물쇠 버튼 → 비밀번호 → 메뉴.
## 학생이 실수로 메뉴를 열거나 기록을 지우지 않게 하는 잠금이다 (보안용 비밀번호가 아니다).
## 기본 비밀번호는 admin이고, 한 번 열면 5분 동안은 다시 묻지 않는다.
## 웹 앱 TeacherMenu.tsx·App.tsx의 항목과 문구를 그대로 옮겼다. 켬/끔 항목은 메뉴를 닫지 않고 바로 바뀐다.

signal go_home
signal level_picked(level: String)
signal setting_changed(key: String, value: Variant)
signal clear_today

const UNLOCK_MS := 5 * 60000
const KEY_ROWS := ["1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm"]
const TITLES := {"login": "선생님 확인", "new": "새 비밀번호", "confirm": "새 비밀번호 한 번 더"}

## main이 넣어 준다. settings는 main의 사전 그대로라 바뀐 값이 바로 보인다
var settings: Dictionary = {}
var brain_games := 0
var version := ""

var _password := Store.DEFAULT_PASSWORD
var _unlocked_until := 0
var _root: Control
var _corner: Control
var _modal: Control
var _toast: Label
var _toast_tween: Tween

# 비밀번호 창 상태
var _pw_mode := ""
var _pw_text := ""
var _pw_first := ""
var _pw_error := ""
var _pw_box: Label
var _pw_msg: Label
var _pw_ok: Button


func _ready() -> void:
	layer = 10
	_password = Store.load_password()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var R := Kit.R
	_corner = Drawn.new(_paint_corner)
	_corner.mouse_filter = Control.MOUSE_FILTER_STOP
	_corner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_corner.offset_left = -R * 4.2
	_corner.offset_right = -R * 1.0
	_corner.offset_top = R * 0.8
	_corner.offset_bottom = R * 3.3
	_corner.gui_input.connect(_on_corner_input)
	_root.add_child(_corner)
	_toast = Kit.pill("", "kid", 1.2)
	_toast.visible = false
	_root.add_child(_toast)


## 모달이 열려 있으면 true (대기 화면으로 돌아가는 60초 시계를 멈춘다)
func busy() -> bool:
	return _modal != null


func unlocked() -> bool:
	return Time.get_ticks_msec() < _unlocked_until


func _on_corner_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _modal == null:
		_corner.accept_event()
		if unlocked():
			_open_menu()
		else:
			_open_password("login")


## 구석 버튼: 자물쇠 + "선생님"
func _paint_corner(ci: Drawn) -> void:
	var R := Kit.R
	var r := Rect2(Vector2.ZERO, ci.size)
	Kit.rrect(ci, Rect2(r.position + Vector2(0, R * 0.18), r.size), Kit.LINE, R * 0.5)
	Kit.rrect(ci, r, Kit.CREAM, R * 0.5)
	var open := unlocked()
	var col := Kit.TEAL if open else Kit.INK_SOFT
	Kit.lock(ci, Rect2(Vector2((r.size.x - R * 1.2) / 2, R * 0.35), Vector2(R * 1.2, R * 1.2)), open, col)
	Kit.text(ci, Kit.F_LABEL, R * 0.7, "선생님", Rect2(0, R * 1.55, r.size.x, R * 0.8), col)


func _process(_delta: float) -> void:
	_corner.queue_redraw()


# ---------- 모달 뼈대 ----------

## 어두운 배경 + 크림 카드. 카드 안의 세로 묶음을 돌려준다
func _card(title: String) -> VBoxContainer:
	_close()
	var R := Kit.R
	var back := ColorRect.new()
	back.color = Color(Kit.INK, 0.45)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(back)
	_modal = back
	var panel := PanelContainer.new()
	var st := Kit.box(Kit.CREAM, R * 0.9)
	st.shadow_color = Kit.LINE
	st.shadow_offset = Vector2(0, R * 0.4)
	panel.add_theme_stylebox_override("panel", st)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size.x = R * 34
	back.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(R * 1.6))
	margin.add_theme_constant_override("margin_right", int(R * 1.6))
	margin.add_theme_constant_override("margin_top", int(R * 1.4))
	margin.add_theme_constant_override("margin_bottom", int(R * 1.4))
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(R * 0.8))
	margin.add_child(vbox)
	if title != "":
		vbox.add_child(Kit.label(title, Kit.F_TITLE, R * 1.7, Kit.NAVY))
	_corner.queue_redraw()
	return vbox


func _close() -> void:
	if _modal:
		_modal.queue_free()
		_modal = null
	_pw_mode = ""


func _note(vbox: VBoxContainer, s: String, size := 1.0, color := Kit.INK_SOFT) -> Label:
	var l := Kit.label(s, Kit.F_BODY, Kit.R * size, color, HORIZONTAL_ALIGNMENT_LEFT, true)
	l.label_settings.line_spacing = Kit.R * 0.45
	vbox.add_child(l)
	return l


## 메뉴 항목 버튼: 왼쪽 맞춤, 카드 너비 가득
func _item(vbox: VBoxContainer, s: String, kind: String, fn: Callable) -> Button:
	var b := Kit.button(s, kind)
	b.add_theme_font_size_override("font_size", int(Kit.R * 1.1))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(fn)
	vbox.add_child(b)
	return b


func _ghost_close(vbox: VBoxContainer) -> void:
	var b := Kit.button("닫기", "ghost")
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_close)
	vbox.add_child(b)


## 오른쪽 맞춤 버튼 줄 (닫기 + 확인)
func _actions(vbox: VBoxContainer, no_text: String, yes_text: String, on_yes: Callable) -> Button:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", int(Kit.R * 0.8))
	var no := Kit.button(no_text, "soft", true)
	no.pressed.connect(_close)
	row.add_child(no)
	var yes := Kit.button(yes_text, "primary", true)
	yes.pressed.connect(on_yes)
	row.add_child(yes)
	vbox.add_child(row)
	return yes


# ---------- 선생님 메뉴 ----------

func _on_off(on: bool) -> String:
	return "켬" if on else "끔"


func _open_menu() -> void:
	var vbox := _card("선생님 메뉴")
	var items := VBoxContainer.new()
	items.add_theme_constant_override("separation", int(Kit.R * 0.5))
	vbox.add_child(items)
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_item(items, "처음 화면으로", "soft", _run.bind(go_home.emit))
	_item(items, "AI 고르기 (처음부터 · 조금 · 많이 배운 AI)", "primary", _open_picker)
	# 새 흐름(AI 졸업시키기)은 3단계 고정이고 안내 4장이 없다. 판 수와 안내는 예전 흐름에서만 쓴다
	_item(items, "놀이 방식: " + ("AI 졸업시키기 (새 흐름)" if settings.newflow else "예전 흐름 (안내 → 판 → 결과)"), "soft", _toggle.bind("newflow", not settings.newflow))
	if not settings.newflow:
		_item(items, "한 번에 둘 판 수: %d판" % settings.rounds, "soft", _toggle.bind("rounds", settings.rounds % 5 + 1))
		_item(items, "안내 보이기: " + _on_off(settings.intro), "soft", _toggle.bind("intro", not settings.intro))
	_item(items, "확률(%) 숫자 보이기: " + _on_off(settings.percent), "soft", _toggle.bind("percent", not settings.percent))
	_item(items, "소리: " + _on_off(settings.sound), "soft", _toggle.bind("sound", not settings.sound))
	_item(items, "전체화면: " + _on_off(full), "soft", _toggle_fullscreen)
	_item(items, "오늘 기록 지우기", "danger", _open_confirm.bind("오늘 기록(판 수, 승·무·패)을 지울까요? AI 구슬은 그대로예요.", "지우기", clear_today.emit))
	_item(items, "비밀번호 바꾸기", "soft", _open_password.bind("new"))
	_item(items, "프로그램 끝내기", "danger", _open_confirm.bind("프로그램을 끝낼까요? AI 구슬과 오늘 기록은 저장되어 있어요.", "끝내기", get_tree().quit))
	_ghost_close(vbox)
	_note(vbox, "성냥갑 AI v%s · AI가 배운 판 %d" % [version, brain_games], 0.85)


## 메뉴를 닫고 일을 한다
func _run(fn: Callable) -> void:
	_close()
	fn.call()


## 설정 하나를 바꾸고 메뉴를 다시 그린다
func _toggle(key: String, value: Variant) -> void:
	setting_changed.emit(key, value)
	_open_menu()


func _toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_open_menu()


func _open_picker() -> void:
	var vbox := _card("AI 고르기")
	_note(vbox, "AI를 바꾸면 지금까지 배운 구슬과 오늘 기록이 새로 시작해요.")
	var items := VBoxContainer.new()
	items.add_theme_constant_override("separation", int(Kit.R * 0.5))
	vbox.add_child(items)
	for level in ["fresh", "some", "lots"]:
		_item(items, SelfPlay.LEVEL_NAMES[level], "primary" if level == "some" else "soft", _pick_level.bind(level))
	_ghost_close(vbox)


func _pick_level(level: String) -> void:
	_close()
	level_picked.emit(level)
	toast("%s로 바꿨어요." % SelfPlay.LEVEL_NAMES[level])


func _open_confirm(text: String, yes: String, fn: Callable) -> void:
	var vbox := _card("")
	_note(vbox, text, 1.3, Kit.INK)
	_actions(vbox, "아니요", yes, _run.bind(fn))


# ---------- 비밀번호 ----------

func _open_password(mode: String) -> void:
	var R := Kit.R
	var vbox := _card(TITLES[mode] as String)
	_pw_mode = mode
	_pw_text = ""
	_pw_error = ""
	if mode != "confirm":
		_pw_first = ""
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Kit.box(Kit.TRAY, R * 0.5))
	box.custom_minimum_size.y = R * 2.6
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_left", int(R * 1.0))
	bm.add_theme_constant_override("margin_right", int(R * 1.0))
	bm.add_theme_constant_override("margin_top", int(R * 0.5))
	bm.add_theme_constant_override("margin_bottom", int(R * 0.5))
	box.add_child(bm)
	_pw_box = Kit.label("", Kit.F_LABEL, R * 1.3, Kit.INK)
	_pw_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bm.add_child(_pw_box)
	vbox.add_child(box)
	_pw_msg = _note(vbox, "")
	# 자판: 숫자 한 줄 + 영문 소문자 세 줄 + 지우기
	var pad := VBoxContainer.new()
	pad.add_theme_constant_override("separation", int(R * 0.35))
	vbox.add_child(pad)
	for row in KEY_ROWS:
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", int(R * 0.35))
		for ch in row:
			h.add_child(_key(ch, _pw_key.bind(ch)))
		pad.add_child(h)
	var edit := HBoxContainer.new()
	edit.alignment = BoxContainer.ALIGNMENT_CENTER
	edit.add_theme_constant_override("separation", int(R * 0.35))
	edit.add_child(_key("지우기", _pw_backspace, true))
	edit.add_child(_key("모두 지우기", _pw_clear, true))
	pad.add_child(edit)
	var ok_text: String = {"login": "열기", "new": "다음", "confirm": "바꾸기"}[mode]
	_pw_ok = _actions(vbox, "닫기", ok_text, _pw_submit)
	_pw_refresh()


func _key(s: String, fn: Callable, wide := false) -> Button:
	var R := Kit.R
	var b := Button.new()
	b.text = s
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(R * (0.0 if wide else 2.4), R * 2.4)
	for state in ["normal", "hover", "pressed"]:
		var st := Kit.box(Kit.PAPER if state != "pressed" else Kit.KRAFT, R * 0.35)
		st.shadow_color = Kit.LINE
		st.shadow_offset = Vector2(0, R * (0.05 if state == "pressed" else 0.15))
		st.content_margin_left = R * (1.2 if wide else 0.2)
		st.content_margin_right = R * (1.2 if wide else 0.2)
		b.add_theme_stylebox_override(state, st)
	b.add_theme_font_override("font", Kit.F_LABEL)
	b.add_theme_font_size_override("font_size", int(R * (1.0 if wide else 1.2)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Kit.INK)
	b.pressed.connect(fn)
	return b


func _pw_key(ch: String) -> void:
	_pw_error = ""
	if _pw_text.length() < Store.PASSWORD_MAX:
		_pw_text += ch
	_pw_refresh()


func _pw_backspace() -> void:
	_pw_text = _pw_text.left(-1)
	_pw_refresh()


func _pw_clear() -> void:
	_pw_text = ""
	_pw_refresh()


func _pw_refresh() -> void:
	if _pw_mode == "":
		return
	if _pw_text == "":
		_pw_box.label_settings.font_size = int(Kit.R * 1.0)
		_pw_box.label_settings.font_color = Kit.INK_SOFT
		_pw_box.text = ("기본 비밀번호는 %s이에요" % Store.DEFAULT_PASSWORD) if _pw_mode == "login" else ("영문 소문자·숫자 %d글자까지" % Store.PASSWORD_MAX)
	else:
		_pw_box.label_settings.font_size = int(Kit.R * 1.3)
		_pw_box.label_settings.font_color = Kit.INK
		_pw_box.text = "●".repeat(_pw_text.length())
	var hint: String = {"login": "선생님 메뉴를 열려면 비밀번호를 눌러요.", "new": "바꿀 비밀번호를 눌러요.", "confirm": "확인을 위해 한 번 더 눌러요."}[_pw_mode]
	Kit.set_text(_pw_msg, _pw_error if _pw_error != "" else hint)
	_pw_msg.label_settings.font_color = Kit.RED_INK if _pw_error != "" else Kit.INK_SOFT
	_pw_ok.disabled = _pw_text == ""


func _pw_submit() -> void:
	if _pw_text == "":
		return
	match _pw_mode:
		"login":
			if _pw_text == _password:
				_unlocked_until = Time.get_ticks_msec() + UNLOCK_MS
				_open_menu()
			else:
				_pw_error = "비밀번호가 달라요. 다시 눌러 주세요."
				_pw_text = ""
				_pw_refresh()
		"new":
			if not Store.is_valid_password(_pw_text):
				_pw_error = "영문 소문자와 숫자로 1~%d글자까지 쓸 수 있어요." % Store.PASSWORD_MAX
				_pw_refresh()
				return
			var first := _pw_text
			_open_password("confirm")
			_pw_first = first
		"confirm":
			if _pw_text == _pw_first:
				_password = _pw_text
				Store.save_password(_password)
				_close()
				toast("비밀번호를 바꿨어요.")
			else:
				_open_password("new")
				_pw_error = "두 번 쓴 비밀번호가 달라요. 처음부터 다시 써 주세요."
				_pw_refresh()


## 자판이 있으면 그걸로도 누를 수 있다
func _input(event: InputEvent) -> void:
	if _pw_mode == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_BACKSPACE:
			_pw_backspace()
		KEY_ENTER, KEY_KP_ENTER:
			_pw_submit()
		KEY_ESCAPE:
			_close()
		_:
			var ch := char(k.unicode).to_lower()
			if ch.length() == 1 and Store.is_valid_password(ch):
				_pw_key(ch)
			else:
				return
	get_viewport().set_input_as_handled()


# ---------- 토스트 ----------

## 아래 가운데에 2.6초 동안 보이는 짧은 알림
func toast(s: String) -> void:
	var R := Kit.R
	_toast.text = s
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast.size = _toast.get_combined_minimum_size()
	_toast.position = Vector2((_root.size.x - _toast.size.x) / 2, _root.size.y - R * 2 - _toast.size.y)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.3)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(_toast.hide)
