extends CharacterBody3D

const SPEED      = 5.0
const JUMP_VEL   = 6.5
const GRAVITY    = 20.0
const MOUSE_SENS = 0.003
const BREAK_TIME : float = 1.5

const SELECTABLE_BTYPES : Array[int] = [0,1,2,3,4,5,6,7,9,10,11,12]
const BLOCK_NAMES : Array[String] = [
	"Grass","Dirt","Stone","Log","Plank","Glass","White","Red",
	"Brick","Concrete","Wood","Roof"
]

var world        : Node3D = null
var selected_idx : int    = 0
var inventory    : Dictionary = {}

var _breaking    : bool     = false
var _break_timer : float    = 0.0
var _break_pos   : Vector3i = Vector3i(-999, -999, -999)

var _combat_mode : bool    = false
var _swinging    : bool    = false
var _club_root   : Node3D  = null

signal block_selected(idx: int, block_name: String)
signal inventory_changed(inv: Dictionary)
signal mode_changed(is_combat: bool)

@onready var head     : Node3D    = $Head
@onready var camera   : Camera3D  = $Head/Camera3D
@onready var ray_cast : RayCast3D = $Head/Camera3D/RayCast3D
var attack_ray : RayCast3D = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# 동물 공격용 레이캐스트 (3블록 범위)
	attack_ray = RayCast3D.new()
	attack_ray.name = "AttackRay"
	attack_ray.target_position = Vector3(0, 0, -9)
	attack_ray.collision_mask = 1
	attack_ray.enabled = true
	camera.add_child(attack_ray)
	# 몽둥이 생성
	_build_club()

func _build_club() -> void:
	_club_root = Node3D.new()
	_club_root.position        = Vector3(0.38, -0.28, -0.52)
	_club_root.rotation_degrees = Vector3(10.0, -12.0, -18.0)
	_club_root.visible         = false
	camera.add_child(_club_root)

	# 손잡이 (얇은 막대)
	var handle := MeshInstance3D.new()
	var hm     := BoxMesh.new()
	hm.size = Vector3(0.06, 0.06, 0.36)
	handle.mesh = hm
	var mat_h := StandardMaterial3D.new()
	mat_h.albedo_color  = Color(0.52, 0.32, 0.10)
	mat_h.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	handle.material_override = mat_h
	handle.position = Vector3(0.0, 0.0, 0.0)
	_club_root.add_child(handle)

	# 머리 (굵은 블록)
	var head_mesh := MeshInstance3D.new()
	var bm        := BoxMesh.new()
	bm.size = Vector3(0.13, 0.13, 0.20)
	head_mesh.mesh = bm
	var mat_b := StandardMaterial3D.new()
	mat_b.albedo_color = Color(0.34, 0.18, 0.05)
	mat_b.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head_mesh.material_override = mat_b
	head_mesh.position = Vector3(0.0, 0.0, -0.26)
	_club_root.add_child(head_mesh)

func _get_btype() -> int:
	return SELECTABLE_BTYPES[selected_idx]

func _toggle_mode() -> void:
	_combat_mode = not _combat_mode
	_club_root.visible = _combat_mode
	# 건축 모드로 돌아오면 파괴 상태 초기화
	if not _combat_mode:
		_breaking    = false
		_break_timer = 0.0
		_break_pos   = Vector3i(-999, -999, -999)
		if world:
			world.set_crack(Vector3i.ZERO, 0.0)
	mode_changed.emit(_combat_mode)

func _input(event: InputEvent) -> void:
	# 마우스 시점
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotate_x(-event.relative.y * MOUSE_SENS)
		head.rotation.x = clamp(head.rotation.x, -PI / 2.0, PI / 2.0)

	# 키보드
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _select(0)
			KEY_2: _select(1)
			KEY_3: _select(2)
			KEY_4: _select(3)
			KEY_5: _select(4)
			KEY_6: _select(5)
			KEY_7: _select(6)
			KEY_8: _select(7)
			KEY_F: _toggle_mode()
			KEY_SPACE:
				if is_on_floor():
					velocity.y = JUMP_VEL
			KEY_R:
				if world:
					world.reset_world()
			KEY_ESCAPE:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				else:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# 마우스 클릭
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if _combat_mode:
					# 전투 모드: 좌클릭 = 공격 + 스윙 모션
					if event.pressed:
						_swing_attack()
				else:
					# 건축 모드: 좌클릭 꾹 = 블록 파괴
					if event.pressed:
						_breaking = true
					else:
						_breaking = false
						_break_timer = 0.0
						_break_pos = Vector3i(-999, -999, -999)
						if world:
							world.set_crack(Vector3i.ZERO, 0.0)
			MOUSE_BUTTON_RIGHT:
				if event.pressed and not _combat_mode:
					_place_block()
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_select((selected_idx - 1 + SELECTABLE_BTYPES.size()) % SELECTABLE_BTYPES.size())
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_select((selected_idx + 1) % SELECTABLE_BTYPES.size())

func _select(idx: int) -> void:
	selected_idx = idx
	block_selected.emit(idx, BLOCK_NAMES[idx])

func _swing_attack() -> void:
	if _swinging:
		return
	_swinging = true
	# 판정 먼저
	if attack_ray.is_colliding():
		var collider := attack_ray.get_collider()
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage()
	# 스윙 애니메이션 (Tween)
	var tw := create_tween()
	tw.tween_property(_club_root, "rotation_degrees",
		Vector3(-50.0, -12.0, -18.0), 0.10)
	tw.tween_property(_club_root, "rotation_degrees",
		Vector3(10.0,  -12.0, -18.0), 0.15)
	tw.tween_callback(func(): _swinging = false)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): dir.y -= 1
	if Input.is_key_pressed(KEY_S): dir.y += 1
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1

	var move := (transform.basis * Vector3(dir.x, 0, dir.y)).normalized()
	if move.length() > 0:
		velocity.x = move.x * SPEED
		velocity.z = move.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	_update_highlight()
	if not _combat_mode:
		_update_breaking(delta)
	_collect_nearby_items()

# ── 레이캐스트 ─────────────────────────────────────────
func _get_target() -> Dictionary:
	if not ray_cast.is_colliding():
		return {}
	var hit    := ray_cast.get_collision_point()
	var normal := ray_cast.get_collision_normal()
	var bp := Vector3i(
		int(floor(hit.x - normal.x * 0.5)),
		int(floor(hit.y - normal.y * 0.5)),
		int(floor(hit.z - normal.z * 0.5))
	)
	var pp := bp + Vector3i(int(round(normal.x)), int(round(normal.y)), int(round(normal.z)))
	return {"block": bp, "place": pp}

func _update_highlight() -> void:
	if not world: return
	var t := _get_target()
	world.set_highlight(t.get("block", Vector3i.ZERO), not t.is_empty())

func _update_breaking(delta: float) -> void:
	if not _breaking or not world:
		return
	var t := _get_target()
	if t.is_empty():
		_break_timer = 0.0
		_break_pos = Vector3i(-999, -999, -999)
		world.set_crack(Vector3i.ZERO, 0.0)
		return
	var bp : Vector3i = t["block"]
	if bp != _break_pos:
		_break_pos = bp
		_break_timer = 0.0
	_break_timer += delta
	world.set_crack(_break_pos, _break_timer / BREAK_TIME)
	if _break_timer >= BREAK_TIME:
		_breaking    = false
		_break_timer = 0.0
		world.set_crack(Vector3i.ZERO, 0.0)
		world.remove_block(_break_pos)

func _collect_nearby_items() -> void:
	var items := get_tree().get_nodes_in_group("items")
	for item in items:
		if not is_instance_valid(item):
			continue
		var dist : float = global_position.distance_to(item.global_position)
		if dist < 1.8:
			var raw = item.get("item_name")
			var iname : String = str(raw) if raw != null else ""
			if iname != "" and iname != "Null":
				inventory[iname] = inventory.get(iname, 0) + 1
				inventory_changed.emit(inventory)
			item.queue_free()

func _place_block() -> void:
	if not world: return
	var t := _get_target()
	if t.is_empty(): return
	var pp : Vector3i = t["place"]
	var px  := int(floor(global_position.x))
	var pz  := int(floor(global_position.z))
	var py0 := int(floor(global_position.y))
	var py1 := py0 + 1
	if pp.x == px and pp.z == pz and (pp.y == py0 or pp.y == py1):
		return
	world.place_block(pp, _get_btype())
