extends Node

const MENU_SCENE_PATH: String = "res://scenes/menu.tscn"
const PARALLAX_TEXTURE: Texture2D = preload("res://assets/parallaxx.png")

@onready var _scene_tree: SceneTree = get_tree()
var _last_scene: Node

func _ready() -> void:
	_update_menu_parallax_for_scene(_scene_tree.current_scene)
	set_process(true)

func _process(delta: float) -> void:
	var current_scene: Node = _scene_tree.current_scene
	if current_scene != _last_scene:
		_update_menu_parallax_for_scene(current_scene)

func _update_menu_parallax_for_scene(scene: Node) -> void:
	_last_scene = scene
	if not scene:
		return
	if scene.scene_file_path != MENU_SCENE_PATH:
		return
	_ensure_parallax(scene)

func _ensure_parallax(menu_root: Node) -> void:
	if menu_root.has_node("MenuParallax"):
		return

	var parallax: MenuParallaxBackground = MenuParallaxBackground.new()
	parallax.name = "MenuParallax"

	var layer: ParallaxLayer = ParallaxLayer.new()
	layer.name = "ParallaxLayer"

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "BackgroundSprite"
	sprite.texture = PARALLAX_TEXTURE
	sprite.modulate = Color(1.75, 1.75, 1.5, 1)
	sprite.scale = Vector2(2.21875, 2.1512346)
	sprite.centered = false
	sprite.position = Vector2.ZERO

	layer.add_child(sprite)
	parallax.add_child(layer)

	menu_root.add_child(parallax)
	menu_root.move_child(parallax, 0)

	var panel: Panel = menu_root.get_node_or_null("Panel") as Panel
	if panel:
		panel.z_index = 0
		var style_box: StyleBoxFlat = StyleBoxFlat.new()
		style_box.bg_color = Color(0.0627451, 0.0196078, 0.207843, 0.25)
		panel.add_theme_style_override("panel", style_box)
