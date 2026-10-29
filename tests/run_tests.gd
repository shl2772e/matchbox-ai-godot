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

	print("테스트 %d개 중 %d개 통과" % [_count, _count - _fails])
	quit(1 if _fails > 0 else 0)
