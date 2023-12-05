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
	if !Globals.is_server:
		# Server cannot see the text anyway
		Globals.advent_of_code_answer = str(
			Globals.advent_of_code_answer, "Day One:\n", advent_of_code_day_01(), "\n"
		)
		Globals.advent_of_code_answer = str(
			Globals.advent_of_code_answer, "Day Two:\n", advent_of_code_day_02(), "\n"
		)
		Globals.advent_of_code_answer = str(
			Globals.advent_of_code_answer, "Day Three:\n", advent_of_code_day_03(), "\n"
		)
		Globals.advent_of_code_answer = str(
			Globals.advent_of_code_answer, "Day Four:\n", advent_of_code_day_04(), "\n"
		)
		Globals.advent_of_code_answer = str(
			Globals.advent_of_code_answer, "Day Five:\n", advent_of_code_day_05(), "\n"
		)


func advent_of_code_day_01() -> String:
	var answer_text: String = ""
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
	var answer_text: String = ""
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
	answer_text = str(answer_text, "1: ", answer_one, "\n2: ", answer_two)
	return answer_text


func process_line_for_day_03(
	array_of_lines: PackedStringArray,
	gears: Dictionary,
	is_symbol_regex: RegEx,
	might_be_a_gear_regex: RegEx,
	line_index_to_search: int,
	starting_position: int,
	ending_position: int,
	part_number: int
) -> Dictionary:
	var result: Dictionary = {
		"number_is_valid": false,
	}
	for character_index: int in array_of_lines[line_index_to_search].length():
		if character_index >= starting_position and character_index < ending_position:
			if is_symbol_regex.search(array_of_lines[line_index_to_search][character_index]):
				result.number_is_valid = true
			if might_be_a_gear_regex.search(array_of_lines[line_index_to_search][character_index]):
				result.might_be_a_gear = true
				if not gears.has(str(line_index_to_search, "-", character_index)):
					gears[str(line_index_to_search, "-", character_index)] = [part_number]
				else:
					gears[str(line_index_to_search, "-", character_index)].append(part_number)
	return result


func advent_of_code_day_03() -> String:
	var answer_text: String = ""
	var puzzle_input: String = "467..114..\n...*......\n..35..633.\n......#...\n617*......\n.....+.58.\n..592.....\n......755.\n...$.*....\n.664.598.."
	var array_of_lines: PackedStringArray = puzzle_input.split("\n")

	var is_symbol_regex: RegEx = RegEx.new()
	is_symbol_regex.compile("\\*|#|\\$|\\+|/|&|%|@|-|=")

	var might_be_a_gear_regex: RegEx = RegEx.new()
	might_be_a_gear_regex.compile("\\*")

	var find_numbers_in_string: RegEx = RegEx.new()
	find_numbers_in_string.compile("[\\w\\d]+")

	var gears: Dictionary = {}

	var answer_one: int = 0

	for line_index: int in array_of_lines.size():
		var regex_matches: Array = find_numbers_in_string.search_all(array_of_lines[line_index])
		for regex_match: RegExMatch in regex_matches:
			var part_number: int = int(regex_match.get_string())
			var number_is_valid: bool = false
			var starting_position: int = regex_match.get_start() - 1
			if starting_position < 0:
				starting_position = 0
			var ending_position: int = regex_match.get_end() + 1
			var process_line_results: Dictionary
			if line_index > 0:
				process_line_results = process_line_for_day_03(
					array_of_lines,
					gears,
					is_symbol_regex,
					might_be_a_gear_regex,
					line_index - 1,
					starting_position,
					ending_position,
					part_number
				)
				if process_line_results.number_is_valid:
					number_is_valid = true

			process_line_results = process_line_for_day_03(
				array_of_lines,
				gears,
				is_symbol_regex,
				might_be_a_gear_regex,
				line_index,
				starting_position,
				ending_position,
				part_number
			)
			if process_line_results.number_is_valid:
				number_is_valid = true

			if array_of_lines.size() > line_index + 1:
				process_line_results = process_line_for_day_03(
					array_of_lines,
					gears,
					is_symbol_regex,
					might_be_a_gear_regex,
					line_index + 1,
					starting_position,
					ending_position,
					part_number
				)
				if process_line_results.number_is_valid:
					number_is_valid = true

			if number_is_valid:
				answer_one += part_number
	answer_text = str(answer_text, "1: ", answer_one)

	var answer_two: int = 0

	# Part 2, Process Gears
	for entry: String in gears:
		if gears[entry].size() > 1:
			answer_two += gears[entry][0] * gears[entry][1]

	answer_text = str(answer_text, "\n2: ", answer_two)
	return answer_text


func advent_of_code_day_04() -> String:
	var answer_text: String = ""
	var puzzle_input: String = "Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53\nCard 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19\nCard 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1\nCard 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83\nCard 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36\nCard 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11"
	var array_of_lines: PackedStringArray = puzzle_input.split("\n")

	# Part 1
	var answer_one: int = 0
	for line: String in array_of_lines:
		var row_score: int = 0
		var card_number_groups: PackedStringArray = line.replace("  ", " ").split(":")[1].split("|")
		var winning_numbers: PackedStringArray = card_number_groups[0].strip_edges().split(" ")
		var had_numbers: PackedStringArray = card_number_groups[1].strip_edges().split(" ")
		for winning_number: String in winning_numbers:
			for had_number: String in had_numbers:
				if had_number == winning_number:
					if row_score > 0:
						row_score = row_score * 2
					else:
						row_score = 1
		answer_one += row_score
	answer_text = str(answer_text, "1: ", answer_one)

	# Part 2 - This is madness
	var card_data: Dictionary = {}
	var highest_card_data_entry: int = 0
	for line: String in array_of_lines:
		var row_winning_number_count: int = 0
		var card_id_array: Array = line.split(":")[0].strip_edges().split(" ")
		var card_id: int = int(card_id_array[card_id_array.size() - 1])
		var card_number_groups: PackedStringArray = line.replace("  ", " ").split(":")[1].split("|")
		var winning_numbers: PackedStringArray = card_number_groups[0].strip_edges().split(" ")
		var had_numbers: PackedStringArray = card_number_groups[1].strip_edges().split(" ")
		for winning_number: String in winning_numbers:
			for had_number: String in had_numbers:
				if had_number == winning_number:
					row_winning_number_count += 1
		card_data[card_id] = {
			"winning_numbers": winning_numbers,
			"had_numbers": had_numbers,
			"card_count": 1,
			"winning_number_count": row_winning_number_count
		}
		highest_card_data_entry = card_id
	for entry: int in range(1, highest_card_data_entry + 1):
		if card_data[entry].winning_number_count > 0:
			for i: int in range(1, card_data[entry].card_count + 1):
				for j: int in range(1, card_data[entry].winning_number_count + 1):
					if card_data.has(entry + j):
						card_data[entry + j].card_count = card_data[entry + j].card_count + 1

	# Count the cards
	var answer_two: int = 0
	for entry: int in card_data:
		answer_two += card_data[entry].card_count
	answer_text = str(answer_text, "\n2: ", answer_two)
	return answer_text


# See https://github.com/winston-yallow/aoc-godot/blob/main/addons/aoc/dock.gd
func get_data_for_day(day: int) -> String:
	var input_path: String = "res://advent_of_code_2023/day_%d_input.txt" % day
	if FileAccess.file_exists(input_path):
		var input_file: FileAccess = FileAccess.open(input_path, FileAccess.READ)
		return input_file.get_as_text()

	return ""


func advent_of_code_day_05() -> String:
	var answer_text: String = ""
	var puzzle_input: String = get_data_for_day(5)
	print(puzzle_input.split("\r\n"))

	var array_of_lines: PackedStringArray = puzzle_input.split("\n")

	var answer_one: int = 0

	answer_text = str(answer_text, "1: ", answer_one)

	var answer_two: int = 0

	answer_text = str(answer_text, "\n2: ", answer_two)
	return answer_text
