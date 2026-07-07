# =============================================================================
# Prueba del bug reportado: "cuando equipo un equipable y hay un filtro
# puesto, este lo ignora y carga todo" — refrescar() reconstruye la grilla
# desde cero (todas las filas nacen visibles) pero nunca reaplicaba el
# último filtro activo, así que cualquier refresco (equipar, lootear,
# desequipar) hacía que la grilla mostrara TODO otra vez.
#   godot --headless --path . --script res://pruebas/prueba_filtro_inventario.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _panel: Node
var _gestor: Node
var _armadura: DatosItem
var _pocion: DatosItem

var _visibles_tras_filtro := -1
var _visibles_tras_equipar := -1
var _armadura_visible_tras_equipar := true


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			# Filtrar solo Equipables (debería ocultar la poción).
			_panel.flow.filter_items(3)  # 3 = Enums.Inventory.TypeItem.EQUIPPABLE
			_visibles_tras_filtro = _contar_visibles(_panel.flow)
			print("Visibles tras filtrar Equipables (esperado 1, solo la armadura): %d" % _visibles_tras_filtro)
			# Equipar la armadura (dispara refrescar() -> reconstruye la grilla).
			var slot_armadura := _buscar_slot_de(_panel.flow, _armadura)
			_panel._equip_item(slot_armadura)
		3:
			_visibles_tras_equipar = _contar_visibles(_panel.flow)
			print("Visibles tras equipar con el filtro puesto (esperado 0: la armadura ya no está suelta, y la poción sigue oculta): %d" % _visibles_tras_equipar)
			return _informar()
	return false


func _montar() -> void:
	_gestor = root.get_node("/root/GestorInventario")
	_gestor.items.clear()

	_armadura = DatosItem.new()
	_armadura.name = "Armadura de Prueba"
	_armadura.type = 3  # EQUIPPABLE
	_armadura.type_equippable = 2  # BODY
	_armadura.can_equip = true

	_pocion = DatosItem.new()
	_pocion.name = "Poción de Prueba"
	_pocion.type = 2  # CONSUMABLE

	_gestor.agregar_item(_armadura)
	_gestor.agregar_item(_pocion)

	_panel = (load("res://escenas/ui/panel_os/paneles/inventario/PanelInventario.tscn") as PackedScene).instantiate()
	root.add_child(_panel)


func _buscar_slot_de(flow: Node, item: DatosItem) -> Node:
	for hijo in flow.get_children():
		if hijo.item_data and hijo.item_data.name == item.name:
			return hijo
	return null


func _contar_visibles(flow: Node) -> int:
	var cuenta := 0
	for hijo in flow.get_children():
		if hijo.visible:
			cuenta += 1
	return cuenta


func _informar() -> bool:
	var exito := _visibles_tras_filtro == 1 and _visibles_tras_equipar == 0
	print("PRUEBA FILTRO INVENTARIO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
