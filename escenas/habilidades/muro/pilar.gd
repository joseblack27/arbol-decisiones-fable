extends Node2D
class_name Pilar
## Visual del pilar: el sprite se configura en el Inspector (textura/escala
## a elección de quien diseñe el nivel). Sin colisión propia — la detección
## de daño y el bloqueo físico los maneja el Muro contenedor sobre toda la fila.

@export var radio_placeholder: float = 8.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Mientras no se le asigne una textura real al Sprite2D (Inspector), se
	# dibuja un marcador simple para poder ver/probar la habilidad ya mismo.
	if not _sprite.texture:
		queue_redraw()


func _draw() -> void:
	if _sprite.texture:
		return
	draw_circle(Vector2.ZERO, radio_placeholder, Color(0.45, 0.42, 0.38, 1.0))
	draw_arc(Vector2.ZERO, radio_placeholder, 0.0, TAU, 16, Color(0.2, 0.18, 0.15, 1.0), 2.0)
