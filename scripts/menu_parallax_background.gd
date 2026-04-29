extends ParallaxBackground
class_name MenuParallaxBackground

const SCROLL_SPEED: Vector2 = Vector2(-30.0, 0.0)

var _parallax_layer: ParallaxLayer
var _background_sprite: Sprite2D

func _ensure_nodes() -> void:
	if not _parallax_layer:
		_parallax_layer = get_node_or_null("ParallaxLayer") as ParallaxLayer
	if _parallax_layer and not _background_sprite:
		_background_sprite = _parallax_layer.get_node_or_null("BackgroundSprite") as Sprite2D

func _ready() -> void:
	_ensure_nodes()
	if not _background_sprite:
		call_deferred("_ready")
		return
	set_process(true)
	var texture_size: Vector2 = _background_sprite.texture.get_size()
	var sprite_scale: Vector2 = _background_sprite.global_scale
	var mirrored_size: Vector2 = Vector2(
		texture_size.x * sprite_scale.x,
		texture_size.y * sprite_scale.y,
	)
	_parallax_layer.motion_mirroring = mirrored_size

func _process(delta: float) -> void:
	scroll_offset += SCROLL_SPEED * delta

# Keeps the menu background moving.
