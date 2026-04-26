extends Area2D
@onready var timer: Timer = $Timer


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerRocket:
		body.reset_to_checkpoint()
		return
	print("you died")
	timer.start()


func _on_timer_timeout() -> void:
	get_tree().reload_current_scene()
