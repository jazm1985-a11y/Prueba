extends Node

signal state_changed
signal ui_message(text: String)

var gold: int = 0
var factory_stock := {"slime": 0, "pulp": 0, "smoothie": 0}
var factory_cap := {"slime": 50, "pulp": 30, "smoothie": 20}
var factory_workers := {"farmer": 0, "juicer": 0, "mixer": 0}
var shop_stock := {"slime": 0, "pulp": 0, "smoothie": 0}
var shop_cap := {"slime": 10, "pulp": 6, "smoothie": 4}
var shop_workers := {"restocker": 0, "cashier": 0}
var checkouts: int = 1
var prices := {"slime": 1, "pulp": 5, "smoothie": 15}

var factory_buildings := {"farmer": 0, "juicer": 0, "mixer": 0}

var _tick_accumulator := 0.0

func _process(delta: float) -> void:
	_tick_accumulator += delta
	while _tick_accumulator >= 1.0:
		_tick_accumulator -= 1.0
		_tick()

func _tick() -> void:
	_auto_farm()
	_auto_juice()
	_auto_mix()
	_auto_restock()
	_auto_cashier()
	emit_signal("state_changed")

func add_worker(worker_name: String) -> void:
	if factory_workers.has(worker_name):
		factory_workers[worker_name] += 1
	elif shop_workers.has(worker_name):
		shop_workers[worker_name] += 1
	emit_signal("state_changed")

func add_building(worker_name: String) -> void:
	if factory_buildings.has(worker_name):
		factory_buildings[worker_name] += 1
	emit_signal("state_changed")

func can_use_station(worker_name: String) -> bool:
	return factory_buildings.get(worker_name, 0) > 0

func manual_add_slime() -> void:
	if not can_use_station("farmer"):
		emit_signal("ui_message", "Bloqueado")
		return
	if factory_stock["slime"] >= factory_cap["slime"]:
		emit_signal("ui_message", "Capacidad llena")
		return
	factory_stock["slime"] += 1
	emit_signal("state_changed")

func manual_slime_to_pulp() -> void:
	if not can_use_station("juicer"):
		emit_signal("ui_message", "Bloqueado")
		return
	if factory_stock["slime"] < 2:
		emit_signal("ui_message", "Falta input")
		return
	if factory_stock["pulp"] >= factory_cap["pulp"]:
		emit_signal("ui_message", "Capacidad llena")
		return
	factory_stock["slime"] -= 2
	factory_stock["pulp"] += 1
	emit_signal("state_changed")

func manual_pulp_to_smoothie() -> void:
	if not can_use_station("mixer"):
		emit_signal("ui_message", "Bloqueado")
		return
	if factory_stock["pulp"] < 2:
		emit_signal("ui_message", "Falta input")
		return
	if factory_stock["smoothie"] >= factory_cap["smoothie"]:
		emit_signal("ui_message", "Capacidad llena")
		return
	factory_stock["pulp"] -= 2
	factory_stock["smoothie"] += 1
	emit_signal("state_changed")

func manual_send_one_each_to_shop() -> void:
	for item in ["slime", "pulp", "smoothie"]:
		if factory_stock[item] <= 0:
			continue
		if shop_stock[item] >= shop_cap[item]:
			continue
		factory_stock[item] -= 1
		shop_stock[item] += 1
	emit_signal("state_changed")

func _auto_farm() -> void:
	if not can_use_station("farmer"):
		return
	var workers := factory_workers["farmer"]
	if workers <= 0:
		return
	var free_space := factory_cap["slime"] - factory_stock["slime"]
	var produced := min(workers, free_space)
	if produced > 0:
		factory_stock["slime"] += produced

func _auto_juice() -> void:
	if not can_use_station("juicer"):
		return
	var workers := factory_workers["juicer"]
	for _i in workers:
		if factory_stock["slime"] < 2:
			break
		if factory_stock["pulp"] >= factory_cap["pulp"]:
			break
		factory_stock["slime"] -= 2
		factory_stock["pulp"] += 1

func _auto_mix() -> void:
	if not can_use_station("mixer"):
		return
	var workers := factory_workers["mixer"]
	for _i in workers:
		if factory_stock["pulp"] < 2:
			break
		if factory_stock["smoothie"] >= factory_cap["smoothie"]:
			break
		factory_stock["pulp"] -= 2
		factory_stock["smoothie"] += 1

func _auto_restock() -> void:
	var workers := shop_workers["restocker"]
	for _i in workers:
		var moved := false
		for item in ["smoothie", "pulp", "slime"]:
			if factory_stock[item] > 0 and shop_stock[item] < shop_cap[item]:
				factory_stock[item] -= 1
				shop_stock[item] += 1
				moved = true
				break
		if not moved:
			break

func _auto_cashier() -> void:
	var sales_limit := min(shop_workers["cashier"], checkouts)
	if sales_limit <= 0:
		return
	for shop_node in get_tree().get_nodes_in_group("shop_system"):
		if shop_node.has_method("process_cashier_sales"):
			shop_node.process_cashier_sales(sales_limit)

func fulfill_order(order: Dictionary) -> bool:
	if not order.has("item") or not order.has("amount"):
		return false
	var item: String = order["item"]
	var amount: int = order["amount"]
	if shop_stock.get(item, 0) < amount:
		return false
	shop_stock[item] -= amount
	gold += prices[item] * amount
	emit_signal("state_changed")
	return true
