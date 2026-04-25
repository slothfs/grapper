extends Node2D
class_name Crosshair

const Player = preload("res://scripts/player.gd")

@export var size: float = 16.0
@export var thickness: float = 2.0
@export var color: Color = Color(1, 0, 0, 0.8)

@onready var player: Player = get_parent() as Player

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	var mouse_position: Vector2 = get_global_mouse_position()
	if player == null:
		global_position = mouse_position
		queue_redraw()
		return
	
	var aim_vector: Vector2 = mouse_position - player.global_position
	var max_distance: float = player.grapple_max_distance
	if aim_vector.length() > max_distance:
		aim_vector = aim_vector.normalized() * max_distance
	global_position = player.global_position + aim_vector
	queue_redraw()

func _draw() -> void:
	var horizontal: Vector2 = Vector2(size, 0)
	draw_line(-horizontal, horizontal, color, thickness)
	var vertical: Vector2 = Vector2(0, size)
	draw_line(-vertical, vertical, color, thickness)
