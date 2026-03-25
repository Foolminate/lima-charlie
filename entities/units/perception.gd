extends Area2D

var detected_entities: Array[Node] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _process(_delta: float) -> void:
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body != owner:
		var dir: String = get_cardinal_direction(body.global_position)
		print("PERCEPTION: Detected %s at %s" % [body.name, dir])
		detected_entities.append(body)

func _on_body_exited(body: Node2D) -> void:
	detected_entities.erase(body)

func _on_area_entered(area: Area2D) -> void:
	var dir: String = get_cardinal_direction(area.global_position)
	print("PERCEPTION: Detected %s at %s" % [area.name, dir])
	detected_entities.append(area)
	print(Sitrep.compile(owner,owner.fsm.State.keys()[owner.fsm.current_state], "Success", "Reach destination undetected"))

func _on_area_exited(area: Area2D) -> void:
	detected_entities.erase(area)

func get_cardinal_direction(target_global_pos: Vector2) -> String:
	var angle: float = global_position.direction_to(target_global_pos).angle()

	# Evaluate clockwise from negative PI (West) wrapping around to positive PI (West)
	if angle < -7 * PI / 8 or angle > 7 * PI / 8: return "W"
	if angle < -5 * PI / 8: return "NW"
	if angle < -3 * PI / 8: return  "N"
	if angle <     -PI / 8: return "NE"
	if angle <      PI / 8: return  "E"
	if angle <  3 * PI / 8: return "SE"
	if angle <  5 * PI / 8: return  "S"

	return "SW"

# --- Debug visualization --- #
func _draw() -> void:
	# Visualize the perception area for debugging
	var vision_radius: float = $CollisionShape2D.shape.radius
	draw_circle(Vector2.ZERO, vision_radius, Color(0.2, 0.8, 0.2, 0.1))
	draw_arc(Vector2.ZERO, vision_radius, 0, TAU, 32, Color(0.2, 0.8, 0.2, 0.5), 1.0)

	# Draw lines to detected entities
	for entity in detected_entities:
		if not is_instance_valid(entity): continue

		draw_line(Vector2.ZERO, to_local(entity.global_position), Color(0.8, 0.2, 0.2, 0.5), 2.0)
