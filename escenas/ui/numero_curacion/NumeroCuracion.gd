extends Node2D
class_name NumeroCuracion
## Número flotante verde de curación ("+N"). Se instancia en la posición
## del objetivo curado, sube y se desvanece — misma mecánica que NumeroDaño,
## pero en su propio script/escena (NumeroDaño es el sistema de daño ya
## probado y en uso, no hace falta ni conviene tocarlo para esto).

@export var duracion: float       = 0.75
@export var flotacion: float      = 45.0
@export var color_curacion: Color = Color(0.25, 0.90, 0.35, 1.0)

@onready var etiqueta: Label = $Label

var _tween: Tween = null


func configurar(cantidad: float, posicion_global: Vector2) -> void:
	global_position = posicion_global + Vector2(0.0, -12.0)
	etiqueta.text = "+%d" % int(cantidad)
	etiqueta.modulate.a = 1.0
	etiqueta.add_theme_color_override("font_color", color_curacion)

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", position.y - flotacion, duracion) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(etiqueta, "modulate:a", 0.0, duracion * 0.45) \
		.set_delay(duracion * 0.55)
	_tween.chain().tween_callback(func() -> void: GestorPiscinas.liberar(self))
