extends Node2D
class_name NumeroDaño
## Número flotante de daño. Se instancia en la posición del objetivo,
## sube y se desvanece. Llama configurar() justo después de add_child().

@export var duracion: float          = 0.75
@export var flotacion: float         = 45.0
@export var dispersión: float        = 18.0  # variación horizontal aleatoria
@export var color_daño: Color        = Color(1.00, 0.30, 0.25, 1.0)
@export var color_critico: Color     = Color(1.00, 0.90, 0.10, 1.0)
@export var umbral_critico: float    = 30.0  # daño ≥ este valor → color crítico

@onready var etiqueta: Label = $Label


func configurar(cantidad: float, posicion_global: Vector2) -> void:
	global_position = posicion_global + Vector2(randf_range(-dispersión, dispersión), -12.0)
	etiqueta.text = str(int(cantidad))
	# Reinicio para reutilización desde la piscina (ver GestorPiscinas): el
	# uso anterior pudo dejar la etiqueta desvanecida o con tamaño de crítico.
	etiqueta.modulate.a = 1.0
	etiqueta.remove_theme_font_size_override("font_size")

	var es_critico := cantidad >= umbral_critico
	etiqueta.add_theme_color_override("font_color",
		color_critico if es_critico else color_daño)
	if es_critico:
		etiqueta.add_theme_font_size_override("font_size", 26)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - flotacion, duracion) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(etiqueta, "modulate:a", 0.0, duracion * 0.45) \
		.set_delay(duracion * 0.55)
	tween.chain().tween_callback(func() -> void: GestorPiscinas.liberar(self))
