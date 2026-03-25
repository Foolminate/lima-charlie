class_name Sitrep
extends Node

# SITREP Syntax:
# SQUAD:[ID|State] @[Zone] RALLY:[Point_A] ASSETS:[Sniper,Tank,Medic]
# VIS:[ObjID(Dist,Dir,Type,Status)]
# RESULT:[Success/Interrupt_Reason] (PREV_EXPECT:[String from last CMD])
static func compile(unit: Node2D, current_state: String, last_result: String, prev_expect: String) -> String:
	var sitrep: String = "<TOON>\n"

	# 1. SQUAD HEADER
	# TODO: Replace with data from GlobalBlackboard.
	var unit_id = unit.name
	sitrep += "SQUAD:[%s|%s] @[Sector_7] RALLY:[Alpha] ASSETS:[%s]\n" % [unit_id, current_state, unit_id]

	# 2. VISIBILITY (Perception Data)
	sitrep += "VIS:["
	var perception_node = unit.get_node_or_null("Perception")

	if perception_node and perception_node.detected_entities.size() > 0:
		var vis_strings: Array[String] = []
		for entity in perception_node.detected_entities:
			if not is_instance_valid(entity): continue

			# Assuming 30 pixels = 1 meter
			var dist_pixels = unit.global_position.distance_to(entity.global_position)
			var dist_meters = int(dist_pixels / 30.0)

			var dir = perception_node.get_cardinal_direction(entity.global_position)

			var type = "Hazard" if entity is Area2D else "Unknown"

			# Format: ObjID(Dist,Dir,Type,Status)
			# TODO: formalise object metadata and status
			vis_strings.append("%s(%dm,%s,%s,Active)" % [entity.name, dist_meters, dir, type])

		sitrep += ",".join(vis_strings)
	else:
		sitrep += "CLEAR"
	sitrep += "]\n"

	# 3. RESULT & REFLECTION
	sitrep += "RESULT:[%s] (PREV_EXPECT:[%s])\n" % [last_result, prev_expect]

	sitrep += "</TOON>"
	return sitrep
