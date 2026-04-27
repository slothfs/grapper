extends CharacterBody2D
class_name SunEnemy

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
var hp: float = 300.0
var max_hp: float = 300.0

@onready var health_bar: ProgressBar = ProgressBar.new()
@onready var light: PointLight2D = PointLight2D.new()
@onready var particles: GPUParticles2D = GPUParticles2D.new()

var gravity: float = 980.0
var fighter: Node2D = null

enum State { IDLE, JUMPING, FALLING, SMASHING }
var state = State.IDLE
var attack_timer: float = 0.0

func _ready() -> void:
	add_to_group("sun_enemy")
	
	# Add Health Bar
	add_child(health_bar)
	health_bar.position = Vector2(-50, -80)
	health_bar.size = Vector2(100, 10)
	health_bar.show_percentage = false
	health_bar.modulate = Color.RED
	health_bar.value = hp
	health_bar.max_value = max_hp
	
	# Add Light
	add_child(light)
	var tex = GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	var grad = Gradient.new()
	grad.colors = [Color.YELLOW, Color.TRANSPARENT]
	tex.gradient = grad
	light.texture = tex
	light.scale = Vector2(6, 6)
	light.color = Color(1, 1, 0.5)
	light.energy = 1.2
	
	# Add Particles
	add_child(particles)
	particles.emitting = false
	particles.one_shot = true
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 20.0
	mat.particle_flag_align_y = true
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 400.0
	mat.initial_velocity_max = 800.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 2.0
	mat.scale_max = 6.0
	mat.color = Color(2, 2, 0, 1) # HDR Yellow/White
	
	var curve = CurveTexture.new()
	var c = Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	curve.curve = c
	mat.scale_curve = curve
	
	particles.process_material = mat
	particles.amount = 80
	particles.lifetime = 0.4
	particles.explosiveness = 0.95
	
	# Shader for alive look
	var smat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	void fragment() {
		vec2 uv = UV;
		uv.y += sin(TIME * 5.0 + uv.x * 10.0) * 0.05;
		COLOR = texture(TEXTURE, uv);
	}
	"""
	smat.shader = shader
	anim.material = smat

	attack_timer = 2.0

func _physics_process(delta: float) -> void:
	if hp <= 0: return
	
	if not fighter or not is_instance_valid(fighter):
		fighter = get_tree().get_first_node_in_group("fighter")
		return
		
	if not is_on_floor():
		velocity.y += gravity * delta
		
	match state:
		State.IDLE:
			attack_timer -= delta
			velocity.x = move_toward(velocity.x, 0, 200 * delta)
			if attack_timer <= 0 and is_on_floor():
				state = State.JUMPING
				velocity.y = -600.0 # Jump high
				# Aim for fighter
				var dir = sign(fighter.global_position.x - global_position.x)
				velocity.x = dir * 300.0
		State.JUMPING:
			if velocity.y > 0:
				state = State.FALLING
		State.FALLING:
			# Track fighter's x position
			var target_x = fighter.global_position.x
			velocity.x = lerp(velocity.x, (target_x - global_position.x) * 5.0, 5.0 * delta)
			
			if is_on_floor():
				state = State.SMASHING
				
				# Check if hit fighter
				if global_position.distance_to(fighter.global_position) < 80.0:
					if fighter.has_method("take_damage"):
						fighter.take_damage()
						# Dynamic zoom out on smash
						if fighter.has_method("apply_camera_shake"):
							fighter.apply_camera_shake(50.0) # Huge shake!
						if "camera" in fighter and fighter.camera:
							fighter.camera.zoom = lerp(fighter.camera.zoom, Vector2(1.5, 1.5), 0.5)
				
				attack_timer = 2.0
				state = State.IDLE

	move_and_slide()
	
	# Reset camera zoom if idle
	if state == State.IDLE and fighter and is_instance_valid(fighter) and "camera" in fighter and fighter.camera:
		fighter.camera.zoom = lerp(fighter.camera.zoom, Vector2(2.5, 2.5), 2.0 * delta)

func take_damage(amount: float = 10.0) -> void:
	if hp <= 0: return
	hp -= amount
	health_bar.value = hp
	
	# Anime Hit Effects
	particles.restart()
	
	# Hit Flash
	anim.modulate = Color(5, 5, 5, 1) # Overblown white flash
	var tween = create_tween()
	tween.tween_property(anim, "modulate", Color.WHITE, 0.2)
	
	# Dynamic zoom and Screen Shake
	if fighter and is_instance_valid(fighter):
		if fighter.has_method("apply_camera_shake"):
			fighter.apply_camera_shake(30.0) # Big screen shake
		if "camera" in fighter and fighter.camera:
			fighter.camera.zoom = Vector2(3.5, 3.5) # Intense zoom in
			
	# Hit Stop (Freeze Frame)
	Engine.time_scale = 0.05
	var timer = get_tree().create_timer(0.01, true, false, true)
	timer.timeout.connect(func(): Engine.time_scale = 1.0)
		
	if hp <= 0:
		die()

func die() -> void:
	set_physics_process(false)
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
	health_bar.hide()
	light.hide()
	
	# Fade out Animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(anim, "modulate", Color(5.0, 0.0, 0.0, 0.0), 3.0)
	
	# Death particles (small particles slowly drifting into the sky)
	var death_particles = GPUParticles2D.new()
	add_child(death_particles)
	death_particles.emitting = true
	death_particles.one_shot = true
	death_particles.amount = 300
	death_particles.lifetime = 6.0
	death_particles.explosiveness = 0.5
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 60.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, -15, 0) # Slowly goes upwards to the sky
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	mat.color = Color(1.0, 0.8, 0.1, 1.0) # Glowing dust
	
	# Fade out over time
	var curve_tex = CurveTexture.new()
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	curve_tex.curve = curve
	mat.alpha_curve = curve_tex
	
	death_particles.process_material = mat
	
	# Cleanup node after particles finish
	var t = get_tree().create_timer(7.0)
	t.timeout.connect(func(): queue_free())
