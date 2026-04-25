extends Camera2D
class_name PlayerCamera

@export var follow_strength: float = 0.08
@export var max_distance_from_player: float = 50.0
@export var deadzone_radius: float = 30.0  # Camera stays still within this radius
@export var use_deadzone: bool = true

func _process(_delta: float) -> void:
	var parent: Node = get_parent()
	if parent is Node2D:
		var target_offset: Vector2 = get_global_mouse_position() - parent.global_position
		target_offset = target_offset.limit_length(max_distance_from_player)
		
		# Deadzone: Only follow if mouse is outside the deadzone
		if use_deadzone and target_offset.length() < deadzone_radius:
			return  # Camera stays in place
		
		# Smooth follow with dampening
		global_position = global_position.lerp(
			parent.global_position + target_offset,
			follow_strength
		)
