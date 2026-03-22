extends CanvasLayer

const SLOT_COLORS : Array = [
	Color(0.20, 0.90, 0.15),  # Grass
	Color(0.50, 0.35, 0.20),  # Dirt
	Color(0.55, 0.55, 0.55),  # Stone
	Color(0.35, 0.22, 0.10),  # Log
	Color(0.80, 0.65, 0.40),  # Plank
	Color(0.75, 0.90, 1.00),  # Glass
	Color(0.95, 0.95, 0.95),  # White
	Color(0.80, 0.20, 0.20),  # Red
	Color(0.70, 0.30, 0.20),  # Brick
	Color(0.75, 0.75, 0.75),  # Concrete
	Color(0.55, 0.38, 0.18),  # Wood
	Color(0.28, 0.22, 0.16),  # Roof
]

const BLOCK_NAMES_UI : Array = [
	"Grass","Dirt","Stone","Log","Plank","Glass","White","Red",
	"Brick","Concrete","Wood","Roof"
]

var _block_label    : Label
var _hotbar_borders : Array[ColorRect] = []
var _inv_panel      : Control
var _inv_labels     : Dictionary = {}

const SLOT_SIZE : int = 42
const BORDER    : int = 3
const GAP       : int = 3

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

	# 선택 블록 표시
	_block_label = Label.new()
	_block_label.text = "[ Grass ]"
	_block_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_block_label.position = Vector2(16, -90)
	_block_label.add_theme_font_size_override("font_size", 20)
	_block_label.add_theme_constant_override("outline_size", 3)
	_block_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_block_label)

	# 조작 도움말
	var help := Label.new()
	help.text = "WASD:이동  SPACE:점프  좌클릭(꾹):제거  우클릭:배치  휠/1~8:블록선택  R:초기화  ESC:커서"
	help.set_anchors_preset(Control.PRESET_TOP_LEFT)
	help.position = Vector2(10, 10)
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_constant_override("outline_size", 2)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.modulate = Color(1, 1, 1, 0.8)
	add_child(help)

	# 시각적 핫바
	_build_hotbar()
	# 인벤토리 패널
	_build_inventory()

func _build_hotbar() -> void:
	var n       : int   = SLOT_COLORS.size()
	var total_w : float = n * SLOT_SIZE + (n - 1) * GAP

	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	container.position = Vector2(-total_w / 2.0, -(SLOT_SIZE + 12))
	add_child(container)

	for i in range(n):
		var x : float = i * (SLOT_SIZE + GAP)

		# 테두리 (선택 시 노란색)
		var border := ColorRect.new()
		border.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		border.position = Vector2(x, 0)
		border.color = Color(1.0, 1.0, 0.2, 1.0) if i == 0 else Color(0.2, 0.2, 0.2, 0.85)
		container.add_child(border)
		_hotbar_borders.append(border)

		# 블록 색상
		var inner := ColorRect.new()
		inner.size = Vector2(SLOT_SIZE - BORDER * 2, SLOT_SIZE - BORDER * 2)
		inner.position = Vector2(x + BORDER, BORDER)
		inner.color = SLOT_COLORS[i]
		container.add_child(inner)

		# 숫자 (1~8만 표시)
		if i < 8:
			var num := Label.new()
			num.text = str(i + 1)
			num.position = Vector2(x + 2, 2)
			num.add_theme_font_size_override("font_size", 11)
			num.add_theme_constant_override("outline_size", 2)
			num.add_theme_color_override("font_outline_color", Color.BLACK)
			num.add_theme_color_override("font_color", Color.WHITE)
			container.add_child(num)

func _build_inventory() -> void:
	_inv_panel = Control.new()
	_inv_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_inv_panel.position = Vector2(-180, 10)
	add_child(_inv_panel)

	var bg := ColorRect.new()
	bg.size = Vector2(170, 180)
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	_inv_panel.add_child(bg)

	var title := Label.new()
	title.text = "인벤토리"
	title.position = Vector2(8, 6)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1, 1, 0.4))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	_inv_panel.add_child(title)

func _on_inventory_changed(inv: Dictionary) -> void:
	# 기존 아이템 레이블 지우기
	for key in _inv_labels:
		if is_instance_valid(_inv_labels[key]):
			_inv_labels[key].queue_free()
	_inv_labels.clear()

	var y : float = 30.0
	for item_name in inv:
		var lbl := Label.new()
		lbl.text = "  " + item_name + " x" + str(inv[item_name])
		lbl.position = Vector2(4, y)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		_inv_panel.add_child(lbl)
		_inv_labels[item_name] = lbl
		y += 20.0

func _on_block_selected(idx: int, block_name: String) -> void:
	_block_label.text = "[ " + block_name + " ]"
	for i in range(_hotbar_borders.size()):
		_hotbar_borders[i].color = Color(1.0, 1.0, 0.2, 1.0) if i == idx else Color(0.2, 0.2, 0.2, 0.85)
