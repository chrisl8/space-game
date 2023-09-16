extends Node

var ws: WebSocketPeer = WebSocketPeer.new()
var url: String = "wss://voidshipephemeral.space/server/"
var websocket_client_connected: bool = false
var websocket_close_reason: String = ""

signal reset
signal close_popup

var connection_list: Dictionary = {}
var ready_to_connect: bool = false
var server_message_sent: bool = false
var username_sent: bool = false
var server_id_string: String
var server_id: int = -1:
	set(value):
		server_id = value
		get_tree().get_root().get_node("Main/LevelSpawner").set_multiplayer_authority(value)
		get_tree().get_root().get_node("Main/PlayersSpawner").set_multiplayer_authority(value)
		get_tree().get_root().get_node("Main/ThingSpawner").set_multiplayer_authority(value)
var peers: Dictionary
var peer_count: int = -1
var peers_have_connected: bool = false
var network_initialized: bool = false
var game_started: bool = false
var game_scene_initialize_in_progress: bool = false
var game_scene_initialized: bool = false
var signalling_server_connection
var network_connection_initiated: bool = false

var player_character_template: PackedScene = preload("res://player/player.tscn")
var level_scene: PackedScene = preload("res://spaceship/spaceship.tscn")

var websocket_multiplayer_peer: WebSocketMultiplayerPeer

@export var player_spawn_point: Vector3 = Vector3(4, 1, -4)


func _init():
	if OS.is_debug_build():
		url = "ws://127.0.0.1:9090"


func _process(_delta) -> void:
	if not ready_to_connect:
		return

	if not network_connection_initiated:
		network_connection_initiated = true
		init_network()

	if not network_initialized:
		return

	if peers.size() != peer_count:
		peer_count = peers.size()
		if peer_count > 0:
			peers_have_connected = true
		Helpers.log_print(str("New peer count is: ", peer_count))

	if not Globals.is_server:
		# Only server adds and removes objects
		return

	# In Debug mode, exit server if everyone disconnects
	if OS.is_debug_build() and peers_have_connected and peer_count < 1:
		Helpers.log_print(
			"Closing server due to all clients disconnecting and this running in Debug mode."
		)
		get_tree().quit()  # Quits the game

	# Initialize the Level if it isn't yet
	if not game_scene_initialized:
		if not game_scene_initialize_in_progress:
			# Helpers.log_print("Load level")
			game_scene_initialize_in_progress = true
			load_level.call_deferred(level_scene)
		elif get_node_or_null("../Main/Level/game_scene"):
			game_scene_initialized = true
		return

	Spawner.things()


func _ready():
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)


func load_level(scene: PackedScene):
	# Helpers.log_print("Loading Scene")
	var level_parent: Node = get_tree().get_root().get_node("Main/Level")
	for c in level_parent.get_children():
		level_parent.remove_child(c)
		c.queue_free()
	#level_parent.set_multiplayer_authority(server_id, true)
	var game_scene = scene.instantiate()
	game_scene.name = "game_scene"
	level_parent.add_child(game_scene)


func _peer_connected(id):
	# In WebSocket this only happens on the server.
	Helpers.log_print(str("Peer ", id, " connected."))
	peers[id] = {}
	if Globals.is_server and id > 1:
		var character = player_character_template.instantiate()
		character.player = id  # Set player id.
		# Randomize character position.
		var pos: Vector2 = Vector2.from_angle(randf() * 2 * PI)
		const SPAWN_RANDOM: float = 2.0
		character.position = Vector3(
			player_spawn_point.x + (pos.x * SPAWN_RANDOM * randf()),
			player_spawn_point.y,
			player_spawn_point.z + (pos.y * SPAWN_RANDOM * randf())
		)
		character.name = str(id)
		get_node("../Main/Players").add_child(character, true)
		character.set_multiplayer_authority(character.player)


func _peer_disconnected(id) -> void:
	Helpers.log_print(str("Peer ", id, " Disconnected."))
	if peers.has(id):
		peers.erase(id)
	if not Globals.is_server:
		return
	var player_spawner_node: Node = get_node_or_null("../Main/Players")
	if player_spawner_node and player_spawner_node.has_node(str(id)):
		player_spawner_node.get_node(str(id)).queue_free()


func _connected_to_server():
	Helpers.log_print("I connected to the server!")
	close_popup.emit()


func _connection_failed():
	Helpers.log_print("My connection failed. =(")
	reset_connection()


func _server_disconnected():
	Helpers.log_print("Server Disconnected")
	reset_connection()


func reset_connection():
	Helpers.log_print("Reset Connection")
	network_initialized = false
	game_scene_initialized = false
	game_scene_initialize_in_progress = false
	multiplayer.multiplayer_peer = null
	websocket_multiplayer_peer = null
	peers.clear()
	peer_count = -1

	for connection in connection_list.values():
		connection.close()

	Globals.user_name = ""
	Globals.player_id = -1
	peers.clear()
	reset.emit(5)


func init_network():
	Helpers.log_print("Init Network")
	websocket_multiplayer_peer = WebSocketMultiplayerPeer.new()
	# This is a client/server setup, NOT a Mesh.
	if Globals.is_server:
		websocket_multiplayer_peer.create_server(9090)
	else:
		var error: int = websocket_multiplayer_peer.create_client(url)  # WebSocket
		if error:
			Helpers.log_print(error)
	get_tree().get_multiplayer().multiplayer_peer = websocket_multiplayer_peer
	close_popup.emit()
	network_initialized = true
