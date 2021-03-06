extends Node

const COLLIDER_SLOTS_NUMBER = 5
const PHASES_STIFFNESS = [ 150.0, 100.0, 50.0, 0.0 ]
const PHASE_WAVES_NUMBER = 100

export(PackedScene) var target_wall = null
export(PackedScene) var score_animation = null

var setpoint_positions = []
var setpoint_position = 0

var total_waves_number = PHASES_STIFFNESS.size() * PHASE_WAVES_NUMBER
var waves_count = 0
var score = 0
var score_state = 0

onready var boundary_area = get_node( "BoundaryArea" )
onready var boundaries = boundary_area.get_node( "Boundaries" )
onready var boundary_extents = boundaries.shape.extents

onready var player = boundaries.get_node( "Player" )

onready var collider_width = 2 * boundary_extents.y / COLLIDER_SLOTS_NUMBER
onready var collider_top = -boundary_extents.y + collider_width / 2

func _ready():
	$GUI.set_timeouts( 3.0, 0.0 )
	if Controller.is_calibrating: $GUI.set_max_effort( 100.0 )
	else: $GUI.set_max_effort( 80.0 )
	if Controller.direction_axis == Controller.HORIZONTAL:
		$Camera.rotate_z( PI / 2 )
		$Camera.translation.x = -3.7
		$Background.translation.x = $Camera.translation.x
		var background_size = $Background.region_rect.size
		background_size = Vector2( background_size.y, background_size.x )
		$Background.region_rect = Rect2( Vector2( 0, 0 ), background_size )
	$GUI.display_setpoint( 0.0 )

func _physics_process( delta ):
	var controller_values = Controller.get_axis_values()
	var new_position = controller_values[ Controller.POSITION ] * boundary_extents.y
	new_position = clamp( new_position, -boundary_extents.y, boundary_extents.y )
	var position_delta = new_position - player.translation.y
	player.translation.y = new_position
	
	if not Controller.is_calibrating:
		var measure_position = player.translation.y / boundary_extents.y
		DataLog.register_values( [ setpoint_position, player.translation.y, score_state ] )
		score_state = 0

func _set_setpoint():
	if setpoint_positions.size() > 0:
		setpoint_position = setpoint_positions.front()
		var stiffness_phase = int( waves_count / PHASE_WAVES_NUMBER ) % PHASES_STIFFNESS.size()
		Controller.set_axis_values( setpoint_position, PHASES_STIFFNESS[ stiffness_phase ] )
		$GUI.display_setpoint( setpoint_position )

func _on_GUI_game_timeout( timeouts_count ):
	if timeouts_count < total_waves_number:
		var score_area = target_wall.instance()
		score_area.translation.x = boundary_extents.x + timeouts_count * 2 * score_area.get_width().x
		score_area.connect( "wall_passed", self, "_on_ScoreArea_wall_passed" )
		score_area.connect( "collider_reached", self, "_on_ScoreArea_collider_reached" )
		boundaries.add_child( score_area )
		var target_position = score_area.spawn_colliders( COLLIDER_SLOTS_NUMBER )
		setpoint_positions.push_back( target_position / boundary_extents.y )
		_set_setpoint()

func _on_BoundaryArea_area_exited( area ):
	area.queue_free()

func _on_ScoreArea_wall_passed( has_passed_ok ):
	score_state = -1
	if has_passed_ok:
		score += 1
		score_state = 1
		var score_up = score_animation.instance()
		player.add_child( score_up )
	setpoint_positions.pop_front()
	waves_count += 1
	if waves_count >= total_waves_number: $GUI.end_game( waves_count, score )
	_set_setpoint()

func _on_ScoreArea_collider_reached( collider ):
	player.interact( collider )

func _on_GUI_game_toggle( started ):
	Controller.set_axis_values( 0.0, 1.0 )
	if Controller.is_calibrating: Controller.set_status( 3 )
	elif Controller.direction_axis == Controller.VERTICAL: Controller.set_status( 2 )
	else: Controller.set_status( 6 )
