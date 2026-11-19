extends SceneTree
## AI 키우기 대회: 계획마다 점수가 어떻게 나오는지 본다 (같은 계획은 언제나 같은 점수).
## 실행: godot --headless --path . --script res://tests/sim_contest.gd
## 칸 순서: 아무 데나, 모서리, 가운데, 공격만, 막기만, 아주 잘 두는


func _init() -> void:
	var plans := [
		[1000, 0, 0, 0, 0, 0], [0, 1000, 0, 0, 0, 0], [0, 0, 1000, 0, 0, 0], [0, 0, 0, 1000, 0, 0], [0, 0, 0, 0, 1000, 0], [0, 0, 0, 0, 0, 1000],
		[200, 200, 200, 200, 200, 0], [170, 170, 165, 165, 165, 165], [0, 0, 0, 500, 500, 0], [200, 0, 0, 400, 400, 0], [100, 0, 0, 300, 300, 300],
		[0, 0, 0, 400, 400, 200], [300, 100, 100, 250, 250, 0], [100, 150, 100, 250, 300, 100], [105, 145, 100, 250, 300, 100], [100, 150, 100, 255, 295, 100],
	]
	print("계획 [아무 데나, 모서리, 가운데, 공격만, 막기만, 아주 잘 두는] → 점수")
	for p in plans:
		print("%s → %d점" % [str(p), SelfPlay.contest_score(p)])
	# 무작위 계획 200개의 점수 분포
	var rng := SeededRng.new(77)
	var scores := []
	for i in 200:
		var cut := [0, 200]
		for k in 5:
			cut.append(floori(rng.next() * 201))
		cut.sort()
		var p := []
		for k in 6:
			p.append((cut[k + 1] - cut[k]) * 5)
		scores.append(SelfPlay.contest_score(p))
	scores.sort()
	print("무작위 계획 200개: 가장 낮은 %d, 가운데 %d, 위에서 10번째 %d, 가장 높은 %d" % [scores[0], scores[100], scores[190], scores[199]])
	quit()
