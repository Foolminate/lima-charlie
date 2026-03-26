extends Node2D

@export var id: String = "dummy_hazard_1"
@export var status: String = "ARMED"
@export var type: String = "Hazard"
@export var tags: Array[String] = ["EXPLOSIVE", "Hazard:DISARM"]
@onready var area: Area2D = $Area2D

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.has_method("trigger_hazard"):
		print("HAZARD: Triggered by %s" % body.name)
		body.trigger_hazard(self)

func get_tags() -> String:
	return ", ".join(tags)
