extends FlowContainer
class_name FlujoItems

@export var min_item_size: int = 48
@export var spacing: int = 8

var slot_scene: PackedScene = preload("res://escenas/ui/panel_os/paneles/inventario/SlotItem.tscn")
var last_filter_type: int = 1  # 1 = Enums.Inventory.TypeItem.ALL

func _ready():
	resized.connect(_update_layout)
	_update_layout()

func _update_layout():
	if get_child_count() == 0:
		return

	var width := size.x
	if width <= 0:
		return

	var cols: int = max(1, int(width / (min_item_size + spacing)))
	var cell_size := int((width - (cols - 1) * spacing) / cols)

	for child in get_children():
		if child is Control:
			child.custom_minimum_size = Vector2(cell_size, cell_size)

func filter_items(filter_type: int):
	last_filter_type = filter_type
	for item: SlotItem in get_children():
		if filter_type == 1:  # ALL
			item.visible = true
		else:
			item.visible = item.item_data.type == filter_type

func _can_drop_data(_at_position, data):
	return data is EquipoSlot

func _drop_data(_at_position, data):
	# Desequipar arrastrando de vuelta al inventario general: el ítem vuelve
	# a GestorInventario (la única fuente de verdad) y se reconstruye la
	# grilla desde ahí — añadirlo solo localmente (sin tocar el autoload)
	# haría que desapareciera la próxima vez que la lista se reconstruya
	# por otra razón (p. ej. lootear algo nuevo).
	var item_slot: EquipoSlot = data
	var item: DatosItem = item_slot.item_data
	if item == null:
		return
	item_slot.item_data = null
	item_slot.update_item()
	GestorInventario.agregar_item(item)
	if owner.has_method("refrescar"):
		owner.refrescar()
	if owner.has_method("notificar_equipo_cambiado"):
		owner.notificar_equipo_cambiado()
	filter_items(last_filter_type)

func _add_item(item_data: DatosItem):
	var slot: SlotItem = slot_scene.instantiate()
	slot.item_data = item_data
	slot.slot_clicked.connect(owner._on_slot_clicked)
	slot.slot_dragging.connect(owner._on_slot_dragging)
	add_child(slot)
	_update_layout()
