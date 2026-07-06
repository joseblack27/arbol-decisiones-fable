# =============================================================================
# Prueba del bug reportado: "al dropear, repite lo que dropeo más lo último
# que dropeé" — equipar un ítem lo sacaba de la UI pero no de GestorInventario,
# así que reaparecía duplicado la próxima vez que la lista se reconstruía
# (p. ej. al lootear algo nuevo).
#   1. Equipar por botón (_equip_item) saca el ítem de GestorInventario.
#   2. Lootear algo nuevo después NO resucita el ítem ya equipado.
#   3. Arrastrar directo a un EquipoSlot (_drop_data) también saca el ítem
#      de GestorInventario, y devuelve el que estaba puesto antes.
#   4. Presionar "Equipar" sobre un ítem YA equipado (bug: EquipoSlot._drop_data
#      dejaba can_equip=true tras equipar por arrastre, así que el botón
#      seguía habilitado y "reequiparlo" lo duplicaba en GestorInventario sin
#      sacarlo del slot) NO debe duplicarlo ni sacarlo de su slot.
#   5. Desequipar arrastrando de vuelta al inventario (FlujoItems._drop_data)
#      lo devuelve a GestorInventario sin duplicarlo.
# Cada paso queda en su propio fotograma para dar tiempo a que los
# queue_free() de la reconstrucción de grilla se procesen de verdad antes
# de contar cuántos slots quedan (si no, un nodo recién liberado seguiría
# apareciendo en get_children() hasta el siguiente fotograma).
#   godot --headless --path . --script res://pruebas/prueba_inventario_equipar.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _panel: Node
var _gestor: Node
var _armadura: DatosItem
var _casco: DatosItem
var _pocion: DatosItem

var _en_inventario_tras_equipar := false
var _veces_armadura_en_gestor := -1
var _veces_armadura_en_grilla := -1
var _casco_en_gestor := false
var _casco_can_equip_tras_drop := true
var _copias_casco_tras_reequipar := -1
var _casco_sigue_en_slot := false
var _armadura_de_vuelta := false
var _copias_armadura_final := -1


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_equipar_armadura()
		3:
			_en_inventario_tras_equipar = _contar_en_lista(_gestor.items, "Armadura de Prueba") > 0
			print("Armadura sigue en GestorInventario tras equiparla (esperado false): %s" % _en_inventario_tras_equipar)
			# Lootear algo nuevo — antes del fix, esto resucitaba la armadura
			# ya equipada como una entrada duplicada en la grilla.
			_gestor.agregar_item(_pocion)
		4:
			_veces_armadura_en_gestor = _contar_en_lista(_gestor.items, "Armadura de Prueba")
			_veces_armadura_en_grilla = _contar_slots_con_nombre(_panel.flow, "Armadura de Prueba")
			print("Copias de la armadura en GestorInventario tras lootear otra cosa (esperado 0): %d" % _veces_armadura_en_gestor)
			print("Copias de la armadura en la grilla del inventario (esperado 0): %d" % _veces_armadura_en_grilla)
			# Arrastrar el casco directo a su EquipoSlot (drag & drop real).
			var slot_casco := _buscar_slot_de(_panel.flow, _casco)
			_panel.equip_slot_helmet._drop_data(Vector2.ZERO, slot_casco)
		5:
			_casco_en_gestor = _contar_en_lista(_gestor.items, "Casco de Prueba") > 0
			print("Casco sigue en GestorInventario tras arrastrarlo al slot (esperado false): %s" % _casco_en_gestor)
			_casco_can_equip_tras_drop = _panel.equip_slot_helmet.can_equip
			print("can_equip del slot tras equipar por arrastre (esperado false): %s" % _casco_can_equip_tras_drop)
			# Presionar "Equipar" sobre el casco YA equipado (mismo camino que
			# _on_equip_button(), usando el propio EquipoSlot como item_equip).
			_panel._equip_item(_panel.equip_slot_helmet)
		6:
			_copias_casco_tras_reequipar = _contar_en_lista(_gestor.items, "Casco de Prueba")
			_casco_sigue_en_slot = _panel.equip_slot_helmet.item_data != null \
				and _panel.equip_slot_helmet.item_data.name == "Casco de Prueba"
			print("Copias del casco en GestorInventario tras 'reequiparlo' (esperado 0): %d" % _copias_casco_tras_reequipar)
			print("Casco sigue puesto en su slot tras 'reequiparlo' (esperado true): %s" % _casco_sigue_en_slot)
			# Desequipar la armadura arrastrándola de vuelta al inventario general.
			_panel.flow._drop_data(Vector2.ZERO, _panel.equip_slot_body)
		7:
			_armadura_de_vuelta = _contar_en_lista(_gestor.items, "Armadura de Prueba") > 0
			_copias_armadura_final = _contar_en_lista(_gestor.items, "Armadura de Prueba")
			print("Armadura de vuelta en GestorInventario tras desequiparla (esperado true): %s" % _armadura_de_vuelta)
			print("Sin duplicados tras desequipar (esperado 1 copia): %d" % _copias_armadura_final)
			return _informar()
	return false


func _montar() -> void:
	_gestor = root.get_node("/root/GestorInventario")
	_gestor.items.clear()

	_armadura = DatosItem.new()
	_armadura.name = "Armadura de Prueba"
	_armadura.type = 3       # EQUIPPABLE
	_armadura.type_equippable = 2  # BODY
	_armadura.can_equip = true

	_casco = DatosItem.new()
	_casco.name = "Casco de Prueba"
	_casco.type = 3
	_casco.type_equippable = 1  # HELMET
	_casco.can_equip = true

	_pocion = DatosItem.new()
	_pocion.name = "Poción de Prueba"
	_pocion.type = 2  # CONSUMABLE

	_gestor.agregar_item(_armadura)
	_gestor.agregar_item(_casco)

	_panel = (load("res://escenas/ui/panel_os/paneles/inventario/PanelInventario.tscn") as PackedScene).instantiate()
	root.add_child(_panel)


func _equipar_armadura() -> void:
	var slot_armadura := _buscar_slot_de(_panel.flow, _armadura)
	print("¿Se encontró el slot de la armadura en el inventario?: %s" % (slot_armadura != null))
	# Equipar por botón: llama directo a _equip_item() como haría
	# _on_equip_button() al presionar "Equipar".
	_panel._equip_item(slot_armadura)


## Busca por NOMBRE, no por referencia: GestorInventario.agregar_item()
## duplica el recurso de los equipables antes de guardarlo (para no
## corromper el .tres original si está en varias tablas de botín a la vez),
## así que el objeto en la grilla nunca es el mismo que el que se creó aquí.
func _buscar_slot_de(flow: Node, item: DatosItem) -> Node:
	for hijo in flow.get_children():
		if hijo.item_data and hijo.item_data.name == item.name:
			return hijo
	return null


func _contar_en_lista(items: Array, nombre: String) -> int:
	var cuenta := 0
	for i in items:
		if i.name == nombre:
			cuenta += 1
	return cuenta


func _contar_slots_con_nombre(flow: Node, nombre: String) -> int:
	var cuenta := 0
	for hijo in flow.get_children():
		if hijo.item_data and hijo.item_data.name == nombre:
			cuenta += 1
	return cuenta


func _informar() -> bool:
	var exito := not _en_inventario_tras_equipar \
		and _veces_armadura_en_gestor == 0 \
		and _veces_armadura_en_grilla == 0 \
		and not _casco_en_gestor \
		and not _casco_can_equip_tras_drop \
		and _copias_casco_tras_reequipar == 0 \
		and _casco_sigue_en_slot \
		and _armadura_de_vuelta \
		and _copias_armadura_final == 1
	print("PRUEBA INVENTARIO EQUIPAR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
