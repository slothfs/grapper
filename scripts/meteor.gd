extends Node2D

@export var speed: float = 200.0
@export var move_distance: float = 500.0
@export var trail_length: int = 15

var start_pos: Vector2
var moving_right: bool = true
var trail: Line2D

func _ready() -> void:
	if has_node("KillZone"):
		$KillZone.collision_mask |= 8
	start_pos = global_position
	moving_right = randf() > 0.5
	speed = randf_range(600.0, 1500.0)
	move_distance = 10000.0
	
	var particles = CPUParticles2D.new()
	particles.amount = 30
	particles.lifetime = 0.6
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 25.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 15.0
	particles.color = Color(1.0, 1.0, 1.0, 0.5)
	add_child(particles)
	move_child(particles, 0)
	
	trail = Line2D.new()
	trail.width = 15.0
	trail.default_color = Color(1.0, 1.0, 1.0, 0.4)
	trail.top_level = true # So it doesn't move with the meteor automatically
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 1))
	trail.width_curve = curve
	add_child(trail)

func _process(delta: float) -> void:
	if moving_right:
		position.x += speed * delta
		if position.x > 8500.0:
			moving_right = false
			randomize_meteor()
	else:
		position.x -= speed * delta
		if position.x < -1000.0:
			moving_right = true
			randomize_meteor()

	# Update trail
	trail.add_point(global_position)
	if trail.get_point_count() > trail_length:
		trail.remove_point(0)

func randomize_meteor() -> void:
	speed = randf_range(600.0, 2000.0)
	position.y = randf_range(-12000.0, -6000.0)
