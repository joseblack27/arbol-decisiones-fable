extends Control
class_name BarraEnergia
## Barra de energía del jugador. Colócala en CanvasLayer.
## Asigna componente_energia en el Inspector o llama a conectar_componente().

@export var color_energia: Color  = Color(0.20, 0.65, 1.00, 0.90)
@export var color_fondo: Color    = Color(0.10, 0.10, 0.20, 0.70)
@export var color_borde: Color    = Color(0.40, 0.80, 1.00, 0.80)
@export var alto: float           = 10.0
@export var ancho: float          = 140.0
@export var radio_borde: float    = 5.0

var _fraccion: float = 1.0


func _ready() -> void:
	BusEventos.energia_cambiada.connect(_on_energia_cambiada)


func _draw() -> void:
	# Fondo
	draw_rect(Rect2(Vector2.ZERO, Vector2(ancho, alto)), color_fondo)
	# Relleno
	if _fraccion > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(ancho * _fraccion, alto)), color_energia)
	# Borde
	draw_rect(Rect2(Vector2.ZERO, Vector2(ancho, alto)), color_borde, false, 1.5)


func _on_energia_cambiada(entidad: Node, nueva: float, maxima: float) -> void:
	if not entidad.is_in_group("jugadores"):
		return
	_fraccion = nueva / maxima if maxima > 0.0 else 0.0
	queue_redraw()
