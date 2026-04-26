extends CharacterBody2D
class_name PlayerRocket

# --- Flight Settings ---
@export var engine_thrust: float = 1200.0   # Forward thrust
@export var rotation_speed: float = 3.5    # Turning speed
@export var gravity: float = 400.0         # Downward pull
@export var drag: float = 0.5              # Air resistance / space friction

const BOARDING_RADIUS: float = 200.0
const EXIT_OFFSET: Vector2 = Vector2(120, 0)
const FADE_OPEN_RADIUS: float = 1.5
const FADE_CLOSED_RADIUS: float = 0.0
const FADE_DURATION: float = 0.6

var is_active: bool = false
var checkpoint_pos: Vector2 = Vector2.ZERO
var fade_rect: ColorRect
var fade_material: ShaderMaterial
var fade_tween: Tween
var transition_in_progress: bool = false

@onready var particles = $Particles
@onready var light = $Light
@onready var boarding_area = $BoardingArea

func _ready() -> void:
	# Add a light texture to the PointLight2D dynamically if needed
	if light and not light.texture:
		var img = Image.create(256, 256, false, Image.FORMAT_RGBA8)
		for y in range(256):
			for x in range(256):
				var dist = Vector2(x - 128, y - 128).length()
				if dist < 128:
					var alpha = 1.0 - (dist / 128.0)
					img.set_pixel(x, y, Color(1, 1, 1, alpha))
				else:
					img.set_pixel(x, y, Color.TRANSPARENT)
		light.texture = ImageTexture.create_from_image(img)
	
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade_rect)
	fade_rect.visible = false
	
	fade_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = "shader_type canvas_item;\nuniform float progress : hint_range(0.0, 1.5) = 1.5;\nvoid fragment() {\n\tvec2 center = vec2(0.5, 0.5);\n\tfloat dist = distance(UV, center);\n\tfloat radius = progress * 1.0;\n\tfloat alpha = smoothstep(radius, radius + 0.05, dist);\n\tCOLOR = vec4(0.0, 0.0, 0.0, alpha);\n}"
	fade_material.shader = shader
	fade_rect.material = fade_material
	
	var sprite = $Sprite2D
	if sprite:
		var alive_mat = ShaderMaterial.new()
		var alive_shader = Shader.new()
		alive_shader.code = "shader_type canvas_item;\n" + \
		"uniform float time_scale = 2.0;\n" + \
		"uniform float amplitude = 0.02;\n" + \
		"uniform float thrust_jitter = 0.0;\n" + \
		"void vertex() {\n" + \
		"\tVERTEX.y += sin(TIME * time_scale) * amplitude * 100.0;\n" + \
		"\tif (thrust_jitter > 0.0) {\n" + \
		"\t\tfloat tip_factor = 1.0 - UV.y;\n" + \
		"\t\tVERTEX.y -= tip_factor * thrust_jitter * 6.0;\n" + \
		"\t\tVERTEX.x *= 1.0 - (tip_factor * thrust_jitter * 0.03);\n" + \
		"\t\tVERTEX.x += (fract(sin(dot(vec2(TIME), vec2(12.9898,78.233))) * 43758.5453) - 0.5) * thrust_jitter;\n" + \
		"\t}\n" + \
		"}"
		alive_mat.shader = alive_shader
		sprite.material = alive_mat
	checkpoint_pos = global_position

func _play_fade(from: float, to: float) -> Tween:
	if fade_tween:
		fade_tween.kill()
	fade_rect.visible = true
	fade_material.set_shader_parameter("progress", from)
	fade_tween = create_tween()
	fade_tween.tween_property(fade_material, "shader_parameter/progress", to, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	return fade_tween

func _play_and_wait(from: float, to: float) -> void:
	var tween = _play_fade(from, to)
	if tween:
		await tween.finished
	_finish_fade(to)

func _finish_fade(target: float) -> void:
	if target >= FADE_OPEN_RADIUS - 0.05:
		fade_rect.visible = false
	fade_tween = null

func _physics_process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player") as Player

	# Enter / Exit logic
	if Input.is_action_just_pressed("ui_accept") and not transition_in_progress:
		if is_active:
			_exit_rocket(player)
		elif player and global_position.distance_to(player.get_player_position()) <= BOARDING_RADIUS:
			_enter_rocket(player)

	if not is_active:
		if particles:
			particles.emitting = false
		if $Sprite2D and $Sprite2D.material:
			$Sprite2D.material.set_shader_parameter("thrust_jitter", 0.0)
			$Sprite2D.material.set_shader_parameter("time_scale", 2.0)
			$Sprite2D.material.set_shader_parameter("amplitude", 0.02)
		velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0, 500 * delta)
		move_and_slide()
		return

	# 1. Handle Rotation (Tilt)
	var rotation_dir: float = 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("left"):
		rotation_dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("right"):
		rotation_dir += 1.0
	rotation += rotation_dir * rotation_speed * delta

	# 2. Get vectors relative to where the rocket is pointing
	var forward_vector = Vector2.UP.rotated(rotation)
	var side_vector = Vector2.RIGHT.rotated(rotation)

	# 3. Apply Gravity (Always pulling down)
	velocity.y += gravity * delta

	# 4. Handle Movement Inputs
	var is_thrusting = false
	if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("jump") or Input.is_action_pressed("ui_up"):
		velocity += forward_vector * engine_thrust * delta
		is_thrusting = true
		
	if particles:
		particles.emitting = is_thrusting
		
	if $Sprite2D and $Sprite2D.material:
		$Sprite2D.material.set_shader_parameter("thrust_jitter", 5.0 if is_thrusting else 0.0)
		$Sprite2D.material.set_shader_parameter("time_scale", 15.0 if is_thrusting else 2.0)
		$Sprite2D.material.set_shader_parameter("amplitude", 0.05 if is_thrusting else 0.02)

	# Apply drag
	velocity = velocity.lerp(Vector2.ZERO, drag * delta)

	# 5. Apply Movement
	move_and_slide()

func _enter_rocket(player: Player) -> void:
	if transition_in_progress or player == null:
		return
	transition_in_progress = true
	_freeze_player_softbody(player)
	await _play_and_wait(FADE_OPEN_RADIUS, FADE_CLOSED_RADIUS)
	is_active = true
	checkpoint_pos = global_position
	if has_node("Camera2D"):
		$Camera2D.enabled = true
		$Camera2D.make_current()
	player.hide()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await _play_and_wait(FADE_CLOSED_RADIUS, FADE_OPEN_RADIUS)
	transition_in_progress = false

func _exit_rocket(player: Player) -> void:
	if transition_in_progress or player == null:
		return
	transition_in_progress = true
	await _play_and_wait(FADE_OPEN_RADIUS, FADE_CLOSED_RADIUS)
	is_active = false
	if has_node("Camera2D"):
		$Camera2D.enabled = false
	var exit_position = global_position + EXIT_OFFSET
	_teleport_player(player, exit_position)
	player.hide()
	await _play_and_wait(FADE_CLOSED_RADIUS, FADE_OPEN_RADIUS)
	_wake_player_softbody(player)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.show()
	if player.has_node("Camera2D"):
		player.get_node("Camera2D").make_current()
	transition_in_progress = false

func reset_to_checkpoint() -> void:
	if transition_in_progress:
		return
	transition_in_progress = true
	global_position = checkpoint_pos
	velocity = Vector2.ZERO
	rotation = 0
	await get_tree().create_timer(0.2).timeout
	transition_in_progress = false

func _set_player_softbody_state(player: Player, frozen: bool) -> void:
	if player == null or player.softbody_node == null:
		return
	for rb_data in player.softbody_node.get_rigid_bodies():
		if "rigidbody" in rb_data and rb_data.rigidbody is RigidBody2D:
			var rb: RigidBody2D = rb_data.rigidbody
			rb.freeze = frozen
			rb.sleeping = frozen
			rb.linear_velocity = Vector2.ZERO
			rb.angular_velocity = 0

func _teleport_player(player: Player, target_position: Vector2) -> void:
	if player == null:
		return
	if player.global_position == target_position:
		return
	player.global_position = target_position


func _freeze_player_softbody(player: Player) -> void:
	_set_player_softbody_state(player, true)

func _wake_player_softbody(player: Player) -> void:
	_set_player_softbody_state(player, false)
