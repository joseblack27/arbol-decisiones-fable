extends Control
class_name PanelCofre
## Panel para gestionar el contenido de un cofre del mundo: grilla del
## cofre a la izquierda, detalle del ítem tocado al centro, inventario
## propio a la derecha — se arrastra libremente entre las dos grillas,
## pedido del usuario: "recoger y dejar los objetos del cofre e inventario
## entre ellos". Las dos grillas son GrillaObjetos (ver ese archivo):
## genéricas, sin ninguna lógica de equipar ni reemplazar por tipo — acá
## un arrastre siempre es "sale de una colección, entra a la otra", pedido
## explícito del usuario ("el inventario que se muestra acá no debe tener
## la misma funcionalidad que el inventario del OS").
## Ocupa toda la pantalla para el layout (igual que PanelTienda), pero SIN
## fondo opaco (ver Fondo.color en el .tscn, alpha 0): a diferencia de una
## tienda, acá tiene sentido seguir viendo el mundo (el cofre, el
## personaje) detrás de las grillas — pedido explícito del usuario
## ("quiero ver lo de atras tambien").
## Se autosuscribe a BusEventos.cofre_solicitado (mismo patrón que
## PanelDialogo/PanelTienda) — Cofre.interactuar() la emite y además activa
## GestorUI.Modo.DIALOGO (mismo modo que ya usa PanelTienda: "hay un panel
## modal abierto", bloquea moverse/pelear mientras está abierto).
## Sin header propio (pedido del usuario: "los paneles lleguen hasta
## arriba") — el nombre real del cofre se muestra en GrillaCofre.titulo, y
## cada grilla trae su propio botón de cerrar (GrillaObjetos.
## mostrar_boton_cerrar) que hace lo mismo que el "Salir" de antes.
##
## También hace de panel para el almacén compartido del leñador (ver
## GestorLenador.gd/AlmacenLenador.gd) — pedido explícito del usuario: "usa
## la del cofre del jugador, allí pondrás los recursos del leñador", en vez
## de mantener PanelAlmacenLenador (una lista aparte, sin arrastrar,
## eliminada). Mismo panel, misma sensación de arrastre — la única
## diferencia real es la fuente: GrillaCofre pasa a poblarse con
## FuenteAlmacenLenador (ver ese archivo) en vez de FuenteCofre, que
## bloquea agregar()/agregar_cantidad() (confirmado con el usuario: "solo
## retirar", nadie deposita ahí arrastrando, solo el leñador) y enruta
## quitar()/quitar_cantidad() por GestorLenador.pedir_retirar() (validado
## por el servidor, async en red — a diferencia de un cofre por jugador,
## sin RPC). _modo distingue cuál de las tres fuentes está abierta ahora
## mismo, para que _tomar_todo()/el refresco en caliente actúen sobre la
## correcta.
##
## Mismo tratamiento para el almacén compartido del minero (ver
## GestorMinero.gd/AlmacenMinero.gd/FuenteAlmacenMinero.gd) — un tercer modo
## más en el mismo panel, en vez de un panel aparte.

@onready var _grilla_cofre: GrillaObjetos = %GrillaCofre
@onready var _grilla_jugador: GrillaObjetos = %GrillaJugador

## Columna central de detalle — mismo diseño visual que el detalle de
## PanelInventario (nombre, ícono, tipo/cantidad, descripción,
## características), pedido explícito del usuario, pero SIN los botones de
## acción (Usar/Equipar/Barra rápida/Soltar): acá la única forma de mover
## un ítem es arrastrarlo, esto es solo información.
@onready var _panel_detalle: Panel = %PanelDetalle
@onready var _icono_item: TextureRect = %IconoItem
@onready var _nombre_item: Label = %NombreItem
@onready var _valor_tipo: Label = %ValorTipo
@onready var _valor_cantidad: Label = %ValorCantidad
@onready var _descripcion_item: RichTextLabel = %TextoDescripcion
@onready var _vbox_caracteristicas: VBoxContainer = %VBoxCaracteristicas

var _id_cofre: String = ""
## Qué fuente está abierta ahora mismo (ver _abrir/_abrir_almacen/
## _abrir_almacen_minero) — decide qué fuente usa _tomar_todo() y cuál de
## los refrescos en caliente (GestorLenador/GestorMinero.almacen_actualizado)
## debe tocar esta grilla ahora mismo.
enum Modo { COFRE, ALMACEN_LENADOR, ALMACEN_MINERO }
var _modo: Modo = Modo.COFRE


func _ready() -> void:
	visible = false
	BusEventos.cofre_solicitado.connect(_abrir)
	BusEventos.almacen_lenador_solicitado.connect(_abrir_almacen)
	BusEventos.almacen_minero_solicitado.connect(_abrir_almacen_minero)
	_grilla_cofre.cerrar_solicitado.connect(_cerrar)
	_grilla_jugador.cerrar_solicitado.connect(_cerrar)
	_grilla_cofre.tomar_todo_solicitado.connect(_tomar_todo)
	_grilla_cofre.item_tocado.connect(_mostrar_detalle)
	_grilla_jugador.item_tocado.connect(_mostrar_detalle)
	# Pedido del usuario: "el doble-tap para transferencia rápida" — cada
	# grilla manda al doble-tap a la OTRA (ver CasillaObjeto._transferencia
	# _rapida/GrillaObjetos.grilla_destino_rapida). Fijo (no cambia entre
	# aperturas, %GrillaCofre/%GrillaJugador son siempre los mismos nodos).
	_grilla_cofre.grilla_destino_rapida = _grilla_jugador
	_grilla_jugador.grilla_destino_rapida = _grilla_cofre
	if not BusEventos.item_agregado.is_connected(_al_cambiar_inventario):
		BusEventos.item_agregado.connect(_al_cambiar_inventario)
	GestorLenador.almacen_actualizado.connect(_al_cambiar_almacen)
	GestorMinero.almacen_actualizado.connect(_al_cambiar_almacen_minero)


func _abrir(id_cofre: String, nombre_cofre: String = "Cofre") -> void:
	_modo = Modo.COFRE
	_id_cofre = id_cofre
	_grilla_cofre.titulo = nombre_cofre
	_grilla_cofre.texto_vacio = "El cofre está vacío"
	# Por si la apertura anterior fue el almacén (ver _abrir_almacen, que los
	# oculta) — %GrillaCofre es el MISMO nodo entre una apertura y la
	# siguiente, sin esto quedarían apagados también para un cofre normal.
	_grilla_cofre.mostrar_filtro_categorias = true
	_grilla_cofre.mostrar_ordenar = true
	_grilla_cofre.mostrar_busqueda = true
	visible = true
	_limpiar_detalle()

	var cofres := Utils.cofres_componente_local()
	var fuente_cofre := FuenteCofre.new()
	fuente_cofre.cofres = cofres
	fuente_cofre.id_cofre = id_cofre
	_grilla_cofre.poblar(
		func() -> Array: return cofres.obtener_contenido(_id_cofre) if cofres else [],
		fuente_cofre
	)
	_poblar_grilla_jugador()


## Almacén compartido del leñador (ver GestorLenador.gd) en vez de un cofre
## por jugador — mismas dos grillas, misma sensación de arrastre, pero
## GrillaCofre pasa a alimentarse de _obtener_items_almacen()/
## FuenteAlmacenLenador (solo retiro, ver ese archivo) en vez de
## CofresComponente/FuenteCofre.
func _abrir_almacen() -> void:
	_modo = Modo.ALMACEN_LENADOR
	_id_cofre = ""
	_grilla_cofre.titulo = "Almacén del Leñador"
	_grilla_cofre.texto_vacio = "El almacén está vacío"
	# Pedido del usuario: sin filtro de categorías, orden ni búsqueda acá —
	# a diferencia de un cofre con ítems variados, el almacén solo tiene
	# recursos del leñador, pocos tipos distintos, no hace falta.
	_grilla_cofre.mostrar_filtro_categorias = false
	_grilla_cofre.mostrar_ordenar = false
	_grilla_cofre.mostrar_busqueda = false
	visible = true
	_limpiar_detalle()

	_grilla_cofre.poblar(_obtener_items_almacen, FuenteAlmacenLenador.new())
	_poblar_grilla_jugador()


## Almacén compartido del minero (ver GestorMinero.gd) — mismo tratamiento
## que _abrir_almacen(), fuente distinta.
func _abrir_almacen_minero() -> void:
	_modo = Modo.ALMACEN_MINERO
	_id_cofre = ""
	_grilla_cofre.titulo = "Almacén del Minero"
	_grilla_cofre.texto_vacio = "El almacén está vacío"
	_grilla_cofre.mostrar_filtro_categorias = false
	_grilla_cofre.mostrar_ordenar = false
	_grilla_cofre.mostrar_busqueda = false
	visible = true
	_limpiar_detalle()

	_grilla_cofre.poblar(_obtener_items_almacen_minero, FuenteAlmacenMinero.new())
	_poblar_grilla_jugador()


func _poblar_grilla_jugador() -> void:
	_grilla_jugador.poblar(
		func() -> Array:
			var inventario := Utils.inventario_componente_local()
			return inventario.items if inventario else [],
		FuenteInventario.new()
	)


## GestorLenador.almacen_replicado es un Dictionary (ruta -> cantidad), no
## una Array[DatosItem] — arma una lista fresca por refresco. .duplicate()
## antes de tocar .quantity: el DatosItem que devuelve load() es el MISMO
## recurso CACHEADO cada vez que se pide esa ruta, mutar su .quantity
## directo corrompería cualquier otro lugar del juego que cargue ese mismo
## .tres (mismo motivo/mismo campo id_recurso que ya usa CofresComponente.
## agregar_cantidad() — Resource.duplicate() no conserva resource_path, ver
## FuenteAlmacenLenador).
func _obtener_items_almacen() -> Array:
	var resultado: Array[DatosItem] = []
	for ruta_item: String in GestorLenador.almacen_replicado.keys():
		var cantidad: int = GestorLenador.almacen_replicado[ruta_item]
		if cantidad <= 0:
			continue
		var original := load(ruta_item) as DatosItem
		if original == null:
			continue
		var item := original.duplicate() as DatosItem
		item.quantity = cantidad
		item.id_recurso = ruta_item
		resultado.append(item)
	return resultado


## Mismo criterio que _obtener_items_almacen(), leyendo GestorMinero en vez
## de GestorLenador.
func _obtener_items_almacen_minero() -> Array:
	var resultado: Array[DatosItem] = []
	for ruta_item: String in GestorMinero.almacen_replicado.keys():
		var cantidad: int = GestorMinero.almacen_replicado[ruta_item]
		if cantidad <= 0:
			continue
		var original := load(ruta_item) as DatosItem
		if original == null:
			continue
		var item := original.duplicate() as DatosItem
		item.quantity = cantidad
		item.id_recurso = ruta_item
		resultado.append(item)
	return resultado


## GestorLenador.almacen_actualizado dispara por depósito del leñador,
## retiro propio o eco de red — mismo criterio que _al_cambiar_inventario
## para la grilla del jugador: solo refresca si el almacén es lo que está
## abierto AHORA, para no pisar una vista de cofre por jugador (u otro
## almacén) que coincidiera en estar visible.
func _al_cambiar_almacen() -> void:
	if _modo == Modo.ALMACEN_LENADOR and is_visible_in_tree():
		_grilla_cofre.notificar_cambio()


## Mismo criterio que _al_cambiar_almacen(), para GestorMinero.
func _al_cambiar_almacen_minero() -> void:
	if _modo == Modo.ALMACEN_MINERO and is_visible_in_tree():
		_grilla_cofre.notificar_cambio()


## Pública: quien cambie el inventario desde AFUERA de un arrastre (loot
## recibido mientras el panel está abierto, ver _al_cambiar_inventario) la
## llama para refrescar la columna de la derecha.
func refrescar_inventario() -> void:
	_grilla_jugador.notificar_cambio()


func _al_cambiar_inventario(_item: DatosItem, _cantidad: int) -> void:
	if is_visible_in_tree():
		refrescar_inventario()


## Mismos datos y mismo helper compartido (Utils.llenar_caracteristicas_
## item) que PanelTienda/PanelInventario. modulate (no visible=false): el
## panel central sigue ocupando su lugar fijo en HBoxColumnas — si se lo
## sacara del layout con visible=false, las dos grillas se estirarían a
## llenar el hueco cada vez que se toca/destoca un ítem, mismo criterio
## que PanelTienda._mostrar_detalle/_limpiar_seleccion.
func _mostrar_detalle(item: DatosItem) -> void:
	_panel_detalle.modulate.a = 1.0
	_icono_item.texture = item.icon
	_nombre_item.text = item.name
	_valor_tipo.text = item.type_descripcion
	_valor_cantidad.text = str(item.quantity)
	_descripcion_item.text = item.description
	Utils.llenar_caracteristicas_item(_vbox_caracteristicas, item)


## Pedido del usuario: "si no hay ningun objeto seleccionado, sea invisible
## este panel" — arranca así al abrir el cofre, y vuelve a este estado si
## hiciera falta "deseleccionar" en el futuro (hoy no hay forma de hacerlo,
## solo queda invisible hasta el primer toque).
func _limpiar_detalle() -> void:
	_panel_detalle.modulate.a = 0.0
	_icono_item.texture = null
	_nombre_item.text = "Tocá un ítem para ver los detalles"
	_valor_tipo.text = "-"
	_valor_cantidad.text = "-"
	_descripcion_item.text = ""
	Utils.llenar_caracteristicas_item(_vbox_caracteristicas, null)


## Pedido del usuario: "un botón de 'Tomar todo' que solo se muestre en el
## inventario del cofre, y pase todo al inventario" (ver GrillaObjetos.
## mostrar_boton_tomar_todo, activo solo en _grilla_cofre). Mueve cada
## ítem con agregar()/quitar() (referencia entera, sin PopupCantidad —
## "todo" no tiene nada que preguntar) usando los fuente_grilla que ya
## tienen las dos grillas — genérico a propósito (ver GrillaObjetos.
## obtener_items_actuales): funciona igual de cofre por jugador que de
## cualquier almacén compartido (ver _modo), sin importar cuál está abierto.
## .duplicate() de la lista: para un cofre, obtener_items_actuales()
## devuelve la MISMA referencia mutable que fuente_grilla.quitar() va a ir
## vaciando en el camino, recorrerla sin copiar saltearía ítems (para el
## almacén no hace falta, pero tampoco molesta).
func _tomar_todo() -> void:
	if _grilla_cofre.fuente_grilla == null or _grilla_jugador.fuente_grilla == null:
		return
	var contenido: Array = _grilla_cofre.obtener_items_actuales().duplicate()
	for item in contenido:
		if _grilla_jugador.fuente_grilla.agregar(item):
			_grilla_cofre.fuente_grilla.quitar(item)
	_grilla_cofre.notificar_cambio()
	_grilla_jugador.notificar_cambio()


func _cerrar() -> void:
	visible = false
	_id_cofre = ""
	GestorUI.cerrar_dialogo()
