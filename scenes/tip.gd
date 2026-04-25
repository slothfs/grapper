extends CharacterBody2D
class_name HookTip

var target_position: Vector2 = Vector2.ZERO
var has_target_position: bool = false
var is_hooked: bool = false
var flight_timer: float = 0.0

var particles: GPUParticles2D
var hook_sprite: Sprite2D

func _ready() -> void:
	hook_sprite = get_node_or_null("Hook") as Sprite2D
	if hook_sprite != null:
		var radius = 5.0
		var size = int(radius * 2.0)
		var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in range(size):
			for x in range(size):
				var dist = Vector2(x - radius, y - radius).length()
				if dist <= radius:
					if dist >= radius - 1.0:
						img.set_pixel(x, y, Color(0.1, 0.1, 0.1, 1.0))
					else:
						img.set_pixel(x, y, Color(0.8, 0.8, 0.8, 1.0))
				else:
					img.set_pixel(x, y, Color.TRANSPARENT)
		var tex = ImageTexture.create_from_image(img)
		hook_sprite.texture = tex
		hook_sprite.scale = Vector2(1.0, 1.0)
		hook_sprite.position = Vector2.ZERO
		
	var col = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = 5.0
		col.shape = circle_shape

	particles = GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 15
	particles.lifetime = 0.5
	particles.explosiveness = 0.8
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 2.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 150.0
	mat.gravity = Vector3(0, 200, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(0.9, 0.9, 0.9, 1.0)
	
	particles.process_material = mat
	var canvas_item_mat = CanvasItemMaterial.new()
	canvas_item_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	particles.material = canvas_item_mat
	
	particles.local_coords = false 
	add_child(particles)

func set_target_position(target: Vector2) -> void:
	target_position = target
	has_target_position = true
	is_hooked = false
	flight_timer = 0.0
	if hook_sprite:
		hook_sprite.scale = Vector2(1.0, 1.0)

func clear_target_position() -> void:
	has_target_position = false
	is_hooked = false
	flight_timer = 0.0
	if hook_sprite:
		hook_sprite.scale = Vector2(1.0, 1.0)

func _physics_process(delta: float) -> void:
	if not visible:
		return
	
	flight_timer += delta
	
	var current_velocity: Vector2 = velocity
	if current_velocity != Vector2.ZERO:
		rotation = current_velocity.angle()
		var collision = move_and_collide(current_velocity * delta)
		
		if collision:
			has_target_position = false
			
			particles.global_position = collision.get_position()
			var pm = particles.process_material as ParticleProcessMaterial
			var normal = collision.get_normal()
			pm.direction = Vector3(normal.x, normal.y, 0)
			particles.restart()
			
			# Stick to the wall
			velocity = Vector2.ZERO
			is_hooked = true
			
			# Visual bouncy effect
			if hook_sprite:
				var tween = create_tween()
				# Squash against the wall
				tween.tween_property(hook_sprite, "scale", Vector2(1.8, 0.4), 0.05)
				# Stretch out slightly
				tween.tween_property(hook_sprite, "scale", Vector2(0.8, 1.2), 0.1)
				# Settle back to normal
				tween.tween_property(hook_sprite, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BOUNCE)
				
		elif has_target_position:
			var distance_to_target: float = global_position.distance_to(target_position)
			if distance_to_target <= 4.0:
				velocity = Vector2.ZERO
				has_target_position = false
