extends SceneTree
## 도메인 테스트. 실행: godot --headless --path . --script res://tests/run_tests.gd
## 웹 앱 tests/domain.test.ts를 옮기고, 웹 앱과 같은 AI가 나오는지 기준값으로 확인한다.

var _fails := 0
var _count := 0


func check(ok: bool, name: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		printerr("실패: ", name)


func B(s: String) -> Array:
	var out := []
	for ch in s:
		out.append(int(ch))
	return out


func _init() -> void:
	# 판과 대칭
	check(Ttt.outcome(B("111220000")) == "ai", "가로 승")
	check(Ttt.outcome(B("210210200")) == "kid", "세로 승")
	check(Ttt.outcome(B("100010001")) == "ai", "대각선 승")
	check(Ttt.outcome(B("121112212")) == "draw", "무승부")
	check(Ttt.outcome(B("100020000")) == "", "안 끝남")
	var b := B("120000200")
	var key: String = Ttt.canonical(b).key
	for s in Ttt.SYMS:
		var t := []
		for i in s:
			t.append(b[i])
		check(Ttt.canonical(t).key == key, "대칭 대표 모양")

	# 성냥갑
	check(Menace.ALL_BOX_KEYS.size() == 304, "상자 304개")
	var brain := Menace.new_brain()
	check(Menace.get_box(brain, Ttt.empty_board()).beads == [4, 4, 4, 4, 4, 4, 4, 4, 4], "첫 상자 4개")
	check(Menace.get_box(brain, B("120000000")).beads.max() == 3, "둘째 수 3개")
	check(Menace.get_box(brain, B("121212000")).beads.max() == 1, "넷째 수 1개")

	brain = Menace.new_brain()
	brain.boxes[Menace.FIRST_KEY] = [0, 0, 0, 0, 9, 0, 0, 0, 1]
	var rng := SeededRng.new(7)
	var center := 0
	for i in 2000:
		var c := Menace.choose_move(brain, Ttt.empty_board(), rng)
		if c.kind == "move" and c.move.cell == 4:
			center += 1
	check(center / 2000.0 > 0.86 and center / 2000.0 < 0.94, "구슬 비율대로 고름")

	brain = Menace.new_brain()
	var c0 := Menace.choose_move(brain, Ttt.empty_board(), SeededRng.new(1))
	var m: Dictionary = c0.move
	check(Menace.learn(Menace.clone_brain(brain), [m], "ai")[0].after == 7, "이김 +3")
	check(Menace.learn(Menace.clone_brain(brain), [m], "draw")[0].after == 5, "비김 +1")
	check(Menace.learn(Menace.clone_brain(brain), [m], "kid")[0].after == 3, "짐 -1")
	var high := Menace.clone_brain(brain)
	high.boxes[m.key][m.canon] = Menace.BEAD_MAX - 1
	check(Menace.learn(high, [m], "ai")[0].after == Menace.BEAD_MAX, "상한")
	check(high.boxes[m.key][m.canon] == roundi((Menace.BEAD_MAX + 2) / 2.0), "상자 반으로")

	brain = Menace.new_brain()
	Menace.get_box(brain, B("120000000")).beads.fill(0)
	check(Menace.choose_move(brain, B("120000000"), SeededRng.new(1)).kind == "resign", "빈 상자 기권")
	brain.boxes[Menace.FIRST_KEY] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	check(Menace.choose_move(brain, Ttt.empty_board(), SeededRng.new(1)).kind == "move", "첫 상자 다시 채움")
	var forced := Menace.choose_move(Menace.new_brain(), B("121122210"), SeededRng.new(1))
	check(forced.kind == "forced" and forced.cell == 8, "마지막 한 칸")

	# 웹 앱과 같은 수열·같은 AI (node로 rng.ts·selfplay.ts를 돌려 얻은 값)
	var r := SeededRng.new(1961)
	var seq := "%.9f,%.9f,%.9f" % [r.next(), r.next(), r.next()]
	check(seq == "0.813780963,0.817659263,0.496835927", "난수 수열 " + seq)
	var some := SelfPlay.trained_brain("some")
	var first := "".join(some.boxes[Menace.FIRST_KEY].map(func(n): return str(n)))
	check(some.boxes.size() == 202 and Menace.total_beads(some) == 2590 and first == "10001248002", "조금 배운 AI %d %d %s" % [some.boxes.size(), Menace.total_beads(some), first])

	# 오늘 기록
	var t := Today.fresh("2026-10-28")
	t = Today.add_result(t, "kid", "2026-10-28")
	t = Today.add_result(t, "ai", "2026-10-28")
	check([t.games, t.kid, t.ai, t.draw] == [2, 1, 1, 0], "오늘 기록 더하기")
	check(Today.roll(t, "2026-10-29").games == 0, "날짜 바뀌면 새로")

	# 새 흐름: 오늘 선생님·졸업 수, 난이도 시뮬레이션, 체험 기록
	t = Today.add_teacher(t, "2026-10-28")
	t = Today.add_grad(t, "2026-10-28")
	check(t.teachers == 1 and t.grads == 1 and t.games == 2, "오늘 선생님·졸업")
	check(Today.from_json({"date": "2026-10-28", "games": 3}).teachers == 0, "옛 오늘 기록 읽기")
	var ev := SelfPlay.evaluate(Menace.new_brain(), 0.7, 200, SeededRng.new(3))
	check(ev.kid + ev.draw + ev.ai == 200, "시뮬레이션 판 수")
	var fresh_kid: int = ev.kid
	var trained_ai := Menace.new_brain()
	var tr := SeededRng.new(5)
	for i in SelfPlay.TRAIN_GAMES:
		SelfPlay.play_one(trained_ai, SelfPlay.TRAIN_OPPONENT, tr)
	ev = SelfPlay.evaluate(trained_ai, 0.7, 200, SeededRng.new(3))
	check(ev.kid < fresh_kid, "빨리 감기 뒤에는 학생이 덜 이김 (%d → %d)" % [fresh_kid, ev.kid])
	Telemetry.enabled = false
	Telemetry.begin({"flow": "new"})
	Telemetry.stage("play1")
	Telemetry.tap()
	Telemetry.add_round({"stage": 1, "outcome": "kid"})
	check(Telemetry.active(), "기록 시작")
	Telemetry.end("grad")
	check(not Telemetry.active(), "기록 끝")

	# 저장: 임시 파일 → .bak → 본 파일. 본 파일이 깨지면 .bak을 읽는다
	var path := "user://test-store.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)
	check(Store.write_safe(path, {"a": 1}), "저장 쓰기")
	check(Store.read_safe(path).a == 1, "저장 읽기")
	check(Store.write_safe(path, {"a": 2}) and Store.read_safe(path).a == 2, "덮어쓰기")
	check(FileAccess.file_exists(path + ".bak") and Store.read_safe(path + ".bak").a == 1, "예비 파일에 전 내용")
	check(not FileAccess.file_exists(path + ".tmp"), "임시 파일 안 남음")
	var broken := FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("{\"a\": ")
	broken.close()
	check(Store.read_safe(path).a == 1, "깨진 파일이면 예비 파일")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)

	# 선생님 비밀번호 규칙
	check(Store.is_valid_password("admin") and Store.is_valid_password("a1") and Store.is_valid_password("abcdefghij12"), "비밀번호 허용")
	check(not Store.is_valid_password("") and not Store.is_valid_password("Admin") and not Store.is_valid_password("abcdefghij123") and not Store.is_valid_password("한글"), "비밀번호 거부")

	print("테스트 %d개 중 %d개 통과" % [_count, _count - _fails])
	quit(1 if _fails > 0 else 0)
