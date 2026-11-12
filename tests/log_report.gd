extends SceneTree
## 체험 기록(user://records/*.jsonl)을 읽어 평가 지표를 계산한다.
## 실행: godot --headless --path . --script res://tests/log_report.gd
## 지표와 합격 기준은 개선 계획서의 "평가 지표"를 따른다. 면담·관찰로 재는 지표는 여기 없다.
## 표본이 적으면(5명 안팎) 비율은 믿지 말고 막히는 곳을 찾는 데만 쓴다.


func _pct(a: int, b: int) -> String:
	return "%d%% (%d/%d)" % [roundi(a * 100.0 / b), a, b] if b > 0 else "자료 없음"


func _row(name: String, value: String, goal: String) -> void:
	print("  %-34s %-18s 기준 %s" % [name, value, goal])


func _init() -> void:
	var sessions := []
	var dir := DirAccess.open(Telemetry.DIR)
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".jsonl"):
				for line in FileAccess.get_file_as_string(Telemetry.DIR.path_join(f)).split("\n", false):
					var d: Variant = JSON.parse_string(line)
					if typeof(d) == TYPE_DICTIONARY:
						sessions.append(d)
	print("체험 기록 %d건 (%s)" % [sessions.size(), ProjectSettings.globalize_path(Telemetry.DIR)])
	for flow in ["new", "old"]:
		var ss := sessions.filter(func(s): return s.get("flow", "") == flow)
		if ss.is_empty():
			continue
		print("\n[%s] %d건" % ["새 흐름 (AI 졸업시키기)" if flow == "new" else "예전 흐름", ss.size()])
		var finished := ss.filter(func(s): return s.stages.any(func(st): return st.name == "grad" or st.name == "result"))
		var timeouts := ss.filter(func(s): return s.end == "timeout" and not finished.has(s))
		_row("끝까지 간 비율", _pct(finished.size(), ss.size()), "85% 이상")
		_row("60초 무입력으로 끝난 비율", _pct(timeouts.size(), ss.size()), "10% 이하")
		var times := []
		for s in finished:
			# 졸업장(결과) 화면에 들어서기까지 걸린 시간
			var ms := 0
			for st in s.stages:
				if st.name == "grad" or st.name == "result":
					break
				ms += int(st.ms)
			times.append(ms / 1000.0)
		times.sort()
		if not times.is_empty():
			_row("한 번 체험 시간 (중앙값)", "%d초" % roundi(times[times.size() / 2]), "180~300초")
			_row("한 번 체험 시간 (10명 중 9명)", "%d초" % roundi(times[mini(times.size() - 1, int(times.size() * 0.9))]), "330초 안")
		if flow != "new":
			continue
		var quiz := finished.filter(func(s): return s.has("quiz"))
		var right := quiz.filter(func(s): return s.quiz.correct)
		_row("한 문제 정답률", _pct(right.size(), quiz.size()), "80% 이상")
		_row("한 문제에 답한 비율", _pct(quiz.size(), finished.size()), "-")
		# 이긴 학생과 진 학생의 정답률 차이 (원리 이해가 승패와 상관없는지)
		var win := quiz.filter(func(s): return s.rounds.any(func(r): return r.outcome == "kid"))
		var lose := quiz.filter(func(s): return not win.has(s))
		if not win.is_empty() and not lose.is_empty():
			var a := win.filter(func(s): return s.quiz.correct).size() * 100.0 / win.size()
			var b := lose.filter(func(s): return s.quiz.correct).size() * 100.0 / lose.size()
			_row("이긴·못 이긴 학생 정답률 차이", "%d%%포인트" % roundi(absf(a - b)), "10%포인트 이하")
		for stage in [2, 3]:
			var offered := 0
			var answered := 0
			var picked_max := 0
			for s in ss:
				for r in s.rounds:
					if int(r.stage) == stage and r.has("predict") and r.predict.offered:
						offered += 1
						if r.predict.answered:
							answered += 1
							if r.predict.guess_max:
								picked_max += 1
			_row("%d단계 맞혀 보기 참여" % stage, _pct(answered, offered), "80% 이상")
			_row("%d단계 구슬 가장 많은 칸을 고름" % stage, _pct(picked_max, answered), "3단계 70% 이상, 2단계보다 높게")
		var manual := 0
		var total := 0
		for s in ss:
			for r in s.rounds:
				if r.has("teach"):
					manual += int(r.teach.manual)
					total += int(r.teach.total)
		_row("상벌을 제 손으로 준 상자", _pct(manual, total), "90% 이상")
		var exams := []
		for s in ss:
			for r in s.rounds:
				if int(r.stage) == 3:
					exams.append(r.outcome)
		_row("졸업 시험에서 학생이 이긴 비율", _pct(exams.count("kid"), exams.size()), "20~40%")
		_row("한 번 더 하기를 누른 비율", _pct(finished.filter(func(s): return s.get("after", "") == "again").size(), finished.size()), "30% 이상")
		var held := ss.filter(func(s): return s.has("train"))
		_row("빨리 감기를 제 손으로 누른 비율", _pct(held.filter(func(s): return not s.train.auto).size(), held.size()), "-")
	quit()
