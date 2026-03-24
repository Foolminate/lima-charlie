extends Node2D

@onready var area: Area2D = $Area2D

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.has_method("trigger_hazard"):
		print("HAZARD: Triggered by %s" % body.name)
		body.trigger_hazard(self)
