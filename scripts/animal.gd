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
var _aggro         : bool  = false   # 공룡 전용: 플레이어 먼저 공격 시 true

var _sound_timer   : float = 0.0    # 울음 간격 타이머

func setup(type: int) -> void:
	animal_type  = type
	_sound_timer = randf_range(3.0, 10.0)  # 스폰 직후 동시 울음 방지
	_build_mesh()
	_new_dir()

func _new_dir() -> void:
	var angle := randf() * TAU
	_dir = Vector3(cos(angle), 0.0, sin(angle)).normalized()

func _dir_to_center() -> void:
	var to_c := Vector3(32.0, 0.0, 32.0) - Vector3(global_position.x, 0.0, global_position.z)
	_dir = to_c.normalized()

func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = pos
	_original_mats.append(mat)
	add_child(mi)

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
	for child in get_children():
		if child is MeshInstance3D:
			child.material_override = red
	await get_tree().create_timer(0.15).timeout
	if not is_instance_valid(self) or _is_dead:
		return
	var idx := 0
	for child in get_children():
		if child is MeshInstance3D:
			if idx < _original_mats.size():
				child.material_override = _original_mats[idx]
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

func _add_collision(size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)

# ── 닭 ────────────────────────────────────────────────
func _build_chicken() -> void:
	_speed = 1.0
	_add_box(Vector3(0,     0.35,  0.00), Vector3(0.40, 0.38, 0.50), Color(0.95, 0.93, 0.88)) # 몸
	_add_box(Vector3(0,     0.68,  0.14), Vector3(0.30, 0.28, 0.28), Color(0.95, 0.93, 0.88)) # 머리
	_add_box(Vector3(0,     0.64,  0.30), Vector3(0.10, 0.08, 0.12), Color(1.00, 0.70, 0.05)) # 부리
	_add_box(Vector3(0,     0.82,  0.14), Vector3(0.08, 0.12, 0.08), Color(0.90, 0.15, 0.15)) # 볏
	_add_box(Vector3(-0.10, 0.08,  0.00), Vector3(0.07, 0.22, 0.07), Color(1.00, 0.60, 0.05)) # 왼다리
	_add_box(Vector3( 0.10, 0.08,  0.00), Vector3(0.07, 0.22, 0.07), Color(1.00, 0.60, 0.05)) # 오른다리
	_add_collision(Vector3(0.40, 0.80, 0.40))

# ── 소 ────────────────────────────────────────────────
func _build_cow() -> void:
	_speed = 1.3
	_add_box(Vector3( 0.00, 0.60,  0.00), Vector3(0.85, 0.72, 1.30), Color(0.94, 0.91, 0.86)) # 몸
	_add_box(Vector3( 0.22, 0.75,  0.25), Vector3(0.32, 0.38, 0.45), Color(0.12, 0.10, 0.09)) # 반점1
	_add_box(Vector3(-0.20, 0.65, -0.20), Vector3(0.28, 0.32, 0.38), Color(0.12, 0.10, 0.09)) # 반점2
	_add_box(Vector3( 0.00, 0.68,  0.80), Vector3(0.55, 0.52, 0.55), Color(0.91, 0.87, 0.82)) # 머리
	_add_box(Vector3( 0.00, 0.56,  1.06), Vector3(0.36, 0.22, 0.15), Color(0.84, 0.68, 0.66)) # 코
	_add_box(Vector3(-0.20, 0.97,  0.75), Vector3(0.07, 0.18, 0.07), Color(0.84, 0.80, 0.68)) # 뿔L
	_add_box(Vector3( 0.20, 0.97,  0.75), Vector3(0.07, 0.18, 0.07), Color(0.84, 0.80, 0.68)) # 뿔R
	_add_box(Vector3(-0.28, 0.14,  0.40), Vector3(0.19, 0.46, 0.19), Color(0.89, 0.86, 0.82)) # 다리FL
	_add_box(Vector3( 0.28, 0.14,  0.40), Vector3(0.19, 0.46, 0.19), Color(0.89, 0.86, 0.82)) # 다리FR
	_add_box(Vector3(-0.28, 0.14, -0.40), Vector3(0.19, 0.46, 0.19), Color(0.89, 0.86, 0.82)) # 다리BL
	_add_box(Vector3( 0.28, 0.14, -0.40), Vector3(0.19, 0.46, 0.19), Color(0.89, 0.86, 0.82)) # 다리BR
	_add_collision(Vector3(0.85, 1.10, 1.30))

# ── 물고기 ─────────────────────────────────────────────
func _build_fish() -> void:
	_speed      = 1.8
	_floating   = true
	motion_mode = MOTION_MODE_FLOATING
	_add_box(Vector3( 0.05, 0.00,  0.00), Vector3(0.48, 0.24, 0.18), Color(1.00, 0.50, 0.10)) # 몸
	_add_box(Vector3(-0.28, 0.00,  0.00), Vector3(0.18, 0.30, 0.08), Color(1.00, 0.35, 0.05)) # 꼬리
	_add_box(Vector3( 0.05, 0.14,  0.00), Vector3(0.22, 0.08, 0.14), Color(1.00, 0.42, 0.08)) # 등지느러미
	_add_box(Vector3( 0.22, 0.06,  0.09), Vector3(0.05, 0.05, 0.05), Color(0.05, 0.05, 0.05)) # 눈L
	_add_box(Vector3( 0.22, 0.06, -0.09), Vector3(0.05, 0.05, 0.05), Color(0.05, 0.05, 0.05)) # 눈R
	_add_collision(Vector3(0.60, 0.30, 0.22))

# ── 새 ────────────────────────────────────────────────
func _build_bird() -> void:
	_speed      = 4.0
	_floating   = true
	motion_mode = MOTION_MODE_FLOATING
	_add_box(Vector3( 0.00,  0.00,  0.00), Vector3(0.28, 0.22, 0.36), Color(0.20, 0.45, 0.82)) # 몸
	_add_box(Vector3( 0.00,  0.18,  0.20), Vector3(0.20, 0.20, 0.20), Color(0.16, 0.36, 0.72)) # 머리
	_add_box(Vector3( 0.00,  0.16,  0.33), Vector3(0.06, 0.06, 0.12), Color(0.92, 0.72, 0.12)) # 부리
	_add_box(Vector3(-0.38,  0.02,  0.00), Vector3(0.52, 0.06, 0.24), Color(0.28, 0.55, 0.90)) # 날개L
	_add_box(Vector3( 0.38,  0.02,  0.00), Vector3(0.52, 0.06, 0.24), Color(0.28, 0.55, 0.90)) # 날개R
	_add_box(Vector3( 0.00, -0.08, -0.22), Vector3(0.16, 0.06, 0.18), Color(0.20, 0.45, 0.82)) # 꼬리
	_add_collision(Vector3(0.55, 0.28, 0.38))

# ── 공룡 (T-Rex 스타일) ────────────────────────────────
func _build_dino() -> void:
	_speed = 0.9
	hp     = 10
	add_to_group("dinosaurs")
	# 몸통
	_add_box(Vector3( 0.00, 1.40,  0.00), Vector3(1.70, 1.20, 2.40), Color(0.20, 0.42, 0.12)) # 몸
	# 꼬리
	_add_box(Vector3( 0.00, 1.20, -1.50), Vector3(0.90, 0.80, 1.10), Color(0.18, 0.38, 0.10)) # 꼬리
	_add_box(Vector3( 0.00, 0.95, -2.30), Vector3(0.50, 0.50, 0.80), Color(0.16, 0.34, 0.09)) # 꼬리 끝
	# 목
	_add_box(Vector3( 0.00, 2.10,  0.90), Vector3(0.70, 0.85, 0.60), Color(0.22, 0.44, 0.12)) # 목
	# 머리
	_add_box(Vector3( 0.00, 2.35,  1.80), Vector3(1.00, 0.80, 1.10), Color(0.24, 0.46, 0.14)) # 머리
	_add_box(Vector3( 0.00, 2.00,  2.10), Vector3(0.88, 0.38, 0.90), Color(0.19, 0.38, 0.10)) # 아래턱
	# 이빨
	_add_box(Vector3(-0.25, 2.16,  2.50), Vector3(0.08, 0.18, 0.08), Color(0.92, 0.90, 0.85)) # 이빨L
	_add_box(Vector3( 0.25, 2.16,  2.50), Vector3(0.08, 0.18, 0.08), Color(0.92, 0.90, 0.85)) # 이빨R
	# 눈
	_add_box(Vector3(-0.42, 2.60,  2.10), Vector3(0.14, 0.14, 0.14), Color(0.90, 0.10, 0.05)) # 눈L
	_add_box(Vector3( 0.42, 2.60,  2.10), Vector3(0.14, 0.14, 0.14), Color(0.90, 0.10, 0.05)) # 눈R
	# 뒷다리 (굵고 길게)
	_add_box(Vector3(-0.55, 0.62, -0.20), Vector3(0.45, 1.40, 0.45), Color(0.18, 0.40, 0.11)) # 뒷다리L
	_add_box(Vector3( 0.55, 0.62, -0.20), Vector3(0.45, 1.40, 0.45), Color(0.18, 0.40, 0.11)) # 뒷다리R
	# 발
	_add_box(Vector3(-0.55, 0.16,  0.15), Vector3(0.45, 0.32, 0.70), Color(0.16, 0.36, 0.09)) # 발L
	_add_box(Vector3( 0.55, 0.16,  0.15), Vector3(0.45, 0.32, 0.70), Color(0.16, 0.36, 0.09)) # 발R
	# 발톱
	_add_box(Vector3(-0.55, 0.08,  0.52), Vector3(0.12, 0.12, 0.22), Color(0.55, 0.55, 0.20)) # 발톱L
	_add_box(Vector3( 0.55, 0.08,  0.52), Vector3(0.12, 0.12, 0.22), Color(0.55, 0.55, 0.20)) # 발톱R
	# 앞팔 (T-Rex: 짧고 작게)
	_add_box(Vector3(-0.62, 1.50,  0.80), Vector3(0.22, 0.45, 0.22), Color(0.18, 0.40, 0.11)) # 앞팔L
	_add_box(Vector3( 0.62, 1.50,  0.80), Vector3(0.22, 0.45, 0.22), Color(0.18, 0.40, 0.11)) # 앞팔R
	_add_collision(Vector3(1.70, 3.00, 2.40))

func _build_mesh() -> void:
	match animal_type:
		CHICKEN: _build_chicken()
		COW:     _build_cow()
		FISH:    _build_fish()
		BIRD:    _build_bird()
		DINO:    _build_dino()

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(2.5, 6.0)
		_new_dir()

	# 울음소리 (닭/소/공룡만, 물고기/새는 조용히)
	_sound_timer -= delta
	if _sound_timer <= 0.0:
		var interval := 8.0 if animal_type == DINO else randf_range(5.0, 12.0)
		_sound_timer = interval
		if animal_type == CHICKEN or animal_type == COW or animal_type == DINO:
			SoundManager.play_animal(animal_type)

	if _floating:
		_process_floating(delta)
	else:
		_process_ground(delta)

	if _dir.length() > 0.1:
		rotation.y = atan2(_dir.x, _dir.z)

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
