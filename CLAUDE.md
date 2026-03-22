# Minecraft_Architecture 프로젝트 컨텍스트

## 경로 정보

| 항목 | 경로 |
|------|------|
| 프로젝트 루트 | `C:\Minecraft_Architecture` |
| Godot 실행파일 | `C:\Users\USER\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.1-stable_win64.exe` |
| 스크립트 폴더 | `C:\Minecraft_Architecture\scripts\` |
| 씬 폴더 | `C:\Minecraft_Architecture\scenes\` |

### Godot 실행 명령
```bash
"/c/Users/USER/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.6.1-stable_win64.exe" --path "C:/Minecraft_Architecture"
```

---

## 기술 스택

- **엔진**: Godot 4.6.1 (GL Compatibility 렌더러, OpenGL 3.3)
- **언어**: GDScript (strict 타입 권장)
- **GPU**: Radeon 540 (저사양 — 셰이더 복잡도 주의)
- **GitHub**: `https://github.com/Hwnagseunghwan/Minecraft_Architecture`
  - git 사용자명: `Hwangseunghwan` / 이메일: `zen896@gmail.com`
  - GitHub 계정: `Hwnagseunghwan` (오타 아님, 실제 계정명)

---

## 스크립트 구조 및 역할

| 파일 | 기반 클래스 | 역할 |
|------|------------|------|
| `scripts/main.gd` | Node3D | 씬 진입점. 환경/조명/월드/플레이어/UI 생성 및 시그널 연결 |
| `scripts/world.gd` | Node3D | 지형 생성, 블록 배치/제거, 메시 풀, 균열 오버레이, 동물 스폰 |
| `scripts/player.gd` | CharacterBody3D | 이동/점프, 블록 파괴(균열), 배치, 동물 공격, 인벤토리 수집 |
| `scripts/animal.gd` | CharacterBody3D | 닭/소/물고기/새 AI, 피격/사망/파티클/전리품 드롭 |
| `scripts/item.gd` | RigidBody3D | 드롭 아이템 물리, 그룹 "items" 등록, 30초 자동 삭제 |
| `scripts/ui.gd` | CanvasLayer | 크로스헤어, 핫바(12슬롯), 블록 이름 표시, 인벤토리 패널 |
| `scenes/Player.tscn` | — | CharacterBody3D + Head + Camera3D + RayCast3D(target -6) |

---

## 주요 설계 결정 (git에서 알 수 없는 이유)

### 1. 렌더러: GL Compatibility
- ANGLE 전환 경고가 뜨지만 정상 동작. Forward+ 사용 시 저사양 GPU에서 문제 발생 가능.

### 2. 버텍스 컬러 노이즈 (셰이더 아님)
- 블록 색상 변화를 **셰이더 대신 SurfaceTool 버텍스 컬러**로 구현.
- 이유: 셰이더 방식 시도 → 회색 화면 발생 → 버텍스 컬러 방식으로 전환.
- `_get_vertex_mat()`: `vertex_color_use_as_albedo = true`, SHADING_MODE_UNSHADED.

### 3. 메시 풀 (MESH_VARIANTS = 16)
- 64×64 맵에서 블록마다 고유 ArrayMesh 생성 시 성능 문제 → 타입당 16개 변형 풀로 해결.
- `_mesh_pool: Dictionary` — key: btype(int) 또는 color html string.

### 4. 동물 스폰 시 Variant 우회
- `Animal.new()` 반환값을 `var a : Node3D`로 받고 `.call("setup", type)` / `.set("_target_y", ...)` 사용.
- 이유: GDScript strict 모드에서 동적 로드 스크립트의 `.new()` 반환 타입 불명확.

### 5. attack_ray 동적 생성
- `@onready`로 선언 불가 — 커스텀 `_ready()` 코드보다 먼저 실행되어 null 참조 발생.
- 해결: `var attack_ray : RayCast3D = null`로 선언 후 `_ready()` 내에서 직접 생성/추가.

### 6. 아이템 드롭 타입 선언
- `var item = item_script.new()` — **타입 미선언** 필수.
- `var item : RigidBody3D = item_script.new()` 형태로 쓰면 파싱 오류 발생.

---

## 블록 타입 상수

| 상수 | 값 | 색상 |
|------|----|------|
| BLOCK_GRASS | 0 | Color(0.38, 0.68, 0.22) |
| BLOCK_DIRT | 1 | Color(0.50, 0.35, 0.20) |
| BLOCK_STONE | 2 | Color(0.55, 0.55, 0.55) |
| BLOCK_LOG | 3 | Color(0.35, 0.22, 0.10) |
| BLOCK_PLANK | 4 | Color(0.80, 0.65, 0.40) |
| BLOCK_GLASS | 5 | Color(0.75, 0.90, 1.00) — 반투명 |
| BLOCK_WHITE | 6 | Color(0.95, 0.95, 0.95) |
| BLOCK_RED | 7 | Color(0.80, 0.20, 0.20) |
| BLOCK_WATER | 8 | Color(0.20, 0.50, 0.90) — 반투명, 배치/제거 불가 |
| BLOCK_BRICK | 9 | Color(0.70, 0.30, 0.20) |
| BLOCK_CONCRETE | 10 | Color(0.75, 0.75, 0.75) |
| BLOCK_WOOD | 11 | Color(0.55, 0.38, 0.18) |
| BLOCK_ROOF | 12 | Color(0.28, 0.22, 0.16) |

플레이어 선택 가능: `SELECTABLE_BTYPES = [0,1,2,3,4,5,6,7,9,10,11,12]` (WATER 제외)

---

## 동물 전리품

| 동물 | 드롭 아이템 |
|------|------------|
| 닭 (CHICKEN) | Feather, ChickenMeat |
| 소 (COW) | Leather, BeefMeat |
| 물고기 (FISH) | RawFish |
| 새 (BIRD) | Feather, Egg |

- 1~2개 랜덤 드롭, 플레이어 반경 1.8m 자동 수집
- 아이템은 RigidBody3D, 그룹 "items", 30초 후 자동 삭제

---

## 조작키

| 키 | 동작 |
|----|------|
| WASD | 이동 |
| SPACE | 점프 |
| 좌클릭 (꾹) | 블록 파괴 (1.5초 균열 후) |
| 우클릭 | 블록 배치 / 동물 공격 (3블록 범위) |
| 휠 / 1~8 | 블록 선택 |
| R | 세계 초기화 |
| ESC | 마우스 커서 토글 |

---

## 밤낮 시스템 (main.gd)

- 1사이클 = **120초** (`DAY_LENGTH = 120.0`)
- `_time`: 0.0 = 정오, 0.5 = 자정
- 태양 각도: `_sun.rotation_degrees.x = angle - 90.0`
- 낮: 하늘 파란색, 노을 색상 전환, 태양 에너지 최대 1.4
- 밤: 하늘 검은색, 태양 꺼짐, ambient 0.04

---

## 알려진 이슈 / 주의사항

- **회색 화면**: GDScript 타입 오류 시 씬 로드 실패로 회색만 표시됨. Godot 에디터 Output 패널에서 오류 확인 필요.
- **Dictionary 값 타입**: `var x : Color = dict["key"]` 형태로 항상 명시적 타입 선언.
- **Godot 에디터 캐시**: 스크립트 수정 후 에디터 재시작 필요할 때 있음.
- **맵 크기**: 64×64, MAX_HEIGHT=14, 플레이어 스폰 Vector3(32, 5, 32).
