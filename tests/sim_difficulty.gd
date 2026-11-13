extends SceneTree
## 난이도 시뮬레이션: 새내기 AI가 혼자 n판을 연습한 뒤, 여러 학생과 두면 학생이 얼마나 이기나.
## 실행: godot --headless --path . --script res://tests/sim_difficulty.gd
## 빨리 감기 판 수(SelfPlay.TRAIN_GAMES)와 연습 상대(SelfPlay.TRAIN_OPPONENT)를 정할 때 쓴다.
## 학생: 실력 0.5·0.9 = 그 확률로 꼼꼼하게(이기거나 막기) 두는 학생, 최고 = 함정까지 파는 가장 잘 두는 학생.
## "최고" 학생이 이기는 비율이 사람이 낼 수 있는 가장 높은 승률에 가깝다.


func _eval_perfect(brain: Dictionary, n: int, rng: SeededRng) -> Dictionary:
	var out := {"kid": 0, "draw": 0, "ai": 0}
	for i in n:
		out[SelfPlay.play_one(Menace.clone_brain(brain), "perfect", rng, false)] += 1
	return out


func _init() -> void:
	print("연습 상대 / 판 수 → [학생 승 %, 비김 %, AI 승 %]")
	for opp in ["careful", "tough", "perfect"]:
		for n in [300, 600, 1000, 2000, 4000]:
			var line := "%-8s %5d판 " % [opp, n]
			var tots := [{"kid": 0, "draw": 0, "ai": 0}, {"kid": 0, "draw": 0, "ai": 0}, {"kid": 0, "draw": 0, "ai": 0}]
			for seed in 6:
				var brain := Menace.new_brain()
				var rng := SeededRng.new(1000 + seed)
				for i in n:
					SelfPlay.play_one(brain, opp, rng)
				var rs := [SelfPlay.evaluate(brain, 0.5, 300, rng), SelfPlay.evaluate(brain, 0.9, 300, rng), _eval_perfect(brain, 300, rng)]
				for k in 3:
					for o in tots[k]:
						tots[k][o] += rs[k][o]
			var names := ["실력 0.5", "실력 0.9", "최고"]
			for k in 3:
				var all: float = tots[k].kid + tots[k].draw + tots[k].ai
				line += " | %s: %2d %2d %2d" % [names[k], roundi(tots[k].kid * 100 / all), roundi(tots[k].draw * 100 / all), roundi(tots[k].ai * 100 / all)]
			print(line)
	quit()
