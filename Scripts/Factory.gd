extends Control

const CELL_SIZE := 72.0
const WORKER_SPEED := 60.0

@onready var stock_label: Label = $VBox/StockLabel
@onready var pool_label: Label = $VBox/PoolLabel
@onready var selected_cell_label: Label = $VBox/SelectedCellLabel
@onready var flow_label: Label = $VBox/MainSplit/WorldPanel/FlowLabel
@onready var status_label: Label = $VBox/StatusLabel
@onready var grid: GridContainer = $VBox/MainSplit/GridPanel/Grid
@onready var world_grid: Node2D = $VBox/MainSplit/WorldPanel/World/WorldGrid
@onready var world_workers: Node2D = $VBox/MainSplit/WorldPanel/World/WorldWorkers

var selected_station_type:String = "slime"
var selected_cell_id:String = ""
var worker_agents: Array = []
var cell_markers := {}
var worker_signature: String = ""

func _ready() -> void:
	$VBox/SelectorButtons/SelectSlimeButton.pressed.connect(func() -> void: _select_station_type("slime"))
	$VBox/SelectorButtons/SelectPulpButton.pressed.connect(func() -> void: _select_station_type("pulp"))
	$VBox/SelectorButtons/SelectSmoothieButton.pressed.connect(func() -> void: _select_station_type("smoothie"))
	$VBox/SelectorButtons/SelectAguaButton.pressed.connect(func() -> void: _select_station_type("agua"))
	$VBox/SelectorButtons/SelectSalButton.pressed.connect(func() -> void: _select_station_type("sal"))
	$VBox/SelectorButtons/SelectUnguentoButton.pressed.connect(func() -> void: _select_station_type("unguento"))
	$VBox/SelectorButtons/SelectStorageButton.pressed.connect(func() -> void: _select_station_type("storage"))
	$VBox/SelectorButtons/SelectEmptyButton.pressed.connect(func() -> void: _select_station_type("empty"))

	$VBox/ApplyBuildButton.pressed.connect(_apply_station_to_selected)
	$VBox/WorkerButtons/HireFactoryWorkerButton.pressed.connect(_buy_worker)
	$VBox/WorkerButtons/AssignWorkerButton.pressed.connect(_assign_worker_to_selected)
	$VBox/WorkerButtons/UnassignWorkerButton.pressed.connect(_unassign_worker_from_selected)

	$VBox/TransferButtons/TransferSlimeButton.pressed.connect(func() -> void: _transfer_item("slime"))
	$VBox/TransferButtons/TransferPulpButton.pressed.connect(func() -> void: _transfer_item("pulp"))
	$VBox/TransferButtons/TransferSmoothieButton.pressed.connect(func() -> void: _transfer_item("smoothie"))
	$VBox/TransferButtons/TransferSalButton.pressed.connect(func() -> void: _transfer_item("sal"))
	$VBox/TransferButtons/TransferUnguentoButton.pressed.connect(func() -> void: _transfer_item("unguento"))

	GameState.state_changed.connect(_refresh)
	_build_world_grid()
	_rebuild_grid()
	_refresh()

func _process(delta: float) -> void:
	_update_worker_visuals(delta)

func _select_station_type(station_type: String) -> void:
	selected_station_type = station_type
	status_label.text = "Tipo seleccionado: " + station_type

func _apply_station_to_selected() -> void:
	if selected_cell_id == "":
		status_label.text = "Bloqueado"
		return
	var result := GameState.set_factory_cell_type(selected_cell_id, selected_station_type)
	_show_result(result)
	_rebuild_grid()
	_sync_worker_agents()

func _buy_worker() -> void:
	_show_result(GameState.try_hire_factory_worker())

func _assign_worker_to_selected() -> void:
	if selected_cell_id == "":
		status_label.text = "Bloqueado"
		return
	_show_result(GameState.assign_worker_to_cell(selected_cell_id))
	_sync_worker_agents()

func _unassign_worker_from_selected() -> void:
	if selected_cell_id == "":
		status_label.text = "Bloqueado"
		return
	_show_result(GameState.unassign_worker_from_cell(selected_cell_id))
	_sync_worker_agents()

func _transfer_item(item: String) -> void:
	_show_result(GameState.try_transfer_to_shop(item))

func _show_result(result: String) -> void:
	if result == "OK":
		status_label.text = "Acción completada"
	else:
		status_label.text = result

func _rebuild_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	grid.columns = GameState.factory_grid_size
	for y in range(GameState.factory_grid_size):
		for x in range(GameState.factory_grid_size):
			var id := "%d_%d" % [x, y]
			var b := Button.new()
			b.custom_minimum_size = Vector2(92, 92)
			b.text = _get_grid_cell_text(id)
			if id == selected_cell_id:
				b.modulate = Color(1.0, 1.0, 0.7)
			b.pressed.connect(_on_grid_cell_pressed.bind(id))
			grid.add_child(b)

func _get_grid_cell_text(cell_id: String) -> String:
	var label := GameState.get_factory_cell_label(cell_id)
	var progress: float = float(GameState.factory_cell_progress.get(cell_id, 0.0))
	if progress > 0.0 and progress < 1.0:
		label += "\n%3d%%" % int(progress * 100.0)
	return label

func _on_grid_cell_pressed(cell_id: String) -> void:
	selected_cell_id = cell_id
	selected_cell_label.text = "Celda seleccionada: " + cell_id + " | Tipo a construir: " + selected_station_type
	_rebuild_grid()

func _build_world_grid() -> void:
	for child in world_grid.get_children():
		child.queue_free()
	cell_markers.clear()
	for y in range(GameState.factory_grid_size):
		for x in range(GameState.factory_grid_size):
			var id := "%d_%d" % [x, y]
			var tile := ColorRect.new()
			tile.size = Vector2(CELL_SIZE - 6.0, CELL_SIZE - 6.0)
			tile.position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			tile.color = Color(0.2, 0.2, 0.24)
			world_grid.add_child(tile)
			cell_markers[id] = tile

func _sync_world_grid_colors() -> void:
	for id in cell_markers.keys():
		var tile: ColorRect = cell_markers[id]
		var station_type: String = String(GameState.factory_cell_types.get(id, ""))
		tile.color = _station_color(station_type)

func _station_color(station_type: String) -> Color:
	if station_type == "slime":
		return Color(0.2, 0.75, 0.3)
	if station_type == "pulp":
		return Color(1.0, 0.7, 0.2)
	if station_type == "smoothie":
		return Color(0.8, 0.2, 0.8)
	if station_type == "agua":
		return Color(0.2, 0.6, 1.0)
	if station_type == "sal":
		return Color(0.9, 0.9, 0.9)
	if station_type == "unguento":
		return Color(0.85, 0.45, 0.15)
	if station_type == "storage":
		return Color(0.35, 0.35, 0.45)
	return Color(0.2, 0.2, 0.24)

func _sync_worker_agents() -> void:
	var parts: Array[String] = []
	for cell_id in GameState.factory_cell_workers.keys():
		parts.append(cell_id + ":" + str(GameState.factory_cell_workers[cell_id]))
	parts.sort()
	var signature := "|".join(parts)
	if signature == worker_signature:
		return
	worker_signature = signature
	for child in world_workers.get_children():
		child.queue_free()
	worker_agents.clear()
	for cell_id in GameState.factory_cell_workers.keys():
		var count:int = int(GameState.factory_cell_workers[cell_id])
		for i in range(count):
			var node := _create_worker_node()
			node.position = _cell_center(cell_id) + Vector2(float(i % 2) * 8.0, float(i / 2) * 8.0)
			world_workers.add_child(node)
			worker_agents.append({
				"node": node,
				"home": cell_id,
				"state": "idle",
				"target": cell_id,
				"item": ""
			})

func _create_worker_node() -> Node2D:
	var node := Node2D.new()
	var body := ColorRect.new()
	body.size = Vector2(12, 12)
	body.position = Vector2(-6, -6)
	body.color = Color(1.0, 0.95, 0.4)
	node.add_child(body)
	var carry := ColorRect.new()
	carry.name = "Carry"
	carry.size = Vector2(8, 8)
	carry.position = Vector2(4, -12)
	carry.color = Color(1, 1, 1)
	carry.visible = false
	node.add_child(carry)
	return node

func _update_worker_visuals(delta: float) -> void:
	for agent in worker_agents:
		_update_single_worker(agent, delta)
	_update_flow_label()

func _update_single_worker(agent: Dictionary, delta: float) -> void:
	var node: Node2D = agent["node"]
	var carry: ColorRect = node.get_node("Carry") as ColorRect
	if agent["state"] == "idle":
		var task := _pick_task_for_cell(agent["home"])
		if not task.is_empty():
			agent["state"] = "to_target"
			agent["target"] = task["target"]
			agent["item"] = task["item"]
			carry.visible = true
			carry.color = _station_color(task["item"])
		else:
			return
	var target_pos: Vector2 = _cell_center(agent["target"]) if agent["state"] == "to_target" else _cell_center(agent["home"])
	node.position = _move_orthogonal(node.position, target_pos, WORKER_SPEED * delta)
	if node.position.distance_to(target_pos) < 1.2:
		if agent["state"] == "to_target":
			agent["state"] = "return_home"
			carry.visible = false
		else:
			agent["state"] = "idle"
			agent["item"] = ""

func _move_orthogonal(from_pos: Vector2, to_pos: Vector2, step: float) -> Vector2:
	var p := from_pos
	if absf(to_pos.x - p.x) > 0.5:
		p.x = move_toward(p.x, to_pos.x, step)
	elif absf(to_pos.y - p.y) > 0.5:
		p.y = move_toward(p.y, to_pos.y, step)
	return p

func _pick_task_for_cell(cell_id: String) -> Dictionary:
	var station_type: String = String(GameState.factory_cell_types.get(cell_id, ""))
	if station_type == "":
		return {}
	if station_type == "storage":
		return {}
	var source_item: String = station_type
	if GameState.factory_stock[source_item] <= 0:
		return {}
	var target_type := _next_station_type(station_type)
	if target_type == "":
		return {}
	var target_cell := _find_nearest_cell_of_type(cell_id, target_type)
	if target_cell == "":
		return {}
	if not _target_needs_input(target_type):
		return {}
	return {"target": target_cell, "item": source_item}

func _next_station_type(station_type: String) -> String:
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
	return ""

func _target_needs_input(target_type: String) -> bool:
	if target_type == "pulp":
		return GameState.factory_stock["slime"] < 2
	if target_type == "smoothie":
		return GameState.factory_stock["pulp"] < 2
	if target_type == "sal":
		return GameState.factory_stock["agua"] < 2
	if target_type == "unguento":
		return GameState.factory_stock["pulp"] < 1 or GameState.factory_stock["sal"] < 1
	if target_type == "storage":
		return true
	return false

func _find_nearest_cell_of_type(from_id: String, target_type: String) -> String:
	var best_id := ""
	var best_dist := 99999
	var from_xy := _cell_to_xy(from_id)
	for other_id in GameState.factory_cell_types.keys():
		if String(GameState.factory_cell_types[other_id]) != target_type:
			continue
		var to_xy := _cell_to_xy(other_id)
		var dist := absi(from_xy.x - to_xy.x) + absi(from_xy.y - to_xy.y)
		if dist < best_dist:
			best_dist = dist
			best_id = other_id
	return best_id

func _cell_to_xy(cell_id: String) -> Vector2i:
	var parts := cell_id.split("_")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

func _cell_center(cell_id: String) -> Vector2:
	var p := _cell_to_xy(cell_id)
	return Vector2(float(p.x) * CELL_SIZE + CELL_SIZE * 0.5, float(p.y) * CELL_SIZE + CELL_SIZE * 0.5)

func _update_flow_label() -> void:
	var moving:int = 0
	for agent in worker_agents:
		if agent["state"] != "idle":
			moving += 1
	flow_label.text = "Flujo: workers moviéndose %d/%d" % [moving, worker_agents.size()]

func _refresh() -> void:
	stock_label.text = "Factory S:%d/%d P:%d/%d Sm:%d/%d A:%d/%d Sa:%d/%d U:%d/%d\nShop S:%d/%d P:%d/%d Sm:%d/%d Sa:%d/%d U:%d/%d" % [
		GameState.factory_stock["slime"], GameState.factory_cap["slime"],
		GameState.factory_stock["pulp"], GameState.factory_cap["pulp"],
		GameState.factory_stock["smoothie"], GameState.factory_cap["smoothie"],
		GameState.factory_stock["agua"], GameState.factory_cap["agua"],
		GameState.factory_stock["sal"], GameState.factory_cap["sal"],
		GameState.factory_stock["unguento"], GameState.factory_cap["unguento"],
		GameState.shop_stock["slime"], GameState.shop_cap["slime"],
		GameState.shop_stock["pulp"], GameState.shop_cap["pulp"],
		GameState.shop_stock["smoothie"], GameState.shop_cap["smoothie"],
		GameState.shop_stock["sal"], GameState.shop_cap["sal"],
		GameState.shop_stock["unguento"], GameState.shop_cap["unguento"]
	]
	pool_label.text = "Pool workers fábrica: total %d | libres %d | coste siguiente %d" % [
		GameState.factory_worker_pool_total,
		GameState.factory_worker_pool_unassigned,
		GameState.get_factory_worker_hire_cost()
	]
	if selected_cell_id != "":
		selected_cell_label.text = "Celda seleccionada: %s | Tipo a construir: %s" % [selected_cell_id, selected_station_type]
	else:
		selected_cell_label.text = "Celda seleccionada: ninguna"
	if cell_markers.size() != GameState.factory_grid_size * GameState.factory_grid_size:
		_build_world_grid()
	_sync_world_grid_colors()
	_sync_worker_agents()
	_rebuild_grid()
