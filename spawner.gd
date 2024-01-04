extends Node

var Map: Resource = preload("res://Items/Map/Map.tscn")
var done_once: bool = false

@onready var things_spawning_node: Node = get_node("../Main/Things")

# Called by players to ask Server to place a held item.
@rpc("any_peer", "call_remote")
func place_thing(node_name: String, placement_position: Vector3 = Vector3.ZERO) -> void:
	if Globals.is_server:  # this should only be called TO the server, but just in case someone calls it incorrectly
		var parsed_node_name: Dictionary = Helpers.parse_thing_name(node_name)
		thing(parsed_node_name.name, parsed_node_name.id, placement_position)


func thing(thing_name: String, id: int, spawn_position: Vector3 = Vector3.ZERO) -> void:
	var thing_name_to_spawn: String = str(thing_name, "-", id)
	var existing_thing: Node = things_spawning_node.get_node_or_null(thing_name_to_spawn)
	if not existing_thing:
		var new_thing: Node
		match thing_name:
			"Map":
				Helpers.log_print("Spawning Map")
				new_thing = Map.instantiate()
			_:
				printerr("Invalid thing to spawn name: ", thing_name)
				return
		new_thing.name = str(thing_name_to_spawn)
		if spawn_position:
			new_thing.spawn_position = spawn_position
		Helpers.log_print(str("spawning ", thing_name_to_spawn), "yellow")
		things_spawning_node.add_child(new_thing)


# This is ONLY called on the server instance
# This is called on EVERY update in the _process() function in network_websocket.gd
func things() -> void:
	# Various Things that respawn if lost
	# The way things get lost is physics yeets them out of the rooms
	# and then they fall past the boundary where they are deleted
	# by their own code

	# Nothing left here, so this comment is an example
	#thing("Ball", 1, Vector3(4, 1, -2))

	# Things to only spawn once, even if they go away
	# Things that can be picked up will disappear when picked up,
	# so they must not respawn then.
	if not done_once:
		done_once = true
		thing("Map", 1, Vector3(0, 0, 0))
