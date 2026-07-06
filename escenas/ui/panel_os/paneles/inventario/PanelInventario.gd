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
@onready var close_button      := $Margin/HBox/Control/PanelDetalle/BotonCerrar
@onready var detail_panel_margin := $Margin/HBox/Control/PanelDetalle

@onready var action_button     := $Margin/HBox/Control/PanelDetalle/MarginContainer/VBoxDetalle/BotonAccion
@onready var main_action_panel: PanelContainer = $Margin/HBox/Control/PanelDetalle/PanelAccionPrincipal
@onready var use_action_button   := $Margin/HBox/Control/PanelDetalle/PanelAccionPrincipal/MarginContainer/VBoxContainer/BotonUsar
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

@export var slots_equippable: Array[EquipoSlot]

var item_data_details: SlotItem

func _ready():
	close_button.pressed.connect(_on_close_button)
	action_button.pressed.connect(_on_action_button)
	equip_action_button.pressed.connect(_on_equip_button)
	# El inventario real vive en el autoload GestorInventario (persiste entre
	# aperturas del panel y cambios de nivel); "items" ya no es la fuente de
	# verdad, solo se usa como vista previa de diseño en el Inspector.
	items = GestorInventario.items
	_load_items_flow()
	_clear_details()
	set_active_filter_button(all_filter_button)
	_conectar_slots_equipables()
	BusEventos.item_agregado.connect(_on_item_agregado)

	var main_os = get_tree().get_root().find_child("OsPrincipal", true, false)
	if main_os:
		main_os.main_button_close.connect(_on_close_button)

func _on_item_agregado(_item: DatosItem, _cantidad: int) -> void:
	refrescar()


## Reconstruye la grilla de inventario desde GestorInventario.items (la
## única fuente de verdad) — llamar siempre que ese autoload cambie por
## cualquier vía (loot, equipar, desequipar), para que la lista visible
## nunca se desincronice de lo que realmente hay.
func refrescar() -> void:
	items = GestorInventario.items
	_load_items_flow()

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

func _on_slot_clicked(item_data: SlotItem):
	if item_data:
		_update_details(item_data)
		main_action_panel.hide()
		detail_panel_margin.show()

func _on_close_button():
	detail_panel_margin.hide()
	main_action_panel.hide()

func _on_action_button():
	main_action_panel.visible = !main_action_panel.visible

func _on_equip_button():
	_equip_item(item_data_details)

func _clear_grid(_grid):
	for child in _grid.get_children():
		child.queue_free()

func _clear_details():
	item_name.text = "No item"
	item_icon.texture = null
	type_value.text = "-"
	qty_value.text = "-"
	description_text.text = ""
	use_action_button.disabled = true
	equip_action_button.disabled = true
	drop_action_button.disabled = true

func _update_details(item: SlotItem):
	item_data_details = item
	item_name.text = item.item_data.name
	item_icon.texture = item.item_data.icon
	type_value.text = item.item_data.type_descripcion
	qty_value.text = str(item.item_data.quantity)
	description_text.text = item.item_data.description
	use_action_button.disabled   = not item.can_use
	equip_action_button.disabled = not item.can_equip
	drop_action_button.disabled  = not item.can_drop
	use_action_button.visible   = item.can_use
	equip_action_button.visible = item.can_equip
	drop_action_button.visible  = item.can_drop

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
