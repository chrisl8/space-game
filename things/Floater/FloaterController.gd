extends RigidBody3D

@export var bounds_distance: int = 100
@export var arms: Array[Node3D] = []
@export var eye: Node3D

var current_time: float = 0.0
var force_applied: bool = false
var last_position: Vector3
var current_eye_rot_time: float = 0


func _ready() -> void:
	set_physics_process(get_multiplayer_authority() == multiplayer.get_unique_id())
	set_process(true)

	# TODO: Figure out a way to use this without having the location hard coded ahead of time.
	if Globals.is_server:
		position = Vector3(20.3, 2.4, -3.1)
		rotation.y = -45.0
	last_position = position


func process_arms(_delta: float) -> void:
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
	# process_arms(delta)


func _process(delta: float) -> void:
	for arm: Node3D in arms:
		#Arm rotation is applied internally, but does not affect rendered arm rotation
		arm.set_rotation_degrees(
			Vector3(
				RandomNumberGenerator.new().randf_range(-90, 90),
				RandomNumberGenerator.new().randf_range(-90, 90),
				RandomNumberGenerator.new().randf_range(-90, 90)
			)
		)
		#When logged will display set rotation, but rotation is not applied to game arm
		#Is it rotating some other arm? The prephab arm? Do rigibodies support sub objects being rotated?
		#print(Arm.rotation)

	current_eye_rot_time += delta
	if current_eye_rot_time > 3:
		current_eye_rot_time = 0
		eye.rotation = Vector3(
			RandomNumberGenerator.new().randf_range(-10, 10),
			RandomNumberGenerator.new().randf_range(-10, 10),
			0
		)
	process_arms(delta)
