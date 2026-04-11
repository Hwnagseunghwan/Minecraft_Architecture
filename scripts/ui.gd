extends CanvasLayer

const ITEM_NAMES_KR : Dictionary = {
	"Feather":      "깃털",
	"ChickenMeat":  "닭고기",
	"Leather":      "가죽",
	"BeefMeat":     "소고기",
	"RawFish":      "생선",
	"Egg":          "달걀",
	"DinosaurClaw": "공룡발톱",
	"Grass":        "잔디",
	"Dirt":         "흙",
	"Stone":        "돌",
	"Log":          "원목",
	"Plank":        "판자",
	"Glass":        "유리",
	"White":        "흰블록",
	"Red":          "빨간블록",
	"Brick":        "벽돌",
	"Concrete":     "콘크리트",
	"Wood":         "나무",
	"Roof":         "지붕",
	"Sand":         "모래",
	"Cactus":       "선인장",
}

const HOTBAR_SLOTS : int = 9
const MAX_HP       : int = 20
const SLOT_SIZE    : int = 52
const BORDER       : int = 3
const GAP          : int = 4

var _block_label     : Label

var _slot_borders  : Array[ColorRect]   = []
var _slot_inners   : Array[ColorRect]   = []
var _slot_icons    : Array[TextureRect] = []
var _slot_names    : Array[Label]       = []
var _slot_counts   : Array[Label]       = []

var _hotbar_items  : Array[String] = []
var _item_icons    : Dictionary    = {}

var _block_panel          : Control
var _block_selector_label : Label

func _ready() -> void:
	_build_item_icons()
	_build()

# ── 아이콘 픽셀 드로잉 ────────────────────────────────────
func _r(img: Image, x:int, y:int, w:int, h:int, c:Color) -> void:
	if w > 0 and h > 0:
		img.fill_rect(Rect2i(x, y, w, h), c)

func _make_icon(item_name: String) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match item_name:
		"Feather":      _icon_feather(img)
		"ChickenMeat":  _icon_chicken_meat(img)
		"Leather":      _icon_leather(img)
		"BeefMeat":     _icon_beef_meat(img)
		"RawFish":      _icon_raw_fish(img)
		"Egg":          _icon_egg(img)
		"DinosaurClaw": _icon_dino_claw(img)
	return ImageTexture.create_from_image(img)

func _build_item_icons() -> void:
	for k in ITEM_NAMES_KR.keys():
		_item_icons[k] = _make_icon(k)

# 깃털: 중앙 깃대 + 좌우 대칭 깃
func _icon_feather(img: Image) -> void:
	var s := Color(0.88, 0.86, 0.82)
	var b := Color(0.96, 0.94, 0.90)
	_r(img, 15,  2,  2, 26, s)
	_r(img, 12,  4,  8,  2, b)
	_r(img, 10,  7, 12,  2, b)
	_r(img,  9, 10, 14,  2, b)
	_r(img,  9, 13, 14,  2, b)
	_r(img, 10, 16, 12,  2, b)
	_r(img, 11, 19, 10,  2, b)
	_r(img, 13, 22,  6,  2, b)
	_r(img, 14, 25,  4,  2, b)

# 닭고기: 고기 덩어리 + 위아래 뼈
func _icon_chicken_meat(img: Image) -> void:
	var meat := Color(0.85, 0.40, 0.28)
	var dark := Color(0.66, 0.26, 0.16)
	var bone := Color(0.93, 0.91, 0.87)
	_r(img, 10,  2, 12,  2, bone)   # 뼈 위 마디
	_r(img, 14,  3,  4,  5, bone)   # 뼈 위 기둥
	_r(img,  6,  8, 20, 15, meat)   # 고기 몸체
	_r(img,  6,  8,  3, 15, dark)   # 좌측 그림자
	_r(img,  6, 22, 20,  2, dark)   # 하단 그림자
	_r(img, 14, 23,  4,  4, bone)   # 뼈 아래 기둥
	_r(img, 10, 26, 12,  2, bone)   # 뼈 아래 마디

# 가죽: 납작한 패치 + 주름선 + 좌측 접힌 면
func _icon_leather(img: Image) -> void:
	var base := Color(0.55, 0.35, 0.18)
	var dark := Color(0.38, 0.24, 0.12)
	var line := Color(0.30, 0.18, 0.08)
	var high := Color(0.68, 0.46, 0.25)
	_r(img,  4,  7, 24, 18, base)
	_r(img,  4,  7, 24,  1, high)
	_r(img,  4,  7,  4, 18, dark)
	_r(img,  4, 11, 24,  1, line)
	_r(img,  4, 15, 24,  1, line)
	_r(img,  4, 19, 24,  1, line)

# 소고기: 두꺼운 스테이크 + 지방 마블링
func _icon_beef_meat(img: Image) -> void:
	var red  := Color(0.82, 0.28, 0.22)
	var dark := Color(0.60, 0.16, 0.12)
	var fat  := Color(0.93, 0.87, 0.83)
	var fat2 := Color(0.86, 0.78, 0.73)
	_r(img,  4,  5, 24, 22, red)
	_r(img,  4,  5, 24,  4, fat)
	_r(img,  5, 13, 22,  2, fat2)
	_r(img,  7, 18, 18,  2, fat2)
	_r(img,  4,  5,  2, 22, dark)
	_r(img,  4, 25, 24,  2, dark)

# 생선: 몸통 + 꼬리 + 머리 + 등지느러미 + 눈
func _icon_raw_fish(img: Image) -> void:
	var body  := Color(1.00, 0.52, 0.12)
	var belly := Color(1.00, 0.76, 0.44)
	var dark  := Color(0.78, 0.34, 0.05)
	var eye   := Color(0.05, 0.04, 0.04)
	_r(img,  2,  7,  6,  5, body)   # 꼬리 위
	_r(img,  2, 20,  6,  5, body)   # 꼬리 아래
	_r(img,  5, 10, 20, 12, body)   # 몸통
	_r(img,  7, 16, 14,  5, belly)  # 배
	_r(img, 23,  9,  5, 14, dark)   # 머리
	_r(img,  9,  7, 10,  4, dark)   # 등지느러미
	_r(img, 24, 12,  3,  3, eye)    # 눈

# 달걀: 타원형 (가로 밴드 쌓기)
func _icon_egg(img: Image) -> void:
	var c  := Color(0.96, 0.92, 0.78)
	var sh := Color(0.82, 0.78, 0.64)
	_r(img, 13,  3,  6,  2, c)
	_r(img, 11,  5, 10,  2, c)
	_r(img,  9,  7, 14,  2, c)
	_r(img,  8,  9, 16,  2, c)
	_r(img,  7, 11, 18,  2, c)
	_r(img,  7, 13, 18,  2, c)
	_r(img,  7, 15, 18,  2, c)
	_r(img,  8, 17, 16,  2, c)
	_r(img,  9, 19, 14,  2, c)
	_r(img, 10, 21, 12,  2, c)
	_r(img, 12, 23,  8,  2, c)
	_r(img, 13, 25,  6,  2, c)
	_r(img, 20,  9,  4,  2, sh)     # 우측 음영
	_r(img, 21, 11,  4,  6, sh)
	_r(img, 20, 17,  4,  2, sh)

# 공룡발톱: 뿌리(아래 넓음) → 끝(위 오른쪽 뾰족)
func _icon_dino_claw(img: Image) -> void:
	var c1 := Color(0.55, 0.55, 0.20)
	var c2 := Color(0.48, 0.48, 0.16)
	var c3 := Color(0.40, 0.40, 0.12)
	_r(img,  6, 23, 16,  5, c1)    # 뿌리 (가장 넓음)
	_r(img,  8, 17, 12,  7, c1)    # 하단 몸체
	_r(img, 11, 11,  9,  7, c2)    # 중간 (오른쪽으로 커브)
	_r(img, 14,  6,  7,  6, c2)    # 상단 몸체
	_r(img, 17,  2,  6,  5, c3)    # 끝 부분
	_r(img, 20,  2,  4,  3, c3)    # 뾰족한 끝

# ── UI 빌드 ───────────────────────────────────────────────
func _build() -> void:
	# 크로스헤어
	var ch := ColorRect.new()
	ch.size = Vector2(20, 2)
	ch.color = Color(1, 1, 1, 0.9)
	ch.set_anchors_preset(Control.PRESET_CENTER)
	ch.position = Vector2(-10, -1)
	add_child(ch)

	var cv := ColorRect.new()
	cv.size = Vector2(2, 20)
	cv.color = Color(1, 1, 1, 0.9)
	cv.set_anchors_preset(Control.PRESET_CENTER)
	cv.position = Vector2(-1, -10)
	add_child(cv)

	# 조작 도움말
	var help := Label.new()
	help.text = "WASD:이동  SPACE:점프  좌클릭(꾹):채굴→아이템드롭  우클릭:설치(인벤토리소모)  F:전투모드  휠/1~8:블록선택  R:초기화  ESC:커서"
	help.set_anchors_preset(Control.PRESET_TOP_LEFT)
	help.position = Vector2(10, 10)
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_constant_override("outline_size", 2)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.modulate = Color(1, 1, 1, 0.8)
	add_child(help)

	_build_mode_indicator()
	_build_block_panel()
	_build_hotbar()
	_build_hearts()
	_build_damage_flash()
	_build_death_overlay()

func _build_block_panel() -> void:
	_block_panel = Control.new()
	_block_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_block_panel.position = Vector2(10, -(SLOT_SIZE + 70))
	add_child(_block_panel)

	var bg := ColorRect.new()
	bg.size = Vector2(160, 44)
	bg.color = Color(0.0, 0.0, 0.0, 0.60)
	_block_panel.add_child(bg)

	var title := Label.new()
	title.text = "블록"
	title.position = Vector2(8, 4)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	_block_panel.add_child(title)

	_block_selector_label = Label.new()
	_block_selector_label.text = "[ Grass ]"
	_block_selector_label.position = Vector2(8, 22)
	_block_selector_label.add_theme_font_size_override("font_size", 15)
	_block_selector_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
	_block_selector_label.add_theme_constant_override("outline_size", 2)
	_block_selector_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_block_panel.add_child(_block_selector_label)

func _build_hotbar() -> void:
	var total_w : float = HOTBAR_SLOTS * SLOT_SIZE + (HOTBAR_SLOTS - 1) * GAP

	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	container.position = Vector2(-total_w / 2.0, -(SLOT_SIZE + 12))
	add_child(container)

	for i in range(HOTBAR_SLOTS):
		var x : float = i * (SLOT_SIZE + GAP)

		# 슬롯 테두리
		var border := ColorRect.new()
		border.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		border.position = Vector2(x, 0)
		border.color = Color(0.25, 0.25, 0.25, 0.85)
		container.add_child(border)
		_slot_borders.append(border)

		# 슬롯 내부 배경
		var inner := ColorRect.new()
		inner.size = Vector2(SLOT_SIZE - BORDER * 2, SLOT_SIZE - BORDER * 2)
		inner.position = Vector2(x + BORDER, BORDER)
		inner.color = Color(0.10, 0.10, 0.10, 0.7)
		container.add_child(inner)
		_slot_inners.append(inner)

		# 아이템 아이콘
		var icon_rect := TextureRect.new()
		icon_rect.size = Vector2(26, 26)
		icon_rect.position = Vector2(x + 13, 5)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_SCALE
		container.add_child(icon_rect)
		_slot_icons.append(icon_rect)

		# 아이템 이름 (슬롯 하단)
		var name_lbl := Label.new()
		name_lbl.text = ""
		name_lbl.position = Vector2(x + 2, 33)
		name_lbl.size = Vector2(SLOT_SIZE - 4, 14)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		name_lbl.add_theme_constant_override("outline_size", 2)
		name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		container.add_child(name_lbl)
		_slot_names.append(name_lbl)

		# 수량 (우하단)
		var cnt_lbl := Label.new()
		cnt_lbl.text = ""
		cnt_lbl.position = Vector2(x + SLOT_SIZE - 16, SLOT_SIZE - 16)
		cnt_lbl.add_theme_font_size_override("font_size", 11)
		cnt_lbl.add_theme_color_override("font_color", Color.WHITE)
		cnt_lbl.add_theme_constant_override("outline_size", 2)
		cnt_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		container.add_child(cnt_lbl)
		_slot_counts.append(cnt_lbl)

func _refresh_hotbar(inv: Dictionary) -> void:
	for iname in inv:
		if not _hotbar_items.has(iname):
			_hotbar_items.append(iname)
	var to_remove : Array = []
	for iname in _hotbar_items:
		if not inv.has(iname) or inv[iname] <= 0:
			to_remove.append(iname)
	for iname in to_remove:
		_hotbar_items.erase(iname)

	for i in range(HOTBAR_SLOTS):
		if i < _hotbar_items.size():
			var iname : String = _hotbar_items[i]
			var cnt   : int    = inv.get(iname, 0)
			_slot_inners[i].color       = Color(0.14, 0.12, 0.10, 0.85)
			_slot_icons[i].texture      = _item_icons.get(iname, null)
			_slot_names[i].text         = ITEM_NAMES_KR.get(iname, iname)
			_slot_counts[i].text        = str(cnt)
			_slot_borders[i].color      = Color(0.60, 0.55, 0.50, 1.0)
		else:
			_slot_inners[i].color  = Color(0.10, 0.10, 0.10, 0.7)
			_slot_icons[i].texture = null
			_slot_names[i].text    = ""
			_slot_counts[i].text   = ""
			_slot_borders[i].color = Color(0.25, 0.25, 0.25, 0.85)

func _on_inventory_changed(inv: Dictionary) -> void:
	_refresh_hotbar(inv)

# ── 체력 ───────────────────────────────────────────────
var _heart_left    : Array[ColorRect] = []
var _heart_right   : Array[ColorRect] = []
var _damage_flash  : ColorRect
var _death_overlay : Control

const HEART_FULL  : Color = Color(0.90, 0.10, 0.10)
const HEART_EMPTY : Color = Color(0.25, 0.25, 0.25)

func _build_hearts() -> void:
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	container.position = Vector2(10, -(SLOT_SIZE + 115))
	add_child(container)

	for i in range(10):
		var ox : float = i * 24.0
		var border := ColorRect.new()
		border.size     = Vector2(20, 20)
		border.position = Vector2(ox, 0)
		border.color    = Color(0.0, 0.0, 0.0, 0.7)
		container.add_child(border)
		var left := ColorRect.new()
		left.size     = Vector2(8, 16)
		left.position = Vector2(ox + 2, 2)
		left.color    = HEART_FULL
		container.add_child(left)
		_heart_left.append(left)
		var right := ColorRect.new()
		right.size     = Vector2(8, 16)
		right.position = Vector2(ox + 10, 2)
		right.color    = HEART_FULL
		container.add_child(right)
		_heart_right.append(right)

func _build_damage_flash() -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color   = Color(0.85, 0.05, 0.05, 0.0)
	_damage_flash.visible = true
	add_child(_damage_flash)

func _build_death_overlay() -> void:
	_death_overlay = Control.new()
	_death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.visible = false
	add_child(_death_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	_death_overlay.add_child(bg)

	var died_lbl := Label.new()
	died_lbl.text = "사망"
	died_lbl.set_anchors_preset(Control.PRESET_CENTER)
	died_lbl.position = Vector2(-55, -50)
	died_lbl.add_theme_font_size_override("font_size", 64)
	died_lbl.add_theme_color_override("font_color", Color(0.90, 0.10, 0.10))
	died_lbl.add_theme_constant_override("outline_size", 4)
	died_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_death_overlay.add_child(died_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "3초 후 부활..."
	sub_lbl.set_anchors_preset(Control.PRESET_CENTER)
	sub_lbl.position = Vector2(-75, 20)
	sub_lbl.add_theme_font_size_override("font_size", 22)
	sub_lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
	sub_lbl.add_theme_constant_override("outline_size", 2)
	sub_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_death_overlay.add_child(sub_lbl)

func _on_hp_changed(current_hp: int, _max_hp: int) -> void:
	for i in range(10):
		_heart_left[i].color  = HEART_FULL if current_hp >= i * 2 + 1 else HEART_EMPTY
		_heart_right[i].color = HEART_FULL if current_hp >= i * 2 + 2 else HEART_EMPTY
	if current_hp < MAX_HP:
		_damage_flash.color = Color(0.85, 0.05, 0.05, 0.40)
		var tw := create_tween()
		tw.tween_property(_damage_flash, "color", Color(0.85, 0.05, 0.05, 0.0), 0.5)

func _on_hp_healed(_current_hp: int, _max_hp: int) -> void:
	_damage_flash.color = Color(1.0, 0.95, 0.0, 0.30)
	var tw := create_tween()
	tw.tween_property(_damage_flash, "color", Color(1.0, 0.95, 0.0, 0.0), 0.5)

func _on_player_died() -> void:
	_death_overlay.visible = true

func _on_player_respawned() -> void:
	_death_overlay.visible = false
	for i in range(10):
		_heart_left[i].color  = HEART_FULL
		_heart_right[i].color = HEART_FULL

# ── 모드 표시 ──────────────────────────────────────────
var _mode_label : Label

func _build_mode_indicator() -> void:
	_mode_label = Label.new()
	_mode_label.text = "[ 건축 모드 ]  F키: 전환"
	_mode_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mode_label.position = Vector2(-220, 10)
	_mode_label.add_theme_font_size_override("font_size", 16)
	_mode_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	_mode_label.add_theme_constant_override("outline_size", 3)
	_mode_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_mode_label)

func _on_mode_changed(mode: int) -> void:
	match mode:
		0:
			_mode_label.text = "[ 건축 모드 ]  F키: 전환"
			_mode_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		1:
			_mode_label.text = "[ 전투-몽둥이 ]  F키: 전환"
			_mode_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		2:
			_mode_label.text = "[ 전투-석궁 ]  우클릭:발사  F키: 전환"
			_mode_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.20))
		3:
			_mode_label.text = "[ 포탈 지팩이 ]  우클릭:포탈 생성  F키: 전환"
			_mode_label.add_theme_color_override("font_color", Color(0.80, 0.30, 1.00))

func _on_block_selected(_idx: int, block_name: String) -> void:
	_block_selector_label.text = "[ " + block_name + " ]"
