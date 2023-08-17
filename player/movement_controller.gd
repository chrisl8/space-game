extends CharacterBody3D
class_name MovementController

# Source: https://github.com/Whimfoome/godot-FirstPersonStarter

# Note: This does not seem to do anything. Maybe it will if we fix the Spawner?
@export var owner_id := -1 :
	set(_own):
		owner_id = _own
		$ServerSynchronizer.set_multiplayer_authority(owner_id)

@export var gravity_multiplier := 3.0
@export var speed := 10
@export var acceleration := 8
@export var deceleration := 10

@export_range(0.0, 1.0, 0.05) var air_control := 0.3
@export var jump_height := 10

# Get the gravity from the project settings to be synced with RigidDynamicBody nodes.
@onready var gravity: float = (ProjectSettings.get_setting("physics/3d/default_gravity")
* gravity_multiplier)

# Player synchronized input.
@onready var input = $PlayerInput


func _ready():
	if not User.is_server:
		print(User.ID)
		get_tree().root.print_tree_pretty()

# Called every physics tick. 'delta' is constant
func _physics_process(delta: float) -> void:
	if is_on_floor():
		if input.jumping:
			velocity.y = jump_height
	else:
		velocity.y -= gravity * delta
	# Reset jump state.
	input.jumping = false
	var direction := direction_input()
	accelerate(delta, direction)
	move_and_slide()

func direction_input() -> Vector3:
	var direction := Vector3()
	var aim: Basis = get_global_transform().basis
	direction = aim.z * -input.input_axis.x + aim.x * input.input_axis.y
	return direction

func accelerate(delta: float, direction: Vector3) -> void:
	# Using only the horizontal velocity, interpolate towards the input.
	var temp_vel := velocity
	temp_vel.y = 0

	var temp_accel: float
	var target: Vector3 = direction * speed

	if direction.dot(temp_vel) > 0:
		temp_accel = acceleration
	else:
		temp_accel = deceleration

	if not is_on_floor():
		temp_accel *= air_control

	temp_vel = temp_vel.lerp(target, temp_accel * delta)

	velocity.x = temp_vel.x
	velocity.z = temp_vel.z
