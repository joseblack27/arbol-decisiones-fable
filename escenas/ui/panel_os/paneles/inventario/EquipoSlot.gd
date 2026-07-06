extends SlotItem
class_name EquipoSlot

@export var icon: Texture2D:
	set(value):
		icon = value
		update_item()

## 0=NONE,1=HELMET,2=BODY,3=PANT,4=BOOTS,5=NECK,6=RING,7=BELT,8=WEAPON,9=SHIELD
@export var type_equippable: int = 0

func update_item():
	if item_data:
		$Icon.texture = item_data.icon
	elif icon:
		$Icon.texture = icon
	else:
		$Icon.texture = null

func _can_drop_data(_position, data) -> bool:
	if data.item_data == null:
		return false
	if item_data and data.item_data.type_equippable != item_data.type_equippable:
		return false
	return data.item_data.type_equippable == type_equippable

func _drop_data(_position, data):
	if data == self:
		return
	var item: DatosItem = data.item_data
	if item == null:
		return
	var item_anterior := item_data
	item_data = item
	# El setter de item_data (heredado de SlotItem) copia can_equip desde el
	# DatosItem — que para un equipable es SIEMPRE true. Sin esto, un ítem
	# equipado por arrastre queda con el botón "Equipar" habilitado si volvés
	# a abrir su detalle; presionarlo entonces lo "reequipa consigo mismo" y
	# lo duplica en GestorInventario sin sacarlo del slot (ver bug reportado).
	can_equip = false

	if data is EquipoSlot:
		# Intercambio directo entre dos slots de equipo: ninguno de los dos
		# pasa por el inventario general, así que GestorInventario no se toca.
		data.item_data = item_anterior
		data.can_equip = false
		data.update_item()
	else:
		# Viene del inventario general: deja de estar "suelto" ahí — si no
		# se saca de GestorInventario aquí, reaparecería duplicado la
		# próxima vez que la lista se reconstruya (sigue en el autoload
		# aunque su slot de la UI ya se haya destruido). Si había algo
		# puesto en este slot, vuelve al inventario.
		var panel := _obtener_panel_inventario()
		GestorInventario.quitar_item(item)
		if item_anterior != null:
			GestorInventario.agregar_item(item_anterior)
		if panel:
			panel.refrescar()

	slot_dragging.emit(false, item_data.type_equippable)
	update_item()
	_notificar_equipo_cambiado()


## El equipo cambió por arrastre directo (sin pasar por
## PanelInventario._equip_item()) — avisarle igual para que recalcule bonos.
func _notificar_equipo_cambiado() -> void:
	var panel := _obtener_panel_inventario()
	if panel and panel.has_method("notificar_equipo_cambiado"):
		panel.notificar_equipo_cambiado()


func _obtener_panel_inventario() -> Node:
	return get_tree().get_root().find_child("PanelInventario", true, false)

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		modulate = Color(1, 1, 1, 1)
