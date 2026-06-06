extends Sprite2D

## メカお母さん
## @export feet_offset / spawn_offsets を読んで、ぷみずまを生成・補充する

@export var pumizuma_scene: PackedScene
@export var feet_offset: Vector2 = Vector2.ZERO
@export var spawn_offsets: Array = []  # Vector2 (お母さん基準のローカル座標)

const RESPAWN_DELAY := 30.0  # SPEC §4.1 仮値

var _slots: Array = []
var _feet: Marker2D = null

func _ready() -> void:
	_feet = Marker2D.new()
	_feet.name = "Feet"
	_feet.position = feet_offset
	add_child(_feet)
	if pumizuma_scene == null:
		return
	for offset in spawn_offsets:
		var slot := {"offset": offset, "puma": null, "respawn_at": 0.0}
		_slots.append(slot)
		_spawn(slot)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for slot in _slots:
		var p = slot["puma"]
		if p != null:
			if not is_instance_valid(p):
				slot["puma"] = null
				slot["respawn_at"] = now + RESPAWN_DELAY
			elif p._attracted:
				slot["puma"] = null
				slot["respawn_at"] = now + RESPAWN_DELAY
		elif slot["respawn_at"] > 0.0 and now >= slot["respawn_at"]:
			_spawn(slot)
			slot["respawn_at"] = 0.0

func _spawn(slot: Dictionary) -> void:
	if pumizuma_scene == null:
		return
	var puma = pumizuma_scene.instantiate()
	puma.set_okaasan(self, _feet)
	add_child(puma)
	puma.position = slot["offset"]
	slot["puma"] = puma
