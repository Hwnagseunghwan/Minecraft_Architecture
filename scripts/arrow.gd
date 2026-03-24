extends RigidBody3D

const SPEED    : float = 45.0
const LIFETIME : float = 6.0

var _can_hit : bool = false

func setup(from: Vector3, dir: Vector3) -> void:
	global_position       = from
	gravity_scale         = 0.30
	contact_monitor       = true
	max_contacts_reported = 4
	linear_velocity       = dir * SPEED
	_build_mesh()
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(0.20).timeout.connect(_activate)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)

func _activate() -> void:
	_can_hit = true

func _on_body_entered(body: Node) -> void:
	if not _can_hit:
		return
	if body.has_method("take_damage"):
		body.take_damage()
	queue_free()

func _physics_process(_delta: float) -> void:
	if linear_velocity.length_squared() > 1.0:
		var fwd : Vector3 = linear_velocity.normalized()
		if fwd.cross(Vector3.UP).length_squared() > 0.01:
			look_at(global_position + fwd, Vector3.UP)

func _build_mesh() -> void:
	# 화살대
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = Vector3(0.04, 0.04, 0.50)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.35, 0.10)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)

	# 화살촉
	var tip  := MeshInstance3D.new()
	var tm   := BoxMesh.new()
	tm.size  = Vector3(0.06, 0.06, 0.10)
	tip.mesh = tm
	var mat2 := StandardMaterial3D.new()
	mat2.albedo_color = Color(0.60, 0.60, 0.65)
	mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tip.material_override = mat2
	tip.position = Vector3(0.0, 0.0, -0.30)
	add_child(tip)

	# 충돌 구체
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.08
	cs.shape  = sh
	add_child(cs)
