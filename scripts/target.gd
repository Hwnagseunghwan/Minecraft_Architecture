extends StaticBody3D
## 석궁 연습장 표적

var _hit_count : int = 0
var _mat_ring  : StandardMaterial3D
var _mat_bull  : StandardMaterial3D

const COLOR_RING  : Color = Color(0.95, 0.95, 0.95)
const COLOR_BULL  : Color = Color(0.85, 0.10, 0.10)
const COLOR_HIT   : Color = Color(1.00, 0.90, 0.10)

func build(pole_height: int) -> void:
	_build_pole(pole_height)
	_build_board()
	_build_collision()

func _build_pole(h: int) -> void:
	for i in range(h):
		var mi  := MeshInstance3D.new()
		var bm  := BoxMesh.new()
		bm.size = Vector3(0.18, 1.0, 0.18)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.22, 0.10)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.position = Vector3(0.0, float(i) + 0.5, 0.0)
		add_child(mi)

func _build_board() -> void:
	# 외곽 흰색 링
	var outer := MeshInstance3D.new()
	var om    := BoxMesh.new()
	om.size   = Vector3(0.90, 0.90, 0.12)
	outer.mesh = om
	_mat_ring  = StandardMaterial3D.new()
	_mat_ring.albedo_color = COLOR_RING
	_mat_ring.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer.material_override = _mat_ring
	var top : float = float(_get_pole_height()) + 0.45
	outer.position = Vector3(0.0, top, 0.0)
	add_child(outer)

	# 빨간 중앙 과녁
	var bull := MeshInstance3D.new()
	var bm   := BoxMesh.new()
	bm.size  = Vector3(0.38, 0.38, 0.14)
	bull.mesh = bm
	_mat_bull  = StandardMaterial3D.new()
	_mat_bull.albedo_color = COLOR_BULL
	_mat_bull.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bull.material_override = _mat_bull
	bull.position = Vector3(0.0, top, 0.0)
	add_child(bull)

func _get_pole_height() -> int:
	var h : int = 0
	for child in get_children():
		if child is MeshInstance3D:
			h += 1
	return h

func _build_collision() -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.90, 0.90, 0.20)
	var top : float = float(_get_pole_height()) - 1 + 0.45
	cs.position = Vector3(0.0, top, 0.0)
	cs.shape = sh
	add_child(cs)

func take_damage() -> void:
	_hit_count += 1
	_mat_ring.albedo_color = COLOR_HIT
	_mat_bull.albedo_color = COLOR_HIT
	get_tree().create_timer(0.30).timeout.connect(_reset_color)

func _reset_color() -> void:
	if not is_inside_tree():
		return
	_mat_ring.albedo_color = COLOR_RING
	_mat_bull.albedo_color = COLOR_BULL
