extends Node3D

# Source: https://github.com/Whimfoome/godot-FirstPersonStarter

@export_node_path("Camera3D") var cam_path := NodePath("Camera3D")

@onready var cam: Camera3D = get_node(cam_path)

@export var mouse_sensitivity := 2.0
@export var y_limit := 90.0

var mouse_axis := Vector2()
var rot        := Vector3()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Only process for the local player
	set_physics_process(get_multiplayer_authority() == multiplayer.get_unique_id())

	if User.is_server:
		# Ensure server has no camera
		$Camera3D.clear_current()
	elif get_multiplayer_authority() == multiplayer.get_unique_id():
			# This doesn't seem to be required, as the curren player always ends up with their own
			# camear, but just to be clear
			$Camera3D.make_current()

	mouse_sensitivity = mouse_sensitivity / 1000
	y_limit = deg_to_rad(y_limit)


# Called when there is an input event
func _input(event: InputEvent) -> void:
	# Mouse look (only if the mouse is captured).
	# and only if this is the local player
	if get_multiplayer_authority() == multiplayer.get_unique_id() and event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		mouse_axis = event.relative
		camera_rotation()


# Called every physics tick. 'delta' is constant
func _physics_process(delta: float) -> void:
	var joystick_axis := Input.get_vector(&"look_left", &"look_right",
	&"look_down", &"look_up")

	if joystick_axis != Vector2.ZERO:
		mouse_axis = joystick_axis * 1000.0 * delta
		camera_rotation()


func camera_rotation() -> void:
	# Horizontal mouse look.
	rot.y -= mouse_axis.x * mouse_sensitivity
	# Vertical mouse look.
	rot.x = clamp(rot.x - mouse_axis.y * mouse_sensitivity, -y_limit, y_limit)

	get_owner().rotation.y = rot.y
	rotation.x = rot.x
