extends Sprite2D

## 家族(まんじろ)
## プレイヤーに接近すると追従、一定時間後にぱっと消えて再配置

@export var player_group: String = "player"
@export var respawn_min: Vector2 = Vector2(-1200, -700)
@export var respawn_max: Vector2 = Vector2(1200, 700)

const D_ATTRACT := 150.0
const FOLLOW_OFFSET := Vector2(30, 0)    # 同じ高さ (lag で自然に後ろになる)
const FOLLOW_SMOOTHING := 2.5           # 遅めにラグらせる
const FOLLOW_DURATION := 120.0          # 2分追従でぱっと消える
const FADE_TIME := 0.25

enum State { IDLE, FOLLOWING, POOFING }

var _state: int = State.IDLE
var _player: Node2D = null
var _follow_timer := 0.0
var _home_parent: Node = null

func _ready() -> void:
	_player = get_tree().get_first_node_in_group(player_group)
	_home_parent = get_parent()

func _process(delta: float) -> void:
	if not _player:
		return
	match _state:
		State.IDLE:
			if global_position.distance_to(_player.global_position) < D_ATTRACT:
				_start_following()
		State.FOLLOWING:
			var target := _player.global_position + FOLLOW_OFFSET
			var f := 1.0 - exp(-FOLLOW_SMOOTHING * delta)
			global_position = global_position.lerp(target, f)
			_follow_timer += delta
			if _follow_timer >= FOLLOW_DURATION:
				_poof_and_respawn()

func _start_following() -> void:
	_state = State.FOLLOWING
	_follow_timer = 0.0
	# Followers コンテナへ reparent (家の中にも持ち越し)
	var carry := get_tree().get_first_node_in_group("followers_container")
	if carry and get_parent() != carry:
		var gp := global_position
		get_parent().remove_child(self)
		carry.add_child(self)
		global_position = gp

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
