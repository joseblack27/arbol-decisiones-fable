# =============================================================================
# Prueba de PanelTienda — selección desde cualquiera de las dos grillas
# (mercancía del comerciante / inventario propio) llena el panel central
# con el ítem correcto y un botón Comprar/Vender según de qué lado salió;
# el selector de cantidad respeta su tope en cada sentido (10 al comprar,
# ver _TOPE_CANTIDAD_COMPRA; lo que se tiene al vender); y comprar/vender
# de verdad actualiza créditos + ambas grillas. Mismo criterio que
# prueba_ui_misiones_botones.gd: sin red real, emitiendo las señales de los
# propios botones/slots (headless no puede simular clics de verdad, pero sí
# puede probar la lógica que esos clics disparan).
#   godot --headless --path . --script res://pruebas/prueba_ui_panel_tienda.gd
# =============================================================================
extends SceneTree

var _jugador
var _creditos
var _inventario
var _panel: Control
var _datos_tienda: DatosTienda
var _botiquin: DatosItem
var _escudo: DatosItem
var _tomo: DatosItem

var _slot_comerciante: SlotItem
var _titulo_npc_y_inventario_ok := false
var _panel_detalle_oculto_al_abrir_ok := false
var _click_comerciante_muestra_comprar_ok := false
var _brillo_aplicado_al_slot_comerciante_ok := false
var _brillo_se_mueve_al_elegir_otro_ok := false
var _tope_cantidad_compra_ok := false
var _bajar_cantidad_ok := false
var _comprar_descuenta_y_agrega_ok := false
var _click_jugador_muestra_vender_ok := false
var _refresco_externo_reselecciona_ok := false
var _tope_cantidad_venta_ok := false
var _vender_suma_y_limpia_seleccion_al_agotarse_ok := false
var _estadisticas_equipable_ok := false
var _item_sin_valor_deshabilita_boton_ok := false
var _filtro_categoria_ok := false
var _salir_oculta_el_panel_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_titulo_npc_y_inventario()
	_probar_panel_detalle_oculto_al_abrir()
	_probar_click_comerciante()
	_probar_tope_cantidad_compra()
	_probar_bajar_cantidad_y_comprar()
	_probar_click_jugador_vendible()
	_probar_refresco_externo_reselecciona()
	_probar_tope_cantidad_venta_y_vender()
	_probar_estadisticas_equipable()
	_probar_item_sin_valor()
	_probar_filtro_categoria()
	_probar_salir()
	return _informar()


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_creditos = _jugador.get_node("CreditosComponente")
	_inventario = _jugador.get_node("InventarioComponente")
	_creditos.agregar_creditos(100)

	_botiquin = load("res://recursos/items/consumibles/botiquin.tres") as DatosItem
	_inventario.agregar_item(_botiquin, 1, true)
	# Ahora vendible (valor=70, ver escudo.tres) — sirve para probar que un
	# equipable elegido muestra sus bonos igual que en el inventario.
	_escudo = load("res://recursos/items/equipables/escudo.tres") as DatosItem
	_inventario.agregar_item(_escudo, 1, true)
	# Tipo PASIVA, sin valor de venta asignado a propósito (mismo caso real
	# que un ítem de misión) — reemplaza al escudo como ejemplo "no
	# vendible" ahora que el escudo sí tiene precio.
	_tomo = load("res://recursos/items/pasivas/tomo_cosecha_de_vida.tres") as DatosItem
	_inventario.agregar_item(_tomo, 1, true)

	var item_tienda := ItemTienda.new()
	item_tienda.item = load("res://recursos/items/consumibles/pocion_vida.tres") as DatosItem
	item_tienda.precio = 20
	_datos_tienda = DatosTienda.new()
	_datos_tienda.items_en_venta = [item_tienda]

	_panel = (load("res://escenas/ui/panel_tienda/PanelTienda.tscn") as PackedScene).instantiate()
	root.add_child(_panel)
	_panel._abrir(_datos_tienda, "Vendedor de Pradera")


## Npc.nombre() llega hasta acá vía BusEventos.tienda_solicitada (ver
## PanelDialogo._ejecutar_accion) — el título de la izquierda debe ser
## quien vende de verdad, no un genérico fijo. El de la derecha SIEMPRE
## dice "Inventario" (pedido explícito, reemplazó a "Tu Inventario").
func _probar_titulo_npc_y_inventario() -> void:
	var titulo_jugador: Label = _panel.get_node( \
		"Fondo/Margin/VBoxRaiz/HBoxColumnas/PanelJugador/Margin/VBox/Titulo")
	_titulo_npc_y_inventario_ok = _panel._titulo_comerciante.text == "Vendedor de Pradera" \
		and titulo_jugador.text == "Inventario"
	print("Título comerciante = nombre del NPC, título jugador = Inventario (esperado true): %s" % _titulo_npc_y_inventario_ok)


func _item_jugador_por_nombre(nombre: String) -> DatosItem:
	for item: DatosItem in _inventario.items:
		if item.name == nombre:
			return item
	return null


## El panel central no se saca del layout con visible=false (eso encogería
## su columna a 0 y HBoxColumnas estiraría comerciante/jugador para llenar
## el hueco, justo lo que NO se quiere — pedido explícito del usuario) —
## se apaga con modulate.a mientras sigue ocupando su ancho fijo.
func _probar_panel_detalle_oculto_al_abrir() -> void:
	_panel_detalle_oculto_al_abrir_ok = _panel._panel_detalle.modulate.a == 0.0 \
		and _panel._panel_detalle.visible \
		and _panel._panel_detalle.custom_minimum_size.x == 230.0
	print("Panel central invisible pero ocupando su lugar sin selección (esperado true): %s" % _panel_detalle_oculto_al_abrir_ok)


func _probar_click_comerciante() -> void:
	_slot_comerciante = _panel._grilla_comerciante.get_child(0)
	_slot_comerciante.slot_clicked.emit(_slot_comerciante)
	_click_comerciante_muestra_comprar_ok = _panel._boton_accion.text == "Comprar" \
		and not _panel._boton_accion.disabled \
		and _panel._nombre_item.text == "Poción de Vida" \
		and _panel._valor_precio.text == "20 créditos" \
		and _panel._panel_detalle.modulate.a == 1.0
	print("Elegir ítem del comerciante muestra Comprar con su precio (esperado true): %s" % _click_comerciante_muestra_comprar_ok)

	_brillo_aplicado_al_slot_comerciante_ok = _slot_comerciante.modulate.r > 1.0
	print("El slot elegido del comerciante tiene el brillo aplicado (esperado true): %s" % _brillo_aplicado_al_slot_comerciante_ok)


## _TOPE_CANTIDAD_COMPRA = 10 — comprar_item() no tiene parámetro de
## cantidad (ver TiendaComponente), la UI la resuelve en un bucle de N
## llamadas, así que el tope existe para no spamear una RPC por unidad.
func _probar_tope_cantidad_compra() -> void:
	for _i in 15:
		_panel._boton_mas.pressed.emit()
	_tope_cantidad_compra_ok = _panel._valor_cantidad.text == "10" and _panel._valor_precio.text == "200 créditos"
	print("Subir cantidad de compra topa en 10 (esperado true): %s" % _tope_cantidad_compra_ok)


func _probar_bajar_cantidad_y_comprar() -> void:
	for _i in 8:
		_panel._boton_menos.pressed.emit()
	_bajar_cantidad_ok = _panel._valor_cantidad.text == "2" and _panel._valor_precio.text == "40 créditos"
	print("Bajar cantidad de compra a 2 (esperado true): %s" % _bajar_cantidad_ok)

	_panel._boton_accion.pressed.emit()
	var pocion := _item_jugador_por_nombre("Poción de Vida")
	_comprar_descuenta_y_agrega_ok = _creditos.obtener_creditos() == 60 \
		and pocion != null and pocion.quantity == 2 \
		and _panel._grilla_jugador.get_child_count() == 4  # botiquín, escudo, tomo, poción
	print("Comprar x2 descuenta 40 créditos (100 -> 60) y agrega 2 pociones (esperado true): %s" % _comprar_descuenta_y_agrega_ok)


func _probar_click_jugador_vendible() -> void:
	var slot := _slot_jugador_por_nombre("Botiquín")
	slot.slot_clicked.emit(slot)
	var pago_esperado := int(_botiquin.valor * TiendaComponente.PORCENTAJE_VENTA)
	_click_jugador_muestra_vender_ok = _panel._boton_accion.text == "Vender" \
		and not _panel._boton_accion.disabled \
		and _panel._nombre_item.text == "Botiquín" \
		and _panel._valor_precio.text == "%d créditos" % pago_esperado
	print("Elegir ítem propio vendible muestra Vender con su precio (esperado true): %s" % _click_jugador_muestra_vender_ok)

	# _slot_comerciante sigue siendo un nodo válido (nunca se reconstruye esa
	# grilla) — elegir del OTRO lado debe haberle sacado el brillo.
	_brillo_se_mueve_al_elegir_otro_ok = _slot_comerciante.modulate.r == 1.0
	print("Elegir un ítem propio le saca el brillo al del comerciante (esperado true): %s" % _brillo_se_mueve_al_elegir_otro_ok)


## _refrescar_grilla_jugador() reconstruye la grilla ENTERA (nodos SlotItem
## nuevos) cada vez que el inventario cambia, incluso por una llegada ajena
## a la venta en curso (loot de otra fuente) — sin volver a ubicar el slot
## nuevo que corresponde al mismo ítem elegido, el resaltado se quedaba en
## el nodo viejo ya destruido en vez de seguir al ítem.
func _probar_refresco_externo_reselecciona() -> void:
	var zanahoria := load("res://recursos/items/consumibles/zanahoria.tres") as DatosItem
	_inventario.agregar_item(zanahoria)  # silencioso=false: emite BusEventos.item_agregado.
	var slot_nuevo := _slot_jugador_por_nombre("Botiquín")
	# _item_jugador_actual se compara contra slot_nuevo.item_data, no contra
	# _botiquin (el recurso ORIGINAL cargado en _montar) — agregar_item()
	# siempre guarda un duplicate(), nunca el mismo objeto por identidad
	# (mismo detalle que ya advierte prueba_tienda_comprar_item.gd).
	_refresco_externo_reselecciona_ok = _panel._origen_seleccion == "vender" \
		and slot_nuevo != null and _panel._item_jugador_actual == slot_nuevo.item_data \
		and _panel._slot_seleccionado == slot_nuevo \
		and _panel._nombre_item.text == "Botiquín"
	print("Refresco por ítem ajeno mantiene la selección en el slot nuevo (esperado true): %s" % _refresco_externo_reselecciona_ok)


func _slot_jugador_por_nombre(nombre: String) -> SlotItem:
	for slot: SlotItem in _panel._grilla_jugador.get_children():
		if slot.item_data and slot.item_data.name == nombre:
			return slot
	return null


## El tope al vender es lo que se tiene (item.quantity), no un número fijo
## — acá el jugador solo tiene 1 botiquín, así que "+" no debería mover la
## cantidad de 1.
func _probar_tope_cantidad_venta_y_vender() -> void:
	for _i in 5:
		_panel._boton_mas.pressed.emit()
	_tope_cantidad_venta_ok = _panel._valor_cantidad.text == "1"
	print("Subir cantidad de venta topa en lo que se tiene (esperado true, sigue en 1): %s" % _tope_cantidad_venta_ok)

	_panel._boton_accion.pressed.emit()
	var pago_esperado := int(_botiquin.valor * TiendaComponente.PORCENTAJE_VENTA)
	# Vender la ÚNICA unidad agota el ítem — _refrescar_grilla_jugador()
	# debe notar que la selección quedó apuntando a algo que ya no existe y
	# limpiar el panel central solo (si no, el botón Vender seguiría ahí
	# ofreciendo vender un ítem que ya no está).
	_vender_suma_y_limpia_seleccion_al_agotarse_ok = _creditos.obtener_creditos() == 60 + pago_esperado \
		and _item_jugador_por_nombre("Botiquín") == null \
		and _panel._nombre_item.text == "Seleccioná un ítem" \
		and _panel._boton_accion.disabled \
		and _panel._panel_detalle.modulate.a == 0.0
	print("Vender la última unidad suma créditos y limpia la selección agotada (esperado true): %s" % _vender_suma_y_limpia_seleccion_al_agotarse_ok)


## Elegir un equipable propio debe mostrar sus bonos igual que en
## PanelInventario (ver Utils.llenar_caracteristicas_item) — escudo.tres
## tiene defensa=8 y resistencia_fisica=15, en ese orden fijo (ver
## Utils.ETIQUETAS_ATRIBUTOS_ITEM). De paso confirma que quedó vendible de
## verdad (valor=70, tarea de precios de equipables).
func _probar_estadisticas_equipable() -> void:
	var slot := _slot_jugador_por_nombre("Escudo de Guardia")
	slot.slot_clicked.emit(slot)
	var vendible: bool = _panel._boton_accion.text == "Vender" and not _panel._boton_accion.disabled
	var filas_ok := false
	if _panel._vbox_caracteristicas.get_child_count() == 2:
		var fila_defensa: HBoxContainer = _panel._vbox_caracteristicas.get_child(0)
		var fila_resistencia: HBoxContainer = _panel._vbox_caracteristicas.get_child(1)
		filas_ok = fila_defensa.get_child(0).text == "Defensa" and fila_defensa.get_child(1).text == "+8" \
			and fila_resistencia.get_child(0).text == "Resist. Física" and fila_resistencia.get_child(1).text == "+15"
	_estadisticas_equipable_ok = vendible and filas_ok
	print("Elegir un equipable vendible muestra sus estadísticas (esperado true): %s" % _estadisticas_equipable_ok)


## DatosItem.valor == 0 (el tomo es tipo PASIVA, nunca tuvo valor de venta
## asignado a propósito — mismo caso real que un ítem de misión) — el panel
## debe dejar VER el ítem pero no ofrecer venderlo, y sin bonos que mostrar.
func _probar_item_sin_valor() -> void:
	var slot := _slot_jugador_por_nombre("Tomo de la Cosecha de Vida")
	slot.slot_clicked.emit(slot)
	_item_sin_valor_deshabilita_boton_ok = _panel._boton_accion.disabled \
		and _panel._boton_accion.text == "No se vende" \
		and _panel._vbox_caracteristicas.get_child_count() == 0
	print("Ítem propio sin valor de venta deshabilita el botón (esperado true): %s" % _item_sin_valor_deshabilita_boton_ok)


## Mismas 4 categorías que PanelInventario, una fila de botones por grilla
## (ver _TIPOS_FILTRO) — a esta altura el inventario tiene zanahoria y
## poción de vida (CONSUMIBLE), escudo (EQUIPABLE) y el tomo (PASIVA, no
## entra en ninguna de las 4 pestañas): filtrar por "Equipos" debe dejar
## viendo solo el escudo.
func _probar_filtro_categoria() -> void:
	_panel._botones_filtro_jugador[1].pressed.emit()  # índice 1 = Equipos
	var visibles := 0
	for slot: SlotItem in _panel._grilla_jugador.get_children():
		if slot.visible:
			visibles += 1
	var escudo_visible := _slot_jugador_por_nombre("Escudo de Guardia").visible
	var pocion_oculta := not _slot_jugador_por_nombre("Poción de Vida").visible
	_filtro_categoria_ok = visibles == 1 and escudo_visible and pocion_oculta
	print("Filtro Equipos deja ver solo el escudo (esperado true): %s" % _filtro_categoria_ok)
	_panel._botones_filtro_jugador[0].pressed.emit()  # volver a Todos.


func _probar_salir() -> void:
	_panel._boton_salir.pressed.emit()
	_salir_oculta_el_panel_ok = not _panel.visible
	print("Salir oculta el panel (esperado true): %s" % _salir_oculta_el_panel_ok)


func _informar() -> bool:
	var exito := _titulo_npc_y_inventario_ok and _panel_detalle_oculto_al_abrir_ok \
		and _click_comerciante_muestra_comprar_ok \
		and _brillo_aplicado_al_slot_comerciante_ok and _tope_cantidad_compra_ok \
		and _bajar_cantidad_ok and _comprar_descuenta_y_agrega_ok \
		and _click_jugador_muestra_vender_ok and _brillo_se_mueve_al_elegir_otro_ok \
		and _refresco_externo_reselecciona_ok and _tope_cantidad_venta_ok \
		and _vender_suma_y_limpia_seleccion_al_agotarse_ok and _estadisticas_equipable_ok \
		and _item_sin_valor_deshabilita_boton_ok and _filtro_categoria_ok \
		and _salir_oculta_el_panel_ok
	print("PRUEBA UI PANEL TIENDA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
