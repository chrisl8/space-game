extends Node

var done_once: bool = false
var Chair: Resource = preload("res://things/chair/chair.tscn")

@onready var things_spawning_node: Node = get_node("../Main/Things")

# Called by players to ask Server to place a new chair.
@rpc("any_peer", "call_remote") func place_chair() -> void:
	if Globals.is_server:
		var new_thing: Node = Chair.instantiate()
		# TODO: I wish I could locate items when I create them, but I cannot. No idea why.
		# new_thing.position = Vector3(8, 1, -8)
		# new_thing.rotation.y = -45.0
		things_spawning_node.add_child(new_thing, true)


func things() -> void:
	# Ball
	var thing_name_to_spawn: String = "Ball01"
	var BeachBall: Resource = preload("res://things/beach_ball/beach_ball.tscn")
	var existing_thing: Node = things_spawning_node.get_node_or_null(thing_name_to_spawn)
	if not existing_thing:
		var new_thing: Node = BeachBall.instantiate()
		new_thing.name = str(thing_name_to_spawn)
		Helpers.log_print(str("spawning ", thing_name_to_spawn))
		things_spawning_node.add_child(new_thing)

	thing_name_to_spawn = "Ball02"
	existing_thing = things_spawning_node.get_node_or_null(thing_name_to_spawn)
	if not existing_thing:
		var new_thing: Node = BeachBall.instantiate()
		new_thing.name = str(thing_name_to_spawn)
		Helpers.log_print(str("spawning ", thing_name_to_spawn))
		things_spawning_node.add_child(new_thing)

	# Spawn a test fish
	thing_name_to_spawn = "Fish"
	var Fish: Resource = preload("res://things/fish/fish.tscn")
	existing_thing = things_spawning_node.get_node_or_null(thing_name_to_spawn)
	if not existing_thing:
		var new_thing: Node = Fish.instantiate()
		new_thing.name = str(thing_name_to_spawn)
		Helpers.log_print(str("spawning ", thing_name_to_spawn))
		# new_thing.position = Vector3(4, 1, -2)
		things_spawning_node.add_child(new_thing)

	if not done_once:
		# TODO: During testing, insure this doesn't respawn when we "pick it up"
		done_once = true
		thing_name_to_spawn = "Chair01"
		existing_thing = things_spawning_node.get_node_or_null(thing_name_to_spawn)
		if not existing_thing:
			var new_thing: Node = Chair.instantiate()
			new_thing.name = str(thing_name_to_spawn)
			# TODO: I wish I could locate items when I create them, but I can't. No idea why.
			# new_thing.position = Vector3(8, 1, -8)
			# new_thing.rotation.y = -45.0
			things_spawning_node.add_child(new_thing)

	#Spawn randomization bounds configured for 3
	#Will generate somewhat reasonably up to 20
	var plants_to_spawn: int = 3

	var Plant: Resource = preload("res://things/plant_a/plant_a.tscn")
	while plants_to_spawn > 0:
		thing_name_to_spawn = "Plant_A" + str(plants_to_spawn)
		existing_thing = things_spawning_node.get_node_or_null(thing_name_to_spawn)
		if not existing_thing:
			var new_thing: Node = Plant.instantiate()
			new_thing.name = str(thing_name_to_spawn)
			things_spawning_node.add_child(new_thing)
		plants_to_spawn -= 1

	thing_name_to_spawn = "Floater"
	existing_thing = things_spawning_node.get_node_or_null(thing_name_to_spawn)
	var Floater: Resource = preload("res://things/Floater/Floater.tscn")
	if not existing_thing:
		var new_thing: Node = Floater.instantiate()
		new_thing.name = str(thing_name_to_spawn)
		things_spawning_node.add_child(new_thing)
