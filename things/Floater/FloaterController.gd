extends RigidBody3D

@export var bounds_distance: int = 100

@export var Arms: Array[Node3D] = []
@export var Eye: Node3D


func _ready() -> void:
	set_physics_process(get_multiplayer_authority() == multiplayer.get_unique_id())
	set_process(true)

	# TODO: Figure out a way to use this without having the location hard coded ahead of time.
	if Globals.is_server:
		position = Vector3(20.3, 2.4, -3.1)
		rotation.y = -45.0
	LastPosition = position


func ProcessArms(_delta: float) -> void:
	var TargetRotation = Vector3(0, 45, 0)
	if position.distance_to(LastPosition) > 0.1 * _delta:
		TargetRotation = position - LastPosition
	for Arm in Arms:
		#Arms still only run on server
		Arm.rotation = TargetRotation
		#Arm.rotation = Vector3(
		#	RandomNumberGenerator.new().randf_range(-20, 20),
		#	45,
		#	RandomNumberGenerator.new().randf_range(-20, 20)
		#)

		#Arm.set_rotation(self.linear_velocity)
		#print(self.velocity)
		#Arm.set_rotation(self.velocity)

	#Because I don't know how to read node atributes
	LastPosition = position


var CurrentTime: float = 0.0
var ForceApplied: bool = false
var LastPosition


func _physics_process(delta: float) -> void:
	# Delete if it gets out of bounds
	# Whatever spawned it should track and respawn it if required
	if abs(position.x) > bounds_distance:
		get_parent().queue_free()
	if abs(position.y) > bounds_distance:
		get_parent().queue_free()
	if abs(position.z) > bounds_distance:
		get_parent().queue_free()

	CurrentTime += delta

	if CurrentTime > 1 and !ForceApplied:
		var MinSpeed: float = 0.5
		var MaxSpeed: float = 1
		var SpeedX: float = RandomNumberGenerator.new().randf_range(MinSpeed, MaxSpeed)
		var SpeedY: float = RandomNumberGenerator.new().randf_range(MinSpeed, MaxSpeed)
		var SpeedZ: float = RandomNumberGenerator.new().randf_range(MinSpeed / 2.0, MaxSpeed / 2.0)

		if RandomNumberGenerator.new().randf_range(0, 1) > 0.5:
			SpeedX *= -1
		if RandomNumberGenerator.new().randf_range(0, 1) > 0.5:
			SpeedY *= -1
		if RandomNumberGenerator.new().randf_range(0, 1) > 0.5:
			SpeedZ *= -1

		ForceApplied = true
		self.apply_impulse(Vector3(SpeedX, SpeedY, SpeedZ))
	if CurrentTime > 3.5:
		CurrentTime = 0
		ForceApplied = false
		self.apply_torque(Vector3(0, RandomNumberGenerator.new().randf_range(-3.5, 3.5), 0))
	ProcessArms(delta)


var CurrentEyeRotTime = 0


func _process(delta: float) -> void:
	for Arm in Arms:
		#Arm rotation is applied internally, but does not affect rendered arm rotation
		Arm.set_rotation_degrees(
			Vector3(
				RandomNumberGenerator.new().randf_range(-90, 90),
				RandomNumberGenerator.new().randf_range(-90, 90),
				RandomNumberGenerator.new().randf_range(-90, 90)
			)
		)
		#When logged will display set rotation, but rotation is not applied to game arm
		#Is it rotating some other arm? The prephab arm? Do rigibodies support sub objects being rotated?
		#print(Arm.rotation)

	CurrentEyeRotTime += delta
	if CurrentEyeRotTime > 3:
		CurrentEyeRotTime = 0
		Eye.rotation = Vector3(
			RandomNumberGenerator.new().randf_range(-10, 10),
			RandomNumberGenerator.new().randf_range(-10, 10),
			0
		)
	ProcessArms(delta)
