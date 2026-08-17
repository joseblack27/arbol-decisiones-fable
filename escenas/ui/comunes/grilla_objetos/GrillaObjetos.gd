extends Panel
class_name GrillaObjetos
## Grilla reusable de 4 columnas: puebla una CasillaObjeto por ítem
## EXISTENTE de una lista (sin huecos, sin casillas vacías precreadas —
## pedido del usuario: "no quiero slots precreados") y se reconstruye
## entera cuando el ScrollContainerObjetos avisa un cambio (ver ese
## archivo — es quien recibe el drop, no las casillas). No sabe nada de
## "cofre" ni "inventario": quien la usa (PanelCofre) le pasa CÓMO
## conseguir la lista actual y la FuenteObjetos compartida por toda la
## grilla. Reemplaza las 2 implementaciones casi idénticas que había
## repetidas en PanelCofre antes de este refactor.

const _CASILLA_SCENE := preload("res://escenas/ui/comunes/casilla_objeto/CasillaObjeto.tscn")

signal item_tocado(item: DatosItem)
## Botón de cerrar propio (ver mostrar_boton_cerrar) — pedido del usuario:
## "quiero un botón de cerrar desde esta vista, que haga lo mismo que el
## que ya está de salir". Genérica a propósito: esta grilla no sabe qué
## significa "cerrar" para quien la usa (PanelCofre la conecta a su propio
## _cerrar()), solo avisa que lo pidieron.
signal cerrar_solicitado

@export var titulo: String = "":
	set(value):
		titulo = value
		if is_node_ready():
			_titulo_label.text = value

## Oculto por defecto — no toda GrillaObjetos necesita un botón de cerrar
## (ej. si en el futuro se reusa en un contexto sin la noción de "salir").
@export var mostrar_boton_cerrar: bool = false:
	set(value):
		mostrar_boton_cerrar = value
		if is_node_ready():
			_boton_cerrar.visible = value

@onready var _titulo_label: Label = %Titulo
@onready var _boton_cerrar: Button = %BotonCerrar
@onready var _contenedor: GridContainer = %Contenedor

## [obtener_items]() -> Array[DatosItem]: la lista a mostrar AHORA MISMO —
## solo ítems que EXISTEN, sin nulls (mismo criterio que InventarioComponente
## .items, ver CofresComponente tras este refactor).
var _obtener_items: Callable = Callable()
## Compartida por TODAS las casillas de esta grilla — sin estado por
## posición (ver FuenteObjetos/ScrollContainerObjetos, que es quien la usa
## de verdad al recibir un drop).
var fuente_grilla: FuenteObjetos = null


func _ready() -> void:
	_titulo_label.text = titulo
	_boton_cerrar.visible = mostrar_boton_cerrar
	_boton_cerrar.pressed.connect(func(): cerrar_solicitado.emit())


func poblar(obtener_items: Callable, fuente: FuenteObjetos) -> void:
	_obtener_items = obtener_items
	fuente_grilla = fuente
	notificar_cambio()


## Pública: ScrollContainerObjetos la llama tras un _drop_data exitoso (ver
## ese archivo), y PanelCofre la llama cuando el inventario cambia por otra
## vía (loot recibido mientras el panel está abierto). Reconstruye ENTERA
## desde _obtener_items — barato para el tamaño real de estas grillas
## (capacidad de un cofre, ítems del inventario — nunca miles) y evita
## cualquier lógica de "actualizar solo lo que cambió" que dependería de
## que ninguna casilla se haya invalidado en el camino, que es justo lo
## que causó los bugs de self-destruido de esta sesión (ver CasillaObjeto
## .gd). Nunca se busca ESTE nodo desde afuera por nombre — quien puebla
## la grilla ya tiene la referencia directa, y cada casilla la lleva en
## "grilla_dueña".
func notificar_cambio() -> void:
	if not _obtener_items.is_valid():
		return
	_limpiar()
	var items: Array = _obtener_items.call()
	for item in items:
		var casilla: CasillaObjeto = _CASILLA_SCENE.instantiate()
		casilla.item_data = item
		casilla.fuente = fuente_grilla
		casilla.grilla_dueña = self
		casilla.tocada.connect(_on_casilla_tocada)
		_contenedor.add_child(casilla)


## Punto único de entrada para un drop aceptado en ESTA grilla — lo llaman
## tanto CasillaObjeto._drop_data (soltar sobre una casilla puntual, el
## caso más común: cubre casi toda el área visible) como ScrollContainer
## Objetos._drop_data (soltar en el hueco vacío alrededor/debajo de las
## casillas). Soltar dentro de la MISMA grilla (agarrar y soltar ahí
## mismo, o en otra casilla de la propia colección) no hace nada — pedido
## del usuario: "no permite que si agarras un item y lo sueltas ahí mismo,
## se añada de nuevo al final... aunque lo sueltes encima de otro
## CasillaObjeto, sea agregado siempre y cuando la escena padre [grilla]
## sea diferente". No hay "posición" que reordenar en una lista densa, así
## que un movimiento dentro de la misma colección no tiene ningún efecto
## que mostrar.
func recibir_desde(origen_fuente: FuenteObjetos, origen_grilla: GrillaObjetos, item: DatosItem) -> void:
	if self == origen_grilla:
		return
	if fuente_grilla == null:
		return
	if not fuente_grilla.agregar(item):
		return
	if origen_fuente:
		origen_fuente.quitar(item)

	notificar_cambio()
	if origen_grilla:
		origen_grilla.notificar_cambio()


## remove_child() + queue_free() (nunca uno sin el otro) — ver memoria
## queue-free-vs-remove-child-godot.
func _limpiar() -> void:
	for hijo in _contenedor.get_children():
		_contenedor.remove_child(hijo)
		hijo.queue_free()


func _on_casilla_tocada(item: DatosItem) -> void:
	if item:
		item_tocado.emit(item)
