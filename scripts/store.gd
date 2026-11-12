class_name Store
extends RefCounted
## 저장: user:// 아래 JSON 파일 (Windows에서는 %APPDATA%\matchbox-ai-godot).
## 서버나 인터넷을 쓰지 않는다.
##
## 안전하게 쓰기: 임시 파일(.tmp)에 다 쓴 뒤 → 지금 파일을 .bak으로 → 임시 파일을 본 파일로.
## 저장 중에 전원이 꺼져도 본 파일이나 .bak 중 하나는 멀쩡하다. 읽을 때 본 파일이 깨졌으면 .bak을 쓴다.

const BRAIN := "user://brain.json"
const TODAY := "user://today.json"
const SETTINGS := "user://settings.json"

## newflow: 새 흐름 "AI 졸업시키기"(3단계 고정). 끄면 예전 흐름(안내 4장 → 판 수만큼 → 결과)
const DEFAULT_SETTINGS := {"rounds": 3, "intro": true, "percent": false, "sound": true, "newflow": true}


## 파일 하나를 읽어 JSON으로 푼다. 없거나 깨졌으면 null
static func _read_one(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## 본 파일을 읽고, 깨졌으면 .bak을 읽는다
static func read_safe(path: String) -> Variant:
	var data: Variant = _read_one(path)
	if data == null:
		data = _read_one(path + ".bak")
		if data != null:
			push_warning("저장 파일이 깨져 예비 파일을 썼어요: " + path)
	return data


## 화면 점검(--qa) 때는 true: 저장을 하지 않는다 (점검이 중간에 꺼져도 두뇌와 오늘 기록이 그대로 남게)
static var frozen := false


## 임시 파일에 쓴 뒤 .bak을 남기고 본 파일로 바꾼다. 성공하면 true
static func write_safe(path: String, data: Variant) -> bool:
	if frozen:
		return true
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("저장 파일을 열 수 없어요: %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("저장 파일을 바꿀 수 없어요: %s (%s)" % [path, error_string(err)])
		return false
	return true


static func load_brain() -> Dictionary:
	return Menace.brain_from_json(read_safe(BRAIN))


static func save_brain(brain: Dictionary) -> void:
	write_safe(BRAIN, brain)


static func load_today() -> Dictionary:
	return Today.roll(Today.from_json(read_safe(TODAY)))


static func save_today(t: Dictionary) -> void:
	write_safe(TODAY, t)


static func load_settings() -> Dictionary:
	var s := DEFAULT_SETTINGS.duplicate()
	var data: Variant = read_safe(SETTINGS)
	if typeof(data) == TYPE_DICTIONARY:
		for k in s:
			if data.has(k) and typeof(data[k]) in [TYPE_BOOL, TYPE_FLOAT, TYPE_INT]:
				s[k] = int(data[k]) if k == "rounds" else bool(data[k])
	return s


static func save_settings(s: Dictionary) -> void:
	write_safe(SETTINGS, s)


# ---------- 선생님 비밀번호 ----------

const TEACHER := "user://teacher.json"
const DEFAULT_PASSWORD := "admin"
const PASSWORD_MAX := 12
const PASSWORD_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789"


## 영문 소문자와 숫자로 1~12글자
static func is_valid_password(p: String) -> bool:
	if p.length() < 1 or p.length() > PASSWORD_MAX:
		return false
	for ch in p:
		if not PASSWORD_CHARS.contains(ch):
			return false
	return true


static func load_password() -> String:
	var data: Variant = read_safe(TEACHER)
	if typeof(data) == TYPE_DICTIONARY and typeof(data.get("password")) == TYPE_STRING and is_valid_password(data.password):
		return data.password
	return DEFAULT_PASSWORD


static func save_password(p: String) -> void:
	write_safe(TEACHER, {"password": p})
