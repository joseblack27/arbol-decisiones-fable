# =============================================================================
# Prueba de PanelCofre — que se abra solo al recibir BusEventos.cofre_
# solicitado (mismo patrón que PanelDialogo/PanelTienda), puebla las dos
# GrillaObjetos SIN casillas precreadas (el cofre arranca vacío si su
# tabla_botin no siembra nada — pedido del usuario: "no quiero slots
# precreados") y que el detalle se actualice al tocar un ítem en
# cualquiera de las dos. refrescar_inventario() sigue existiendo para
# cuando el inventario cambia por otra vía (loot recibido con el panel
# abierto).
#   godot --headless --path . --script res://pruebas/prueba_panel_cofre.gd
# =============================================================================
extends SceneTree

const _ID_COFRE := "cofre_panel_de_prueba"

var _jugador
var _inventario
var _panel
var _gestor_cofres: Node

var _se_abre_por_bus_eventos_ok := false
var _grilla_cofre_sin_slots_precreados_ok := false
var _grilla_jugador_tiene_los_items_reales_ok := false
var _refrescar_inventario_reconstruye_ok := false
var _detalle_al_tocar_item_ok := false
var _arrastre_ida_y_vuelta_por_panel_real_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_abrir()
	_probar_refrescar_inventario()
	_probar_detalle_al_tocar_item()
	_probar_arrastre_ida_y_vuelta_por_panel_real()
	return _informar()


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_inventario = _jugador.get_node("InventarioComponente")

	var pocion := load("res://recursos/items/consumibles/pocion_vida.tres") as DatosItem
	_inventario.agregar_item(pocion, 1, true)

	# tabla_botin VACÍA a propósito: sin nada que sembrar, el cofre debe
	# arrancar sin NINGUNA casilla (no 8 vacías precreadas).
	var datos := DatosCofre.new()
	datos.id = _ID_COFRE
	datos.capacidad = 8
	_gestor_cofres = root.get_node("/root/GestorCofres")
	_gestor_cofres.catalogo.append(datos)

	_panel = (load("res://escenas/ui/panel_cofre/PanelCofre.tscn") as PackedScene).instantiate()
	root.add_child(_panel)


func _probar_abrir() -> void:
	print("Panel arranca oculto (esperado true): %s" % (not _panel.visible))
	var arrancaba_oculto: bool = not _panel.visible

	root.get_node("/root/BusEventos").cofre_solicitado.emit(_ID_COFRE, "Cofre de Prueba")

	print("Se abre solo al recibir cofre_solicitado (esperado true): %s" % _panel.visible)
	print("Título muestra el nombre recibido (esperado 'Cofre de Prueba'): %s" % _panel._titulo_cofre.text)
	_se_abre_por_bus_eventos_ok = arrancaba_oculto and _panel.visible \
		and _panel._titulo_cofre.text == "Cofre de Prueba"

	print("Grilla del cofre SIN slots precreados, vacía (esperado 0): %d" % \
		_panel._grilla_cofre._contenedor.get_child_count())
	_grilla_cofre_sin_slots_precreados_ok = _panel._grilla_cofre._contenedor.get_child_count() == 0

	print("Grilla de inventario muestra los ítems reales (esperado 1): %d" % \
		_panel._grilla_jugador._contenedor.get_child_count())
	_grilla_jugador_tiene_los_items_reales_ok = _panel._grilla_jugador._contenedor.get_child_count() == 1


func _probar_refrescar_inventario() -> void:
	var hoja := load("res://recursos/items/recursos/hoja_1.tres") as DatosItem
	_inventario.agregar_item(hoja, 1, true)
	_panel.refrescar_inventario()
	print("refrescar_inventario() refleja un ítem nuevo (esperado 2): %d" % \
		_panel._grilla_jugador._contenedor.get_child_count())
	_refrescar_inventario_reconstruye_ok = _panel._grilla_jugador._contenedor.get_child_count() == 2


## Bug real reportado en su momento: "no se pueden ver los detalles de
## los objetos" — verifica que GrillaObjetos.item_tocado esté de verdad
## CONECTADO a PanelCofre._mostrar_detalle. Emite la señal directo sobre
## la grilla en vez de simular gui_input (mismo criterio que el resto de
## la suite).
func _probar_detalle_al_tocar_item() -> void:
	_panel._grilla_jugador.item_tocado.emit(_inventario.items[0])
	print("Tocar un ítem del inventario muestra su nombre en el detalle (esperado 'Poción de Vida'): %s" % \
		_panel._nombre_item.text)
	print("... y su descripción (esperado no vacía): %s" % (_panel._descripcion_item.text != ""))
	_detalle_al_tocar_item_ok = _panel._nombre_item.text == "Poción de Vida" and _panel._descripcion_item.text != ""


## Bug real reportado: "Cannot call method 'get_root' on a null value" al
## pasar una hoja del inventario al cofre y devolverla — causa real y fix
## completo descriptos en el historial de CasillaObjeto.gd/SlotItem.gd.
## Verifica que el arrastre siga sin reventar a través de un PanelCofre
## real, ahora vía el ScrollContainer de cada grilla (pedido del usuario:
## "quien debe recibir el arrastre... debe ser el scroll container") en
## vez de casilla a casilla.
func _probar_arrastre_ida_y_vuelta_por_panel_real() -> void:
	var origen_inventario = null
	for casilla in _panel._grilla_jugador._contenedor.get_children():
		if casilla.item_data and casilla.item_data.name == "Hoja Verde":
			origen_inventario = casilla
			break
	var scroll_cofre = _panel._grilla_cofre.get_node("%ScrollContainer")
	scroll_cofre._drop_data(Vector2.ZERO, origen_inventario)

	var cofres = _jugador.get_node("CofresComponente")
	var contenido_cofre = cofres.obtener_contenido(_ID_COFRE)
	var ida_ok := false
	for item: DatosItem in contenido_cofre:
		if item.name == "Hoja Verde":
			ida_ok = true
			break
	print("Inventario -> cofre (a través del panel real, vía ScrollContainer): la hoja entra (esperado true): %s" % ida_ok)

	# notificar_cambio() ya reconstruyó _grilla_jugador (el nodo viejo de
	# arriba ya no existe, quedó solo la poción) — cualquier casilla del
	# cofre sirve de origen para el viaje de vuelta.
	var origen_cofre = _panel._grilla_cofre._contenedor.get_child(0)
	var scroll_inventario = _panel._grilla_jugador.get_node("%ScrollContainer")
	scroll_inventario._drop_data(Vector2.ZERO, origen_cofre)

	var vuelve_ok := false
	for item: DatosItem in _inventario.items:
		if item.name == "Hoja Verde":
			vuelve_ok = true
			break
	print("Cofre -> inventario (a través del panel real, vía ScrollContainer): no revienta y la hoja vuelve (esperado true): %s" % vuelve_ok)

	_arrastre_ida_y_vuelta_por_panel_real_ok = ida_ok and vuelve_ok


func _informar() -> bool:
	var exito := _se_abre_por_bus_eventos_ok and _grilla_cofre_sin_slots_precreados_ok \
		and _grilla_jugador_tiene_los_items_reales_ok and _refrescar_inventario_reconstruye_ok \
		and _detalle_al_tocar_item_ok and _arrastre_ida_y_vuelta_por_panel_real_ok
	print("  se abre por BusEventos.cofre_solicitado: %s" % _se_abre_por_bus_eventos_ok)
	print("  grilla del cofre sin slots precreados: %s" % _grilla_cofre_sin_slots_precreados_ok)
	print("  grilla de inventario: ítems reales: %s" % _grilla_jugador_tiene_los_items_reales_ok)
	print("  refrescar_inventario() reconstruye: %s" % _refrescar_inventario_reconstruye_ok)
	print("  detalle al tocar un ítem: %s" % _detalle_al_tocar_item_ok)
	print("  arrastre ida y vuelta por el panel real: %s" % _arrastre_ida_y_vuelta_por_panel_real_ok)
	print("PRUEBA PANEL COFRE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
