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
var _detalle_arranca_invisible_ok := false
var _refrescar_inventario_reconstruye_ok := false
var _detalle_al_tocar_item_ok := false
var _arrastre_ida_y_vuelta_por_panel_real_ok := false
var _boton_cerrar_de_grilla_cierra_panel_ok := false
var _tomar_todo_ok := false
var _scroll_a_cada_lado_ok := false
var _filtro_categorias_activo_por_defecto_ok := false
var _doble_tap_transferencia_rapida_ok := false
var _estado_vacio_ok := false
var _orden_activo_por_defecto_ok := false
var _busqueda_activa_por_defecto_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_abrir()
	_probar_estado_vacio()
	_probar_refrescar_inventario()
	_probar_detalle_al_tocar_item()
	_probar_arrastre_ida_y_vuelta_por_panel_real()
	_probar_boton_cerrar_de_grilla_cierra_panel()
	_probar_tomar_todo()
	_probar_scroll_a_cada_lado()
	_probar_doble_tap_transferencia_rapida()
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
	print("Título muestra el nombre recibido (esperado 'Cofre de Prueba'): %s" % _panel._grilla_cofre.titulo)
	_se_abre_por_bus_eventos_ok = arrancaba_oculto and _panel.visible \
		and _panel._grilla_cofre.titulo == "Cofre de Prueba"

	print("Grilla del cofre SIN slots precreados, vacía (esperado 0): %d" % \
		_panel._grilla_cofre._contenedor.get_child_count())
	_grilla_cofre_sin_slots_precreados_ok = _panel._grilla_cofre._contenedor.get_child_count() == 0

	# Pedido del usuario: "activale los filtros al cofre de la ciudad...
	# por defecto debe venir activada" + "el que tiene los items del
	# inventario también activaselo" — sin tocar nada, ya visibles al abrir
	# EN LAS DOS grillas.
	print("Filtro de categorías del cofre viene activado por defecto (esperado true): %s" % \
		_panel._grilla_cofre._tabs_filtro.visible)
	print("Filtro de categorías del inventario viene activado por defecto (esperado true): %s" % \
		_panel._grilla_jugador._tabs_filtro.visible)
	_filtro_categorias_activo_por_defecto_ok = _panel._grilla_cofre._tabs_filtro.visible \
		and _panel._grilla_jugador._tabs_filtro.visible

	# Pedido del usuario: "activale [el orden] en las dos grillas del
	# cofre" — mismo criterio, ya visible al abrir en las dos.
	print("Selector de orden del cofre viene activado por defecto (esperado true): %s" % \
		_panel._grilla_cofre._fila_orden.visible)
	print("Selector de orden del inventario viene activado por defecto (esperado true): %s" % \
		_panel._grilla_jugador._fila_orden.visible)
	_orden_activo_por_defecto_ok = _panel._grilla_cofre._fila_orden.visible \
		and _panel._grilla_jugador._fila_orden.visible

	# Pedido del usuario: "me interesa la búsqueda por texto" — mismo
	# criterio, ya visible al abrir en las dos.
	print("Campo de búsqueda del cofre viene activado por defecto (esperado true): %s" % \
		_panel._grilla_cofre._campo_busqueda.visible)
	print("Campo de búsqueda del inventario viene activado por defecto (esperado true): %s" % \
		_panel._grilla_jugador._campo_busqueda.visible)
	_busqueda_activa_por_defecto_ok = _panel._grilla_cofre._campo_busqueda.visible \
		and _panel._grilla_jugador._campo_busqueda.visible

	print("Grilla de inventario muestra los ítems reales (esperado 1): %d" % \
		_panel._grilla_jugador._contenedor.get_child_count())
	_grilla_jugador_tiene_los_items_reales_ok = _panel._grilla_jugador._contenedor.get_child_count() == 1

	print("Panel de detalle arranca invisible, sin nada seleccionado (esperado 0.0): %.1f" % \
		_panel._panel_detalle.modulate.a)
	_detalle_arranca_invisible_ok = _panel._panel_detalle.modulate.a == 0.0


## Pedido del usuario: "agrega el estado vacío" — el cofre arranca sin
## ítems (ver _montar, tabla_botin vacía) y debe mostrar la etiqueta
## personalizada del panel; agregar un ítem la oculta, sacarlo la vuelve a
## mostrar. El inventario del jugador arranca CON un ítem (la poción), así
## que su estado vacío debe estar oculto desde el principio.
func _probar_estado_vacio() -> void:
	print("Cofre vacío muestra el estado vacío (esperado true): %s" % \
		_panel._grilla_cofre._etiqueta_vacia.visible)
	print("... con el texto del panel (esperado 'El cofre está vacío'): %s" % \
		_panel._grilla_cofre._etiqueta_vacia.text)
	var cofre_vacio_muestra_estado_ok: bool = _panel._grilla_cofre._etiqueta_vacia.visible \
		and _panel._grilla_cofre._etiqueta_vacia.text == "El cofre está vacío"

	var cofres = _jugador.get_node("CofresComponente")
	var pocion := load("res://recursos/items/consumibles/pocion_vida.tres") as DatosItem
	cofres.agregar(_ID_COFRE, pocion)
	_panel._grilla_cofre.notificar_cambio()
	print("Con un ítem adentro, el estado vacío se oculta (esperado false): %s" % \
		_panel._grilla_cofre._etiqueta_vacia.visible)
	var con_item_oculta_estado_ok: bool = not _panel._grilla_cofre._etiqueta_vacia.visible

	cofres.quitar(_ID_COFRE, pocion)
	_panel._grilla_cofre.notificar_cambio()
	print("Al vaciarse de nuevo, el estado vacío reaparece (esperado true): %s" % \
		_panel._grilla_cofre._etiqueta_vacia.visible)
	var vuelve_a_mostrar_estado_ok: bool = _panel._grilla_cofre._etiqueta_vacia.visible

	print("Inventario con ítems no muestra el estado vacío (esperado false): %s" % \
		_panel._grilla_jugador._etiqueta_vacia.visible)
	var jugador_con_items_oculta_estado_ok: bool = not _panel._grilla_jugador._etiqueta_vacia.visible

	_estado_vacio_ok = cofre_vacio_muestra_estado_ok and con_item_oculta_estado_ok \
		and vuelve_a_mostrar_estado_ok and jugador_con_items_oculta_estado_ok


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
	print("... y su tipo/cantidad, mismo diseño que PanelInventario (esperado no '-'): %s / %s" % \
		[_panel._valor_tipo.text, _panel._valor_cantidad.text])
	print("... y el panel de detalle se hace visible (esperado 1.0): %.1f" % _panel._panel_detalle.modulate.a)
	_detalle_al_tocar_item_ok = _panel._nombre_item.text == "Poción de Vida" and _panel._descripcion_item.text != "" \
		and _panel._valor_tipo.text != "-" and _panel._valor_cantidad.text != "-" \
		and _panel._panel_detalle.modulate.a == 1.0


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


## Pedido del usuario: "coloca en la vista de GrillaObjeto un boton de
## cerrar, que cuando se presione oculte toda la vista, osea hara lo mismo
## que el boton que ya esta de salir". Verifica que AMBAS grillas (cofre e
## inventario) muestren su botón (mostrar_boton_cerrar = true en el .tscn)
## y que su señal cerrar_solicitado esté de verdad conectada a _cerrar().
func _probar_boton_cerrar_de_grilla_cierra_panel() -> void:
	print("Botón cerrar visible en GrillaCofre (esperado true): %s" % _panel._grilla_cofre._boton_cerrar.visible)
	print("Botón cerrar visible en GrillaJugador (esperado true): %s" % _panel._grilla_jugador._boton_cerrar.visible)
	var botones_visibles_ok: bool = _panel._grilla_cofre._boton_cerrar.visible and _panel._grilla_jugador._boton_cerrar.visible

	_panel._grilla_cofre.cerrar_solicitado.emit()
	print("cerrar_solicitado de GrillaCofre oculta el panel (esperado true): %s" % (not _panel.visible))
	var cierra_desde_cofre_ok: bool = not _panel.visible

	root.get_node("/root/BusEventos").cofre_solicitado.emit(_ID_COFRE, "Cofre de Prueba")
	_panel._grilla_jugador.cerrar_solicitado.emit()
	print("cerrar_solicitado de GrillaJugador oculta el panel (esperado true): %s" % (not _panel.visible))
	var cierra_desde_inventario_ok: bool = not _panel.visible

	_boton_cerrar_de_grilla_cierra_panel_ok = botones_visibles_ok and cierra_desde_cofre_ok and cierra_desde_inventario_ok


## Pedido del usuario: "un boton de 'Tomar todo' que solo se muestre en el
## inventario del cofre, y pase todo al inventario" — verifica que el
## botón esté visible SOLO en GrillaCofre (no en GrillaJugador) y que
## presionarlo (emite tomar_todo_solicitado, ver GrillaObjetos) vacíe el
## cofre entero hacia el inventario.
func _probar_tomar_todo() -> void:
	root.get_node("/root/BusEventos").cofre_solicitado.emit(_ID_COFRE, "Cofre de Prueba")

	print("Botón 'Tomar todo' visible en GrillaCofre (esperado true): %s" % \
		_panel._grilla_cofre._boton_tomar_todo.visible)
	print("Botón 'Tomar todo' NO visible en GrillaJugador (esperado false): %s" % \
		_panel._grilla_jugador._boton_tomar_todo.visible)
	var boton_solo_en_cofre_ok: bool = _panel._grilla_cofre._boton_tomar_todo.visible \
		and not _panel._grilla_jugador._boton_tomar_todo.visible

	# Mete la hoja al cofre directo (sin arrastre, no es lo que se prueba
	# acá) para tener algo real que "tomar todo".
	var cofres = _jugador.get_node("CofresComponente")
	var hoja_actual: DatosItem = null
	for item: DatosItem in _inventario.items:
		if item.name == "Hoja Verde":
			hoja_actual = item
			break
	_inventario.quitar_item(hoja_actual)
	cofres.agregar(_ID_COFRE, hoja_actual)
	_panel._grilla_cofre.notificar_cambio()
	_panel._grilla_jugador.notificar_cambio()

	_panel._grilla_cofre.tomar_todo_solicitado.emit()

	print("'Tomar todo' vacía el cofre (esperado 0): %d" % cofres.obtener_contenido(_ID_COFRE).size())
	var cofre_vacio_ok: bool = cofres.obtener_contenido(_ID_COFRE).size() == 0

	var hoja_de_vuelta := false
	for item: DatosItem in _inventario.items:
		if item.name == "Hoja Verde":
			hoja_de_vuelta = true
			break
	print("... y la hoja vuelve al inventario (esperado true): %s" % hoja_de_vuelta)

	_tomar_todo_ok = boton_solo_en_cofre_ok and cofre_vacio_ok and hoja_de_vuelta


## Pedido del usuario: "un scroll a cada lado... cuando sea del inventario
## del jugador muestre el scroll derecho y cuando sea el del cofre muestre
## el scroll izquierdo, para dar un buen diseño para los dedos" — verifica
## que BarraDesplazamientoV quede primera (izquierda) en GrillaCofre
## (scroll_a_la_izquierda = true en el .tscn) y última (derecha) en
## GrillaJugador (default false).
func _probar_scroll_a_cada_lado() -> void:
	var barra_cofre = _panel._grilla_cofre._barra_desplazamiento
	var hbox_cofre: Node = barra_cofre.get_parent()
	print("Scroll del cofre queda primero, a la izquierda (esperado 0): %d" % \
		hbox_cofre.get_children().find(barra_cofre))
	var scroll_cofre_izquierda_ok: bool = hbox_cofre.get_child(0) == barra_cofre

	var barra_jugador = _panel._grilla_jugador._barra_desplazamiento
	var hbox_jugador: Node = barra_jugador.get_parent()
	print("Scroll del inventario queda último, a la derecha (esperado %d): %d" % [
		hbox_jugador.get_child_count() - 1, hbox_jugador.get_children().find(barra_jugador)
	])
	var scroll_jugador_derecha_ok: bool = hbox_jugador.get_child(hbox_jugador.get_child_count() - 1) == barra_jugador

	_scroll_a_cada_lado_ok = scroll_cofre_izquierda_ok and scroll_jugador_derecha_ok


## Pedido del usuario: "hazme el doble-tap para transferencia rápida" —
## dos toques seguidos sobre una casilla del inventario deben mandar el
## ítem al cofre (grilla_destino_rapida, conectado en PanelCofre._ready()),
## la MISMA lógica que ya usa el arrastre. Usa una batería (no una hoja):
## a esta altura el inventario ya puede tener una hoja de pruebas
## anteriores, y agregar_item() FUSIONARÍA (quantity>1 dispara PopupCantidad
## en vez de mover directo, ver GrillaObjetos.recibir_desde) — un ítem sin
## ninguna entrada previa mantiene esto en el camino simple sin popup.
func _probar_doble_tap_transferencia_rapida() -> void:
	var bateria := load("res://recursos/items/recursos/bateria_1.tres") as DatosItem
	_inventario.agregar_item(bateria, 1, true)
	_panel._grilla_jugador.notificar_cambio()

	var casilla = null
	for c in _panel._grilla_jugador._contenedor.get_children():
		if c.item_data and c.item_data.name == bateria.name:
			casilla = c
			break

	casilla._procesar_tap()
	casilla._procesar_tap()

	var cofres = _jugador.get_node("CofresComponente")
	var entro_al_cofre := false
	for item: DatosItem in cofres.obtener_contenido(_ID_COFRE):
		if item.name == bateria.name:
			entro_al_cofre = true
			break
	print("Doble-tap sobre una casilla del inventario la manda al cofre (esperado true): %s" % entro_al_cofre)
	_doble_tap_transferencia_rapida_ok = entro_al_cofre


func _informar() -> bool:
	var exito := _se_abre_por_bus_eventos_ok and _grilla_cofre_sin_slots_precreados_ok \
		and _grilla_jugador_tiene_los_items_reales_ok and _detalle_arranca_invisible_ok \
		and _refrescar_inventario_reconstruye_ok and _detalle_al_tocar_item_ok \
		and _arrastre_ida_y_vuelta_por_panel_real_ok and _boton_cerrar_de_grilla_cierra_panel_ok \
		and _tomar_todo_ok and _scroll_a_cada_lado_ok and _filtro_categorias_activo_por_defecto_ok \
		and _doble_tap_transferencia_rapida_ok and _estado_vacio_ok and _orden_activo_por_defecto_ok \
		and _busqueda_activa_por_defecto_ok
	print("  se abre por BusEventos.cofre_solicitado: %s" % _se_abre_por_bus_eventos_ok)
	print("  grilla del cofre sin slots precreados: %s" % _grilla_cofre_sin_slots_precreados_ok)
	print("  grilla de inventario: ítems reales: %s" % _grilla_jugador_tiene_los_items_reales_ok)
	print("  panel de detalle arranca invisible: %s" % _detalle_arranca_invisible_ok)
	print("  refrescar_inventario() reconstruye: %s" % _refrescar_inventario_reconstruye_ok)
	print("  detalle al tocar un ítem: %s" % _detalle_al_tocar_item_ok)
	print("  arrastre ida y vuelta por el panel real: %s" % _arrastre_ida_y_vuelta_por_panel_real_ok)
	print("  botón cerrar de cada grilla cierra el panel: %s" % _boton_cerrar_de_grilla_cierra_panel_ok)
	print("  botón 'Tomar todo' solo en el cofre, mueve todo: %s" % _tomar_todo_ok)
	print("  scroll a cada lado (cofre izquierda, inventario derecha): %s" % _scroll_a_cada_lado_ok)
	print("  filtro de categorías del cofre activo por defecto: %s" % _filtro_categorias_activo_por_defecto_ok)
	print("  doble-tap transferencia rápida: %s" % _doble_tap_transferencia_rapida_ok)
	print("  estado vacío: %s" % _estado_vacio_ok)
	print("  selector de orden activo por defecto: %s" % _orden_activo_por_defecto_ok)
	print("  campo de búsqueda activo por defecto: %s" % _busqueda_activa_por_defecto_ok)
	print("PRUEBA PANEL COFRE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
