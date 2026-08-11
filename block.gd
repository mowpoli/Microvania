@tool
extends StaticBody2D


func _process(_delta: float) -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var visual := get_node_or_null("ColorRect") as ColorRect

	if collision == null or visual == null:
		return

	var retangulo := collision.shape as RectangleShape2D

	if retangulo == null:
		return

	visual.size = retangulo.size
	visual.position = collision.position - retangulo.size / 2.0
