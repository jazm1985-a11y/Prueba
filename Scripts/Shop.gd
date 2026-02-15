extends Control

const CUSTOMER_SPEED:float = 120.0

@onready var gold_label: Label = $VBox/GoldLabel
@onready var stock_label: Label = $VBox/StockLabel
@onready var order_label: Label = $VBox/OrderLabel
@onready var feedback_label: Label = $VBox/FeedbackLabel
@onready var world: Node2D = $World
@onready var spawn_point: Marker2D = $World/Spawn
@onready var queue1_point: Marker2D = $World/Queue1
@onready var queue2_point: Marker2D = $World/Queue2
@onready var counter_point: Marker2D = $World/Counter
@onready var exit_point: Marker2D = $World/Exit

var customers: Array = []
var spawn_cooldown: float = 2.0

func _ready() -> void:
	GameState.state_changed.connect(_refresh_ui)
	GameState.tick_processed.connect(_on_tick)
	_refresh_ui()

func _process(delta: float) -> void:
	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0:
		_try_spawn_customer()
		spawn_cooldown = randf_range(5.0, 8.0)
	_update_customers(delta)
	_refresh_order_label()

func _try_spawn_customer() -> void:
	if customers.size() >= 3:
		return
	var order := _generate_order()
	var customer := {
		"node": _create_customer_visual(),
		"state": "to_queue1",
		"order": order,
		"wait_counter": 0.0
	}
	customers.append(customer)

func _create_customer_visual() -> Node2D:
	var node := Node2D.new()
	var body := ColorRect.new()
	body.size = Vector2(30, 30)
	body.position = Vector2(-15, -15)
	body.color = Color(0.4, 0.8, 1.0)
	node.add_child(body)
	node.position = spawn_point.position
	world.add_child(node)
	return node

func _generate_order() -> Dictionary:
	var roll:int = randi_range(0, 2)
	if roll == 0:
		return {"item": "slime", "amount": 2}
	if roll == 1:
		return {"item": "pulp", "amount": 1}
	return {"item": "smoothie", "amount": 1}

func _update_customers(delta: float) -> void:
	for customer in customers:
		var target: Vector2 = _get_target_position(customer["state"])
		var node: Node2D = customer["node"]
		node.position = node.position.move_toward(target, CUSTOMER_SPEED * delta)
		if node.position.distance_to(target) < 2.0:
			_advance_customer_state(customer, delta)

func _get_target_position(state: String) -> Vector2:
	match state:
		"to_queue1":
			return queue1_point.position
		"to_queue2":
			return queue2_point.position
		"to_counter", "waiting_order":
			return counter_point.position
		"to_exit":
			return exit_point.position
		_:
			return counter_point.position

func _advance_customer_state(customer: Dictionary, delta: float) -> void:
	match customer["state"]:
		"to_queue1":
			customer["state"] = "to_queue2"
		"to_queue2":
			customer["state"] = "to_counter"
		"to_counter":
			customer["state"] = "waiting_order"
		"waiting_order":
			customer["wait_counter"] += delta
			if customer["wait_counter"] >= 4.0:
				feedback_label.text = "Pedido no atendido, cliente se va"
				customer["state"] = "to_exit"
		"to_exit":
			_remove_customer(customer)

func _on_tick() -> void:
	var sales_left:int = GameState.get_cashier_sales_per_tick()
	if sales_left <= 0:
		return
	for customer in customers:
		if sales_left <= 0:
			break
		if customer["state"] != "waiting_order":
			continue
		var order: Dictionary = customer["order"]
		var success: bool = GameState.try_fulfill_order(order)
		if success:
			feedback_label.text = "Venta: %d %s" % [order["amount"], order["item"]]
			customer["state"] = "to_exit"
			sales_left -= 1
		else:
			feedback_label.text = "Falta input"
	_refresh_ui()

func _remove_customer(customer: Dictionary) -> void:
	var node: Node2D = customer["node"]
	if is_instance_valid(node):
		node.queue_free()
	customers.erase(customer)

func _refresh_order_label() -> void:
	var waiting_orders: Array[String] = []
	for customer in customers:
		if customer["state"] == "waiting_order" or customer["state"] == "to_counter":
			var order: Dictionary = customer["order"]
			waiting_orders.append("%d %s" % [order["amount"], order["item"]])
	if waiting_orders.is_empty():
		order_label.text = "Pedido actual: ninguno"
	else:
		order_label.text = "Pedido actual: " + ", ".join(waiting_orders)

func _refresh_ui() -> void:
	gold_label.text = "Gold: %d" % GameState.gold
	stock_label.text = "Shop Stock S:%d/%d P:%d/%d M:%d/%d | Cashiers:%d Checkouts:%d" % [
		GameState.shop_stock["slime"], GameState.shop_cap["slime"],
		GameState.shop_stock["pulp"], GameState.shop_cap["pulp"],
		GameState.shop_stock["smoothie"], GameState.shop_cap["smoothie"],
		GameState.shop_workers["cashier"], GameState.checkouts
	]
