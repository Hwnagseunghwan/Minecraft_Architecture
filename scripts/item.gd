extends RigidBody3D

var item_name : String = ""

func setup(name: String, color: Color) -> void:
	item_name = name
	collision_layer = 2
	collision_mask  = 1
	add_to_group("items")

	# 메시
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = Vector3(0.28, 0.28, 0.28)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)

	# 충돌체
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.28, 0.28, 0.28)
	cs.shape = sh
	add_child(cs)

	# 튀어오르는 초기 속도 + 회전
	linear_velocity  = Vector3(randf_range(-1.5, 1.5), randf_range(2.0, 4.0), randf_range(-1.5, 1.5))
	angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))

	# 30초 후 자동 삭제
	get_tree().create_timer(30.0).timeout.connect(queue_free)
