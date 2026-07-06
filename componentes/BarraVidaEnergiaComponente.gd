extends Node2D
class_name BarraVidaEnergiaComponente
## Barras de vida y energía sobre la cabeza de un enemigo.
## Colócalo como hijo directo del enemigo (mismo padre que VidaComponente y,
## si tiene, EnergiaComponente): se busca a los hermanos por nombre, no hace
## falta cablear nada a mano. Si el enemigo no tiene EnergiaComponente (p. ej.
## el ratón), simplemente no dibuja esa segunda barra.
##
## No necesita lógica propia para desaparecer al morir: al ser hijo del
## mismo CharacterBody2D, hereda el modulate que Enemigo._desvanecer_y_eliminar
## ya anima (a negro y luego transparente).

@export var ancho: float = 28.0
@export var alto_vida: float = 4.0
@export var alto_energia: float = 3.0
@export var separacion: float = 1.0

@export var color_fondo: Color   = Color(0.05, 0.05, 0.05, 0.75)
@export var color_vida: Color    = Color(0.85, 0.15, 0.15, 0.95)
@export var color_energia: Color = Color(0.20, 0.65, 1.00, 0.95)
@export var color_borde: Color   = Color(0.0, 0.0, 0.0, 0.6)

var _fraccion_vida: float = 1.0
var _fraccion_energia: float = 1.0
var _tiene_energia: bool = false


func _ready() -> void:
	# Esperar a que termine de propagarse el _ready de TODO el árbol de este
	# fotograma: el orden de _ready entre hermanos (VidaComponente, esta
	# barra…) depende del orden en la escena, y encima Enemigo._aplicar_datos()
	# (que fija la vida máxima real desde EnemigoDatos) corre en el _ready del
	# nodo raíz, que puede llegar DESPUÉS del de esta barra. Sin esta espera,
	# la barra podía leer valores aún sin inicializar y arrancar vacía/negra
	# hasta el primer cambio de vida.
	await get_tree().process_frame

	var vida := get_parent().get_node_or_null("VidaComponente") as VidaComponente
	if vida:
		var maxima := vida.obtener_vida_maxima()
		_fraccion_vida = clampf(vida.obtener_vida() / maxima, 0.0, 1.0) if maxima > 0.0 else 0.0
		vida.cambio_valor_vida.connect(_al_cambiar_vida.bind(vida))

	var energia := get_parent().get_node_or_null("EnergiaComponente") as EnergiaComponente
	if energia:
		_tiene_energia = true
		_fraccion_energia = energia.obtener_fraccion()
		energia.energia_cambiada.connect(_al_cambiar_energia)

	queue_redraw()


func _al_cambiar_vida(valor: float, vida: VidaComponente) -> void:
	var maxima := vida.obtener_vida_maxima()
	_fraccion_vida = clampf(valor / maxima, 0.0, 1.0) if maxima > 0.0 else 0.0
	queue_redraw()


func _al_cambiar_energia(nueva: float, maxima: float) -> void:
	_fraccion_energia = clampf(nueva / maxima, 0.0, 1.0) if maxima > 0.0 else 0.0
	queue_redraw()


func _draw() -> void:
	_dibujar_barra(Vector2(-ancho / 2.0, 0.0), alto_vida, _fraccion_vida, color_vida)
	if _tiene_energia:
		_dibujar_barra(
			Vector2(-ancho / 2.0, alto_vida + separacion), alto_energia, _fraccion_energia, color_energia
		)


func _dibujar_barra(pos: Vector2, alto: float, fraccion: float, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(ancho, alto)), color_fondo)
	if fraccion > 0.0:
		draw_rect(Rect2(pos, Vector2(ancho * fraccion, alto)), color)
	draw_rect(Rect2(pos, Vector2(ancho, alto)), color_borde, false, 1.0)
