extends Node3D

const CHUNK_SIZE  : int = 16
const RENDER_DIST : int = 2
const MAX_HEIGHT  : int = 14

const BLOCK_GRASS    = 0
const BLOCK_DIRT     = 1
const BLOCK_STONE    = 2
const BLOCK_LOG      = 3
const BLOCK_PLANK    = 4
const BLOCK_GLASS    = 5
const BLOCK_WHITE    = 6
const BLOCK_RED      = 7
const BLOCK_WATER    = 8
const BLOCK_BRICK    = 9
const BLOCK_CONCRETE = 10
const BLOCK_WOOD     = 11
const BLOCK_ROOF     = 12

const BLOCK_COLORS : Dictionary = {
	0: Color(0.38, 0.68, 0.22),
	1: Color(0.50, 0.35, 0.20),
	2: Color(0.55, 0.55, 0.55),
	3: Color(0.35, 0.22, 0.10),
	4: Color(0.80, 0.65, 0.40),
	5: Color(0.75, 0.90, 1.00),
	6: Color(0.95, 0.95, 0.95),
	7: Color(0.80, 0.20, 0.20),
	8:  Color(0.20, 0.50, 0.90),
	9:  Color(0.70, 0.30, 0.20),
	10: Color(0.75, 0.75, 0.75),
	11: Color(0.55, 0.38, 0.18),
	12: Color(0.28, 0.22, 0.16),
}

const LEAF_COLORS : Array = [
	Color(0.20, 0.85, 0.10),
	Color(0.30, 0.90, 0.20),
	Color(0.45, 0.95, 0.30),
]

var _blocks      : Dictionary = {}
var _mat_cache   : Dictionary = {}
var _grass_mesh  : ArrayMesh  = null
var _highlight   : MeshInstance3D
var _crack_overlay : MeshInstance3D
var _vertex_mat  : StandardMaterial3D = null
var _mesh_pool   : Dictionary         = {}

var _loaded_chunks     : Dictionary = {}
var _last_player_chunk : Vector2i   = Vector2i(-9999, -9999)
var _animals_spawned   : bool       = false
var _spawn_waterfall_done : bool    = false

const MESH_VARIANTS : int = 16

func _ready() -> void:
	_create_highlight()
	_create_crack_overlay()

# ── 청크 시스템 ────────────────────────────────────────
func _chunk_key(cx: int, cz: int) -> String:
	return str(cx) + "," + str(cz)

func _pos_to_chunk(x: int, z: int) -> Vector2i:
	return Vector2i(floori(float(x) / float(CHUNK_SIZE)), floori(float(z) / float(CHUNK_SIZE)))

func _terrain_height(x: int, z: int) -> int:
	var fx := float(x)
	var fz := float(z)
	var h  := sin(fx * 0.07) * cos(fz * 0.09) * 3.5
	h      += sin(fx * 0.13 + 1.2) * cos(fz * 0.11 + 0.8) * 2.0
	h      += sin(fx * 0.21 + fz * 0.17) * 1.0
	return 1 + int(absf(h))

func _is_water_at(x: int, z: int) -> bool:
	var fx := float(x)
	var fz := float(z)
	return sin(fx * 0.05 + 1.3) * sin(fz * 0.07 + 0.6) > 0.72

func _has_tree(x: int, z: int) -> bool:
	var h := absf(sin(float(x * 73 + z * 127) * 0.00731))
	return h > 0.9995 and not _is_water_at(x, z)

func _generate_chunk(cx: int, cz: int) -> void:
	var key := _chunk_key(cx, cz)
	if _loaded_chunks.has(key):
		return
	_loaded_chunks[key] = true
	var bx := cx * CHUNK_SIZE
	var bz := cz * CHUNK_SIZE
	for lz in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var wx := bx + lx
			var wz := bz + lz
			if _is_water_at(wx, wz):
				_place(Vector3i(wx, 0, wz), BLOCK_WATER)
			else:
				var top := _terrain_height(wx, wz)
				for y in range(top + 1):
					var btype : int
					if y == top:       btype = BLOCK_GRASS
					elif y == top - 1: btype = BLOCK_DIRT
					else:              btype = BLOCK_STONE
					_place(Vector3i(wx, y, wz), btype)
				if _has_tree(wx, wz):
					_place_tree(wx, top, wz)
	_spawn_animals_in_chunk(cx, cz)
	_try_place_waterfall_in_chunk(cx, cz)

func _place_guaranteed_waterfall(origin_x: int, origin_z: int, radius: int) -> void:
	var dirs : Array = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	# 1단계: 반경 내에서 물 인접 육지 중 가장 높은 곳 탐색
	var best_x := 0; var best_z := 0; var best_h := 0
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			var wx := origin_x + dx
			var wz := origin_z + dz
			if _is_water_at(wx, wz):
				continue
			var h := _terrain_height(wx, wz)
			if h <= best_h:
				continue
			for d in dirs:
				if _is_water_at(wx + d.x, wz + d.y):
					best_x = wx; best_z = wz; best_h = h
					break
	if best_h >= 1:
		_place_waterfall_wide(best_x, best_z, best_h)
		return
	# 2단계: 물이 전혀 없으면 가장 높은 지점 옆에 인공 폭포 생성
	var peak_x := origin_x; var peak_z := origin_z
	var peak_h := 0
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			var wx := origin_x + dx
			var wz := origin_z + dz
			var h := _terrain_height(wx, wz)
			if h > peak_h:
				peak_h = h; peak_x = wx; peak_z = wz
	for oz in range(-2, 3):
		_place(Vector3i(peak_x + 1, 0, peak_z + oz), BLOCK_WATER)
	_place_waterfall_wide(peak_x, peak_z, peak_h)

func _try_place_waterfall_in_chunk(cx: int, cz: int) -> void:
	if randf() > 0.1:
		return
	var bx := cx * CHUNK_SIZE
	var bz := cz * CHUNK_SIZE
	var dirs : Array = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for lz in range(1, CHUNK_SIZE - 1):
		for lx in range(1, CHUNK_SIZE - 1):
			var wx := bx + lx
			var wz := bz + lz
			if _is_water_at(wx, wz):
				continue
			var h := _terrain_height(wx, wz)
			if h < 3:
				continue
			var near_water := false
			for d in dirs:
				if _is_water_at(wx + d.x, wz + d.y):
					near_water = true
					break
			if not near_water:
				continue
			# 폭포: 절벽 면에 물 블록을 y=1부터 꼭대기까지
			_place_waterfall_wide(wx, wz, h)
			return

func _place_waterfall_wide(wx: int, wz: int, h: int) -> void:
	var offsets : Array = [Vector2i(0,0), Vector2i(0,-1), Vector2i(0,1),
						   Vector2i(0,-2), Vector2i(0,2),
						   Vector2i(-1,0), Vector2i(1,0)]
	for y in range(1, h + 1):
		for o in offsets:
			_place(Vector3i(wx + o.x, y, wz + o.y), BLOCK_WATER)

func _unload_chunk(cx: int, cz: int) -> void:
	var key := _chunk_key(cx, cz)
	if not _loaded_chunks.has(key):
		return
	var bx := cx * CHUNK_SIZE
	var bz := cz * CHUNK_SIZE
	var to_remove : Array = []
	for pos in _blocks.keys():
		if pos.x >= bx and pos.x < bx + CHUNK_SIZE and \
		   pos.z >= bz and pos.z < bz + CHUNK_SIZE:
			to_remove.append(pos)
	for pos in to_remove:
		if _blocks.has(pos):
			_blocks[pos].queue_free()
			_blocks.erase(pos)
	_loaded_chunks.erase(key)

func update_chunks(player_pos: Vector3) -> void:
	var pc := _pos_to_chunk(int(player_pos.x), int(player_pos.z))
	# 미로드 청크가 있으면 프레임당 1개만 생성
	for dx in range(-RENDER_DIST, RENDER_DIST + 1):
		for dz in range(-RENDER_DIST, RENDER_DIST + 1):
			var cx := pc.x + dx
			var cz := pc.y + dz
			if not _loaded_chunks.has(_chunk_key(cx, cz)):
				_generate_chunk(cx, cz)
				return  # 이번 프레임은 여기까지
	# 주변 청크 전부 로드 완료
	if not _animals_spawned:
		_animals_spawned = true
		spawn_animals()
	if not _spawn_waterfall_done:
		_spawn_waterfall_done = true
		_place_guaranteed_waterfall(32, 32, 60)
	if pc == _last_player_chunk:
		return
	_last_player_chunk = pc
	var to_unload : Array = []
	for key in _loaded_chunks.keys():
		var parts : PackedStringArray = key.split(",")
		var cx    := int(parts[0])
		var cz    := int(parts[1])
		if abs(cx - pc.x) > RENDER_DIST + 1 or abs(cz - pc.y) > RENDER_DIST + 1:
			to_unload.append([cx, cz])
	for pair in to_unload:
		_unload_chunk(pair[0], pair[1])

# ── 메시 생성 ──────────────────────────────────────────
func _get_vertex_mat() -> StandardMaterial3D:
	if _vertex_mat != null:
		return _vertex_mat
	_vertex_mat = StandardMaterial3D.new()
	_vertex_mat.vertex_color_use_as_albedo = true
	_vertex_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_vertex_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _vertex_mat

func _vert_hash(seed: int, vi: int) -> float:
	var h := sin(float(seed * 127 + vi * 1009) * 0.127)
	return fmod(absf(h) * 43758.5453, 1.0)

func _build_noisy_box(base_color: Color, seed: int, variation: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st   := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_get_vertex_mat())
	var faces : Array = [
		[Vector3(-0.5,-0.5, 0.5), Vector3( 0.5,-0.5, 0.5), Vector3( 0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5), Vector3( 0, 0, 1)],
		[Vector3( 0.5,-0.5,-0.5), Vector3(-0.5,-0.5,-0.5), Vector3(-0.5, 0.5,-0.5), Vector3( 0.5, 0.5,-0.5), Vector3( 0, 0,-1)],
		[Vector3(-0.5, 0.5, 0.5), Vector3( 0.5, 0.5, 0.5), Vector3( 0.5, 0.5,-0.5), Vector3(-0.5, 0.5,-0.5), Vector3( 0, 1, 0)],
		[Vector3(-0.5,-0.5,-0.5), Vector3( 0.5,-0.5,-0.5), Vector3( 0.5,-0.5, 0.5), Vector3(-0.5,-0.5, 0.5), Vector3( 0,-1, 0)],
		[Vector3( 0.5,-0.5, 0.5), Vector3( 0.5,-0.5,-0.5), Vector3( 0.5, 0.5,-0.5), Vector3( 0.5, 0.5, 0.5), Vector3( 1, 0, 0)],
		[Vector3(-0.5,-0.5,-0.5), Vector3(-0.5,-0.5, 0.5), Vector3(-0.5, 0.5, 0.5), Vector3(-0.5, 0.5,-0.5), Vector3(-1, 0, 0)],
	]
	for fi in range(6):
		var face   : Array   = faces[fi]
		var normal : Vector3 = face[4]
		var verts  : Array   = [face[0], face[1], face[2], face[3]]
		var colors : Array   = []
		for vi in range(4):
			var h      := _vert_hash(seed + fi * 97, vi)
			var offset := (h - 0.5) * variation * 2.0
			colors.append(Color(
				clampf(base_color.r + offset, 0.0, 1.0),
				clampf(base_color.g + offset, 0.0, 1.0),
				clampf(base_color.b + offset, 0.0, 1.0)
			))
		st.set_normal(normal)
		st.set_color(colors[0]); st.add_vertex(verts[0])
		st.set_color(colors[1]); st.add_vertex(verts[1])
		st.set_color(colors[2]); st.add_vertex(verts[2])
		st.set_color(colors[0]); st.add_vertex(verts[0])
		st.set_color(colors[2]); st.add_vertex(verts[2])
		st.set_color(colors[3]); st.add_vertex(verts[3])
	st.commit(mesh)
	return mesh

func _get_noisy_mesh(btype: int, pos: Vector3i) -> ArrayMesh:
	if not _mesh_pool.has(btype):
		var pool : Array = []
		var base_col : Color = BLOCK_COLORS[btype]
		var vari : float = _get_variation(btype)
		for i in range(MESH_VARIANTS):
			pool.append(_build_noisy_box(base_col, i * 1009 + btype * 31, vari))
		_mesh_pool[btype] = pool
	var idx : int = (pos.x * 7 + pos.y * 13 + pos.z * 11) % MESH_VARIANTS
	return _mesh_pool[btype][idx] as ArrayMesh

func _get_noisy_mesh_colored(color: Color, pos: Vector3i) -> ArrayMesh:
	var key : String = color.to_html()
	if not _mesh_pool.has(key):
		var pool : Array = []
		for i in range(MESH_VARIANTS):
			pool.append(_build_noisy_box(color, i * 1009 + color.r8 * 31, 0.09))
		_mesh_pool[key] = pool
	var idx : int = (pos.x * 7 + pos.y * 13 + pos.z * 11) % MESH_VARIANTS
	return _mesh_pool[key][idx] as ArrayMesh

func _make_mat(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _get_grass_mesh() -> ArrayMesh:
	if _grass_mesh != null:
		return _grass_mesh
	var mat_top  := _make_mat(Color(0.20, 0.90, 0.15))
	var mat_side := _make_mat(Color(0.46, 0.32, 0.14))
	var mat_bot  := _make_mat(Color(0.50, 0.35, 0.18))
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat_top)
	_add_quad(st, mat_top.albedo_color, Vector3.UP,
		Vector3(-0.5, 0.5, 0.5), Vector3( 0.5, 0.5, 0.5),
		Vector3( 0.5, 0.5,-0.5), Vector3(-0.5, 0.5,-0.5))
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat_bot)
	_add_quad(st, mat_bot.albedo_color, Vector3.DOWN,
		Vector3(-0.5,-0.5,-0.5), Vector3( 0.5,-0.5,-0.5),
		Vector3( 0.5,-0.5, 0.5), Vector3(-0.5,-0.5, 0.5))
	st.commit(mesh)
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
	st.set_color(color); st.set_normal(normal)
	st.add_vertex(v0); st.add_vertex(v1); st.add_vertex(v2)
	st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v3)

func _get_variation(btype: int) -> float:
	match btype:
		BLOCK_STONE:    return 0.10
		BLOCK_DIRT:     return 0.08
		BLOCK_LOG:      return 0.12
		BLOCK_PLANK:    return 0.08
		BLOCK_WHITE:    return 0.04
		BLOCK_RED:      return 0.07
		BLOCK_BRICK:    return 0.10
		BLOCK_CONCRETE: return 0.06
		BLOCK_WOOD:     return 0.11
		BLOCK_ROOF:     return 0.08
		_:              return 0.05

func _get_mat(btype: int) -> Material:
	if _mat_cache.has(btype):
		return _mat_cache[btype]
	if btype == BLOCK_GLASS or btype == BLOCK_WATER:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = BLOCK_COLORS[btype]
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color.a = 0.45 if btype == BLOCK_GLASS else 0.70
		_mat_cache[btype] = mat
		return mat
	return _get_vertex_mat()

func _leaf_color(x: int, y: int, z: int) -> Color:
	return LEAF_COLORS[(x * 7 + y * 11 + z * 13) % 3]

func _make_node(btype: int, color_override: Color = Color.TRANSPARENT, pos: Vector3i = Vector3i.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mi   := MeshInstance3D.new()
	if btype == BLOCK_GRASS and color_override == Color.TRANSPARENT:
		mi.mesh = _get_grass_mesh()
	elif btype == BLOCK_GLASS or btype == BLOCK_WATER:
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		mi.mesh = bm
		mi.material_override = _get_mat(btype)
	elif color_override != Color.TRANSPARENT:
		mi.mesh = _get_noisy_mesh_colored(color_override, pos)
	else:
		mi.mesh = _get_noisy_mesh(btype, pos)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3.ONE
	cs.shape = sh
	body.add_child(cs)
	body.set_meta("btype",  btype)
	body.set_meta("color",  color_override)
	return body

func _place(pos: Vector3i, btype: int, color_override: Color = Color.TRANSPARENT) -> void:
	if _blocks.has(pos):
		_blocks[pos].queue_free()
		_blocks.erase(pos)
	var node := _make_node(btype, color_override, pos)
	node.position = Vector3(pos.x, pos.y, pos.z)
	add_child(node)
	_blocks[pos] = node

# ── 공개 API ──────────────────────────────────────────
func get_surface_y(x: int, z: int) -> float:
	if _is_water_at(x, z):
		return 2.0
	return float(_terrain_height(x, z)) + 1.1

func set_highlight(pos: Vector3i, show: bool) -> void:
	_highlight.visible = show
	if show:
		_highlight.position = Vector3(pos.x, pos.y, pos.z)

func place_block(pos: Vector3i, btype: int) -> bool:
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

func reset_world() -> void:
	var keys := _loaded_chunks.keys().duplicate()
	for key in keys:
		var parts : PackedStringArray = key.split(",")
		_unload_chunk(int(parts[0]), int(parts[1]))
	_last_player_chunk = Vector2i(-9999, -9999)
	_animals_spawned = false
	_spawn_waterfall_done = false

# ── 나무 ──────────────────────────────────────────────
func _place_tree(x: int, base_y: int, z: int) -> void:
	for y in range(base_y, base_y + 4):
		if y <= MAX_HEIGHT:
			_place(Vector3i(x, y, z), BLOCK_LOG)
	var top := base_y + 4
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if abs(dx) == 2 and abs(dz) == 2:
				continue
			var lx := x + dx; var lz := z + dz
			if top <= MAX_HEIGHT:
				_place(Vector3i(lx, top, lz), BLOCK_GRASS, _leaf_color(lx, top, lz))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var lx := x + dx; var lz := z + dz
			if top + 1 <= MAX_HEIGHT:
				_place(Vector3i(lx, top + 1, lz), BLOCK_GRASS, _leaf_color(lx, top + 1, lz))
	if top + 2 <= MAX_HEIGHT:
		_place(Vector3i(x, top + 2, z), BLOCK_GRASS, _leaf_color(x, top + 2, z))

# ── 균열 텍스처 ───────────────────────────────────────
var _crack_textures : Array[ImageTexture] = []

const _CRACK_LINES : Array = [
	[[[16,16],[5,8]],  [[16,16],[26,5]]],
	[[[16,16],[5,8]],  [[16,16],[26,5]],  [[16,16],[25,26]], [[16,16],[4,24]]],
	[[[16,16],[5,8]],  [[16,16],[26,5]],  [[16,16],[25,26]], [[16,16],[4,24]],
	 [[5,8],[1,2]],    [[26,5],[31,1]],   [[10,12],[18,4]]],
	[[[16,16],[5,8]],  [[16,16],[26,5]],  [[16,16],[25,26]], [[16,16],[4,24]],
	 [[5,8],[1,2]],    [[26,5],[31,1]],   [[10,12],[18,4]],
	 [[25,26],[30,31]],[[4,24],[1,30]],   [[20,20],[28,24]]],
	[[[16,16],[5,8]],  [[16,16],[26,5]],  [[16,16],[25,26]], [[16,16],[4,24]],
	 [[5,8],[1,2]],    [[26,5],[31,1]],   [[10,12],[18,4]],
	 [[25,26],[30,31]],[[4,24],[1,30]],   [[20,20],[28,24]],
	 [[5,8],[12,3]],   [[16,16],[22,11]], [[8,20],[3,16]],   [[20,10],[24,2]]],
]

func _draw_line_on_image(img: Image, x0: int, y0: int, x1: int, y1: int) -> void:
	var dx := absi(x1 - x0); var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	var color := Color(0.05, 0.05, 0.05, 0.9)
	while true:
		if x0 >= 0 and x0 < 32 and y0 >= 0 and y0 < 32:
			img.set_pixel(x0, y0, color)
		if x0 == x1 and y0 == y1:
			break
		var e2 := err * 2
		if e2 > -dy: err -= dy; x0 += sx
		if e2 < dx:  err += dx; y0 += sy

func _build_crack_textures() -> void:
	for lines in _CRACK_LINES:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for ln in lines:
			_draw_line_on_image(img, ln[0][0], ln[0][1], ln[1][0], ln[1][1])
		_crack_textures.append(ImageTexture.create_from_image(img))

func _create_crack_overlay() -> void:
	_build_crack_textures()
	_crack_overlay = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.03, 1.03, 1.03)
	_crack_overlay.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 2
	mat.albedo_texture = _crack_textures[0]
	_crack_overlay.material_override = mat
	_crack_overlay.visible = false
	add_child(_crack_overlay)

func set_crack(pos: Vector3i, progress: float) -> void:
	if progress <= 0.0:
		_crack_overlay.visible = false
		return
	_crack_overlay.visible = true
	_crack_overlay.position = Vector3(pos.x, pos.y, pos.z)
	var stage := mini(int(progress * 5), 4)
	var mat := _crack_overlay.material_override as StandardMaterial3D
	mat.albedo_texture = _crack_textures[stage]

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

# ── 동물 스폰 ─────────────────────────────────────────
func spawn_animals() -> void:
	pass  # 청크 생성 시 자동 스폰으로 대체

func _spawn_animals_in_chunk(cx: int, cz: int) -> void:
	var Animal := preload("res://scripts/animal.gd")
	var bx := cx * CHUNK_SIZE
	var bz := cz * CHUNK_SIZE
	var count := randi_range(1, 3)
	for _i in range(count):
		var lx := randi_range(0, CHUNK_SIZE - 1)
		var lz := randi_range(0, CHUNK_SIZE - 1)
		var wx := bx + lx
		var wz := bz + lz
		var type := randi_range(0, 4)
		if type == 2:  # 물고기
			var pos := Vector3i(wx, 0, wz)
			if _blocks.has(pos) and _blocks[pos].get_meta("btype") == BLOCK_WATER:
				var a := Animal.new()
				add_child(a)
				a.call("setup", 2)
				a.set("_target_y", 0.5)
				a.global_position = Vector3(wx + 0.5, 0.5, wz + 0.5)
		elif type == 3:  # 새
			var ty := float(randi_range(7, 10))
			var a := Animal.new()
			add_child(a)
			a.call("setup", 3)
			a.set("_target_y", ty)
			a.global_position = Vector3(wx + 0.5, ty, wz + 0.5)
		else:  # 닭·소·공룡
			for y in range(MAX_HEIGHT, -1, -1):
				var pos := Vector3i(wx, y, wz)
				if _blocks.has(pos):
					if _blocks[pos].get_meta("btype") == BLOCK_GRASS:
						var a := Animal.new()
						add_child(a)
						a.call("setup", type)
						a.global_position = Vector3(wx + 0.5, float(y) + 1.1, wz + 0.5)
					break
