@tool
class_name ToastStyle

extends Resource

enum Position { TOP, BOTTOM }

enum Type { FLOAT, FULL }

@export var position: Position = Position.BOTTOM
@export var toast_type: Type = Type.FLOAT

@export var background_color: Color = Color(1, 1, 1, 0.8)
@export var font_color: Color = Color(0.01, 0.01, 0.01, 1)

@export var corner_radius: int = 20
@export var content_margin_left: float = 20.0
@export var content_margin_right: float = 20.0
@export var content_margin_top: float = 10.0
@export var content_margin_bottom: float = 10.0

@export_enum("Left", "Center", "Right", "Fill") var text_align: int = 1
