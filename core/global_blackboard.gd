extends Node

# A reference to global game state

# Squads format:
# {
#   "id": {
#     "members": Array[Node2D],
#     "location": String,
#     "rally_point": String,
#     "last_objective": String,
#     "objective_status": String,
#     "current_objective": String,
#     "objective_location": Vector2,
#     "doctrine": String,
#     "previous_command": String,
#     "expectation": String,
#     "outcome": String
#   }
# }
var squads: Dictionary = {}

# Stores known entities (Threats, POIs, Assets).
# Format: { "entity_id": { "location": Vector2, "type": EntityType, "reporter": String } }
var tactical_memory: Dictionary = {}

# Stores mission objectives and their statuses. Format: { "objective_id": "status" }
var mission_objectives: Dictionary = {}

signal intel_updated(entity_id: String, entity_type: Tactical.Entity, location: Vector2, reporter: String)
signal objective_updated(objective_id: String, status: String)

func update_objective(objective_id: String, status: String) -> void:
	mission_objectives[objective_id] = status
	objective_updated.emit(objective_id, status)

func register_intel(entity: Node2D) -> void:
	tactical_memory[entity.id] = {
		"node_ref": weakref(entity),
		"is_visible": true,
		"type": entity.type,
		"status": "",
		"last_tags": "",
		"last_position": Vector2.ZERO,
		"intel_seen": 0.0,
	}

	intel_updated.emit(entity.id)

func persist_intel(entity) -> void:
	var entity_id: String = entity.id
	var memory = tactical_memory.get(entity_id, null)
	if memory == null: return

	memory["is_visible"] = false
	memory["status"] = entity.status
	memory["last_tags"] = entity.get_tags()
	memory["last_position"] = entity.global_position
	memory["intel_seen"] = Time.get_ticks_msec()

# Called before compiling a SITREP, minimises TOON tokens by removing stale or low-importance intelligence.
func prune_stale_memory(max_base_age_msec: int = 300_000) -> void:
	var current_time = Time.get_ticks_msec()
	var keys_to_remove = []

	for key in tactical_memory.keys():
		var memory = tactical_memory[key]
		var age = current_time - memory["timestamp"]
		var age_threshold = max_base_age_msec * memory["importance"]

		if age > age_threshold and memory["importance"] != Tactical.Importance.CRITICAL:
			keys_to_remove.append(key)

	for key in keys_to_remove:
		tactical_memory.erase(key)

# Returns a dictionary of known entities by type, useful for prompt injection and decision-making.
func get_memory_by_type(target_type: Tactical.Entity) -> Dictionary:
	var filtered_memory = {}
	for key in tactical_memory.keys():
		if tactical_memory[key]["type"] == target_type:
			filtered_memory[key] = tactical_memory[key]
	return filtered_memory
