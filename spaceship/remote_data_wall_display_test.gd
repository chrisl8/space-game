extends Label3D

@rpc("any_peer", "call_remote")
func send_remote_admin_wall_text(text_from_server: String) -> void:
	text = text_from_server