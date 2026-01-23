# Copied from https://github.com/godotengine/godot-demo-projects/tree/master/networking/websocket_chat/websocket
class_name RemoteAdmin
extends Node

@export var handshake_headers: PackedStringArray
@export var supported_protocols: PackedStringArray
var tls_options: TLSOptions = null

var socket := WebSocketPeer.new()
var last_state := WebSocketPeer.STATE_CLOSED

signal connected_to_server()
signal connection_closed()
signal message_received(message: Variant)

func connect_to_url(url: String) -> int:
	Helpers.log_print("Remote Admin: Connecting to url: " + url, "purple")

	var err := socket.connect_to_url(url, tls_options)
	if err != OK:
		Helpers.log_print("Remote Admin: Error connecting to url: " + url + " with error: " + str(err), "red")
		return err

	last_state = socket.get_ready_state()
	Helpers.log_print("Remote Admin: Connection State: " + _state_to_string(last_state), "purple")
	return OK


func send(message: String) -> int:
	if typeof(message) == TYPE_STRING:
		return socket.send_text(message)
	return socket.send(var_to_bytes(message))


func get_message() -> Variant:
	if socket.get_available_packet_count() < 1:
		return null
	var pkt := socket.get_packet()
	if socket.was_string_packet():
		var message: String = pkt.get_string_from_utf8()
		Helpers.log_print("Remote Admin: Received message: " + message, "purple")
		update_remote_admin_screen_strings.rpc("panel_testing", message)
		return message
	return bytes_to_var(pkt)


func close(code: int = 1000, reason: String = "") -> void:
	socket.close(code, reason)
	last_state = socket.get_ready_state()


func clear() -> void:
	socket = WebSocketPeer.new()
	last_state = socket.get_ready_state()


func get_socket() -> WebSocketPeer:
	return socket


func _state_to_string(state: int) -> String:
	match state:
		WebSocketPeer.STATE_CONNECTING:
			return "CONNECTING"
		WebSocketPeer.STATE_OPEN:
			return "OPEN"
		WebSocketPeer.STATE_CLOSING:
			return "CLOSING"
		WebSocketPeer.STATE_CLOSED:
			return "CLOSED"
		_:
			return "UNKNOWN"

func poll() -> void:
	var state := socket.get_ready_state()

	if last_state != state:
		Helpers.log_print("Remote Admin: Connection State changed from " + _state_to_string(last_state) + " to " + _state_to_string(state), "purple")
		last_state = state
		if state == socket.STATE_OPEN:
			connected_to_server.emit()
		elif state == socket.STATE_CLOSED:
			connection_closed.emit()

	if state != socket.STATE_CLOSED:
		socket.poll()


	while socket.get_ready_state() == socket.STATE_OPEN and socket.get_available_packet_count():
		message_received.emit(get_message())


func _process(_delta: float) -> void:
	poll()

func disable_permanently() -> void:
	# Used to disable this entire process on clients for performance reasons
	set_process(false)

@rpc("any_peer", "call_remote")
func update_remote_admin_screen_strings(entry_name: String, text: String) -> void:
	var json: JSON = JSON.new()
	var error: int = json.parse(text)
	if error != OK:
		Helpers.log_print("Remote Admin: Error parsing JSON: " + json.error_string, "red")
		return
	var data: Dictionary = json.get_data()
	Globals.remote_admin_screen_strings[entry_name]["data"] = data
	Globals.remote_admin_screen_strings[entry_name]["screen_text"] = "We got data!"
