extends Area2D

## SPEC §4.2: ぷみずま
## 一度プレイヤーが owner_okaasan に近づくと _attracted になり、以後永続追従
## 3 回タップで消滅。

@export var owner_okaasan: NodePath  # 後方互換用、通常は set_okaasan() で設定
@export var player_group: String = "player"
@export var voice_normal: AudioStream
@export var voice_high: AudioStream

const D_ATTRACT := 150.0
const R_ORBIT := 80.0
const DRIFT_AMPLITUDE := 18.0
const DRIFT_SPEED := 1.2
const ORBIT_SPEED := 1.8
const FOLLOW_SMOOTHING := 4.0
const TAP_SCALE_FACTOR := 0.7
const TAP_TWEEN_TIME := 0.1
const MAX_TAPS := 3

var home_position: Vector2
var tap_count := 0
var _attracted := false

var _t := 0.0
var _phase := 0.0
var _orbit_angle := 0.0
var _okaasan: Node2D = null
var _okaasan_ref: Node2D = null
var _player: Node2D = null
@onready var _voice: AudioStreamPlayer = $Voice

func set_okaasan(okaasan: Node2D, ref: Node2D = null) -> void:
	_okaasan = okaasan
	_okaasan_ref = ref if ref else okaasan

func _ready() -> void:
	home_position = global_position
	_phase = randf() * TAU
	_orbit_angle = randf() * TAU
	_t = randf() * 10.0
	# Inspector で owner_okaasan が直接指定されている場合
	if _okaasan == null and owner_okaasan != NodePath(""):
		_okaasan = get_node_or_null(owner_okaasan)
		if _okaasan:
			var feet := _okaasan.get_node_or_null("Feet")
			_okaasan_ref = feet if feet else _okaasan
	if _okaasan_ref == null and _okaasan:
		_okaasan_ref = _okaasan
	_player = get_tree().get_first_node_in_group(player_group)
	input_event.connect(_on_input_event)
	# 複数同時鳴り対策: 微小なピッチ揺らぎで位相重なりを回避
	if _voice:
		_voice.pitch_scale = randf_range(0.95, 1.05)

func _process(delta: float) -> void:
	_t += delta
	if not _attracted and _player and _okaasan_ref:
		if _player.global_position.distance_to(_okaasan_ref.global_position) < D_ATTRACT:
			_become_attracted()
	var target: Vector2
	if _attracted and _player:
		_orbit_angle += delta * ORBIT_SPEED
		target = _player.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * R_ORBIT
		target += Vector2(sin(_t * DRIFT_SPEED + _phase), cos(_t * DRIFT_SPEED * 0.8 + _phase)) * 4.0
	else:
		var dx := sin(_t * DRIFT_SPEED + _phase) * DRIFT_AMPLITUDE
		var dy := cos(_t * DRIFT_SPEED * 0.7 + _phase) * DRIFT_AMPLITUDE
		target = home_position + Vector2(dx, dy)
	var f := 1.0 - exp(-FOLLOW_SMOOTHING * delta)
	global_position = global_position.lerp(target, f)

func _become_attracted() -> void:
	if _attracted:
		return
	_attracted = true
	add_to_group("attracted_pumizuma")
	# トップレベルの Followers コンテナへ reparent (家の中にも持ち越し)
	var carry := get_tree().get_first_node_in_group("followers_container")
	if carry and get_parent() != carry:
		var gp := global_position
		var s := scale
		get_parent().remove_child(self)
		carry.add_child(self)
		global_position = gp
		scale = s
	# 鳴き声開始 (normal)
	if _voice and voice_normal:
		_voice.stream = voice_normal
		_voice.play()
	# Main に累計獲得数を通知
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("on_pumi_attracted"):
		main.on_pumi_attracted()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var tapped := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tapped = true
	elif event is InputEventScreenTouch and event.pressed:
		tapped = true
	if tapped:
		_on_tapped()
		get_viewport().set_input_as_handled()

func _on_tapped() -> void:
	tap_count += 1
	if tap_count >= MAX_TAPS:
		# TODO: 消滅エフェクト
		if _voice:
			_voice.stop()
		queue_free()
		return
	# 一度叩かれたら high の鳴き声に切り替え
	if _voice and voice_high and _voice.stream != voice_high:
		_voice.stream = voice_high
		_voice.play()
	var t := create_tween()
	t.tween_property(self, "scale", scale * TAP_SCALE_FACTOR, TAP_TWEEN_TIME)

## VoiceManager (main.gd) からの優先度制御。
## active=false の間は stream_paused で止め、true で再開する。
func set_voice_active(active: bool) -> void:
	if not _voice:
		return
	if active:
		if not _voice.playing and _voice.stream:
			_voice.play()
		_voice.stream_paused = false
	else:
		_voice.stream_paused = true
