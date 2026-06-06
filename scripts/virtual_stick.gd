extends Control

const BASE_RADIUS := 64.0
const KNOB_RADIUS := 28.0
const BASE_COLOR := Color(0, 0, 0, 0.18)
const KNOB_COLOR := Color(0, 0, 0, 0.35)

var _active_pointer: int = -1
var _knob_offset := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(BASE_RADIUS * 2.0, BASE_RADIUS * 2.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

func get_direction() -> Vector2:
	var v := _knob_offset / BASE_RADIUS
	if v.length() < 0.15:
		return Vector2.ZERO
	if v.length() > 1.0:
		v = v.normalized()
	return v

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, BASE_RADIUS, BASE_COLOR)
	draw_circle(center + _knob_offset, KNOB_RADIUS, KNOB_COLOR)

func _gui_input(event: InputEvent) -> void:
	var center := size * 0.5
	if event is InputEventScreenTouch:
		if event.pressed and _active_pointer == -1:
			_active_pointer = event.index
			_update_knob(event.position - center)
			accept_event()
		elif not event.pressed and event.index == _active_pointer:
			_active_pointer = -1
			_update_knob(Vector2.ZERO)
			accept_event()
	elif event is InputEventScreenDrag and event.index == _active_pointer:
		_update_knob(event.position - center)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _active_pointer == -1:
				_active_pointer = -2
				_update_knob(event.position - center)
				accept_event()
			elif not event.pressed and _active_pointer == -2:
				_active_pointer = -1
				_update_knob(Vector2.ZERO)
				accept_event()
	elif event is InputEventMouseMotion and _active_pointer == -2:
		_update_knob(event.position - center)
		accept_event()

func _update_knob(offset: Vector2) -> void:
	if offset.length() > BASE_RADIUS:
		offset = offset.normalized() * BASE_RADIUS
	_knob_offset = offset
	queue_redraw()
