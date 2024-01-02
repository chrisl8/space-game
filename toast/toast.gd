# Original code from
# https://github.com/rares45/godot-toasts

@tool
class_name Toast

extends Control

signal done

var label_text: String
var toast_duration: float
var style: ToastStyle

#Nodes
var label: Label
var animation: AnimationPlayer


func _init(
	text: String = "",
	duration: float = 1,
	toast_style: ToastStyle = preload("style_resource/default.tres")
) -> void:
	label_text = text
	toast_duration = duration
	if toast_style is ToastStyle:
		style = toast_style
	else:
		printerr("Expected ToastStyle resource. Using default style")


func _ready() -> void:
	#Setting itself
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	#Setting the label
	label = Label.new()

	var style_box_parser: StyleBoxFlat = StyleBoxFlat.new()
	style_box_parser.bg_color = style.background_color
	style_box_parser.content_margin_bottom = style.content_margin_bottom
	style_box_parser.content_margin_left = style.content_margin_left
	style_box_parser.content_margin_right = style.content_margin_right
	style_box_parser.content_margin_top = style.content_margin_top
	style_box_parser.corner_radius_bottom_left = style.corner_radius
	style_box_parser.corner_radius_bottom_right = style.corner_radius
	style_box_parser.corner_radius_top_left = style.corner_radius
	style_box_parser.corner_radius_top_right = style.corner_radius
	label.add_theme_stylebox_override("normal", style_box_parser)

	label.add_theme_color_override("font_color", style.font_color)
	label.text = label_text
	match style.position:
		ToastStyle.Position.BOTTOM:
			if style.toast_type == ToastStyle.Type.FLOAT:
				label.anchor_bottom = 1.0
				label.anchor_top = 1.0
				label.anchor_left = 0.5
				label.anchor_right = 0.5
				label.offset_bottom = -60
			elif style.toast_type == ToastStyle.Type.FULL:
				label.anchor_bottom = 1.0
				label.anchor_top = 1.0
				label.anchor_left = 0
				label.anchor_right = 1
				label.offset_bottom = 0
			label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		ToastStyle.Position.TOP:
			if style.toast_type == ToastStyle.Type.FLOAT:
				label.anchor_bottom = 0
				label.anchor_top = 0
				label.anchor_left = 0.5
				label.anchor_right = 0.5
				label.margin_top = 60
			elif style.toast_type == ToastStyle.Type.FULL:
				label.anchor_bottom = 0
				label.anchor_top = 0
				label.anchor_left = 0
				label.anchor_right = 1
				label.margin_top = 0
			label.grow_vertical = Control.GROW_DIRECTION_END
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

	#Setting the animation
	animation = AnimationPlayer.new()
	var toast_animations: AnimationLibrary = AnimationLibrary.new()
	toast_animations.add_animation("start", load("res://toast/animations/start.anim"))
	toast_animations.add_animation("end", load("res://toast/animations/end.anim"))
	animation.add_animation_library("toast_animations", toast_animations)
	add_child(animation)


func display() -> void:
	Helpers.log_print("display()")
	animation.play("toast_animations/start")
	animation.animation_finished.connect(_animation_ended)
	visible = true


func _animation_ended(which_animation: String) -> void:
	Helpers.log_print(which_animation)
	if which_animation == "toast_animations/start":
		await get_tree().create_timer(toast_duration).timeout
		animation.play("toast_animations/end")
	else:
		animation.animation_finished.disconnect(_animation_ended)
		queue_free()
		emit_signal("done")
