extends Control

@onready var gold_label: Label = $VBox/GoldLabel
@onready var workers_label: Label = $VBox/WorkersLabel
@onready var feedback_label: Label = $VBox/FeedbackLabel

func _ready() -> void:
	$VBox/HireButtons/FarmerButton.pressed.connect(_hire_factory_pool_worker)
	$VBox/HireButtons/JuicerButton.pressed.connect(_hire_factory_pool_worker)
	$VBox/HireButtons/MixerButton.pressed.connect(_hire_factory_pool_worker)
	$VBox/HireButtons/RestockerButton.pressed.connect(func() -> void: _hire_shop_worker("restocker"))
	$VBox/HireButtons/CashierButton.pressed.connect(func() -> void: _hire_shop_worker("cashier"))
	GameState.state_changed.connect(_refresh)
	_refresh()

func _hire_factory_pool_worker() -> void:
	var result:String = GameState.try_hire_factory_worker()
	if result == "OK":
		feedback_label.text = "Worker de fábrica contratado"
	else:
		feedback_label.text = result

func _hire_shop_worker(worker_type: String) -> void:
	var result:String = GameState.hire_worker(worker_type)
	if result == "OK":
		feedback_label.text = "Contratado: " + worker_type
	else:
		feedback_label.text = result

func _refresh() -> void:
	gold_label.text = "Gold: %d" % GameState.gold
	workers_label.text = "Factory pool total:%d libres:%d coste:%d | Shop[r:%d c:%d] Checkouts:%d" % [
		GameState.factory_worker_pool_total,
		GameState.factory_worker_pool_unassigned,
		GameState.get_factory_worker_hire_cost(),
		GameState.shop_workers["restocker"],
		GameState.shop_workers["cashier"],
		GameState.checkouts
	]
