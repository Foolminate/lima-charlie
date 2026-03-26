extends CharacterBody2D

@export var id: String = "viper_1"
@export var squad: String = "ALPHA"
@export var type: String = "TacticalUnit"
@export var health: int = 100
@export var tags: String = "Rifleman, Stealth, SKL:DISARM"
@export var movement_speed: float = 150.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var state_label: Label = $DebugCanvas/StateLabel
@onready var expect_label: Label = $DebugCanvas/ExpectLabel
@onready var fsm: UnitFSM = $UnitFSM
# {
#   "squad_id": {
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
func _ready() -> void:
	call_deferred("_actor_setup")
	fsm.state_changed.connect(_on_state_changed)
	var squad_data: Variant = GlobalBlackboard.squads.get(squad, null)

	if squad_data != null:
		squad_data["members"].append(self)
		return

	# TODO: create an object for this nonsense.
	squad_data = {
		"members": [self],
		"location": "Sector_7",
		"rally_point": "Point_A",
		"last_objective": "Infiltrate_Compound",
		"objective_status": "SUCCESS",
		"current_objective": "Defuse_Bomb",
		"objective_location": Vector2(500, -200),
		"next_objective": "Extract_VIP",
		"doctrine": "STEALTH",
		"previous_command": "MOVE",
		"expectation": "Approach the objective without breaking stealth",
		"outcome": "SUCCESS",
	}

	GlobalBlackboard.squads[squad] = squad_data

func _physics_process(_delta: float) -> void:
	# Stop if we've reached the target
	if fsm.current_state != fsm.State.EXECUTING or nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	# Calculate the direction to the next point in the path
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	velocity = global_position.direction_to(next_pos) * movement_speed
	sprite.rotation = velocity.angle()

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	# Listen for Left Mouse Button clicks
	if (event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed):

		_set_movement_target(get_global_mouse_position())

func trigger_hazard(hazard: Node) -> void:
	print("UNIT: interrupted by %s" % hazard.name)
	if fsm.current_state == fsm.State.EXECUTING:
		fsm.change_state(fsm.State.INTERRUPTED)
		nav_agent.target_position = global_position

func get_status() -> String:
	return fsm.State.keys()[fsm.current_state]

func _actor_setup() -> void:
	# Wait for the NavigationServer to sync.
	await get_tree().process_frame
	nav_agent.navigation_finished.connect(_on_navigation_finished)

func _set_movement_target(target_pos: Vector2) -> void:
	nav_agent.target_position = target_pos
	fsm.change_state(fsm.State.EXECUTING)

func _update_debug_ui(current_state: String, current_expect: String) -> void:
	state_label.text = "[STATE: %s]" % current_state
	expect_label.text = "[EXPECT: %s]" % current_expect

func _on_state_changed(new_state: int) -> void:
	var state_name: String = fsm.State.keys()[new_state]
	_update_debug_ui(state_name, "N/A")

func _on_navigation_finished() -> void:
	if fsm.current_state == fsm.State.EXECUTING:
		fsm.change_state(fsm.State.IDLE)
