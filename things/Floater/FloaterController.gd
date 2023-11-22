extends RigidBody3D

@export var bounds_distance: int = 100
@export var arms: Array[Node3D] = []
@export var arm_particles: Array[GPUParticles3D] = []
@export var spawn_position: Vector3

var current_time: float = 0.0
var force_applied: bool = false
var last_position: Vector3 = Vector3(0, 0, 0)
var current_eye_rot_time: float = 0
var current_arm_rot_time: float = 0
var arm_movement_last_rotation: Vector3 = Vector3.ZERO
var particle_last_position: Vector3 = Vector3.ZERO

@onready var eye: Node3D = $Eye


func _ready() -> void:
	set_physics_process(get_multiplayer_authority() == multiplayer.get_unique_id())

	# No need to run these cosmetic movements on the server
	set_process(!Globals.is_server)

	if Globals.is_server and spawn_position:
		position = spawn_position

	last_position = position
	particle_last_position = position


func process_arms(delta: float) -> void:
	current_arm_rot_time += delta
	#var target_rotation: Vector3 = arm_movement_last_rotation
	#if position.distance_to(last_position) > 0.01 * delta or true:
	#	#current_arm_rot_time = 0
	#	target_rotation = position - last_position
	#elif current_arm_rot_time > 1:
	#	# Otherwise it moves back so rapidly we never see the changes
	#	#current_arm_rot_time = 0
	#	target_rotation = Vector3.ZERO
	#var LerpTarget = arm_movement_last_rotation.lerp(target_rotation,delta*99)

	last_position = lerp(last_position, position, 1.5 * delta)
	last_position = Vector3(last_position.x, position.y - 2, last_position.z)

	particle_last_position = lerp(particle_last_position, position, 0.7 * delta)

	for arm: Node3D in arms:
		arm.look_at(last_position, Vector3.UP, false)

	for particle_system: GPUParticles3D in arm_particles:
		particle_system.amount_ratio = clamp(
			abs((particle_last_position - position).length() * 2), 0.1, 3
		)
		particle_system.speed_scale = clamp(
			abs((particle_last_position - position).length() * 2), 1, 3
		)


func _physics_process(delta: float) -> void:
	# Delete if it gets out of bounds
	# Whatever spawned it should track and respawn it if required
	if abs(position.x) > bounds_distance:
		queue_free()
	if abs(position.y) > bounds_distance:
		queue_free()
	if abs(position.z) > bounds_distance:
		queue_free()

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
	# Eye Movement
	current_eye_rot_time += delta
	if current_eye_rot_time > 3:
		current_eye_rot_time = 0
		var eye_x: float = RandomNumberGenerator.new().randf_range(-30, 10)
		var eye_y: float = RandomNumberGenerator.new().randf_range(-37, 37)
		eye.rotation_degrees = Vector3(eye_x, eye_y, 0)

	process_arms(delta)
