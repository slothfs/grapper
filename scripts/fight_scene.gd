extends Node2D
class_name FightScene

var scene_transition: SceneTransition = null

func _get_landing_manager_node() -> Node:
	var landing_manager_node: Node = get_tree().get_root().get_node_or_null("LandingAreaManager")
	return landing_manager_node

func _ready() -> void:
	var landing_manager_node: Node = _get_landing_manager_node()
	if landing_manager_node and landing_manager_node.has_method("get_scene_transition"):
		var transition: SceneTransition = landing_manager_node.call("get_scene_transition") as SceneTransition
		if transition:
			scene_transition = transition
	if scene_transition:
		await scene_transition.fade_out()
