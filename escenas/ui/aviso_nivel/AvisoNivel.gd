extends Control
class_name AvisoNivel
## Cartel de "¡Subiste a nivel N!" — a propósito SEPARADO del sistema de
## notificaciones chicas (PanelNotificacionesLoot, ítems/XP): el jugador
## pidió que ESTE aviso en particular sea grande y centrado arriba de la
## pantalla, sin tocar cómo se ven los avisos de ítems/XP ganada.
##
## No usa cola ni pool: subir de nivel no pasa seguido (a diferencia de
## recoger ítems), así que un solo Label reutilizado alcanza — si llega un
## segundo aviso mientras el primero sigue en pantalla, corta el fundido
## en curso y reinicia con el nuevo texto en vez de encolar.

@onready var _texto: Label = %Texto

## Segundos que el cartel queda totalmente visible antes de empezar a
## desvanecerse (más la duración del propio fundido, DURACION_FUNDIDO).
@export var duracion_visible: float = 1.6
@export var duracion_fundido: float = 0.5

var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	BusEventos.nivel_subido.connect(_on_nivel_subido)


func _on_nivel_subido(nivel_nuevo: int) -> void:
	_texto.text = "¡Subiste a nivel %d!" % nivel_nuevo
	if _tween and _tween.is_valid():
		_tween.kill()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(duracion_visible)
	_tween.tween_property(self, "modulate:a", 0.0, duracion_fundido)
