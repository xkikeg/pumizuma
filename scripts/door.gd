extends Area2D

## 家のドア。プレイヤーが接触すると Main に入室を依頼する

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("try_enter_house"):
		main.try_enter_house()
