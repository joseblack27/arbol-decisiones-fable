extends Control
class_name ItemSlot

signal slot_clicked(item_data)
signal slot_dragging(status: bool, type_item: Enums.Inventory.TypeItem)

@export var item_data: ItemData:
	set(value):
		item_data = value
		update_item()
		if value:
			can_use = item_data.can_use
			can_equip = item_data.can_equip
			can_drop = item_data.can_drop
	get:
		return item_data

@export var can_use: bool = false
@export var can_equip: bool = false
@export var can_drop: bool = true

var is_dragging := false

func _ready():
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = false

		elif event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
			if not is_dragging:
				slot_clicked.emit(self)

func update_item():
	if item_data:
		$Icon.texture = item_data.icon
		$QuantityLabel.text = str(item_data.quantity) if item_data.quantity > 1 else ""
		$QuantityLabel.visible = true
	else:
		$Icon.texture = null
		$QuantityLabel.text = ""
		$QuantityLabel.visible = false

func _get_drag_data(_at_position):

	is_dragging = true

	if not item_data \
	or item_data.can_equip == false:
		return null

	slot_dragging.emit(true, item_data.type_equippable)

	# Preview visual mientras se arrastra
	var size_icon: Vector2 = Vector2(32,32)

	# Contenedor raíz del preview
	var wrapper := Control.new()
	wrapper.custom_minimum_size = size_icon
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Icono
	var preview := TextureRect.new()
	preview.texture = item_data.icon
	preview.expand = true
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = size_icon
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 🔥 ESTE ES EL TRUCO REAL
	preview.position = -size_icon / 2

	wrapper.add_child(preview)

	set_drag_preview(wrapper)
	
	return self
