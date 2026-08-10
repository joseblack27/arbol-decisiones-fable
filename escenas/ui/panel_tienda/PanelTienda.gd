extends Control
class_name PanelTienda
## Pantalla completa de comercio con un NPC: mercancía del comerciante a la
## izquierda, inventario propio a la derecha, detalle del ítem elegido al
## centro (ícono, descripción, precio, cantidad) con un único botón de
## acción que compra o vende según de qué lado se tocó el ítem. Se
## autosuscribe a BusEventos.tienda_solicitada (mismo patrón que
## PanelDialogo con dialogo_solicitado) — se abre desde una opción de
## diálogo con action ABRIR_TIENDA, GestorUI.Modo.DIALOGO ya está activo
## cuando esto pasa (ver PanelDialogo._elegir_opcion), así que este panel
## no necesita tocar el modo al abrir, solo al cerrar de verdad.

const _SLOT_ITEM_SCENE := preload("res://escenas/ui/panel_os/paneles/inventario/SlotItem.tscn")
const _ICONO_COMPRAR := preload("res://assets/iconos/buttons/dialogo/flecha_derecha.png")
const _ICONO_VENDER := preload("res://assets/iconos/buttons/dialogo/flecha_izquierda.png")
const _COLOR_SLOT_NORMAL := Color(1, 1, 1, 1)
## > 1.0 en los 3 canales: no es un tinte de color, es sobre-brillo (blanco
## puro multiplicado por más de 1), ahí es donde se ve "brillante" en vez
## de simplemente más claro.
const _COLOR_SLOT_SELECCIONADO := Color(1.4, 1.4, 1.4, 1)

## Comprar es, del lado de la UI, un bucle de N llamadas individuales a
## TiendaComponente.comprar_item() — esa API no tiene parámetro de cantidad
## (compra de a un ItemTienda por vez, ver TiendaComponente), así que cada
## unidad es su propia RPC. Tope bajo a propósito para no spamear la red.
## Vender sí acepta "cantidad" en una sola llamada (vender_item), no
## necesita este tope — el suyo es simplemente cuánto se tiene.
const _TOPE_CANTIDAD_COMPRA := 10

## Mismas 4 categorías que ya filtra PanelInventario (Todos/Equipables/
## Consumibles/Recursos, en ese orden — ver TabsFiltro en su .tscn) —
## acá se repiten los botones (uno por grilla) en vez de reusar FlujoItems/
## BotonFiltro.gd: esos dos asumen un único ítem por slot y un solo
## owner._on_slot_clicked fijo, pero la grilla del comerciante necesita
## además el ItemTienda (precio) de cada slot, no solo el DatosItem.
const _TIPOS_FILTRO := [
	Enums.Inventario.TipoItem.TODOS,
	Enums.Inventario.TipoItem.EQUIPABLE,
	Enums.Inventario.TipoItem.CONSUMIBLE,
	Enums.Inventario.TipoItem.RECURSO,
]

@onready var _texto_creditos: Label = %Creditos
@onready var _boton_salir: Button = %BotonSalir
@onready var _titulo_comerciante: Label = %TituloComerciante
@onready var _grilla_comerciante: FlowContainer = %GrillaComerciante
@onready var _grilla_jugador: FlowContainer = %GrillaJugador
@onready var _botones_filtro_comerciante: Array[Button] = [%FiltroComTodos, %FiltroComEquipos, %FiltroComConsumibles, %FiltroComRecursos]
@onready var _botones_filtro_jugador: Array[Button] = [%FiltroInvTodos, %FiltroInvEquipos, %FiltroInvConsumibles, %FiltroInvRecursos]

@onready var _panel_detalle: Control = %PanelDetalle
@onready var _icono_item: TextureRect = %IconoItem
@onready var _nombre_item: Label = %NombreItem
@onready var _descripcion_item: RichTextLabel = %TextoDescripcion
@onready var _vbox_caracteristicas: VBoxContainer = %VBoxCaracteristicas
@onready var _valor_precio: Label = %ValorPrecio
@onready var _valor_cantidad: Label = %ValorCantidad
@onready var _boton_menos: Button = %BotonMenos
@onready var _boton_mas: Button = %BotonMas
@onready var _boton_accion: Button = %BotonAccion

var _creditos: CreditosComponente = null
var _datos_tienda: DatosTienda = null
var _filtro_comerciante: int = Enums.Inventario.TipoItem.TODOS
var _filtro_jugador: int = Enums.Inventario.TipoItem.TODOS

## "comprar" | "vender" | "" (nada elegido todavía) — decide qué hace
## _on_accion() y de dónde sale el precio unitario mostrado.
var _origen_seleccion: String = ""
var _item_tienda_actual: ItemTienda = null  ## válido solo si _origen_seleccion == "comprar"
var _item_jugador_actual: DatosItem = null  ## válido solo si _origen_seleccion == "vender"
var _cantidad_actual: int = 1
var _slot_seleccionado: SlotItem = null


func _ready() -> void:
	visible = false
	BusEventos.tienda_solicitada.connect(_abrir)
	_boton_salir.pressed.connect(_cerrar)
	_boton_menos.pressed.connect(_cambiar_cantidad.bind(-1))
	_boton_mas.pressed.connect(_cambiar_cantidad.bind(1))
	_boton_accion.pressed.connect(_on_accion)
	for i in _botones_filtro_comerciante.size():
		_botones_filtro_comerciante[i].pressed.connect(_on_filtro_comerciante_pressed.bind(_TIPOS_FILTRO[i]))
	for i in _botones_filtro_jugador.size():
		_botones_filtro_jugador[i].pressed.connect(_on_filtro_jugador_pressed.bind(_TIPOS_FILTRO[i]))


func _abrir(datos: DatosTienda, nombre_comerciante: String = "Comerciante") -> void:
	if datos == null:
		return
	_datos_tienda = datos
	_titulo_comerciante.text = nombre_comerciante
	_creditos = Utils.creditos_componente_local()
	# El eco de créditos llega en AMBOS sentidos (comprar los descuenta,
	# vender los suma, ver CreditosComponente) — reusarlo también para
	# refrescar la grilla del jugador cubre el caso en red (cliente que no
	# es servidor: la confirmación de ComponenteConfirmacionesRed llega
	# async, esta señal es la forma de enterarse de que ya se aplicó).
	if _creditos and not _creditos.creditos_cambiados.is_connected(_al_cambiar_creditos):
		_creditos.creditos_cambiados.connect(_al_cambiar_creditos)
	if not BusEventos.item_agregado.is_connected(_al_cambiar_inventario):
		BusEventos.item_agregado.connect(_al_cambiar_inventario)
	visible = true
	_limpiar_seleccion()
	# Arranca siempre en "Todos" — sin esto, reabrir la tienda con un filtro
	# angosto elegido la vez anterior (ej. "Recursos") ocultaría de entrada
	# ítems que sí están ahí, sin ningún indicio visual de por qué.
	_filtro_comerciante = Enums.Inventario.TipoItem.TODOS
	_filtro_jugador = Enums.Inventario.TipoItem.TODOS
	_botones_filtro_comerciante[0].button_pressed = true
	_botones_filtro_jugador[0].button_pressed = true
	_actualizar_creditos(_creditos.obtener_creditos() if _creditos else 0)
	_llenar_grilla_comerciante()
	_refrescar_grilla_jugador()


func _on_filtro_comerciante_pressed(tipo: int) -> void:
	_filtro_comerciante = tipo
	_filtrar_grilla(_grilla_comerciante, tipo)


func _on_filtro_jugador_pressed(tipo: int) -> void:
	_filtro_jugador = tipo
	_filtrar_grilla(_grilla_jugador, tipo)


func _filtrar_grilla(grilla: FlowContainer, tipo: int) -> void:
	for slot: SlotItem in grilla.get_children():
		slot.visible = tipo == Enums.Inventario.TipoItem.TODOS or (slot.item_data and slot.item_data.type == tipo)


## La mercancía del comerciante nunca cambia mientras el panel está abierto
## (items_en_venta no se agota al comprar, ver TiendaComponente._comprar_
## local) — a diferencia de _refrescar_grilla_jugador(), esta grilla se
## arma UNA sola vez, al abrir.
func _llenar_grilla_comerciante() -> void:
	_limpiar_grilla(_grilla_comerciante)
	for item_tienda: ItemTienda in _datos_tienda.items_en_venta:
		if item_tienda == null or item_tienda.item == null:
			continue
		var slot := _crear_slot(item_tienda.item)
		slot.slot_clicked.connect(_on_slot_comerciante_clicked.bind(item_tienda))
		_grilla_comerciante.add_child(slot)
	_filtrar_grilla(_grilla_comerciante, _filtro_comerciante)


## Reconstruye la grilla del jugador desde InventarioComponente.items (única
## fuente de verdad) — se llama al abrir y cada vez que el inventario puede
## haber cambiado (compra/venta propia, loot recibido de otra fuente
## mientras el panel sigue abierto).
func _refrescar_grilla_jugador() -> void:
	var inventario := Utils.inventario_componente_local()
	_limpiar_grilla(_grilla_jugador)
	if inventario == null:
		return
	var slot_seleccionado_nuevo: SlotItem = null
	for item: DatosItem in inventario.items:
		var slot := _crear_slot(item)
		slot.slot_clicked.connect(_on_slot_jugador_clicked.bind(item))
		_grilla_jugador.add_child(slot)
		if _origen_seleccion == "vender" and item == _item_jugador_actual:
			slot_seleccionado_nuevo = slot
	# La grilla se reconstruye ENTERA acá — el ítem elegido pudo agotarse
	# (se vendió del todo: sin este chequeo, el detalle se quedaba
	# mostrando un ítem que ya no está, con un botón Vender que fallaría en
	# silencio) o seguir en el inventario pero en un SlotItem nuevo (sin
	# esto, el resaltado quedaba en el nodo viejo ya destruido en
	# vez de seguir al ítem — ej. al recibir loot de otra fuente mientras
	# hay algo elegido para vender).
	if _origen_seleccion == "vender":
		if slot_seleccionado_nuevo:
			_marcar_seleccionado(slot_seleccionado_nuevo)
		else:
			_limpiar_seleccion()
	_filtrar_grilla(_grilla_jugador, _filtro_jugador)


func _crear_slot(item: DatosItem) -> SlotItem:
	var slot: SlotItem = _SLOT_ITEM_SCENE.instantiate()
	slot.item_data = item
	return slot


## remove_child() (desvincula DE INMEDIATO) + queue_free() (destruye recién
## en un momento seguro) — nunca uno solo de los dos. Con queue_free() solo,
## una compra de cantidad > 1 dispara varios refrescos seguidos dentro del
## MISMO fotograma (uno por cada crédito descontado, vía _al_cambiar_
## creditos, más el explícito al final de _on_accion) y los hijos viejos
## seguían en get_children() cuando ya se estaban agregando los nuevos —
## mismo bug ya visto en PanelDialogo._limpiar_opciones() (ver memoria
## queue-free-vs-remove-child-godot).
func _limpiar_grilla(grilla: FlowContainer) -> void:
	for hijo in grilla.get_children():
		grilla.remove_child(hijo)
		hijo.queue_free()


func _on_slot_comerciante_clicked(slot: SlotItem, item_tienda: ItemTienda) -> void:
	_origen_seleccion = "comprar"
	_item_tienda_actual = item_tienda
	_item_jugador_actual = null
	_cantidad_actual = 1
	_marcar_seleccionado(slot)
	_mostrar_detalle(item_tienda.item)


func _on_slot_jugador_clicked(slot: SlotItem, item: DatosItem) -> void:
	_origen_seleccion = "vender"
	_item_jugador_actual = item
	_item_tienda_actual = null
	_cantidad_actual = 1
	_marcar_seleccionado(slot)
	_mostrar_detalle(item)


func _marcar_seleccionado(slot: SlotItem) -> void:
	_resaltar_slot(_slot_seleccionado, false)
	_slot_seleccionado = slot
	_resaltar_slot(slot, true)


## slot puede ser un nodo ya destinado a queue_free() (la grilla se
## reconstruye entera en cada refresco) — tocarle el modulate antes de que
## el free() diferido se ejecute de verdad no rompe nada, solo no tiene
## efecto visible.
func _resaltar_slot(slot: SlotItem, resaltado: bool) -> void:
	if slot == null:
		return
	slot.modulate = _COLOR_SLOT_SELECCIONADO if resaltado else _COLOR_SLOT_NORMAL


func _mostrar_detalle(item: DatosItem) -> void:
	# modulate (no visible=false): el panel central sigue ocupando su lugar
	# fijo en HBoxColumnas — si se lo sacara del layout con visible=false,
	# las otras dos columnas se estirarían a llenar el hueco (HBoxContainer
	# solo reparte espacio entre hijos VISIBLES), justo lo que no se quiere.
	_panel_detalle.modulate.a = 1.0
	_icono_item.texture = item.icon
	_nombre_item.text = item.name
	_descripcion_item.text = item.description
	# Mismos bonos que ya muestra PanelInventario para un equipable (ver
	# Utils.llenar_caracteristicas_item) — un ítem sin bonos ni curación
	# simplemente no agrega ninguna fila.
	Utils.llenar_caracteristicas_item(_vbox_caracteristicas, item)
	_actualizar_precio_y_boton()


## Precio unitario del ítem elegido según de qué lado salió: comprar usa el
## precio fijo del NPC (ItemTienda.precio); vender es una VISTA PREVIA del
## mismo cálculo que hace el servidor (ver TiendaComponente._vender_local,
## PORCENTAJE_VENTA) — el pago real siempre lo decide el servidor con su
## propia copia de DatosItem.valor, esto solo evita mostrarle al jugador un
## número que no va a coincidir.
func _precio_unitario() -> int:
	if _origen_seleccion == "comprar" and _item_tienda_actual:
		return _item_tienda_actual.precio
	if _origen_seleccion == "vender" and _item_jugador_actual:
		return int(_item_jugador_actual.valor * TiendaComponente.PORCENTAJE_VENTA)
	return 0


func _cambiar_cantidad(delta: int) -> void:
	var tope := _tope_cantidad()
	_cantidad_actual = clampi(_cantidad_actual + delta, 1, max(1, tope))
	_actualizar_precio_y_boton()


func _tope_cantidad() -> int:
	if _origen_seleccion == "comprar":
		return _TOPE_CANTIDAD_COMPRA
	if _origen_seleccion == "vender" and _item_jugador_actual:
		return _item_jugador_actual.quantity
	return 1


func _actualizar_precio_y_boton() -> void:
	_valor_cantidad.text = str(_cantidad_actual)
	var unitario := _precio_unitario()
	_valor_precio.text = "%d créditos" % (unitario * _cantidad_actual)
	var vendible := _origen_seleccion != "vender" or (_item_jugador_actual and _item_jugador_actual.valor > 0)
	_boton_accion.disabled = _origen_seleccion == "" or not vendible
	if _origen_seleccion == "comprar":
		_boton_accion.text = "Comprar"
		_boton_accion.icon = _ICONO_COMPRAR
	elif _origen_seleccion == "vender":
		_boton_accion.text = "Vender" if vendible else "No se vende"
		_boton_accion.icon = _ICONO_VENDER
	else:
		_boton_accion.text = "—"
		_boton_accion.icon = null


func _on_accion() -> void:
	var tienda := Utils.tienda_componente_local()
	if tienda == null:
		return
	if _origen_seleccion == "comprar" and _item_tienda_actual:
		for _i in _cantidad_actual:
			tienda.comprar_item(_item_tienda_actual)
	elif _origen_seleccion == "vender" and _item_jugador_actual:
		tienda.vender_item(_item_jugador_actual, _cantidad_actual)
	# Cubre el caso local/servidor (sincrónico, ya aplicado ahora mismo);
	# el caso cliente-en-red se refresca solo, vía _al_cambiar_creditos.
	_refrescar_grilla_jugador()


func _limpiar_seleccion() -> void:
	_origen_seleccion = ""
	_item_tienda_actual = null
	_item_jugador_actual = null
	_cantidad_actual = 1
	_resaltar_slot(_slot_seleccionado, false)
	_slot_seleccionado = null
	_panel_detalle.modulate.a = 0.0
	_icono_item.texture = null
	_nombre_item.text = "Seleccioná un ítem"
	_descripcion_item.text = ""
	Utils.llenar_caracteristicas_item(_vbox_caracteristicas, null)
	_valor_cantidad.text = "1"
	_valor_precio.text = "-"
	_boton_accion.text = "—"
	_boton_accion.icon = null
	_boton_accion.disabled = true


func _al_cambiar_creditos(nuevo: int) -> void:
	_actualizar_creditos(nuevo)
	_refrescar_grilla_jugador()


func _al_cambiar_inventario(_item: DatosItem, _cantidad: int) -> void:
	if is_visible_in_tree():
		_refrescar_grilla_jugador()


func _actualizar_creditos(nuevo: int) -> void:
	_texto_creditos.text = "%d créditos" % nuevo


func _cerrar() -> void:
	visible = false
	_limpiar_seleccion()
	GestorUI.cerrar_dialogo()
