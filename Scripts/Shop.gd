extends Control

signal navigate(screen_name: String)

const CUSTOMER_SCENE := preload("res://Scenes/Customer.tscn")

@onready var world: Control = $VBoxContainer/World
@onready var stock_label: Label = $VBoxContainer/StockLabel
@onready var order_label: Label = $VBoxContainer/OrderLabel
@onready var message_label: Label = $VBoxContainer/MessageLabel

var spawn_point := Vector2(90, 200)
var queue1_point := Vector2(280, 200)
var queue2_point := Vector2(430, 200)
var counter_point := Vector2(640, 200)
var exit_point := Vector2(950, 200)

var customers := []
var spawn_cooldown := 0.0

func _ready() -> void:
	add_to_group("shop_system")
	GameState.state_changed.connect(_refresh)
	GameState.ui_message.connect(_show_message)
	_reset_spawn_time()
	_refresh()

func _exit_tree() -> void:
	remove_from_group("shop_system")
	if GameState.state_changed.is_connected(_refresh):
		GameState.state_changed.disconnect(_refresh)
	if GameState.ui_message.is_connected(_show_message):
		GameState.ui_message.disconnect(_show_message)

func _process(delta: float) -> void:
	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0 and customers.size() < 3:
		_spawn_customer()
		_reset_spawn_time()
	_update_customers(delta)
	_update_order_ui()

func _show_message(text: String) -> void:
	message_label.text = text

func _refresh() -> void:
	stock_label.text = "Shop stock: slime %d/%d | pulp %d/%d | smoothie %d/%d | Gold: %d | Cashiers: %d | Checkouts: %d" % [
		GameState.shop_stock["slime"], GameState.shop_cap["slime"],
		GameState.shop_stock["pulp"], GameState.shop_cap["pulp"],
		GameState.shop_stock["smoothie"], GameState.shop_cap["smoothie"],
		GameState.gold,
		GameState.shop_workers["cashier"],
		GameState.checkouts
	]

func process_cashier_sales(sales_limit: int) -> void:
	var sold := 0
	for customer_data in customers:
		if sold >= sales_limit:
			break
		if customer_data["state"] != "counter_waiting":
			continue
		if GameState.fulfill_order(customer_data["order"]):
			customer_data["state"] = "leaving"
			sold += 1
		else:
			customer_data["wait_time"] += 1.0
			if customer_data["wait_time"] >= 4.0:
				customer_data["state"] = "leaving"
	_refresh()

func _reset_spawn_time() -> void:
	spawn_cooldown = randf_range(5.0, 8.0)

func _spawn_customer() -> void:
	var customer := CUSTOMER_SCENE.instantiate()
	world.add_child(customer)
	customer.position = spawn_point
	var target_state := "queue1"
	if customers.size() == 1:
		target_state = "queue2"
	var order := _generate_order()
	customers.append({
		"node": customer,
		"state": target_state,
		"order": order,
		"wait_time": 0.0,
		"speed": 120.0
	})

func _generate_order() -> Dictionary:
	var roll := randi_range(0, 2)
	if roll == 0:
		return {"item": "slime", "amount": 2}
	if roll == 1:
		return {"item": "pulp", "amount": 1}
	return {"item": "smoothie", "amount": 1}

func _update_customers(delta: float) -> void:
	for customer_data in customers:
		var target := _target_for_state(customer_data["state"])
		var node: Node2D = customer_data["node"]
		node.position = node.position.move_toward(target, customer_data["speed"] * delta)
		if node.position.distance_to(target) < 2.0:
			if customer_data["state"] == "queue1":
				customer_data["state"] = "counter_waiting"
			elif customer_data["state"] == "queue2":
				customer_data["state"] = "queue1"
			elif customer_data["state"] == "leaving":
				customer_data["state"] = "gone"
	var remaining := []
	for customer_data in customers:
		if customer_data["state"] == "gone":
			customer_data["node"].queue_free()
		else:
			remaining.append(customer_data)
	customers = remaining

func _target_for_state(state: String) -> Vector2:
	match state:
		"queue1":
			return queue1_point
		"queue2":
			return queue2_point
		"counter_waiting":
			return counter_point
		"leaving":
			return exit_point
		_:
			return spawn_point

func _update_order_ui() -> void:
	for customer_data in customers:
		if customer_data["state"] == "counter_waiting":
			var order := customer_data["order"]
			order_label.text = "Pedido actual: %d %s" % [order["amount"], order["item"]]
			return
	order_label.text = "Pedido actual: ninguno"

func _on_back_pressed() -> void:
	navigate.emit("castle")
