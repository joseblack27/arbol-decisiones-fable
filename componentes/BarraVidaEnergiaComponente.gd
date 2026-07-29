extends Node2D
class_name BarraVidaEnergiaComponente
## Nameplate del enemigo: "Nv.X Nombre" arriba, y debajo las barras de vida y
## energía. Colócalo como hijo directo del enemigo (mismo padre que
## VidaComponente y, si tiene, EnergiaComponente): se busca a los hermanos por
## nombre, no hace falta cablear nada a mano. Si el enemigo no tiene
## EnergiaComponente (p. ej. el ratón), simplemente no dibuja esa segunda barra.
##
## El nombre y el nivel salen del EnemigoDatos del padre (ver
## recursos/enemigos/EnemigoDatos.gd). Sin datos asignados (Araña, Ratón) cae
## al nombre del nodo y no muestra nivel — así ningún mob queda con un "Nv.1"
## inventado que no significa nada.
##
## Todo se dibuja acá (no con nodos Label) porque este componente ya lo usan
## los 7 enemigos: sumar el texto acá los cubre a todos de una, en vez de
## tener que tocar cada escena por separado.
##
## No necesita lógica propia para desaparecer al morir: al ser hijo del
## mismo CharacterBody2D, hereda el modulate que Enemigo._desvanecer_y_eliminar
## ya anima (a negro y luego transparente).

const _FUENTE := preload("res://assets/fonts/jet brain mono/JetBrainsMono-Medium.ttf")

@export var ancho: float = 40.0
@export var alto_vida: float = 4.0
@export var alto_energia: float = 3.0
@export var separacion: float = 1.0

@export_group("Nombre")
@export var mostrar_nombre: bool = true
@export var tamano_fuente: int = 7
## Separación entre la línea de texto y el borde superior de la barra de vida.
@export var margen_nombre: float = 3.0
@export var color_nombre: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var color_contorno_nombre: Color = Color(0.0, 0.0, 0.0, 0.9)
## Grosor del contorno del texto. 2 con fuente 7 es el punto de equilibrio,
## verificado sobre terreno claro Y oscuro: con 1 el texto blanco casi
## desaparece sobre la arena, y con 4 (la proporción del HUD para fuentes más
## grandes) el contorno se come el glifo y queda una mancha.
@export var grosor_contorno_nombre: int = 2

@export_group("Colores")
@export var color_fondo: Color   = Color(0.05, 0.05, 0.05, 0.75)
@export var color_vida: Color    = Color(0.85, 0.15, 0.15, 0.95)
@export var color_energia: Color = Color(0.20, 0.65, 1.00, 0.95)
@export var color_borde: Color   = Color(0.0, 0.0, 0.0, 0.6)

var _fraccion_vida: float = 1.0
var _fraccion_energia: float = 1.0
var _tiene_energia: bool = false
var _texto_nombre: String = ""


func _ready() -> void:
	# Esperar a que termine de propagarse el _ready de TODO el árbol de este
	# fotograma: el orden de _ready entre hermanos (VidaComponente, esta
	# barra…) depende del orden en la escena, y encima Enemigo._aplicar_datos()
	# (que fija la vida máxima real desde EnemigoDatos) corre en el _ready del
	# nodo raíz, que puede llegar DESPUÉS del de esta barra. Sin esta espera,
	# la barra podía leer valores aún sin inicializar y arrancar vacía/negra
	# hasta el primer cambio de vida. Vale igual para el nombre/nivel, que
	# salen del mismo EnemigoDatos.
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

	_resolver_nombre()
	queue_redraw()


## "Nv.X Nombre" si el mob tiene EnemigoDatos; solo el nombre del nodo si no
## (ver el comentario de cabecera sobre por qué no se inventa un nivel).
func _resolver_nombre() -> void:
	if not mostrar_nombre:
		return
	var padre := get_parent()
	if padre == null:
		return
	var datos = padre.get("datos") if "datos" in padre else null
	if datos != null:
		var nombre: String = str(datos.get("nombre_tipo")).strip_edges()
		if nombre == "":
			nombre = String(padre.name)
		var nivel: int = int(datos.get("nivel")) if "nivel" in datos else 0
		_texto_nombre = ("Nv.%d %s" % [nivel, nombre]) if nivel > 0 else nombre
	else:
		_texto_nombre = String(padre.name)


func _al_cambiar_vida(valor: float, vida: VidaComponente) -> void:
	var maxima := vida.obtener_vida_maxima()
	_fraccion_vida = clampf(valor / maxima, 0.0, 1.0) if maxima > 0.0 else 0.0
	queue_redraw()


func _al_cambiar_energia(nueva: float, maxima: float) -> void:
	_fraccion_energia = clampf(nueva / maxima, 0.0, 1.0) if maxima > 0.0 else 0.0
	queue_redraw()


func _draw() -> void:
	if mostrar_nombre and _texto_nombre != "":
		_dibujar_nombre()
	_dibujar_barra(Vector2(-ancho / 2.0, 0.0), alto_vida, _fraccion_vida, color_vida)
	if _tiene_energia:
		_dibujar_barra(
			Vector2(-ancho / 2.0, alto_vida + separacion), alto_energia, _fraccion_energia, color_energia
		)


## Centrado sobre las barras. El texto puede ser más ancho que la barra (los
## nombres largos como "Caballero Esqueleto" lo son): se centra igual sobre
## el mob, desbordando parejo a los dos lados en vez de recortarse.
func _dibujar_nombre() -> void:
	var ancho_texto := _FUENTE.get_string_size(
		_texto_nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente).x
	# draw_string posiciona por la LÍNEA BASE (el pie de las letras), no por
	# el borde superior del texto: con la base en -margen_nombre, el texto
	# crece hacia ARRIBA desde ahí y queda por encima de la barra de vida,
	# que arranca en y=0.
	var pos := Vector2(-ancho_texto / 2.0, -margen_nombre)
	if grosor_contorno_nombre > 0:
		draw_string_outline(_FUENTE, pos, _texto_nombre, HORIZONTAL_ALIGNMENT_LEFT, -1,
			tamano_fuente, grosor_contorno_nombre, color_contorno_nombre)
	draw_string(_FUENTE, pos, _texto_nombre, HORIZONTAL_ALIGNMENT_LEFT, -1,
		tamano_fuente, color_nombre)


func _dibujar_barra(pos: Vector2, alto: float, fraccion: float, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(ancho, alto)), color_fondo)
	if fraccion > 0.0:
		draw_rect(Rect2(pos, Vector2(ancho * fraccion, alto)), color)
	draw_rect(Rect2(pos, Vector2(ancho, alto)), color_borde, false, 1.0)
