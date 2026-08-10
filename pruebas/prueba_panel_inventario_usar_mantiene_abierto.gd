# =============================================================================
# Prueba de PanelInventario._on_use_button() — pedido explícito: usar un
# consumible que todavía tiene cantidad en el inventario NO debe cerrar el
# panel de detalles (antes se cerraba siempre, sin importar cuánto
# quedara). Solo debe cerrarse cuando la última unidad se gasta de verdad.
# Mismo criterio que prueba_ui_panel_tienda.gd: sin red real, emitiendo las
# señales de los propios botones (headless no puede simular clics de
# verdad, pero sí la lógica que esos clics disparan).
#   godot --headless --path . --script res://pruebas/prueba_panel_inventario_usar_mantiene_abierto.gd
# =============================================================================
extends SceneTree

var _jugador
var _inventario
var _panel: Control

var _primer_uso_mantiene_panel_abierto_ok := false
var _segundo_uso_agota_y_cierra_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_primer_uso_mantiene_abierto()
	_probar_segundo_uso_agota_y_cierra()
	return _informar()


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_inventario = _jugador.get_node("InventarioComponente")

	# Ticket: can_use=true, curacion=0 y energia=0 — a propósito, no
	# zanahoria/poción: esas SOLO se consumen de verdad si a el jugador le
	# falta esa vida/energía (ver InventarioComponente._consumible_util), y
	# un jugador recién armado en la prueba arranca con la vida llena, así
	# que usarlas sería un no-op y quantity nunca bajaría.
	var ticket := load("res://recursos/items/recursos/ticket_1.tres") as DatosItem
	_inventario.agregar_item(ticket, 2, true)

	_panel = (load("res://escenas/ui/panel_os/paneles/inventario/PanelInventario.tscn") as PackedScene).instantiate()
	root.add_child(_panel)


func _slot_por_nombre(nombre: String) -> SlotItem:
	for slot: SlotItem in _panel.flow.get_children():
		if slot.item_data and slot.item_data.name == nombre:
			return slot
	return null


func _probar_primer_uso_mantiene_abierto() -> void:
	var slot := _slot_por_nombre("Ticket Común")
	slot.slot_clicked.emit(slot)
	_panel.use_action_button.pressed.emit()
	# refrescar() reconstruye la grilla entera — item_data_details debe
	# apuntar al SlotItem NUEVO (mismo DatosItem, nodo distinto), no al
	# viejo ya destruido.
	var slot_nuevo := _slot_por_nombre("Ticket Común")
	_primer_uso_mantiene_panel_abierto_ok = _panel.detail_panel_margin.visible \
		and _panel.item_data_details == slot_nuevo \
		and _panel.qty_value.text == "1"
	print("Usar con cantidad restante mantiene el panel abierto (esperado true): %s" % _primer_uso_mantiene_panel_abierto_ok)


func _probar_segundo_uso_agota_y_cierra() -> void:
	_panel.use_action_button.pressed.emit()
	_segundo_uso_agota_y_cierra_ok = not _panel.detail_panel_margin.visible \
		and _panel.item_data_details == null \
		and _slot_por_nombre("Ticket Común") == null
	print("Usar la última unidad agota el ítem y cierra el panel (esperado true): %s" % _segundo_uso_agota_y_cierra_ok)


func _informar() -> bool:
	var exito := _primer_uso_mantiene_panel_abierto_ok and _segundo_uso_agota_y_cierra_ok
	print("PRUEBA PANEL INVENTARIO USAR MANTIENE ABIERTO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
