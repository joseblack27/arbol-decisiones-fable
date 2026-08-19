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

## Botón "Tomar todo" (ver mostrar_boton_tomar_todo) — pedido del usuario:
## "un botón que solo se muestre en el inventario del cofre, y pase todo al
## inventario". Misma idea que cerrar_solicitado: esta grilla no sabe qué
## significa "tomar todo" (no conoce ninguna otra grilla), solo avisa que
## lo pidieron — PanelCofre es quien de verdad mueve los ítems, usando el
## fuente_grilla de ESTA grilla y el de GrillaJugador.
signal tomar_todo_solicitado

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

## Oculto por defecto — pedido del usuario: "solo se muestre en el
## inventario del cofre" (PanelCofre lo activa nada más en GrillaCofre).
@export var mostrar_boton_tomar_todo: bool = false:
	set(value):
		mostrar_boton_tomar_todo = value
		if is_node_ready():
			_boton_tomar_todo.visible = value

## false (por defecto) = la barra de scroll queda a la DERECHA de las
## casillas (orden natural del .tscn); true = a la IZQUIERDA. Pedido del
## usuario: "que cuando sea del inventario del jugador muestre el scroll
## derecho y cuando sea el del cofre muestre el scroll izquierdo, para dar
## un buen diseño para los dedos" — en PanelCofre, GrillaCofre queda a la
## izquierda de la pantalla y GrillaJugador a la derecha; con la barra
## siempre "hacia afuera" (el borde de la pantalla, no el que da contra el
## panel de detalle del medio) queda al alcance del pulgar de cada mano
## sin cruzar la pantalla.
@export var scroll_a_la_izquierda: bool = false:
	set(value):
		scroll_a_la_izquierda = value
		if is_node_ready():
			_aplicar_orden_scroll()

## Oculto por defecto — pedido del usuario: "filtros como lo del
## inventario por categoría de objetos... pero parametrizable por un
## booleano para quitarlo o ponerlo". Mismas 4 categorías/orden que ya usan
## PanelInventario (FlujoItems.gd) y PanelTienda (_TIPOS_FILTRO): Todos,
## Equipables, Consumibles, Recursos — ver _TIPOS_FILTRO.
@export var mostrar_filtro_categorias: bool = false:
	set(value):
		mostrar_filtro_categorias = value
		if is_node_ready():
			_tabs_filtro.visible = value

## Texto del estado vacío (ver notificar_cambio) — pedido del usuario:
## "agrega el estado vacío". Un campo por instancia, no un texto fijo, para
## que cada grilla pueda decir "Cofre vacío" / "No tenés objetos" en vez de
## un genérico "Vacío" — esta grilla no sabe si es cofre o inventario.
@export var texto_vacio: String = "Vacío":
	set(value):
		texto_vacio = value
		if is_node_ready():
			_etiqueta_vacia.text = value

## Oculto por defecto — pedido del usuario: "poder organizar los ítems por
## orden alfabético de las categorías ascendente y descendente, orden
## alfabético ascendente y descendente [por nombre]". Mismo criterio que
## mostrar_filtro_categorias: parametrizable por booleano.
@export var mostrar_ordenar: bool = false:
	set(value):
		mostrar_ordenar = value
		if is_node_ready():
			_fila_orden.visible = value

enum OrdenItems { SIN_ORDENAR, CATEGORIA_ASC, CATEGORIA_DESC, NOMBRE_ASC, NOMBRE_DESC }

@onready var _titulo_label: Label = %Titulo
@onready var _boton_cerrar: Button = %BotonCerrar
@onready var _boton_tomar_todo: Button = %BotonTomarTodo
@onready var _contenedor: GridContainer = %Contenedor
@onready var _popup_cantidad: PopupCantidad = %PopupCantidad
@onready var _barra_desplazamiento: Control = %BarraDesplazamientoV
@onready var _tabs_filtro: HBoxContainer = %TabsFiltro
@onready var _botones_filtro: Array[Button] = [%BotonFiltroTodos, %BotonFiltroEquipables, %BotonFiltroConsumibles, %BotonFiltroRecursos]
@onready var _etiqueta_vacia: Label = %EtiquetaVacia
@onready var _fila_orden: HBoxContainer = %FilaOrden
@onready var _selector_orden: OptionButton = %SelectorOrden

## Mismo orden que _botones_filtro — índice a índice.
const _TIPOS_FILTRO := [
	Enums.Inventario.TipoItem.TODOS,
	Enums.Inventario.TipoItem.EQUIPABLE,
	Enums.Inventario.TipoItem.CONSUMIBLE,
	Enums.Inventario.TipoItem.RECURSO,
]
var _filtro_categoria_actual: Enums.Inventario.TipoItem = Enums.Inventario.TipoItem.TODOS

## Mismo orden que los add_item() de _ready() — índice del OptionButton ==
## valor del enum, así el índice que manda item_selected() se puede usar
## directo como OrdenItems sin mapear nada.
var _orden_actual: OrdenItems = OrdenItems.SIN_ORDENAR

## [obtener_items]() -> Array[DatosItem]: la lista a mostrar AHORA MISMO —
## solo ítems que EXISTEN, sin nulls (mismo criterio que InventarioComponente
## .items, ver CofresComponente tras este refactor).
var _obtener_items: Callable = Callable()
## Compartida por TODAS las casillas de esta grilla — sin estado por
## posición (ver FuenteObjetos/ScrollContainerObjetos, que es quien la usa
## de verdad al recibir un drop).
var fuente_grilla: FuenteObjetos = null

## A qué grilla manda un doble-tap sobre una casilla de ESTA grilla (ver
## CasillaObjeto._transferencia_rapida) — pedido del usuario: "el
## doble-tap para transferencia rápida". null = sin configurar (grilla
## suelta, sin contraparte armada). No es @export: como fuente_grilla, se
## arma en tiempo de ejecución — quien usa dos GrillaObjetos como par (ej.
## PanelCofre) las conecta entre sí después de poblarlas, esta grilla no
## sabe nada de la otra por sí sola.
var grilla_destino_rapida: GrillaObjetos = null

## Transferencia esperando que PopupCantidad confirme una cantidad (ver
## recibir_desde()) — solo puede haber UNA a la vez, el popup bloquea el
## resto de la UI mientras está abierto.
var _pendiente_origen_fuente: FuenteObjetos = null
var _pendiente_origen_grilla: GrillaObjetos = null
var _pendiente_item: DatosItem = null


func _ready() -> void:
	_titulo_label.text = titulo
	_boton_cerrar.visible = mostrar_boton_cerrar
	_boton_cerrar.pressed.connect(func(): cerrar_solicitado.emit())
	_boton_tomar_todo.visible = mostrar_boton_tomar_todo
	_boton_tomar_todo.pressed.connect(func(): tomar_todo_solicitado.emit())
	_aplicar_orden_scroll()
	_tabs_filtro.visible = mostrar_filtro_categorias
	for i in _botones_filtro.size():
		var tipo: Enums.Inventario.TipoItem = _TIPOS_FILTRO[i]
		_botones_filtro[i].pressed.connect(func(): _seleccionar_filtro(tipo))
	_etiqueta_vacia.text = texto_vacio
	_fila_orden.visible = mostrar_ordenar
	_selector_orden.add_item("Sin ordenar")
	_selector_orden.add_item("Categoría (A-Z)")
	_selector_orden.add_item("Categoría (Z-A)")
	_selector_orden.add_item("Nombre (A-Z)")
	_selector_orden.add_item("Nombre (Z-A)")
	_selector_orden.item_selected.connect(_on_orden_seleccionado)
	_popup_cantidad.confirmada.connect(_on_popup_cantidad_confirmada)
	_popup_cantidad.cancelada.connect(_limpiar_pendiente)


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
	# .duplicate(): _ordenar()/filter() no deben mutar la lista REAL de
	# quien la provee (ej. InventarioComponente.items) — sin filtro activo,
	# _obtener_items.call() devuelve esa misma referencia tal cual.
	var items: Array = _obtener_items.call().duplicate()
	if mostrar_filtro_categorias and _filtro_categoria_actual != Enums.Inventario.TipoItem.TODOS:
		items = items.filter(func(item: DatosItem) -> bool: return item.type == _filtro_categoria_actual)
	_ordenar(items)
	for item in items:
		var casilla: CasillaObjeto = _CASILLA_SCENE.instantiate()
		casilla.item_data = item
		casilla.fuente = fuente_grilla
		casilla.grilla_dueña = self
		casilla.tocada.connect(_on_casilla_tocada)
		_contenedor.add_child(casilla)
	_etiqueta_vacia.visible = items.is_empty()


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
## Si el stack tiene más de 1 unidad, no mueve nada todavía: abre
## PopupCantidad (pedido del usuario: "que me deje elegir cuantos quiero
## pasar") y guarda los datos del drop en _pendiente_* hasta que el
## usuario confirme o cancele (ver _on_popup_cantidad_confirmada). Un
## stack de 1 (o un ítem no apilable) se mueve directo, sin preguntar.
func recibir_desde(origen_fuente: FuenteObjetos, origen_grilla: GrillaObjetos, item: DatosItem) -> void:
	if self == origen_grilla:
		return
	if fuente_grilla == null:
		return
	if item.quantity > 1:
		_pendiente_origen_fuente = origen_fuente
		_pendiente_origen_grilla = origen_grilla
		_pendiente_item = item
		_popup_cantidad.abrir(item.quantity)
		return
	_transferir(origen_fuente, origen_grilla, item, item.quantity)


func _on_popup_cantidad_confirmada(cantidad: int) -> void:
	_transferir(_pendiente_origen_fuente, _pendiente_origen_grilla, _pendiente_item, cantidad)
	_limpiar_pendiente()


func _limpiar_pendiente() -> void:
	_pendiente_origen_fuente = null
	_pendiente_origen_grilla = null
	_pendiente_item = null


## El ButtonGroup (ver .tscn) ya se encarga del look de "tab activa" —
## acá solo hace falta guardar el tipo elegido y reconstruir filtrado.
func _seleccionar_filtro(tipo: Enums.Inventario.TipoItem) -> void:
	_filtro_categoria_actual = tipo
	notificar_cambio()


func _on_orden_seleccionado(indice: int) -> void:
	_orden_actual = indice as OrdenItems
	notificar_cambio()


## sort_custom() en el lugar — [items] ya es una copia propia de
## notificar_cambio(), nunca la lista real de la fuente. Categoría ordena
## por type_equippable_descripcion (el SLOT real — casco, anillo, arma...
## pedido explícito del usuario: "la categoria no es que sea equipable, la
## categoria es el Enums.Inventario.TipoItemEquipable"), no por el TipoItem
## genérico. Los ítems sin slot (NINGUNO — consumibles, recursos, misión)
## van SIEMPRE al final, pedido del usuario: "los recursos van al final",
## sin importar la dirección asc/desc; dentro de cada grupo (con o sin
## slot), empate por nombre para no dejar el orden interno al azar.
func _ordenar(items: Array) -> void:
	match _orden_actual:
		OrdenItems.CATEGORIA_ASC:
			items.sort_custom(func(a: DatosItem, b: DatosItem) -> bool: return _comparar_categoria(a, b, true))
		OrdenItems.CATEGORIA_DESC:
			items.sort_custom(func(a: DatosItem, b: DatosItem) -> bool: return _comparar_categoria(a, b, false))
		OrdenItems.NOMBRE_ASC:
			items.sort_custom(func(a: DatosItem, b: DatosItem) -> bool: return a.name < b.name)
		OrdenItems.NOMBRE_DESC:
			items.sort_custom(func(a: DatosItem, b: DatosItem) -> bool: return a.name > b.name)


func _comparar_categoria(a: DatosItem, b: DatosItem, ascendente: bool) -> bool:
	var sin_slot := Enums.Inventario.TipoItemEquipable.NINGUNO
	var a_sin_slot := a.type_equippable == sin_slot
	var b_sin_slot := b.type_equippable == sin_slot
	if a_sin_slot != b_sin_slot:
		return b_sin_slot
	if a.type_equippable_descripcion == b.type_equippable_descripcion:
		return a.name < b.name
	if ascendente:
		return a.type_equippable_descripcion < b.type_equippable_descripcion
	return a.type_equippable_descripcion > b.type_equippable_descripcion


## move_child() a índice 0 (izquierda, en el HBoxContainer que las
## contiene) o de vuelta al final (derecha) — ver scroll_a_la_izquierda.
func _aplicar_orden_scroll() -> void:
	var padre := _barra_desplazamiento.get_parent()
	if scroll_a_la_izquierda:
		padre.move_child(_barra_desplazamiento, 0)
	else:
		padre.move_child(_barra_desplazamiento, padre.get_child_count() - 1)


## Mueve de verdad "cantidad" unidades. Si es el stack ENTERO (cantidad >=
## item.quantity) usa agregar()/quitar() — mueve la referencia tal cual,
## igual que siempre (más barato, y preserva la identidad del ítem: varias
## pruebas ya dependen de que sea "la MISMA instancia"). Si es PARCIAL usa
## las variantes _cantidad (ver FuenteObjetos, duplican del lado de
## "agregar" para no tocar el resto que se queda en el origen).
func _transferir(origen_fuente: FuenteObjetos, origen_grilla: GrillaObjetos, item: DatosItem, cantidad: int) -> void:
	var mover_todo := cantidad >= item.quantity
	var agregado := fuente_grilla.agregar(item) if mover_todo else fuente_grilla.agregar_cantidad(item, cantidad)
	if not agregado:
		return
	if origen_fuente:
		if mover_todo:
			origen_fuente.quitar(item)
		else:
			origen_fuente.quitar_cantidad(item, cantidad)

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
