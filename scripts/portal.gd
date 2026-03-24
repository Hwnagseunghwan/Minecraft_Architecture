extends Area3D
## 포탈 - 플레이어가 들어가면 지정 좌표로 텔레포트

var _dest       : Vector3              = Vector3.ZERO
var _use_return : bool                 = false  # true: 플레이어 귀환 좌표로 이동
var _cooldown   : float                = 1.5
var _inner_mat  : StandardMaterial3D   = null

func setup(dest: Vector3, use_return: bool = false) -> void:
	_dest       = dest
	_use_return = use_return
	collision_layer = 0
	collision_mask  = 1
	monitoring      = true
	add_to_group("portals")
	_build_visual()
	_build_collision()
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if _inner_mat != null:
		var t     : float = Time.get_ticks_msec() * 0.003
		var alpha : float = 0.35 + sin(t) * 0.14
		_inner_mat.albedo_color = Color(0.58, 0.08, 0.92, alpha)

func _build_visual() -> void:
	# 내부 (반투명 보라, 깜박임)
	var inner  := MeshInstance3D.new()
	var qm     := QuadMesh.new()
	qm.size    = Vector2(1.10, 1.90)
	inner.mesh = qm
	_inner_mat = StandardMaterial3D.new()
	_inner_mat.albedo_color      = Color(0.58, 0.08, 0.92, 0.45)
	_inner_mat.flags_transparent = true
	_inner_mat.shading_mode      = BaseMaterial3D.SHADING_MODE_UNSHADED
	_inner_mat.cull_mode         = BaseMaterial3D.CULL_DISABLED
	inner.material_override      = _inner_mat
	add_child(inner)

	# 테두리 프레임
	var fc : Color = Color(0.78, 0.28, 1.00)
	_add_bar(Vector3(0,   1.00, 0), Vector3(1.30, 0.10, 0.12), fc)  # 상단
	_add_bar(Vector3(0,  -1.00, 0), Vector3(1.30, 0.10, 0.12), fc)  # 하단
	_add_bar(Vector3(-0.65, 0,  0), Vector3(0.12, 2.10, 0.12), fc)  # 좌
	_add_bar(Vector3( 0.65, 0,  0), Vector3(0.12, 2.10, 0.12), fc)  # 우

	# 보라 빛
	var light := OmniLight3D.new()
	light.light_color  = Color(0.72, 0.22, 1.00)
	light.light_energy = 2.0
	light.omni_range   = 6.0
	add_child(light)

func _add_bar(pos: Vector3, size: Vector3, color: Color) -> void:
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

func _build_collision() -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.10, 1.90, 0.60)
	cs.shape = sh
	add_child(cs)

func _on_body_entered(body: Node3D) -> void:
	if _cooldown > 0.0:
		return
	if body.has_method("_enter_portal"):
		_cooldown = 2.0
		body._enter_portal(_dest, _use_return)
