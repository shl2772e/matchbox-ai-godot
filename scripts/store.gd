class_name Store
extends RefCounted
## 저장: user:// 아래 JSON 파일 (Windows에서는 %APPDATA%\matchbox-ai-godot).
## 서버나 인터넷을 쓰지 않는다.

const BRAIN := "user://brain.json"
const TODAY := "user://today.json"
const SETTINGS := "user://settings.json"

const DEFAULT_SETTINGS := {"rounds": 3, "intro": true, "percent": false, "sound": true}


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func _write(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


static func load_brain() -> Dictionary:
	return Menace.brain_from_json(_read(BRAIN))


static func save_brain(brain: Dictionary) -> void:
	_write(BRAIN, brain)


static func load_today() -> Dictionary:
	return Today.roll(Today.from_json(_read(TODAY)))


static func save_today(t: Dictionary) -> void:
	_write(TODAY, t)


static func load_settings() -> Dictionary:
	var s := DEFAULT_SETTINGS.duplicate()
	var data: Variant = _read(SETTINGS)
	if typeof(data) == TYPE_DICTIONARY:
		for k in s:
			if data.has(k) and typeof(data[k]) in [TYPE_BOOL, TYPE_FLOAT, TYPE_INT]:
				s[k] = int(data[k]) if k == "rounds" else bool(data[k])
	return s


static func save_settings(s: Dictionary) -> void:
	_write(SETTINGS, s)
