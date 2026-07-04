extends CharacterBody2D

const GRAVITY := 900.0
const WALK_SPEED := 80.0
const JUMP_VELOCITY := -270.0
const DASH_SPEED := 200.0
const DASH_DURATION := 0.2
const SHOOT_DURATION := 0.15
const KNOCKBACK_SPEED := 140.0
const KNOCKBACK_UP := -120.0
const KNOCKBACK_DURATION := 0.35

enum State { IDLE, RUN, JUMP, FALL, DASH, LOOK_UP, CROUCH, SHOOT_HORIZONTAL, HURT }

const ANIM_BY_STATE := {
	State.IDLE: &"idle",
	State.RUN: &"run",
	State.JUMP: &"jump",
	State.FALL: &"fall",
	State.DASH: &"run",
	State.LOOK_UP: &"look_up",
	State.CROUCH: &"crouch",
	State.SHOOT_HORIZONTAL: &"shoot_horizontal",
	State.HURT: &"hurt",
}

@export var bullet_scene: PackedScene

var state := State.IDLE
var facing := 1
var dash_timer := 0.0
var shoot_timer := 0.0
var hurt_timer := 0.0

@onready var bullet_spawn_horizontal: Marker2D = $BulletSpawnHorizontal
@onready var bullet_spawn_up: Marker2D = $BulletSpawnUp
@onready var bullet_spawn_low: Marker2D = $BulletSpawnLow
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: HealthComponent = $HealthComponent

func _ready() -> void:
	health.died.connect(func(): get_tree().call_deferred("reload_current_scene"))

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_input(delta)
	move_and_slide()
	_update_state()

func _apply_gravity(delta: float) -> void:
	if state != State.DASH and not is_on_floor():
		velocity.y += GRAVITY * delta

func _handle_input(delta: float) -> void:
	shoot_timer = maxf(shoot_timer - delta, 0.0)

	if hurt_timer > 0.0:
		hurt_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		return

	if state == State.DASH:
		dash_timer -= delta
		velocity.x = DASH_SPEED * facing
		velocity.y = 0.0
		return

	if Input.is_action_pressed("aim_down") and is_on_floor():
		velocity.x = 0.0
	else:
		var dir := Input.get_axis("move_left", "move_right")
		velocity.x = dir * WALK_SPEED

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed("dash"):
		dash_timer = DASH_DURATION
		state = State.DASH
		velocity.x = DASH_SPEED * facing
		velocity.y = 0.0
		return

	if Input.is_action_just_pressed("shoot"):
		shoot_timer = SHOOT_DURATION
		_fire()

func _update_state() -> void:
	if hurt_timer > 0.0:
		state = State.HURT
		_play_anim()
		return

	if dash_timer > 0.0:
		state = State.DASH
		_play_anim()
		return

	if velocity.x > 0.0:
		facing = 1
		sprite.flip_h = false
	elif velocity.x < 0.0:
		facing = -1
		sprite.flip_h = true

	if not is_on_floor():
		state = State.JUMP if velocity.y < 0.0 else State.FALL
	elif Input.is_action_pressed("aim_down"):
		state = State.CROUCH
	elif Input.is_action_pressed("aim_up"):
		state = State.LOOK_UP
	elif shoot_timer > 0.0:
		state = State.SHOOT_HORIZONTAL
	elif absf(velocity.x) > 1.0:
		state = State.RUN
	else:
		state = State.IDLE

	_play_anim()

func _play_anim() -> void:
	var anim: StringName = ANIM_BY_STATE.get(state, &"idle")
	if sprite.animation != anim:
		sprite.play(anim)

func _fire() -> void:
	if bullet_scene == null:
		return
	var bullet := bullet_scene.instantiate()
	var direction: Vector2
	var spawn_position: Vector2

	if is_on_floor() and Input.is_action_pressed("aim_up"):
		direction = Vector2.UP
		spawn_position = bullet_spawn_up.global_position
		bullet.attack_type = Bullet.UP
	else:
		var is_down_shot := is_on_floor() and Input.is_action_pressed("aim_down")
		var marker: Marker2D = bullet_spawn_low if is_down_shot else bullet_spawn_horizontal
		var offset := marker.position
		offset.x = absf(offset.x) * facing
		direction = Vector2(facing, 0)
		spawn_position = global_position + offset
		bullet.attack_type = Bullet.DOWN if is_down_shot else Bullet.HORIZONTAL

	bullet.global_position = spawn_position
	bullet.direction = direction
	get_tree().current_scene.add_child(bullet)

func hit_by_enemy(source_pos: Vector2) -> void:
	if hurt_timer > 0.0:
		return
	hurt_timer = KNOCKBACK_DURATION
	var dir: float = sign(global_position.x - source_pos.x)
	if dir == 0:
		dir = 1
	velocity.x = dir * KNOCKBACK_SPEED
	velocity.y = KNOCKBACK_UP
	state = State.HURT
	health.take_damage(1)
