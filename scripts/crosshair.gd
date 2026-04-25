extends Node2D
class_name Crosshair

const PlayerClass = preload("res://scripts/player.gd")

@export var size: float = 16.0
@export var thickness: float = 2.0
@export var color: Color = Color.WHITE

@onready var player: PlayerClass = get_parent() as PlayerClass

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	var new_mat: CanvasItemMaterial = CanvasItemMaterial.new()
	new_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = new_mat
	color = Color.WHITE
	set_process(true)

func _process(delta: float) -> void:
	var mouse_position: Vector2 = get_global_mouse_position()
	global_position = mouse_position
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("shoot"):
		rotation += deg_to_rad(360.0) * delta
	queue_redraw()

func _draw() -> void:
	var horizontal: Vector2 = Vector2(size, 0)
	draw_line(-horizontal, horizontal, color, thickness)
	var vertical: Vector2 = Vector2(0, size)
	draw_line(-vertical, vertical, color, thickness)
