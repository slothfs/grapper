extends Control

func _ready() -> void:
	pass
	
func _process(delta: float) -> void:
	pass

func _on_story_pressed() -> void:
	print("story")
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_level_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_setting_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_vom_pressed() -> void:
	print("volume")


func _on_exit_pressed() -> void:
	print("exited")
	get_tree().quit()
