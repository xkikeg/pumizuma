extends CharacterBody2D

const SPEED := 200.0

@export var virtual_stick_path: NodePath

var _stick: Node = null

func _ready() -> void:
	if virtual_stick_path != NodePath(""):
		_stick = get_node_or_null(virtual_stick_path)

func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _stick and _stick.has_method("get_direction"):
		dir += _stick.get_direction()
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity = dir * SPEED
	move_and_slide()
