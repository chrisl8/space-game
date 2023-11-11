extends Node

var Chair: Resource = preload("res://things/chair/chair.tscn")
var BeachBall: Resource = preload("res://things/beach_ball/beach_ball.tscn")
var Fish: Resource = preload("res://things/fish/fish.tscn")
var Floater: Resource = preload("res://things/Floater/Floater.tscn")
var PlantA: Resource = preload("res://things/plant_a/plant_a.tscn")
var done_once: bool = false

@onready var things_spawning_node: Node = get_node("../Main/Things")

# Called by players to ask Server to place a new chair.
@rpc("any_peer", "call_remote") func place_chair() -> void:
	if Globals.is_server:
		thing("Chair", 1)
		# TODO: I wish I could locate items when I create them, but I cannot. No idea why.
		# new_thing.position = Vector3(8, 1, -8)
		# new_thing.rotation.y = -45.0


func thing(thing_name: String, id: int) -> void:
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
				Helpers.log_print(str("Invalid thing to spawn name: ", thing_name), "red")
				return
		new_thing.name = str(thing_name_to_spawn)
		Helpers.log_print(str("spawning ", thing_name_to_spawn), "yellow")
		things_spawning_node.add_child(new_thing)


# This is ONLY called on the server, by the _process() function in network_websocket.gd
func things() -> void:
	# Balls
	thing("Ball", 1)
	thing("Ball", 2)
	thing("Fish", 1)
	thing("Floater", 1)

	# Only spawn the chair once, even if it goes away
	# so that it is not re-spawned when picked up
	if not done_once:
		done_once = true
		thing("Chair", 1)

	#Spawn randomization bounds configured for 3
	#Will generate somewhat reasonably up to 20
	var plants_to_spawn: int = 3
	while plants_to_spawn > 0:
		thing("PlantA", plants_to_spawn)
		plants_to_spawn -= 1
