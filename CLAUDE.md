# Minecraft_Architecture 프로젝트 컨텍스트

## 경로
- 프로젝트: `C:\Minecraft_Architecture`
- Godot 실행: `C:\Users\USER\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.1-stable_win64.exe`
- GitHub: `https://github.com/Hwnagseunghwan/Minecraft_Architecture` (계정명: Hwnagseunghwan)
- git: 이름 Hwangseunghwan / zen896@gmail.com

### Godot 실행 명령
```bash
"/c/Users/USER/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.6.1-stable_win64.exe" --path "C:/Minecraft_Architecture"
```

---

## 스택
- Godot 4.6.1, GL Compatibility (ANGLE 전환 정상), GDScript strict
- GPU: Radeon 540 (저사양, 셰이더 복잡도 주의)

---

## 스크립트 구조

| 파일 | 역할 |
|------|------|
| `main.gd` | 씬 진입점, 환경/조명/밤낮/경계벽 생성, 시그널 연결 |
| `world.gd` | 지형 64×64, 블록 배치/제거, 메시 풀, 균열, 동물 스폰 |
| `player.gd` | 이동/점프, 건축/전투 모드(F키), 체력, 인벤토리 |
| `animal.gd` | 닭/소/물고기/새/공룡 AI, 피격/사망/전리품 드롭 |
| `item.gd` | 드롭 아이템 (RigidBody3D, "items" 그룹) |
| `ui.gd` | 크로스헤어, 핫바(아이템), 하트, 모드표시, 사망화면 |

---

## 주요 구현 현황

### 블록 (13종)
`SELECTABLE_BTYPES = [0,1,2,3,4,5,6,7,9,10,11,12]` (WATER=8 제외)
- 버텍스 컬러 노이즈 메시 (셰이더 → 회색화면 이슈로 전환)
- 메시 풀 MESH_VARIANTS=16, 균열 파괴 1.5초

### 동물/공룡
| 종류 | HP | 전리품 |
|------|----|--------|
| 닭 | 3 | Feather, ChickenMeat |
| 소 | 3 | Leather, BeefMeat |
| 물고기 | 3 | RawFish |
| 새 | 3 | Feather, Egg |
| 공룡 | 10 | DinosaurClaw x2~4 |

- 공룡: 플레이어가 먼저 공격해야 반격 (`_aggro` 플래그)
- 공룡 그룹: `"dinosaurs"`
- 새: 맵 경계 안에서만 비행

### 체력 시스템
- MAX_HP=20, 하트 10개 (1하트=HP2, 반쪽 하트 지원)
- 공룡 1타 = 5 데미지 (2.5하트)
- 5초 후 자동 회복 (1초마다 +1)
- 피격=빨간 플래시, 회복=노란 플래시
- HP=0 → 사망 → 인벤토리 드롭(1분 소멸) → 3초 후 부활

### 모드 (F키 전환)
- 건축모드: 좌클릭=블록파괴, 우클릭=블록배치
- 전투모드: 좌클릭=몽둥이 공격+스윙 애니메이션

### UI
- 하단 중앙: 아이템 핫바 9칸 (수집 시 채워짐)
- 좌하단: 블록 선택 패널 + 하트
- 우상단: 현재 모드 표시
- 밤낮: 120초 사이클 (main.gd `_process`)

### 맵
- 64×64, 투명 경계벽 (높이 30), 안전망
- 플레이어 스폰: Vector3(32, 5, 32)

---

## 주의사항 (GDScript)
- `var item = item_script.new()` — 타입 미선언 필수 (RigidBody3D 선언 시 파싱 오류)
- Dictionary 값: `var x : Color = dict["key"]` 명시적 타입 필요
- `@onready` 불가한 동적 노드는 `_ready()`에서 직접 생성
- 회색 화면 = GDScript 파싱 오류, Godot Output 패널 확인
- Godot 에디터 스크립트 수정 후 재시작 필요할 때 있음

---

## 다음 후보 작업
- 멀티플레이어 (Tailscale VPN + Godot ENet 권장, 최대 5명)
