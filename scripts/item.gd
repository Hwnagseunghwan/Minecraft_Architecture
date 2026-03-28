extends RigidBody3D

var item_name : String = ""

func setup(name: String, color: Color, despawn_time: float = 30.0) -> void:
	item_name = name
	collision_layer = 2
	collision_mask  = 1
	add_to_group("items")

	_build_mesh(name, color)

	# 충돌체
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.28, 0.28, 0.28)
	cs.shape = sh
	add_child(cs)

	linear_velocity  = Vector3(randf_range(-1.5, 1.5), randf_range(2.0, 4.0), randf_range(-1.5, 1.5))
	angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))

	get_tree().create_timer(despawn_time).timeout.connect(queue_free)

func _add_part(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = pos
	add_child(mi)

func _build_mesh(name: String, color: Color) -> void:
	match name:
		"Feather":       _build_feather(color)
		"ChickenMeat":   _build_chicken_meat()
		"Leather":       _build_leather()
		"BeefMeat":      _build_beef_meat()
		"RawFish":       _build_raw_fish()
		"Egg":           _build_egg(color)
		"DinosaurClaw":  _build_dino_claw()
		_:
			_add_part(Vector3.ZERO, Vector3(0.28, 0.28, 0.28), color)

# ── 깃털 (닭=흰색 / 새=파란색, color로 구분) ──────────────
func _build_feather(color: Color) -> void:
	var dark := Color(color.r * 0.82, color.g * 0.82, color.b * 0.82)
	# 깃대
	_add_part(Vector3(0,  0.00, 0), Vector3(0.03, 0.26, 0.03), dark)
	# 깃 (위→아래로 넓어지다 좁아지는 모양)
	_add_part(Vector3(0,  0.09, 0), Vector3(0.08, 0.04, 0.03), color)
	_add_part(Vector3(0,  0.05, 0), Vector3(0.13, 0.04, 0.03), color)
	_add_part(Vector3(0,  0.01, 0), Vector3(0.15, 0.04, 0.03), color)
	_add_part(Vector3(0, -0.03, 0), Vector3(0.13, 0.04, 0.03), color)
	_add_part(Vector3(0, -0.07, 0), Vector3(0.09, 0.04, 0.03), color)
	_add_part(Vector3(0, -0.11, 0), Vector3(0.05, 0.03, 0.03), color)

# ── 닭고기 (고기 덩어리 + 뼈) ─────────────────────────────
func _build_chicken_meat() -> void:
	var meat  := Color(0.85, 0.42, 0.32)
	var meat2 := Color(0.78, 0.35, 0.26)
	var bone  := Color(0.92, 0.90, 0.86)
	# 고기 덩어리
	_add_part(Vector3( 0.00,  0.04, 0.00), Vector3(0.22, 0.14, 0.18), meat)
	_add_part(Vector3( 0.04,  0.01, 0.02), Vector3(0.10, 0.08, 0.10), meat2)
	# 뼈 기둥
	_add_part(Vector3( 0.00, -0.08, 0.00), Vector3(0.05, 0.10, 0.05), bone)
	# 뼈 끝 마디
	_add_part(Vector3( 0.00, -0.14, 0.00), Vector3(0.10, 0.05, 0.10), bone)

# ── 가죽 (평평한 조각 + 주름) ─────────────────────────────
func _build_leather() -> void:
	var base  := Color(0.55, 0.35, 0.18)
	var dark  := Color(0.44, 0.27, 0.13)
	# 가죽 본체
	_add_part(Vector3( 0.00,  0.00,  0.00), Vector3(0.28, 0.04, 0.22), base)
	# 주름 라인
	_add_part(Vector3(-0.07,  0.03,  0.00), Vector3(0.05, 0.03, 0.18), dark)
	_add_part(Vector3( 0.07,  0.03,  0.00), Vector3(0.05, 0.03, 0.18), dark)
	# 테두리 두께감
	_add_part(Vector3( 0.00,  0.02,  0.10), Vector3(0.26, 0.03, 0.04), dark)
	_add_part(Vector3( 0.00,  0.02, -0.10), Vector3(0.26, 0.03, 0.04), dark)

# ── 소고기 (두꺼운 스테이크 단면) ─────────────────────────
func _build_beef_meat() -> void:
	var red   := Color(0.80, 0.28, 0.22)
	var fat   := Color(0.92, 0.85, 0.80)
	var fat2  := Color(0.88, 0.78, 0.74)
	# 고기 본체
	_add_part(Vector3( 0.00,  0.00,  0.00), Vector3(0.26, 0.20, 0.20), red)
	# 지방 마블링 (위)
	_add_part(Vector3( 0.00,  0.09,  0.00), Vector3(0.24, 0.04, 0.18), fat)
	# 지방 줄기
	_add_part(Vector3( 0.06,  0.02,  0.00), Vector3(0.07, 0.14, 0.18), fat2)
	_add_part(Vector3(-0.06, -0.02,  0.00), Vector3(0.05, 0.10, 0.16), fat2)

# ── 생선 (미니 물고기 형태) ────────────────────────────────
func _build_raw_fish() -> void:
	var body  := Color(1.00, 0.52, 0.12)
	var belly := Color(1.00, 0.75, 0.40)
	var tail  := Color(1.00, 0.36, 0.06)
	var eye   := Color(0.08, 0.06, 0.04)
	# 몸통 (등)
	_add_part(Vector3( 0.02,  0.01,  0.00), Vector3(0.20, 0.10, 0.08), body)
	# 배
	_add_part(Vector3( 0.02, -0.02,  0.00), Vector3(0.16, 0.05, 0.06), belly)
	# 머리
	_add_part(Vector3( 0.11,  0.00,  0.00), Vector3(0.08, 0.10, 0.08), body)
	# 눈
	_add_part(Vector3( 0.13,  0.03,  0.04), Vector3(0.04, 0.04, 0.03), eye)
	_add_part(Vector3( 0.13,  0.03, -0.04), Vector3(0.04, 0.04, 0.03), eye)
	# 꼬리 기둥
	_add_part(Vector3(-0.12,  0.00,  0.00), Vector3(0.04, 0.12, 0.05), tail)
	# 꼬리 갈래
	_add_part(Vector3(-0.17,  0.05,  0.00), Vector3(0.08, 0.06, 0.04), tail)
	_add_part(Vector3(-0.17, -0.05,  0.00), Vector3(0.08, 0.06, 0.04), tail)
	# 등지느러미
	_add_part(Vector3( 0.02,  0.09,  0.00), Vector3(0.10, 0.06, 0.03), tail)

# ── 달걀 (구형) ────────────────────────────────────────────
func _build_egg(color: Color) -> void:
	var mi  := MeshInstance3D.new()
	var sm  := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.13
	mi.mesh   = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)

# ── 공룡 발톱 (휘어진 날카로운 발톱) ──────────────────────
func _build_dino_claw() -> void:
	var c1 := Color(0.55, 0.55, 0.20)
	var c2 := Color(0.50, 0.50, 0.17)
	var c3 := Color(0.45, 0.45, 0.14)
	# 발톱 기부 (두꺼운 뿌리)
	_add_part(Vector3( 0.00,  0.07,  0.00), Vector3(0.10, 0.10, 0.08), c1)
	# 발톱 몸체
	_add_part(Vector3( 0.00,  0.01,  0.00), Vector3(0.08, 0.09, 0.06), c2)
	# 발톱 중간 (앞으로 휘기 시작)
	_add_part(Vector3( 0.02, -0.06,  0.00), Vector3(0.06, 0.07, 0.05), c2)
	# 발톱 끝부분
	_add_part(Vector3( 0.05, -0.11,  0.00), Vector3(0.04, 0.06, 0.04), c3)
	_add_part(Vector3( 0.08, -0.15,  0.00), Vector3(0.03, 0.05, 0.03), c3)
	# 발톱 뾰족한 끝
	_add_part(Vector3( 0.10, -0.18,  0.00), Vector3(0.02, 0.04, 0.02), c3)
