extends CharacterBody2D
class_name Fighter

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
var camera: Camera2D = null
var hp: int = 3
var is_dashing: bool = false
var is_attacking: bool = false
var attack_combo: int = 0
var flying_mode: bool = false
var gravity: float = 980.0
var jump_velocity: float = -400.0

var can_dodge: bool = true
var is_dodging: bool = false
@onready var dodge_timer: Timer = Timer.new()
@onready var dodge_cooldown_timer: Timer = Timer.new()

@onready var hearts_label: Label = Label.new()
@onready var light: PointLight2D = PointLight2D.new()
var shake_strength: float = 0.0

signal died
signal hit_sun
signal switch_to_flying

func _ready() -> void:
	add_to_group("fighter")
	
	# Add Light
	add_child(light)
	var tex = GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	var grad = Gradient.new()
	grad.colors = [Color.WHITE, Color.TRANSPARENT]
	tex.gradient = grad
	light.texture = tex
	light.scale = Vector2(4, 4)
	light.energy = 0.8
	
	# Add Hearts UI
	var canvas = CanvasLayer.new()
	add_child(canvas)
	hearts_label.position = Vector2(20, 20)
	hearts_label.add_theme_font_size_override("font_size", 40)
	update_hearts()
	canvas.add_child(hearts_label)
	
	# Add Dodge Timers
	add_child(dodge_timer)
	dodge_timer.one_shot = true
	dodge_timer.timeout.connect(_on_dodge_timeout)
	
	add_child(dodge_cooldown_timer)
	dodge_cooldown_timer.one_shot = true
	dodge_cooldown_timer.timeout.connect(_on_dodge_cooldown_timeout)
	
	anim.animation_finished.connect(_on_anim_finished)
	
	if anim.sprite_frames.has_animation("spwan"):
		anim.sprite_frames.set_animation_loop("spwan", false)
	if anim.sprite_frames.has_animation("punch_left"):
		anim.sprite_frames.set_animation_loop("punch_left", false)
	if anim.sprite_frames.has_animation("punch_right"):
		anim.sprite_frames.set_animation_loop("punch_right", false)
	if anim.sprite_frames.has_animation("before dash"):
		anim.sprite_frames.set_animation_loop("before dash", false)
	if anim.sprite_frames.has_animation("dash"):
		anim.sprite_frames.set_animation_loop("dash", false)
	if anim.sprite_frames.has_animation("death"):
		anim.sprite_frames.set_animation_loop("death", false)
	
	# Spawn animation
	anim.play("spwan")
	set_physics_process(false) # wait for spawn

func update_hearts() -> void:
	var text = ""
	for i in range(hp):
		text += "❤️"
	hearts_label.text = text

func take_damage() -> void:
	if is_dashing or is_dodging or hp <= 0: return
	hp -= 1
	update_hearts()
	if hp <= 0:
		die()

func start_dodge() -> void:
	if can_dodge and not is_dodging:
		is_dodging = true
		can_dodge = false
		modulate = Color(1.0, 1.0, 1.0, 0.5) # Ghost effect
		dodge_timer.start(1.0)

func _on_dodge_timeout() -> void:
	is_dodging = false
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	dodge_cooldown_timer.start(3.0)

func _on_dodge_cooldown_timeout() -> void:
	can_dodge = true

func die() -> void:
	anim.play("death")
	set_physics_process(false)
	emit_signal("died")

func _process(delta: float) -> void:
	if shake_strength > 0:
		shake_strength = lerpf(shake_strength, 0, 10.0 * delta)

func apply_camera_shake(strength: float) -> void:
	shake_strength = strength

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
		
	if Input.is_key_pressed(KEY_SPACE) and can_dodge and not is_dodging:
		start_dodge()

	if is_attacking or is_dashing:
		velocity.x = move_toward(velocity.x, 0, 400 * delta)
		move_and_slide()
		return
		
	var direction = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left") or Input.is_action_pressed("left"):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right") or Input.is_action_pressed("right"):
		direction += 1.0
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_attacking:
		is_attacking = true
		anim.flip_h = get_global_mouse_position().x < global_position.x
		attack_combo = (attack_combo + 1) % 2
		if attack_combo == 1:
			anim.play("punch_left")
		else:
			anim.play("punch_right")
		check_attack_hit()
	elif Input.is_key_pressed(KEY_Q) and not is_dashing:
		is_dashing = true
		if direction != 0:
			anim.flip_h = direction < 0
		anim.play("before dash")
	elif direction != 0:
		emit_signal("switch_to_flying", direction)
		return
	else:
		velocity.x = move_toward(velocity.x, 0, 400 * delta)
	
	move_and_slide()

func check_attack_hit() -> void:
	var sun = get_tree().get_first_node_in_group("sun_enemy")
	if sun and is_instance_valid(sun):
		var dist = global_position.distance_to(sun.global_position)
		if dist < 100.0: # Attack range
			emit_signal("hit_sun")

func _on_anim_finished() -> void:
	if anim.animation == "spwan":
		anim.play("idle")
		set_physics_process(true)
	elif anim.animation == "punch_left" or anim.animation == "punch_right":
		is_attacking = false
		anim.play("idle")
	elif anim.animation == "before dash":
		anim.play("dash")
		var dir = -1 if anim.flip_h else 1
		velocity.x = dir * 800
	elif anim.animation == "dash":
		is_dashing = false
		anim.play("idle")

func spawn_at(pos: Vector2) -> void:
	global_position = pos
	anim.play("spwan")
	set_physics_process(false)

func land_at(pos: Vector2) -> void:
	global_position = pos
	anim.play("idle")
	set_physics_process(true)
