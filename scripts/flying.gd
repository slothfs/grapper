extends Node2D
class_name FlyingPlayer

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
var speed: float = 300.0

signal stopped_flying

func _process(delta: float) -> void:
	var dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left") or Input.is_action_pressed("left"):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right") or Input.is_action_pressed("right"):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up") or Input.is_action_pressed("jump"):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		dir.y += 1
		
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		global_position += dir * speed * delta
		anim.play("flying")
		anim.flip_h = dir.x < 0
	else:
		anim.stop()
		if not get_meta("fighter_dead", false):
			emit_signal("stopped_flying")
