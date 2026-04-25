extends Node2D
class_name Chain

const PlayerClass = preload("res://scripts/player.gd")

var link_sprite: Sprite2D = null
var hook_tip: CharacterBody2D = null
var hook_light: PointLight2D = null
@onready var player_node: Node2D = get_parent() as Node2D
var crosshair_node: Node2D = null

func _ready() -> void:
	if has_node("Links"):
		link_sprite = $Links
	
	if has_node("Tip"):
		hook_tip = $Tip
	
	if hook_tip != null:
		hook_tip.top_level = true
		hook_tip.visible = false
		if hook_tip.has_node("Hook/PointLight2D"):
			hook_light = hook_tip.get_node("Hook/PointLight2D") as PointLight2D
		
	if link_sprite != null:
		link_sprite.top_level = true
		link_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		link_sprite.region_enabled = true
		link_sprite.centered = true
		link_sprite.offset = Vector2.ZERO
		link_sprite.visible = false

	if player_node != null and player_node.has_node("Crosshair"):
		crosshair_node = player_node.get_node("Crosshair") as Node2D

func _process(_delta: float) -> void:
	update_chain()

func update_chain() -> void:
	if link_sprite == null or hook_tip == null:
		return
	
	if not hook_tip.visible:
		link_sprite.visible = false
		return
	
	var start_point: Vector2
	if player_node != null:
		if player_node is PlayerClass:
			start_point = (player_node as PlayerClass).get_player_position()
		else:
			start_point = player_node.global_position
	else:
		start_point = global_position
	var end_point: Vector2 = hook_tip.global_position
	
	var distance: float = start_point.distance_to(end_point)
	if distance < 5.0:
		link_sprite.visible = false
		return
		
	link_sprite.visible = true
	
	link_sprite.global_rotation = (end_point - start_point).angle() - PI / 2.0
	link_sprite.global_position = (start_point + end_point) * 0.5
	
	var tex_width: float = 16.0
	var tex_height: float = 16.0
	if link_sprite.texture != null:
		tex_width = link_sprite.texture.get_width()
		tex_height = link_sprite.texture.get_height()
		
	var desired_length: float = max(distance, tex_height)
	link_sprite.region_rect = Rect2(0.0, 0.0, tex_width, desired_length)
