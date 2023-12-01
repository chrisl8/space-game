extends Node


func _ready() -> void:
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
	var answer_one: int = 0
	for line_value: int in list_of_line_values:
		answer_one += line_value
	Globals.advent_of_code_answer = str(answer_one)
