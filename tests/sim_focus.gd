extends SceneTree
## 학생과 둘 때의 쏠림 정도(Menace.FOCUS_KID)를 정하는 시뮬레이션.
## 실행: godot --headless --path . --script res://tests/sim_focus.gd
## 빨리 감기를 마친 AI가 쏠림 정도마다 학생에게 얼마나 지는지(졸업 시험 난이도)와,
## 몇 판 안 둔 AI에서 "가장 확률이 높은 칸"이 실제로 뽑히는 비율(맞혀 보기가 맞는 정도)을 잰다.


func _init() -> void:
	print("쏠림 | 졸업 시험에서 학생이 이기는 % (실력 0.5 / 0.9 / 최고) | 가장 높은 칸이 뽑히는 % (구슬 7·4·4 / 6·3·3·3 / 5·4·4)")
	for focus in [1.0, 2.0, 3.0, 4.0, 6.0, 1000.0]:
		var kid := [0, 0, 0]
		var all := 0
		for seed in 8:
			var brain := Menace.new_brain()
			var rng := SeededRng.new(2000 + seed)
			for i in SelfPlay.TRAIN_GAMES:
				SelfPlay.play_one(brain, SelfPlay.TRAIN_OPPONENT, rng)
			kid[0] += SelfPlay.evaluate(brain, 0.5, 400, rng, focus).kid
			kid[1] += SelfPlay.evaluate(brain, 0.9, 400, rng, focus).kid
			for i in 400:
				if SelfPlay.play_one(Menace.clone_brain(brain), "perfect", rng, false, focus) == "kid":
					kid[2] += 1
			all += 400
		var tops := []
		for beads in [[7, 4, 4], [6, 3, 3, 3], [5, 4, 4]]:
			tops.append(roundi(Menace.chances(beads, focus)[0] * 100))
		print("%6.0f | %4.1f / %4.1f / %4.1f | %d / %d / %d" % [focus, kid[0] * 100.0 / all, kid[1] * 100.0 / all, kid[2] * 100.0 / all, tops[0], tops[1], tops[2]])
	quit()
