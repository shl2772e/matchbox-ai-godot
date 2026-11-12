extends SceneTree
## 난이도 시뮬레이션: 새내기 AI가 혼자 n판을 연습한 뒤, 실력이 다른 학생과 두면 누가 얼마나 이기나.
## 실행: godot --headless --path . --script res://tests/sim_difficulty.gd
## 빨리 감기 판 수(TrainScreen.GAMES)와 연습 상대(TrainScreen.OPPONENT)를 정할 때 쓴다.
## 목표: 졸업 시험에서 학생이 이기는 비율 20~40%.


func _init() -> void:
	var skills := [0.3, 0.5, 0.7, 0.9]
	print("연습 상대 / 판 수 → 학생 실력별 [학생 승 %, 비김 %, AI 승 %] (실력 = 꼼꼼하게 두는 확률)")
	for opp in ["mixed", "careful"]:
		for n in [0, 100, 200, 300, 500, 1000]:
			var line := "%-8s %5d판 " % [opp, n]
			for p in skills:
				var tot := {"kid": 0, "draw": 0, "ai": 0}
				for seed in 8:
					var brain := Menace.new_brain()
					var rng := SeededRng.new(1000 + seed)
					for i in n:
						SelfPlay.play_one(brain, opp, rng)
					var r := SelfPlay.evaluate(brain, p, 300, rng)
					for k in tot:
						tot[k] += r[k]
				var all: float = tot.kid + tot.draw + tot.ai
				line += " | 실력 %.1f: %2d %2d %2d" % [p, roundi(tot.kid * 100 / all), roundi(tot.draw * 100 / all), roundi(tot.ai * 100 / all)]
			print(line)
	quit()
