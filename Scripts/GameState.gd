extends Node

signal state_changed
signal tick_processed

var gold:int = 100
var factory_stock := {"slime": 0, "pulp": 0, "smoothie": 0, "agua": 0, "sal": 0, "unguento": 0}
var factory_cap := {"slime": 80, "pulp": 40, "smoothie": 25, "agua": 60, "sal": 25, "unguento": 15}
var factory_workers := {"farmer": 0, "juicer": 0, "mixer": 0}
var shop_stock := {"slime": 0, "pulp": 0, "smoothie": 0, "sal": 0, "unguento": 0}
var shop_cap := {"slime": 10, "pulp": 6, "smoothie": 4, "sal": 4, "unguento": 2}
var shop_workers := {"restocker": 0, "cashier": 0}
var checkouts:int = 1
var prices := {"slime": 1, "pulp": 5, "smoothie": 15, "sal": 12, "unguento": 45}

var reputation:int = 0
var max_visible_customers:int = 3
var max_customer_wait: float = 20.0
var restocker_hired: bool = false
var cashier_hired: bool = false

var station_progress := {"slime": 0.0, "pulp": 0.0, "smoothie": 0.0, "agua": 0.0, "sal": 0.0, "unguento": 0.0}
var station_ready := {"slime": 0, "pulp": 0, "smoothie": 0, "agua": 0, "sal": 0, "unguento": 0}
var station_time := {"slime": 2.0, "pulp": 3.0, "smoothie": 4.0, "agua": 3.0, "sal": 6.0, "unguento": 10.0}

var factory_grid_size:int = 3
var factory_layout := {}
var selected_building:String = ""

var factory_worker_pool_total:int = 0
var factory_worker_pool_unassigned:int = 0
var factory_cell_types := {}
var factory_cell_workers := {}
var factory_cell_progress := {}

var _tick_accumulator:float = 0.0
var _save_accumulator:float = 0.0
const SAVE_PATH := "user://save_game.json"

func _ready() -> void:
	load_game()

func _process(delta: float) -> void:
	_tick_accumulator += delta
	_save_accumulator += delta
	_update_factory_cells(delta)
	while _tick_accumulator >= 1.0:
		_tick_accumulator -= 1.0
		run_tick()
	if _save_accumulator >= 15.0:
		_save_accumulator = 0.0
		save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func run_tick() -> void:
	_run_farmers()
	_run_juicers()
	_run_mixers()
	_run_restockers()
	emit_signal("tick_processed")
	emit_signal("state_changed")

# --- FACTORY GRID 2.0 ---

func get_factory_worker_hire_cost() -> int:
	return int(round(10.0 * pow(2.0, factory_worker_pool_total)))

func try_hire_factory_worker() -> String:
	var cost:int = get_factory_worker_hire_cost()
	if gold < cost:
		return "Falta gold"
	gold -= cost
	factory_worker_pool_total += 1
	factory_worker_pool_unassigned += 1
	emit_signal("state_changed")
	return "OK"

func get_factory_valid_station_types() -> Array[String]:
	return ["slime", "pulp", "smoothie", "agua", "sal", "unguento", "storage", "empty"]

func set_factory_cell_type(cell_id: String, station_type: String) -> String:
	if not station_type in get_factory_valid_station_types():
		return "Bloqueado"
	if station_type == "empty":
		factory_worker_pool_unassigned += int(factory_cell_workers.get(cell_id, 0))
		factory_cell_workers.erase(cell_id)
		factory_cell_types.erase(cell_id)
		factory_cell_progress.erase(cell_id)
		emit_signal("state_changed")
		return "OK"
	factory_cell_types[cell_id] = station_type
	if not factory_cell_workers.has(cell_id):
		factory_cell_workers[cell_id] = 0
	if not factory_cell_progress.has(cell_id):
		factory_cell_progress[cell_id] = 0.0
	emit_signal("state_changed")
	return "OK"

func assign_worker_to_cell(cell_id: String) -> String:
	if not factory_cell_types.has(cell_id):
		return "Bloqueado"
	if factory_cell_types[cell_id] == "storage":
		return "Bloqueado"
	if factory_worker_pool_unassigned <= 0:
		return "Falta input"
	factory_worker_pool_unassigned -= 1
	factory_cell_workers[cell_id] = int(factory_cell_workers.get(cell_id, 0)) + 1
	emit_signal("state_changed")
	return "OK"

func unassign_worker_from_cell(cell_id: String) -> String:
	if int(factory_cell_workers.get(cell_id, 0)) <= 0:
		return "Falta input"
	factory_cell_workers[cell_id] -= 1
	factory_worker_pool_unassigned += 1
	emit_signal("state_changed")
	return "OK"

func get_factory_cell_label(cell_id: String) -> String:
	if not factory_cell_types.has(cell_id):
		return "Vacío"
	var t:String = factory_cell_types[cell_id]
	var w:int = int(factory_cell_workers.get(cell_id, 0))
	if t == "storage":
		return "Storage"
	return "%s\nW:%d" % [t.capitalize(), w]

func _update_factory_cells(delta: float) -> void:
	for cell_id in factory_cell_types.keys():
		var station_type:String = factory_cell_types[cell_id]
		if station_type == "storage":
			continue
		var workers:int = int(factory_cell_workers.get(cell_id, 0))
		if workers <= 0:
			continue
		var efficiency := _get_factory_efficiency_for_cell(cell_id, station_type)
		if efficiency <= 0.0:
			continue
		var progress_gain: float = (delta * float(workers) * efficiency) / station_time[station_type]
		factory_cell_progress[cell_id] = float(factory_cell_progress.get(cell_id, 0.0)) + progress_gain
		while factory_cell_progress[cell_id] >= 1.0:
			var produced: bool = _try_produce_from_cell(station_type)
			if not produced:
				factory_cell_progress[cell_id] = 0.99
				break
			factory_cell_progress[cell_id] -= 1.0
	emit_signal("state_changed")

func _get_factory_efficiency_for_cell(cell_id: String, station_type: String) -> float:
	var target_type:String = _get_station_primary_target(station_type)
	var dist:int = _get_distance_to_closest_station(cell_id, target_type)
	return 1.0 / max(1.0, 1.0 + float(dist) * 0.25)

func _get_station_primary_target(station_type: String) -> String:
	if station_type == "slime":
		return "pulp"
	if station_type == "pulp":
		return "smoothie"
	if station_type == "agua":
		return "sal"
	if station_type == "sal":
		return "unguento"
	if station_type == "smoothie" or station_type == "unguento":
		return "storage"
	return "storage"

func _get_distance_to_closest_station(cell_id: String, target_type: String) -> int:
	var origin: Vector2i = _cell_id_to_vec2i(cell_id)
	var best:int = 999999
	for other_id in factory_cell_types.keys():
		if String(factory_cell_types[other_id]) != target_type:
			continue
		var v: Vector2i = _cell_id_to_vec2i(other_id)
		var d:int = absi(v.x - origin.x) + absi(v.y - origin.y)
		best = min(best, d)
	if best == 999999:
		return 3
	return best

func _cell_id_to_vec2i(cell_id: String) -> Vector2i:
	var parts := cell_id.split("_")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

func _try_produce_from_cell(station_type: String) -> bool:
	if factory_stock[station_type] >= factory_cap[station_type]:
		return false
	if station_type == "pulp":
		if factory_stock["slime"] < 2:
			return false
		factory_stock["slime"] -= 2
	elif station_type == "smoothie":
		if factory_stock["pulp"] < 2:
			return false
		factory_stock["pulp"] -= 2
	elif station_type == "sal":
		if factory_stock["agua"] < 2:
			return false
		factory_stock["agua"] -= 2
	elif station_type == "unguento":
		if factory_stock["pulp"] < 1 or factory_stock["sal"] < 1:
			return false
		factory_stock["pulp"] -= 1
		factory_stock["sal"] -= 1
	factory_stock[station_type] += 1
	return true

# --- LEGACY/AUX PRODUCTION METHODS ---

func collect_station(station: String) -> String:
	if station_ready.get(station, 0) <= 0:
		return "Falta input"
	if factory_stock[station] >= factory_cap[station]:
		return "Capacidad llena"
	if station == "pulp":
		if factory_stock["slime"] < 2:
			return "Falta input"
		factory_stock["slime"] -= 2
	elif station == "smoothie":
		if factory_stock["pulp"] < 2:
			return "Falta input"
		factory_stock["pulp"] -= 2
	elif station == "sal":
		if factory_stock["agua"] < 2:
			return "Falta input"
		factory_stock["agua"] -= 2
	elif station == "unguento":
		if factory_stock["pulp"] < 1 or factory_stock["sal"] < 1:
			return "Falta input"
		factory_stock["pulp"] -= 1
		factory_stock["sal"] -= 1
	station_ready[station] -= 1
	factory_stock[station] += 1
	emit_signal("state_changed")
	return "OK"

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
	if shop_workers["restocker"] <= 0:
		return
	var moves_left:int = shop_workers["restocker"]
	var moved := true
	while moved and moves_left > 0:
		moved = false
		for item in ["unguento", "smoothie", "sal", "pulp", "slime"]:
			if factory_stock[item] > 0 and shop_stock[item] < shop_cap[item]:
				factory_stock[item] -= 1
				shop_stock[item] += 1
				moves_left -= 1
				moved = true
				break

# --- HIRING / SHOP ---

func can_hire_worker(worker_type: String) -> bool:
	return gold >= 10 and (_has_worker_key(worker_type))

func hire_worker(worker_type: String) -> String:
	if gold < 10:
		return "Falta gold"
	if worker_type in factory_workers:
		factory_workers[worker_type] += 1
	elif worker_type == "restocker":
		return try_hire_restocker()
	elif worker_type == "cashier":
		return try_hire_cashier()
	else:
		return "Worker inválido"
	gold -= 10
	emit_signal("state_changed")
	return "OK"

func _has_worker_key(worker_type: String) -> bool:
	return worker_type in factory_workers or worker_type in shop_workers

func try_hire_restocker() -> String:
	var cost:int = get_restocker_hire_cost()
	if gold < cost:
		return "Falta gold"
	gold -= cost
	shop_workers["restocker"] += 1
	restocker_hired = shop_workers["restocker"] > 0
	emit_signal("state_changed")
	return "OK"

func try_hire_cashier() -> String:
	var cost:int = get_cashier_hire_cost()
	if gold < cost:
		return "Falta gold"
	gold -= cost
	shop_workers["cashier"] += 1
	cashier_hired = shop_workers["cashier"] > 0
	emit_signal("state_changed")
	return "OK"

func get_restocker_hire_cost() -> int:
	return int(round(10.0 * pow(1.6, shop_workers["restocker"])))

func get_cashier_hire_cost() -> int:
	return int(round(10.0 * pow(1.7, shop_workers["cashier"])))

func try_upgrade_checkouts() -> String:
	var cost:int = 30 + (checkouts - 1) * 20
	if gold < cost:
		return "Falta gold"
	gold -= cost
	checkouts += 1
	emit_signal("state_changed")
	return "OK"

func try_upgrade_shelves() -> String:
	var cost:int = 25 + (get_shelf_upgrade_step()) * 20
	if gold < cost:
		return "Falta gold"
	gold -= cost
	shop_cap["slime"] += 2
	shop_cap["pulp"] += 2
	shop_cap["smoothie"] += 1
	shop_cap["sal"] += 1
	shop_cap["unguento"] += 1
	emit_signal("state_changed")
	return "OK"

func get_checkout_upgrade_cost() -> int:
	return 30 + (checkouts - 1) * 20

func get_shelf_upgrade_step() -> int:
	return max(shop_cap["slime"] - 10, 0) / 2

func get_shelf_upgrade_cost() -> int:
	return 25 + (get_shelf_upgrade_step()) * 20

func try_upgrade_max_visible_customers() -> String:
	if max_visible_customers >= 8:
		return "Capacidad llena"
	var step := max_visible_customers - 3
	var cost: int = int(round(120.0 * pow(1.65, step)))
	if gold < cost:
		return "Falta gold"
	gold -= cost
	max_visible_customers += 1
	emit_signal("state_changed")
	return "OK"

func get_upgrade_max_visible_customers_cost() -> int:
	var step := max_visible_customers - 3
	return int(round(120.0 * pow(1.65, step)))

func record_customer_outcome(served: bool) -> void:
	if served:
		reputation = min(100, reputation + 2)
	else:
		reputation = max(0, reputation - 5)
	emit_signal("state_changed")

func get_shop_stars() -> int:
	return clampi(int(floor(reputation / 20.0)) + 1, 1, 5)

func get_customer_pool() -> Array:
	var pool := [{"item": "slime", "min": 1, "max": 3}]
	if reputation >= 20:
		pool.append({"item": "pulp", "min": 1, "max": 2})
	if reputation >= 40:
		pool.append({"item": "smoothie", "min": 1, "max": 2})
	if reputation >= 60:
		pool.append({"item": "sal", "min": 1, "max": 2})
	if reputation >= 80:
		pool.append({"item": "unguento", "min": 1, "max": 1})
	return pool

# --- TRANSFERS / SALES ---

func try_transfer_to_shop(item: String) -> String:
	if item == "agua":
		return "Bloqueado"
	if not shop_stock.has(item):
		return "Bloqueado"
	if factory_stock[item] <= 0:
		return "Falta input"
	if shop_stock[item] >= shop_cap[item]:
		return "Capacidad llena"
	factory_stock[item] -= 1
	shop_stock[item] += 1
	emit_signal("state_changed")
	return "OK"

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
	if not shop_stock.has(item):
		return false
	if shop_stock[item] < amount:
		return false
	shop_stock[item] -= amount
	gold += prices[item] * amount
	emit_signal("state_changed")
	return true

func get_cashier_sales_per_tick() -> int:
	if shop_workers["cashier"] <= 0:
		return 0
	return min(shop_workers["cashier"], checkouts)

# --- SAVE / LOAD ---

func save_game() -> void:
	var data := {
		"gold": gold,
		"reputation": reputation,
		"factory_stock": factory_stock,
		"shop_stock": shop_stock,
		"max_visible_customers": max_visible_customers,
		"shop_workers": shop_workers,
		"checkouts": checkouts,
		"factory_worker_pool_total": factory_worker_pool_total,
		"factory_worker_pool_unassigned": factory_worker_pool_unassigned,
		"factory_cell_types": factory_cell_types,
		"factory_cell_workers": factory_cell_workers,
		"factory_cell_progress": factory_cell_progress,
		"timestamp": Time.get_unix_time_from_system()
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	gold = int(parsed.get("gold", gold))
	reputation = int(parsed.get("reputation", reputation))
	var f_stock: Dictionary = parsed.get("factory_stock", {})
	for key in factory_stock.keys():
		factory_stock[key] = int(f_stock.get(key, factory_stock[key]))
	var s_stock: Dictionary = parsed.get("shop_stock", {})
	for key in shop_stock.keys():
		shop_stock[key] = int(s_stock.get(key, shop_stock[key]))
	max_visible_customers = int(parsed.get("max_visible_customers", max_visible_customers))
	var loaded_workers: Dictionary = parsed.get("shop_workers", {})
	shop_workers["restocker"] = int(loaded_workers.get("restocker", shop_workers["restocker"]))
	shop_workers["cashier"] = int(loaded_workers.get("cashier", shop_workers["cashier"]))
	restocker_hired = shop_workers["restocker"] > 0
	cashier_hired = shop_workers["cashier"] > 0
	checkouts = int(parsed.get("checkouts", checkouts))

	factory_worker_pool_total = int(parsed.get("factory_worker_pool_total", factory_worker_pool_total))
	factory_worker_pool_unassigned = int(parsed.get("factory_worker_pool_unassigned", factory_worker_pool_unassigned))
	factory_cell_types = parsed.get("factory_cell_types", factory_cell_types)
	factory_cell_workers = parsed.get("factory_cell_workers", factory_cell_workers)
	factory_cell_progress = parsed.get("factory_cell_progress", factory_cell_progress)

	_apply_offline_progress(int(parsed.get("timestamp", Time.get_unix_time_from_system())))
	emit_signal("state_changed")

func _apply_offline_progress(saved_timestamp: int) -> void:
	var now := int(Time.get_unix_time_from_system())
	var offline_seconds := clampi(now - saved_timestamp, 0, 7200)
	if offline_seconds <= 0:
		return
	var slime_gain := offline_seconds / int(station_time["slime"])
	var agua_gain := offline_seconds / int(station_time["agua"])
	factory_stock["slime"] = min(factory_cap["slime"], factory_stock["slime"] + slime_gain)
	factory_stock["agua"] = min(factory_cap["agua"], factory_stock["agua"] + agua_gain)
	var rep_loss := int(float(offline_seconds) / 3600.0 * 5.0)
	reputation = max(0, reputation - rep_loss)
