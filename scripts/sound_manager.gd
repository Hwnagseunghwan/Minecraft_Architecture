extends Node

const MIX_RATE   : int = 22050
const MAX_VOICES : int = 8

var _voices : Array = []
var _vi     : int   = 0
var _sfx    : Dictionary = {}

func _ready() -> void:
	for _i in range(MAX_VOICES):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_bake_all()


func _bake(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format   = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo   = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v : int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data[i * 2]     = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	stream.data = data
	return stream

func _n(sec: float) -> int:
	return int(MIX_RATE * sec)


func _bake_all() -> void:
	_sfx["dig"]     = _bake(_gen_dig())
	_sfx["place"]   = _bake(_gen_place())
	_sfx["step"]    = _bake(_gen_step())
	_sfx["hurt"]    = _bake(_gen_hurt())
	_sfx["die"]     = _bake(_gen_die())
	_sfx["pickup"]  = _bake(_gen_pickup())
	_sfx["swing"]   = _bake(_gen_swing())
	_sfx["chicken"] = _bake(_gen_chicken())
	_sfx["cow"]     = _bake(_gen_cow())
	_sfx["dino"]    = _bake(_gen_dino())


func _play(key: String, vol: float) -> void:
	if not _sfx.has(key):
		return
	var p : AudioStreamPlayer = _voices[_vi] as AudioStreamPlayer
	_vi = (_vi + 1) % MAX_VOICES
	p.stream    = _sfx[key] as AudioStreamWAV
	p.volume_db = vol
	p.play()

func play_dig()    -> void: _play("dig",    -4.0)
func play_place()  -> void: _play("place",  -3.0)
func play_step()   -> void: _play("step",  -10.0)
func play_hurt()   -> void: _play("hurt",    0.0)
func play_die()    -> void: _play("die",     2.0)
func play_pickup() -> void: _play("pickup", -2.0)
func play_swing()  -> void: _play("swing",  -6.0)

func play_animal(type: int) -> void:
	match type:
		0: _play("chicken", -4.0)
		1: _play("cow",     -3.0)
		4: _play("dino",     2.0)


func _gen_dig() -> PackedFloat32Array:
	var n : int = _n(0.22)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   : float = float(i) / float(MIX_RATE)
		var env : float = exp(-t * 18.0)
		s[i] = randf_range(-1.0, 1.0) * env * 0.70 + sin(TAU * 90.0 * t) * env * 0.20
	return s

func _gen_place() -> PackedFloat32Array:
	var n : int = _n(0.12)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   : float = float(i) / float(MIX_RATE)
		var env : float = exp(-t * 35.0)
		var f   : float = 160.0 - t * 300.0
		s[i] = sin(TAU * f * t) * env * 0.55 + randf_range(-0.15, 0.15) * env
	return s

func _gen_step() -> PackedFloat32Array:
	var n : int = _n(0.09)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   : float = float(i) / float(MIX_RATE)
		var env : float = exp(-t * 45.0)
		s[i] = (randf_range(-1.0, 1.0) * 0.35 + sin(TAU * 75.0 * t) * 0.40) * env
	return s

func _gen_hurt() -> PackedFloat32Array:
	var n : int = _n(0.30)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   : float = float(i) / float(MIX_RATE)
		var env : float = exp(-t * 11.0)
		s[i] = (sin(TAU * 300.0 * t) * 0.55 + sin(TAU * 620.0 * t) * 0.25 + randf_range(-0.20, 0.20)) * env
	return s

func _gen_die() -> PackedFloat32Array:
	var n : int = _n(0.60)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   : float = float(i) / float(MIX_RATE)
		var env : float = exp(-t * 5.5)
		s[i] = (sin(TAU * 58.0 * t) * 0.60 + sin(TAU * 116.0 * t) * 0.25 + randf_range(-0.18, 0.18)) * env
	return s

func _gen_pickup() -> PackedFloat32Array:
	var n     : int   = _n(0.20)
	var s     := PackedFloat32Array()
	var phase : float = 0.0
	s.resize(n)
	for i in range(n):
		var t   : float = float(i) / float(MIX_RATE)
		var env : float = exp(-t * 14.0)
		var f   : float = 750.0 + t * 1200.0
		phase += f / float(MIX_RATE)
		s[i] = sin(TAU * phase) * env * 0.55
	return s

func _gen_swing() -> PackedFloat32Array:
	var n     : int   = _n(0.22)
	var s     := PackedFloat32Array()
	var phase : float = 0.0
	s.resize(n)
	for i in range(n):
		var t   : float = float(i) / float(MIX_RATE)
		var env : float = (1.0 - exp(-t * 25.0)) * exp(-t * 9.0)
		var f   : float = maxf(520.0 - t * 700.0, 60.0)
		phase += f / float(MIX_RATE)
		s[i] = (sin(TAU * phase) * 0.35 + randf_range(-0.12, 0.12)) * env
	return s

func _gen_chicken() -> PackedFloat32Array:
	var n : int = _n(0.28)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t    : float = float(i) / float(MIX_RATE)
		var env1 : float = exp(-t * 30.0) if t < 0.13 else 0.0
		var env2 : float = exp(-(t - 0.15) * 30.0) if t >= 0.15 else 0.0
		var env  : float = env1 + env2
		var vib  : float = sin(TAU * 12.0 * t) * 60.0
		s[i] = sin(TAU * (880.0 + vib) * t) * env * 0.55
	return s

func _gen_cow() -> PackedFloat32Array:
	var n : int = _n(0.55)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   : float = float(i) / float(MIX_RATE)
		var env : float = (1.0 - exp(-t * 6.0)) * exp(-t * 3.0)
		var vib : float = sin(TAU * 4.0 * t) * 8.0
		s[i] = (sin(TAU * (115.0 + vib) * t) * 0.60 + sin(TAU * (230.0 + vib) * t) * 0.25) * env
	return s

func _gen_dino() -> PackedFloat32Array:
	var n : int = _n(0.65)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   : float = float(i) / float(MIX_RATE)
		var env : float = (1.0 - exp(-t * 4.0)) * exp(-t * 3.0)
		var val : float = sin(TAU * 52.0 * t) * 0.45 + sin(TAU * 104.0 * t) * 0.30
		val += sin(TAU * 78.0 * t) * 0.15 + randf_range(-0.12, 0.12)
		s[i] = val * env
	return s
