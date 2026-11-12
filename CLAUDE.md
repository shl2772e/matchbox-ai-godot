# CLAUDE.md

웹 앱 **성냥갑 AI**(`C:\antigravity\matchbox-ai`, MENACE 1961 틱택토 강화학습 체험)를 Godot 4(2D)로 옮기고 애니메이션을 더한 버전이다. 규칙·문구·디자인(시안 A "1961 성냥갑 연구실")의 기준은 웹 앱의 PRD(`matchbox-ai/docs/성냥갑AI(틱택토 강화학습) PRD.md`)다. 웹 앱 코드는 참조만 하고 고치지 않는다.

## 범위 (v0.2)
- 놀이 방식은 둘이다 (선생님 메뉴 "놀이 방식", `settings.newflow`). 기본은 새 흐름이다.
- **새 흐름 "AI 졸업시키기"** (약 4분, 3단계 고정): 대기 → 1단계 새내기(보기) → 2단계 연습생(맞혀 보기) → 빨리 감기(AI 혼자 200판) → 3단계 졸업 시험 → 졸업장. 판이 끝날 때마다 놀이 화면에서 학생이 제 손으로 상과 벌을 준다(`TeachPanel`, 6초 손대지 않으면 저절로). 학생마다 새내기 AI(`session_brain`)로 시작하고, 학생이 둔 판은 저장되는 "우리 반 AI"(`brain`)에도 쌓인다. "강화학습"이라는 낱말은 졸업장에서 처음 나온다. 설계 근거와 평가 지표는 `local-docs/성냥갑 AI 개선 계획서.md`(git에 없음).
- 맞혀 보기: 2·3단계에서 한 판에 한 번, 서랍이 열린 뒤 학생이 칸을 누른다. 4초 안에 안 누르면 넘어간다. 맞고 틀림을 축하하지 않고 구슬 수만 말한다.
- 빨리 감기 판 수·연습 상대(`SelfPlay.TRAIN_GAMES`, `TRAIN_OPPONENT`)는 `tests/sim_difficulty.gd`로 정한다 (목표: 졸업 시험에서 학생이 이기는 비율 20~40%). 화면에 보이는 판 수만큼만 실제로 둔다.
- 체험 기록: `Telemetry`가 체험 한 번을 한 줄 JSON으로 `user://records/날짜.jsonl`에 남긴다 (이름·얼굴 없음). `tests/log_report.gd`가 지표를 계산한다. `--qa` 때는 기록하지 않는다.
- **예전 흐름** (비교용): 대기 → 안내 4장(신문·앨범·구슬·상과 벌) → 놀이(판 수 1~5) → 배우는 순간 → 결과. 우리 반 AI와 둔다.
- 공통: 60초 무입력 시 대기로, 저장(두뇌·오늘 기록·설정), 소리.
- 대기 화면을 20초 그대로 두면 안내 4장이 한 장씩(9초) 저절로 넘어간다(`IntroScreen.attract`, 기다리는 학생이 본다). 누르면 바로 체험을 시작한다.
- 교사용 안내: 선생님 메뉴 제목 줄의 동그란 i 단추(`TeacherLayer.GUIDE`). 흐름, 체험 뒤 질문 3가지, 운영 방법, 기록 위치.
- 문구는 대본 A "오늘 내가 AI 선생님"(`docs/설명 대본 시안.md`). 학생은 "나", AI는 "AI"로 부른다 ("네/너" 금지).
- 안내 사진은 CC BY-SA라 출처를 화면과 `docs/CREDITS.md`에 적는다. 사진을 바꾸면 둘 다 고친다. 새 흐름에서는 졸업장의 "1961년 이야기 보기"가 같은 안내 화면(`IntroScreen`)을 연다.
- 선생님 메뉴(`scripts/ui/teacher_layer.gd`, CanvasLayer 10): 오른쪽 위 자물쇠 → 비밀번호(기본 `admin`, 영문 소문자·숫자 1~12자, `user://teacher.json`) → 메뉴. 한 번 열면 5분 동안 다시 묻지 않는다. 항목: 처음 화면으로, AI 고르기(우리 반 AI), 놀이 방식(새 흐름/예전 흐름), 판 수 1~5와 안내(예전 흐름일 때만 보임), 확률·소리·전체화면 켬/끔(메뉴를 닫지 않고 바로 바뀜), 오늘 기록 지우기, 비밀번호 바꾸기, 프로그램 끝내기. 모달이 열려 있으면 60초 대기 시계가 멈춘다. 놀이 화면 머리 오른쪽 3.2R는 이 버튼 자리로 비워 둔다.
- 아직 없음: 관객 화면(외부 모니터), 두뇌 파일 저장/불러오기, 녹음한 효과음·배경음과 그린 그림(지금은 모두 코드로 만든 소리·도형).

## 구조
- `scripts/domain/` 순수 규칙 (노드·화면 없음): `ttt.gd`(판·승부·대칭), `menace.gd`(상자·구슬·두기·배우기), `self_play.gd`(혼자 두기·AI 단계·난이도 시뮬레이션), `today.gd`, `rng.gd`(mulberry32, 웹 앱과 같은 수열 — 같은 시드면 웹 앱과 같은 AI).
- `scripts/ui/kit.gd` 색·글꼴·그림 도구. 색은 여기 상수만 쓴다. `Kit.R`(27px)이 웹의 1rem.
- `scripts/ui/` 그리는 부품: `board_view.gd`(판, 내 차례면 테두리가 밝아지고 1초 뒤 안내: 빈칸마다 옅은 ×가 숨 쉬고 손가락이 빈칸을 옮겨 다니며 두드린다. 한 칸만 누르라는 뜻으로 보이지 않게), `matchbox_view.gd`(성냥갑·서랍), `thought_bubble.gd`(생각 풍선, 서랍을 감싸고 꼬리가 기계로 이어짐), `machine_view.gd`(성냥갑 기계 캐릭터 "AI", 구슬을 꺼내는 동안 톱니가 돌고 `mood`로 표정이 바뀐다: calm·lost·think·happy·sad·resign), `teach_panel.gd`(내 손으로 상과 벌 주기), `drawn.gd`.
- 놀이 화면 "무대 조명": 내 차례엔 풍선+서랍(CanvasGroup `_mind`)이 55%로 흐려지고 판이 밝아진다. AI 차례엔 반대. 풍선 주인은 로봇이 아니라 성냥갑 기계다(1961년 세계관).
- `scripts/screens/` 화면. 위치는 `relayout()`에서 직접 계산하고, 세로 화면(`portrait()`)이면 배치만 바꾼다.
- 새 흐름 화면: `play_screen.gd`(opts.newflow면 단계 이름·여는 한마디·맞혀 보기·상벌 주기), `train_screen.gd`(빨리 감기), `grad_screen.gd`(졸업장: 칭호, 처음·지금 첫 상자, 강화학습 한마디, 한 문제). 확률 표시를 켜면(중등) 졸업장에 상태·행동·보상 낱말이 붙는다.
- `scripts/main.gd` 화면 흐름. `scripts/sfx.gd`(자동 로드 `Sfx`) 소리를 코드로 만든다. `scripts/telemetry.gd` 체험 기록.
- 화면 기준 1920×1080, stretch `canvas_items` + `expand`. 렌더러는 GL Compatibility(현장 PC 호환).

## 규칙
- 화면 글자에 이모지·←/→를 쓰지 않는다. 문구는 초등 3학년이 읽을 수 있게.
- AI 차례 연출은 1.2초 안: 서랍 열림 0.45초 → 구슬 떠오름 0.2초 → 판으로 날아감 0.4초. 뽑기·당첨처럼 보이는 연출(번쩍임, 뜸 들이기) 금지.
- 줄바꿈이 있는 글자는 `Kit.label(..., wrap=true)`로 만들고 `Kit.place()`로 놓는다 (낱말 중간에서 안 끊기게, 높이는 글꼴로 잼).
- 놀이 화면의 설명줄은 언제나 두 줄까지(`PlayScreen._fit_message`, 넘치면 글자를 줄인다). 가로 화면에서는 성냥갑 기계를 오른쪽 끝에 두고 설명줄이 판 아래부터 풍선 꼬리 앞까지 넓게 쓴다.
- GDScript에서 여러 줄 람다를 함수 인자로 넘기지 않는다. 메서드 + `bind()`를 쓴다.

## 명령어 (Godot 경로: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\`)
- 실행: `run.bat` (전체화면, F11로 창 모드). **run.bat에는 한글을 쓰지 않는다** (cmd가 UTF-8 한글을 읽다 깨진다), 줄 끝은 CRLF.
- 편집기: `Godot_v4.7.2-stable_win64.exe --path . -e`
- 테스트: `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd`
- 화면 점검(선생님 메뉴 3장 + 지금 놀이 방식으로 끝까지 자동 진행 후 PNG 저장, 5~6분 걸림): `... --path . --resolution 1920x1080 -- --qa=<폴더>` (세로는 `1080x1920`). 점검 중에는 저장하지 않는다(`Store.frozen`).
- 난이도 시뮬레이션: `... --headless --path . --script res://tests/sim_difficulty.gd`. 체험 기록 지표: `... --headless --path . --script res://tests/log_report.gd`.
- `--script`로 돌리는 테스트에서는 자동 로드(`Sfx`)를 쓰는 화면 클래스를 부르지 않는다 (컴파일 오류). 규칙 상수는 `scripts/domain/`에 둔다.
- 스크립트를 새로 만들었으면 먼저 `--headless --path . --import`로 클래스 목록을 갱신한다.
- 실행 파일 내보내기: `... --headless --path . --export-release "Windows Desktop" build/matchbox-ai.exe` → `build/matchbox-ai.exe` 하나(PCK 포함, 약 120MB)를 현장 PC에 복사하면 된다. 내보낸 실행 파일은 전체화면으로 시작한다. `tests/`·`docs/`는 빼고 넣는다(export_presets.cfg). export templates는 `%APPDATA%\Godot\export_templates\4.7.2.stable\`에 Windows x86_64 4개만 넣었다(없으면 GitHub 릴리스의 `Godot_v4.7.2-stable_export_templates.tpz`에서 꺼낸다).
- 웹 내보내기: `... --headless --path . --export-release "Web" build/web/index.html` (스레드 없는 템플릿 `web_nothreads_*.zip`이라 서버에 특별한 헤더가 필요 없다). `build/web`을 Vercel에 정적 사이트로 올린다(`npx vercel deploy build/web --prod`). 웹에서는 전체화면·프로그램 끝내기 항목을 숨긴다.
- 오픈그래프: 태그는 `export_presets.cfg`의 Web 프리셋 `html/head_include`에 있고(주소가 바뀌면 여기를 고친다), 공유 이미지는 `web/og.png`(1200×630, 대기 화면에서 잘라 만듦). 내보낸 뒤 `web/og.png`를 `build/web/`에 복사하고 올린다.
- Vercel 프로젝트(`web`)는 GitHub 저장소와 연결하지 않는다(`vercel git disconnect`). 연결돼 있으면 푸시할 때마다 Godot 소스가 사이트를 덮어써 404가 된다. 사이트는 `build/web`을 직접 올릴 때만 바뀐다.
- 저장 파일(`%APPDATA%\matchbox-ai-godot\*.json`)은 `.tmp`에 쓴 뒤 `.bak`을 남기고 바꾼다. 본 파일이 깨지면 `.bak`을 읽는다.
