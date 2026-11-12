class_name Telemetry
extends RefCounted
## 이름 없는 체험 기록. 한 번의 체험(대기 화면을 누른 때부터 끝날 때까지)을 한 줄 JSON으로
## user://records/날짜.jsonl 에 덧붙인다. 이름·얼굴·소리는 남기지 않는다.
## 지표 계산은 tests/log_report.gd 가 한다 (개선 계획서의 평가 지표).
##
## 한 줄: {"v", "start", "flow", "percent", "stages": [{"name", "ms"}], "rounds": [...],
##         "train": {...}, "quiz": {...}, "taps", "longest_gap_ms", "total_ms", "end"}
## end: "grad"(졸업장까지) / "result"(예전 흐름 결과까지) / "timeout"(60초 무입력) / "left"(선생님이 처음으로)

const DIR := "user://records"

## 화면 점검(--qa)이나 테스트 때는 끈다
static var enabled := true
static var _cur := {}
static var _t0 := 0
static var _stage_t := 0
static var _last_tap := 0


static func active() -> bool:
	return not _cur.is_empty()


static func begin(info: Dictionary) -> void:
	_t0 = Time.get_ticks_msec()
	_stage_t = _t0
	_last_tap = _t0
	_cur = {"v": 1, "start": Time.get_datetime_string_from_system(), "stages": [], "rounds": [], "taps": 0, "longest_gap_ms": 0}
	_cur.merge(info)
	_cur["_stage"] = "start"


## 새 단계에 들어섰다. 앞 단계에 머문 시간을 적는다
static func stage(name: String) -> void:
	if not active():
		return
	var now := Time.get_ticks_msec()
	_cur.stages.append({"name": _cur["_stage"], "ms": now - _stage_t})
	_cur["_stage"] = name
	_stage_t = now


static func tap() -> void:
	if not active():
		return
	var now := Time.get_ticks_msec()
	_cur.taps += 1
	_cur.longest_gap_ms = maxi(_cur.longest_gap_ms, now - _last_tap)
	_last_tap = now


static func put(key: String, value: Variant) -> void:
	if active():
		_cur[key] = value


static func add_round(r: Dictionary) -> void:
	if active():
		_cur.rounds.append(r)


static func end(how: String) -> void:
	if not active():
		return
	stage("end")
	_cur.erase("_stage")
	_cur["end"] = how
	_cur["total_ms"] = Time.get_ticks_msec() - _t0
	var line := JSON.stringify(_cur)
	_cur = {}
	if not enabled:
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR.path_join(Today.date_key() + ".jsonl")
	var f := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("체험 기록을 쓸 수 없어요: " + path)
		return
	f.seek_end()
	f.store_line(line)
	f.close()
