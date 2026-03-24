extends Node

const RATE : int = 22050

var _pool : Array = []
var _idx  : int   = 0
var _cache : Dictionary = {}

func _ready() -> void:
	for _i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	# 첫 프레임 이후에 생성 (게임 로딩 차단 방지)
	call_deferred("_build_all")

func _build_all() -> void:
	_cache["dig"]     = _make(0.20, _wave_dig)
	_cache["place"]   = _make(0.10, _wave_place)
	_cache["step"]    = _make(0.08, _wave_step)
	_cache["hurt"]    = _make(0.28, _wave_hurt)
	_cache["die"]     = _make(0.55, _wave_die)
	_cache["pickup"]  = _make(0.18, _wave_pickup)
	_cache["swing"]   = _make(0.20, _wave_swing)
	_cache["chicken"] = _make(0.26, _wave_chicken)
	_cache["cow"]     = _make(0.50, _wave_cow)
	_cache["dino"]    = _make(0.60, _wave_dino)
	_cache["shoot"]   = _make(0.18, _wave_shoot)

func _make(dur: float, fn: Callable) -> AudioStreamWAV:
	var n   : int   = int(RATE * dur)
	var buf : PackedFloat32Array = fn.call(n)
	var wav := AudioStreamWAV.new()
	wav.format   = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo   = false
	var raw := PackedByteArray()
	raw.resize(n * 2)
	for i in range(n):
		var v : int = int(clampf(buf[i], -1.0, 1.0) * 32767)
		raw[i * 2]     = v & 0xFF
		raw[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = raw
	return wav

func _play(key: String, db: float) -> void:
	if not _cache.has(key):
		return
	var p : AudioStreamPlayer = _pool[_idx] as AudioStreamPlayer
	_idx = (_idx + 1) % _pool.size()
	p.stream    = _cache[key] as AudioStreamWAV
	p.volume_db = db
	p.play()

func play_dig()    -> void: _play("dig",    -4.0)
func play_place()  -> void: _play("place",  -3.0)
func play_step()   -> void: _play("step",  -10.0)
func play_hurt()   -> void: _play("hurt",    0.0)
func play_die()    -> void: _play("die",     2.0)
func play_pickup() -> void: _play("pickup", -2.0)
func play_swing()  -> void: _play("swing",  -6.0)
func play_shoot()  -> void: _play("shoot",  -3.0)
func play_animal(t: int) -> void:
	if   t == 0: _play("chicken", -4.0)
	elif t == 1: _play("cow",     -3.0)
	elif t == 4: _play("dino",     2.0)

# ── 파형 함수들 ───────────────────────────────────────
func _wave_dig(n: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t : float = float(i) / float(RATE)
		s[i] = randf_range(-1.0, 1.0) * exp(-t * 18.0) * 0.7
	return s

func _wave_place(n: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t : float = float(i) / float(RATE)
		var e : float = exp(-t * 35.0)
		s[i] = sin(TAU * (160.0 - t * 300.0) * t) * e * 0.55
	return s

func _wave_step(n: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t : float = float(i) / float(RATE)
		s[i] = (randf_range(-1.0, 1.0) * 0.35 + sin(TAU * 75.0 * t) * 0.4) * exp(-t * 45.0)
	return s

func _wave_hurt(n: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t : float = float(i) / float(RATE)
		s[i] = (sin(TAU * 300.0 * t) * 0.55 + randf_range(-0.2, 0.2)) * exp(-t * 11.0)
	return s

func _wave_die(n: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t : float = float(i) / float(RATE)
		s[i] = (sin(TAU * 58.0 * t) * 0.6 + randf_range(-0.18, 0.18)) * exp(-t * 5.5)
	return s

func _wave_pickup(n: int) -> PackedFloat32Array:
	var s     := PackedFloat32Array()
	var phase : float = 0.0
	s.resize(n)
	for i in range(n):
		var t : float = float(i) / float(RATE)
		phase += (750.0 + t * 1200.0) / float(RATE)
		s[i] = sin(TAU * phase) * exp(-t * 14.0) * 0.55
	return s

func _wave_swing(n: int) -> PackedFloat32Array:
	var s     := PackedFloat32Array()
	var phase : float = 0.0
	s.resize(n)
	for i in range(n):
		var t : float = float(i) / float(RATE)
		var e : float = (1.0 - exp(-t * 25.0)) * exp(-t * 9.0)
		phase += maxf(520.0 - t * 700.0, 60.0) / float(RATE)
		s[i] = (sin(TAU * phase) * 0.35 + randf_range(-0.12, 0.12)) * e
	return s

func _wave_chicken(n: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t  : float = float(i) / float(RATE)
		var e1 : float = exp(-t * 30.0) if t < 0.13 else 0.0
		var e2 : float = exp(-(t - 0.15) * 30.0) if t >= 0.15 else 0.0
		s[i] = sin(TAU * (880.0 + sin(TAU * 12.0 * t) * 60.0) * t) * (e1 + e2) * 0.55
	return s

func _wave_cow(n: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   : float = float(i) / float(RATE)
		var e   : float = (1.0 - exp(-t * 6.0)) * exp(-t * 3.0)
		var vib : float = sin(TAU * 4.0 * t) * 8.0
		s[i] = sin(TAU * (115.0 + vib) * t) * e * 0.6
	return s

func _wave_shoot(n: int) -> PackedFloat32Array:
	# 석궁 발사: 짧은 "퉁" + 휘파람
	var s     := PackedFloat32Array()
	var phase : float = 0.0
	s.resize(n)
	for i in range(n):
		var t   : float = float(i) / float(RATE)
		var thunk : float = exp(-t * 40.0) * randf_range(-0.5, 0.5)
		var whoosh : float = sin(TAU * phase) * exp(-t * 12.0) * 0.4
		phase += (400.0 - t * 500.0) / float(RATE)
		s[i] = thunk * 0.5 + whoosh
	return s

func _wave_dino(n: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   : float = float(i) / float(RATE)
		var e   : float = (1.0 - exp(-t * 4.0)) * exp(-t * 3.0)
		var val : float = sin(TAU * 52.0 * t) * 0.45
		val += sin(TAU * 104.0 * t) * 0.30
		val += randf_range(-0.12, 0.12)
		s[i] = val * e
	return s
