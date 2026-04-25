extends CharacterBody2D
class_name HookTip

var target_position: Vector2 = Vector2.ZERO
var has_target_position: bool = false
var is_hooked: bool = false
var flight_timer: float = 0.0

func set_target_position(target: Vector2) -> void:
	target_position = target
	has_target_position = true
	is_hooked = false
	flight_timer = 0.0

func clear_target_position() -> void:
	has_target_position = false
	is_hooked = false
	flight_timer = 0.0

func _physics_process(delta: float) -> void:
	if not visible:
		return
	
	flight_timer += delta
	
	# Only move if the hook has velocity
	var current_velocity: Vector2 = velocity
	if current_velocity != Vector2.ZERO:
		rotation = current_velocity.angle()
		move_and_slide()
		
		# If hook hits something, stop moving
		if get_slide_collision_count() > 0:
			velocity = Vector2.ZERO
			has_target_position = false
			is_hooked = true
			return
			
		if has_target_position:
			var distance_to_target: float = global_position.distance_to(target_position)
			if distance_to_target <= 4.0:
				velocity = Vector2.ZERO
				has_target_position = false
