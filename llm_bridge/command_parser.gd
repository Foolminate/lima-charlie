class_name CommandParser
extends Node

## Parses the isolated <COMMAND> block string into executable FSM data.
static func parse_command(command_string: String) -> Dictionary:
	var result = {
		"is_valid": true,
		"orders": [],
		"expect": "",
		"bark": "",
		"errors": ""
	}

	var errors: Array[String] = []
	var lines = command_string.strip_edges().split("\n", false)
	var found_order = false

	for line in lines:
		var clean_line = line.strip_edges()
		if clean_line.is_empty():
			continue

		if clean_line.begins_with("EXPECT:"):
			result["expect"] = clean_line.trim_prefix("EXPECT:").strip_edges()
		elif clean_line.begins_with("BARK:"):
			result["bark"] = clean_line.trim_prefix("BARK:").strip_edges()
		elif "|" in clean_line:
			found_order = true
			var parsed_order = _parse_order(clean_line)

			if parsed_order.has("errors"):
				# Accumulate ALL errors found in this specific line
				errors.append_array(parsed_order["errors"])
			else:
				result["orders"].append(parsed_order["components"])

	# Exhaustive checks for omissions across the whole block
	if not found_order:
		errors.append("MISSING:ORDER")

	if result["expect"].is_empty():
		errors.append("MISSING:EXPECT")

	if result["bark"].is_empty():
		errors.append("MISSING:BARK")

	# Compile final result
	if not errors.is_empty():
		result["is_valid"] = false
		result["errors"] = "ERRORS: " + " | ".join(errors)

	return result

## Helper: Slices a line exhaustively and returns either {"data": dict} OR {"errors": Array}
static func _parse_order(line: String) -> Dictionary:
	var components = {}
	var errors: Array[String] = []
	var segments = line.split("|")

	for segment in segments:
		var kvp = segment.split(":")

		if kvp.size() == 2:
			var key = kvp[0].strip_edges().to_lower()
			var value = kvp[1].strip_edges()
			components[key] = value
		else:
			errors.append("SYNTAX:" + segment.strip_edges())

	# Exhaustively check all required keys against whatever valid data was parsed
	var required_keys = ["unit", "action", "target", "skill", "doctrine"]
	for req in required_keys:
		if not components.has(req):
			errors.append("MISSING:" + req.to_upper())

	if not errors.is_empty():
		return {"errors": errors}

	return {"components": components}