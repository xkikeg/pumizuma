extends Sprite2D

## 家族(まんじろ)
## プレイヤーに接近すると追従、一定時間後にぱっと消えて再配置。
## 累計ぷみずま 20 匹で「みなとく」状態に変身しカットイン。
## 初期位置に戻ると minowa が現れ、両者フェードアウトして通常状態で再スポーン。

@export var player_group: String = "player"
@export var respawn_min: Vector2 = Vector2(-1200, -700)
@export var respawn_max: Vector2 = Vector2(1200, 700)
@export var minatoku_texture: Texture2D

const D_ATTRACT := 150.0
const FOLLOW_OFFSET := Vector2(30, 0)    # 同じ高さ (lag で自然に後ろになる)
const FOLLOW_SMOOTHING := 2.5           # 遅めにラグらせる
const FOLLOW_DURATION := 120.0          # 2分追従でぱっと消える
const FADE_TIME := 0.25
const D_ENCOUNTER := 120.0              # プレイヤーがまんじろ初期位置に近づいたら encounter

enum State { IDLE, FOLLOWING, MINATOKU, POOFING, ENCOUNTER }

var _state: int = State.IDLE
var _player: Node2D = null
var _follow_timer := 0.0
var _home_parent: Node = null
var _home_position: Vector2
var _normal_texture: Texture2D = null
var _encounter_allowed := false

func _ready() -> void:
	add_to_group("manjiro")
	_player = get_tree().get_first_node_in_group(player_group)
	_home_parent = get_parent()
	_home_position = global_position
	_normal_texture = texture

func _process(delta: float) -> void:
	if not _player:
		return
	match _state:
		State.IDLE:
			if global_position.distance_to(_player.global_position) < D_ATTRACT:
				_start_following()
		State.FOLLOWING:
			_follow_player(delta)
			_follow_timer += delta
			if _follow_timer >= FOLLOW_DURATION:
				_poof_and_respawn()
		State.MINATOKU:
			_follow_player(delta)
			# カットイン演出中は encounter をロック。
			# 解禁後にプレイヤーが まんじろ初期位置 に近づいたら encounter 開始
			if _encounter_allowed and _player.global_position.distance_to(_home_position) < D_ENCOUNTER:
				_start_encounter()

func _follow_player(delta: float) -> void:
	var target := _player.global_position + FOLLOW_OFFSET
	var f := 1.0 - exp(-FOLLOW_SMOOTHING * delta)
	global_position = global_position.lerp(target, f)

func _start_following() -> void:
	_state = State.FOLLOWING
	_follow_timer = 0.0
	_ensure_in_followers()
	# 累計閾値超過済みなら Main 側で minatoku 変身を起動できるよう通知
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("on_manjiro_started_following"):
		main.on_manjiro_started_following()

func is_following() -> bool:
	return _state == State.FOLLOWING

func unlock_encounter() -> void:
	_encounter_allowed = true

func _ensure_in_followers() -> void:
	var carry := get_tree().get_first_node_in_group("followers_container")
	if carry and get_parent() != carry:
		var gp := global_position
		var s := scale
		get_parent().remove_child(self)
		carry.add_child(self)
		global_position = gp
		scale = s

## Main から呼ばれる: 累計ぷみずま閾値で呼ばれてみなとく状態に変身。
## fukidashi カットインが終わるまで encounter はロックされる。
func transform_to_minatoku() -> void:
	if _state == State.MINATOKU or _state == State.ENCOUNTER:
		return
	_state = State.MINATOKU
	_encounter_allowed = false
	if minatoku_texture:
		texture = minatoku_texture
	_ensure_in_followers()

func _start_encounter() -> void:
	_state = State.ENCOUNTER
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("on_manjiro_encounter"):
		main.on_manjiro_encounter(_home_position, self)

## Main から encounter 演出後に呼ばれる: 通常テクスチャで再スポーン。
func encounter_finished() -> void:
	_encounter_allowed = false
	if _normal_texture:
		texture = _normal_texture
	modulate.a = 1.0
	_do_respawn()

func _poof_and_respawn() -> void:
	_state = State.POOFING
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	t.tween_callback(_do_respawn)
	t.tween_property(self, "modulate:a", 1.0, FADE_TIME)

func _do_respawn() -> void:
	# 元の親 (Outside.NPCs) に戻し、ランダム位置へ
	if _home_parent and get_parent() != _home_parent:
		var s := scale
		get_parent().remove_child(self)
		_home_parent.add_child(self)
		scale = s
	global_position = Vector2(
		randf_range(respawn_min.x, respawn_max.x),
		randf_range(respawn_min.y, respawn_max.y)
	)
	_state = State.IDLE
	_follow_timer = 0.0
