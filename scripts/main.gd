extends Node2D

## ワールド切替: Outside <-> Inside
## 家のドアでぷみずまを連れていれば中へ、中でぷみずまが全消滅したら外へ
## 切替時にホワイトアウト

const FADE_TIME := 0.4
const INSIDE_PLAYER_POS := Vector2(0, 380)
const OUTSIDE_PLAYER_POS := Vector2(0, 50)
const MAX_VOICES := 10  # 同時に鳴らすぷみずま声の上限
const MINATOKU_THRESHOLD := 20  # 累計ぷみずま獲得数の閾値
const FUKIDASHI_HOLD := 2.0
const FUKIDASHI_INOUT := 0.35
const ENCOUNTER_PAUSE := 5.4  # minowa が出てから消えるまでの間
const ENCOUNTER_FADE := 1.0

@export var minowa_texture: Texture2D

@onready var _outside: Node = $Worlds/Outside
@onready var _inside: Node = $Worlds/Inside
@onready var _player: CharacterBody2D = $Player
@onready var _fade: ColorRect = $UI/Fade
@onready var _fukidashi: TextureRect = $UI/Fukidashi
@onready var _debug_give_btn: Button = $UI/DebugGiveBtn

var _in_inside := false
var _transitioning := false
var _pumi_collected := 0
var _minatoku_triggered := false

func _ready() -> void:
	add_to_group("main")
	_set_world_active(_outside, true)
	_set_world_active(_inside, false)
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fukidashi.scale = Vector2.ZERO
	_fukidashi.modulate.a = 0.0
	_fukidashi.visible = false
	# デバッグビルド時のみボタンを有効化
	if OS.is_debug_build():
		_debug_give_btn.visible = true
		_debug_give_btn.pressed.connect(_on_debug_give_pressed)
	else:
		_debug_give_btn.visible = false

func _on_debug_give_pressed() -> void:
	_debug_give_pumi(9)

func _debug_give_pumi(n: int) -> void:
	var puma_scene: PackedScene = load("res://scenes/pumizuma.tscn")
	if not puma_scene:
		return
	var parent: Node = _inside if _in_inside else _outside
	for i in n:
		var puma = puma_scene.instantiate()
		parent.add_child(puma)
		puma.global_position = _player.global_position + Vector2(
			randf_range(-80.0, 80.0),
			randf_range(-80.0, 80.0)
		)
		# 即座に attracted 状態へ (Main 経由のカウンタ通知も走る)
		puma._become_attracted()

func _process(_delta: float) -> void:
	if _in_inside and not _transitioning:
		if get_tree().get_nodes_in_group("attracted_pumizuma").is_empty():
			exit_house()
	_update_voice_priority()

## ぷみずまが新規に attracted になった際に pumizuma.gd から呼ばれる。
func on_pumi_attracted() -> void:
	_pumi_collected += 1
	if not _minatoku_triggered and _pumi_collected >= MINATOKU_THRESHOLD:
		_trigger_minatoku()

func _trigger_minatoku() -> void:
	_minatoku_triggered = true
	var manjiro := get_tree().get_first_node_in_group("manjiro")
	if manjiro and manjiro.has_method("transform_to_minatoku"):
		manjiro.transform_to_minatoku()
	# 手持ちのぷみずまを全消滅
	for p in get_tree().get_nodes_in_group("attracted_pumizuma"):
		if not is_instance_valid(p):
			continue
		# 家から自動退出されないよう先にグループから外す
		p.remove_from_group("attracted_pumizuma")
		var ft := create_tween()
		ft.tween_property(p, "modulate:a", 0.0, 0.3)
		ft.tween_callback(p.queue_free)
	_show_fukidashi_cutin()

func _show_fukidashi_cutin() -> void:
	_fukidashi.visible = true
	_fukidashi.scale = Vector2.ZERO
	_fukidashi.modulate.a = 1.0
	var t := create_tween()
	t.set_parallel(false)
	# pop in (オーバーシュート)
	t.tween_property(_fukidashi, "scale", Vector2(1.15, 1.15), FUKIDASHI_INOUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_fukidashi, "scale", Vector2(1.0, 1.0), 0.1)
	t.tween_interval(FUKIDASHI_HOLD)
	# pop out
	t.tween_property(_fukidashi, "scale", Vector2.ZERO, FUKIDASHI_INOUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): _fukidashi.visible = false)

## まんじろが MINATOKU 状態で初期位置に戻ったときに呼ばれる。
## minowa を出現させ、両者をフェードアウトしてから まんじろ再スポーン。
func on_manjiro_encounter(pos: Vector2, manjiro: Node) -> void:
	var minowa := Sprite2D.new()
	minowa.texture = minowa_texture
	minowa.scale = manjiro.scale if manjiro is Node2D else Vector2(0.3, 0.3)
	minowa.z_index = 5
	_outside.add_child(minowa)
	minowa.global_position = pos
	minowa.modulate.a = 0.0
	# pop in → 待ち → 両者フェードアウト → manjiro 再スポーン
	var t := create_tween()
	t.tween_property(minowa, "modulate:a", 1.0, 0.3)
	t.tween_interval(ENCOUNTER_PAUSE)
	t.set_parallel(true)
	t.tween_property(minowa, "modulate:a", 0.0, ENCOUNTER_FADE)
	t.tween_property(manjiro, "modulate:a", 0.0, ENCOUNTER_FADE)
	t.chain().tween_callback(func():
		minowa.queue_free()
		if manjiro and manjiro.has_method("encounter_finished"):
			manjiro.encounter_finished()
		# 次サイクル用にリセット
		_pumi_collected = 0
		_minatoku_triggered = false
	)

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
