extends RigidBody2D

@export var player: int = -1
@export var player_spawn_point: Vector2 = Vector2(4, 1.5)

@export var SyncedPosition: Vector2 = Vector2(0,0):
	set(new_value):
			SyncedPosition = new_value
			UpdateSyncedPosition = !IsLocal
var UpdateSyncedPosition: bool = false

@export var SyncedRotation: float = 0:
	set(new_value):
			SyncedRotation = new_value
			UpdateSyncedRotation = !IsLocal
var UpdateSyncedRotation: bool = false



@onready var camera: Node = get_node("./Camera2D")  # Camera3D node



var IsLocal: bool = false

func _ready() -> void:
	IsLocal = player == multiplayer.get_unique_id()

	set_process(IsLocal)
	set_physics_process(IsLocal)
	set_process_input(IsLocal)

	if IsLocal:
		camera.make_current()
	else:
		if(multiplayer.is_server()):
			camera.reparent(get_tree().get_root())
			camera.position = Vector2(99999,99999)
		else:
			camera.queue_free()
		#freeze = true

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
		
	### Movement
	var MoveInput: Vector2 = relative_input()
	
	var Velocity: Vector2 = linear_velocity
	if(abs(MoveInput.x) > 0.1):
		Velocity = Vector2(MoveInput.x*1000.0,Velocity.y)
	else:
		var Damp: float = 5000.0
		var Dampening: float = Velocity.x
		if(Velocity.x < 0.0):
			Dampening = Velocity.x - (Damp*delta) * (Velocity.x/abs(Velocity.x))
			Dampening = clamp(Dampening,Velocity.x,0.0)
		elif(Velocity.x > 0):
			Dampening = Velocity.x - (Damp*delta) * (Velocity.x/abs(Velocity.x))
			Dampening = clamp(Dampening,0.0,Velocity.x)

		Velocity = Vector2(Dampening,Velocity.y)
	if(abs(MoveInput.y) > 0.1):
		Velocity = Vector2(Velocity.x,MoveInput.y*1000.0)
	
	linear_velocity = Velocity
	SyncedPosition = position
	SyncedRotation = rotation

# Get movement vector based on input, relative to the player's head transform
func relative_input() -> Vector2:
	# Initialize the movement vector
	var move: Vector2 = Vector2()
	# Get cumulative input on axes
	var input: Vector3 = Vector3()
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		input.z += int(Input.is_action_pressed("move_forward"))
		input.z -= int(Input.is_action_pressed("move_backward"))
		input.x += int(Input.is_action_pressed("move_right"))
		input.x -= int(Input.is_action_pressed("move_left"))
		# Add input vectors to movement relative to the direction the head is facing
		move.x = input.x
		move.y = -input.z
	# Normalize to prevent stronger diagonal forces
	return move.normalized()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if(!IsLocal):
		if(UpdateSyncedPosition and UpdateSyncedRotation):
			state.transform = Transform2D(SyncedRotation, SyncedPosition)
		elif (UpdateSyncedPosition):
			state.transform = Transform2D(state.transform.get_rotation(), SyncedPosition)
		elif(UpdateSyncedRotation):
			state.transform = Transform2D(SyncedRotation, state.origin)
		UpdateSyncedPosition = false
		UpdateSyncedRotation = false




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