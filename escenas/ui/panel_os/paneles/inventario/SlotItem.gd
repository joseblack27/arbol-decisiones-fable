extends Control
class_name SlotItem

signal slot_clicked(item_data)
signal slot_dragging(status: bool, type_item: int)

@export var item_data: DatosItem:
	set(value):
		item_data = value
		update_item()
		if value:
			can_use   = item_data.can_use
			can_equip = item_data.can_equip
			can_drop  = item_data.can_drop
	get:
		return item_data

@export var can_use:  bool = false
@export var can_equip: bool = false
@export var can_drop:  bool = true

var is_dragging := false

## Qué instancia inició el arrastre actualmente en curso, si alguna —
## necesario porque NOTIFICATION_DRAG_END llega a TODOS los controles del
## árbol (no solo al que arrancó el arrastre), así que un EquipoSlot
## necesita esta forma de confirmar que el arrastre que acaba de terminar
## era el SUYO antes de reaccionar (ver EquipoSlot._notification).
static var arrastrando_ahora: SlotItem = null

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

	# can_equip (llevar a un EquipoSlot) O can_use (llevar a la barra rápida
	# de consumibles, ver SlotConsumibleRapido): sin el segundo caso, un
	# ítem usable (poción, comida...) nunca podía arrastrarse desde la
	# grilla general del inventario, solo equipables.
	if not item_data or (item_data.can_equip == false and item_data.can_use == false):
		return null

	arrastrando_ahora = self
	slot_dragging.emit(true, item_data.type_equippable)

	var size_icon := Vector2(32, 32)
	var wrapper := Control.new()
	wrapper.custom_minimum_size = size_icon
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview := TextureRect.new()
	preview.texture = item_data.icon
	preview.expand = true
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = size_icon
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.position = -size_icon / 2

	wrapper.add_child(preview)
	set_drag_preview(wrapper)
	return self


## Solo acepta el drop si ESTE slot tiene un ítem del MISMO type_equippable
## que el que se está arrastrando desde un EquipoSlot — es la única acción
## "positiva" que una celda de la grilla general necesita manejar ella
## misma (reemplazo real). Cualquier OTRO caso (celda vacía, tipo distinto,
## soltar en el fondo del panel, sobre otro EquipoSlot que no coincide...)
## NO se acepta acá a propósito: lo resuelve EquipoSlot._notification como
## red de seguridad final cuando el arrastre termina sin que nadie lo
## haya aceptado — ver ese archivo para el porqué (mouse_filter STOP por
## defecto corta cualquier intento de "burbujear" el rechazo hacia arriba,
## así que depender de eso para el resto de los casos no es confiable).
func _can_drop_data(_at_position, data) -> bool:
	return data is EquipoSlot and data.item_data != null \
		and item_data != null and item_data.type_equippable == data.item_data.type_equippable


## Reemplazo: el ítem de ESTA celda pasa a equipado en el EquipoSlot de
## origen, y el que estaba puesto ahí vuelve al inventario general.
func _drop_data(_at_position, data) -> void:
	var fuente: EquipoSlot = data
	var item: DatosItem = fuente.item_data
	if item == null:
		return
	var item_reemplazo := item_data
	fuente.item_data = item_reemplazo
	fuente.can_equip = false
	fuente.update_item()
	GestorInventario.quitar_item(item_reemplazo)
	GestorInventario.agregar_item(item)
	fuente.slot_dragging.emit(false, item.type_equippable)
	var panel := _obtener_panel_inventario()
	if panel:
		panel.refrescar()
		panel.notificar_equipo_cambiado()


func _obtener_panel_inventario() -> Node:
	return get_tree().get_root().find_child("PanelInventario", true, false)


func _notification(what):
	if what == NOTIFICATION_DRAG_END and arrastrando_ahora == self:
		arrastrando_ahora = null
