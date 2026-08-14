# =============================================================================
# Prueba de la corrección al bug reportado: "cuando vas caminando y usás un
# consumible, se traba el juego y después de unos milisegundos el jugador
# hace tp a donde debería seguir caminando". La causa real era
# SlotConsumibleRapido._on_click() llamando PanelInventario.refrescar()
# SIEMPRE, sin importar si el panel estaba visible (PanelInventario nunca se
# destruye, solo se oculta — así que find_child() SIEMPRE lo encontraba).
# refrescar() reconstruye la grilla ENTERA del inventario (destruye e
# reinstancia un SlotItem por cada ítem que tenga el jugador) — con el panel
# cerrado (el caso normal de usar la barra rápida del HUD en pleno
# movimiento) eso era trabajo sincrónico tirado a la basura en el hilo
# principal. El freeze resultante pausaba toda la física por un instante;
# al descongelarse, el motor corre varios pasos de física de "recuperación"
# seguidos con la dirección que el joystick seguía sosteniendo — eso se ve
# como el jugador "tp"-eándose hacia adelante (caminando quieto no se nota:
# con dirección CERO no hay nada que recuperar).
#
# Cubre:
#   1. Usar un consumible de la barra rápida con el panel CERRADO no
#      reconstruye la grilla ahí mismo (mismo nodo de antes) — solo la
#      marca desactualizada (PanelInventario._grilla_desactualizada).
#   2. Al abrir el panel después, la grilla se reconstruye sola y muestra
#      la cantidad YA actualizada (sin quedar vieja/desincronizada).
#   3. Usar un consumible con el panel YA ABIERTO sigue refrescando de
#      inmediato, como siempre (no se retrasa sin necesidad).
#   godot --headless --path . --script res://pruebas/prueba_barra_rapida_uso_no_congela_panel_cerrado.gd
# =============================================================================
extends SceneTree

var _jugador
var _inventario
var _panel
var _slot_rapido
var _gestor_barra: Node
var _ticket: DatosItem

var _cerrado_no_reconstruye_ok := false
var _abrir_actualiza_solo_ok := false
var _abierto_refresca_de_inmediato_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_uso_con_panel_cerrado()
	_probar_al_abrir_se_actualiza()
	_probar_uso_con_panel_abierto()
	return _informar()


func _montar() -> void:
	# Jugador real (no solo GestorInventario a mano): ticket_1.tres otorga
	# experiencia además de consumirse, y ese camino (InventarioComponente
	# ._pedir_experiencia/_experiencia_local) necesita un ExperienciaComponente
	# hermano de verdad — con GestorInventario cayendo a su instancia de
	# respaldo (sin padre) esto revienta. Mismo molde que
	# prueba_panel_inventario_usar_mantiene_abierto.gd. Entra solo al grupo
	# "jugadores" (ver Jugador.gd/_ready), así Utils.jugador_local() —de la
	# que depende GestorInventario/SlotConsumibleRapido— lo encuentra solo.
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_inventario = _jugador.get_node("InventarioComponente")

	_gestor_barra = root.get_node("/root/GestorBarraRapida")
	_gestor_barra.casillas = [null, null, null, null] as Array[DatosItem]

	# can_use=true, curacion=0 y energia=0 — se consume siempre, sin
	# depender de que al jugador de prueba le falte vida/energía (ver
	# InventarioComponente._consumible_util).
	var ticket_original := load("res://recursos/items/recursos/ticket_1.tres") as DatosItem
	_inventario.agregar_item(ticket_original, 3, true)
	# El objeto que de verdad queda en items tras agregar_item() (no
	# necesariamente el mismo Resource pasado — ver GestorInventario).
	_ticket = _inventario.items[0]
	_gestor_barra.casillas[0] = _ticket

	_panel = (load("res://escenas/ui/panel_os/paneles/inventario/PanelInventario.tscn") as PackedScene).instantiate()
	root.add_child(_panel)
	_panel.refrescar()

	_slot_rapido = (load("res://escenas/ui/hud/SlotConsumibleRapido.tscn") as PackedScene).instantiate()
	_slot_rapido.slot_index = 0
	root.add_child(_slot_rapido)


func _slot_en_grilla() -> SlotItem:
	for slot: SlotItem in _panel.flow.get_children():
		if slot.item_data == _ticket:
			return slot
	return null


func _probar_uso_con_panel_cerrado() -> void:
	_panel.visible = false
	var slot_grilla_antes := _slot_en_grilla()

	_slot_rapido.slot_clicked.emit(_slot_rapido)

	print("Cantidad real tras usar con panel cerrado (esperado 2): %d" % _ticket.quantity)
	print("Grilla NO se tocó con el panel cerrado (mismo nodo, esperado true): %s" % \
		(_slot_en_grilla() == slot_grilla_antes))
	print("Panel marcado desactualizado (esperado true): %s" % _panel._grilla_desactualizada)
	_cerrado_no_reconstruye_ok = _ticket.quantity == 2 \
		and _slot_en_grilla() == slot_grilla_antes and _panel._grilla_desactualizada


func _probar_al_abrir_se_actualiza() -> void:
	_panel.visible = true

	var slot_grilla := _slot_en_grilla()
	var texto_cantidad: String = slot_grilla.get_node("QuantityLabel").text if slot_grilla else "<null>"
	print("Grilla muestra la cantidad correcta al abrir (esperado '2'): %s" % texto_cantidad)
	print("Panel ya no está marcado desactualizado (esperado true): %s" % (not _panel._grilla_desactualizada))
	_abrir_actualiza_solo_ok = slot_grilla != null and texto_cantidad == "2" \
		and not _panel._grilla_desactualizada


func _probar_uso_con_panel_abierto() -> void:
	var slot_grilla_antes := _slot_en_grilla()

	_slot_rapido.slot_clicked.emit(_slot_rapido)

	var slot_grilla_despues := _slot_en_grilla()
	print("Grilla SÍ se reconstruye de inmediato con el panel abierto (nodo distinto, esperado true): %s" % \
		(slot_grilla_despues != slot_grilla_antes))
	print("Cantidad real tras usar con panel abierto (esperado 1): %d" % _ticket.quantity)
	# QuantityLabel queda VACÍO en 1 (SlotItem.update_item solo lo muestra
	# por encima de 1, para no ensuciar cada ítem no apilado con un "1") —
	# a diferencia de qty_value del panel de detalle, que sí lo muestra
	# siempre (ver prueba_panel_inventario_usar_mantiene_abierto.gd).
	var texto_cantidad: String = slot_grilla_despues.get_node("QuantityLabel").text if slot_grilla_despues else "<null>"
	_abierto_refresca_de_inmediato_ok = slot_grilla_despues != null \
		and slot_grilla_despues != slot_grilla_antes and _ticket.quantity == 1 and texto_cantidad == ""


func _informar() -> bool:
	var exito := _cerrado_no_reconstruye_ok and _abrir_actualiza_solo_ok and _abierto_refresca_de_inmediato_ok
	print("  uso con panel cerrado no reconstruye la grilla: %s" % _cerrado_no_reconstruye_ok)
	print("  al abrir, la grilla se actualiza sola: %s" % _abrir_actualiza_solo_ok)
	print("  uso con panel abierto sigue refrescando de inmediato: %s" % _abierto_refresca_de_inmediato_ok)
	print("PRUEBA BARRA RAPIDA USO NO CONGELA PANEL CERRADO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
