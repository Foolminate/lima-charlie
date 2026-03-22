extends Node

# A reference to global game state

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

func register_intel(entity_id: String, entity_type: Tactical.Entity, location: Vector2, reporter: String, importance: Tactical.Importance = Tactical.Importance.LOW) -> void:
	tactical_memory[entity_id] = {
		"location": location,
		"type": entity_type,
		"reporter": reporter,
		"importance": importance,
		"timestamp": Time.get_ticks_msec()
	}
	intel_updated.emit(entity_id, entity_type, location, reporter)

# Called before compiling a SITREP, minimises TOON tokens by removing stale or low-importance intelligence.
func prune_stale_memory(max_base_age_msec: int) -> void:
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
