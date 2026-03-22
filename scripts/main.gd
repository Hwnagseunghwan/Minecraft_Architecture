extends Node3D

const DAY_LENGTH : float = 120.0  # 낮+밤 1사이클 (초)

var _sun      : DirectionalLight3D
var _sky_mat  : ProceduralSkyMaterial
var _env      : Environment
var _time     : float = 0.0  # 0.0 = 정오, 0.5 = 자정

func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_setup_safety_floor()

	# 월드 생성
	var world_script := preload("res://scripts/world.gd")
	var world := world_script.new()
	world.name = "World"
	add_child(world)

	# 플레이어 생성
	var player_scene := preload("res://scenes/Player.tscn")
	var player := player_scene.instantiate()
	player.world = world
	add_child(player)
	player.global_position = Vector3(32.0, 5.0, 32.0)

	# UI 생성
	var ui_script := preload("res://scripts/ui.gd")
	var ui := ui_script.new()
	ui.name = "UI"
	add_child(ui)

	# 시그널 연결
	player.block_selected.connect(ui._on_block_selected)
	player.inventory_changed.connect(ui._on_inventory_changed)

func _process(delta: float) -> void:
	_time = fmod(_time + delta / DAY_LENGTH, 1.0)
	_update_sky(_time)

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
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = _env
	add_child(we)

func _setup_lighting() -> void:
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-90, 30, 0)
	_sun.light_energy = 1.4
	_sun.shadow_enabled = true
	add_child(_sun)

func _setup_safety_floor() -> void:
	var body := StaticBody3D.new()
	var cs   := CollisionShape3D.new()
	var sh   := BoxShape3D.new()
	sh.size = Vector3(400, 1, 400)
	cs.shape = sh
	body.add_child(cs)
	body.position = Vector3(32, -2, 32)
	add_child(body)
