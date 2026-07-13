extends Control
class_name PanelInventario

@export var slot_scene: PackedScene
@export var items: Array[DatosItem] = []
@export var slot_size := Vector2(48, 48)
@export var min_spacing := 4

@onready var flow: FlujoItems = $Margin/HBox/PanelItems/MarginContainer/VBoxItems/MarginContainer/ScrollContainer/FlujoItems

@onready var item_name         := $Margin/HBox/Control/PanelDetalle/MarginContainer/VBoxDetalle/NombreItem
@onready var item_icon         := $Margin/HBox/Control/PanelDetalle/MarginContainer/VBoxDetalle/IconoItem
@onready var type_value        := $Margin/HBox/Control/PanelDetalle/MarginContainer/VBoxDetalle/MarginContainer/RejillaInfo/ValorTipo
@onready var qty_value         := $Margin/HBox/Control/PanelDetalle/MarginContainer/VBoxDetalle/MarginContainer/RejillaInfo/ValorCantidad
@onready var description_text  := $Margin/HBox/Control/PanelDetalle/MarginContainer/VBoxDetalle/MarginContainer2/VBoxContainer/TextoDescripcion
@onready var vbox_caracteristicas: VBoxContainer = $Margin/HBox/Control/PanelDetalle/MarginContainer/VBoxDetalle/VBoxCaracteristicas

## Orden y etiqueta en español de cada campo de AtributosBase que se muestra
## en el detalle de un equipable. Solo se listan los bonos que el ítem
## realmente aporta (valor != 0), sin título — van pegados debajo de la
## descripción, separados por el HSeparator4 ya existente en la escena.
const ETIQUETAS_ATRIBUTOS := [
	["danos", "Daños"],
	["potencia", "Potencia"],
	["impacto", "Impacto"],
	["afliccion", "Aflicción"],
	["impulso", "Impulso"],
	["probabilidad_critico", "Prob. Crítico"],
	["dano_critico", "Daño Crítico"],
	["defensa", "Defensa"],
	["tenacidad", "Tenacidad"],
	["fortaleza", "Fortaleza"],
	["resistencia_fisica", "Resist. Física"],
	["resistencia_aire", "Resist. Aire"],
	["resistencia_agua", "Resist. Agua"],
	["resistencia_fuego", "Resist. Fuego"],
	["resistencia_tierra", "Resist. Tierra"],
]
@onready var close_button      := $Margin/HBox/Control/PanelDetalle/BotonCerrar
@onready var detail_panel_margin := $Margin/HBox/Control/PanelDetalle

@onready var action_button     := $Margin/HBox/Control/PanelDetalle/MarginContainer/VBoxDetalle/BotonAccion
@onready var main_action_panel: PanelContainer = $Margin/HBox/Control/PanelDetalle/PanelAccionPrincipal
@onready var use_action_button   := $Margin/HBox/Control/PanelDetalle/PanelAccionPrincipal/MarginContainer/VBoxContainer/BotonUsar
@onready var barra_rapida_button := $Margin/HBox/Control/PanelDetalle/PanelAccionPrincipal/MarginContainer/VBoxContainer/BotonBarraRapida
@onready var equip_action_button := $Margin/HBox/Control/PanelDetalle/PanelAccionPrincipal/MarginContainer/VBoxContainer/BotonEquipar
@onready var drop_action_button  := $Margin/HBox/Control/PanelDetalle/PanelAccionPrincipal/MarginContainer/VBoxContainer/BotonSoltar

@onready var all_filter_button:        Button = $Margin/HBox/PanelItems/MarginContainer/VBoxItems/TabsFiltro/BotonTodos
@onready var equipments_filter_button: Button = $Margin/HBox/PanelItems/MarginContainer/VBoxItems/TabsFiltro/BotonEquipables
@onready var consumables_filter_button: Button = $Margin/HBox/PanelItems/MarginContainer/VBoxItems/TabsFiltro/BotonConsumibles
@onready var resources_filter_button:  Button = $Margin/HBox/PanelItems/MarginContainer/VBoxItems/TabsFiltro/BotonRecursos

@onready var equipment_panel: Panel = $Margin/HBox/Control/PanelEquipamiento
@onready var equip_slot_weapon:  EquipoSlot = $Margin/HBox/Control/PanelEquipamiento/MarginContainer/VBoxEquipamiento/HBoxContainer1/SlotArma
@onready var equip_slot_shield:  EquipoSlot = $Margin/HBox/Control/PanelEquipamiento/MarginContainer/VBoxEquipamiento/HBoxContainer1/SlotEscudo
@onready var equip_slot_helmet:  EquipoSlot = $Margin/HBox/Control/PanelEquipamiento/MarginContainer/VBoxEquipamiento/HBoxContainer2/SlotCasco
@onready var equip_slot_neck:    EquipoSlot = $Margin/HBox/Control/PanelEquipamiento/MarginContainer/VBoxEquipamiento/HBoxContainer2/SlotCuello
@onready var equip_slot_body:    EquipoSlot = $Margin/HBox/Control/PanelEquipamiento/MarginContainer/VBoxEquipamiento/HBoxContainer3/SlotPecho
@onready var equip_slot_ring_1:  EquipoSlot = $Margin/HBox/Control/PanelEquipamiento/MarginContainer/VBoxEquipamiento/HBoxContainer3/SlotAnillo1
@onready var equip_slot_pant:    EquipoSlot = $Margin/HBox/Control/PanelEquipamiento/MarginContainer/VBoxEquipamiento/HBoxContainer4/SlotPantalon
@onready var equip_slot_ring_2:  EquipoSlot = $Margin/HBox/Control/PanelEquipamiento/MarginContainer/VBoxEquipamiento/HBoxContainer4/SlotAnillo2
@onready var equip_slot_boots:   EquipoSlot = $Margin/HBox/Control/PanelEquipamiento/MarginContainer/VBoxEquipamiento/HBoxContainer5/SlotBotas
@onready var equip_slot_belt:    EquipoSlot = $Margin/HBox/Control/PanelEquipamiento/MarginContainer/VBoxEquipamiento/HBoxContainer5/SlotCinturon

## Fila vertical de casillas rápidas dentro del inventario (misma fuente de
## verdad que la barra flotante del HUD, ver GestorBarraRapida/
## SlotConsumibleRapido) — usar_al_tocar=false en su escena: un toque acá
## solo abre el detalle de siempre, no usa el ítem directo.
@onready var quick_slots_inventario: Array[SlotConsumibleRapido] = [
	$Margin/HBox/Control/PanelBarraRapida/MarginContainer/VBox/Slot0,
	$Margin/HBox/Control/PanelBarraRapida/MarginContainer/VBox/Slot1,
	$Margin/HBox/Control/PanelBarraRapida/MarginContainer/VBox/Slot2,
	$Margin/HBox/Control/PanelBarraRapida/MarginContainer/VBox/Slot3,
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
	visibility_changed.connect(_on_visibility_changed)
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
	if is_visible_in_tree() and _grilla_desactualizada:
		_grilla_desactualizada = false
		refrescar()


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

func _on_close_button():
	detail_panel_margin.hide()
	main_action_panel.hide()

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
	_on_close_button()


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
			GestorInventario.agregar_item(item)
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
	var indice := GestorBarraRapida.primer_indice_vacio()
	if indice < 0:
		return
	GestorBarraRapida.asignar(indice, item)
	_on_close_button()

func _clear_grid(_grid):
	for child in _grid.get_children():
		child.queue_free()

func _clear_details():
	item_name.text = "No item"
	item_icon.texture = null
	type_value.text = "-"
	qty_value.text = "-"
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


## Pinta, debajo de la descripción, una fila por cada característica != 0
## del ítem: primero "Vida" si es un consumible con curacion (ver
## DatosItem.curacion), después cada bono de equipo != 0 (nombre pegado a
## la izquierda, valor pegado a la derecha).
func _actualizar_caracteristicas(item: DatosItem) -> void:
	# free() inmediato (no queue_free): son nodos recién creados sin señales
	# ni procesos pendientes, y así la lista queda consistente en el mismo
	# fotograma en que se cambia de ítem seleccionado.
	for hijo in vbox_caracteristicas.get_children():
		hijo.free()
	if item == null:
		return
	if item.curacion > 0.0:
		_agregar_fila_caracteristica("Vida", item.curacion)
	if item.bonos != null:
		for par in ETIQUETAS_ATRIBUTOS:
			var campo: String = par[0]
			var etiqueta: String = par[1]
			var valor: float = item.bonos.get(campo)
			if valor == 0.0:
				continue
			_agregar_fila_caracteristica(etiqueta, valor)


func _agregar_fila_caracteristica(etiqueta: String, valor: float) -> void:
	var fila := HBoxContainer.new()
	var nombre := Label.new()
	nombre.text = etiqueta
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cantidad := Label.new()
	cantidad.text = ("+%s" % _formatear_valor(valor)) if valor > 0.0 else _formatear_valor(valor)
	cantidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila.add_child(nombre)
	fila.add_child(cantidad)
	vbox_caracteristicas.add_child(fila)


## Evita el ".0" final en bonos con valor entero (10.0 -> "10"); conserva
## decimales cuando el bono realmente los tiene (2.5 -> "2.5").
func _formatear_valor(valor: float) -> String:
	if valor == floor(valor):
		return str(int(valor))
	return str(valor)

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
		GestorInventario.agregar_item(old_item)
	else:
		target_slot.item_data = item
		target_slot.can_equip = false
	refrescar()
	notificar_equipo_cambiado()
	_on_close_button()


## Avisa (vía GestorEquipo/BusEventos) la lista completa de ítems puestos
## ahora mismo — quien escuche (típicamente AtributosComponente del jugador)
## recalcula sus bonos de atributos desde cero con esta lista. Pública:
## EquipoSlot._drop_data() también la llama (arrastrar directo a un slot de
## equipo cambia el equipo sin pasar por _equip_item()).
func notificar_equipo_cambiado() -> void:
	var equipados: Array[DatosItem] = []
	for slot: EquipoSlot in slots_equippable:
		if slot and slot.item_data:
			equipados.append(slot.item_data)
	GestorEquipo.actualizar(equipados)


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
