extends Node

# Call the day you want to in the _ready() function.
# Within that day function you must set the puzzle_input variable to the input data.

# In order to maximize my likelihood of doing each one,
# I'm just racing to the answer, so I'm skipping niceties
# like reading data from a file and formatting it.
# I just use a text editor to replace the line breaks with \n
# and then using that to split the string into an array,
# because I find that super fast to do and it works well.

# Each line must be separated with a \n in the String, as I did not provide code to do that.


func _ready() -> void:
	Globals.advent_of_code_answer = advent_of_code_day_02()


func advent_of_code_day_01() -> String:
	var answer_text: String = "Day One:\n"
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
	answer_text = str(answer_text, "1: ", answer_one)

	# Part 2
	# Example from Part 2 Instructions:
	puzzle_input = "two1nine\neightwothree\nabcone2threexyz\nxtwone3four\n4nineeightseven2\nzoneight234\n7pqrstsixteen"  # Part 2 Example

	array_of_lines = puzzle_input.split("\n")
	# In this example, the calibration values are 29, 83, 13, 24, 42, 14, and 76. Adding these together produces 281.
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
	var answer_two: int = 0
	for line_value: int in list_of_line_values:
		answer_two += line_value
	answer_text = str(answer_text, "\n2: ", answer_two)
	return answer_text


func advent_of_code_day_02() -> String:
	var answer_text: String = "Day Two:\n"
	# Part 1 and 2
	# Example from instructions:
	var puzzle_input: String = "Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green\nGame 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue\nGame 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red\nGame 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red\nGame 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green"
	# if the bag contained only 12 red cubes, 13 green cubes, and 14 blue cubes
	# If you add up the IDs of the games that would have been possible, you get 8.
	# Part 1 Example Answer: 8
	# Part 2 Example Answer: 2286

	var max_red_cubes: int = 12
	var max_green_cubes: int = 13
	var max_blue_cubes: int = 14

	var array_of_lines: PackedStringArray = puzzle_input.split("\n")
	var answer_one: int = 0
	var answer_two: int = 0
	for line: String in array_of_lines:
		var game_id: int = int(line.split(":")[0].split(" ")[1])
		var game_is_valid: bool = true
		var min_red_cubes: int = 0
		var min_green_cubes: int = 0
		var min_blue_cubes: int = 0
		var handfuls: PackedStringArray = line.split(":")[1].split(";")
		for handful: String in handfuls:
			var color_count_strings: PackedStringArray = handful.split(",")
			for color_count_string: String in color_count_strings:
				var color_count: int = int(color_count_string.strip_edges().split(" ")[0])
				var color: String = color_count_string.strip_edges().split(" ")[1]
				match color:
					"red":
						if color_count > max_red_cubes:
							game_is_valid = false
						if color_count > min_red_cubes:
							min_red_cubes = color_count
					"green":
						if color_count > max_green_cubes:
							game_is_valid = false
						if color_count > min_green_cubes:
							min_green_cubes = color_count
					"blue":
						if color_count > max_blue_cubes:
							game_is_valid = false
						if color_count > min_blue_cubes:
							min_blue_cubes = color_count
		if game_is_valid:
			answer_one += game_id
		var minimum_set_power: int = min_red_cubes * min_green_cubes * min_blue_cubes
		answer_two += minimum_set_power
		print(
			game_id,
			" ",
			min_red_cubes,
			" ",
			min_green_cubes,
			" ",
			min_blue_cubes,
			" ",
			minimum_set_power
		)
	answer_text = str(answer_text, "1: ", answer_one, "\n2: ", answer_two)
	return answer_text
