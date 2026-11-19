class_name HangulPad
extends Control
## 화면 자판 (이름 적기). 낱자를 누르면 글자로 모아 changed(글자)를 알린다. 가장 긴 이름은 MAX_LEN 글자.

signal changed(text: String)

const ROWS := ["ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ", "ㅁㄴㅇㄹㅎㅗㅓㅏㅣ", "ㅋㅌㅊㅍㅠㅜㅡ", "ㄲㄸㅃㅆㅉㅒㅖ"]
const MAX_LEN := 6

var _jamos: Array = []
var _keys: Array = []
var _back: Button


func _ready() -> void:
	for row in ROWS:
		var line := []
		for ch in row:
			var b := Kit.button(ch, "soft")
			b.add_theme_font_override("font", Kit.F_BOLD)
			b.add_theme_font_size_override("font_size", int(Kit.R * 1.5))
			b.pressed.connect(type.bind(ch))
			add_child(b)
			line.append(b)
		_keys.append(line)
	_back = Kit.button("지우기", "danger")
	_back.pressed.connect(backspace)
	add_child(_back)
	resized.connect(_layout)
	_layout()


static func key_size() -> float:
	return Kit.R * 2.6


## 자판 전체 크기 (열 10개, 줄 4개)
static func wanted_size() -> Vector2:
	var k := key_size()
	var gap := Kit.R * 0.3
	return Vector2(k * 10 + gap * 9, k * 4 + gap * 3)


func _layout() -> void:
	var k := key_size()
	var gap := Kit.R * 0.3
	for r in _keys.size():
		var line: Array = _keys[r]
		var w := line.size() * k + (line.size() - 1) * gap
		# 마지막 줄은 지우기 단추가 오른쪽에 붙는다
		var extra := (k * 2.4 + gap) if r == _keys.size() - 1 else 0.0
		var x := (size.x - w - extra) / 2
		for b: Button in line:
			b.position = Vector2(x, r * (k + gap))
			b.size = Vector2(k, k)
			x += k + gap
		if r == _keys.size() - 1:
			_back.position = Vector2(x, r * (k + gap))
			_back.size = Vector2(k * 2.4, k)


func text() -> String:
	return Hangul.compose(_jamos)


func type(ch: String) -> void:
	_jamos.append(ch)
	if Hangul.compose(_jamos).length() > MAX_LEN:
		_jamos.pop_back()
		return
	Sfx.tap()
	changed.emit(text())


func backspace() -> void:
	if _jamos.is_empty():
		return
	_jamos.pop_back()
	Sfx.tap()
	changed.emit(text())
