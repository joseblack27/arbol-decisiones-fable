extends PanelContainer
class_name MenuAccesosOS
## Cuadrícula de accesos directos a secciones del panel OS (ver
## OsPrincipal.gd) — pedido explícito del usuario: en vez de que el botón
## "OS" abra directo el panel en su pestaña por defecto, abre ESTA
## cuadrícula (máximo 4 columnas, anclada arriba a la derecha por debajo
## del botón); tocar un ícono abre el panel OS directo en esa sección.
##
## Genérica a propósito: agregar una opción nueva más adelante es crear un
## OpcionMenuOS.tres (ícono + nombre del método de OsPrincipal que abre esa
## sección) y sumarlo al array "opciones" del inspector — este script no
## sabe nada de inventario/mapa/habilidades en particular, solo arma un
## botón por entrada y llama a su método por nombre.

const _MAX_COLUMNAS := 4
const _TAMANO_BOTON := Vector2(48, 48)
## Tamaño de fuente de la etiqueta bajo cada ícono — pedido explícito del
## usuario: nada de tooltip (el juego es para celular, sin mouse que se
## quede quieto encima para dispararlo), el texto va SIEMPRE visible.
const _TAMANO_FUENTE_ETIQUETA := 9

@export var opciones: Array[OpcionMenuOS] = []

@onready var _grid: GridContainer = $Grid


func _ready() -> void:
	visible = false
	_grid.columns = _MAX_COLUMNAS
	for opcion in opciones:
		if opcion == null:
			continue
		_grid.add_child(_crear_celda(opcion))
	# Deferido: recién con las celdas ya agregadas y un fotograma de
	# layout de por medio el GridContainer reporta su tamaño mínimo real
	# (columnas completas, separación) — pedirlo antes daría 0x0.
	call_deferred("_ajustar_tamano")


## Ícono (el botón real, lo que se toca) + etiqueta de texto debajo, fija
## siempre visible — no un tooltip.
func _crear_celda(opcion: OpcionMenuOS) -> VBoxContainer:
	var celda := VBoxContainer.new()
	celda.add_theme_constant_override("separation", 2)

	var boton := Button.new()
	boton.custom_minimum_size = _TAMANO_BOTON
	boton.theme_type_variation = &"RanuraHud"
	boton.icon = opcion.icono
	boton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton.focus_mode = Control.FOCUS_NONE
	boton.pressed.connect(_al_elegir.bind(opcion))
	celda.add_child(boton)

	var etiqueta := Label.new()
	etiqueta.text = opcion.etiqueta
	etiqueta.custom_minimum_size.x = _TAMANO_BOTON.x
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD
	etiqueta.add_theme_font_size_override("font_size", _TAMANO_FUENTE_ETIQUETA)
	celda.add_child(etiqueta)

	return celda


## Los botones se agregan por código (no viven en el .tscn, salen de
## "opciones") — sin fijar el tamaño acá, el PanelContainer se queda en el
## tamaño de diseño vacío en vez de encoger/crecer según cuántas opciones
## haya de verdad.
func _ajustar_tamano() -> void:
	reset_size()


func alternar() -> void:
	visible = not visible


func cerrar() -> void:
	visible = false


func _al_elegir(opcion: OpcionMenuOS) -> void:
	visible = false
	if opcion.metodo_en_os.is_empty():
		return
	var os_principal := get_tree().get_root().find_child("OsPrincipal", true, false)
	if os_principal == null:
		return
	GestorUI.abrir_os()
	if "color_rect" in os_principal:
		os_principal.color_rect.show()
	if os_principal.has_method(opcion.metodo_en_os):
		os_principal.call(opcion.metodo_en_os)
