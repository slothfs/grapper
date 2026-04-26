extends CharacterBody2D

# --- Flight Settings ---
@export var engine_thrust: float = 800.0   # Forward thrust
@export var side_thrust: float = 300.0     # Sideways "strafe" force
@export var rotation_speed: float = 4.0    # Turning speed
@export var gravity: float = 300.0         # Downward pull

func _physics_process(delta: float) -> void:
	# 1. Handle Rotation (Tilt)
	var rotation_dir: float = 0.0
	if Input.is_physical_key_pressed(KEY_A):
		rotation_dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		rotation_dir += 1.0
	rotation += rotation_dir * rotation_speed * delta

	# 2. Get vectors relative to where the rocket is pointing
	var forward_vector = Vector2.UP.rotated(rotation)
	var side_vector = Vector2.RIGHT.rotated(rotation)

	# 3. Apply Gravity (Always pulling down)
	velocity.y += gravity * delta

	# 4. Handle Movement Inputs
	
	# Forward Thrust (W)
	if Input.is_physical_key_pressed(KEY_W):
		velocity += forward_vector * engine_thrust * delta
		
	# Sideways/Strafe Thrust (A and D)
	# Now instead of just turning, these buttons add a little "nudge" to the sides
	if Input.is_physical_key_pressed(KEY_A):
		velocity -= side_vector * side_thrust * delta
	if Input.is_physical_key_pressed(KEY_D):
		velocity += side_vector * side_thrust * delta

	# 5. Apply Movement
	move_and_slide()
