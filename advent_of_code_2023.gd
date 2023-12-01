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
	Globals.advent_of_code_answer = str(
		"Day One:\n", Globals.advent_of_code_answer, "\n1: ", answer_one
	)

	# Part 2
	# Example from Part 2 Instructions:
	puzzle_input = "two1nine\neightwothree\nabcone2threexyz\nxtwone3four\n4nineeightseven2\nzoneight234\n7pqrstsixteen"  # Part 2 Example

	array_of_lines = puzzle_input.split("\n")
	# In this example, the calibration values are 29, 83, 13, 24, 42, 14, and 76. Adding these together produces 281.
	# [0-9]|one|two|three|four|five|six|seven|eight|nine
	digit_regex.compile("[0-9]|one|two|three|four|five|six|seven|eight|nine")
	list_of_line_values.clear()
	for line: String in array_of_lines:
		var first_digit: String
		var last_digit: String
		var regex_matches: Array = digit_regex.search_all(line)
		for regex_match: RegExMatch in regex_matches:
			var digit_text: String = regex_match.get_string()
			match digit_text:
				"one":
					digit_text = "1"
				"two":
					digit_text = "2"
				"three":
					digit_text = "3"
				"four":
					digit_text = "4"
				"five":
					digit_text = "5"
				"six":
					digit_text = "6"
				"seven":
					digit_text = "7"
				"eight":
					digit_text = "8"
				"nine":
					digit_text = "9"
			if not first_digit:
				first_digit = digit_text
				last_digit = digit_text
			else:
				last_digit = digit_text
		list_of_line_values.append(int(str(first_digit, last_digit)))
		print(first_digit, " ", last_digit)
	var answer_two: int = 0
	for line_value: int in list_of_line_values:
		answer_two += line_value
	print(answer_two)
	Globals.advent_of_code_answer = str(Globals.advent_of_code_answer, "\n2: ", answer_two)
