extends Node2D
class_name Chain

const PlayerClass = preload("res://scripts/player.gd")
const ROPE_TEXTURE_PATH: String = "res://assets/g/rope_segment_frame_0_1777146718.png"
const ROPE_SHADER_PATH: String = "res://shaders/rope_color.gdshader"
var _rope_shader: Shader = null
const ROPE_COLOR: Color = Color(1, 1, 1, 1)
const ROPE_Z_INDEX: int = 100

@onready var link_sprite: Line2D = get_node_or_null("RopeLine") as Line2D
var hook_tip: CharacterBody2D = null
var hook_light: PointLight2D = null
@onready var player_node: Node2D = get_parent() as Node2D
var crosshair_node: Node2D = null

func _ready() -> void:
	_configure_rope()
	if has_node("Tip"):
		hook_tip = $Tip as CharacterBody2D
	if hook_tip != null:
		hook_tip.top_level = true
		hook_tip.visible = false
		if hook_tip.has_node("Hook/PointLight2D"):
			hook_light = hook_tip.get_node("Hook/PointLight2D") as PointLight2D
	else:
		push_error("Hook tip missing from Chain node. Grapple visuals disabled.")
	if player_node != null and player_node.has_node("Crosshair"):
		crosshair_node = player_node.get_node("Crosshair") as Node2D

	set_process(true)

func _configure_rope() -> void:
	if link_sprite == null:
		push_error("RopeLine missing from Chain. Grapple rope will not render.")
		return
	link_sprite.visible = false
	link_sprite.top_level = true
	link_sprite.joint_mode = Line2D.LINE_JOINT_ROUND
	link_sprite.begin_cap_mode = Line2D.LINE_CAP_ROUND
	link_sprite.end_cap_mode = Line2D.LINE_CAP_ROUND
	link_sprite.texture_mode = Line2D.LINE_TEXTURE_TILE
	link_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	link_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	link_sprite.width = 12.0
	link_sprite.light_mask = 1
	link_sprite.z_index = ROPE_Z_INDEX
	link_sprite.z_as_relative = false
	link_sprite.default_color = ROPE_COLOR
	link_sprite.modulate = ROPE_COLOR
	if _rope_shader == null:
		_rope_shader = load(ROPE_SHADER_PATH) as Shader
	if _rope_shader != null:
		var rope_material: ShaderMaterial = ShaderMaterial.new()
		rope_material.shader = _rope_shader
		rope_material.set_shader_parameter("rope_color", ROPE_COLOR)
		link_sprite.material = rope_material
	else:
		push_warning("Missing rope shader at %s" % ROPE_SHADER_PATH)
	var rope_texture: Texture2D = load(ROPE_TEXTURE_PATH) as Texture2D
	if rope_texture != null:
		link_sprite.texture = rope_texture
	else:
		push_warning("Could not find rope texture: %s" % ROPE_TEXTURE_PATH)

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
	
	link_sprite.global_position = start_point
	link_sprite.visible = true
	link_sprite.global_rotation = 0

	var points: PackedVector2Array = PackedVector2Array()
	var num_points: int = max(2, int(distance / 10.0))
	var time: float = Time.get_ticks_msec() / 1000.0
	var is_wobbly: bool = false
	if hook_tip.velocity.length() > 10.0 or (distance > 20.0 and hook_tip.visible):
		is_wobbly = true

	var direction: Vector2 = end_point - start_point
	var normalized_direction: Vector2 = Vector2.ZERO
	if direction != Vector2.ZERO:
		normalized_direction = direction.normalized()

	for i in range(num_points + 1):
		var t: float = float(i) / num_points
		var pt: Vector2 = start_point.lerp(end_point, t)
		if is_wobbly and i > 0 and i < num_points and normalized_direction != Vector2.ZERO:
			var perp: Vector2 = Vector2(-normalized_direction.y, normalized_direction.x)
			var wobble_amt: float = sin(time * 20.0 + t * 10.0) * 8.0 * sin(t * PI)
			pt += perp * wobble_amt
		points.append(pt - start_point)

	link_sprite.points = points
