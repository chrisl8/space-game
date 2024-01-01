extends RigidBody2D

@export var bounds_distance: int = 100
@export var push_factor: float = 0.9
@export var spawn_position: Vector2

var player_focused: String

func _ready() -> void:
	set_physics_process(get_multiplayer_authority() == multiplayer.get_unique_id())
	if Globals.is_server and spawn_position:
		position = spawn_position
		# Only position, not rotation is currently passed in by the spawner
		rotation = -45.0


func _physics_process(_delta: float) -> void:
	# Delete if it gets out of bounds
	# Whatever spawned it should track and respawn it if required
	if abs(position.x) > bounds_distance:
		queue_free()
	if abs(position.y) > bounds_distance:
		queue_free()


func select(other_name: String) -> void:
	if player_focused == "":
		player_focused = other_name
		Helpers.log_print(str(other_name, " is near me (", name, ")"), "saddlebrown")
		$SpotLight3D.visible = true


func unselect(other_name: String) -> void:
	player_focused = ""
	Helpers.log_print(str(other_name, " moved away from me (", name, ")"), "saddlebrown")
	$SpotLight3D.visible = false


@rpc("any_peer", "call_remote") func grab() -> void:
	Helpers.log_print(
		str(
			"I (",
			name,
			") was grabbed by ",
			multiplayer.get_remote_sender_id(),
			" Deleting myself now"
		),
		"saddlebrown"
	)
	# Delete myself if someone grabbed me
	queue_free()
	# Once that is done, tell the player node that grabbed me to spawn a "held" version
	var player_spawner_node: Node = get_node("/root/Main/Players")
	var player: Node = player_spawner_node.get_node_or_null(str(multiplayer.get_remote_sender_id()))
	if player and player.has_method("spawn_player_held_thing"):
		player.spawn_player_held_thing.rpc(name)


func my_name() -> String:
	return get_parent().name


func input_position(new_position: Vector2) -> void:
	self.position = new_position
