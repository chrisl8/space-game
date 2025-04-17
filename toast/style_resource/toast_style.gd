@tool
extends Resource
class_name ToastStyle

# Public enums
enum Position { TOP, BOTTOM }
enum Type { FLOAT, FULL }
enum TextAlign { LEFT, CENTER, RIGHT, FILL }

# Exported properties
@export var position: Position = Position.BOTTOM
@export var toast_type: Type = Type.FLOAT

@export var background_color: Color = Color(1, 1, 1, 0.8)
@export var font_color: Color = Color(0.01, 0.01, 0.01, 1)
@export var font_size: int = 16

@export var corner_radius: int = 20
@export var content_margin: Margin = Margin(20, 20, 10, 10) # left, right, top, bottom

@export_enum("Left", "Center", "Right", "Fill") var text_align: TextAlign = TextAlign.CENTER

# NEW: Icon support
@export var icon_texture: Texture2D
@export var icon_size: Vector2 = Vector2(24, 24)
@export var icon_margin: float = 8.0

# NEW: Animation & timing
@export var show_duration: float = 0.3  # fade/tween in
@export var hide_duration: float = 0.3  # fade/tween out
@export var display_time: float = 2.0   # how long to remain visible

# Signals
signal toast_shown()
signal toast_hidden()

# Internal helpers
func _ensure_theme():
    # You could replace these with a Theme resource lookup
    return {
        "bg_color": background_color,
        "font_color": font_color,
        "font_size": font_size,
        "corner_radius": corner_radius,
        "margins": content_margin
    }

# Call this from your UI code to display a toast
func show_toast(message: String, duration: float = -1.0) -> void:
    var duration_to_use = (duration > 0) ? duration : display_time
    var container = _create_toast_node(message)
    get_tree().current_scene.add_child(container)
    _animate_in(container)
    yield(get_tree().create_timer(duration_to_use), "timeout")
    _animate_out(container)

# Build the Control node dynamically
func _create_toast_node(text: String) -> Control:
    var theme = _ensure_theme()

    var toast = Control.new()
    toast.name = "Toast"
    toast.mouse_filter = Control.MouseFilter.Ignore

    # StyleBox for background
    var style_box = StyleBoxFlat.new()
    style_box.bg_color = theme["bg_color"]
    style_box.corner_radius_top_left = theme["corner_radius"]
    style_box.corner_radius_top_right = theme["corner_radius"]
    style_box.corner_radius_bottom_left = theme["corner_radius"]
    style_box.corner_radius_bottom_right = theme["corner_radius"]
    toast.add_stylebox_override("panel", style_box)

    # HBox to hold icon + label
    var hbox = HBoxContainer.new()
    hbox.anchor_left = 0.1
    hbox.anchor_right = 0.9
    hbox.anchor_top = (position == Position.TOP) ? 0.0 : 1.0
    hbox.anchor_bottom = (position == Position.TOP) ? 0.0 : 1.0
    hbox.margin_left = theme["margins"].left
    hbox.margin_right = -theme["margins"].right
    hbox.margin_top = (position == Position.TOP) ? theme["margins"].top : -theme["margins"].bottom
    hbox.margin_bottom = hbox.margin_top + theme["font_size"] + theme["margins"].top + theme["margins"].bottom

    # Optional icon
    if icon_texture:
        var icon = TextureRect.new()
        icon.texture = icon_texture
        icon.rect_min_size = icon_size
        icon.margin_right = icon_margin
        hbox.add_child(icon)

    # Label
    var label = Label.new()
    label.text = text
    label.align = text_align
    label.autowrap = true
    label.percent_visible = 1.0
    label.add_color_override("font_color", theme["font_color"])
    label.add_font_override("font", DynamicFont.new())
    label.get_font("font").size = theme["font_size"]
    hbox.add_child(label)

    toast.add_child(hbox)
    toast.modulate.a = 0.0  # start transparent

    return toast

# Animate the toast in
func _animate_in(toast: Control) -> void:
    var tween = Tween.new()
    toast.add_child(tween)
    tween.tween_property(toast, "modulate:a", 1.0, show_duration)
    tween.play()
    tween.connect("finished", Callable(self, "_on_shown"), [toast])

# Animate the toast out
func _animate_out(toast: Control) -> void:
    var tween = Tween.new()
    toast.add_child(tween)
    tween.tween_property(toast, "modulate:a", 0.0, hide_duration)
    tween.play()
    tween.connect("finished", Callable(self, "_on_hidden"), [toast])

# Signal emissions & cleanup
func _on_shown(toast):
    emit_signal("toast_shown")
    toast.get_child(0).queue_free()  # remove tween

func _on_hidden(toast):
    emit_signal("toast_hidden")
    toast.queue_free()
