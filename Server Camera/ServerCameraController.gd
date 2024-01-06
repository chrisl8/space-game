extends Node2D

const MovementSpeed: float = 4.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):

	var move: Vector2 = Vector2()

	var input: Vector3 = Vector3()
	input.z += int(Input.is_action_pressed("move_forward"))
	input.z -= int(Input.is_action_pressed("move_backward"))
	input.x += int(Input.is_action_pressed("move_right"))
	input.x -= int(Input.is_action_pressed("move_left"))

	move.x = input.x
	move.y = -input.z

	global_position+=move*MovementSpeed
