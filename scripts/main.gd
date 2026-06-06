extends Node2D

## ワールド切替: Outside <-> Inside
## 家のドアでぷみずまを連れていれば中へ、中でぷみずまが全消滅したら外へ
## 切替時にホワイトアウト

const FADE_TIME := 0.4
const INSIDE_PLAYER_POS := Vector2(0, 380)
const OUTSIDE_PLAYER_POS := Vector2(0, 50)
const MAX_VOICES := 10  # 同時に鳴らすぷみずま声の上限

@onready var _outside: Node = $Worlds/Outside
@onready var _inside: Node = $Worlds/Inside
@onready var _player: CharacterBody2D = $Player
@onready var _fade: ColorRect = $UI/Fade

var _in_inside := false
var _transitioning := false

func _ready() -> void:
	add_to_group("main")
	_set_world_active(_outside, true)
	_set_world_active(_inside, false)
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if _in_inside and not _transitioning:
		if get_tree().get_nodes_in_group("attracted_pumizuma").is_empty():
			exit_house()
	_update_voice_priority()

## プレイヤーに近い順に MAX_VOICES 匹だけ鳴らす。
## normal と high の両方が存在する場合は、個数比に応じて配分しつつ
## 各種別に最低1スロットは確保する。
func _update_voice_priority() -> void:
	var pumis := get_tree().get_nodes_in_group("attracted_pumizuma")
	if pumis.is_empty():
		return
	var pp := _player.global_position
	var normals: Array = []
	var highs: Array = []
	for p in pumis:
		if not is_instance_valid(p) or not p.has_method("set_voice_active"):
			continue
		if p.tap_count > 0:
			highs.append(p)
		else:
			normals.append(p)
	var cmp := func(a, b): return a.global_position.distance_squared_to(pp) < b.global_position.distance_squared_to(pp)
	normals.sort_custom(cmp)
	highs.sort_custom(cmp)

	var n_n := normals.size()
	var n_h := highs.size()
	var slots_n: int
	var slots_h: int
	if n_n + n_h <= MAX_VOICES:
		slots_n = n_n
		slots_h = n_h
	else:
		# 個数比で配分
		slots_n = int(round(float(MAX_VOICES * n_n) / float(n_n + n_h)))
		slots_h = MAX_VOICES - slots_n
		# 両種別が存在するときは最低1枠ずつ確保
		if n_h > 0 and slots_h == 0:
			slots_h = 1
			slots_n = MAX_VOICES - 1
		if n_n > 0 and slots_n == 0:
			slots_n = 1
			slots_h = MAX_VOICES - 1
		slots_n = mini(slots_n, n_n)
		slots_h = mini(slots_h, n_h)

	for i in normals.size():
		normals[i].set_voice_active(i < slots_n)
	for i in highs.size():
		highs[i].set_voice_active(i < slots_h)

func try_enter_house() -> void:
	if _in_inside or _transitioning:
		return
	if get_tree().get_nodes_in_group("attracted_pumizuma").is_empty():
		return  # ぷみずまを連れていない時は入れない
	_transition(true)

func exit_house() -> void:
	if not _in_inside or _transitioning:
		return
	_transition(false)

func _transition(to_inside: bool) -> void:
	_transitioning = true
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	t.tween_callback(_do_swap.bind(to_inside))
	t.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
	t.tween_callback(_end_transition)

func _do_swap(to_inside: bool) -> void:
	if to_inside:
		_set_world_active(_outside, false)
		_set_world_active(_inside, true)
		_player.global_position = INSIDE_PLAYER_POS
		_in_inside = true
	else:
		_set_world_active(_inside, false)
		_set_world_active(_outside, true)
		_player.global_position = OUTSIDE_PLAYER_POS
		_in_inside = false

func _end_transition() -> void:
	_transitioning = false

func _set_world_active(world: Node, active: bool) -> void:
	world.visible = active
	world.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
