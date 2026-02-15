extends Node2D

var color := Color(0.7, 0.9, 1.0)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, color)
