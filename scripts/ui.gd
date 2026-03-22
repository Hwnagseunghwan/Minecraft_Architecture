extends CanvasLayer

var _block_label : Label

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
	_block_label.position = Vector2(16, -52)
	_block_label.add_theme_font_size_override("font_size", 22)
	_block_label.add_theme_constant_override("outline_size", 3)
	_block_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_block_label)

	# 블록 팔레트 힌트
	var palette := Label.new()
	palette.text = "1:Grass  2:Dirt  3:Stone  4:Log  5:Plank  6:Glass  7:White  8:Red  (휠: 변경)"
	palette.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	palette.position = Vector2(16, -28)
	palette.add_theme_font_size_override("font_size", 13)
	palette.add_theme_constant_override("outline_size", 2)
	palette.add_theme_color_override("font_outline_color", Color.BLACK)
	palette.modulate = Color(0.9, 0.9, 0.9)
	add_child(palette)

	# 조작 도움말
	var help := Label.new()
	help.text = "WASD:이동  SPACE:점프  좌클릭:제거  우클릭:배치  R:초기화  ESC:커서"
	help.set_anchors_preset(Control.PRESET_TOP_LEFT)
	help.position = Vector2(10, 10)
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_constant_override("outline_size", 2)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.modulate = Color(1, 1, 1, 0.8)
	add_child(help)

func _on_block_selected(block_name: String) -> void:
	_block_label.text = "[ " + block_name + " ]"
