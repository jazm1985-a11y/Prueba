extends Control

@onready var gold_label: Label = $VBox/GoldLabel
@onready var workers_label: Label = $VBox/WorkersLabel
@onready var feedback_label: Label = $VBox/FeedbackLabel

func _ready() -> void:
	$VBox/HireButtons/FarmerButton.pressed.connect(_upgrade_factory_grid)
	$VBox/HireButtons/JuicerButton.pressed.connect(_upgrade_checkouts)
	$VBox/HireButtons/MixerButton.pressed.connect(_upgrade_shelves)
	$VBox/HireButtons/RestockerButton.pressed.connect(_upgrade_max_customers)
	$VBox/HireButtons/CashierButton.disabled = true
	$VBox/HireButtons/CashierButton.text = "Contrata workers en Factory/Shop"
	GameState.state_changed.connect(_refresh)
	_refresh()

func _upgrade_factory_grid() -> void:
	var result:String = GameState.try_upgrade_factory_grid()
	feedback_label.text = "Fábrica ampliada" if result == "OK" else result

func _upgrade_checkouts() -> void:
	var result:String = GameState.try_upgrade_checkouts()
	feedback_label.text = "Nueva caja" if result == "OK" else result

func _upgrade_shelves() -> void:
	var result:String = GameState.try_upgrade_shelves()
	feedback_label.text = "Estanterías mejoradas" if result == "OK" else result

func _upgrade_max_customers() -> void:
	var result:String = GameState.try_upgrade_max_visible_customers()
	feedback_label.text = "Capacidad de clientes mejorada" if result == "OK" else result

func _refresh() -> void:
	gold_label.text = "Gold: %d" % GameState.gold
	$VBox/HireButtons/FarmerButton.text = "Ampliar fábrica (%d)" % GameState.get_factory_grid_upgrade_cost()
	$VBox/HireButtons/JuicerButton.text = "Añadir caja (%d)" % GameState.get_checkout_upgrade_cost()
	$VBox/HireButtons/MixerButton.text = "Mejorar estanterías (%d)" % GameState.get_shelf_upgrade_cost()
	$VBox/HireButtons/RestockerButton.text = "Más clientes (%d)" % GameState.get_upgrade_max_visible_customers_cost()
	workers_label.text = "Factory grid:%dx%d | Shop[r:%d c:%d] | Checkouts:%d | Reputación:%d" % [
		GameState.factory_grid_size,
		GameState.factory_grid_size,
		GameState.shop_workers["restocker"],
		GameState.shop_workers["cashier"],
		GameState.checkouts,
		GameState.reputation
	]
