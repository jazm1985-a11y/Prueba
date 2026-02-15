extends Control

signal navigate(screen_name: String)

@onready var stock_label: Label = $VBoxContainer/StockLabel
@onready var building_label: Label = $VBoxContainer/BuildingLabel
@onready var message_label: Label = $VBoxContainer/MessageLabel
@onready var grid: GridContainer = $VBoxContainer/GridContainer

var selected_building := ""
var cells: Array[Button] = []
var grid_data := []

func _ready() -> void:
	for cell in grid.get_children():
		if cell is Button:
			cells.append(cell)
			cell.pressed.connect(_on_cell_pressed.bind(cells.size() - 1))
			grid_data.append("")
	GameState.state_changed.connect(_refresh)
	GameState.ui_message.connect(_show_message)
	_refresh()

func _exit_tree() -> void:
	if GameState.state_changed.is_connected(_refresh):
		GameState.state_changed.disconnect(_refresh)
	if GameState.ui_message.is_connected(_show_message):
		GameState.ui_message.disconnect(_show_message)

func _show_message(text: String) -> void:
	message_label.text = text

func _refresh() -> void:
	stock_label.text = "Factory: slime %d/%d | pulp %d/%d | smoothie %d/%d\nShop: slime %d/%d | pulp %d/%d | smoothie %d/%d" % [
		GameState.factory_stock["slime"], GameState.factory_cap["slime"],
		GameState.factory_stock["pulp"], GameState.factory_cap["pulp"],
		GameState.factory_stock["smoothie"], GameState.factory_cap["smoothie"],
		GameState.shop_stock["slime"], GameState.shop_cap["slime"],
		GameState.shop_stock["pulp"], GameState.shop_cap["pulp"],
		GameState.shop_stock["smoothie"], GameState.shop_cap["smoothie"]
	]
	building_label.text = "Estado: FarmerStation %s | JuicerStation %s | MixerStation %s" % [
		"Activo" if GameState.can_use_station("farmer") else "Bloqueado",
		"Activo" if GameState.can_use_station("juicer") else "Bloqueado",
		"Activo" if GameState.can_use_station("mixer") else "Bloqueado"
	]

func _on_select_farmer_station_pressed() -> void:
	selected_building = "farmer"
	_show_message("Colocando FarmerStation")

func _on_select_juicer_station_pressed() -> void:
	selected_building = "juicer"
	_show_message("Colocando JuicerStation")

func _on_select_mixer_station_pressed() -> void:
	selected_building = "mixer"
	_show_message("Colocando MixerStation")

func _on_cell_pressed(index: int) -> void:
	if selected_building == "":
		_show_message("Selecciona un edificio")
		return
	if grid_data[index] != "":
		_show_message("Celda ocupada")
		return
	grid_data[index] = selected_building
	cells[index].text = selected_building
	GameState.add_building(selected_building)
	selected_building = ""
	_show_message("Edificio colocado")

func _on_add_slime_pressed() -> void:
	GameState.manual_add_slime()

func _on_slime_to_pulp_pressed() -> void:
	GameState.manual_slime_to_pulp()

func _on_pulp_to_smoothie_pressed() -> void:
	GameState.manual_pulp_to_smoothie()

func _on_send_shop_pressed() -> void:
	GameState.manual_send_one_each_to_shop()

func _on_back_pressed() -> void:
	navigate.emit("castle")
