extends Control

@onready var gold_label: Label = $VBox/GoldLabel
@onready var workers_label: Label = $VBox/WorkersLabel
@onready var feedback_label: Label = $VBox/FeedbackLabel

func _ready() -> void:
	$VBox/HireButtons/FarmerButton.pressed.connect(func() -> void: _hire("farmer"))
	$VBox/HireButtons/JuicerButton.pressed.connect(func() -> void: _hire("juicer"))
	$VBox/HireButtons/MixerButton.pressed.connect(func() -> void: _hire("mixer"))
	$VBox/HireButtons/RestockerButton.pressed.connect(func() -> void: _hire("restocker"))
	$VBox/HireButtons/CashierButton.pressed.connect(func() -> void: _hire("cashier"))
	GameState.state_changed.connect(_refresh)
	_refresh()

func _hire(worker_type: String) -> void:
	var result:String = GameState.hire_worker(worker_type)
	if result == "OK":
		feedback_label.text = "Contratado: " + worker_type
	else:
		feedback_label.text = result

func _refresh() -> void:
	gold_label.text = "Gold: %d" % GameState.gold
	workers_label.text = "Factory[f:%d j:%d m:%d] Shop[r:%d c:%d] Checkouts:%d" % [
		GameState.factory_workers["farmer"],
		GameState.factory_workers["juicer"],
		GameState.factory_workers["mixer"],
		GameState.shop_workers["restocker"],
		GameState.shop_workers["cashier"],
		GameState.checkouts
	]
