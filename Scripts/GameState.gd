extends Node

signal state_changed
signal tick_processed

var gold:int = 100
var factory_stock := {"slime": 0, "pulp": 0, "smoothie": 0}
var factory_cap := {"slime": 50, "pulp": 30, "smoothie": 20}
var factory_workers := {"farmer": 0, "juicer": 0, "mixer": 0}
var shop_stock := {"slime": 0, "pulp": 0, "smoothie": 0}
var shop_cap := {"slime": 10, "pulp": 6, "smoothie": 4}
var shop_workers := {"restocker": 0, "cashier": 0}
var checkouts:int = 1
var prices := {"slime": 1, "pulp": 5, "smoothie": 15}

var factory_grid_size:int = 3
var factory_layout := {}
var selected_building:String = ""

var _tick_accumulator:float = 0.0

func _process(delta: float) -> void:
	_tick_accumulator += delta
	while _tick_accumulator >= 1.0:
		_tick_accumulator -= 1.0
		run_tick()

func run_tick() -> void:
	_run_farmers()
	_run_juicers()
	_run_mixers()
	_run_restockers()
	emit_signal("tick_processed")
	emit_signal("state_changed")

func _run_farmers() -> void:
	var workers:int = factory_workers["farmer"]
	if workers <= 0:
		return
	var space:int = factory_cap["slime"] - factory_stock["slime"]
	if space <= 0:
		return
	factory_stock["slime"] += min(workers, space)

func _run_juicers() -> void:
	var workers:int = factory_workers["juicer"]
	if workers <= 0:
		return
	var space:int = factory_cap["pulp"] - factory_stock["pulp"]
	if space <= 0:
		return
	var possible_from_input:int = factory_stock["slime"] / 2
	var conversions:int = min(workers, min(space, possible_from_input))
	if conversions <= 0:
		return
	factory_stock["slime"] -= conversions * 2
	factory_stock["pulp"] += conversions

func _run_mixers() -> void:
	var workers:int = factory_workers["mixer"]
	if workers <= 0:
		return
	var space:int = factory_cap["smoothie"] - factory_stock["smoothie"]
	if space <= 0:
		return
	var possible_from_input:int = factory_stock["pulp"] / 2
	var conversions:int = min(workers, min(space, possible_from_input))
	if conversions <= 0:
		return
	factory_stock["pulp"] -= conversions * 2
	factory_stock["smoothie"] += conversions

func _run_restockers() -> void:
	var moves_left:int = shop_workers["restocker"]
	if moves_left <= 0:
		return
	var priority := ["smoothie", "pulp", "slime"]
	while moves_left > 0:
		var moved:bool = false
		for item in priority:
			if factory_stock[item] > 0 and shop_stock[item] < shop_cap[item]:
				factory_stock[item] -= 1
				shop_stock[item] += 1
				moves_left -= 1
				moved = true
				break
		if not moved:
			break

func can_hire_worker(worker_type: String) -> bool:
	return gold >= 10 and (_has_worker_key(worker_type))

func hire_worker(worker_type: String) -> String:
	if gold < 10:
		return "Falta gold"
	if worker_type in factory_workers:
		factory_workers[worker_type] += 1
	elif worker_type in shop_workers:
		shop_workers[worker_type] += 1
	else:
		return "Worker inválido"
	gold -= 10
	emit_signal("state_changed")
	return "OK"

func _has_worker_key(worker_type: String) -> bool:
	return worker_type in factory_workers or worker_type in shop_workers

func try_add_slime_manual() -> String:
	if not has_building("FarmerStation"):
		return "Bloqueado"
	if factory_stock["slime"] >= factory_cap["slime"]:
		return "Capacidad llena"
	factory_stock["slime"] += 1
	emit_signal("state_changed")
	return "OK"

func try_convert_slime_to_pulp_manual() -> String:
	if not has_building("JuicerStation"):
		return "Bloqueado"
	if factory_stock["slime"] < 2:
		return "Falta input"
	if factory_stock["pulp"] >= factory_cap["pulp"]:
		return "Capacidad llena"
	factory_stock["slime"] -= 2
	factory_stock["pulp"] += 1
	emit_signal("state_changed")
	return "OK"

func try_convert_pulp_to_smoothie_manual() -> String:
	if not has_building("MixerStation"):
		return "Bloqueado"
	if factory_stock["pulp"] < 2:
		return "Falta input"
	if factory_stock["smoothie"] >= factory_cap["smoothie"]:
		return "Capacidad llena"
	factory_stock["pulp"] -= 2
	factory_stock["smoothie"] += 1
	emit_signal("state_changed")
	return "OK"

func try_send_bundle_to_shop() -> String:
	for item in ["slime", "pulp", "smoothie"]:
		if factory_stock[item] < 1:
			return "Falta input"
	for item in ["slime", "pulp", "smoothie"]:
		if shop_stock[item] >= shop_cap[item]:
			return "Capacidad llena"
	for item in ["slime", "pulp", "smoothie"]:
		factory_stock[item] -= 1
		shop_stock[item] += 1
	emit_signal("state_changed")
	return "OK"

func has_building(building_name: String) -> bool:
	for key in factory_layout.keys():
		if factory_layout[key] == building_name:
			return true
	return false

func place_building(cell_id: String, building_name: String) -> String:
	if selected_building == "":
		return "Bloqueado"
	if building_name != selected_building:
		return "Bloqueado"
	if factory_layout.has(cell_id):
		return "Capacidad llena"
	factory_layout[cell_id] = building_name
	emit_signal("state_changed")
	return "OK"

func expand_factory_grid() -> void:
	factory_grid_size += 1
	emit_signal("state_changed")

func try_fulfill_order(order: Dictionary) -> bool:
	var item:String = order.get("item", "")
	var amount:int = order.get("amount", 0)
	if item == "" or amount <= 0:
		return false
	if shop_stock[item] < amount:
		return false
	shop_stock[item] -= amount
	gold += prices[item] * amount
	emit_signal("state_changed")
	return true

func get_cashier_sales_per_tick() -> int:
	return min(shop_workers["cashier"], checkouts)
