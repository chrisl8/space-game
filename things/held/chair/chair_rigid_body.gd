extends RigidBody3D

@export var bounds_distance: int = 100

@export var push_factor: float = 0.9

var player_focused: String
@export var player_holding_me: String


func _ready():
	set_physics_process(get_multiplayer_authority() == multiplayer.get_unique_id())
	if Globals.is_server:
		position = Vector3(8, 1, -8)
		rotation.y = -45.0


func _physics_process(_delta):
#	print(
#		"grabbing|",
#		Globals.local_debug_instance_number,
#		"|",
#		multiplayer.get_unique_id(),
#		"|",
#		name,
#		"|",
#		player_holding_me
#	)
	if player_holding_me != "":
		var things_parent: Node = get_tree().get_root().get_node("Main/Things")
		var existing_thing: Node = things_parent.get_node_or_null(String(name))
		if existing_thing:
			existing_thing.queue_free()
		# var players_parent: Node = get_tree().get_root().get_node("Main/Players")
		# var player_to_follow: Node = players_parent.get_node_or_null(player_holding_me)
		# if player_to_follow:
		# 	var player_character_to_follow: Node = player_to_follow.get_node_or_null("Character")
		# 	if player_character_to_follow:
		# 		var player_has_thing: Node = player_character_to_follow.get_node_or_null(
		# 			String(name)
		# 		)
		# 		if not player_has_thing:
		# 			var chair: Resource = preload("res://things/chair/chair.tscn")
		# 			var new_thing = chair.instantiate()
		# 			new_thing.name = str(name)
		# 			player_character_to_follow.add_child(new_thing)

		#var transform_hold_obj = player_character_to_follow.get_global_transform()
		# I think instead of this, the thing should be removed from the current parent
		# and childed to the player's character,
		# whether that be a direct remove/add_child
		# https://ask.godotengine.org/1754/how-to-change-the-parent-of-a-node-from-gdscript
		# or a queue_free and rebirth as a new object, needs some testing.

		# var some_distance_between_you_and_object: int = 1
		# transform_hold_obj.origin = (
		# 	transform_hold_obj.origin
		# 	- transform_hold_obj.basis.z * some_distance_between_you_and_object
		# )
		# position = transform_hold_obj.origin
		# rotation = player_to_follow.rotation

	# Delete if it gets out of bounds
	# Whatever spawned it should track and respawn it if required
	if abs(position.x) > bounds_distance:
		get_parent().queue_free()
	if abs(position.y) > bounds_distance:
		get_parent().queue_free()
	if abs(position.z) > bounds_distance:
		get_parent().queue_free()


func select(other_name):
	if player_focused == "":
		player_focused = other_name
		print(other_name, " is near ", get_parent().name)
		$SpotLight3D.visible = true


func unselect(other_name):
	player_focused = ""
	print(other_name, " moved away from ", get_parent().name)
	$SpotLight3D.visible = false


@rpc("any_peer", "call_remote") func grab(other_name) -> void:
	if player_holding_me == "":
		Helpers.log_print(str(name, " grabbed by ", other_name))
		player_holding_me = other_name


func my_name() -> String:
	return get_parent().name


func input_position(new_position):
	self.position = new_position
