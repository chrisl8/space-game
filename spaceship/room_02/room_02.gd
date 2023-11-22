extends Node3D

var screen_text: Dictionary = {
	1: "The vending machine is now stocked.",
	2: "Today's special: FISH!",
	3: "Watch your head when using the vending machine.",
	4: "Spare chairs and balls now available in the vending machine."
}
var screen_current_text: int = 0
var screen_update_interval: int = 10
var screen_time: float = screen_update_interval


func _process(delta: float) -> void:
	screen_time += delta
	if screen_time > screen_update_interval:
		screen_time = 0
		screen_current_text += 1
		if screen_current_text > screen_text.size():
			screen_current_text = 1
		get_node("Screen Text").text = screen_text[screen_current_text]
