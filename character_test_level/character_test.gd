extends Node3D

@export var capture_mouse_on_startup: bool = false  # This is actually annoying so I never turn it on.

var release_mouse_text: String = "ESC to Release Mouse"
var how_to_end_game_text: String = "END key to Close Game"


func _ready() -> void:
	if capture_mouse_on_startup and not Globals.is_server:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if OS.is_debug_build():
		release_mouse_text = "F1 to Release Mouse"
		how_to_end_game_text = "ESC to Close Game"

	if OS.get_name() != "Web":
		await get_tree().create_timer(5).timeout
		var toast = Toast.new(how_to_end_game_text, 2.0)
		get_node("/root").add_child(toast)
		toast.show()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		if OS.is_debug_build():
			# ESC key closes game in debug mode
			Helpers.quit_gracefully()
		else:  # Releases mouse in normal build
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed(&"ui_end"):
		# END key closes the game
		Helpers.quit_gracefully()

	# Only in Debug Mode: Use F1 to both Release and Capture the mouse for testing
	if (
		not Globals.is_server
		and event.is_action_pressed(&"change_mouse_input")
		and OS.is_debug_build()
	):
		match Input.get_mouse_mode():
			Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			Input.MOUSE_MODE_VISIBLE:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# Capture mouse if clicked on the game
# Called when an InputEvent hasn't been consumed by _input() or any GUI item
func _unhandled_input(event: InputEvent) -> void:
	if not Globals.is_server and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			await get_tree().create_timer(0.5).timeout
			#print("Mouse Mode: ", Input.get_mouse_mode())
			var text_to_toast: String = release_mouse_text
			if Input.get_mouse_mode() == 0:
				# Browsers have a cool down on capturing the mouse.
				# https://discourse.threejs.org/t/how-to-avoid-pointerlockcontrols-error/33017/4
				# So users may click, Esc, and then Click again too fast and it does not capture the mouse
				# This will let the user know that happened
				text_to_toast = "Oops, too fast, try again"
			var toast = Toast.new(text_to_toast, 2.0)
			get_node("/root").add_child(toast)
			toast.show()
