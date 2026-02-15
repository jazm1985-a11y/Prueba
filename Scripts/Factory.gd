extends Control

@onready var stock_label: Label = $VBox/StockLabel
@onready var station_status_label: Label = $VBox/StationStatusLabel
@onready var status_label: Label = $VBox/StatusLabel
@onready var grid: GridContainer = $VBox/Grid

func _ready() -> void:
	$VBox/PlaceButtons/FarmerStationButton.pressed.connect(func() -> void: _select_building("FarmerStation"))
	$VBox/PlaceButtons/JuicerStationButton.pressed.connect(func() -> void: _select_building("JuicerStation"))
	$VBox/PlaceButtons/MixerStationButton.pressed.connect(func() -> void: _select_building("MixerStation"))
	$VBox/ExpandButton.pressed.connect(_expand_grid)
	$VBox/ManualButtons/AddSlimeButton.pressed.connect(_manual_slime)
	$VBox/ManualButtons/MakePulpButton.pressed.connect(_manual_pulp)
	$VBox/ManualButtons/MakeSmoothieButton.pressed.connect(_manual_smoothie)
	$VBox/ManualButtons/SendBundleButton.pressed.connect(_send_bundle)
	$VBox/CollectButtons/CollectSlimeButton.pressed.connect(func() -> void: _collect_station("slime"))
	$VBox/CollectButtons/CollectPulpButton.pressed.connect(func() -> void: _collect_station("pulp"))
	$VBox/CollectButtons/CollectSmoothieButton.pressed.connect(func() -> void: _collect_station("smoothie"))
	$VBox/CollectButtons/CollectAguaButton.pressed.connect(func() -> void: _collect_station("agua"))
	$VBox/CollectButtons/CollectSalButton.pressed.connect(func() -> void: _collect_station("sal"))
	$VBox/CollectButtons/CollectUnguentoButton.pressed.connect(func() -> void: _collect_station("unguento"))
	$VBox/TransferButtons/TransferSlimeButton.pressed.connect(func() -> void: _transfer_item("slime"))
	$VBox/TransferButtons/TransferPulpButton.pressed.connect(func() -> void: _transfer_item("pulp"))
	$VBox/TransferButtons/TransferSmoothieButton.pressed.connect(func() -> void: _transfer_item("smoothie"))
	$VBox/TransferButtons/TransferSalButton.pressed.connect(func() -> void: _transfer_item("sal"))
	$VBox/TransferButtons/TransferUnguentoButton.pressed.connect(func() -> void: _transfer_item("unguento"))
	GameState.state_changed.connect(_refresh)
	_rebuild_grid()
	_refresh()

func _select_building(building_name: String) -> void:
	GameState.selected_building = building_name
	status_label.text = "Seleccionado: " + building_name

func _expand_grid() -> void:
	GameState.expand_factory_grid()
	_rebuild_grid()
	status_label.text = "Grid ampliado"

func _manual_slime() -> void:
	_show_result(GameState.try_add_slime_manual())

func _manual_pulp() -> void:
	_show_result(GameState.try_convert_slime_to_pulp_manual())

func _manual_smoothie() -> void:
	_show_result(GameState.try_convert_pulp_to_smoothie_manual())

func _send_bundle() -> void:
	_show_result(GameState.try_send_bundle_to_shop())

func _collect_station(station: String) -> void:
	_show_result(GameState.collect_station(station))

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
			b.custom_minimum_size = Vector2(80, 80)
			b.text = GameState.factory_layout.get(id, "Vacío")
			b.pressed.connect(func() -> void: _place_on_cell(id))
			grid.add_child(b)

func _place_on_cell(cell_id: String) -> void:
	if GameState.selected_building == "":
		status_label.text = "Bloqueado"
		return
	var result := GameState.place_building(cell_id, GameState.selected_building)
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
	station_status_label.text = "LISTO -> Sl:%d Pu:%d Sm:%d Ag:%d Sa:%d Un:%d" % [
		GameState.station_ready["slime"],
		GameState.station_ready["pulp"],
		GameState.station_ready["smoothie"],
		GameState.station_ready["agua"],
		GameState.station_ready["sal"],
		GameState.station_ready["unguento"]
	]
