extends RigidBody3D

@export var bounds_distance: int = 100
@export var arms: Array[Node3D] = []
@export var spawn_position: Vector3

var current_time: float = 0.0
var force_applied: bool = false
var last_position: Vector3
var current_eye_rot_time: float = 0

@onready var eye: Node3D = $Eye


func _ready() -> void:
	set_physics_process(get_multiplayer_authority() == multiplayer.get_unique_id())

	# No need to run these cosmetic movements on the server
	set_process(!Globals.is_server)

	if Globals.is_server and spawn_position:
		position = spawn_position

	last_position = position


func process_arms(_delta: float) -> void:
	# This code works, but it results in insanely rapid movement of the arms,
	# so I disabled it by not calling it in _process
	var target_rotation: Vector3 = Vector3(0, 45, 0)
	if position.distance_to(last_position) > 0.1 * _delta:
		target_rotation = position - last_position
	for arm: Node3D in arms:
		#arms still only run on server
		arm.rotation = target_rotation
		#Arm.rotation = Vector3(
		#	RandomNumberGenerator.new().randf_range(-20, 20),
		#	45,
		#	RandomNumberGenerator.new().randf_range(-20, 20)
		#)

		#Arm.set_rotation(self.linear_velocity)
		#print(self.velocity)
		#Arm.set_rotation(self.velocity)

	#Because I don't know how to read node attributes
	last_position = position


func _physics_process(delta: float) -> void:
	# Delete if it gets out of bounds
	# Whatever spawned it should track and respawn it if required
	if abs(position.x) > bounds_distance:
		get_parent().queue_free()
	if abs(position.y) > bounds_distance:
		get_parent().queue_free()
	if abs(position.z) > bounds_distance:
		get_parent().queue_free()

	current_time += delta

	if current_time > 1 and !force_applied:
		var min_speed: float = 0.5
		var max_speed: float = 1
		var speed_x: float = RandomNumberGenerator.new().randf_range(min_speed, max_speed)
		var speed_y: float = RandomNumberGenerator.new().randf_range(min_speed, max_speed)
		var speed_z: float = RandomNumberGenerator.new().randf_range(
			min_speed / 2.0, max_speed / 2.0
		)

		if RandomNumberGenerator.new().randf_range(0, 1) > 0.5:
			speed_x *= -1
		if RandomNumberGenerator.new().randf_range(0, 1) > 0.5:
			speed_y *= -1
		if RandomNumberGenerator.new().randf_range(0, 1) > 0.5:
			speed_z *= -1

		force_applied = true
		self.apply_impulse(Vector3(speed_x, speed_y, speed_z))
	if current_time > 3.5:
		current_time = 0
		force_applied = false
		self.apply_torque(Vector3(0, RandomNumberGenerator.new().randf_range(-3.5, 3.5), 0))


func _process(delta: float) -> void:
	# This code fights with the code in process_arms, need to use one or the other.
	# for arm: Node3D in arms:
	# 	#Arm rotation is applied internally, but does not affect rendered arm rotation
	# 	arm.set_rotation_degrees(
	# 		Vector3(
	# 			RandomNumberGenerator.new().randf_range(-90, 90),
	# 			RandomNumberGenerator.new().randf_range(-90, 90),
	# 			RandomNumberGenerator.new().randf_range(-90, 90)
	# 		)
	# 	)
	# 	#When logged will display set rotation, but rotation is not applied to game arm
	# 	#Is it rotating some other arm? The prephab arm? Do rigibodies support sub objects being rotated?
	# 	#print(Arm.rotation)

	# Eye Movement
	current_eye_rot_time += delta
	if current_eye_rot_time > 3:
		current_eye_rot_time = 0
		var eye_x: float = RandomNumberGenerator.new().randf_range(-30, 10)
		var eye_y: float = RandomNumberGenerator.new().randf_range(-37, 37)
		eye.rotation_degrees = Vector3(eye_x, eye_y, 0)
	#process_arms(delta)
