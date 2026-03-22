extends Node3D

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
	player.global_position = Vector3(16.0, 5.0, 22.0)

	# UI 생성
	var ui_script := preload("res://scripts/ui.gd")
	var ui := ui_script.new()
	ui.name = "UI"
	add_child(ui)

	# 시그널 연결
	player.block_selected.connect(ui._on_block_selected)

func _setup_environment() -> void:
	var we  := WorldEnvironment.new()
	var env := Environment.new()

	env.background_mode = Environment.BG_SKY
	var sky     := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color      = Color(0.35, 0.60, 0.95)
	sky_mat.sky_horizon_color  = Color(0.70, 0.85, 1.00)
	sky_mat.ground_bottom_color   = Color(0.25, 0.20, 0.15)
	sky_mat.ground_horizon_color  = Color(0.50, 0.45, 0.40)
	sky.sky_material = sky_mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = env
	add_child(we)

func _setup_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

func _setup_safety_floor() -> void:
	# 맵 아래 안전망 (플레이어가 추락해도 막아줌)
	var body := StaticBody3D.new()
	var cs   := CollisionShape3D.new()
	var sh   := BoxShape3D.new()
	sh.size = Vector3(200, 1, 200)
	cs.shape = sh
	body.add_child(cs)
	body.position = Vector3(12, -2, 12)
	add_child(body)
