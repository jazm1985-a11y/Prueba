extends Control

signal navigate(screen_name: String)

@onready var gold_label: Label = $VBoxContainer/GoldLabel
@onready var message_label: Label = $VBoxContainer/MessageLabel

func _ready() -> void:
	GameState.state_changed.connect(_refresh)
	GameState.ui_message.connect(_show_message)
	_refresh()

func _exit_tree() -> void:
	if GameState.state_changed.is_connected(_refresh):
		GameState.state_changed.disconnect(_refresh)
	if GameState.ui_message.is_connected(_show_message):
		GameState.ui_message.disconnect(_show_message)

func _refresh() -> void:
	gold_label.text = "Gold: %d" % GameState.gold

func _show_message(text: String) -> void:
	message_label.text = text

func _on_farmer_pressed() -> void:
	GameState.add_worker("farmer")

func _on_juicer_pressed() -> void:
	GameState.add_worker("juicer")

func _on_mixer_pressed() -> void:
	GameState.add_worker("mixer")

func _on_restocker_pressed() -> void:
	GameState.add_worker("restocker")

func _on_cashier_pressed() -> void:
	GameState.add_worker("cashier")

func _on_factory_pressed() -> void:
	navigate.emit("factory")

func _on_shop_pressed() -> void:
	navigate.emit("shop")
