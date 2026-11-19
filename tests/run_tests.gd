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
	# 학생과 둘 때: 구슬이 많은 칸으로 쏠리고, 돌려준 확률(화면의 %)대로 뽑힌다
	brain.boxes[Menace.FIRST_KEY] = [7, 0, 0, 0, 4, 0, 0, 0, 4]
	var want: float = Menace.chances([7, 4, 4], Menace.FOCUS_KID)[0]
	var tops := 0
	var flagged := 0
	for i in 4000:
		var cf := Menace.choose_move(brain, Ttt.empty_board(), rng, Menace.FOCUS_KID)
		if cf.move.cell == 0:
			tops += 1
		if cf.top == (cf.move.cell == 0):
			flagged += 1
	check(want > 0.7 and absf(tops / 4000.0 - want) < 0.03, "학생과 둘 때는 많은 칸으로 쏠림 (%.2f, 실제 %.2f)" % [want, tops / 4000.0])
	check(flagged == 4000, "가장 높은 칸을 골랐는지 표시")
	var shown: Array = Menace.choose_move(brain, Ttt.empty_board(), rng, Menace.FOCUS_KID).chances
	check(absf(shown[0] - want) < 0.001 and absf(shown[0] + shown[4] + shown[8] - 1.0) < 0.001, "화면에 보일 확률")

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

	# 체험 통계: 기록 묶음에서 합계와 가운데 값
	var recs := [
		{"flow": "new", "end": "grad", "after": "again", "quiz": {"correct": true}, "stages": [{"name": "play1-1", "ms": 60000.0}, {"name": "explain1", "ms": 8000.0}, {"name": "grad", "ms": 5000.0}],
			"rounds": [{"stage": 1.0, "outcome": "kid", "kid_ms": [1000.0, 3000.0, 2000.0], "explored": 1.0, "predict": {"offered": true, "answered": true, "hit": true, "ms": 1500.0}, "teach": {"manual": 2.0, "total": 3.0}}]},
		{"flow": "new", "end": "timeout", "stages": [{"name": "play1-1", "ms": 90000.0}], "rounds": []},
		{"flow": "contest", "end": "left", "score": 520.0, "plan": [100.0, 200.0, 100.0, 250.0, 250.0, 100.0], "stages": [{"name": "plan", "ms": 12000.0}], "rounds": []},
	]
	var sum := Stats.summary(recs)
	var flat := {}
	for part in sum:
		for row in part[1]:
			flat[part[0] + "/" + row[0]] = row[1]
	check(flat["AI 가르치기/시작한 횟수"] == "2번" and flat["AI 가르치기/졸업장까지 간 비율"] == "50% (1 / 2)", "통계: 끝까지 간 비율")
	check(flat["AI 가르치기/1단계 승패"] == "학생 1 · 비김 0 · AI 0" and flat["AI 가르치기/1단계 한 수 두는 데 걸린 시간 (가운데 값)"] == "2.0초", "통계: 승패와 반응 시간")
	check(flat["AI 가르치기/졸업장까지 걸린 시간 (가운데 값)"] == "1분 8초" and flat["AI 가르치기/퀴즈 정답 비율"] == "100% (1 / 1)", "통계: 걸린 시간과 퀴즈")
	check(flat["AI 키우기 대회/점수 (평균 / 가장 높은 점수)"] == "520점 / 520점", "통계: 대회 점수")

	# 이름 자판: 낱자를 글자로 모으기
	check(Hangul.compose(["ㅅ", "ㅓ", "ㅇ", "ㄴ", "ㅑ", "ㅇ"]) == "성냥", "한글 모으기 성냥")
	check(Hangul.compose(["ㄱ", "ㅏ", "ㅂ", "ㅅ"]) == "값", "겹받침")
	check(Hangul.compose(["ㄱ", "ㅏ", "ㅂ", "ㅅ", "ㅣ"]) == "갑시", "겹받침이 다음 글자로")
	check(Hangul.compose(["ㅇ", "ㅗ", "ㅏ"]) == "와", "겹모음")
	check(Hangul.compose(["ㅁ", "ㅣ", "ㄴ", "ㅅ", "ㅜ"]) == "민수", "받침 뒤 새 글자")
	check(Hangul.compose(["ㄸ", "ㅏ", "ㄹ", "ㄱ", "ㅣ"]) == "딸기", "쌍자음 첫소리")
	check(Hangul.compose([]) == "" and Hangul.compose(["ㄱ"]) == "ㄱ", "빈 것과 낱자 하나")
	for ch in "ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎㅏㅐㅑㅒㅓㅔㅕㅖㅗㅛㅜㅠㅡㅣ":
		check(load("res://assets/fonts/GowunBatang-Bold.ttf").has_char(ch.unicode_at(0)), "자판 글자가 글꼴에 있음 " + ch)

	# AI 키우기 대회: 점수와 순위
	var cb := Menace.new_brain()
	var crng := SeededRng.new(11)
	var pts := 0
	for i in 60:
		pts += SelfPlay.contest_point(cb, "random", crng)
	check(pts >= 0 and pts <= 180, "대회 점수 범위")
	var mixed_ai := Menace.new_brain()
	var only_best := Menace.new_brain()
	var mix := ["random", "careful", "careful", "careful", "careful", "perfect"]
	for i in SelfPlay.CONTEST_GAMES:
		SelfPlay.play_one(mixed_ai, mix[floori(crng.next() * 6)], crng)
		SelfPlay.play_one(only_best, "perfect", crng)
	var pm := 0
	var pb := 0
	for kind in SelfPlay.CONTEST_KINDS:
		for i in 100:
			pm += SelfPlay.contest_point(mixed_ai, kind, crng)
			pb += SelfPlay.contest_point(only_best, kind, crng)
	check(pm > pb, "섞어서 연습한 AI가 잘 두는 상대하고만 연습한 AI보다 점수가 높음 (%d > %d)" % [pm, pb])
	# 연습 친구 여섯: 언제나 빈칸에 두고, 같은 계획이면 같은 점수
	for friend in SelfPlay.CONTEST_FRIENDS:
		var fb := B("120010000")
		var ok := true
		for i in 30:
			if fb[SelfPlay.kid_move(friend, fb, crng)] != 0:
				ok = false
		check(ok, "연습 친구가 빈칸에 둠 " + friend)
	check(SelfPlay.kid_move("defend", B("110020000"), crng) == 2 and SelfPlay.kid_move("attack", B("110220000"), crng) == 5, "막기만 하는 친구는 막고, 공격만 하는 친구는 이긴다")
	var plan_a := [100, 150, 100, 250, 300, 100]
	check(SelfPlay.contest_plan(plan_a).size() == SelfPlay.CONTEST_GAMES / SelfPlay.CONTEST_STEP, "계획 목록 크기")
	check(SelfPlay.contest_seed(plan_a) == SelfPlay.contest_seed(plan_a.duplicate()) and SelfPlay.contest_seed(plan_a) != SelfPlay.contest_seed([105, 145, 100, 250, 300, 100]), "계획마다 정해진 씨앗")
	var sc1 := SelfPlay.contest_score(plan_a)
	check(sc1 == SelfPlay.contest_score(plan_a) and sc1 > 0 and sc1 <= 700, "같은 계획은 같은 점수 (%d점)" % sc1)
	Store.frozen = true
	var rl := []
	check(Store.add_ranking(rl, {"name": "가", "score": 500, "plan": [2, 2, 2], "date": "d"}) == 1, "순위 첫 기록")
	check(Store.add_ranking(rl, {"name": "나", "score": 600, "plan": [1, 4, 1], "date": "d"}) == 1, "더 높은 점수는 1등")
	check(Store.add_ranking(rl, {"name": "다", "score": 550, "plan": [0, 6, 0], "date": "d"}) == 2 and rl[2].name == "가", "가운데 점수는 2등")
	Store.frozen = false

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
