extends Node

var Chair: Resource = preload("res://things/chair/chair.tscn")
var BeachBall: Resource = preload("res://things/beach_ball/beach_ball.tscn")
var Fish: Resource = preload("res://things/fish/fish.tscn")
var Floater: Resource = preload("res://things/Floater/Floater.tscn")
var PlantA: Resource = preload("res://things/plant_a/plant_a.tscn")
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
			"Ball":
				new_thing = BeachBall.instantiate()
			"Fish":
				new_thing = Fish.instantiate()
			"Floater":
				new_thing = Floater.instantiate()
			"PlantA":
				new_thing = PlantA.instantiate()
			"Chair":
				new_thing = Chair.instantiate()
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
	thing("Ball", 1, Vector3(4, 1, -2))
	thing("Ball", 2, Vector3(4, 1, -2))
	thing("Fish", 1, Vector3(4, 1, -2))
	thing("Floater", 1, Vector3(20.3, 2.4, -3.1))

	# Plants
	#Spawn randomization bounds configured for 3
	#Will generate somewhat reasonably up to 20
	var plants_to_spawn: int = 3
	while plants_to_spawn > 0:
		var plant_position: Vector3 = Vector3(
			2.274 + RandomNumberGenerator.new().randf_range(-1.0, 1.0),
			0.5,
			-17.702 + RandomNumberGenerator.new().randf_range(-1.0, 1.0)
		)
		thing("PlantA", plants_to_spawn, plant_position)
		plants_to_spawn -= 1

	# Things to only spawn once, even if they go away
	# Things that can be picked up will disappear when picked up,
	# so they must not respawn then.
	if not done_once:
		done_once = true
		thing("Chair", 1, Vector3(8, 1, -8))
