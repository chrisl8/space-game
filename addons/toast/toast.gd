@tool
extends Control

class_name Toast

signal done

var labelText
var toastDuration
var style

#Nodes
var label
var timer
var animation


func _init(
	text: String = "",
	duration: float = 1,
	toast_style: ToastStyle = preload("style_resource/default.tres")
):
	labelText = text
	toastDuration = duration
	if toast_style is ToastStyle:
		style = toast_style
	else:
		printerr("Expected ToastStyle resource. Using default style")


func _ready():
	#Setting itself
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	#Setting the label
	label = Label.new()

	var styleBoxParser: StyleBoxFlat = StyleBoxFlat.new()
	styleBoxParser.bg_color = style.backgroundColor
	styleBoxParser.content_margin_bottom = style.contentMarginBottom
	styleBoxParser.content_margin_left = style.contentMarginLeft
	styleBoxParser.content_margin_right = style.contentMarginRight
	styleBoxParser.content_margin_top = style.contentMarginTop
	styleBoxParser.corner_radius_bottom_left = style.cornerRadius
	styleBoxParser.corner_radius_bottom_right = style.cornerRadius
	styleBoxParser.corner_radius_top_left = style.cornerRadius
	styleBoxParser.corner_radius_top_right = style.cornerRadius
	label.add_theme_stylebox_override("normal", styleBoxParser)

	label.add_theme_color_override("font_color", style.fontColor)
	label.text = labelText
	match style.position:
		ToastStyle.Position.Bottom:
			if style.toastType == ToastStyle.Type.Float:
				label.anchor_bottom = 1.0
				label.anchor_top = 1.0
				label.anchor_left = 0.5
				label.anchor_right = 0.5
				label.offset_bottom = -60
			elif style.toastType == ToastStyle.Type.Full:
				label.anchor_bottom = 1.0
				label.anchor_top = 1.0
				label.anchor_left = 0
				label.anchor_right = 1
				label.offset_bottom = 0
			label.grow_vertical = 0
		ToastStyle.Position.Top:
			if style.toastType == ToastStyle.Type.Float:
				label.anchor_bottom = 0
				label.anchor_top = 0
				label.anchor_left = 0.5
				label.anchor_right = 0.5
				label.margin_top = 60
			elif style.toastType == ToastStyle.Type.Full:
				label.anchor_bottom = 0
				label.anchor_top = 0
				label.anchor_left = 0
				label.anchor_right = 1
				label.margin_top = 0
			label.grow_vertical = 1
	label.grow_horizontal = 2
	label.horizontal_alignment = 1
	add_child(label)

	#Setting the animation
	animation = AnimationPlayer.new()
	var toast_animations: AnimationLibrary = AnimationLibrary.new()
	toast_animations.add_animation("start", load("res://addons/toast/animations/start.anim"))
	toast_animations.add_animation("end", load("res://addons/toast/animations/end.anim"))
	animation.add_animation_library("toast_animations", toast_animations)
	add_child(animation)


func show():
	animation.play("toast_animations/start")
	animation.animation_finished.connect(_animationEnded)
	visible = true


func _animationEnded(whichAnimation):
	#Helpers.log_print(str("_animationEnded ", whichAnimation))
	if whichAnimation == "toast_animations/start":
		await get_tree().create_timer(toastDuration).timeout
		animation.play("toast_animations/end")
	elif whichAnimation == "endAnimation":
		animation.play("toast_animations/end")
		animation.disconnect("animation_finished", self, "_animationEnded")
		animation.connect("animation_finished", self, "_done")


func _done(_a):
	animation.remove_animation("start")
	queue_free()
	emit_signal("done")
