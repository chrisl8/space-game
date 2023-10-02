extends RigidBody3D

@export var bounds_distance: int = 100

@export var Arms: Array[Node3D] = []
@export var Eye: Node3D

func _ready():
	set_physics_process(get_multiplayer_authority() == multiplayer.get_unique_id())

	# TODO: Figure out a way to use this without having the location hard coded ahead of time.
	if Globals.is_server:
		position = Vector3(20.3, 2.4, -3.1)
		rotation.y = -45.0

func ProcessArms(delta) -> void:
	for Arm in Arms:
		#Why arm no rotate :(
		Arm.rotation = Vector3(RandomNumberGenerator.new().randf_range(-10, 10),RandomNumberGenerator.new().randf_range(-10, 10),0)
		

		
		#print("A")
		#Arm.set_rotation(self.linear_velocity)
		#print(self.velocity)
		#Arm.set_rotation(self.velocity)

var CurrentTime = 0
var ForceApplied = false
func _physics_process(_delta):
	# Delete if it gets out of bounds
	# Whatever spawned it should track and respawn it if required
	if abs(position.x) > bounds_distance:
		get_parent().queue_free()
	if abs(position.y) > bounds_distance:
		get_parent().queue_free()
	if abs(position.z) > bounds_distance:
		get_parent().queue_free()
		
	CurrentTime+=_delta
	var MinSpeed = 1.5
	var MaxSpeed = 3
	var SpeedX = RandomNumberGenerator.new().randf_range(MinSpeed, MaxSpeed)
	var SpeedY = RandomNumberGenerator.new().randf_range(MinSpeed, MaxSpeed)
	var SpeedZ = RandomNumberGenerator.new().randf_range(MinSpeed/2.0, MaxSpeed/2.0)
		
	if(RandomNumberGenerator.new().randf_range(0, 1) > 0.5):
		SpeedX*=-1
	if(RandomNumberGenerator.new().randf_range(0, 1) > 0.5):
		SpeedY*=-1
	if(RandomNumberGenerator.new().randf_range(0, 1) > 0.5):
		SpeedZ*=-1
		
	if(CurrentTime > 2 and !ForceApplied):
		ForceApplied = true
		self.apply_impulse(Vector3(SpeedX,SpeedY,SpeedZ))
	if(CurrentTime > 3.5):
		#Eye.rotation = Vector3(RandomNumberGenerator.new().randf_range(-10, 10),RandomNumberGenerator.new().randf_range(-10, 10),0)
		CurrentTime = 0
		ForceApplied = false
		self.apply_torque(Vector3(0,RandomNumberGenerator.new().randf_range(-3.5, 3.5),0))
	ProcessArms(_delta)
