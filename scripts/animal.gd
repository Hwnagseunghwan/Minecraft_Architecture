extends CharacterBody3D

const GRAVITY : float = 20.0

const CHICKEN = 0
const COW     = 1
const FISH    = 2
const BIRD    = 3
const DINO    = 4

const MAP_MIN : float = 2.0
const MAP_MAX : float = 62.0

var animal_type    : int   = CHICKEN
var _speed         : float = 1.2
var _dir           : Vector3 = Vector3.ZERO
var _timer         : float = 0.0
var _floating      : bool  = false
var _target_y      : float = 0.0
var hp             : int   = 3
var _original_mats : Array = []
var _is_dead       : bool  = false
var _aggro         : bool  = false   # 공룡 전용: 플레이어가 먼저 공격하면 true

var _sound_timer   : float = 0.0    # 울음 간격 타이머

# 애니메이션 변수
var _leg_pivots  : Array  = []
var _wing_pivots : Array  = []
var _tail_pivot  : Node3D = null
var _body_node   : Node3D = null
var _body_base_y : float  = 0.0
var _anim_phase  : float  = 0.0

# ── setup ──────────────────────────────────────────────
func setup(type: int) -> void:
	animal_type  = type
	_sound_timer = randf_range(3.0, 10.0)  # 스폰 직후 동시 울음 방지
	_anim_phase  = randf() * TAU
	_build_mesh()
	_new_dir()

# ── 방향 헬퍼 ──────────────────────────────────────────
func _new_dir() -> void:
	var angle := randf() * TAU
	_dir = Vector3(cos(angle), 0.0, sin(angle)).normalized()

func _dir_to_center() -> void:
	var to_c := Vector3(32.0, 0.0, 32.0) - Vector3(global_position.x, 0.0, global_position.z)
	_dir = to_c.normalized()

# ── 머티리얼 헬퍼 ──────────────────────────────────────
# 기본 유기체 재질: 림 라이팅 + 러프니스 조정
func _new_bio_mat(color: Color, rough: float = 0.78) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = rough
	mat.rim_enabled  = true
	mat.rim          = 0.12
	mat.rim_tint     = 0.4
	_original_mats.append(mat)
	return mat

# 노이즈 법선맵 재질: 깃털/털/비늘 표면 질감
func _new_noise_mat(color: Color, rough: float = 0.82, freq: float = 0.07) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = rough
	mat.rim_enabled  = true
	mat.rim          = 0.10
	mat.rim_tint     = 0.35
	var noise_tex    := NoiseTexture2D.new()
	var fnl          := FastNoiseLite.new()
	fnl.seed          = randi()
	fnl.frequency     = freq
	noise_tex.noise        = fnl
	noise_tex.width        = 128
	noise_tex.height       = 128
	noise_tex.as_normal_map = true
	noise_tex.bump_strength = 2.0
	mat.normal_enabled  = true
	mat.normal_texture  = noise_tex
	_original_mats.append(mat)
	return mat

func _new_mat(color: Color) -> StandardMaterial3D:
	return _new_bio_mat(color)

# ── 메시 헬퍼 함수들 ───────────────────────────────────
func _add_box(pos: Vector3, size: Vector3, color: Color, parent: Node3D = null, textured: bool = false) -> MeshInstance3D:
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _new_noise_mat(color) if textured else _new_bio_mat(color)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	else:
		add_child(mi)
	return mi

func _add_capsule(pos: Vector3, radius: float, height: float, color: Color, parent: Node3D = null, textured: bool = false) -> MeshInstance3D:
	var mi  := MeshInstance3D.new()
	var cm  := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = _new_noise_mat(color) if textured else _new_bio_mat(color)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	else:
		add_child(mi)
	return mi

func _add_sphere(pos: Vector3, radius: float, color: Color, parent: Node3D = null, textured: bool = false) -> MeshInstance3D:
	var mi  := MeshInstance3D.new()
	var sm  := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.material_override = _new_noise_mat(color) if textured else _new_bio_mat(color)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	else:
		add_child(mi)
	return mi

func _add_cylinder(pos: Vector3, radius: float, height: float, color: Color, parent: Node3D = null, textured: bool = false) -> MeshInstance3D:
	var mi  := MeshInstance3D.new()
	var cym := CylinderMesh.new()
	cym.top_radius    = radius
	cym.bottom_radius = radius
	cym.height        = height
	mi.mesh = cym
	mi.material_override = _new_noise_mat(color) if textured else _new_bio_mat(color)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	else:
		add_child(mi)
	return mi

func _make_pivot(pos: Vector3, parent: Node3D = null) -> Node3D:
	var piv := Node3D.new()
	piv.position = pos
	if parent:
		parent.add_child(piv)
	else:
		add_child(piv)
	return piv

func _add_collision(size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)

# ── 애니메이션 ──────────────────────────────────────────
func _animate() -> void:
	var t        : float = Time.get_ticks_msec() * 0.001 + _anim_phase
	var move_spd : float = Vector3(velocity.x, 0.0, velocity.z).length()
	var walk_fac : float = clampf(move_spd / max(_speed, 0.1), 0.0, 1.0)
	var walk_t   : float = t * 4.0 * walk_fac

	# 다리 교대 스윙
	for i in range(_leg_pivots.size()):
		var phase : float = PI if (i % 2 == 1) else 0.0
		_leg_pivots[i].rotation.x = sin(walk_t + phase) * 0.50 * walk_fac

	# 날개/앞팔 애니메이션
	for i in range(_wing_pivots.size()):
		var side : float = -1.0 if i == 0 else 1.0
		if animal_type == BIRD and _floating:
			_wing_pivots[i].rotation.z = sin(t * 6.0) * 0.65 * side
		elif animal_type == CHICKEN:
			_wing_pivots[i].rotation.z = sin(walk_t) * 0.18 * side * walk_fac
		elif animal_type == DINO:
			var dphase : float = PI if i == 1 else 0.0
			_wing_pivots[i].rotation.x = sin(walk_t + dphase) * 0.25 * walk_fac

	# 꼬리 흔들기
	if _tail_pivot:
		match animal_type:
			FISH:  _tail_pivot.rotation.y = sin(t * 4.5) * 0.55
			COW:   _tail_pivot.rotation.y = sin(t * 1.8) * 0.35
			BIRD:  _tail_pivot.rotation.z = sin(t * 3.0) * 0.20
			DINO:  _tail_pivot.rotation.y = sin(t * 1.2) * 0.30
			_:     _tail_pivot.rotation.y = sin(t * 2.5) * 0.30

	# 몸통 상하 bobbing
	if _body_node and not _floating:
		_body_node.position.y = _body_base_y + sin(walk_t * 2.0) * 0.03 * walk_fac

# ── 데미지 & 사망 ──────────────────────────────────────
func take_damage() -> void:
	if _is_dead:
		return
	hp -= 1
	# 공룡: 플레이어가 먼저 공격하면 aggro 활성화
	if animal_type == DINO:
		_aggro = true
	_flash_red()
	if hp <= 0:
		_die()

func _flash_red() -> void:
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1.0, 0.15, 0.15)
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for child in find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = red
	await get_tree().create_timer(0.15).timeout
	if not is_instance_valid(self) or _is_dead:
		return
	var idx := 0
	for child in find_children("*", "MeshInstance3D", true, false):
		if idx < _original_mats.size():
			(child as MeshInstance3D).material_override = _original_mats[idx]
		idx += 1

func _die() -> void:
	_is_dead = true
	_spawn_particles()
	_drop_loot()
	queue_free()

func _drop_loot() -> void:
	var item_script := load("res://scripts/item.gd")
	var loot : Array = []
	match animal_type:
		CHICKEN:
			loot = [{"name": "Feather",      "color": Color(0.95, 0.93, 0.88)},
					{"name": "ChickenMeat",  "color": Color(0.85, 0.45, 0.35)}]
		COW:
			loot = [{"name": "Leather",      "color": Color(0.55, 0.35, 0.18)},
					{"name": "BeefMeat",     "color": Color(0.80, 0.30, 0.25)}]
		FISH:
			loot = [{"name": "RawFish",      "color": Color(1.00, 0.50, 0.10)}]
		BIRD:
			loot = [{"name": "Feather",      "color": Color(0.28, 0.55, 0.90)},
					{"name": "Egg",          "color": Color(0.96, 0.92, 0.78)}]
		DINO:
			loot = [{"name": "DinosaurClaw", "color": Color(0.55, 0.55, 0.20)}]
	var drop_count : int = randi_range(1, 2) if animal_type != DINO else randi_range(2, 4)
	for i in range(drop_count):
		var entry : Dictionary = loot[randi() % loot.size()]
		var item = item_script.new()
		get_parent().add_child(item)
		item.global_position = global_position + Vector3(0, 1.0, 0)
		var col : Color = entry["color"]
		item.call("setup", entry["name"] as String, col)

func _spawn_particles() -> void:
	var p := CPUParticles3D.new()
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 0.5, 0)
	p.emitting             = true
	p.amount               = 24 if animal_type != DINO else 60
	p.lifetime             = 0.9
	p.one_shot             = true
	p.explosiveness        = 1.0
	p.direction            = Vector3(0, 1, 0)
	p.spread               = 180.0
	p.gravity              = Vector3(0, -12.0, 0)
	p.initial_velocity_min = 2.5 if animal_type != DINO else 5.0
	p.initial_velocity_max = 5.0 if animal_type != DINO else 10.0
	p.scale_amount_min     = 0.08
	p.scale_amount_max     = 0.18
	p.color                = Color(0.20, 0.55, 0.10) if animal_type == DINO else Color(1.0, 0.35, 0.1)
	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(p.queue_free)

# ── 닭 ────────────────────────────────────────────────
func _build_chicken() -> void:
	_speed = 1.0

	# 몸통 피벗
	_body_node   = _make_pivot(Vector3(0, 0.38, 0))
	_body_base_y = _body_node.position.y
	_add_capsule(Vector3.ZERO, 0.22, 0.44, Color(0.96, 0.94, 0.90), _body_node, true)

	# 꼬리 피벗
	_tail_pivot = _make_pivot(Vector3(0, 0.38, -0.28))
	_add_box(Vector3(0, 0.08, -0.08), Vector3(0.22, 0.14, 0.16), Color(0.94, 0.92, 0.88), _tail_pivot, true)

	# 목 (몸통→머리 연결)
	var neck_ck := _add_cylinder(Vector3(0, 0.60, 0.09), 0.08, 0.20, Color(0.96, 0.94, 0.90))
	neck_ck.rotation_degrees.x = -26.0

	# 머리
	_add_sphere(Vector3(0, 0.70, 0.18), 0.14, Color(0.96, 0.94, 0.90), null, true)

	# 볏
	_add_box(Vector3(0, 0.88, 0.15), Vector3(0.07, 0.12, 0.08), Color(0.88, 0.10, 0.10))

	# 부리
	_add_box(Vector3(0, 0.70, 0.32), Vector3(0.10, 0.05, 0.10), Color(1.00, 0.75, 0.10))

	# 눈
	_add_sphere(Vector3(-0.14, 0.72, 0.28), 0.035, Color(0.06, 0.05, 0.04))
	_add_sphere(Vector3( 0.14, 0.72, 0.28), 0.035, Color(0.06, 0.05, 0.04))

	# 날개 피벗 (좌, 우)
	for side in [-1.0, 1.0]:
		var wp := _make_pivot(Vector3(side * 0.22, 0.40, 0.0))
		_wing_pivots.append(wp)
		_add_box(Vector3(side * 0.06, 0, 0), Vector3(0.10, 0.18, 0.36), Color(0.90, 0.88, 0.84), wp, true)

	# 다리 피벗 (좌, 우)
	for side in [-1.0, 1.0]:
		var lp := _make_pivot(Vector3(side * 0.10, 0.20, 0.04))
		_leg_pivots.append(lp)
		_add_cylinder(Vector3(0, -0.10, 0),    0.04, 0.18, Color(1.00, 0.60, 0.10), lp)
		_add_cylinder(Vector3(0, -0.24, 0.04), 0.03, 0.14, Color(1.00, 0.55, 0.08), lp)
		_add_box(Vector3(0, -0.32, 0.06), Vector3(0.07, 0.04, 0.12), Color(1.00, 0.52, 0.06), lp)

	_add_collision(Vector3(0.40, 0.82, 0.40))

# ── 소 ────────────────────────────────────────────────
func _build_cow() -> void:
	_speed = 1.3

	# 몸통 피벗
	_body_node   = _make_pivot(Vector3(0, 0.82, 0))
	_body_base_y = _body_node.position.y
	var bmi := _add_capsule(Vector3.ZERO, 0.46, 1.10, Color(0.94, 0.91, 0.86), _body_node, true)
	bmi.rotation_degrees.z = 90.0
	var bmi2 := _add_capsule(Vector3(0, -0.18, 0), 0.32, 0.80, Color(0.98, 0.95, 0.92), _body_node, true)
	bmi2.rotation_degrees.z = 90.0
	# 반점
	_add_box(Vector3( 0.22, 0.10,  0.24), Vector3(0.30, 0.36, 0.42), Color(0.10, 0.09, 0.08), _body_node)
	_add_box(Vector3(-0.20, -0.04, -0.20), Vector3(0.26, 0.30, 0.36), Color(0.10, 0.09, 0.08), _body_node)

	# 목 (몸통→머리 연결)
	var neck_cow := _add_capsule(Vector3(0, 0.83, 0.50), 0.22, 0.32, Color(0.91, 0.87, 0.82), null, true)
	neck_cow.rotation_degrees.x = -10.0

	# 머리 피벗
	var head_piv := _make_pivot(Vector3(0, 0.80, 0.72))
	_add_capsule(Vector3.ZERO, 0.28, 0.52, Color(0.91, 0.87, 0.82), head_piv, true)
	# 귀
	_add_box(Vector3(-0.32, 0.10, -0.06), Vector3(0.14, 0.08, 0.24), Color(0.84, 0.70, 0.65), head_piv)
	_add_box(Vector3( 0.32, 0.10, -0.06), Vector3(0.14, 0.08, 0.24), Color(0.84, 0.70, 0.65), head_piv)
	# 뿔
	_add_cylinder(Vector3(-0.23, 0.26, -0.02), 0.03, 0.22, Color(0.82, 0.78, 0.65), head_piv)
	_add_cylinder(Vector3( 0.23, 0.26, -0.02), 0.03, 0.22, Color(0.82, 0.78, 0.65), head_piv)
	# 눈
	_add_sphere(Vector3(-0.26, 0.04, 0.26), 0.06, Color(0.08, 0.06, 0.05), head_piv)
	_add_sphere(Vector3( 0.26, 0.04, 0.26), 0.06, Color(0.08, 0.06, 0.05), head_piv)
	# 코
	_add_box(Vector3(0, -0.16, 0.33), Vector3(0.34, 0.20, 0.16), Color(0.84, 0.68, 0.65), head_piv)

	# 꼬리 피벗
	_tail_pivot = _make_pivot(Vector3(0, 0.88, -0.64))
	_add_cylinder(Vector3(0, -0.15, 0), 0.04, 0.28, Color(0.91, 0.88, 0.84), _tail_pivot)
	_add_sphere(Vector3(0, -0.32, 0), 0.08, Color(0.16, 0.13, 0.10), _tail_pivot)

	# 다리 4개 피벗
	var leg_positions : Array = [
		Vector3(-0.28, 0.50,  0.36),
		Vector3( 0.28, 0.50,  0.36),
		Vector3(-0.28, 0.50, -0.36),
		Vector3( 0.28, 0.50, -0.36)
	]
	for lpos in leg_positions:
		var lp := _make_pivot(lpos)
		_leg_pivots.append(lp)
		_add_cylinder(Vector3(0, -0.22, 0), 0.09, 0.42, Color(0.89, 0.86, 0.82), lp)
		_add_box(Vector3(0, -0.47, 0), Vector3(0.18, 0.10, 0.18), Color(0.14, 0.11, 0.09), lp)

	_add_collision(Vector3(0.82, 1.10, 1.22))

# ── 물고기 ─────────────────────────────────────────────
func _build_fish() -> void:
	_speed      = 1.8
	_floating   = true
	motion_mode = MOTION_MODE_FLOATING

	# 몸통 (비늘 노이즈 텍스처)
	var bmi := _add_capsule(Vector3(0.04, 0, 0), 0.11, 0.46, Color(1.00, 0.52, 0.12), null, true)
	bmi.rotation_degrees.z = 90.0
	var bmi2 := _add_capsule(Vector3(0.04, -0.04, 0), 0.07, 0.30, Color(1.00, 0.75, 0.40), null, true)
	bmi2.rotation_degrees.z = 90.0

	# 머리
	_add_sphere(Vector3(0.22, 0, 0), 0.11, Color(1.00, 0.48, 0.10), null, true)

	# 입
	_add_box(Vector3(0.30, -0.03, 0), Vector3(0.04, 0.04, 0.10), Color(0.80, 0.25, 0.15))

	# 눈
	_add_sphere(Vector3(0.22, 0.07,  0.07), 0.04, Color(0.06, 0.05, 0.04))
	_add_sphere(Vector3(0.22, 0.07, -0.07), 0.04, Color(0.06, 0.05, 0.04))

	# 등지느러미
	_add_box(Vector3(0.04, 0.14, 0), Vector3(0.18, 0.10, 0.10), Color(1.00, 0.42, 0.08))

	# 가슴지느러미
	_add_box(Vector3(0.13, 0.00,  0.10), Vector3(0.10, 0.05, 0.12), Color(1.00, 0.55, 0.18))
	_add_box(Vector3(0.13, 0.00, -0.10), Vector3(0.10, 0.05, 0.12), Color(1.00, 0.55, 0.18))

	# 몸통-꼬리 연결부
	var fish_bridge := _add_capsule(Vector3(-0.19, 0, 0), 0.08, 0.16, Color(1.00, 0.45, 0.10), null, true)
	fish_bridge.rotation_degrees.z = 90.0

	# 꼬리 피벗
	_tail_pivot = _make_pivot(Vector3(-0.24, 0, 0))
	# 꼬리 기둥
	_add_box(Vector3(0, 0, 0), Vector3(0.06, 0.26, 0.08), Color(1.00, 0.38, 0.06), _tail_pivot)
	# 꼬리 위 갈래
	_add_box(Vector3(-0.09, 0.10, 0), Vector3(0.14, 0.12, 0.06), Color(1.00, 0.35, 0.05), _tail_pivot)
	# 꼬리 아래 갈래
	_add_box(Vector3(-0.09, -0.10, 0), Vector3(0.14, 0.12, 0.06), Color(1.00, 0.35, 0.05), _tail_pivot)

	_add_collision(Vector3(0.60, 0.28, 0.22))

# ── 새 ────────────────────────────────────────────────
func _build_bird() -> void:
	_speed      = 4.0
	_floating   = true
	motion_mode = MOTION_MODE_FLOATING

	# 몸통
	_add_capsule(Vector3(0, 0, 0), 0.13, 0.32, Color(0.20, 0.46, 0.84), null, true)

	# 배
	_add_capsule(Vector3(0, -0.02, 0), 0.09, 0.20, Color(0.88, 0.90, 0.96), null, true)

	# 목 (몸통→머리 연결)
	var neck_bd := _add_cylinder(Vector3(0, 0.12, 0.09), 0.06, 0.14, Color(0.18, 0.42, 0.80))
	neck_bd.rotation_degrees.x = -30.0

	# 머리
	_add_sphere(Vector3(0, 0.18, 0.18), 0.10, Color(0.16, 0.36, 0.72), null, true)

	# 부리
	_add_box(Vector3(0, 0.18, 0.30), Vector3(0.06, 0.04, 0.10), Color(0.92, 0.74, 0.14))

	# 눈
	_add_sphere(Vector3(-0.09, 0.21, 0.24), 0.035, Color(0.06, 0.05, 0.04))
	_add_sphere(Vector3( 0.09, 0.21, 0.24), 0.035, Color(0.06, 0.05, 0.04))

	# 날개 피벗 (좌, 우)
	for i in range(2):
		var side : float = -1.0 if i == 0 else 1.0
		var wp := _make_pivot(Vector3(side * 0.13, 0.02, 0))
		_wing_pivots.append(wp)
		_add_box(Vector3(side * 0.12, 0, 0),    Vector3(0.18, 0.07, 0.26), Color(0.22, 0.50, 0.88), wp, true)
		_add_box(Vector3(side * 0.30, -0.02, 0), Vector3(0.26, 0.05, 0.20), Color(0.30, 0.58, 0.92), wp, true)

	# 꼬리 피벗
	_tail_pivot = _make_pivot(Vector3(0, -0.06, -0.18))
	_add_box(Vector3(0, 0, -0.06), Vector3(0.14, 0.05, 0.14), Color(0.18, 0.40, 0.78), _tail_pivot)
	_add_box(Vector3(-0.08, -0.03, -0.13), Vector3(0.06, 0.04, 0.12), Color(0.20, 0.45, 0.82), _tail_pivot)
	_add_box(Vector3( 0.00, -0.03, -0.14), Vector3(0.06, 0.04, 0.14), Color(0.20, 0.45, 0.82), _tail_pivot)
	_add_box(Vector3( 0.08, -0.03, -0.13), Vector3(0.06, 0.04, 0.12), Color(0.20, 0.45, 0.82), _tail_pivot)

	# 발
	_add_box(Vector3(-0.07, -0.12, 0.04), Vector3(0.05, 0.06, 0.05), Color(0.88, 0.70, 0.14))
	_add_box(Vector3( 0.07, -0.12, 0.04), Vector3(0.05, 0.06, 0.05), Color(0.88, 0.70, 0.14))

	_add_collision(Vector3(0.55, 0.28, 0.38))

# ── 공룡 (T-Rex 스타일) ────────────────────────────────
func _build_dino() -> void:
	_speed = 0.9
	hp     = 10
	add_to_group("dinosaurs")

	# 몸통 피벗
	_body_node   = _make_pivot(Vector3(0, 1.42, 0))
	_body_base_y = _body_node.position.y
	var bmi := _add_capsule(Vector3.ZERO, 0.62, 1.90, Color(0.20, 0.42, 0.12), _body_node, true)
	bmi.rotation_degrees.z = 90.0
	var bmi2 := _add_capsule(Vector3(0, -0.28, 0), 0.44, 1.50, Color(0.54, 0.62, 0.28), _body_node, true)
	bmi2.rotation_degrees.z = 90.0
	# 척추 돌기 6개
	_add_box(Vector3(0, 0.66,  0.58), Vector3(0.16, 0.28, 0.16), Color(0.14, 0.30, 0.07), _body_node)
	_add_box(Vector3(0, 0.66,  0.28), Vector3(0.14, 0.26, 0.14), Color(0.14, 0.30, 0.07), _body_node)
	_add_box(Vector3(0, 0.66,  0.00), Vector3(0.14, 0.24, 0.14), Color(0.14, 0.30, 0.07), _body_node)
	_add_box(Vector3(0, 0.62, -0.28), Vector3(0.12, 0.22, 0.12), Color(0.14, 0.30, 0.07), _body_node)
	_add_box(Vector3(0, 0.58, -0.58), Vector3(0.12, 0.20, 0.12), Color(0.14, 0.30, 0.07), _body_node)
	_add_box(Vector3(0, 0.53, -0.88), Vector3(0.10, 0.18, 0.10), Color(0.14, 0.30, 0.07), _body_node)

	# 몸통-꼬리 브리지 (gap 0.38 채움)
	var tail_bridge := _add_capsule(Vector3(0, 1.32, -0.80), 0.42, 0.60, Color(0.18, 0.38, 0.10), null, true)
	tail_bridge.rotation_degrees.z = 90.0

	# 꼬리 피벗
	_tail_pivot = _make_pivot(Vector3(0, 1.25, -1.0))
	var tail_sizes : Array = [
		[0.40, 0.78],
		[0.28, 0.58],
		[0.18, 0.48],
		[0.10, 0.36]
	]
	var tail_positions : Array = [
		Vector3(0, -0.18, -0.38),
		Vector3(0, -0.38, -0.88),
		Vector3(0, -0.52, -1.30),
		Vector3(0, -0.62, -1.60)
	]
	var tail_colors : Array = [
		Color(0.18, 0.38, 0.10),
		Color(0.16, 0.34, 0.09),
		Color(0.14, 0.30, 0.08),
		Color(0.12, 0.26, 0.07)
	]
	for i in range(4):
		var tmi := _add_capsule(tail_positions[i], tail_sizes[i][0], tail_sizes[i][1], tail_colors[i], _tail_pivot)
		tmi.rotation_degrees.z = 90.0

	# 목
	var neck_mi := _add_capsule(Vector3(0, 2.18, 0.86), 0.28, 0.80, Color(0.22, 0.44, 0.12), null, true)
	neck_mi.rotation_degrees.x = -35.0

	# 머리 피벗
	var head_piv := _make_pivot(Vector3(0, 2.44, 1.80))
	var hmi := _add_capsule(Vector3.ZERO, 0.38, 0.96, Color(0.24, 0.46, 0.14), head_piv, true)
	hmi.rotation_degrees.z = 90.0
	# 눈썹뼈
	_add_box(Vector3(-0.44, 0.36, 0.18), Vector3(0.20, 0.12, 0.30), Color(0.15, 0.32, 0.08), head_piv)
	_add_box(Vector3( 0.44, 0.36, 0.18), Vector3(0.20, 0.12, 0.30), Color(0.15, 0.32, 0.08), head_piv)
	# 눈 (노란) + 동공
	_add_sphere(Vector3(-0.44, 0.16, 0.30), 0.09, Color(0.90, 0.78, 0.10), head_piv)
	_add_sphere(Vector3( 0.44, 0.16, 0.30), 0.09, Color(0.90, 0.78, 0.10), head_piv)
	_add_sphere(Vector3(-0.44, 0.16, 0.38), 0.05, Color(0.05, 0.04, 0.04), head_piv)
	_add_sphere(Vector3( 0.44, 0.16, 0.38), 0.05, Color(0.05, 0.04, 0.04), head_piv)
	# 아래턱
	_add_box(Vector3(0, -0.37, 0.30), Vector3(0.86, 0.36, 0.88), Color(0.19, 0.38, 0.10), head_piv)
	# 이빨 3개
	_add_box(Vector3(-0.28, -0.20, 0.70), Vector3(0.08, 0.20, 0.08), Color(0.92, 0.90, 0.85), head_piv)
	_add_box(Vector3( 0.00, -0.20, 0.74), Vector3(0.07, 0.18, 0.07), Color(0.92, 0.90, 0.85), head_piv)
	_add_box(Vector3( 0.28, -0.20, 0.70), Vector3(0.08, 0.20, 0.08), Color(0.92, 0.90, 0.85), head_piv)

	# 뒷다리 2개 피벗
	var leg_positions : Array = [
		Vector3(-0.58, 1.10, -0.10),
		Vector3( 0.58, 1.10, -0.10)
	]
	for lpos in leg_positions:
		var lp := _make_pivot(lpos)
		_leg_pivots.append(lp)
		# 허벅지
		var thigh := _add_capsule(Vector3(0, -0.12, 0), 0.18, 0.44, Color(0.18, 0.40, 0.11), lp)
		thigh.rotation_degrees.z = 0.0
		# 정강이
		var shin := _add_capsule(Vector3(0, -0.44, 0.12), 0.13, 0.42, Color(0.16, 0.36, 0.09), lp)
		shin.rotation_degrees.x = 10.0
		# 발
		_add_box(Vector3(0, -0.72, 0.22), Vector3(0.44, 0.26, 0.66), Color(0.14, 0.32, 0.08), lp)
		# 발톱
		_add_box(Vector3(-0.12, -0.78, 0.56), Vector3(0.10, 0.12, 0.22), Color(0.55, 0.55, 0.20), lp)
		_add_box(Vector3( 0.12, -0.78, 0.56), Vector3(0.10, 0.12, 0.22), Color(0.55, 0.55, 0.20), lp)

	# 앞팔 2개 피벗
	var arm_positions : Array = [
		Vector3(-0.64, 1.64, 0.72),
		Vector3( 0.64, 1.64, 0.72)
	]
	for apos in arm_positions:
		var ap := _make_pivot(apos)
		_wing_pivots.append(ap)
		# 위팔
		_add_capsule(Vector3(0, -0.10, 0), 0.09, 0.28, Color(0.18, 0.40, 0.11), ap)
		# 아래팔
		_add_capsule(Vector3(0, -0.32, 0.08), 0.07, 0.22, Color(0.16, 0.36, 0.09), ap)
		# 손발톱
		_add_box(Vector3(0, -0.46, 0.12), Vector3(0.18, 0.14, 0.20), Color(0.55, 0.55, 0.20), ap)

	_add_collision(Vector3(1.70, 3.00, 2.40))

# ── 메시 빌드 진입점 ───────────────────────────────────
func _build_mesh() -> void:
	match animal_type:
		CHICKEN: _build_chicken()
		COW:     _build_cow()
		FISH:    _build_fish()
		BIRD:    _build_bird()
		DINO:    _build_dino()

# ── 물리 프로세스 ──────────────────────────────────────
func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(2.5, 6.0)
		_new_dir()

	# 울음소리
	_sound_timer -= delta
	if _sound_timer <= 0.0:
		var interval : float
		match animal_type:
			CHICKEN: interval = randf_range(4.0,  8.0)
			COW:     interval = randf_range(8.0,  15.0)
			FISH:    interval = randf_range(20.0, 35.0)
			DINO:    interval = randf_range(12.0, 20.0)
			_:       interval = randf_range(10.0, 18.0)
		_sound_timer = interval
		if animal_type == CHICKEN or animal_type == COW or animal_type == FISH or animal_type == DINO:
			SoundManager.play_animal(animal_type)

	if _floating:
		_process_floating(delta)
	else:
		_process_ground(delta)

	if _dir.length() > 0.1:
		rotation.y = atan2(_dir.x, _dir.z)

	_animate()

func _process_ground(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	velocity.x = _dir.x * _speed
	velocity.z = _dir.z * _speed
	move_and_slide()
	if is_on_wall():
		if is_on_floor():
			velocity.y = 5.5
		else:
			_new_dir()

func _process_floating(delta: float) -> void:
	var bob    := sin(Time.get_ticks_msec() * 0.002) * 0.25
	var y_diff := _target_y - global_position.y
	velocity.x = _dir.x * _speed
	velocity.z = _dir.z * _speed
	velocity.y = y_diff * 3.0 + bob
	move_and_slide()
	if is_on_wall():
		_new_dir()
	# 새: 맵 경계 안에서만 비행
	if animal_type == BIRD:
		if global_position.y > _target_y + 2.0 or global_position.y < _target_y - 2.0:
			_new_dir()
		if global_position.x < MAP_MIN or global_position.x > MAP_MAX or \
		   global_position.z < MAP_MIN or global_position.z > MAP_MAX:
			_dir_to_center()
