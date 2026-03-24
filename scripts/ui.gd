extends CanvasLayer

# 아이템 색상 (전리품 이름 → 색상)
const ITEM_COLORS : Dictionary = {
	"Feather":    Color(0.95, 0.93, 0.88),
	"ChickenMeat":Color(0.85, 0.45, 0.35),
	"Leather":    Color(0.55, 0.35, 0.18),
	"BeefMeat":   Color(0.80, 0.30, 0.25),
	"RawFish":    Color(1.00, 0.50, 0.10),
	"Egg":           Color(0.96, 0.92, 0.78),
	"DinosaurClaw":  Color(0.55, 0.55, 0.20),
}

const HOTBAR_SLOTS : int = 9
const MAX_HP       : int = 20  # HP 2 = 하트 1개 (반쪽 하트 지원)
const SLOT_SIZE    : int = 48
const BORDER       : int = 3
const GAP          : int = 4

var _block_label     : Label

# 핫바 슬롯 노드 목록
var _slot_borders  : Array[ColorRect] = []
var _slot_inners   : Array[ColorRect] = []
var _slot_names    : Array[Label]     = []
var _slot_counts   : Array[Label]     = []

# 현재 핫바 아이템 (순서 유지 배열: [item_name, ...])
var _hotbar_items  : Array[String]    = []

# 블록 선택 미니 패널
var _block_panel   : Control
var _block_selector_label : Label

func _ready() -> void:
	_build()

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
	help.text = "WASD:이동  SPACE:점프  좌클릭(꾹):블록제거  우클릭:블록배치/공격  휠/1~8:블록선택  R:초기화  ESC:커서"
	help.set_anchors_preset(Control.PRESET_TOP_LEFT)
	help.position = Vector2(10, 10)
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_constant_override("outline_size", 2)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.modulate = Color(1, 1, 1, 0.8)
	add_child(help)

	# 모드 표시 (우상단)
	_build_mode_indicator()

	# 블록 선택 미니 패널 (좌하단)
	_build_block_panel()

	# 핫바 (아이템 슬롯, 하단 중앙)
	_build_hotbar()

	# 체력 하트
	_build_hearts()
	# 피격 플래시
	_build_damage_flash()
	# 사망 오버레이 (맨 위에 올라오도록 마지막에)
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

		# 슬롯 내부 (빈 슬롯 = 어두운 색)
		var inner := ColorRect.new()
		inner.size = Vector2(SLOT_SIZE - BORDER * 2, SLOT_SIZE - BORDER * 2)
		inner.position = Vector2(x + BORDER, BORDER)
		inner.color = Color(0.10, 0.10, 0.10, 0.7)
		container.add_child(inner)
		_slot_inners.append(inner)

		# 아이템 이름 (2줄로 줄임)
		var name_lbl := Label.new()
		name_lbl.text = ""
		name_lbl.position = Vector2(x + 3, BORDER + 4)
		name_lbl.size = Vector2(SLOT_SIZE - 6, SLOT_SIZE - 20)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		name_lbl.add_theme_constant_override("outline_size", 2)
		name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		container.add_child(name_lbl)
		_slot_names.append(name_lbl)

		# 아이템 수량 (우하단)
		var cnt_lbl := Label.new()
		cnt_lbl.text = ""
		cnt_lbl.position = Vector2(x + SLOT_SIZE - 18, SLOT_SIZE - 18)
		cnt_lbl.add_theme_font_size_override("font_size", 12)
		cnt_lbl.add_theme_color_override("font_color", Color.WHITE)
		cnt_lbl.add_theme_constant_override("outline_size", 2)
		cnt_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		container.add_child(cnt_lbl)
		_slot_counts.append(cnt_lbl)

func _refresh_hotbar(inv: Dictionary) -> void:
	# _hotbar_items 순서 유지하며 신규 아이템 추가
	for iname in inv:
		if not _hotbar_items.has(iname):
			_hotbar_items.append(iname)
	# 수량 0이 된 아이템 제거
	var to_remove : Array = []
	for iname in _hotbar_items:
		if not inv.has(iname) or inv[iname] <= 0:
			to_remove.append(iname)
	for iname in to_remove:
		_hotbar_items.erase(iname)

	# 슬롯 갱신
	for i in range(HOTBAR_SLOTS):
		if i < _hotbar_items.size():
			var iname : String = _hotbar_items[i]
			var cnt   : int    = inv.get(iname, 0)
			var col   : Color  = ITEM_COLORS.get(iname, Color(0.7, 0.7, 0.7))
			_slot_inners[i].color  = col
			_slot_names[i].text    = iname
			_slot_counts[i].text   = str(cnt)
			_slot_borders[i].color = Color(0.55, 0.55, 0.55, 1.0)
		else:
			# 빈 슬롯
			_slot_inners[i].color  = Color(0.10, 0.10, 0.10, 0.7)
			_slot_names[i].text    = ""
			_slot_counts[i].text   = ""
			_slot_borders[i].color = Color(0.25, 0.25, 0.25, 0.85)

func _on_inventory_changed(inv: Dictionary) -> void:
	_refresh_hotbar(inv)

# ── 체력 ───────────────────────────────────────────────
# 하트 1개 = HP 2  /  반쪽 하트 = HP 1
var _heart_left  : Array[ColorRect] = []   # 왼쪽 반 (HP 홀수 = 반칸)
var _heart_right : Array[ColorRect] = []   # 오른쪽 반
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
		# 테두리
		var border := ColorRect.new()
		border.size     = Vector2(20, 20)
		border.position = Vector2(ox, 0)
		border.color    = Color(0.0, 0.0, 0.0, 0.7)
		container.add_child(border)
		# 왼쪽 반 하트
		var left := ColorRect.new()
		left.size     = Vector2(8, 16)
		left.position = Vector2(ox + 2, 2)
		left.color    = HEART_FULL
		container.add_child(left)
		_heart_left.append(left)
		# 오른쪽 반 하트
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
	# 하트 i: 왼쪽 = HP >= i*2+1, 오른쪽 = HP >= i*2+2
	for i in range(10):
		_heart_left[i].color  = HEART_FULL if current_hp >= i * 2 + 1 else HEART_EMPTY
		_heart_right[i].color = HEART_FULL if current_hp >= i * 2 + 2 else HEART_EMPTY
	# 피격 플래시
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
