extends RigidBody3D

@export var bounds_distance: int = 200
@export var spawn_position: Vector3

@export var NavAgent : NavigationAgent3D
@export var MovementVelocity: float = 3.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_physics_process(Globals.is_server)
	if(Globals.is_server):
		position = spawn_position
		NavAgent.velocity_computed.connect(Callable(_on_velocity_computed))



#func _process(delta: float) -> void:

	
var TimeSinceNav = 0

func _physics_process(_delta: float) -> void:
	if abs(position.x) > bounds_distance:
		queue_free()
	if abs(position.y) > bounds_distance:
		queue_free()
	if abs(position.z) > bounds_distance:
		queue_free()

	var NextPathPosition: Vector3 = NavAgent.get_next_path_position()
	var CurrentPosition: Vector3 = global_position
	var NewVelocity: Vector3 = (NextPathPosition - CurrentPosition).normalized() * MovementVelocity
	
	if NavAgent.avoidance_enabled:
		NavAgent.set_velocity(NewVelocity)
	else:
		_on_velocity_computed(NewVelocity)
		
	if NavAgent.is_navigation_finished():
		NavAgent.set_target_position(position + Vector3(RandomNumberGenerator.new().randf_range(-10, 10),0,RandomNumberGenerator.new().randf_range(-10, 10)))

func _on_velocity_computed(safe_velocity: Vector3):
	linear_velocity = safe_velocity

var TargetPlant

func ReachedDestination():
	if(len(Globals.AllocatedPlants) > 0 and (false in Globals.AllocatedPlants)):
		var FoundTarget = false
		var SelectedIndex = -1
		while(!FoundTarget):
			SelectedIndex = RandomNumberGenerator.new().randi_range(0, len(Globals.AllocatedPlants)-1)
			if(!Globals.AllocatedPlants[SelectedIndex]):
				FoundTarget = true
		TargetPlant = Globals.PottedPlants[SelectedIndex]
		Globals.AllocatedPlants[SelectedIndex] = true
		NavAgent.set_target_position(TargetPlant.position)
