class_name Bullet
extends Area2D

const SPEED := 200.0
const LIFETIME := 2.0

const HORIZONTAL := 0
const DOWN := 1
const UP := 2

var direction := Vector2.RIGHT
var attack_type := HORIZONTAL

var _time := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_time += delta
	if _time >= LIFETIME:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_attack"):
		body.take_attack(attack_type)
	queue_free()
