# =============================================================================
# Prueba del pedido: "al equipar un consumible en el acceso rápido..."
#   1) Botón "Añadir a barra rápida" del detalle: si el ítem YA está en
#      alguna casilla, no hace nada (no duplica, no lo mueve).
#   2) Arrastrar un ítem a una casilla VACÍA cuando ya existe en otra: se
#      quita de la casilla vieja y se pone en la nueva (no queda duplicado).
#   godot --headless --path . --script res://pruebas/prueba_barra_rapida_sin_duplicados.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _panel
var _gestor_barra: Node
# El objeto que de verdad queda en GestorInventario.items tras agregar_item()
# (no necesariamente el mismo Resource que se le pasó — ver GestorInventario).
var _pocion: DatosItem

var _ok_boton := false
var _ok_arrastre := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_probar_boton_accion()
		3:
			_probar_arrastre_a_vacia()
			return _informar()
	return false


func _montar() -> void:
	_gestor_barra = root.get_node("/root/GestorBarraRapida")
	var vacio: Array[DatosItem] = [null, null, null, null]
	_gestor_barra.casillas = vacio

	var gestor_inv := root.get_node("/root/GestorInventario")
	gestor_inv.items.clear()

	var pocion_nueva := DatosItem.new()
	pocion_nueva.name = "Poción de Prueba"
	pocion_nueva.type = 2  # CONSUMIBLE
	pocion_nueva.can_use = true
	gestor_inv.agregar_item(pocion_nueva)

	_panel = (load("res://escenas/ui/panel_os/paneles/inventario/PanelInventario.tscn") as PackedScene).instantiate()
	root.add_child(_panel)
	_panel.refrescar()

	_pocion = _buscar_slot_por_nombre(_panel.flow, "Poción de Prueba").item_data


func _probar_boton_accion() -> void:
	# El ítem ya está puesto en la casilla 2 de antes.
	_gestor_barra.casillas[2] = _pocion

	var slot := _buscar_slot_por_nombre(_panel.flow, "Poción de Prueba")
	_panel._update_details(slot)
	_panel._on_barra_rapida_button()

	var ocupadas := 0
	for c in _gestor_barra.casillas:
		if c == _pocion:
			ocupadas += 1
	_ok_boton = (ocupadas == 1) and (_gestor_barra.casillas[2] == _pocion)
	print("Tras presionar 'Añadir a barra rápida' con el ítem ya puesto (esperado: sigue solo en la casilla 2, sin duplicar): %s" % [_gestor_barra.casillas])


func _probar_arrastre_a_vacia() -> void:
	# Sigue en la casilla 2 (del paso anterior). Simular arrastrarlo a la
	# casilla 0 (vacía) desde la grilla general.
	var slot_origen := _buscar_slot_por_nombre(_panel.flow, "Poción de Prueba")
	var slot_destino_0 = _panel.quick_slots_inventario[0]
	slot_destino_0._drop_data(Vector2.ZERO, slot_origen)

	var ocupadas := 0
	var indice_final := -1
	for i in _gestor_barra.casillas.size():
		if _gestor_barra.casillas[i] == _pocion:
			ocupadas += 1
			indice_final = i
	_ok_arrastre = (ocupadas == 1) and (indice_final == 0)
	print("Tras arrastrarlo a la casilla 0 vacía (esperado: se quita de la 2 y queda solo en la 0): %s" % [_gestor_barra.casillas])


func _buscar_slot_por_nombre(flow: Node, nombre: String) -> Node:
	for hijo in flow.get_children():
		if hijo.item_data and hijo.item_data.name == nombre:
			return hijo
	return null


func _informar() -> bool:
	var exito := _ok_boton and _ok_arrastre
	print("PRUEBA BARRA RAPIDA SIN DUPLICADOS: %s" % ("OK" if exito else "FALLO"))
	quit(0 if exito else 1)
	return true
