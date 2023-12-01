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

# func _process(delta: float) -> void:
# 	screen_time += delta
# 	if screen_time > screen_update_interval:
# 		screen_time = 0
# 		screen_current_text += 1
# 		if screen_current_text > screen_text.size():
# 			screen_current_text = 1
# 		$ScreenText.text = screen_text[screen_current_text]


func _ready() -> void:
	if not Globals.is_server:
		advent_of_code_day_01()


func advent_of_code_day_01() -> void:
	# Part 1
	# Example from Part 1 instructions:
	var puzzle_input: String = "1abc2\npqr3stu8vwx\na1b2c3d4e5f\ntreb7uchet"
	# In this example, the calibration values of these four lines are 12, 38, 15, and 77. Adding these together produces 142.

	var array_of_lines: PackedStringArray = puzzle_input.split("\n")
	var digit_regex: RegEx = RegEx.new()
	digit_regex.compile("[0-9]")
	var list_of_line_values: Array = []
	for line: String in array_of_lines:
		var first_digit: String
		var last_digit: String
		for character: String in line:
			if digit_regex.search(character):
				if not first_digit:
					first_digit = character
					last_digit = character
				else:
					last_digit = character
		list_of_line_values.append(int(str(first_digit, last_digit)))
	var answer: int = 0
	for line_value: int in list_of_line_values:
		answer += line_value
	print(answer)
	$ScreenText.text = str(answer)

	# Part 2
	# Example from Part 2 Instructions:
	puzzle_input = "two1nine\neightwothree\nabcone2threexyz\nxtwone3four\n4nineeightseven2\nzoneight234\n7pqrstsixteen"  # Part 2 Example
	# In this example, the calibration values are 29, 83, 13, 24, 42, 14, and 76. Adding these together produces 281.
