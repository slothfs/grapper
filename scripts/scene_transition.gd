extends CanvasLayer
class_name SceneTransition

@export var fade_color: Color = Color.BLACK
@export var fade_duration: float = 0.6

var fade_rect: ColorRect = null
var _tween: Tween = null

func _ready() -> void:
	layer = 100
	_ensure_overlay()

func fade_in() -> void:
	var fade_finished: Signal = _fade_to(1.0, 0.0)
	await fade_finished
	_tween = null

func fade_out() -> void:
	var fade_finished: Signal = _fade_to(0.0, 1.0)
	await fade_finished
	if fade_rect:
		fade_rect.visible = false
	_tween = null

func _fade_to(target_alpha: float, start_alpha: float) -> Signal:
	_ensure_overlay()
	if _tween and is_instance_valid(_tween):
		_tween.kill()
	fade_rect.visible = true
	fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, start_alpha)
	_tween = create_tween()
	var finished_signal: Signal = _tween.finished
	_tween.tween_property(fade_rect, "color:a", target_alpha, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return finished_signal

func _ensure_overlay() -> void:
	if fade_rect and is_instance_valid(fade_rect):
		return
	if has_node("ColorRect"):
		fade_rect = $ColorRect
	else:
		fade_rect = ColorRect.new()
		fade_rect.name = "ColorRect"
		add_child(fade_rect)
	fade_rect.z_index = 1000
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
	fade_rect.visible = false
