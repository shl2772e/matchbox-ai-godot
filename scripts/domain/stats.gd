class_name Stats
extends RefCounted
## 체험 기록(Telemetry가 남긴 user://records/날짜.jsonl)을 읽어 통계를 낸다.
## 선생님 메뉴의 "체험 통계"와 tests/log_report.gd가 같이 쓴다.
## 기록에는 이름·얼굴·소리가 없다. 여기서도 한 사람을 가려낼 수 있는 것은 만들지 않는다 (모두 합계와 가운데 값).

const SET_NAMES := ["1단계", "2단계", "졸업 시험"]


## 기록 파일이 있는 날짜들 (오래된 날부터)
static func dates() -> Array:
	var out := []
	var dir := DirAccess.open(Telemetry.DIR)
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".jsonl"):
				out.append(f.trim_suffix(".jsonl"))
	out.sort()
	return out


## only_date가 비어 있으면 모든 날짜의 기록
static func load_sessions(only_date := "") -> Array:
	var out := []
	for d in dates():
		if only_date != "" and d != only_date:
			continue
		for line in FileAccess.get_file_as_string(Telemetry.DIR.path_join(d + ".jsonl")).split("\n", false):
			var s: Variant = JSON.parse_string(line)
			if typeof(s) == TYPE_DICTIONARY and s.has("stages") and s.has("rounds"):
				out.append(s)
	return out


static func clear_all() -> void:
	for d in dates():
		DirAccess.remove_absolute(Telemetry.DIR.path_join(d + ".jsonl"))


static func _pct(a: int, b: int) -> String:
	return "%d%% (%d / %d)" % [roundi(a * 100.0 / b), a, b] if b > 0 else "기록 없음"


static func _median(a: Array) -> float:
	if a.is_empty():
		return -1.0
	var s := a.duplicate()
	s.sort()
	return s[s.size() / 2]


static func _secs(ms: float) -> String:
	if ms < 0.0:
		return "기록 없음"
	if ms >= 60000.0:
		return "%d분 %d초" % [int(ms / 60000.0), int(fmod(ms, 60000.0) / 1000.0)]
	return "%.1f초" % (ms / 1000.0)


static func _stage_ms(s: Dictionary, prefix: String) -> float:
	var ms := 0.0
	var found := false
	for st in s.stages:
		if str(st.name).begins_with(prefix):
			ms += float(st.ms)
			found = true
	return ms if found else -1.0


## [[묶음 제목, [[항목, 값], ...]], ...]
static func summary(sessions: Array) -> Array:
	var out := []
	var teach := []
	var contest := []
	var old := []
	for s in sessions:
		match str(s.get("flow", "")):
			"new":
				teach.append(s)
			"contest":
				contest.append(s)
			_:
				old.append(s)
	out.append(["AI 가르치기", _teach_rows(teach)])
	out.append(["AI 키우기 대회", _contest_rows(contest)])
	if not old.is_empty():
		out.append(["예전 흐름", [["시작한 횟수", "%d번" % old.size()]]])
	return out


static func _teach_rows(ss: Array) -> Array:
	var rows := []
	if ss.is_empty():
		return [["시작한 횟수", "0번"]]
	var finished := []
	var timeouts := 0
	for s in ss:
		if str(s.get("end", "")) == "grad":
			finished.append(s)
		elif str(s.get("end", "")) == "timeout":
			timeouts += 1
	rows.append(["시작한 횟수", "%d번" % ss.size()])
	rows.append(["졸업장까지 간 비율", _pct(finished.size(), ss.size())])
	rows.append(["60초 동안 손을 안 대서 끝난 비율", _pct(timeouts, ss.size())])
	var totals := []
	for s in finished:
		# 졸업장에 들어서기까지 걸린 시간
		var ms := 0.0
		for st in s.stages:
			if str(st.name) == "grad":
				break
			ms += float(st.ms)
		totals.append(ms)
	rows.append(["졸업장까지 걸린 시간 (가운데 값)", _secs(_median(totals))])
	# 단계마다: 승패, 내 차례에 걸린 시간
	for set_i in [1, 2, 3]:
		var o := {"kid": 0, "draw": 0, "ai": 0}
		var think := []
		for s in ss:
			for r in s.rounds:
				if int(r.get("stage", 0)) != set_i:
					continue
				o[str(r.outcome)] += 1
				for ms in r.get("kid_ms", []):
					think.append(float(ms))
		rows.append(["%s 승패" % SET_NAMES[set_i - 1], "학생 %d · 비김 %d · AI %d" % [o.kid, o.draw, o.ai]])
		rows.append(["%s 한 수 두는 데 걸린 시간 (가운데 값)" % SET_NAMES[set_i - 1], _secs(_median(think))])
	var offered := 0
	var answered := 0
	var hit := 0
	var guess_ms := []
	var manual := 0
	var total := 0
	var explored := 0
	var games := 0
	for s in ss:
		for r in s.rounds:
			games += 1
			explored += int(r.get("explored", 0))
			if r.has("predict") and r.predict.get("offered", false):
				offered += 1
				if r.predict.get("answered", false):
					answered += 1
					if r.predict.get("hit", false):
						hit += 1
					if r.predict.has("ms"):
						guess_ms.append(float(r.predict.ms))
			if r.has("teach"):
				manual += int(r.teach.get("manual", 0))
				total += int(r.teach.get("total", 0))
	rows.append(["맞혀 보기에서 칸을 누른 비율", _pct(answered, offered)])
	rows.append(["맞혀 보기에서 AI가 고른 칸을 맞힌 비율", _pct(hit, answered)])
	rows.append(["맞혀 보기에서 누르기까지 (가운데 값)", _secs(_median(guess_ms))])
	rows.append(["상과 벌을 제 손으로 준 칸", _pct(manual, total)])
	rows.append(["AI가 확률이 낮은 칸을 고른 횟수", "%d번 (%d판 가운데)" % [explored, games]])
	var quiz := 0
	var right := 0
	var to_contest := 0
	for s in finished:
		if s.has("quiz"):
			quiz += 1
			if s.quiz.get("correct", false):
				right += 1
		if str(s.get("after", "")) == "again":
			to_contest += 1
	rows.append(["퀴즈에 답한 비율", _pct(quiz, finished.size())])
	rows.append(["퀴즈 정답 비율", _pct(right, quiz)])
	rows.append(["졸업 뒤 대회로 간 비율", _pct(to_contest, finished.size())])
	for pair in [["explain1", "설명 1 화면"], ["explain2", "설명 2 화면"], ["train", "빨리 감기 화면"], ["grad", "졸업장 화면"]]:
		var ms := []
		for s in ss:
			var v := _stage_ms(s, pair[0])
			if v >= 0.0:
				ms.append(v)
		rows.append(["%s에 머문 시간 (가운데 값)" % pair[1], _secs(_median(ms))])
	return rows


static func _contest_rows(ss: Array) -> Array:
	if ss.is_empty():
		return [["시작한 횟수", "0번"]]
	var rows := []
	var scores := []
	var plan_ms := []
	var slots := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var plans := 0
	for s in ss:
		if s.has("score"):
			scores.append(float(s.score))
		if s.has("plan") and s.plan.size() == slots.size():
			plans += 1
			for i in slots.size():
				slots[i] += float(s.plan[i])
			var v := _stage_ms(s, "plan")
			if v >= 0.0:
				plan_ms.append(v)
	rows.append(["시작한 횟수", "%d번" % ss.size()])
	rows.append(["점수까지 간 비율", _pct(scores.size(), ss.size())])
	if not scores.is_empty():
		var sum := 0.0
		for v in scores:
			sum += v
		rows.append(["점수 (평균 / 가장 높은 점수)", "%d점 / %d점" % [roundi(sum / scores.size()), roundi(scores.max())]])
	rows.append(["계획 세우는 데 걸린 시간 (가운데 값)", _secs(_median(plan_ms))])
	if plans > 0:
		var parts := []
		for i in slots.size():
			parts.append("%s %d판" % [str(SelfPlay.FRIEND_NAMES[SelfPlay.CONTEST_FRIENDS[i]]).trim_suffix(" 친구"), roundi(slots[i] / plans)])
		rows.append(["평균 계획 (%d판 가운데)" % SelfPlay.CONTEST_GAMES, " · ".join(parts)])
	return rows
