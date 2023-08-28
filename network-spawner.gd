extends Node

# Check if this is the first instance of a debug run, so only one attempts to be the server
# https://gist.github.com/CrankyBunny/71316e7af809d7d4cf5ec6e2369a30b9
var instance_num                            := -1
var peers: Dictionary
var peer_count                              := -1
var is_server: bool                         =  false
var local_debug_instance_number             := -1
var network_initialized: bool               =  false
var game_scene_initialized: bool            =  false
var game_scene_initialize_in_progress: bool =  false
var player_character_template               := preload("res://player/player.tscn")
var level_scene                             := preload("res://spaceship/spaceship.tscn")
var url := "ws://127.0.0.1:9080"
#var url := "wss://voidshipephemeral.space/server/"
#var rtc_peer: ENetMultiplayerPeer # ENet
var rtc_peer: WebSocketMultiplayerPeer # WebSocket
signal reset
signal close_popup

@export var player_spawn_point := Vector3(4,1,-4)


func _init():
	if not OS.is_debug_build():
		# NEVER use local IP in release
		url = "wss://voidshipephemeral.space/server/"

func _ready():
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)

func _process(_delta) -> void:
	if not network_initialized:
		return

	if peers.size() != peer_count:
		peer_count = peers.size()
		print(multiplayer.get_unique_id(), " New peer count is: ", peer_count)

	if not User.is_server:
		# Only server adds and removes objects
		return

	# Initialize the Level if it isn't yet
	if not game_scene_initialized:
		if not game_scene_initialize_in_progress:
			game_scene_initialize_in_progress = true
			load_level.call_deferred(level_scene)
		elif get_node_or_null("../Main/Level/game_scene"):
			game_scene_initialized = true
		return

	spawn_things()

func load_level(scene: PackedScene):
	print("%d Loading Scene" % [multiplayer.get_unique_id()])
	var level_parent := get_tree().get_root().get_node("Main/Level")
	for c in level_parent.get_children():
		level_parent.remove_child(c)
		c.queue_free()
	#level_parent.set_multiplayer_authority(server_id, true)
	var game_scene = scene.instantiate()
	game_scene.name = "game_scene"
	level_parent.add_child(game_scene)

func _peer_connected(id):
	print("%d: Peer %d connected." % [multiplayer.get_unique_id(), id])
	if User.is_server and id > 1:
		var character = player_character_template.instantiate()
		character.player = id # Set player id.
		# Randomize character position.
		var pos := Vector2.from_angle(randf() * 2 * PI)
		const SPAWN_RANDOM := 2.0
		character.position = Vector3(player_spawn_point.x + (pos.x * SPAWN_RANDOM * randf()), player_spawn_point.y, player_spawn_point.z + (pos.y * SPAWN_RANDOM * randf()))
		character.name = str(id)
		#$Players.add_child(character, true)
		get_node("../Main/Players").add_child(character, true)

func _peer_disconnected(id) -> void:
	print("%d: Peer %d Disconnected." % [multiplayer.get_unique_id(), id])
	if not User.is_server:
		return
	var player_spawner_node := get_node_or_null("../Main/Players")
	if player_spawner_node and player_spawner_node.has_node(str(id)):
		player_spawner_node.get_node(str(id)).queue_free()

func _connected_to_server():
	print("%d: I connected to the server!" % [multiplayer.get_unique_id()])
	close_popup.emit()

func _connection_failed():
	print("%d: My connection failed. =(" % [multiplayer.get_unique_id()])
	reset_connection()

func _server_disconnected():
	print("%d: Server Disconnected" % [multiplayer.get_unique_id()])
	reset_connection()

func reset_connection():
	network_initialized = false
	game_scene_initialized = false
	game_scene_initialize_in_progress = false
	multiplayer.multiplayer_peer = null
	rtc_peer = null
	peers.clear()
	peer_count = -1
	reset.emit(5)

func init_connection():
	print("Connecting!")
	#rtc_peer = ENetMultiplayerPeer.new() # ENet
	rtc_peer = WebSocketMultiplayerPeer.new() # WebSocket

	multiplayer.multiplayer_peer = null
	if User.is_server:
		rtc_peer.create_server(9080)
		# Server is born ready
		network_initialized = true
	else:
		#rtc_peer.create_client('127.0.0.1', 9080) # ENet
		var error := rtc_peer.create_client(url) # WebSocket
		if error:
			print(error)
	close_popup.emit()
	multiplayer.multiplayer_peer = rtc_peer


func spawn_things():
	# Ball
	var thing_name_to_spawn := "Ball01"
	var things_spawning_node := get_node("../Main/Things")
	var beach_ball := preload("res://things/beach_ball/beach_ball.tscn")
	var existing_thing := things_spawning_node.get_node_or_null(thing_name_to_spawn)
	if not existing_thing:
		var new_thing = beach_ball.instantiate()
		new_thing.name = str(thing_name_to_spawn)
		things_spawning_node.add_child(new_thing)

	thing_name_to_spawn = "Ball02"
	existing_thing = things_spawning_node.get_node_or_null(thing_name_to_spawn)
	if not existing_thing:
		var new_thing = beach_ball.instantiate()
		new_thing.name = str(thing_name_to_spawn)
		things_spawning_node.add_child(new_thing)

	thing_name_to_spawn = "Chair01"
	existing_thing = things_spawning_node.get_node_or_null(thing_name_to_spawn)
	var chair := preload("res://things/chair/chair.tscn")
	if not existing_thing:
		var new_thing = chair.instantiate()
		new_thing.name = str(thing_name_to_spawn)
		things_spawning_node.add_child(new_thing)
