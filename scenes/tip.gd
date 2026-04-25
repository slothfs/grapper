extends CharacterBody2D
class_name HookTip

var target_position: Vector2 = Vector2.ZERO
var has_target_position: bool = false

func set_target_position(target: Vector2) -> void:
	target_position = target
	has_target_position = true

func clear_target_position() -> void:
	has_target_position = false

func _physics_process(delta: float) -> void:
	if not visible:
		return
	
	# Only move if the hook has velocity
	var current_velocity: Vector2 = velocity
	if current_velocity != Vector2.ZERO:
		rotation = current_velocity.angle()
		move_and_slide()
		
		if has_target_position:
			var distance_to_target: float = global_position.distance_to(target_position)
			if distance_to_target <= 4.0:
				velocity = Vector2.ZERO
				has_target_position = false
			
		# If hook hits something, stop moving
		if get_slide_collision_count() > 0:
			velocity = Vector2.ZERO
			has_target_position = false
