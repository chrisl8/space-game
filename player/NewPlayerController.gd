extends RigidBody2D

@export var player: int = -1
@export var player_spawn_point: Vector2 = Vector2(4, 1.5)



var is_grounded: bool  # Whether the player is considered to be touching a walkable slope

@onready var camera: Node = get_node("./Camera2D")  # Camera3D node

@export var SyncedVar: float = 1.0:
	set(new_value):
			SyncedVar = new_value

var IsLocal: bool = false

func _ready() -> void:
	IsLocal = player == multiplayer.get_unique_id()

	set_process(IsLocal)
	set_physics_process(IsLocal)
	set_process_input(IsLocal)

	if IsLocal:
		camera.make_current()
		position = Vector2(0,0)
	else:
		if(multiplayer.is_server()):
			camera.reparent(get_tree().get_root())
			camera.position = Vector2(99999,99999)
		else:
			camera.queue_free()
		freeze = true

func _input(event: InputEvent) -> void:
	# Player look
	if (
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		and event is InputEventMouseMotion
	):
		return


func _process(_delta: float) -> void:
	if (
		get_multiplayer_authority() == multiplayer.get_unique_id()
		and Input.is_action_just_pressed(&"interact")
	):
		return


func _physics_process(delta: float) -> void:

	'''
	if Input.is_action_pressed("sprint"):
		print("SPRINTING")
	elif Input.is_action_pressed("tiptoe"):
		print("TIPTOEING")
	else:
		print("WALKING")
	'''
		
	if(player != multiplayer.get_unique_id()):
		print("ERROR")
	### Movement
	var move: Vector3 = relative_input()  # Get movement vector relative to player orientation
	var move2: Vector2 = Vector2(move.x, move.z)  # Convert movement for Vector2 
	linear_velocity = move2*1000.0

# Get movement vector based on input, relative to the player's head transform
func relative_input() -> Vector3:
	# Initialize the movement vector
	var move: Vector3 = Vector3()
	# Get cumulative input on axes
	var input: Vector3 = Vector3()
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		input.z += int(Input.is_action_pressed("move_forward"))
		input.z -= int(Input.is_action_pressed("move_backward"))
		input.x += int(Input.is_action_pressed("move_right"))
		input.x -= int(Input.is_action_pressed("move_left"))
		# Add input vectors to movement relative to the direction the head is facing
		move.z = -input.z
		move.x = input.x
	# Normalize to prevent stronger diagonal forces
	return move.normalized()

func get_new_spawn_position() -> Vector2:

	print("BBB")

	if(player != multiplayer.get_unique_id()):
		print("ERROR")

	var pos: Vector2 = Vector2.from_angle(randf() * 2 * PI)
	const SPAWN_RANDOM: float = 2.0
	return Vector2(
		0.0 + (pos.x * SPAWN_RANDOM * randf()),
		0.0 + (pos.y * SPAWN_RANDOM * randf())
	)
