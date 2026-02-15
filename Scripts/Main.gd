extends Control

@onready var screen_container: Control = $MarginContainer/VBoxContainer/ScreenContainer

var _current_screen: Control

func _ready() -> void:
	_show_screen("castle")

func _show_screen(screen_name: String) -> void:
	if _current_screen:
		_current_screen.queue_free()
	var scene_path := ""
	match screen_name:
		"castle":
			scene_path = "res://Scenes/Castle.tscn"
		"factory":
			scene_path = "res://Scenes/Factory.tscn"
		"shop":
			scene_path = "res://Scenes/Shop.tscn"
	if scene_path == "":
		return
	_current_screen = load(scene_path).instantiate()
	screen_container.add_child(_current_screen)
	if _current_screen.has_signal("navigate"):
		_current_screen.navigate.connect(_show_screen)
