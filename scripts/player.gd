extends CharacterBody2D
class_name Player

@export var speed: float = 200.0
@export var jump_force: float = -400.0
@export var gravity: float = 900.0
@export var friction: float = 16.0
@export var grapple_pull_speed: float = 600.0
@export var grapple_max_distance: float = 500.0

const HOOK_SPEED: float = 900.0

var camera_2d: Camera2D = null
var chain: Node2D = null
var hook_tip: HookTip = null
var crosshair: Crosshair = null

var hook_active: bool = false
var hook_released: bool = true
var grapple_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Find nodes after scene is fully loaded
	if has_node("Camera2D"):
		camera_2d = $Camera2D
	else:
		push_warning("Camera2D not found!")
	
	if has_node("Crosshair"):
		crosshair = $Crosshair
	else:
		push_warning("Crosshair not found!")
	
	if has_node("Chain"):
		chain = $Chain
	else:
		push_warning("Chain not found!")
	
	if has_node("Chain/Tip"):
		hook_tip = $Chain/Tip
	else:
		push_error("Hook Tip (Chain/Tip) not found! Check scene structure.")

func _physics_process(delta: float) -> void:
	handle_input()
	
	if hook_active and hook_tip != null and hook_tip.velocity == Vector2.ZERO:
		apply_grapple_pull(delta)
	else:
		apply_normal_movement(delta)
	
	move_and_slide()

func handle_input() -> void:
	if Input.is_action_just_pressed("shoot"):
		print("✅ shoot action detected!")
		shoot()
	
	if Input.is_action_just_pressed("release"):
		print("✅ release action detected!")
		release()

func apply_normal_movement(delta: float) -> void:
	# Horizontal movement
	if Input.is_action_pressed("right"):
		velocity.x = speed
	elif Input.is_action_pressed("left"):
		velocity.x = -speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction)
	
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force
	
	# Reset grapple velocity
	grapple_velocity = Vector2.ZERO

func apply_grapple_pull(delta: float) -> void:
	# Pull player toward the hook
	var direction: Vector2 = (hook_tip.global_position - global_position).normalized()
	var distance: float = global_position.distance_to(hook_tip.global_position)
	
	# If we're too close, release automatically
	if distance < 20.0:
		release()
		return
	
	# Pull the player toward the hook
	grapple_velocity = direction * grapple_pull_speed
	
	# Allow swinging: add horizontal input while grappling
	if Input.is_action_pressed("right"):
		grapple_velocity.x += speed * 0.5
	elif Input.is_action_pressed("left"):
		grapple_velocity.x -= speed * 0.5
	
	# Apply some gravity while grappling to allow swinging motion
	grapple_velocity.y += gravity * delta * 0.3
	
	velocity = grapple_velocity

func shoot() -> void:
	if hook_tip == null:
		push_error("Hook Tip (Chain/Tip) not found in scene tree!")
		return
	
	var aim_target: Vector2 = global_position
	if crosshair != null:
		aim_target = crosshair.global_position
	else:
		aim_target = get_global_mouse_position()
	
	var raw_direction: Vector2 = aim_target - global_position
	if raw_direction == Vector2.ZERO:
		return
	
	var distance_to_target: float = raw_direction.length()
	var aim_direction: Vector2 = raw_direction / distance_to_target
	var clamped_distance: float = min(distance_to_target, grapple_max_distance)
	var target_position: Vector2 = global_position + aim_direction * clamped_distance

	print("🎯 SHOOT called! Hook heading toward ", target_position)
	hook_active = true
	hook_released = false
	hook_tip.visible = true
	hook_tip.global_position = global_position
	hook_tip.set_target_position(target_position)
	hook_tip.velocity = aim_direction * HOOK_SPEED

func release() -> void:
	if hook_tip == null:
		return
	
	hook_active = false
	hook_released = true
	hook_tip.visible = false
	hook_tip.velocity = Vector2.ZERO
	hook_tip.clear_target_position()
	hook_tip.global_position = global_position
