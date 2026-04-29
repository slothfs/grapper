extends Node2D
class_name Player

@export var speed: float = 200.0
@export var jump_force: float = -450.0
@export var acceleration: float = 1000
@export var gravity: float = 900.0
@export var gravity_scale: float = 1.0
@export var grapple_pull_speed: float = 600.0
@export var grapple_max_distance: float = 500.0
@export var extra_air_jumps: int = 1

@export var min_light_energy: float = 0.5
@export var max_light_energy: float = 1.2
@export var brightness_adjust_speed: float = 2.0
@export var brightness_source_path: NodePath = NodePath("../CanvasModulate")
@export var gradient_source_path: NodePath = NodePath("../BG/BackgroundGradient")
@export var gradient_top_y: float = -15000.0
@export var gradient_bottom_y: float = 5000.0

const HOOK_SPEED: float = 900.0
const LIGHT_MASK: int = 1
const ENVIRONMENT_COLLISION_LAYER: int = 1
const PLAYER_COLLISION_LAYER: int = 2
const BRIGHTNESS_WEIGHTS: Vector3 = Vector3(0.299, 0.587, 0.114)
const DEFAULT_GRADIENT_TOP_COLOR: Color = Color(0.09, 0.02, 0.16, 1.0)
const DEFAULT_GRADIENT_BOTTOM_COLOR: Color = Color(0.02, 0.03, 0.14, 1.0)
const DEFAULT_GRADIENT_EXPONENT: float = 1.25

@onready var softbody_node: SoftBody2D = $SoftBody2D
@onready var floor_ray: RayCast2D = $FloorRay
@onready var chain_node: Node2D = $Chain
@onready var crosshair: Crosshair = $Crosshair
@onready var player_light: PointLight2D = $PointLight2D
@onready var brightness_source: CanvasModulate = null
@onready var background_gradient: ColorRect = null
@onready var gradient_shader: ShaderMaterial = null
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var falling_sound: AudioStreamPlayer2D = $FallingSound

var tile_map: TileMapLayer = null
var hook_tip: HookTip = null
var center_rigidbody: RigidBody2D = null
var softbody_base_scale_x: float = 1.0
var softbody_scale_y: float = 1.0
var softbody_facing_right: bool = true

var hook_active: bool = false
var hook_released: bool = true
var grapple_velocity: Vector2 = Vector2.ZERO
var air_jumps_remaining: int = 0

func _ready() -> void:
	if chain_node != null and chain_node.has_node("Tip"):
		hook_tip = chain_node.get_node("Tip") as HookTip
		hook_tip.collision_mask = ENVIRONMENT_COLLISION_LAYER # Ensure hook only collides with environment
		hook_tip.collision_layer = 4
	else:
		push_error("Hook Tip (Chain/Tip) not found! Check scene structure.")

	if crosshair == null:
		push_warning("Crosshair missing. The aiming system may not work.")

	brightness_source = get_node_or_null(brightness_source_path) as CanvasModulate
	var parent_node: Node = get_parent()
	if brightness_source == null and parent_node != null and parent_node.has_node("CanvasModulate"):
		brightness_source = parent_node.get_node("CanvasModulate") as CanvasModulate
	if parent_node != null and parent_node.has_node("TileMapLayer"):
		var found_tile_map: TileMapLayer = parent_node.get_node("TileMapLayer") as TileMapLayer
		if found_tile_map != null and player_light != null:
			tile_map = found_tile_map
			tile_map.light_mask = LIGHT_MASK
			_configure_tilemap_lighting(tile_map)
			player_light.light_mask = LIGHT_MASK
			player_light.range_item_cull_mask = LIGHT_MASK
			player_light.shadow_item_cull_mask = LIGHT_MASK

	background_gradient = get_node_or_null(gradient_source_path) as ColorRect
	if background_gradient == null and parent_node != null and parent_node.has_node("BG/BackgroundGradient"):
		background_gradient = parent_node.get_node("BG/BackgroundGradient") as ColorRect
	if background_gradient != null:
		if background_gradient.material is ShaderMaterial:
			gradient_shader = background_gradient.material as ShaderMaterial
		else:
			push_warning("BackgroundGradient does not have a ShaderMaterial assigned.")

	if floor_ray != null:
		floor_ray.target_position = Vector2(0, 24) # Short enough for 1.0 scale

	air_jumps_remaining = max(extra_air_jumps, 0)
	add_to_group("player")
	
	var trail = GPUParticles2D.new()
	trail.name = "Trail"
	trail.amount = 15
	trail.lifetime = 0.5
	trail.local_coords = false
	var trail_mat = CanvasItemMaterial.new()
	trail_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	trail.material = trail_mat
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 12.0
	mat.gravity = Vector3(0, -30, 0)
	mat.scale_min = 4.0
	mat.scale_max = 10.0
	mat.color = Color.WHITE
	trail.process_material = mat
	add_child(trail)

	call_deferred("_initialize_softbody")

func _configure_tilemap_lighting(map: TileMapLayer) -> void:
	if map == null:
		return
	var new_material: CanvasItemMaterial = null
	if map.material is CanvasItemMaterial:
		new_material = map.material as CanvasItemMaterial
	else:
		new_material = CanvasItemMaterial.new()
		map.material = new_material
	new_material.light_mode = CanvasItemMaterial.LIGHT_MODE_NORMAL

func _calculate_color_brightness(color: Color) -> float:
	var brightness: float = color.r * BRIGHTNESS_WEIGHTS.x
	brightness += color.g * BRIGHTNESS_WEIGHTS.y
	brightness += color.b * BRIGHTNESS_WEIGHTS.z
	return clamp(brightness, 0.0, 1.0)

func _get_shader_color_parameter(param_name: String, default_color: Color) -> Color:
	if gradient_shader == null:
		return default_color
	var param_value = gradient_shader.get_shader_parameter(param_name)
	if param_value is Color:
		return param_value
	return default_color

func _get_shader_float_parameter(param_name: String, default_value: float) -> float:
	if gradient_shader == null:
		return default_value
	var param_value = gradient_shader.get_shader_parameter(param_name)
	if typeof(param_value) == TYPE_FLOAT:
		return float(param_value)
	return default_value

func _calculate_gradient_brightness() -> float:
	var brightness: float = -1.0
	if gradient_shader == null:
		return brightness
	var top_color: Color = _get_shader_color_parameter("top_color", DEFAULT_GRADIENT_TOP_COLOR)
	var bottom_color: Color = _get_shader_color_parameter("bottom_color", DEFAULT_GRADIENT_BOTTOM_COLOR)
	var exponent_value: float = _get_shader_float_parameter("gradient_exponent", DEFAULT_GRADIENT_EXPONENT)
	var y_range: float = gradient_bottom_y - gradient_top_y
	if abs(y_range) < 0.001:
		y_range = 0.001
	var normalized_y: float = clamp((global_position.y - gradient_top_y) / y_range, 0.0, 1.0)
	var gradient_value: float = pow(normalized_y, max(exponent_value, 0.001))
	var sampled_color: Color = bottom_color.lerp(top_color, gradient_value)
	return _calculate_color_brightness(sampled_color)

func _update_light_energy(delta: float) -> void:
	if player_light == null:
		return
	var canvas_brightness: float = 1.0
	if brightness_source != null:
		canvas_brightness = _calculate_color_brightness(brightness_source.color)
	var gradient_brightness: float = _calculate_gradient_brightness()
	var brightness: float = canvas_brightness
	if gradient_brightness >= 0.0:
		brightness = min(canvas_brightness, gradient_brightness)
	var desired_energy: float = lerp(max_light_energy, min_light_energy, brightness)
	desired_energy = clamp(desired_energy, min_light_energy, max_light_energy)
	var blend: float = clamp(brightness_adjust_speed * delta, 0.0, 1.0)
	player_light.energy = lerp(player_light.energy, desired_energy, blend)

func _generate_circle_texture_and_polygon(radius: float) -> void:
	var size = int(radius * 2.0)
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	for y in range(size):
		for x in range(size):
			var dist = Vector2(x - radius, y - radius).length()
			if dist <= radius:
				if dist >= radius - 2.0:
					img.set_pixel(x, y, Color.BLACK)
				else:
					img.set_pixel(x, y, Color(0.2, 0.7, 0.9, 1.0))
			else:
				img.set_pixel(x, y, Color.TRANSPARENT)
				
	var tex = ImageTexture.create_from_image(img)
	softbody_node.texture = tex
	
	var points = PackedVector2Array()
	var num_points = 16
	for i in range(num_points):
		var angle = i * TAU / num_points
		points.append(Vector2(radius, radius) + Vector2(cos(angle), sin(angle)) * radius)
	
	softbody_node.polygon = points

func _initialize_softbody() -> void:
	if softbody_node == null:
		push_error("SoftBody2D node missing. Player visuals are unavailable.")
		return

	_generate_circle_texture_and_polygon(16.0)

	softbody_node.collision_layer = PLAYER_COLLISION_LAYER
	softbody_node.collision_mask = ENVIRONMENT_COLLISION_LAYER | PLAYER_COLLISION_LAYER

	# Force the SoftBody2D to regenerate its mesh and bones from the new circular texture
	softbody_node.create_softbody2d(true)

	softbody_base_scale_x = abs(softbody_node.scale.x)
	softbody_scale_y = softbody_node.scale.y

	center_rigidbody = _get_center_rigidbody()
	if center_rigidbody == null:
		push_error("Failed to locate the center rigidbody inside the softbody.")
		return

	center_rigidbody.gravity_scale = gravity_scale
	

	var bouncy_mat = PhysicsMaterial.new()
	bouncy_mat.bounce = 0.5
	bouncy_mat.friction = 0.8
	
	softbody_node.physics_material_override = bouncy_mat


	var rigid_bodies: Array = softbody_node.get_rigid_bodies()
	for rb_data in rigid_bodies:
		if "rigidbody" in rb_data and rb_data.rigidbody is RigidBody2D:
			var rb: RigidBody2D = rb_data.rigidbody
			rb.physics_material_override = bouncy_mat
			rb.collision_layer = softbody_node.collision_layer
			rb.collision_mask = softbody_node.collision_mask
		if "joints" in rb_data:
			for joint in rb_data.joints:
				if joint is PinJoint2D:
					joint.softness = 10.0

func _get_center_rigidbody() -> RigidBody2D:
	if softbody_node == null:
		return null
	var center_body := softbody_node.get_center_body()
	if center_body == null:
		return null
	return center_body.rigidbody as RigidBody2D

func _physics_process(delta: float) -> void:
	if center_rigidbody == null:
		_initialize_softbody()
		if center_rigidbody == null:
			return

	_update_floor_ray_position()
	
	var on_floor_now: bool = is_on_floor()
	if on_floor_now:
		air_jumps_remaining = max(extra_air_jumps, 0)
	
	if has_node("Trail"):
		get_node("Trail").global_position = get_player_position()
		
	if player_light != null:
		player_light.global_position = get_player_position()

	_update_light_energy(delta)

	handle_input()

	if hook_active and hook_tip != null:
		if hook_tip.is_hooked:
			apply_grapple_pull(delta)
		elif hook_tip.velocity == Vector2.ZERO or hook_tip.flight_timer >= 3.0:
			release()
			apply_normal_movement(delta, on_floor_now)
		else:
			apply_normal_movement(delta, on_floor_now)
	else:
		apply_normal_movement(delta, on_floor_now)

	update_softbody_orientation()
	_update_falling_sound(on_floor_now)

func _update_falling_sound(on_floor: bool) -> void:
	if falling_sound == null:
		return
	var vertical_velocity: float = 0.0
	if center_rigidbody != null:
		vertical_velocity = center_rigidbody.linear_velocity.y
	var is_descending: bool = vertical_velocity > 0.0
	var has_hook_attached: bool = hook_tip != null and hook_tip.is_hooked
	var should_play_sound: bool = not on_floor and is_descending and not has_hook_attached
	if should_play_sound:
		if not falling_sound.is_playing():
			falling_sound.play()
		return
	if falling_sound.is_playing():
		falling_sound.stop()

func handle_input() -> void:
	if Input.is_action_just_pressed("shoot"):
		shoot()
	if Input.is_action_just_pressed("release"):
		release()

func apply_normal_movement(delta: float, on_floor: bool) -> void:
	var input_direction: float = 0.0
	if Input.is_action_pressed("right"):
		input_direction += 1.0
	if Input.is_action_pressed("left"):
		input_direction -= 1.0

	var jump_pressed: bool = Input.is_action_just_pressed("jump")
	var should_jump: bool = false
	if jump_pressed:
		if on_floor:
			should_jump = true
		elif air_jumps_remaining > 0:
			should_jump = true
			air_jumps_remaining -= 1

	if should_jump and jump_sound != null:
		jump_sound.play()

	if softbody_node:
		var rigid_bodies: Array = softbody_node.get_rigid_bodies()
		for rb_data in rigid_bodies:
			if "rigidbody" in rb_data and rb_data.rigidbody is RigidBody2D:
				var rb: RigidBody2D = rb_data.rigidbody
				
				# Apply a rolling torque so the circular body rotates naturally
				rb.apply_torque(input_direction * 12000.0)
				
				var current_velocity: Vector2 = rb.linear_velocity
				
				# Apply damping when no input is pressed, or horizontal force when pressed
				if input_direction == 0:
					current_velocity.x = move_toward(current_velocity.x, 0, acceleration * delta)
					rb.linear_velocity = Vector2(current_velocity.x, rb.linear_velocity.y)
				else:
					rb.apply_central_force(Vector2(input_direction * acceleration * 2.0, 0))
					if abs(rb.linear_velocity.x) > speed:
						rb.linear_velocity = Vector2(sign(rb.linear_velocity.x) * speed, rb.linear_velocity.y)

				if should_jump:
					rb.linear_velocity = Vector2(rb.linear_velocity.x, jump_force)


func is_on_floor() -> bool:
	if floor_ray == null:
		return false
	return floor_ray.is_colliding()

func _update_floor_ray_position() -> void:
	if floor_ray == null:
		return
	floor_ray.global_position = get_player_position()
	floor_ray.force_raycast_update()

func update_softbody_orientation() -> void:
	if softbody_node == null or center_rigidbody == null:
		return

	var horizontal_velocity: float = center_rigidbody.linear_velocity.x
	if horizontal_velocity > 0.0:
		softbody_facing_right = true
	elif horizontal_velocity < 0.0:
		softbody_facing_right = false

	# We skip scaling the SoftBody2D natively because flipping physics nodes 
	# (scale.x = -1) causes physics engine explosions and duplicate visual glitches!
	# softbody_node.scale = ...


func shoot() -> void:
	if hook_tip == null:
		push_error("Hook Tip (Chain/Tip) not found in scene tree!")
		return

	var player_position: Vector2 = get_player_position()
	var aim_target: Vector2 = player_position
	if crosshair != null:
		aim_target = crosshair.global_position
	else:
		aim_target = get_global_mouse_position()

	var raw_direction: Vector2 = aim_target - player_position
	if raw_direction == Vector2.ZERO:
		return

	var distance_to_target: float = raw_direction.length()
	var aim_direction: Vector2 = raw_direction / distance_to_target
	var clamped_distance: float = min(distance_to_target, grapple_max_distance)
	var target_position: Vector2 = player_position + aim_direction * clamped_distance

	hook_active = true
	hook_released = false
	hook_tip.visible = true
	hook_tip.global_position = player_position
	hook_tip.set_target_position(target_position)
	hook_tip.velocity = aim_direction * HOOK_SPEED

func release() -> void:
	if hook_tip == null:
		return

	hook_active = false
	hook_released = true
	hook_tip.visible = false
	hook_tip.velocity = Vector2.ZERO
	hook_tip.clear_target_position()
	hook_tip.global_position = get_player_position()

func apply_grapple_pull(delta: float) -> void:
	if hook_tip == null:
		return

	var player_position: Vector2 = get_player_position()
	var direction: Vector2 = (hook_tip.global_position - player_position).normalized()
	var distance: float = player_position.distance_to(hook_tip.global_position)

	if distance < 20.0:
		release()
		return

	grapple_velocity = direction * grapple_pull_speed
	var swing_input := 0.0
	if Input.is_action_pressed("right"):
		swing_input += 1.0
	if Input.is_action_pressed("left"):
		swing_input -= 1.0
		
	var jump_pressed := Input.is_action_just_pressed("jump")
		
	grapple_velocity.x += swing_input * speed * 0.5
	grapple_velocity.y += gravity * delta * 0.3
	
	if softbody_node:
		var rigid_bodies: Array = softbody_node.get_rigid_bodies()
		for rb_data in rigid_bodies:
			if "rigidbody" in rb_data and rb_data.rigidbody is RigidBody2D:
				var rb: RigidBody2D = rb_data.rigidbody
				
				# Pull strongly by applying central force 
				rb.apply_central_force(direction * grapple_pull_speed * 4.0 * rb.mass)
				
				# Allow swinging back and forth when attached
				if swing_input != 0.0:
					var max_swing_speed = speed * 2.0
					if (swing_input > 0 and rb.linear_velocity.x < max_swing_speed) or (swing_input < 0 and rb.linear_velocity.x > -max_swing_speed):
						rb.apply_central_force(Vector2(swing_input * acceleration * 2.0 * rb.mass, 0))
				
				# Apply a gentle torque to give it a spinning effect while grappling
				rb.apply_torque(grapple_velocity.x * 20.0)
				

					
				# Dampen extreme velocities smoothly
				var current_speed = rb.linear_velocity.length()
				if current_speed > grapple_pull_speed * 1.5:
					rb.linear_velocity = rb.linear_velocity.move_toward(rb.linear_velocity.normalized() * grapple_pull_speed, delta * grapple_pull_speed * 2.0)

		if jump_pressed:
			release()
			return

	elif center_rigidbody:
		if jump_pressed:
			var tangent = Vector2(-direction.y, direction.x)
			var side = 1.0
			if swing_input != 0.0:
				side = sign(swing_input) * sign(tangent.x)
			elif center_rigidbody.linear_velocity.x != 0.0:
				side = sign(center_rigidbody.linear_velocity.x) * sign(tangent.x)
			var swing_dir = tangent * side
			if swing_dir.y > 0.0:
				swing_dir = -swing_dir
			center_rigidbody.linear_velocity = swing_dir * 1000.0 + Vector2(0, jump_force)
			release()
			return
		center_rigidbody.linear_velocity = grapple_velocity


func get_player_position() -> Vector2:
	if center_rigidbody != null:
		return center_rigidbody.global_position
	if softbody_node != null:
		return softbody_node.global_position
	return global_position


func _on_area_2d_body_entered(_body: Node2D) -> void:
	get_tree().reload_current_scene()
