extends Control
class_name PanelInventario

@export var slot_scene: PackedScene
@export var items: Array[DatosItem] = []
@export var slot_size := Vector2(48, 48)
@export var min_spacing := 4

@onready var flow: FlujoItems = $Margin/HBox/PanelItems/MarginContainer/VBoxItems/MarginContainer/ScrollContainer/FlujoItems

@onready var item_name         := $Margin/HBox/PanelDetalle/MarginContainer/VBoxDetalle/ContenidoDetalle/HeaderNombre/NombreItem
## A partir de IconoItem, todo vive dentro de ScrollBody (ver PanelInventario
## .tscn) — pedido explícito del usuario: con el nombre en 2 líneas MÁS un
## conjunto con varios tramos, el contenido podía necesitar más alto que el
## espacio fijo de la columna de detalle, y nada de eso tenía cómo
## desplazarse (la descripción, con fit_content=true, tampoco se desplaza
## sola — depende de que algo de afuera le haga lugar). HeaderNombre se
## queda AFUERA del scroll a propósito (título + botón cerrar siempre
## visibles arriba).
@onready var item_icon         := $Margin/HBox/PanelDetalle/MarginContainer/VBoxDetalle/ContenidoDetalle/ScrollBody/VBoxScrollBody/IconoItem
@onready var type_value        := $Margin/HBox/PanelDetalle/MarginContainer/VBoxDetalle/ContenidoDetalle/ScrollBody/VBoxScrollBody/MarginContainer/RejillaInfo/ValorTipo
@onready var qty_value         := $Margin/HBox/PanelDetalle/MarginContainer/VBoxDetalle/ContenidoDetalle/ScrollBody/VBoxScrollBody/MarginContainer/RejillaInfo/ValorCantidad
## Fila "Conjunto:" en la misma grilla que Tipo/Cantidad — pedido explícito
## del usuario: si la pieza pertenece a un conjunto, su nombre aparece ACÁ
## arriba (no solo mezclado con los tramos de bono más abajo). Oculta por
## defecto en el .tscn; _update_details()/_clear_details() la muestran solo
## cuando item.conjunto != null.
@onready var conjunto_label    := $Margin/HBox/PanelDetalle/MarginContainer/VBoxDetalle/ContenidoDetalle/ScrollBody/VBoxScrollBody/MarginContainer/RejillaInfo/ConjuntoLabel
@onready var conjunto_value    := $Margin/HBox/PanelDetalle/MarginContainer/VBoxDetalle/ContenidoDetalle/ScrollBody/VBoxScrollBody/MarginContainer/RejillaInfo/ValorConjunto
@onready var description_text  := $Margin/HBox/PanelDetalle/MarginContainer/VBoxDetalle/ContenidoDetalle/ScrollBody/VBoxScrollBody/MarginContainer2/VBoxContainer/TextoDescripcion
@onready var vbox_caracteristicas: VBoxContainer = $Margin/HBox/PanelDetalle/MarginContainer/VBoxDetalle/ContenidoDetalle/ScrollBody/VBoxScrollBody/VBoxCaracteristicas

@onready var close_button      := $Margin/HBox/PanelDetalle/MarginContainer/VBoxDetalle/ContenidoDetalle/HeaderNombre/BotonCerrar
## Lo que se muestra/oculta según haya algo seleccionado o no — el PANEL en
## sí (PanelDetalle) ya no se oculta más: la columna "Detalles del Objeto"
## siempre está ahí, como Mochila/Inventario y Equipamiento Activo; lo que
## aparece y desaparece es solo el contenido específico del ítem elegido,
## dejando el espacio realmente VACÍO (sin nombre, sin ícono, nada) cuando
## no hay selección, en vez de mostrar placeholders tipo "No item" / "-".
@onready var detail_panel_margin := $Margin/HBox/PanelDetalle/MarginContainer/VBoxDetalle/ContenidoDetalle

## Créditos del jugador, visibles en PanelDetalle mientras no hay ningún
## ítem seleccionado (mismo espacio que ocupa ContenidoDetalle) — pedido
## del usuario: "que el detalle del item se dibuje por encima de los
## creditos". En vez de superponerlos y depender del orden de dibujado, se
## ocultan mutuamente (ver _on_slot_clicked/_on_close_button): mismo
## resultado visual, sin arriesgar que el texto de los créditos se vea
## atravesando el detalle.
@onready var _label_creditos: Label = $Margin/HBox/PanelDetalle/MarginCreditos/Creditos
var _creditos: CreditosComponente = null

## Pedido explícito del usuario: el botón de acción se queda FIJO abajo (no
## adentro de ScrollBody) — solo el contenido de arriba (ícono, descripción,
## características/conjunto) se desplaza.
@onready var action_button     := $Margin/HBox/PanelDetalle/MarginContainer/VBoxDetalle/ContenidoDetalle/BotonAccion
@onready var main_action_panel: PanelContainer = $Margin/HBox/PanelDetalle/PanelAccionPrincipal
@onready var use_action_button   := $Margin/HBox/PanelDetalle/PanelAccionPrincipal/MarginContainer/VBoxContainer/BotonUsar
@onready var barra_rapida_button := $Margin/HBox/PanelDetalle/PanelAccionPrincipal/MarginContainer/VBoxContainer/BotonBarraRapida
@onready var equip_action_button := $Margin/HBox/PanelDetalle/PanelAccionPrincipal/MarginContainer/VBoxContainer/BotonEquipar
@onready var drop_action_button  := $Margin/HBox/PanelDetalle/PanelAccionPrincipal/MarginContainer/VBoxContainer/BotonSoltar

@onready var all_filter_button:        Button = $Margin/HBox/PanelItems/MarginContainer/VBoxItems/TabsFiltro/BotonTodos
@onready var equipments_filter_button: Button = $Margin/HBox/PanelItems/MarginContainer/VBoxItems/TabsFiltro/BotonEquipables
@onready var consumables_filter_button: Button = $Margin/HBox/PanelItems/MarginContainer/VBoxItems/TabsFiltro/BotonConsumibles
@onready var resources_filter_button:  Button = $Margin/HBox/PanelItems/MarginContainer/VBoxItems/TabsFiltro/BotonRecursos

@onready var equipment_panel: Panel = $Margin/HBox/PanelEquipamiento
@onready var equip_slot_weapon:  EquipoSlot = $Margin/HBox/PanelEquipamiento/MarginContainer/VBoxEquipamiento/VBoxIzquierda/ColArma/SlotArma
@onready var equip_slot_shield:  EquipoSlot = $Margin/HBox/PanelEquipamiento/MarginContainer/VBoxEquipamiento/VBoxDerecha/ColEscudo/SlotEscudo
@onready var equip_slot_helmet:  EquipoSlot = $Margin/HBox/PanelEquipamiento/MarginContainer/VBoxEquipamiento/VBoxIzquierda/ColCasco/SlotCasco
@onready var equip_slot_neck:    EquipoSlot = $Margin/HBox/PanelEquipamiento/MarginContainer/VBoxEquipamiento/VBoxDerecha/ColAmuleto/SlotCuello
@onready var equip_slot_body:    EquipoSlot = $Margin/HBox/PanelEquipamiento/MarginContainer/VBoxEquipamiento/VBoxIzquierda/ColCuerpo/SlotPecho
@onready var equip_slot_ring_1:  EquipoSlot = $Margin/HBox/PanelEquipamiento/MarginContainer/VBoxEquipamiento/VBoxDerecha/ColAnillo1/SlotAnillo1
@onready var equip_slot_pant:    EquipoSlot = $Margin/HBox/PanelEquipamiento/MarginContainer/VBoxEquipamiento/VBoxIzquierda/ColPantalon/SlotPantalon
@onready var equip_slot_ring_2:  EquipoSlot = $Margin/HBox/PanelEquipamiento/MarginContainer/VBoxEquipamiento/VBoxDerecha/ColAnillo2/SlotAnillo2
@onready var equip_slot_boots:   EquipoSlot = $Margin/HBox/PanelEquipamiento/MarginContainer/VBoxEquipamiento/VBoxIzquierda/ColBotas/SlotBotas
@onready var equip_slot_belt:    EquipoSlot = $Margin/HBox/PanelEquipamiento/MarginContainer/VBoxEquipamiento/VBoxDerecha/ColCinturon/SlotCinturon

## Fila vertical de casillas rápidas dentro del inventario (misma fuente de
## verdad que la barra flotante del HUD, ver GestorBarraRapida/
## SlotConsumibleRapido) — usar_al_tocar=false en su escena: un toque acá
## solo abre el detalle de siempre, no usa el ítem directo.
@onready var quick_slots_inventario: Array[SlotConsumibleRapido] = [
	$Margin/HBox/PanelBarraRapida/MarginContainer/VBox/Slot0,
	$Margin/HBox/PanelBarraRapida/MarginContainer/VBox/Slot1,
	$Margin/HBox/PanelBarraRapida/MarginContainer/VBox/Slot2,
	$Margin/HBox/PanelBarraRapida/MarginContainer/VBox/Slot3,
]

@export var slots_equippable: Array[EquipoSlot]

var item_data_details: SlotItem
## Loot llegó a GestorInventario mientras este panel no se veía en pantalla
## (menú cerrado o en otra pestaña) — reconstruir la grilla completa en ese
## momento no sirve de nada (nadie la está mirando) y en Android se sentía
## como un tirón cada vez que moría un enemigo. Se posterga hasta que el
## panel vuelva a ser visible.
var _grilla_desactualizada := false

func _ready():
	close_button.pressed.connect(_on_close_button)
	action_button.pressed.connect(_on_action_button)
	equip_action_button.pressed.connect(_on_equip_button)
	use_action_button.pressed.connect(_on_use_button)
	barra_rapida_button.pressed.connect(_on_barra_rapida_button)
	drop_action_button.pressed.connect(_on_drop_button)
	# El inventario real vive en el autoload GestorInventario (persiste entre
	# aperturas del panel y cambios de nivel); "items" ya no es la fuente de
	# verdad, solo se usa como vista previa de diseño en el Inspector.
	items = GestorInventario.items
	_load_items_flow()
	_clear_details()
	set_active_filter_button(all_filter_button)
	_conectar_slots_equipables()
	for slot in quick_slots_inventario:
		slot.slot_clicked.connect(_on_slot_clicked)
	BusEventos.item_agregado.connect(_on_item_agregado)
	# Bug real reportado: "cuando paso objetos del cofre al inventario...
	# lo que haya hecho no se sincroniza acá" — FuenteInventario.agregar()
	# (ver ese archivo) siempre pasa silencioso=true, así que item_agregado
	# de arriba nunca se dispara para ese flujo (ni para sacar algo del
	# inventario hacia el cofre). inventario_cambiado SÍ se emite siempre
	# (ver InventarioComponente), sin importar la vía — refrescar_diferido()
	# es el mismo patrón ya usado por SlotConsumibleRapido para "algo
	# cambió el inventario desde afuera, quizás con el panel cerrado".
	BusEventos.inventario_cambiado.connect(refrescar_diferido)
	visibility_changed.connect(_on_visibility_changed)
	_conectar_creditos()
	# GestorInventario.agregar_item(..., silencioso=true) — el modo que usa
	# GestorGuardado para restaurar una partida guardada — a propósito NO
	# emite item_agregado (esos ítems ya eran tuyos, no son botín nuevo; ver
	# el comentario de agregar_item). Pero eso significa que este panel
	# nunca se enteraba de que el inventario se acababa de llenar: si ya
	# estaba en escena antes de que llegara la partida (o el jugador la
	# abría antes de matar el primer mob), se quedaba mostrando la grilla
	# vacía con la que arrancó, hasta el primer item_agregado real (matar
	# un mob) — reportado como "el inventario no carga al inicio".
	GestorGuardado.partida_cargada.connect(refrescar)

	var main_os = get_tree().get_root().find_child("OsPrincipal", true, false)
	if main_os:
		main_os.main_button_close.connect(_on_close_button)

func _on_item_agregado(_item: DatosItem, _cantidad: int) -> void:
	if is_visible_in_tree():
		refrescar()
	else:
		_grilla_desactualizada = true

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		return
	if _creditos == null:
		_conectar_creditos()
	if _grilla_desactualizada:
		_grilla_desactualizada = false
		refrescar()


## Mismo patrón que PanelTienda._al_cambiar_creditos/HudJugador — reintenta
## en cada apertura (ver _on_visibility_changed) por si el jugador local
## todavía no existía cuando este panel corrió su propio _ready().
func _conectar_creditos() -> void:
	_creditos = Utils.creditos_componente_local()
	if _creditos and not _creditos.creditos_cambiados.is_connected(_actualizar_creditos):
		_creditos.creditos_cambiados.connect(_actualizar_creditos)
		_actualizar_creditos(_creditos.obtener_creditos())


func _actualizar_creditos(nuevo: int) -> void:
	_label_creditos.text = "Créditos: %d" % nuevo


## Reconstruye la grilla de inventario desde GestorInventario.items (la
## única fuente de verdad) — llamar siempre que ese autoload cambie por
## cualquier vía (loot, equipar, desequipar), para que la lista visible
## nunca se desincronice de lo que realmente hay.
func refrescar() -> void:
	items = GestorInventario.items
	_load_items_flow()
	# _load_items_flow() reconstruye la grilla desde cero — las filas nuevas
	# nacen todas visibles, así que si había un filtro activo (Equipables,
	# Consumibles...) hay que reaplicarlo o se vería como si se hubiera
	# ignorado (mostrando todo) cada vez que algo dispara un refresco
	# (equipar, lootear, desequipar).
	flow.filter_items(flow.last_filter_type)

## Como refrescar(), pero para quien cambia el inventario desde AFUERA del
## panel mientras puede estar CERRADO (ver SlotConsumibleRapido._on_click) —
## mismo criterio que _on_item_agregado: si nadie lo está mirando ahora
## mismo, alcanza con marcarlo desactualizado y reconstruir la grilla recién
## cuando se abra (ver _on_visibility_changed), en vez de reconstruirla
## entera a ciegas. _load_items_flow() destruye/reinstancia un nodo por
## CADA ítem del inventario completo (no solo el usado) — reportado como un
## tirón notable ("se traba el juego y el jugador hace tp") al usar un
## consumible de la barra rápida mientras caminaba, con el panel cerrado:
## el freeze pausaba toda la física por un instante y el motor "recuperaba"
## de golpe el movimiento acumulado del joystick al descongelarse.
func refrescar_diferido() -> void:
	if is_visible_in_tree():
		refrescar()
	else:
		_grilla_desactualizada = true


func _load_items_flow():
	_clear_grid(flow)
	for data: DatosItem in items:
		flow._add_item(data)

func _conectar_slots_equipables():
	equip_slot_weapon.slot_clicked.connect(_on_slot_clicked)
	equip_slot_shield.slot_clicked.connect(_on_slot_clicked)
	equip_slot_helmet.slot_clicked.connect(_on_slot_clicked)
	equip_slot_neck.slot_clicked.connect(_on_slot_clicked)
	equip_slot_body.slot_clicked.connect(_on_slot_clicked)
	equip_slot_ring_1.slot_clicked.connect(_on_slot_clicked)
	equip_slot_pant.slot_clicked.connect(_on_slot_clicked)
	equip_slot_ring_2.slot_clicked.connect(_on_slot_clicked)
	equip_slot_boots.slot_clicked.connect(_on_slot_clicked)
	equip_slot_belt.slot_clicked.connect(_on_slot_clicked)

func _on_slot_clicked(slot: SlotItem):
	# "slot" es el NODO del slot — siempre válido, aunque esté vacío (no
	# confundir con su propiedad interna slot.item_data, el DatosItem que
	# de verdad contiene). Sin este chequeo, clickear un EquipoSlot vacío
	# llamaba _update_details() igual, que revienta leyendo
	# slot.item_data.name sobre un DatosItem nulo.
	if slot and slot.item_data:
		_update_details(slot)
		main_action_panel.hide()
		detail_panel_margin.show()
		_label_creditos.hide()

func _on_close_button():
	item_data_details = null
	detail_panel_margin.hide()
	main_action_panel.hide()
	_label_creditos.show()

func _on_action_button():
	main_action_panel.visible = !main_action_panel.visible

func _on_equip_button():
	_equip_item(item_data_details)

func _on_use_button():
	var item := item_data_details.item_data
	GestorInventario.usar_item(item)
	# El ítem usado puede seguir referenciado en alguna casilla rápida (ver
	# SlotConsumibleRapido: asignar ahí ya NO lo saca del inventario) — sin
	# esto, esa casilla se quedaba mostrando la cantidad vieja, o un ítem ya
	# agotado, hasta el próximo cambio que la refrescara por otra vía.
	for indice in GestorBarraRapida.CANTIDAD_CASILLAS:
		if GestorBarraRapida.casillas[indice] == item:
			if item.quantity <= 0:
				GestorBarraRapida.limpiar(indice)
			else:
				GestorBarraRapida.refrescar(indice)
	refrescar()
	# Si todavía queda cantidad, el detalle se queda abierto mostrando el
	# mismo ítem (con el número ya actualizado) — usar un consumible con
	# varias unidades no debería obligar a volver a tocarlo cada vez.
	# refrescar() reconstruye la grilla entera, así que item_data_details
	# (el SlotItem viejo) ya no es válido: hay que encontrar el nuevo que
	# representa el mismo DatosItem (misma identidad — usar_item() muta
	# item.quantity en el lugar, nunca reemplaza el objeto).
	if item.quantity <= 0:
		_on_close_button()
		return
	for slot: SlotItem in flow.get_children():
		if slot.item_data == item:
			_update_details(slot)
			return


## Botón "Soltar" del detalle — nunca estaba conectado a nada (bug: no
## hacía absolutamente nada al presionarlo). Para un ítem EQUIPADO
## (item_data_details es un EquipoSlot), significa desequiparlo: mismo
## efecto que arrastrarlo de vuelta a la grilla general (ver
## FlujoItems._drop_data), pero disponible con un solo toque.
func _on_drop_button():
	var slot := item_data_details
	if slot is EquipoSlot:
		var equipo_slot := slot as EquipoSlot
		var item := equipo_slot.item_data
		if item != null:
			equipo_slot.item_data = null
			equipo_slot.update_item()
			# silencioso=true: vuelve al inventario general, no es botín
			# nuevo — no debe disparar la notificación de "recibiste".
			GestorInventario.agregar_item(item, -1, true)
			refrescar()
			notificar_equipo_cambiado()
	_on_close_button()


## Alternativa a arrastrar el ítem a mano hasta una casilla rápida (más
## directo en pantallas táctiles): lo manda a la primera casilla libre de
## GestorBarraRapida — se refleja solo tanto en la fila de este panel como
## en la barra flotante del HUD (ver SlotConsumibleRapido). Solo guarda una
## REFERENCIA: el ítem sigue estando en el inventario general también, la
## casilla es un atajo, no lo saca de ahí. Si las 4 están ocupadas, no hace
## nada — el jugador tiene que soltar/reemplazar una a mano primero.
func _on_barra_rapida_button():
	var item := item_data_details.item_data
	if item == null:
		return
	# Ya está en alguna casilla rápida: no duplicar la referencia ni moverla
	# de lugar solo por presionar el botón de nuevo.
	if item in GestorBarraRapida.casillas:
		_on_close_button()
		return
	var indice := GestorBarraRapida.primer_indice_vacio()
	if indice < 0:
		return
	GestorBarraRapida.asignar(indice, item)
	_on_close_button()

## remove_child() (desvincula DE INMEDIATO) + queue_free() (destruye recién
## en un momento seguro) — nunca uno solo de los dos: con queue_free() solo,
## los hijos viejos siguen en get_children() hasta el próximo fotograma,
## así que un código que busca el slot nuevo justo después de refrescar()
## (ver _on_use_button) podía toparse con el viejo todavía ahí (ver memoria
## queue-free-vs-remove-child-godot; mismo bug ya corregido en
## PanelDialogo._limpiar_opciones() y PanelTienda._limpiar_grilla()).
func _clear_grid(_grid):
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

func _clear_details():
	item_name.text = "No item"
	item_icon.texture = null
	type_value.text = "-"
	qty_value.text = "-"
	conjunto_label.visible = false
	conjunto_value.visible = false
	description_text.text = ""
	_actualizar_caracteristicas(null)
	use_action_button.disabled = true
	barra_rapida_button.disabled = true
	equip_action_button.disabled = true
	drop_action_button.disabled = true

func _update_details(item: SlotItem):
	item_data_details = item
	item_name.text = item.item_data.name
	item_icon.texture = item.item_data.icon
	type_value.text = item.item_data.type_descripcion
	qty_value.text = str(item.item_data.quantity)
	var conjunto := item.item_data.conjunto
	conjunto_label.visible = conjunto != null
	conjunto_value.visible = conjunto != null
	conjunto_value.text = conjunto.nombre if conjunto != null else ""
	description_text.text = item.item_data.description
	_actualizar_caracteristicas(item.item_data)
	use_action_button.disabled   = not item.can_use
	barra_rapida_button.disabled = not item.can_use
	equip_action_button.disabled = not item.can_equip
	drop_action_button.disabled  = not item.can_drop
	use_action_button.visible   = item.can_use
	barra_rapida_button.visible = item.can_use
	equip_action_button.visible = item.can_equip
	drop_action_button.visible  = item.can_drop
	# El botón ya desequipaba de verdad para un ítem puesto (ver
	# _on_drop_button: item_data_details is EquipoSlot) pero decía "Soltar"
	# para cualquier ítem — para uno YA EQUIPADO eso no deja claro qué hace
	# (reportado: "necesito que agregues la accion de desequipar en los
	# objetos que ya estan equipados", sin saber que ya existía bajo ese
	# nombre confuso).
	drop_action_button.text = "Desequipar" if item is EquipoSlot else "Soltar"


## Delegado a Utils.llenar_caracteristicas_item (compartido con PanelTienda,
## que necesita exactamente lo mismo al elegir un equipable propio para
## vender — ver ese comentario para el detalle de qué pinta).
func _actualizar_caracteristicas(item: DatosItem) -> void:
	Utils.llenar_caracteristicas_item(vbox_caracteristicas, item)

func set_active_filter_button(button: Button):
	all_filter_button.button_pressed = false
	all_filter_button.disabled = false
	equipments_filter_button.button_pressed = false
	equipments_filter_button.disabled = false
	consumables_filter_button.button_pressed = false
	consumables_filter_button.disabled = false
	resources_filter_button.button_pressed = false
	resources_filter_button.disabled = false
	button.button_pressed = true
	button.disabled = true

func _on_slot_dragging(status: bool, type_equippable: int):
	_show_color_slot_compatible(status, type_equippable)

func _show_color_slot_compatible(status: bool, type_equippable: int):
	if status:
		for equippable: EquipoSlot in slots_equippable:
			if equippable:
				var valido = equippable.type_equippable == type_equippable
				equippable.modulate = Color(0,1,0,1) if valido else Color(1,0,0,1)
	else:
		for equippable: EquipoSlot in slots_equippable:
			if equippable:
				equippable.modulate = Color(1,1,1,1)

func _equip_item(item_equip: SlotItem):
	var target_slot: SlotItem = null
	if item_equip.item_data.type_equippable == 6:  # RING
		if equip_slot_ring_1.item_data != null and equip_slot_ring_2.item_data != null:
			target_slot = equip_slot_ring_1
		elif equip_slot_ring_1.item_data != null:
			target_slot = equip_slot_ring_2
		else:
			target_slot = equip_slot_ring_1
	else:
		for item: EquipoSlot in slots_equippable:
			if item.type_equippable == item_equip.item_data.type_equippable:
				target_slot = item
	if target_slot == null:
		return
	var item := item_equip.item_data
	# Ya está puesto en ESE MISMO slot (p. ej. tras el bug de EquipoSlot._drop_data
	# que dejaba can_equip=true en ítems equipados por arrastre): no hay nada
	# que intercambiar. Sin este corte, el bloque de abajo lo trataría como
	# "el ocupante viejo" y lo devolvería a GestorInventario sin sacarlo del
	# slot, duplicándolo.
	if target_slot.item_data == item:
		_on_close_button()
		return
	# El ítem deja de estar "suelto" en el inventario general — si no se saca
	# de GestorInventario aquí, la próxima vez que la lista se reconstruya
	# (p. ej. al lootear algo nuevo) reaparecería duplicado, porque seguiría
	# en el autoload aunque su slot de la UI ya se haya destruido.
	GestorInventario.quitar_item(item)
	if target_slot.item_data != null:
		var old_item = target_slot.item_data
		target_slot.item_data = item
		target_slot.can_equip = false
		# silencioso=true: el ocupante anterior vuelve al inventario, no es
		# botín nuevo — no debe disparar la notificación de "recibiste".
		GestorInventario.agregar_item(old_item, -1, true)
	else:
		target_slot.item_data = item
		target_slot.can_equip = false
	refrescar()
	notificar_equipo_cambiado()  # también cierra el detalle — ver su comentario.


## Único punto de entrada de "el equipo cambió" — lo llaman TODOS los
## caminos que pueden cambiarlo: botón Equipar/Soltar, arrastre directo a
## un EquipoSlot (EquipoSlot._drop_data), desequipar arrastrando fuera
## (EquipoSlot._desequipar), soltarlo en la grilla general (FlujoItems) y
## restaurar_equipo() al cargar partida. Cerrar el detalle ACÁ (no en cada
## caller por separado) es a propósito: antes solo el botón Equipar lo
## cerraba (pedido del usuario), y el arrastre directo se quedó afuera sin
## que nadie lo notara — item_data_details seguía apuntando a la
## referencia VIEJA, así que un ítem de CONJUNTO mostraba la cuenta de
## "X/N piezas equipadas" congelada de ANTES de este cambio. Centralizarlo
## acá cubre cualquier camino nuevo que aparezca después sin tener que
## acordarse de repetir la llamada.
func notificar_equipo_cambiado() -> void:
	var equipados: Array[DatosItem] = []
	for slot: EquipoSlot in slots_equippable:
		if slot and slot.item_data:
			equipados.append(slot.item_data)
	GestorEquipo.actualizar(equipados)
	_on_close_button()


## Llenado directo de los slots de equipo desde una lista plana de ítems
## (usado por GestorGuardado al cargar una partida) — mismo criterio que
## _equip_item() para decidir a qué slot va cada uno (por type_equippable;
## los anillos llenan el primero vacío), pero sin pasar por GestorInventario
## porque estos ítems nunca estuvieron "sueltos": vienen directo del
## guardado ya equipados.
func restaurar_equipo(items_equipados: Array[DatosItem]) -> void:
	for slot: EquipoSlot in slots_equippable:
		slot.item_data = null
		slot.update_item()
	for item in items_equipados:
		if item == null:
			continue
		var destino: EquipoSlot = null
		if item.type_equippable == 6:  # RING
			destino = equip_slot_ring_1 if equip_slot_ring_1.item_data == null else equip_slot_ring_2
		else:
			for slot: EquipoSlot in slots_equippable:
				if slot.type_equippable == item.type_equippable:
					destino = slot
		if destino == null:
			continue
		destino.item_data = item
		destino.can_equip = false
		destino.update_item()
	notificar_equipo_cambiado()
