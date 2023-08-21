extends MultiplayerSynchronizer

@export var input_axis := Vector2()

# Set via RPC to simulate is_action_just_pressed.
@export var jumping := false

@export var camera_rotation_y := 0.0

# Source: https://github.com/Whimfoome/godot-FirstPersonStarter

var cam: Camera3D

@export var mouse_sensitivity := 2.0
@export var y_limit := 80.0

var mouse_axis := Vector2()
var rot        := Vector3()

func _ready():

	cam = get_parent().get_node("Head").get_node("Camera3D")

	# Only process for the local player
	set_process(get_multiplayer_authority() == multiplayer.get_unique_id())
	set_physics_process(get_multiplayer_authority() == multiplayer.get_unique_id())
	set_process_input(get_multiplayer_authority() == multiplayer.get_unique_id())

	if User.is_server:
		# Ensure server has no player cameras
		cam.clear_current()
	elif get_parent().player == multiplayer.get_unique_id():
		cam.make_current()

	mouse_sensitivity = mouse_sensitivity / 1000
	y_limit = deg_to_rad(y_limit)


# Called when there is an input event
func _input(event: InputEvent) -> void:
	# Mouse look (only if the mouse is captured).
	# and only if this is the local player
	if  event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		mouse_axis = event.relative
		camera_rotation()


# Called every physics tick. 'delta' is constant
func _physics_process(delta: float) -> void:
	var joystick_axis := Input.get_vector(&"look_left", &"look_right",
	&"look_down", &"look_up")

	if joystick_axis != Vector2.ZERO:
		mouse_axis = joystick_axis * 1000.0 * delta
		camera_rotation()


@rpc("authority")
func jump():
	jumping = true

func _process(_delta):
	input_axis = Input.get_vector(&"move_back", &"move_forward",
	&"move_left", &"move_right")

	if Input.is_action_just_pressed(&"jump"):
		jump.rpc()


@rpc("authority")
func cam_rotate_y(input):
	camera_rotation_y = input


func camera_rotation() -> void:
	# Horizontal mouse look.
	rot.y -= mouse_axis.x * mouse_sensitivity
	cam_rotate_y(rot.y)

	# Vertical mouse look.
	rot.x = clamp(rot.x - mouse_axis.y * mouse_sensitivity, -y_limit, y_limit)
	cam.rotation.x = rot.x
