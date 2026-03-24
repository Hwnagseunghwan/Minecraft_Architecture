extends Node
## 절차적 음향 생성 — AudioStreamWAV + PCM 샘플 (파일 없음)

const MIX_RATE   := 22050
const MAX_VOICES := 8        # 동시 재생 가능 채널 수

var _voices : Array[AudioStreamPlayer] = []
var _vi     : int = 0        # 라운드-로빈 인덱스
var _sfx    : Dictionary = {}

func _ready() -> void:
	for _i in range(MAX_VOICES):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_bake_all()


# ── WAV 변환 ──────────────────────────────────────────
func _bake(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format   = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo   = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data[i * 2]     = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	stream.data = data
	return stream

func _secs(s: float) -> int:
	return int(MIX_RATE * s)


# ── 사전 생성 ─────────────────────────────────────────
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


# ── 재생 ─────────────────────────────────────────────
func _play(key: String, vol: float = 0.0) -> void:
	if not _sfx.has(key):
		return
	var p : AudioStreamPlayer = _voices[_vi]
	_vi = (_vi + 1) % MAX_VOICES
	p.stream    = _sfx[key]
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


# ── 파형 생성 ─────────────────────────────────────────

func _gen_dig() -> PackedFloat32Array:
	# 블록 파괴: 0.22초 노이즈 버스트 (흙/돌 부서지는 소리)
	var n := _secs(0.22)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   := float(i) / MIX_RATE
		var env := exp(-t * 18.0)
		s[i] = randf_range(-1.0, 1.0) * env * 0.70 + sin(TAU * 90.0 * t) * env * 0.20
	return s

func _gen_place() -> PackedFloat32Array:
	# 블록 배치: 0.12초 둔탁한 클릭 (주파수 하강)
	var n := _secs(0.12)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   := float(i) / MIX_RATE
		var env := exp(-t * 35.0)
		var f   := 160.0 - t * 300.0
		s[i] = sin(TAU * f * t) * env * 0.55 + randf_range(-0.15, 0.15) * env
	return s

func _gen_step() -> PackedFloat32Array:
	# 발걸음: 0.09초 저음 탁
	var n := _secs(0.09)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   := float(i) / MIX_RATE
		var env := exp(-t * 45.0)
		s[i] = (randf_range(-1.0, 1.0) * 0.35 + sin(TAU * 75.0 * t) * 0.40) * env
	return s

func _gen_hurt() -> PackedFloat32Array:
	# 피격: 0.3초 날카로운 충격음
	var n := _secs(0.30)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   := float(i) / MIX_RATE
		var env := exp(-t * 11.0)
		s[i] = (sin(TAU * 300.0 * t) * 0.55 + sin(TAU * 620.0 * t) * 0.25 + randf_range(-0.20, 0.20)) * env
	return s

func _gen_die() -> PackedFloat32Array:
	# 사망: 0.6초 낮고 무거운 충격
	var n := _secs(0.60)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   := float(i) / MIX_RATE
		var env := exp(-t * 5.5)
		s[i] = (sin(TAU * 58.0 * t) * 0.60 + sin(TAU * 116.0 * t) * 0.25 + randf_range(-0.18, 0.18)) * env
	return s

func _gen_pickup() -> PackedFloat32Array:
	# 아이템 줍기: 0.2초 밝은 핑 (주파수 상승)
	var n     := _secs(0.20)
	var s     := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in range(n):
		var t   := float(i) / MIX_RATE
		var env := exp(-t * 14.0)
		var f   := 750.0 + t * 1200.0
		phase  += f / MIX_RATE
		s[i] = sin(TAU * phase) * env * 0.55
	return s

func _gen_swing() -> PackedFloat32Array:
	# 공격 스윙: 0.22초 휘— 소리 (주파수 하강)
	var n     := _secs(0.22)
	var s     := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in range(n):
		var t   := float(i) / MIX_RATE
		var env := (1.0 - exp(-t * 25.0)) * exp(-t * 9.0)
		var f   := maxf(520.0 - t * 700.0, 60.0)
		phase  += f / MIX_RATE
		s[i] = (sin(TAU * phase) * 0.35 + randf_range(-0.12, 0.12)) * env
	return s

func _gen_chicken() -> PackedFloat32Array:
	# 닭: 0.28초 높은 "깩깩" 2번 발성
	var n := _secs(0.28)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t    := float(i) / MIX_RATE
		var env1 := exp(-t * 30.0) if t < 0.13 else 0.0
		var env2 := exp(-(t - 0.15) * 30.0) if t >= 0.15 else 0.0
		var env  := env1 + env2
		var vib  := sin(TAU * 12.0 * t) * 60.0
		s[i] = sin(TAU * (880.0 + vib) * t) * env * 0.55
	return s

func _gen_cow() -> PackedFloat32Array:
	# 소: 0.55초 낮은 "음-" 소리 + 비브라토
	var n := _secs(0.55)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   := float(i) / MIX_RATE
		var env := (1.0 - exp(-t * 6.0)) * exp(-t * 3.0)
		var vib := sin(TAU * 4.0 * t) * 8.0
		s[i] = (sin(TAU * (115.0 + vib) * t) * 0.60 + sin(TAU * (230.0 + vib) * t) * 0.25) * env
	return s

func _gen_dino() -> PackedFloat32Array:
	# 공룡: 0.65초 저음 으르렁
	var n := _secs(0.65)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t   := float(i) / MIX_RATE
		var env := (1.0 - exp(-t * 4.0)) * exp(-t * 3.0)
		s[i] = (sin(TAU * 52.0  * t) * 0.45
			  + sin(TAU * 104.0 * t) * 0.30
			  + sin(TAU * 78.0  * t) * 0.15
			  + randf_range(-0.12, 0.12)) * env
	return s
