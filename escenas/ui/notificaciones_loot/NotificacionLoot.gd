extends PanelContainer
class_name NotificacionLoot
## Una fila de la lista de avisos rápidos (botín obtenido, XP ganada...):
## ícono opcional + texto. No interactuable (mouse_filter=IGNORE en toda la
## fila) — solo aparece, espera unos segundos y se desvanece sola.

@export var duracion_visible: float = 2.5
@export var duracion_fundido: float = 0.4

@onready var _icono: TextureRect = $Margen/HBox/Icono
@onready var _texto: Label       = $Margen/HBox/Texto


## Fila de un ítem obtenido: ícono + "+cantidad nombre".
func configurar(item: DatosItem, cantidad: int) -> void:
	_icono.texture = item.icon
	_icono.visible = true
	_texto.text = "+%d %s" % [cantidad, item.name]
	_iniciar_fundido()


## Fila de texto simple, sin ícono (p. ej. XP ganada).
func configurar_texto(texto: String) -> void:
	_icono.visible = false
	_texto.text = texto
	_iniciar_fundido()


func _iniciar_fundido() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_interval(duracion_visible)
	tween.tween_property(self, "modulate:a", 0.0, duracion_fundido)
	tween.tween_callback(queue_free)
