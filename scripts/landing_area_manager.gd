extends Node
class_name LandingAreaManager

@export var target_scene: PackedScene = preload("res://fight.tscn")

var _transition_node: SceneTransition = null
var _landing_area: Area2D = null
var _is_transitioning: bool = false

func _ready() -> void:
	get_tree().connect("scene_changed", Callable(self, "_on_scene_changed"))
	_ensure_landing_area_connection()

func _on_scene_changed() -> void:
	_is_transitioning = false
	_ensure_landing_area_connection()

func _ensure_landing_area_connection() -> void:
	var current_scene: Node = get_tree().get_current_scene()
	if current_scene == null:
		return
	var landing_area: Area2D = current_scene.get_node_or_null("Landing area") as Area2D
	if landing_area == null or landing_area == _landing_area:
		return
	if _landing_area and _landing_area.is_connected("body_entered", Callable(self, "_on_landing_body_entered")):
		_landing_area.disconnect("body_entered", Callable(self, "_on_landing_body_entered"))
	_landing_area = landing_area
	landing_area.connect("body_entered", Callable(self, "_on_landing_body_entered"))

func _on_landing_body_entered(body: Node) -> void:
	if _is_transitioning:
		return
	if body is PlayerRocket:
		_is_transitioning = true
		var transition: SceneTransition = _ensure_transition_node()
		if transition:
			await transition.fade_in()
		if target_scene:
			get_tree().change_scene_to_packed(target_scene)
		else:
			push_warning("LandingAreaManager: target_scene is not assigned.")

func get_scene_transition() -> SceneTransition:
	return _ensure_transition_node()

func _ensure_transition_node() -> SceneTransition:
	if _transition_node and is_instance_valid(_transition_node):
		return _transition_node
	var existing: SceneTransition = get_node_or_null("SceneTransition") as SceneTransition
	if existing:
		_transition_node = existing
		return existing
	var new_transition: SceneTransition = SceneTransition.new()
	new_transition.name = "SceneTransition"
	add_child(new_transition)
	_transition_node = new_transition
	return new_transition
