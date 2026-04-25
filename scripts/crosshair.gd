extends Node2D
class_name Crosshair

const PlayerClass = preload("res://scripts/player.gd")

@export var size: float = 16.0
@export var thickness: float = 2.0
@export var color: Color = Color(1, 0, 0, 0.8)

@onready var player: PlayerClass = get_parent() as PlayerClass

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	var mouse_position: Vector2 = get_global_mouse_position()
	global_position = mouse_position
	queue_redraw()

func _draw() -> void:
	var horizontal: Vector2 = Vector2(size, 0)
	draw_line(-horizontal, horizontal, color, thickness)
	var vertical: Vector2 = Vector2(0, size)
	draw_line(-vertical, vertical, color, thickness)
