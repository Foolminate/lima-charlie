class_name UnitFSM
extends Node

#Signal to notify the Debug Canvas and Unit when states change
signal state_changed(new_state: int)

# The core OODAR physical states
enum State {
	IDLE,
	PLANNING,
	EXECUTING,
	INTERRUPTED,
	CONFUSED
}

var current_state: int = State.IDLE

func _ready() -> void:
	# Ensure the system boots into IDLE cleanly
	call_deferred("change_state", State.IDLE)

func change_state(new_state: int) -> void:
	if new_state == current_state:
		return

	current_state = new_state
	state_changed.emit(current_state)

	match current_state:
		State.IDLE:
			print("FSM: Unit IDLE.")
			# Halt movement and trigger perception checks
			pass
		State.PLANNING:
			print("FSM: Unit PLANNING.")
			# Delaying action while awaiting LLM response
		State.EXECUTING:
			print("FSM: Unit EXECUTING.")
			# Execute the LLM command
		State.INTERRUPTED:
			print("FSM: Unit INTERRUPTED.")
			# Cancel current action, request LLM update, and re-plan
		State.CONFUSED:
			print("FSM: Unit CONFUSED.")
			# LLM hallucination or error, fallback to safe behavior and re-query LLM
