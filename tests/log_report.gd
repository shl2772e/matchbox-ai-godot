extends SceneTree
## 체험 기록(user://records/*.jsonl)의 통계를 찍는다. 선생님 메뉴의 "체험 통계"와 같은 계산(Stats)이다.
## 실행: godot --headless --path . --script res://tests/log_report.gd
## 표본이 적으면(5명 안팎) 비율은 믿지 말고 막히는 곳을 찾는 데만 쓴다.


func _init() -> void:
	var sessions := Stats.load_sessions()
	print("체험 기록 %d건 (%s), 날짜 %s" % [sessions.size(), ProjectSettings.globalize_path(Telemetry.DIR), ", ".join(Stats.dates())])
	for part in Stats.summary(sessions):
		print("\n[%s]" % part[0])
		for row in part[1]:
			print("  %s: %s" % [row[0], row[1]])
	quit()
