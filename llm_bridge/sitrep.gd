class_name Sitrep
extends Node

# Builds a squad's structured situation report string, based on member states and perception data.
static func compile(unit: Node2D) -> String:
	var squad: Dictionary = GlobalBlackboard.squads.get(unit.squad, null)
	if squad == null: return ""

	var sitrep: String = ""
	var objective_vector: String = get_semantic_vector(unit.global_position, squad["objective_location"])

	# 1. SQUAD HEADER
	sitrep += "SQUAD:%s | @%s | RALLY:%s\n" % [unit.squad, squad["location"], squad["rally_point"]]
	sitrep += "OBJECTIVE:1.%s:%s | 2.%s:%s | 3.%s\n" % [squad["last_objective"], squad["objective_status"], squad["current_objective"], objective_vector, squad["next_objective"]]
	sitrep += "DOCTRINE:%s\n" % squad["doctrine"]
	sitrep += "PREVIOUS:%s | EXPECT:%s | RESULT:%s\n\n" % [squad["previous_command"], squad["expectation"], squad["outcome"]]

	# 2. SQUAD STATUS
	# |ID| HEALTH | AMMO | STATUS | TAGS/SKILLS |
	sitrep += "| ID | HEALTH | AMMO | STATUS | TAGS/SKILLS |\n|---|---|---|---|---|\n"
	for member in squad["members"]:
		sitrep += "| %s | %d | %s | %s | %s |\n" % [member.id, member.health, "High", member.get_status(), member.tags]

	# 2. VISIBILITY (Perception Data)
	# | ID | VECTOR | LOS | STATUS | TAGS |
	sitrep += "\n| ID | VECTOR | LOS | STATUS | TAGS |\n|---|---|---|---|---|\n"
	var memory: Dictionary = GlobalBlackboard.tactical_memory
	var entities: String = ""

	for entity_id in memory.keys():
		var entity_info = memory[entity_id]
		var entity = entity_info["node_ref"].get_ref()

		if entity_info["is_visible"]:
			entities += "| %s | %s | Visible | %s | %s |\n" % [
				entity_id,
				get_semantic_vector(unit.global_position, entity.global_position),
				entity.status,
				entity.get_tags(),
			]
		if not entity_info["is_visible"]:
			var elapsed_time: int = ceil((Time.get_ticks_msec() - entity_info["intel_seen"]) / 1000.0)

			entities += "| %s | %s | %s | %s | %s |\n" % [
				entity_id,
				get_semantic_vector(unit.global_position, entity_info["last_position"]),
				str(elapsed_time) + "s",
				entity_info["status"],
				entity_info["last_tags"],
			]

	if entities == "":
		sitrep += "| None | | | | |\n"
	else:
		sitrep += entities

	return sitrep

static func get_semantic_vector(from_pos: Vector2, to_pos: Vector2) -> String:
	var dir: String = get_cardinal_direction(from_pos, to_pos)
	var dist_pixels: float = from_pos.distance_to(to_pos)
	var dist_meters: int = int(dist_pixels / 30.0) # Assuming 30 pixels = 1 meter
	return "%s_%dm" % [dir, dist_meters]

static func get_cardinal_direction(from_pos: Vector2, to_pos: Vector2) -> String:
	var angle: float = from_pos.direction_to(to_pos).angle()

	# Evaluate clockwise from negative PI (West) wrapping around to positive PI (West)
	if angle < -7 * PI / 8 or angle > 7 * PI / 8: return "W"
	if angle < -5 * PI / 8: return "NW"
	if angle < -3 * PI / 8: return  "N"
	if angle <     -PI / 8: return "NE"
	if angle <      PI / 8: return  "E"
	if angle <  3 * PI / 8: return "SE"
	if angle <  5 * PI / 8: return  "S"

	return "SW"