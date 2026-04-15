extends CharacterBody2D

signal health_changed(new_health: int)
signal died

const SPEED = 300.0

var last_direction: Vector2 = Vector2.RIGHT
var is_attacking: bool = false
var hitbox_offset: Vector2
var is_alive: bool = true
var strength: int = 40
var max_health: int
var health: int

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var damage_cooldown: Timer = $DamageCooldown

@onready var take_damage_sound: AudioStreamPlayer2D = $TakeDamage
@onready var swing_sword_sound: AudioStreamPlayer2D = $SwingSword


func _ready() -> void:
	# Load health from singleton
	max_health = PlayerStats.health
	health = PlayerStats.health
	# Initialize hitbox offset
	hitbox_offset = hitbox.position


func _physics_process(_delta: float) -> void:
	
	# Disable hitbox until an attack is triggered
	hitbox.monitoring = false
	
	if not is_alive:
		return
		
	if Input.is_action_just_pressed("attack") and not is_attacking:
		attack()
		
	# Skip movement if attacking
	if is_attacking:
		velocity = Vector2.ZERO
		return
		
	process_movement()
	process_animation()
	move_and_slide()

# -------------------- #
# MOVEMENT & ANIMATION #
# -------------------- #

func process_movement() -> void:
	var direction := Input.get_vector("left", "right", "up", "down")
	
	if direction != Vector2.ZERO:
		velocity = direction * SPEED
		last_direction = direction
		update_hitbox_offset()
	else:
		velocity = Vector2.ZERO
	
	
func process_animation() -> void:
	if is_attacking:
		return
	
	if velocity != Vector2.ZERO:
		play_animation("run", last_direction)
	else:
		play_animation("idle", last_direction)
	
	
func play_animation(prefix: String, dir: Vector2) -> void:
	if dir.x != 0:
		animated_sprite_2d.flip_h = dir.x < 0
		animated_sprite_2d.play(prefix + "_right")
	elif dir.y < 0:
		animated_sprite_2d.play(prefix + "_up")
	elif dir.y > 0:
		animated_sprite_2d.play(prefix + "_down")
	
# Attacking #	
		
func attack() -> void:
	is_attacking = true
	hitbox.monitoring = true
	swing_sword_sound.play()
	play_animation("attack", last_direction)


func _on_animated_sprite_2d_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		
# HITBOX #

func update_hitbox_offset() -> void:
	var x := hitbox_offset.x
	var y := hitbox_offset.y
	
	match last_direction:
		Vector2.LEFT:
			hitbox.position = Vector2(-x, y)
		Vector2.RIGHT:
			hitbox.position = Vector2(x, y)
		Vector2.UP:
			hitbox.position = Vector2(y, -x)
		Vector2.DOWN:
			hitbox.position = Vector2(y, x)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_attacking and body.name.begins_with("Slime"):
		body.take_damage(strength, position)
		
		
func heal(amount: int) -> void:
	health += amount
	if health >= max_health:
		health = max_health
	PlayerStats.health = health
	emit_signal("health_changed", health)
	
		
func take_damage(amount: int) -> void:
	if not is_alive:
		return
	
	if damage_cooldown.time_left > 0:
		return
		
	take_damage_sound.play()
	health -= amount
	PlayerStats.health = health
	emit_signal("health_changed", health)
	
	if health <= 0:
		die()
		
	# Make player invincible for a short time
	damage_cooldown.start()


func die() -> void:
	animated_sprite_2d.play("dying")
	is_alive = false
	await animated_sprite_2d.animation_finished
	died.emit()
