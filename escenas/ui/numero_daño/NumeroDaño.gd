extends Node2D
class_name NumeroDaño
## Número flotante de daño. Se instancia en la posición del objetivo,
## sube y se desvanece. Llama configurar() justo después de add_child().

@export var duracion: float          = 0.75
@export var flotacion: float         = 45.0
## Variación horizontal aleatoria. En 0 (pedido del usuario: el número
## siempre centrado horizontalmente con la entidad) — el costo asumido es
## que dos golpes muy seguidos al mismo objetivo caen en el punto exacto y
## se tapan un instante; subir este valor los dispersa si algún día molesta.
@export var dispersión: float        = 0.0
@export var tamano_fuente: int       = 20
@export var tamano_fuente_critico: int = 26
@export var color_daño: Color        = Color(1.00, 0.30, 0.25, 1.0)
@export var color_critico: Color     = Color(1.00, 0.90, 0.10, 1.0)
@export var umbral_critico: float    = 30.0  # daño ≥ este valor → color crítico

@onready var etiqueta: Label = $Label

var _tween: Tween = null


func configurar(cantidad: float, posicion_global: Vector2) -> void:
	# Centrado HORIZONTAL exacto con la entidad (dispersión=0 por defecto,
	# pedido del usuario); en vertical conserva el pequeño realce de -12px
	# de siempre (arranca apenas sobre el centro y flota hacia arriba).
	global_position = posicion_global + Vector2(randf_range(-dispersión, dispersión), -12.0)
	etiqueta.text = str(int(cantidad))
	# Reinicio para reutilización desde la piscina (ver GestorPiscinas): el
	# uso anterior pudo dejar la etiqueta desvanecida o con tamaño de crítico.
	etiqueta.modulate.a = 1.0

	var es_critico := cantidad >= umbral_critico
	etiqueta.add_theme_color_override("font_color",
		color_critico if es_critico else color_daño)
	# SIEMPRE fijar el tamaño explícito (nunca remove_theme_font_size_override:
	# eso borraba también el 20 que fija la ESCENA, y desde el primer
	# reciclaje del pool los números no críticos salían con el tamaño por
	# defecto del tema — chiquitos, "a veces ni se ven").
	etiqueta.add_theme_font_size_override("font_size",
		tamano_fuente_critico if es_critico else tamano_fuente)

	# Matar el tween anterior antes de crear uno nuevo: si este nodo fue
	# liberado a mitad de animación (cambio de nivel via
	# liberar_todos_los_activos), su tween viejo seguía vivo pausado — al
	# reutilizarlo, ese tween retomaba y liberaba el número EN PLENO VUELO.
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", position.y - flotacion, duracion) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(etiqueta, "modulate:a", 0.0, duracion * 0.45) \
		.set_delay(duracion * 0.55)
	_tween.chain().tween_callback(func() -> void: GestorPiscinas.liberar(self))
