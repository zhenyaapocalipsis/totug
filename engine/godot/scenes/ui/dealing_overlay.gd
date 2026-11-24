extends ColorRect

const L10n := preload("res://scenes/localization.gd")
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")
var _dots: Label
var _elapsed := 0.0

func _init() -> void:
	name = "DealingOverlay"
	color = PixelTheme.BG
	theme = PixelTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UnderdarkBg.make())
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel",GameScreen.zone_style(10))
	centre.add_child(plate)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",4)
	plate.add_child(col)
	var title := Label.new()
	L10n.bind(title,"lobby.dealing_title")
	title.add_theme_font_size_override("font_size",PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color",PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_dots = Label.new()
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_dots)
	_process(0)

func _process(delta: float) -> void:
	_elapsed += delta
	var count := int(_elapsed*2.5)%4
	L10n.bind(_dots,"lobby.building_dots",{"dots":".".repeat(count)+" ".repeat(3-count)})
