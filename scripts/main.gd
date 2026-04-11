extends Node3D

const DAY_LENGTH : float = 600.0  # 낮+밤 1사이클 (초) — 낮 5분 + 밤 5분

var _sun      : DirectionalLight3D
var _sky_mat  : ProceduralSkyMaterial
var _env      : Environment
var _time     : float = 0.0  # 0.0 = 정오, 0.5 = 자정
var _world    : Node3D = null
var _player   : CharacterBody3D = null

func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_setup_safety_floor()

	# 월드 생성
	var world_script := preload("res://scripts/world.gd")
	_world = world_script.new()
	_world.name = "World"
	add_child(_world)

	# 플레이어 생성
	var player_scene := preload("res://scenes/Player.tscn")
	_player = player_scene.instantiate()
	_player.world = _world
	add_child(_player)
	var spawn_y : float = _world.call("get_surface_y", 32, 32) + 10.0
	_player.global_position = Vector3(32.0, spawn_y, 32.0)

	# UI 생성
	var ui_script := preload("res://scripts/ui.gd")
	var ui := ui_script.new()
	ui.name = "UI"
	add_child(ui)

	# 석궁 연습장
	_build_range_area()

	# 시그널 연결
	_player.block_selected.connect(ui._on_block_selected)
	_player.inventory_changed.connect(ui._on_inventory_changed)
	_player.mode_changed.connect(ui._on_mode_changed)
	_player.hp_changed.connect(ui._on_hp_changed)
	_player.hp_healed.connect(ui._on_hp_healed)
	_player.player_died.connect(ui._on_player_died)
	_player.player_respawned.connect(ui._on_player_respawned)

func _build_range_area() -> void:
	# 포탈 연습장: 메인 월드 밖 x=500, z=500 기준
	var B : Vector3 = Vector3(500.0, 0.0, 500.0)

	# 바닥
	_range_solid(B + Vector3( 1.0, -0.5,   0.0), Vector3(34, 1, 34), Color(0.48, 0.46, 0.44))

	# 벽 3면 (북·남·동) + 입구 서쪽 벽
	_range_solid(B + Vector3( 1.0,  5.0, -17.5), Vector3(34, 12,  1), Color(0.56, 0.45, 0.35))
	_range_solid(B + Vector3( 1.0,  5.0,  17.5), Vector3(34, 12,  1), Color(0.56, 0.45, 0.35))
	_range_solid(B + Vector3(18.5,  5.0,   0.0), Vector3( 1, 12, 36), Color(0.50, 0.40, 0.30))
	_range_solid(B + Vector3(-16.5, 5.0,   0.0), Vector3( 1, 12, 36), Color(0.56, 0.45, 0.35))

	# 표적 10개 (연습장 구석구석 배치)
	var target_script := preload("res://scripts/target.gd")
	var tconfigs : Array = [
		# 원거리 타겟 벽 (x=513~516)
		[B + Vector3(15.0, 2.0, -14.0), 2],  # 원거리 좌끝 낮음
		[B + Vector3(15.0, 2.0,  -7.0), 5],  # 원거리 좌 높음
		[B + Vector3(16.0, 2.0,   0.0), 8],  # 원거리 중앙 최고
		[B + Vector3(15.0, 2.0,   7.0), 5],  # 원거리 우 높음
		[B + Vector3(15.0, 2.0,  14.0), 2],  # 원거리 우끝 낮음
		# 중거리 (x=505)
		[B + Vector3( 5.0, 2.0, -13.0), 3],  # 중거리 좌측 모서리
		[B + Vector3( 5.0, 2.0,  13.0), 3],  # 중거리 우측 모서리
		[B + Vector3( 6.0, 2.0,   0.0), 6],  # 중거리 중앙 높음
		# 근거리 (x=495)
		[B + Vector3(-4.0, 2.0, -10.0), 4],  # 근거리 좌측
		[B + Vector3(-4.0, 2.0,  10.0), 4],  # 근거리 우측
	]
	for cfg in tconfigs:
		var tpos   : Vector3 = cfg[0]
		var pole_h : int     = cfg[1]
		var t = target_script.new()
		add_child(t)
		t.call("build", pole_h)
		t.global_position = tpos

	# 출구 포탈 (입구 쪽)
	var portal_script := preload("res://scripts/portal.gd")
	var exit_portal = portal_script.new()
	add_child(exit_portal)
	exit_portal.global_position = B + Vector3(-14.0, 2.0, 0.0)
	var home_y : float = _world.call("get_surface_y", 32, 32)
	exit_portal.call("setup", Vector3(32.0, home_y, 32.0), true)

func _range_solid(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var cs   := CollisionShape3D.new()
	var sh   := BoxShape3D.new()
	sh.size  = size
	cs.shape = sh
	body.add_child(cs)
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	body.add_child(mi)
	body.position = pos
	add_child(body)
func _process(delta: float) -> void:
	_time = fmod(_time + delta / DAY_LENGTH, 1.0)
	_update_sky(_time)
	# 플레이어 이동에 따라 청크 동적 로드/언로드
	if _world != null and _player != null:
		_world.update_chunks(_player.global_position)
		# 지하 블록 실시간 유지 (플레이어가 지하에 있을 때)
		_world.fill_underground_around(_player.global_position)

func _update_sky(t: float) -> void:
	# t: 0=정오, 0.25=저녁, 0.5=자정, 0.75=새벽
	var angle := t * 360.0
	_sun.rotation_degrees.x = angle - 90.0

	# 태양 고도 (1=한낮, -1=한밤)
	var sun_h : float = cos(t * TAU)

	if sun_h > 0.0:
		# 낮
		var d : float = sun_h  # 1→0
		_sun.light_energy = lerp(0.0, 1.4, d)
		_sun.light_color = Color(1.0, lerp(0.55, 1.0, d), lerp(0.3, 0.95, d))

		_sky_mat.sky_top_color     = Color(lerp(0.05, 0.35, d), lerp(0.08, 0.60, d), lerp(0.15, 0.95, d))
		_sky_mat.sky_horizon_color = Color(lerp(0.55, 0.70, d), lerp(0.30, 0.85, d), lerp(0.10, 1.00, d))
		_env.ambient_light_energy  = lerp(0.05, 0.6, d)
	else:
		# 밤
		_sun.light_energy = 0.0
		_sky_mat.sky_top_color     = Color(0.01, 0.01, 0.04)
		_sky_mat.sky_horizon_color = Color(0.03, 0.03, 0.06)
		_env.ambient_light_energy  = 0.04

func _setup_environment() -> void:
	var we  := WorldEnvironment.new()
	_env = Environment.new()

	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color      = Color(0.35, 0.60, 0.95)
	_sky_mat.sky_horizon_color  = Color(0.70, 0.85, 1.00)
	_sky_mat.ground_bottom_color   = Color(0.25, 0.20, 0.15)
	_sky_mat.ground_horizon_color  = Color(0.50, 0.45, 0.40)
	sky.sky_material = _sky_mat
	_env.sky = sky

	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.6
	_env.tonemap_mode         = Environment.TONE_MAPPER_ACES

	# SSAO (주변광 차폐) – 깊이감 강화
	_env.ssao_enabled = true
	_env.ssao_radius   = 1.0
	_env.ssao_intensity = 1.8

	# 안개 – 원거리 자연스러운 페이드
	_env.fog_enabled   = true
	_env.fog_density   = 0.003
	_env.fog_sky_affect = 0.3

	we.environment = _env
	add_child(we)

func _setup_lighting() -> void:
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees          = Vector3(-90, 30, 0)
	_sun.light_energy              = 1.4
	_sun.shadow_enabled            = true
	_sun.directional_shadow_mode   = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.directional_shadow_max_distance = 80.0
	add_child(_sun)

func _setup_safety_floor() -> void:
	var body := StaticBody3D.new()
	var cs   := CollisionShape3D.new()
	var sh   := BoxShape3D.new()
	sh.size = Vector3(10000, 1, 10000)
	cs.shape = sh
	body.add_child(cs)
	body.position = Vector3(0, -999999, 0)  # 사실상 무한 지하 지원을 위해 안전 바닥 제거
	add_child(body)
