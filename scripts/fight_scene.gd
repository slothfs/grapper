extends Node2D
class_name FightScene

var scene_transition: SceneTransition = null

@onready var fighter: Fighter = $Fighter
@onready var enemy: SunEnemy = $enemy
@onready var flying: FlyingPlayer = $flying
@onready var camera: Camera2D = $Camera2D
@onready var tile_map: TileMap = $TileMap

const CAMERA_FOLLOW_SPEED: float = 8.0
const CAMERA_SHAKE_DECAY: float = 300.0
const PORTAL_NODE_NAME: String = "PortalVisual"
const GROUND_SEARCH_DISTANCE: int = 96

var camera_target: Node = null
var restart_allowed: bool = true
var restart_block_timer: Timer = null

func _get_landing_manager_node() -> Node:
	var landing_manager_node: Node = get_tree().get_root().get_node_or_null("LandingAreaManager")
	return landing_manager_node

func _ready() -> void:
	# Setup combat connections
	if is_instance_valid(fighter):
		fighter.switch_to_flying.connect(_on_switch_to_flying)
		fighter.hit_sun.connect(_on_fighter_hit_sun)
		fighter.died.connect(_on_fighter_died)
		fighter.camera = camera
		_set_camera_target(fighter)
	if is_instance_valid(flying):
		flying.stopped_flying.connect(_on_stopped_flying)
		flying.hide()
		flying.set_process(false)
		
	var landing_manager_node: Node = _get_landing_manager_node()
	if landing_manager_node and landing_manager_node.has_method("get_scene_transition"):
		var transition: SceneTransition = landing_manager_node.call("get_scene_transition") as SceneTransition
		if transition:
			scene_transition = transition
	camera.make_current()
	restart_block_timer = Timer.new()
	restart_block_timer.one_shot = true
	restart_block_timer.wait_time = 1.0
	restart_block_timer.timeout.connect(_on_restart_block_timeout)
	add_child(restart_block_timer)
	if scene_transition:
		await scene_transition.fade_out()

func _process(delta: float) -> void:
	_update_camera(delta)
	if is_instance_valid(flying) and is_instance_valid(fighter):
		if flying.visible:
			if not flying.get_meta("fighter_dead", false):
				fighter.global_position = flying.global_position
			
	var spawned_player = get_node_or_null("Player")
	var restart = get_node_or_null("restart")
	if restart_allowed and restart and restart.has_node("PortalVisual") and spawned_player and spawned_player.has_method("get_player_position"):
		var col = restart.get_node_or_null("CollisionShape2D")
		var check_pos = restart.global_position
		if col:
			check_pos = col.global_position
		var p_pos = spawned_player.get_player_position()
		if p_pos.distance_to(check_pos) < 100.0:
			get_tree().reload_current_scene()


func _update_camera(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	if camera_target and is_instance_valid(camera_target):
		var target_pos = _get_camera_target_position()
		camera.global_position = camera.global_position.move_toward(target_pos, CAMERA_FOLLOW_SPEED * delta)
	if is_instance_valid(fighter) and fighter.shake_strength > 0:
		var shake = fighter.shake_strength
		camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		camera.offset = camera.offset.move_toward(Vector2.ZERO, CAMERA_SHAKE_DECAY * delta)

func _get_camera_target_position() -> Vector2:
	if camera_target == null or not is_instance_valid(camera_target):
		return camera.global_position
	if camera_target.has_method("get_player_position"):
		return camera_target.get_player_position()
	return camera_target.global_position

func _set_camera_target(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		camera_target = null
		return
	camera_target = target
	camera.global_position = _get_camera_target_position()

func _get_restart_position(restart_node: Node) -> Vector2:
	if restart_node == null:
		return Vector2.ZERO
	var collision: CollisionShape2D = restart_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		return collision.global_position
	return restart_node.global_position

func _align_position_to_ground(target_position: Vector2) -> Vector2:
	var ground_position = _find_ground_position(target_position)
	if ground_position != null:
		return ground_position as Vector2
	return target_position

func _find_ground_position(target_position: Vector2) -> Variant:
	if tile_map == null:
		return null
	var used_rect: Rect2i = tile_map.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return null
	var map_pos: Vector2i = tile_map.local_to_map(target_position)
	var start_y: int = max(map_pos.y, used_rect.position.y)
	var scan_end: int = max(used_rect.position.y + used_rect.size.y - 1, start_y + GROUND_SEARCH_DISTANCE)
	var min_x: int = used_rect.position.x
	var max_x: int = max(min_x, used_rect.position.x + used_rect.size.x - 1)
	var offsets: Array = [0, -1, 1, -2, 2]
	for offset in offsets:
		var column: int = clamp(map_pos.x + offset, min_x, max_x)
		for y in range(start_y, scan_end + 1):
			var cell_coords = Vector2i(column, y)
			var source_id: int = tile_map.get_cell_source_id(0, cell_coords)
			if source_id != -1:
				var cell_world: Vector2 = tile_map.map_to_local(Vector2(column, y))
				var cell_height: float = _calculate_cell_height(cell_coords)
				return Vector2(cell_world.x, cell_world.y - cell_height * 0.5)
	return null

func _calculate_cell_height(coords: Vector2i) -> float:
	if tile_map == null:
		return 32.0
	var current_world = tile_map.map_to_local(Vector2(coords.x, coords.y))
	var below_world = tile_map.map_to_local(Vector2(coords.x, coords.y + 1))
	var height = abs(below_world.y - current_world.y)
	if height <= 0.0:
		return 32.0
	return height

func _create_restart_portal() -> Node2D:
	var portal = Node2D.new()
	portal.name = PORTAL_NODE_NAME
	
	var light = PointLight2D.new()
	light.color = Color(0.08, 0.12, 0.35)
	light.energy = 5.0
	light.texture_scale = 5.0
	var grad_tex = GradientTexture2D.new()
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	var grad = Gradient.new()
	grad.set_color(0, Color(0.4, 0.6, 1.0, 0.9))
	grad.set_color(1, Color.TRANSPARENT)
	grad_tex.gradient = grad
	light.texture = grad_tex
	portal.add_child(light)
	
	var particles = CPUParticles2D.new()
	particles.amount = 180
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 35.0
	particles.gravity = Vector2(0, -40)
	particles.scale_amount_min = 2.5
	particles.scale_amount_max = 4.5
	particles.color = Color(0.2, 0.45, 1.0, 0.8)
	particles.speed_scale = 1.5
	particles.emitting = true
	portal.add_child(particles)

	return portal

func _lock_restart_check(duration: float = 1.0) -> void:
	restart_allowed = false
	if restart_block_timer != null:
		restart_block_timer.start(duration)

func _on_restart_block_timeout() -> void:
	restart_allowed = true

func _on_switch_to_flying(dir: float) -> void:
	fighter.hide()
	fighter.set_physics_process(false)
	fighter.remove_from_group("fighter")
	
	flying.global_position = fighter.global_position
	flying.show()
	flying.set_process(true)
	
	# Add to group so enemy tracks it
	flying.add_to_group("fighter")
	
	# Initial boost
	var dir_vec = Vector2(dir, 0)
	flying.global_position += dir_vec * 10.0
	_set_camera_target(flying)

func _on_stopped_flying() -> void:
	flying.hide()
	flying.set_process(false)
	flying.remove_from_group("fighter")
	
	fighter.global_position = flying.global_position
	fighter.anim.flip_h = flying.anim.flip_h
	fighter.show()
	fighter.add_to_group("fighter")
	
	fighter.land_at(flying.global_position)
	_set_camera_target(fighter)

func _on_fighter_hit_sun() -> void:
	if is_instance_valid(enemy):
		enemy.take_damage(34.0) # Takes 3 hits to kill if hp is 100

func _on_fighter_died() -> void:
	await get_tree().create_timer(1.5).timeout
	
	var death_position: Vector2 = Vector2.ZERO
	if is_instance_valid(fighter):
		death_position = fighter.global_position

	_set_camera_target(null)
	if is_instance_valid(enemy):
		enemy.queue_free()
	
	var restart_node = get_node_or_null("restart")
	var restart_position = _get_restart_position(restart_node)
	if restart_node and restart_position == Vector2.ZERO:
		restart_position = restart_node.global_position

	if restart_node and not restart_node.has_node(PORTAL_NODE_NAME):
		var portal = _create_restart_portal()
		restart_node.add_child(portal)
		portal.position = Vector2.ZERO
	
	var spawn_pos: Vector2 = death_position
	if spawn_pos == Vector2.ZERO:
		spawn_pos = restart_position
	if spawn_pos != Vector2.ZERO:
		spawn_pos = _align_position_to_ground(spawn_pos)
	if is_instance_valid(fighter):
		fighter.remove_from_group("fighter")
		fighter.queue_free()
	
	if is_instance_valid(flying):
		flying.remove_from_group("fighter")
		flying.queue_free()
	
	var player_scene = load("res://scenes/player.tscn")
	if player_scene:
		var new_player = player_scene.instantiate()
		new_player.name = "Player"
		new_player.global_position = spawn_pos
		add_child(new_player)
		new_player.add_to_group("fighter")
		_set_camera_target(new_player)
		_lock_restart_check()
