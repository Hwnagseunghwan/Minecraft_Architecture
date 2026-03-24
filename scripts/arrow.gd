extends CharacterBody3D
## 석궁 화살 - CharacterBody3D 방식 (물리 충격량 없음)

const GRAVITY  : float = 9.0
const SPEED    : float = 45.0
const LIFETIME : float = 6.0

var _vel    : Vector3 = Vector3.ZERO
var _active : bool    = false

func setup(from: Vector3, dir: Vector3) -> void:
	global_position = from
	_vel = dir * SPEED
	_build_mesh()
	get_tree().create_timer(0.15).timeout.connect(func(): _active = true)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	_vel.y -= GRAVITY * delta
	var col : KinematicCollision3D = move_and_collide(_vel * delta)
	if col != null:
		if _active:
			var body : Object = col.get_collider()
			if body != null and body.has_method("take_damage"):
				body.take_damage()
		queue_free()
		return
	# 날아가는 방향으로 화살 회전
	if _vel.length_squared() > 1.0:
		var fwd : Vector3 = _vel.normalized()
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

	# 충돌 구체 (새 맞추기 쉽도록 넉넉하게)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.35
	cs.shape  = sh
	add_child(cs)
