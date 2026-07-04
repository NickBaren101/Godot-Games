extends Area2D

## Path to the scene that loads when the player touches this teleporter.
@export_file("*.tscn") var target_scene: String

var _triggered := false

func _on_body_entered(body: Node2D) -> void:
	if _triggered or target_scene.is_empty():
		return
	if body is CharacterBody2D:
		_triggered = true
		get_tree().call_deferred("change_scene_to_file", target_scene)
