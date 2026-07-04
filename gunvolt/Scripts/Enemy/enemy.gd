extends CharacterBody2D

const GRAVITY := 900.0
const SPEED := 30.0

enum Posture { STANDING, LYING }

@export var posture := Posture.STANDING

@onready var health: HealthComponent = $HealthComponent

func _ready() -> void:
	if posture == Posture.LYING:
		$StandingShape.disabled = true
		$LyingShape.disabled = false
		$Visual.polygon = PackedVector2Array([Vector2(-14, -4), Vector2(14, -4), Vector2(14, 4), Vector2(-14, 4)])
	health.died.connect(queue_free)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		velocity.x = signf(player.global_position.x - global_position.x) * SPEED
	else:
		velocity.x = 0.0

	move_and_slide()

func take_attack(_attack_type: int) -> void:
	health.take_damage(1)

func _on_contact_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("hit_by_enemy"):
		body.hit_by_enemy(global_position)
