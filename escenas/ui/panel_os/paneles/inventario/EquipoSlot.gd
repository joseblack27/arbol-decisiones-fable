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
	var old_item = item_data
	var item: DatosItem = data.item_data
	item_data = item
	if data:
		if (data is EquipoSlot and data.type_equippable == type_equippable) \
		or (data is SlotItem and data.item_data.type_equippable == item_data.type_equippable):
			item_data = data.item_data
			data.item_data = old_item
			if data.item_data == null:
				data.call_deferred("queue_free")
	slot_dragging.emit(false, item_data.type_equippable)
	update_item()

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		modulate = Color(1, 1, 1, 1)
