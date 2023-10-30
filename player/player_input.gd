extends MultiplayerSynchronizer
# TODO: Delete this file, none of it is used anymore.

@export var input_axis: Vector2 = Vector2()

# Set via RPC to simulate is_action_just_pressed.
@export var jumping: bool = false
@export var interacting: bool = false

@export var camera_rotation_y: float = 0.0

# Source: https://github.com/Whimfoome/godot-FirstPersonStarter

var cam: Camera3D

@export var mouse_sensitivity: float = 2.0
@export var y_limit: float = 80.0

var mouse_axis: Vector2 = Vector2()
var rot: Vector3 = Vector3()

@export var speed: int = 10
var normal_fov: float
@export var fov_multiplier: float = 1.05
var is_sprinting: bool = false
var normal_speed: int = speed
var sprint_speed: int = 25


func _ready() -> void:
	cam = get_parent().get_node("Head").get_node("Camera3D")
	normal_fov = cam.fov

	# Only process for the local player
	set_process(get_multiplayer_authority() == multiplayer.get_unique_id())
	set_physics_process(get_multiplayer_authority() == multiplayer.get_unique_id())
	set_process_input(get_multiplayer_authority() == multiplayer.get_unique_id())

	if Globals.is_server:
		# Ensure server has no player cameras
		cam.clear_current()
	elif get_parent().player == multiplayer.get_unique_id():
		cam.make_current()

	mouse_sensitivity = mouse_sensitivity / 1000
	y_limit = deg_to_rad(y_limit)


func _input(event: InputEvent) -> void:
	# Mouse look (only if the mouse is captured).
	# and only if this is the local player
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		mouse_axis = event.relative
		camera_rotation()
	elif event is InputEventKey and event.keycode == KEY_SHIFT:
		if event.pressed != is_sprinting:
			is_sprinting = event.pressed
			if is_sprinting:
				speed = sprint_speed
			else:
				speed = normal_speed


func _physics_process(delta: float) -> void:
	var joystick_axis: Vector2 = Input.get_vector(
		&"look_left", &"look_right", &"look_down", &"look_up"
	)

	if joystick_axis != Vector2.ZERO:
		mouse_axis = joystick_axis * 1000.0 * delta
		camera_rotation()

	if is_sprinting:
		cam.set_fov(lerp(cam.fov, normal_fov * fov_multiplier, delta * 8))
	else:
		cam.set_fov(lerp(cam.fov, normal_fov, delta * 8))


func jump() -> void:
	jumping = true


@rpc() func interact() -> void:
	interacting = true


func _process(_delta: float) -> void:
	input_axis = Input.get_vector(&"move_back", &"move_forward", &"move_left", &"move_right")

	if Input.is_action_just_pressed(&"jump"):
		jump()

	if Input.is_action_just_pressed(&"interact"):
		interact.rpc()


func camera_rotation() -> void:
	# Horizontal mouse look.
	rot.y -= mouse_axis.x * mouse_sensitivity
	camera_rotation_y = rot.y

	# Vertical mouse look.
	rot.x = clamp(rot.x - mouse_axis.y * mouse_sensitivity, -y_limit, y_limit)
	cam.rotation.x = rot.x
