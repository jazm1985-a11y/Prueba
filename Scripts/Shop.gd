extends Control

const CUSTOMER_SPEED:float = 120.0
const WORKER_SPEED:float = 95.0

@onready var gold_label: Label = $VBox/GoldLabel
@onready var stock_label: Label = $VBox/StockLabel
@onready var order_label: Label = $VBox/OrderLabel
@onready var feedback_label: Label = $VBox/FeedbackLabel
@onready var world: Node2D = $World
@onready var spawn_point: Marker2D = $World/Spawn
@onready var queue1_point: Marker2D = $World/Queue1
@onready var queue2_point: Marker2D = $World/Queue2
@onready var counter_point: Marker2D = $World/Counter
@onready var cashier_spot_point: Marker2D = $World/CashierSpot
@onready var exit_point: Marker2D = $World/Exit
@onready var stock_room_point: Marker2D = $World/StockRoom
@onready var shelf_slime_point: Marker2D = $World/ShelfSlime
@onready var shelf_pulp_point: Marker2D = $World/ShelfPulp
@onready var shelf_smoothie_point: Marker2D = $World/ShelfSmoothie

var customers: Array = []
var restocker_agents: Array = []
var cashier_agents: Array = []
var restock_tasks := {"slime": 0, "pulp": 0, "smoothie": 0}
var last_shop_stock := {"slime": 0, "pulp": 0, "smoothie": 0}
var spawn_cooldown: float = 2.0

func _ready() -> void:
	GameState.state_changed.connect(_refresh_ui)
	GameState.tick_processed.connect(_on_tick)
	last_shop_stock = GameState.shop_stock.duplicate()
	_refresh_worker_visuals()
	_refresh_ui()

func _process(delta: float) -> void:
	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0:
		_try_spawn_customer()
		spawn_cooldown = randf_range(5.0, 8.0)
	_update_customers(delta)
	_update_restockers(delta)
	_refresh_order_label()

func _try_spawn_customer() -> void:
	if customers.size() >= 3:
		return
	var order := _generate_order()
	var customer := {
		"node": _create_actor_visual(Color(0.35, 0.85, 1.0), "C"),
		"state": "to_shelf",
		"order": order,
		"wait_counter": 0.0
	}
	customers.append(customer)

func _create_actor_visual(color: Color, text_value: String) -> Node2D:
	var node := Node2D.new()
	var body := ColorRect.new()
	body.size = Vector2(26, 26)
	body.position = Vector2(-13, -13)
	body.color = color
	node.add_child(body)
	var tag := Label.new()
	tag.text = text_value
	tag.position = Vector2(-8, -32)
	node.add_child(tag)
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
	var remove_list: Array = []
	for customer in customers:
		var target: Vector2 = _get_customer_target_position(customer)
		var node: Node2D = customer["node"]
		node.position = node.position.move_toward(target, CUSTOMER_SPEED * delta)
		if node.position.distance_to(target) < 2.0:
			if _advance_customer_state(customer, delta):
				remove_list.append(customer)
	for customer in remove_list:
		_remove_customer(customer)

func _get_customer_target_position(customer: Dictionary) -> Vector2:
	var state:String = customer["state"]
	match state:
		"to_shelf", "picking":
			return _get_shelf_position(customer["order"]["item"])
		"to_queue1":
			return queue1_point.position
		"to_queue2":
			return queue2_point.position
		"to_counter", "waiting_checkout":
			return counter_point.position
		"to_exit":
			return exit_point.position
		_:
			return counter_point.position

func _advance_customer_state(customer: Dictionary, delta: float) -> bool:
	match customer["state"]:
		"to_shelf":
			customer["state"] = "picking"
			customer["wait_counter"] = 0.0
		"picking":
			var order: Dictionary = customer["order"]
			if GameState.shop_stock[order["item"]] >= order["amount"]:
				feedback_label.text = "Cliente tomó producto de estantería"
				customer["state"] = "to_queue1"
				customer["wait_counter"] = 0.0
			else:
				customer["wait_counter"] += delta
				feedback_label.text = "Falta input"
				if customer["wait_counter"] >= 4.0:
					feedback_label.text = "Cliente no encontró stock y se fue"
					customer["state"] = "to_exit"
		"to_queue1":
			customer["state"] = "to_queue2"
		"to_queue2":
			customer["state"] = "to_counter"
		"to_counter":
			customer["state"] = "waiting_checkout"
			customer["wait_counter"] = 0.0
		"waiting_checkout":
			customer["wait_counter"] += delta
			if customer["wait_counter"] >= 6.0:
				feedback_label.text = "Caja lenta, cliente se va"
				customer["state"] = "to_exit"
		"to_exit":
			return true
	return false

func _on_tick() -> void:
	_refresh_worker_visuals()
	_detect_restock_tick_changes()
	var sales_left:int = GameState.get_cashier_sales_per_tick()
	if sales_left > 0:
		for customer in customers:
			if sales_left <= 0:
				break
			if customer["state"] != "waiting_checkout":
				continue
			var order: Dictionary = customer["order"]
			var success: bool = GameState.try_fulfill_order(order)
			if success:
				feedback_label.text = "Caja cobró: %d %s" % [order["amount"], order["item"]]
				customer["state"] = "to_exit"
				sales_left -= 1
			else:
				feedback_label.text = "Falta input"
	_refresh_ui()

func _refresh_worker_visuals() -> void:
	_sync_worker_agents(cashier_agents, GameState.shop_workers["cashier"], Color(1.0, 0.55, 0.15), "K")
	_sync_worker_agents(restocker_agents, GameState.shop_workers["restocker"], Color(0.75, 1.0, 0.2), "R")

	for i in range(cashier_agents.size()):
		var cashier: Dictionary = cashier_agents[i]
		var node: Node2D = cashier["node"]
		node.position = cashier_spot_point.position + Vector2(float(i) * 26.0, 0.0)

	for i in range(restocker_agents.size()):
		var restocker: Dictionary = restocker_agents[i]
		if restocker["state"] == "idle":
			var base := stock_room_point.position + Vector2(float(i) * 20.0, 16.0)
			var node: Node2D = restocker["node"]
			node.position = base

func _sync_worker_agents(worker_array: Array, target_count: int, color: Color, tag: String) -> void:
	while worker_array.size() < target_count:
		var node := _create_actor_visual(color, tag)
		worker_array.append({
			"node": node,
			"state": "idle",
			"item": "",
			"carry": _create_carry_box(node)
		})
	while worker_array.size() > target_count:
		var worker: Dictionary = worker_array.pop_back()
		var node: Node2D = worker["node"]
		if is_instance_valid(node):
			node.queue_free()

func _create_carry_box(node: Node2D) -> ColorRect:
	var carry := ColorRect.new()
	carry.size = Vector2(10, 10)
	carry.position = Vector2(10, -18)
	carry.color = Color(1.0, 1.0, 1.0)
	carry.visible = false
	node.add_child(carry)
	return carry

func _detect_restock_tick_changes() -> void:
	for item in ["slime", "pulp", "smoothie"]:
		var delta:int = GameState.shop_stock[item] - last_shop_stock[item]
		if delta > 0:
			restock_tasks[item] += delta
	last_shop_stock = GameState.shop_stock.duplicate()

func _update_restockers(delta: float) -> void:
	for restocker in restocker_agents:
		_update_single_restocker(restocker, delta)

func _update_single_restocker(restocker: Dictionary, delta: float) -> void:
	var node: Node2D = restocker["node"]
	var carry: ColorRect = restocker["carry"]
	if restocker["state"] == "idle":
		var item := _take_restock_task()
		if item != "":
			restocker["item"] = item
			restocker["state"] = "to_shelf"
			carry.visible = true
			carry.color = _item_color(item)
		else:
			return
	var target: Vector2 = stock_room_point.position
	if restocker["state"] == "to_shelf":
		target = _get_shelf_position(restocker["item"])
	elif restocker["state"] == "returning":
		target = stock_room_point.position
	node.position = node.position.move_toward(target, WORKER_SPEED * delta)
	if node.position.distance_to(target) < 2.0:
		if restocker["state"] == "to_shelf":
			restocker["state"] = "returning"
			carry.visible = false
		elif restocker["state"] == "returning":
			restocker["state"] = "idle"
			restocker["item"] = ""

func _take_restock_task() -> String:
	for item in ["smoothie", "pulp", "slime"]:
		if restock_tasks[item] > 0:
			restock_tasks[item] -= 1
			return item
	return ""

func _get_shelf_position(item: String) -> Vector2:
	if item == "slime":
		return shelf_slime_point.position
	if item == "pulp":
		return shelf_pulp_point.position
	return shelf_smoothie_point.position

func _item_color(item: String) -> Color:
	if item == "slime":
		return Color(0.1, 0.9, 0.3)
	if item == "pulp":
		return Color(1.0, 0.8, 0.2)
	return Color(0.8, 0.2, 0.9)

func _remove_customer(customer: Dictionary) -> void:
	var node: Node2D = customer["node"]
	if is_instance_valid(node):
		node.queue_free()
	customers.erase(customer)

func _refresh_order_label() -> void:
	var waiting_orders: Array[String] = []
	for customer in customers:
		if customer["state"] == "waiting_checkout" or customer["state"] == "to_counter":
			var order: Dictionary = customer["order"]
			waiting_orders.append("%d %s" % [order["amount"], order["item"]])
	if waiting_orders.is_empty():
		order_label.text = "Pedido actual: ninguno"
	else:
		order_label.text = "Pedido actual: " + ", ".join(waiting_orders)

func _refresh_ui() -> void:
	gold_label.text = "Gold: %d" % GameState.gold
	stock_label.text = "Shop Stock S:%d/%d P:%d/%d M:%d/%d | Restockers:%d Cashiers:%d Checkouts:%d" % [
		GameState.shop_stock["slime"], GameState.shop_cap["slime"],
		GameState.shop_stock["pulp"], GameState.shop_cap["pulp"],
		GameState.shop_stock["smoothie"], GameState.shop_cap["smoothie"],
		GameState.shop_workers["restocker"],
		GameState.shop_workers["cashier"],
		GameState.checkouts
	]
