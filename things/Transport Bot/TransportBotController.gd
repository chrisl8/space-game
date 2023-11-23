extends Node3D

@export var bounds_distance: int = 200
@export var spawn_position: Vector3

@export var PhysicsBody : RigidBody3D
@export var NavAgent : NavigationAgent3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_physics_process(Globals.is_server)
	if(Globals.is_server):
		position = spawn_position
	PhysicsBody.position = position
	



#func _process(delta: float) -> void:

	
var TimeSinceNav = 0

func _physics_process(_delta: float) -> void:
	return
	# Only the server should act on this object, as the server owns it,
	# especially the delete part.
	# Delete if it gets out of bounds
	if abs(position.x) > bounds_distance:
		queue_free()
	if abs(position.y) > bounds_distance:
		queue_free()
	if abs(position.z) > bounds_distance:
		queue_free()
	
	if(!NavAgent.is_navigation_finished()):
		print("1")
		pass
		#print("2")
		position = lerp(position, NavAgent.get_next_path_position(),0.5)
		#PhysicsBody.position = position
	else:
		print("2")
		NavAgent.set_target_position(position + Vector3(RandomNumberGenerator.new().randf_range(-1, 1),0,RandomNumberGenerator.new().randf_range(-1, 1)))
