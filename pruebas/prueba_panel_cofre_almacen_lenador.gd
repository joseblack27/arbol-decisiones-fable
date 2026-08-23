# =============================================================================
# Prueba de PanelCofre en modo almacén — reemplaza a PanelAlmacenLenador
# (eliminado, pedido explícito del usuario: "usa la del cofre del jugador,
# allí pondrás los recursos del leñador"). Mismo panel de arrastrar-y-soltar
# que un cofre normal (ver prueba_panel_cofre.gd), pero GrillaCofre se
# puebla con el contenido del almacén compartido del leñador (ver
# GestorLenador.gd) a través de FuenteAlmacenLenador en vez de FuenteCofre.
#
# Cubre lo que NO ya cubre prueba_panel_cofre.gd (arrastre genérico, botón
# cerrar, scroll, doble-tap, etc. — todo eso corre igual porque es el MISMO
# panel):
#   1. BusEventos.almacen_lenador_solicitado abre el panel con el título del
#      almacén y su contenido real (no un cofre por jugador).
#   2. Arrastrar del inventario HACIA el almacén no hace nada — confirmado
#      con el usuario: "solo retirar", nadie deposita ahí arrastrando.
#   3. Arrastrar del almacén hacia el inventario retira de verdad (pasa por
#      GestorLenador.pedir_retirar(), server-validado — ver
#      prueba_almacen_lenador_compartido.gd para la validación del lado
#      servidor en sí).
#   4. GestorLenador.almacen_actualizado refresca la grilla en caliente
#      (ej. el leñador deposita mientras el panel sigue abierto).
#   5. "Tomar todo" (generalizado en GrillaObjetos.obtener_items_actuales(),
#      ver ese archivo) también vacía el almacén hacia el inventario.
#   godot --headless --path . --script res://pruebas/prueba_panel_cofre_almacen_lenador.gd
# =============================================================================
extends SceneTree

const _RUTA_LENA := "res://recursos/items/recursos/lena_1.tres"

var _jugador
var _inventario
var _panel
var _gl


var _se_abre_con_titulo_y_contenido_del_almacen_ok := false
var _bloquea_depositar_desde_inventario_ok := false
var _retirar_descuenta_del_almacen_y_da_item_ok := false
var _refresco_en_caliente_al_depositar_ok := false
var _tomar_todo_vacia_el_almacen_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_abrir()
	_probar_bloquea_depositar()
	_probar_retirar()
	_probar_refresco_en_caliente()
	_probar_tomar_todo()
	return _informar()


func _montar() -> void:
	_gl = root.get_node("/root/GestorLenador")
	_gl._almacen.clear()
	_gl.almacen_replicado.clear()

	var lena := load(_RUTA_LENA) as DatosItem
	_gl.depositar_servidor(lena)  # 1 unidad (ver lena_1.tres, quantity=1).

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_inventario = _jugador.get_node("InventarioComponente")

	_panel = (load("res://escenas/ui/panel_cofre/PanelCofre.tscn") as PackedScene).instantiate()
	root.add_child(_panel)


func _casilla_con_nombre(grilla: GrillaObjetos, nombre: String) -> Node:
	for casilla in grilla._contenedor.get_children():
		if casilla.item_data and casilla.item_data.name == nombre:
			return casilla
	return null


func _probar_abrir() -> void:
	root.get_node("/root/BusEventos").almacen_lenador_solicitado.emit()

	print("Se abre con el título del almacén (esperado 'Almacén del Leñador'): %s" % \
		_panel._grilla_cofre.titulo)
	var titulo_ok: bool = _panel.visible and _panel._grilla_cofre.titulo == "Almacén del Leñador"

	var casilla_lena := _casilla_con_nombre(_panel._grilla_cofre, "Leña")
	var contenido_ok: bool = casilla_lena != null and casilla_lena.item_data.quantity == 1
	print("La grilla muestra el contenido real del almacén (esperado true, 1): %s, %s" % [
		casilla_lena != null, casilla_lena.item_data.quantity if casilla_lena else -1
	])

	# Pedido del usuario: sin filtro de categorías ni orden en el almacén
	# (pocos tipos de recurso, no hace falta) — a diferencia de un cofre
	# normal, que sí los muestra (ver prueba_panel_cofre.gd).
	print("Sin filtro de categorías en el almacén (esperado false): %s" % \
		_panel._grilla_cofre._tabs_filtro.visible)
	print("Sin selector de orden en el almacén (esperado false): %s" % \
		_panel._grilla_cofre._fila_orden.visible)
	var sin_filtro_ni_orden_ok: bool = not _panel._grilla_cofre._tabs_filtro.visible \
		and not _panel._grilla_cofre._fila_orden.visible

	_se_abre_con_titulo_y_contenido_del_almacen_ok = titulo_ok and contenido_ok and sin_filtro_ni_orden_ok


func _probar_bloquea_depositar() -> void:
	var pocion := load("res://recursos/items/consumibles/pocion_vida.tres") as DatosItem
	_inventario.agregar_item(pocion, 1, true)
	_panel._grilla_jugador.notificar_cambio()

	var origen := _casilla_con_nombre(_panel._grilla_jugador, "Poción de Vida")
	var scroll_almacen = _panel._grilla_cofre.get_node("%ScrollContainer")
	scroll_almacen._drop_data(Vector2.ZERO, origen)

	var entro_al_almacen: bool = _casilla_con_nombre(_panel._grilla_cofre, "Poción de Vida") != null
	print("Arrastrar del inventario al almacén no hace nada (esperado false): %s" % entro_al_almacen)

	var se_quedo_en_inventario: bool = _casilla_con_nombre(_panel._grilla_jugador, "Poción de Vida") != null
	print("... la poción se queda en el inventario del jugador (esperado true): %s" % se_quedo_en_inventario)

	_bloquea_depositar_desde_inventario_ok = not entro_al_almacen and se_quedo_en_inventario


func _probar_retirar() -> void:
	var origen := _casilla_con_nombre(_panel._grilla_cofre, "Leña")
	var scroll_inventario = _panel._grilla_jugador.get_node("%ScrollContainer")
	scroll_inventario._drop_data(Vector2.ZERO, origen)

	var total_en_almacen: int = _gl._almacen.get(_RUTA_LENA, 0)
	print("Arrastrar del almacén al inventario retira de verdad, server-validado (esperado 0): %d" % \
		total_en_almacen)

	var lena_en_inventario: bool = false
	for item: DatosItem in _inventario.items:
		if item.name == "Leña":
			lena_en_inventario = true
			break
	print("... y la leña llega al inventario del jugador (esperado true): %s" % lena_en_inventario)

	_retirar_descuenta_del_almacen_y_da_item_ok = total_en_almacen == 0 and lena_en_inventario


## Simula al leñador depositando mientras el panel del almacén sigue
## abierto — GestorLenador.almacen_actualizado debe refrescar la grilla
## sola, sin que el jugador tenga que cerrar y volver a abrir.
func _probar_refresco_en_caliente() -> void:
	var hoja := load("res://recursos/items/recursos/hoja_1.tres") as DatosItem
	_gl.depositar_servidor(hoja)

	var entro_sola: bool = _casilla_con_nombre(_panel._grilla_cofre, hoja.name) != null
	print("Un depósito nuevo mientras el panel está abierto se ve solo (esperado true): %s" % entro_sola)
	_refresco_en_caliente_al_depositar_ok = entro_sola


func _probar_tomar_todo() -> void:
	_panel._grilla_cofre.tomar_todo_solicitado.emit()

	print("'Tomar todo' vacía el almacén (esperado true): %s" % _gl._almacen.is_empty())
	var almacen_vacio_ok: bool = _gl._almacen.is_empty()

	var hoja_en_inventario: bool = false
	for item: DatosItem in _inventario.items:
		if item.name == "Hoja Verde":
			hoja_en_inventario = true
			break
	print("... y lo que quedaba (hoja) llega al inventario (esperado true): %s" % hoja_en_inventario)

	_tomar_todo_vacia_el_almacen_ok = almacen_vacio_ok and hoja_en_inventario


func _informar() -> bool:
	var exito := _se_abre_con_titulo_y_contenido_del_almacen_ok and _bloquea_depositar_desde_inventario_ok \
		and _retirar_descuenta_del_almacen_y_da_item_ok and _refresco_en_caliente_al_depositar_ok \
		and _tomar_todo_vacia_el_almacen_ok
	print("  se abre con título y contenido del almacén: %s" % _se_abre_con_titulo_y_contenido_del_almacen_ok)
	print("  bloquea depositar desde el inventario: %s" % _bloquea_depositar_desde_inventario_ok)
	print("  retirar descuenta del almacén y da el ítem: %s" % _retirar_descuenta_del_almacen_y_da_item_ok)
	print("  refresco en caliente al depositar: %s" % _refresco_en_caliente_al_depositar_ok)
	print("  'Tomar todo' vacía el almacén: %s" % _tomar_todo_vacia_el_almacen_ok)
	print("PRUEBA PANEL COFRE ALMACEN LEÑADOR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
