extends Control

@onready var stock_label: Label = $VBox/StockLabel
@onready var pool_label: Label = $VBox/PoolLabel
@onready var status_label: Label = $VBox/StatusLabel
@onready var grid: GridContainer = $VBox/Grid

var selected_station_type:String = "slime"
var selected_cell_id:String = ""

func _ready() -> void:
	$VBox/SelectorButtons/SelectSlimeButton.pressed.connect(func() -> void: _select_station_type("slime"))
	$VBox/SelectorButtons/SelectPulpButton.pressed.connect(func() -> void: _select_station_type("pulp"))
	$VBox/SelectorButtons/SelectSmoothieButton.pressed.connect(func() -> void: _select_station_type("smoothie"))
	$VBox/SelectorButtons/SelectAguaButton.pressed.connect(func() -> void: _select_station_type("agua"))
	$VBox/SelectorButtons/SelectSalButton.pressed.connect(func() -> void: _select_station_type("sal"))
	$VBox/SelectorButtons/SelectUnguentoButton.pressed.connect(func() -> void: _select_station_type("unguento"))
	$VBox/SelectorButtons/SelectStorageButton.pressed.connect(func() -> void: _select_station_type("storage"))
	$VBox/SelectorButtons/SelectEmptyButton.pressed.connect(func() -> void: _select_station_type("empty"))

	$VBox/WorkerButtons/HireFactoryWorkerButton.pressed.connect(_buy_worker)
	$VBox/WorkerButtons/AssignWorkerButton.pressed.connect(_assign_worker_to_selected)
	$VBox/WorkerButtons/UnassignWorkerButton.pressed.connect(_unassign_worker_from_selected)

	$VBox/TransferButtons/TransferSlimeButton.pressed.connect(func() -> void: _transfer_item("slime"))
	$VBox/TransferButtons/TransferPulpButton.pressed.connect(func() -> void: _transfer_item("pulp"))
	$VBox/TransferButtons/TransferSmoothieButton.pressed.connect(func() -> void: _transfer_item("smoothie"))
	$VBox/TransferButtons/TransferSalButton.pressed.connect(func() -> void: _transfer_item("sal"))
	$VBox/TransferButtons/TransferUnguentoButton.pressed.connect(func() -> void: _transfer_item("unguento"))

	GameState.state_changed.connect(_refresh)
	_rebuild_grid()
	_refresh()

func _select_station_type(station_type: String) -> void:
	selected_station_type = station_type
	status_label.text = "Tipo seleccionado: " + station_type

func _buy_worker() -> void:
	_show_result(GameState.try_hire_factory_worker())

func _assign_worker_to_selected() -> void:
	if selected_cell_id == "":
		status_label.text = "Bloqueado"
		return
	_show_result(GameState.assign_worker_to_cell(selected_cell_id))

func _unassign_worker_from_selected() -> void:
	if selected_cell_id == "":
		status_label.text = "Bloqueado"
		return
	_show_result(GameState.unassign_worker_from_cell(selected_cell_id))

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
			b.text = GameState.get_factory_cell_label(id)
			b.pressed.connect(func() -> void: _on_grid_cell_pressed(id))
			grid.add_child(b)

func _on_grid_cell_pressed(cell_id: String) -> void:
	selected_cell_id = cell_id
	var result := GameState.set_factory_cell_type(cell_id, selected_station_type)
	_show_result(result)
	_rebuild_grid()

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
	_rebuild_grid()
