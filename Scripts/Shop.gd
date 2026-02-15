extends Control

const CUSTOMER_SPEED:float = 120.0
const WORKER_SPEED:float = 95.0
const CUSTOMER_NAMES := ["Lima", "Nora", "Bruno", "Paz", "Sol", "Iris", "Teo", "Mina", "Leo", "Vera"]
const CUSTOMER_DIALOGUES := [
	"Tengo prisa.",
	"¿Qué recomiendas?",
	"Solo una cosita.",
	"Vengo por lo de siempre.",
	"¿Hay oferta hoy?",
	"Me encanta esta tienda.",
	"Voy tarde.",
	"Necesito algo rápido.",
	"¿Queda stock?",
	"Atiéndeme porfa."
]

@onready var gold_label: Label = $VBox/GoldLabel
@onready var stars_label: Label = $VBox/StarsLabel
@onready var stock_label: Label = $VBox/StockLabel
@onready var order_label: Label = $VBox/OrderLabel
@onready var feedback_label: Label = $VBox/FeedbackLabel
@onready var serve_button: Button = $VBox/ActionButtons/ServeButton
@onready var hire_restocker_button: Button = $VBox/ActionButtons/HireRestockerButton
@onready var hire_cashier_button: Button = $VBox/ActionButtons/HireCashierButton
@onready var upgrade_checkout_button: Button = $VBox/UpgradeButtons/UpgradeCheckoutButton
@onready var upgrade_shelf_button: Button = $VBox/UpgradeButtons/UpgradeShelfButton
@onready var upgrade_max_customers_button: Button = $VBox/UpgradeButtons/UpgradeMaxCustomersButton
@onready var client_slots: VBoxContainer = $VBox/ClientSlots
@onready var world: Node2D = $World
@onready var counter_point: Marker2D = $World/Counter
@onready var cashier_spot_point: Marker2D = $World/CashierSpot
@onready var stock_room_point: Marker2D = $World/StockRoom
@onready var shelf_slime_point: Marker2D = $World/ShelfSlime
@onready var shelf_pulp_point: Marker2D = $World/ShelfPulp
@onready var shelf_smoothie_point: Marker2D = $World/ShelfSmoothie

var customers: Array = []
var restocker_agents: Array = []
var cashier_agents: Array = []
var restock_tasks := {"slime": 0, "pulp": 0, "smoothie": 0, "sal": 0, "unguento": 0}
var last_shop_stock := {"slime": 0, "pulp": 0, "smoothie": 0, "sal": 0, "unguento": 0}
var serve_cooldown: float = 0.0

func _ready() -> void:
	GameState.state_changed.connect(_refresh_ui)
	GameState.tick_processed.connect(_on_tick)
	serve_button.pressed.connect(_on_serve_button_pressed)
	hire_restocker_button.pressed.connect(_on_hire_restocker_button_pressed)
	hire_cashier_button.pressed.connect(_on_hire_cashier_button_pressed)
	upgrade_checkout_button.pressed.connect(_on_upgrade_checkout_button_pressed)
	upgrade_shelf_button.pressed.connect(_on_upgrade_shelf_button_pressed)
	upgrade_max_customers_button.pressed.connect(_on_upgrade_max_customers_button_pressed)
	last_shop_stock = GameState.shop_stock.duplicate()
	_refresh_worker_visuals()
	_fill_queue_to_max()
	_refresh_ui()

func _process(delta: float) -> void:
	serve_cooldown = maxf(0.0, serve_cooldown - delta)
	_update_customer_patience(delta)
	_update_restockers(delta)
	if GameState.cashier_hired and serve_cooldown <= 0.0:
		_try_serve_first_customer()
	_refresh_order_label()
	_refresh_ui()

func _on_hire_restocker_button_pressed() -> void:
	var result := GameState.try_hire_restocker()
	feedback_label.text = "Restocker contratado" if result == "OK" else result

func _on_hire_cashier_button_pressed() -> void:
	var result := GameState.try_hire_cashier()
	feedback_label.text = "Cashier contratado" if result == "OK" else result

func _on_upgrade_checkout_button_pressed() -> void:
	var result: String = GameState.try_upgrade_checkouts()
	feedback_label.text = "Nueva caja registrada" if result == "OK" else result

func _on_upgrade_shelf_button_pressed() -> void:
	var result: String = GameState.try_upgrade_shelves()
	feedback_label.text = "Nueva estantería añadida" if result == "OK" else result

func _on_upgrade_max_customers_button_pressed() -> void:
	var result: String = GameState.try_upgrade_max_visible_customers()
	if result == "OK":
		feedback_label.text = "Más clientes visibles"
		_fill_queue_to_max()
	else:
		feedback_label.text = result

func _fill_queue_to_max() -> void:
	while customers.size() < GameState.max_visible_customers:
		customers.append(_generate_customer())

func _generate_customer() -> Dictionary:
	var pool := GameState.get_customer_pool()
	var pick: Dictionary = pool[randi_range(0, pool.size() - 1)]
	var amount:int = randi_range(pick["min"], pick["max"])
	var avatar_id:int = randi_range(0, CUSTOMER_NAMES.size() - 1)
	return {
		"name": CUSTOMER_NAMES[avatar_id],
		"dialog": CUSTOMER_DIALOGUES[randi_range(0, CUSTOMER_DIALOGUES.size() - 1)],
		"avatar": avatar_id,
		"order": {"item": pick["item"], "amount": amount},
		"patience": GameState.max_customer_wait
	}

func _update_customer_patience(delta: float) -> void:
	var to_remove: Array = []
	for customer in customers:
		customer["patience"] -= delta
		if customer["patience"] <= 0.0:
			to_remove.append(customer)
	for customer in to_remove:
		customers.erase(customer)
		GameState.record_customer_outcome(false)
		feedback_label.text = "Cliente perdido por paciencia"
	_fill_queue_to_max()

func _on_serve_button_pressed() -> void:
	if GameState.cashier_hired:
		feedback_label.text = "Bloqueado"
		return
	if serve_cooldown > 0.0:
		feedback_label.text = "Bloqueado"
		return
	_try_serve_first_customer()

func _try_serve_first_customer() -> void:
	if customers.is_empty():
		feedback_label.text = "Falta input"
		return
	if serve_cooldown > 0.0:
		feedback_label.text = "Bloqueado"
		return
	var customer: Dictionary = customers[0]
	var success := GameState.try_fulfill_order(customer["order"])
	if not success:
		feedback_label.text = "Falta input"
		return
	serve_cooldown = 1.0
	GameState.record_customer_outcome(true)
	feedback_label.text = "Venta atendida"
	customers.pop_front()
	_fill_queue_to_max()

func _on_tick() -> void:
	_refresh_worker_visuals()
	_detect_restock_tick_changes()
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
	node.position = counter_point.position
	world.add_child(node)
	return node

func _create_carry_box(node: Node2D) -> ColorRect:
	var carry := ColorRect.new()
	carry.size = Vector2(10, 10)
	carry.position = Vector2(10, -18)
	carry.color = Color(1.0, 1.0, 1.0)
	carry.visible = false
	node.add_child(carry)
	return carry

func _detect_restock_tick_changes() -> void:
	for item in restock_tasks.keys():
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
	for item in ["unguento", "smoothie", "sal", "pulp", "slime"]:
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
	if item == "sal":
		return Color(0.95, 0.95, 0.95)
	if item == "unguento":
		return Color(0.9, 0.5, 0.1)
	return Color(0.8, 0.2, 0.9)

func _refresh_order_label() -> void:
	if customers.is_empty():
		order_label.text = "Pedido actual: ninguno"
		return
	var c: Dictionary = customers[0]
	order_label.text = "Pedido actual: %s x%d" % [c["order"]["item"], c["order"]["amount"]]

func _refresh_client_slots() -> void:
	for child in client_slots.get_children():
		child.queue_free()
	for i in range(GameState.max_visible_customers):
		var row := HBoxContainer.new()
		if i < customers.size():
			var c: Dictionary = customers[i]
			var info := Label.new()
			info.text = "%d) %s | %s | %s x%d" % [i + 1, c["name"], c["dialog"], c["order"]["item"], c["order"]["amount"]]
			row.add_child(info)
			var bar := ProgressBar.new()
			bar.min_value = 0
			bar.max_value = GameState.max_customer_wait
			bar.value = c["patience"]
			bar.custom_minimum_size = Vector2(180, 20)
			row.add_child(bar)
		else:
			var empty := Label.new()
			empty.text = "%d) [vacío]" % [i + 1]
			row.add_child(empty)
		client_slots.add_child(row)

func _refresh_ui() -> void:
	gold_label.text = "Gold: %d" % GameState.gold
	stars_label.text = "Reputación: %d | Estrellas: %d★ | Cola: %d/%d" % [
		GameState.reputation,
		GameState.get_shop_stars(),
		customers.size(),
		GameState.max_visible_customers
	]
	stock_label.text = "Shop S:%d/%d P:%d/%d Sm:%d/%d Sa:%d/%d Un:%d/%d | CD atender: %.1fs" % [
		GameState.shop_stock["slime"], GameState.shop_cap["slime"],
		GameState.shop_stock["pulp"], GameState.shop_cap["pulp"],
		GameState.shop_stock["smoothie"], GameState.shop_cap["smoothie"],
		GameState.shop_stock["sal"], GameState.shop_cap["sal"],
		GameState.shop_stock["unguento"], GameState.shop_cap["unguento"],
		serve_cooldown
	]
	serve_button.disabled = GameState.cashier_hired or customers.is_empty() or serve_cooldown > 0.0
	upgrade_checkout_button.text = "Añadir caja (%d gold)" % GameState.get_checkout_upgrade_cost()
	upgrade_shelf_button.text = "Añadir estantería (%d gold)" % GameState.get_shelf_upgrade_cost()
	upgrade_max_customers_button.text = "Más clientes (%d gold)" % GameState.get_upgrade_max_visible_customers_cost()
	hire_restocker_button.disabled = GameState.restocker_hired
	hire_cashier_button.disabled = GameState.cashier_hired
	_refresh_client_slots()
