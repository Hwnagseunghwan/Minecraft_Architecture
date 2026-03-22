extends Node3D

const MAP_SIZE   : int = 32
const MAX_HEIGHT : int = 14

const BLOCK_GRASS  = 0
const BLOCK_DIRT   = 1
const BLOCK_STONE  = 2
const BLOCK_LOG    = 3
const BLOCK_PLANK  = 4
const BLOCK_GLASS  = 5
const BLOCK_WHITE  = 6
const BLOCK_RED    = 7
const BLOCK_WATER  = 8

const BLOCK_COLORS : Dictionary = {
	0: Color(0.38, 0.68, 0.22),
	1: Color(0.50, 0.35, 0.20),
	2: Color(0.55, 0.55, 0.55),
	3: Color(0.35, 0.22, 0.10),
	4: Color(0.80, 0.65, 0.40),
	5: Color(0.75, 0.90, 1.00),
	6: Color(0.95, 0.95, 0.95),
	7: Color(0.80, 0.20, 0.20),
	8: Color(0.20, 0.50, 0.90),
}

# 나뭇잎 3가지 초록 색조
const LEAF_COLORS : Array = [
	Color(0.20, 0.85, 0.10),   # 진한 초록
	Color(0.30, 0.90, 0.20),   # 중간 초록
	Color(0.45, 0.95, 0.30),   # 밝은 초록
]

var _blocks        : Dictionary = {}
var _saved_terrain : Dictionary = {}
var _mat_cache     : Dictionary = {}
var _grass_mesh    : ArrayMesh  = null
var _highlight     : MeshInstance3D

func _ready() -> void:
	_create_highlight()
	generate_terrain()
	_save_terrain()

# ── 잔디 전용 메시 (윗면=초록, 옆면=흙색, 아랫면=흙) ──────
func _make_mat(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _get_grass_mesh() -> ArrayMesh:
	if _grass_mesh != null:
		return _grass_mesh
	var mat_top  := _make_mat(Color(0.20, 0.90, 0.15))  # 밝은 초록
	var mat_side := _make_mat(Color(0.46, 0.32, 0.14))  # 흙빛 갈색
	var mat_bot  := _make_mat(Color(0.50, 0.35, 0.18))  # 흙
	var mesh := ArrayMesh.new()

	# 윗면
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat_top)
	_add_quad(st, mat_top.albedo_color, Vector3.UP,
		Vector3(-0.5, 0.5, 0.5), Vector3( 0.5, 0.5, 0.5),
		Vector3( 0.5, 0.5,-0.5), Vector3(-0.5, 0.5,-0.5))
	st.commit(mesh)

	# 아랫면
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat_bot)
	_add_quad(st, mat_bot.albedo_color, Vector3.DOWN,
		Vector3(-0.5,-0.5,-0.5), Vector3( 0.5,-0.5,-0.5),
		Vector3( 0.5,-0.5, 0.5), Vector3(-0.5,-0.5, 0.5))
	st.commit(mesh)

	# 4개 옆면
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat_side)
	_add_quad(st, mat_side.albedo_color, Vector3( 0, 0, 1),
		Vector3(-0.5,-0.5, 0.5), Vector3( 0.5,-0.5, 0.5),
		Vector3( 0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5))
	_add_quad(st, mat_side.albedo_color, Vector3( 0, 0,-1),
		Vector3( 0.5,-0.5,-0.5), Vector3(-0.5,-0.5,-0.5),
		Vector3(-0.5, 0.5,-0.5), Vector3( 0.5, 0.5,-0.5))
	_add_quad(st, mat_side.albedo_color, Vector3( 1, 0, 0),
		Vector3( 0.5,-0.5, 0.5), Vector3( 0.5,-0.5,-0.5),
		Vector3( 0.5, 0.5,-0.5), Vector3( 0.5, 0.5, 0.5))
	_add_quad(st, mat_side.albedo_color, Vector3(-1, 0, 0),
		Vector3(-0.5,-0.5,-0.5), Vector3(-0.5,-0.5, 0.5),
		Vector3(-0.5, 0.5, 0.5), Vector3(-0.5, 0.5,-0.5))
	st.commit(mesh)

	_grass_mesh = mesh
	return _grass_mesh

func _add_quad(st: SurfaceTool, color: Color, normal: Vector3,
			   v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	st.set_color(color)
	st.set_normal(normal)
	st.add_vertex(v0); st.add_vertex(v1); st.add_vertex(v2)
	st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v3)

# ── 머티리얼 캐시 ─────────────────────────────────────
func _get_mat(btype: int) -> StandardMaterial3D:
	if _mat_cache.has(btype):
		return _mat_cache[btype]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BLOCK_COLORS[btype]
	if btype == BLOCK_GLASS:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.45
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif btype == BLOCK_WATER:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.70
	_mat_cache[btype] = mat
	return mat

func _get_color_mat(color: Color) -> StandardMaterial3D:
	var key : String = color.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	_mat_cache[key] = mat
	return mat

# ── 나뭇잎 색 결정 (위치 기반 3가지 변화) ───────────────
func _leaf_color(x: int, y: int, z: int) -> Color:
	return LEAF_COLORS[(x * 7 + y * 11 + z * 13) % 3]

# ── 블록 노드 생성 ────────────────────────────────────
func _make_node(btype: int, color_override: Color = Color.TRANSPARENT) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mi   := MeshInstance3D.new()
	if btype == BLOCK_GRASS and color_override == Color.TRANSPARENT:
		# 잔디 전용 메시 (윗면/옆면 색 분리)
		mi.mesh = _get_grass_mesh()
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		mi.mesh = bm
		if color_override != Color.TRANSPARENT:
			mi.material_override = _get_color_mat(color_override)
		else:
			mi.material_override = _get_mat(btype)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3.ONE
	cs.shape = sh
	body.add_child(cs)
	body.set_meta("btype",  btype)
	body.set_meta("color",  color_override)
	return body

# ── 내부 배치 ─────────────────────────────────────────
func _place(pos: Vector3i, btype: int,
			color_override: Color = Color.TRANSPARENT) -> void:
	if _blocks.has(pos):
		_blocks[pos].queue_free()
		_blocks.erase(pos)
	var node := _make_node(btype, color_override)
	node.position = Vector3(pos.x, pos.y, pos.z)
	add_child(node)
	_blocks[pos] = node

func _place_safe(pos: Vector3i, btype: int,
				 color_override: Color = Color.TRANSPARENT) -> void:
	if pos.x < 0 or pos.x >= MAP_SIZE or pos.z < 0 or pos.z >= MAP_SIZE:
		return
	if pos.y < 0 or pos.y > MAX_HEIGHT:
		return
	_place(pos, btype, color_override)

# ── 공개 API ──────────────────────────────────────────
func set_highlight(pos: Vector3i, show: bool) -> void:
	_highlight.visible = show
	if show:
		_highlight.position = Vector3(pos.x, pos.y, pos.z)

func place_block(pos: Vector3i, btype: int) -> bool:
	if pos.x < 0 or pos.x >= MAP_SIZE or pos.z < 0 or pos.z >= MAP_SIZE:
		return false
	if pos.y < 0 or pos.y > MAX_HEIGHT:
		return false
	if btype == BLOCK_WATER:
		return false
	_place(pos, btype)
	return true

func remove_block(pos: Vector3i) -> bool:
	if not _blocks.has(pos):
		return false
	if _blocks[pos].get_meta("btype") == BLOCK_WATER:
		return false
	_blocks[pos].queue_free()
	_blocks.erase(pos)
	return true

# ── 지형 생성 ─────────────────────────────────────────
func _is_water(x: int, z: int) -> bool:
	if z >= 13 and z <= 16 and x >= 4 and x <= 27:
		return true
	if x >= 24 and z >= 23:
		return true
	return false

func _hill_h(x: int, z: int) -> int:
	var d1 : float = Vector2(x, z).distance_to(Vector2(5, 5))
	var h1 : int   = maxi(0, 4 - int(d1))
	var d2 : float = Vector2(x, z).distance_to(Vector2(26, 6))
	var h2 : int   = maxi(0, 3 - int(d2))
	return maxi(h1, h2)

func generate_terrain() -> void:
	for z in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			if _is_water(x, z):
				_place(Vector3i(x, 0, z), BLOCK_WATER)
			else:
				var top : int = 1 + _hill_h(x, z)
				for y in range(top + 1):
					var btype : int
					if y == top:
						btype = BLOCK_GRASS
					elif y == top - 1:
						btype = BLOCK_DIRT
					else:
						btype = BLOCK_STONE
					_place(Vector3i(x, y, z), btype)
	# 나무 6그루
	_place_tree(8,  2, 8)
	_place_tree(20, 2, 10)
	_place_tree(6,  2, 20)
	_place_tree(14, 2, 24)
	_place_tree(24, 2, 20)
	_place_tree(28, 2, 10)

# ── 나무: 트렁크 4칸 + 피라미드형 캐노피 ─────────────────
func _place_tree(x: int, base_y: int, z: int) -> void:
	# 트렁크 4블록
	for y in range(base_y, base_y + 4):
		_place(Vector3i(x, y, z), BLOCK_LOG)
	var top := base_y + 4
	# 층 0: 5×5 (네 꼭짓점 제외 = 21블록)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if abs(dx) == 2 and abs(dz) == 2:
				continue
			var lx := x + dx; var lz := z + dz
			_place_safe(Vector3i(lx, top,     lz), BLOCK_GRASS, _leaf_color(lx, top,     lz))
	# 층 1: 3×3
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var lx := x + dx; var lz := z + dz
			_place_safe(Vector3i(lx, top + 1, lz), BLOCK_GRASS, _leaf_color(lx, top + 1, lz))
	# 꼭대기: 1블록
	_place_safe(Vector3i(x, top + 2, z), BLOCK_GRASS, _leaf_color(x, top + 2, z))

# ── 하이라이트 ────────────────────────────────────────
func _create_highlight() -> void:
	_highlight = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.04, 1.04, 1.04)
	_highlight.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 1.0, 0.2, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 1
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_highlight.material_override = mat
	_highlight.visible = false
	add_child(_highlight)

# ── 리셋 ──────────────────────────────────────────────
func _save_terrain() -> void:
	for pos in _blocks:
		_saved_terrain[pos] = {
			"btype": _blocks[pos].get_meta("btype"),
			"color": _blocks[pos].get_meta("color"),
		}

func reset_world() -> void:
	for pos in _blocks.keys():
		_blocks[pos].queue_free()
	_blocks.clear()
	for pos in _saved_terrain:
		var d = _saved_terrain[pos]
		_place(pos, d["btype"], d["color"])
