extends Node

@onready var things_spawning_node: Node = get_node("../Main/Things")

var done_once: bool = false

# Called by players to ask Server to place a new chair.
@rpc("any_peer", "call_remote") func place_chair() -> void:
	if Globals.is_server:
		var chair: Resource = preload("res://things/chair/chair.tscn")
		var new_thing = chair.instantiate()
		# TODO: I wish I could locate items when I create them, but I cannnot. No idea why.
		# new_thing.position = Vector3(8, 1, -8)
		# new_thing.rotation.y = -45.0
		things_spawning_node.add_child(new_thing, true)


func things():
	# Ball
	var thing_name_to_spawn: String = "Ball01"
	var beach_ball: Resource = preload("res://things/beach_ball/beach_ball.tscn")
	var existing_thing: Node = things_spawning_node.get_node_or_null(thing_name_to_spawn)
	if not existing_thing:
		var new_thing = beach_ball.instantiate()
		new_thing.name = str(thing_name_to_spawn)
		Helpers.log_print(str("spawning ", thing_name_to_spawn))
		things_spawning_node.add_child(new_thing)

	thing_name_to_spawn = "Ball02"
	existing_thing = things_spawning_node.get_node_or_null(thing_name_to_spawn)
	if not existing_thing:
		var new_thing = beach_ball.instantiate()
		new_thing.name = str(thing_name_to_spawn)

		Helpers.log_print(str("spawning ", thing_name_to_spawn))

		things_spawning_node.add_child(new_thing)

	if not done_once:
		# TODO: During testing, insure this doesn't respawn when we "pick it up"
		done_once = true
		thing_name_to_spawn = "Chair01"
		existing_thing = things_spawning_node.get_node_or_null(thing_name_to_spawn)
		var chair: Resource = preload("res://things/chair/chair.tscn")
		if not existing_thing:
			var new_thing = chair.instantiate()
			new_thing.name = str(thing_name_to_spawn)
			# TODO: I wish I could locate items when I create them, but I can't. No idea why.
			# new_thing.position = Vector3(8, 1, -8)
			# new_thing.rotation.y = -45.0
			things_spawning_node.add_child(new_thing)

	#Spawn randomization bounds configured for 3
	#Will generate somewhat reasonably up to 20
	var PlantsToSpawn: int = 3

	var plant_a: Resource = preload("res://things/plant_a/plant_a.tscn")
	while PlantsToSpawn > 0:
		thing_name_to_spawn = "Plant_A" + str(PlantsToSpawn)
		existing_thing = things_spawning_node.get_node_or_null(thing_name_to_spawn)
		if not existing_thing:
			var new_thing = plant_a.instantiate()
			new_thing.name = str(thing_name_to_spawn)
			things_spawning_node.add_child(new_thing)
		PlantsToSpawn -= 1
		
	thing_name_to_spawn = "Floater"
	existing_thing = things_spawning_node.get_node_or_null(thing_name_to_spawn)
	var Floater: Resource = preload("res://things/Floater/Floater.tscn")
	if not existing_thing:
		var new_thing = Floater.instantiate()
		new_thing.name = str(thing_name_to_spawn)
		things_spawning_node.add_child(new_thing)
