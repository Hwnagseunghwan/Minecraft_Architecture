extends CharacterBody3D

const SPEED      = 5.0
const JUMP_VEL   = 6.5
const GRAVITY    = 20.0
const MOUSE_SENS = 0.003
const BREAK_TIME : float = 1.5

const ITEM_DROP_COLORS : Dictionary = {
	"Feather":      Color(0.95, 0.93, 0.88),
	"ChickenMeat":  Color(0.85, 0.45, 0.35),
	"Leather":      Color(0.55, 0.35, 0.18),
	"BeefMeat":     Color(0.80, 0.30, 0.25),
	"RawFish":      Color(1.00, 0.50, 0.10),
	"Egg":          Color(0.96, 0.92, 0.78),
	"DinosaurClaw": Color(0.55, 0.55, 0.20),
}

const SELECTABLE_BTYPES : Array[int] = [0,1,2,3,4,5,6,7,9,10,11,12]
const BLOCK_NAMES : Array[String] = [
	"Grass","Dirt","Stone","Log","Plank","Glass","White","Red",
	"Brick","Concrete","Wood","Roof"
]

# ── 체력 ───────────────────────────────────────────────
const MAX_HP     : int   = 20     # 하트 10개 × 2 = 20
const DAMAGE_CD  : float = 1.5   # 피격 쿨다운 (초)
const HEAL_DELAY : float = 5.0   # 마지막 피격 후 회복 시작 대기
const HEAL_RATE  : float = 1.0   # 회복 간격 (1초마다 HP +1)

var hp           : int   = MAX_HP
var _dmg_timer   : float = 0.0
var _heal_delay  : float = 0.0
var _heal_timer  : float = 0.0
var _is_dead     : bool  = false

var world        : Node3D = null
var selected_idx : int    = 0
var inventory    : Dictionary = {}

var _breaking    : bool     = false
var _break_timer : float    = 0.0
var _break_pos   : Vector3i = Vector3i(-999, -999, -999)

var _step_timer  : float    = 0.0   # 발걸음 간격 타이머

var _mode          : int    = 0      # 0=건축  1=몽둥이  2=석궁
var _swinging      : bool   = false
var _club_root     : Node3D = null
var _crossbow_root : Node3D = null
var _arrow_cd      : float  = 0.0   # 석궁 쿨다운

const ARROW_CD : float = 0.8

signal block_selected(idx: int, block_name: String)
signal inventory_changed(inv: Dictionary)
signal mode_changed(mode: int)
signal hp_changed(current_hp: int, max_hp: int)
signal hp_healed(current_hp: int, max_hp: int)
signal player_died()
signal player_respawned()

@onready var head     : Node3D    = $Head
@onready var camera   : Camera3D  = $Head/Camera3D
@onready var ray_cast : RayCast3D = $Head/Camera3D/RayCast3D
var attack_ray : RayCast3D = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# 초기 HP 상태 UI에 전달 (1프레임 뒤에 시그널 연결 완료 후 emit)
	call_deferred("_emit_initial_hp")
	attack_ray = RayCast3D.new()
	attack_ray.name = "AttackRay"
	attack_ray.target_position = Vector3(0, 0, -9)
	attack_ray.collision_mask = 1
	attack_ray.enabled = true
	camera.add_child(attack_ray)
	_build_club()
	_build_crossbow()

func _build_club() -> void:
	_club_root = Node3D.new()
	_club_root.position         = Vector3(0.38, -0.28, -0.52)
	_club_root.rotation_degrees = Vector3(10.0, -12.0, -18.0)
	_club_root.visible          = false
	camera.add_child(_club_root)

	var handle := MeshInstance3D.new()
	var hm     := BoxMesh.new()
	hm.size = Vector3(0.06, 0.06, 0.36)
	handle.mesh = hm
	var mat_h := StandardMaterial3D.new()
	mat_h.albedo_color = Color(0.52, 0.32, 0.10)
	mat_h.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	handle.material_override = mat_h
	_club_root.add_child(handle)

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

func _build_crossbow() -> void:
	_crossbow_root = Node3D.new()
	_crossbow_root.position         = Vector3(0.32, -0.22, -0.55)
	_crossbow_root.rotation_degrees = Vector3(0.0, -10.0, -5.0)
	_crossbow_root.visible          = false
	camera.add_child(_crossbow_root)

	# 스톡 (손잡이)
	var stock := MeshInstance3D.new()
	var sm    := BoxMesh.new()
	sm.size   = Vector3(0.06, 0.06, 0.42)
	stock.mesh = sm
	var mat1  := StandardMaterial3D.new()
	mat1.albedo_color = Color(0.42, 0.26, 0.10)
	mat1.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stock.material_override = mat1
	_crossbow_root.add_child(stock)

	# 활 팔 (가로 막대)
	var arm  := MeshInstance3D.new()
	var am   := BoxMesh.new()
	am.size  = Vector3(0.38, 0.05, 0.04)
	arm.mesh = am
	var mat2 := StandardMaterial3D.new()
	mat2.albedo_color = Color(0.28, 0.18, 0.07)
	mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arm.material_override = mat2
	arm.position = Vector3(0.0, 0.04, -0.14)
	_crossbow_root.add_child(arm)

func _emit_initial_hp() -> void:
	hp_changed.emit(hp, MAX_HP)

func _get_btype() -> int:
	return SELECTABLE_BTYPES[selected_idx]

func _toggle_mode() -> void:
	_mode = (_mode + 1) % 3
	_club_root.visible     = (_mode == 1)
	_crossbow_root.visible = (_mode == 2)
	if _mode == 0:
		_breaking    = false
		_break_timer = 0.0
		_break_pos   = Vector3i(-999, -999, -999)
		if world:
			world.set_crack(Vector3i.ZERO, 0.0)
	mode_changed.emit(_mode)

# ── 체력 시스템 ────────────────────────────────────────
func _take_damage(amount: int) -> void:
	if _is_dead:
		return
	hp = maxi(hp - amount, 0)
	_heal_delay = HEAL_DELAY
	_heal_timer = HEAL_RATE
	SoundManager.play_hurt()
	hp_changed.emit(hp, MAX_HP)
	if hp <= 0:
		_die()

func _die() -> void:
	_is_dead = true
	velocity  = Vector3.ZERO
	SoundManager.play_die()
	_drop_inventory()
	player_died.emit()
	get_tree().create_timer(3.0).timeout.connect(_respawn)

func _drop_inventory() -> void:
	if inventory.is_empty():
		return
	var item_script := load("res://scripts/item.gd")
	for iname in inventory:
		var count : int   = inventory[iname]
		var col   : Color = ITEM_DROP_COLORS.get(iname, Color(0.7, 0.7, 0.7))
		for _i in range(mini(count, 6)):  # 한 종류당 최대 6개
			var item = item_script.new()
			get_parent().add_child(item)
			var offset := Vector3(randf_range(-1.5, 1.5), 0.5, randf_range(-1.5, 1.5))
			item.global_position = global_position + offset
			item.call("setup", iname, col, 60.0)  # 1분 후 사라짐
	inventory.clear()
	inventory_changed.emit(inventory)

func _respawn() -> void:
	hp           = MAX_HP
	_is_dead     = false
	_dmg_timer   = 0.0
	_heal_delay  = 0.0
	_heal_timer  = 0.0
	global_position = Vector3(32.0, 5.0, 32.0)
	velocity     = Vector3.ZERO
	hp_changed.emit(hp, MAX_HP)
	player_respawned.emit()

func _check_dino_damage(delta: float) -> void:
	_dmg_timer -= delta
	if _dmg_timer > 0.0:
		return
	var dinos := get_tree().get_nodes_in_group("dinosaurs")
	for dino in dinos:
		if not is_instance_valid(dino):
			continue
		# 플레이어가 먼저 공격(aggro)한 공룡만 반격
		if not bool(dino.get("_aggro")):
			continue
		var dist : float = global_position.distance_to(dino.global_position)
		if dist < 3.5:
			_take_damage(5)  # 2.5 하트 (HP 2 = 하트 1개)
			_dmg_timer = DAMAGE_CD
			return

func _update_heal(delta: float) -> void:
	if _is_dead or hp >= MAX_HP:
		return
	if _heal_delay > 0.0:
		_heal_delay -= delta
		return
	_heal_timer -= delta
	if _heal_timer <= 0.0:
		hp = mini(hp + 1, MAX_HP)
		_heal_timer = HEAL_RATE
		hp_changed.emit(hp, MAX_HP)
		hp_healed.emit(hp, MAX_HP)

func _input(event: InputEvent) -> void:
	if _is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotate_x(-event.relative.y * MOUSE_SENS)
		head.rotation.x = clamp(head.rotation.x, -PI / 2.0, PI / 2.0)

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

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if _mode == 1:
					if event.pressed:
						_swing_attack()
				elif _mode == 0:
					if event.pressed:
						_breaking = true
					else:
						_breaking = false
						_break_timer = 0.0
						_break_pos = Vector3i(-999, -999, -999)
						if world:
							world.set_crack(Vector3i.ZERO, 0.0)
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					if _mode == 0:
						_place_block()
					elif _mode == 2:
						_shoot_arrow()
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
	SoundManager.play_swing()
	if attack_ray.is_colliding():
		var collider := attack_ray.get_collider()
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage()
	var tw := create_tween()
	tw.tween_property(_club_root, "rotation_degrees",
		Vector3(-50.0, -12.0, -18.0), 0.10)
	tw.tween_property(_club_root, "rotation_degrees",
		Vector3(10.0,  -12.0, -18.0), 0.15)
	tw.tween_callback(func(): _swinging = false)

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

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
	if _mode == 0:
		_update_breaking(delta)
	_collect_nearby_items()
	_check_dino_damage(delta)
	_update_heal(delta)
	_update_footstep(delta)
	if _arrow_cd > 0.0:
		_arrow_cd -= delta

func _shoot_arrow() -> void:
	if _arrow_cd > 0.0:
		return
	_arrow_cd = ARROW_CD
	var arrow_script := load("res://scripts/arrow.gd")
	var arrow        = arrow_script.new()
	get_parent().add_child(arrow)
	var dir  : Vector3 = -camera.global_transform.basis.z.normalized()
	var from : Vector3 = camera.global_position + dir * 0.8
	arrow.call("setup", from, dir)
	SoundManager.play_shoot()

func _update_footstep(delta: float) -> void:
	_step_timer -= delta
	var moving : bool = absf(velocity.x) > 0.5 or absf(velocity.z) > 0.5
	if moving and is_on_floor():
		if _step_timer <= 0.0:
			SoundManager.play_step()
			_step_timer = 0.40
	else:
		_step_timer = 0.0

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
		SoundManager.play_dig()
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
				SoundManager.play_pickup()
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
	if world.place_block(pp, _get_btype()):
		SoundManager.play_place()
