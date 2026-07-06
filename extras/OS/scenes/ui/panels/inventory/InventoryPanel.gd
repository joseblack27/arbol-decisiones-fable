extends Control
class_name InventoryPanel

@export var slot_scene: PackedScene          # ItemSlot.tscn
@export var items: Array[ItemData] = []      # Lista de items del jugador
@export var slot_size := Vector2(48, 48)     # tamaño del slot
@export var min_spacing := 4                 # mínimo espacio permitido

@onready var flow: FlowItems = $Margin/HBox/ItemsPanel/MarginContainer/ItemsVBox/MarginContainer/ScrollContainer/FlowItems

# Panel de detalle
@onready var item_name := $Margin/HBox/Control/DetailPanel/MarginContainer/DetailVBox/ItemName
@onready var item_icon := $Margin/HBox/Control/DetailPanel/MarginContainer/DetailVBox/ItemIcon
@onready var type_value := $Margin/HBox/Control/DetailPanel/MarginContainer/DetailVBox/MarginContainer/InfoGrid/TypeValue
@onready var qty_value := $Margin/HBox/Control/DetailPanel/MarginContainer/DetailVBox/MarginContainer/InfoGrid/QtyValue
@onready var description_text := $Margin/HBox/Control/DetailPanel/MarginContainer/DetailVBox/MarginContainer2/VBoxContainer/DescriptionText
@onready var close_button := $Margin/HBox/Control/DetailPanel/CloseButton
@onready var detail_panel_margin := $Margin/HBox/Control/DetailPanel

@onready var action_button := $Margin/HBox/Control/DetailPanel/MarginContainer/DetailVBox/ActionButton

@onready var main_action_panel: PanelContainer = $Margin/HBox/Control/DetailPanel/MainActionPanel
@onready var use_action_button := $Margin/HBox/Control/DetailPanel/MainActionPanel/MarginContainer/VBoxContainer/UseButton
@onready var equip_action_button := $Margin/HBox/Control/DetailPanel/MainActionPanel/MarginContainer/VBoxContainer/EquipButton
@onready var drop_action_button := $Margin/HBox/Control/DetailPanel/MainActionPanel/MarginContainer/VBoxContainer/DropButton

@onready var all_filter_button: Button = $Margin/HBox/ItemsPanel/MarginContainer/ItemsVBox/FilterTabs/AllButton
@onready var equipments_filter_button: Button = $Margin/HBox/ItemsPanel/MarginContainer/ItemsVBox/FilterTabs/EquipmentsButton
@onready var consumables_filter_button: Button = $Margin/HBox/ItemsPanel/MarginContainer/ItemsVBox/FilterTabs/ConsumablesButton
@onready var resources_filter_button: Button = $Margin/HBox/ItemsPanel/MarginContainer/ItemsVBox/FilterTabs/ResourcesButton

# Panel de equipamiento
@onready var equipment_panel: Panel = $Margin/HBox/Control/EquipmentPanel
@onready var equip_slot_weapon: EquipoSlot = $Margin/HBox/Control/EquipmentPanel/MarginContainer/EquipmentVBox/HBoxContainer1/EquipSlotWeapon
@onready var equip_slot_shield: EquipoSlot = $Margin/HBox/Control/EquipmentPanel/MarginContainer/EquipmentVBox/HBoxContainer1/EquipSlotShield
@onready var equip_slot_helmet: EquipoSlot = $Margin/HBox/Control/EquipmentPanel/MarginContainer/EquipmentVBox/HBoxContainer2/EquipSlotHelmet
@onready var equip_slot_neck: EquipoSlot = $Margin/HBox/Control/EquipmentPanel/MarginContainer/EquipmentVBox/HBoxContainer2/EquipSlotNeck
@onready var equip_slot_body : EquipoSlot= $Margin/HBox/Control/EquipmentPanel/MarginContainer/EquipmentVBox/HBoxContainer3/EquipSlotBody
@onready var equip_slot_ring_1: EquipoSlot = $Margin/HBox/Control/EquipmentPanel/MarginContainer/EquipmentVBox/HBoxContainer3/EquipSlotRing1
@onready var equip_slot_pant: EquipoSlot = $Margin/HBox/Control/EquipmentPanel/MarginContainer/EquipmentVBox/HBoxContainer4/EquipSlotPant
@onready var equip_slot_ring_2: EquipoSlot = $Margin/HBox/Control/EquipmentPanel/MarginContainer/EquipmentVBox/HBoxContainer4/EquipSlotRing2
@onready var equip_slot_boots: EquipoSlot = $Margin/HBox/Control/EquipmentPanel/MarginContainer/EquipmentVBox/HBoxContainer5/EquipSlotBoots
@onready var equip_slot_belt: EquipoSlot = $Margin/HBox/Control/EquipmentPanel/MarginContainer/EquipmentVBox/HBoxContainer5/EquipSlotBelt

@export var slots_equippable: Array[EquipoSlot]

var item_data_details: ItemSlot

func _ready():
	close_button.pressed.connect(_on_close_button)
	action_button.pressed.connect(_on_action_button)
	equip_action_button.pressed.connect(_on_equip_button)
	
	_load_items_flow()
	_clear_details()
	#_update_spacing()
	set_active_filter_button(all_filter_button)
	
	var main_os = get_tree().get_root().find_child("MainOS", true, false)
	if main_os:
		main_os.main_button_close.connect(_on_close_button)

func _load_items_flow():
	_clear_grid(flow)

	for data: ItemData in items:
		flow._add_item(data)
	
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

#region Botones

func _on_slot_clicked(item_data: ItemSlot):
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

#endregion

func _update_spacing():
	var container_width := flow.size.x
	if container_width <= 0:
		return

	var slot_w := slot_size.x

	# cuántos caben por fila
	var max_per_row = max(1, floori(container_width / (slot_w + min_spacing)))

	# ancho usado por items
	var used_width = max_per_row * slot_w

	# espacio libre entre items
	var free_space = container_width - used_width

	# spacing ideal
	var spacing := floori(free_space / (max_per_row + 1))

	# límite para que no se desarme la grilla
	spacing = clamp(spacing, min_spacing, 32)

	flow.add_theme_constant_override("h_separation", spacing)
	flow.add_theme_constant_override("v_separation", spacing)

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

func _update_details(item: ItemSlot):
	item_data_details = item
	item_name.text = item.item_data.name
	item_icon.texture = item.item_data.icon
	type_value.text = item.item_data.type_descripcion
	qty_value.text = str(item.item_data.quantity)
	description_text.text = item.item_data.description

	# Habilitar según tipo
	use_action_button.disabled = not item.can_use
	equip_action_button.disabled = not item.can_equip
	drop_action_button.disabled = not item.can_drop
	
	use_action_button.visible = item.can_use
	equip_action_button.visible = item.can_equip
	drop_action_button.visible = item.can_drop

func set_active_filter_button(button: Button):
	# Primero desactivo todos
	all_filter_button.button_pressed = false
	all_filter_button.disabled = false
	equipments_filter_button.button_pressed = false
	equipments_filter_button.disabled = false
	consumables_filter_button.button_pressed = false
	consumables_filter_button.disabled = false
	resources_filter_button.button_pressed = false
	resources_filter_button.disabled = false

	# Activo solo el correcto
	button.button_pressed = true
	button.disabled = true

func _on_slot_dragging(status: bool, type_equippable: Enums.Inventory.TypeItemEquippable):
	_show_color_slot_compatible(status, type_equippable)

func _show_color_slot_compatible(status: bool, type_equippable: Enums.Inventory.TypeItemEquippable):
	if status == true:
		for equippable: EquipoSlot in slots_equippable:
			if equippable:
				var valido = equippable.type_equippable == type_equippable
				equippable.modulate = Color(0,1,0,1) if valido else Color(1,0,0,1)
	else:
		for equippable: EquipoSlot in slots_equippable:
			if equippable:
				equippable.modulate = Color(1,1,1,1)

func _equip_item(item_equip: ItemSlot):
	
	var target_slot: ItemSlot = null
	
	if item_equip.item_data.type_equippable == Enums.Inventory.TypeItemEquippable.RING:
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
	
	if target_slot.item_data != null:
		var old_item = target_slot.item_data
		target_slot.item_data = item_equip.item_data
		target_slot.can_equip = false
		item_equip.item_data = old_item
		item_equip.can_equip = true
	else:
		target_slot.item_data = item_equip.item_data
		target_slot.can_equip = false
		item_equip.call_deferred("queue_free")
	
	_on_close_button()

#func _equip_item(item_equip: ItemSlot):
	#var target_slot: ItemSlot = null
	#var item_type := item_equip.item_data.type_equippable
#
	## 🔵 CASO ESPECIAL: RING
	#if item_type == Enums.Inventory.TypeItemEquippable.RING:
		#if equip_slot_ring_1.item_data != null and equip_slot_ring_2.item_data != null:
			## Ambos ocupados → reemplaza el primero
			#target_slot = equip_slot_ring_1
		#elif equip_slot_ring_1.item_data != null:
			## Solo el primero ocupado → usa el segundo
			#target_slot = equip_slot_ring_2
		#else:
			## El primero está libre
			#target_slot = equip_slot_ring_1
#
	## 🔵 OTROS TIPOS DE EQUIPAMIENTO
	#else:
		#for slot: EquipoSlot in slots_equippable:
			#if slot.type_equippable == item_type:
				#target_slot = slot
				#break
#
	## 🔒 Seguridad
	#if target_slot == null:
		#return
#
	## 🔁 EQUIPAR / INTERCAMBIAR
	#if target_slot.item_data != null:
		#var old_item = target_slot.item_data
		#target_slot.item_data = item_equip.item_data
		#item_equip.item_data = old_item
	#else:
		#target_slot.item_data = item_equip.item_data
		#item_equip.call_deferred("queue_free")
#
	#_on_close_button()
