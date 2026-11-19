extends SceneTree
## 성냥갑이 몇 개 필요한지 직접 센다 (AI가 먼저 두는 틱택토, 돌리거나 뒤집어 같은 판은 하나로).
## 실행: godot --headless --path . --script res://tests/count_boxes.gd


func _init() -> void:
	var seen := {}
	var stack := [Ttt.empty_board()]
	# 수 차례(AI의 몇 번째 수)마다: 전체, 끝나지 않은 판, 그 가운데 다음 수로 바로 이길 수 있는 판
	var by_turn := {}
	while not stack.is_empty():
		var b: Array = stack.pop_back()
		var k := Ttt.key_of(b)
		if seen.has(k):
			continue
		seen[k] = true
		if Ttt.outcome(b) != "":
			continue
		var ai_turn := Ttt.count(b, Ttt.AI) == Ttt.count(b, Ttt.KID)
		var empties := Ttt.empty_cells(b)
		if ai_turn:
			var t := Ttt.count(b, Ttt.AI) + 1
			if not by_turn.has(t):
				by_turn[t] = {}
			by_turn[t][Ttt.canonical(b).key] = true
		for c in empties:
			stack.append(Ttt.place(b, c, Ttt.AI if ai_turn else Ttt.KID))
	var total := 0
	for t in [1, 2, 3, 4, 5]:
		var n: int = by_turn[t].size()
		print("AI의 %d번째 수 차례인 판 모양: %d가지" % [t, n])
		total += n
	print("모두: %d, 넷째 수까지(마지막 한 칸은 상자가 필요 없음): %d" % [total, total - by_turn[5].size()])
	quit()
