# Univ_ShootMaster 졸업 프로젝트 META QUEST 를 위한 SHOOT MASTER VR 정리
![Thumb Image](https://raw.githubusercontent.com/IceCreamPie-dev/Univ_ShootMaster_summ/main/thumb.png)
[데모 영상 구글 드라이브](https://drive.google.com/file/d/1g--5IixpdHckdw8_ZNiHMM8ipB5-XK2W/view?usp=sharing)

졸업 논문 및 프로젝트를 위해 개발한 VR 클레이 사격게임, 아케이드성을 높인 사격게임을 통해 이용자의 반응속도와 사격능력을 향상 시키기 위해 개발하였다.

개발기간 (8주)
![Gant Image](https://github.com/IceCreamPie-dev/Univ_ShootMaster_summ/blob/main/gantCHarg.png)

**shooter_clay.tscn** - 클레이 발사장치 씬
```
var shooter = $shooter
shooter.shoot() # 기본속도로 발사
shooter.launch_angle = 10 # 10도 각도 조정
shooter.shoot(28.0) # 100km/h 를 m/s로
```


## SubtitleSystem

**자막표시**
```
SubtitleSystem.show_subtitle(" NAME ", " TEXT ", sec(float), NAME_COLOR(Color), TEXT_COLOR(Color))

```

**사운드 재생**
```
SubtitleSystem.sfx("res://path/to/sound.wav", vol(float))
```

## DialogManager

## 1. 초기 설정

1.1. DialogueManager를 AutoLoad로 추가합니다.

- 프로젝트 설정 -> AutoLoad 탭에서 DialogueManager 스크립트를 추가합니다.

1.2. 대화 파일 구조 설정:

- `res://Assets/Dialouges/[카테고리]/[대화키]_[언어코드].dialogue` 형식으로 파일을 생성합니다.
- 예: `res://Assets/Dialouges/Tutorial/start_ko.dialogue`

## 2. 대화 파일 작성

2.1. 대화 파일 예시:

```
~ start

아나운서: 안녕하신가!
[wait=1]
아나운서: 테스트1
[wait=1]
아나운서: 테스트세트ㅡㅌ테스트2
[wait=1]

~ normal_start
아나운서: 이런!
=> END

~ start_2
아나운서: 와!
=> END
```

## 3. 대화 시작

3.1. 스크립트에서 대화 시작:
에셋의 다이얼로그 폴더 안의 이동
```
func _ready():
	DialogueManager.start_dialogue("Tutorial/start")
	DialogueManager.start_dialogue("Tutorial/start", "normal_start")
```

## 4. 신호 연결

4.1. 대화 진행 상황을 추적하기 위한 신호 연결:

```
func _ready():
	DialogueManager.dialogue_started.connect(self._on_dialogue_start)
	DialogueManager.dialogue_ended.connect(self._ondialogue_ended)
	Dialoguemanager.dialogue_next.connect(self._on_dialogue_next)

func _on_dialogue_started(dialogue_key):
	print("대화 시작:", dialogue_key)

func _on_dialogue_ended():
	print("대화 종료)

func _on_dialoge_next(speaker, text):
	print(speaker + ": " + text)
```

## 5. 언어 설정

5.1. 언어 변경:

```
DialogueManager.set_language("ko")
```

## 6. 커스텀 명령어 사용

6.1. 대화 파일에 커스텀 명령어 추가:

```
아나운서: 이제 특별한 효과를 보여드리겠습니다. 
[do play_special_effect("explosion")] 
아나운서: 어떠셨나요?
```
```
~ start 
아나운서: 안녕하세요! 특별한 효과를 보여드리겠습니다. 
[play_sfx=Voice/Tutorial/tutorial_start_1.mp3]
[wait=2]  
[do emit_custom_signal "/root/MainScene/QuestSystem" "quest_started" "tutorial_quest"] 
아나운서: 튜토리얼 퀘스트가 시작되었습니다. 
=> END
```


6.2. 커스텀 명령어 구현:

`func play_special_effect(effect_name):     # 효과 재생 로직    pass`

## 주의사항

- 대화 파일의 인코딩이 UTF-8인지 확인하세요.
- 지원하는 언어 코드를 정확히 사용해야 합니다 (예: "ko", "en", "ja").
- SubtitleSystem이 구현되어 있어야 자막 표시 기능이 작동합니다.
