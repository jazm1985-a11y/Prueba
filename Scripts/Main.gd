extends Control

@onready var screen_container: Control = $Margin/VBox/ScreenContainer
@onready var status_label: Label = $Margin/VBox/StatusLabel

var current_screen: Node

func _ready() -> void:
	$Margin/VBox/Nav/HBox/CastleButton.pressed.connect(_on_castle_pressed)
	$Margin/VBox/Nav/HBox/FactoryButton.pressed.connect(_on_factory_pressed)
	$Margin/VBox/Nav/HBox/ShopButton.pressed.connect(_on_shop_pressed)
	_on_castle_pressed()

func _on_castle_pressed() -> void:
	load_screen("res://Scenes/Castle.tscn")

func _on_factory_pressed() -> void:
	load_screen("res://Scenes/Factory.tscn")

func _on_shop_pressed() -> void:
	load_screen("res://Scenes/Shop.tscn")

func load_screen(path: String) -> void:
	if current_screen:
		current_screen.queue_free()
	var packed := load(path) as PackedScene
	if packed == null:
		status_label.text = "No se pudo cargar escena"
		return
	current_screen = packed.instantiate()
	screen_container.add_child(current_screen)
	status_label.text = "Pantalla: " + current_screen.name
