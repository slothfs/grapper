extends TextureButton

func _ready():
	pivot_offset = Vector2(25, 25)

func _process(delta):
	rotation += delta * 2.0
