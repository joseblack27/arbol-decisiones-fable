# =============================================================================
# Prueba del menú de accesos rápidos del botón OS (ver MenuAccesosOS.gd),
# pedido explícito del usuario: en vez de que el botón OS abra directo el
# panel OS en su pestaña por defecto, abre esta cuadrícula (máximo 4
# columnas) y cada ícono lleva directo a una sección puntual.
#   1. Arranca oculta.
#   2. alternar() la muestra, con un botón por opción configurada, en una
#      cuadrícula de a lo sumo 4 columnas, y un tamaño real (no 0x0).
#   3. Elegir una opción abre el panel OS real en la pestaña correcta
#      (current_tab del TabContainer) y vuelve a ocultar la cuadrícula.
#   godot --headless --path . --script res://pruebas/prueba_menu_accesos_os.gd
# =============================================================================
extends SceneTree

var _f := 0
var _menu
var _os_principal

var _arranca_oculto_ok := false
var _alternar_muestra_ok := false
var _cantidad_botones_ok := false
var _columnas_ok := false
var _tamano_real_ok := false
var _elige_abre_tab_correcto_ok := false
var _vuelve_a_ocultarse_ok := false
var _etiqueta_visible_sin_tooltip_ok := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		3:
			_verificar_inicial_y_alternar()
		4:
			_elegir_opcion()
			return _informar()
	return false


func _montar() -> void:
	var contenedor := Control.new()
	contenedor.size = Vector2(1280, 720)
	root.add_child(contenedor)
	current_scene = contenedor

	_os_principal = (load("res://escenas/ui/panel_os/principal/OsPrincipal.tscn") as PackedScene).instantiate()
	contenedor.add_child(_os_principal)

	_menu = (load("res://escenas/ui/menu_accesos_os/MenuAccesosOS.tscn") as PackedScene).instantiate()
	# La escena base no trae opciones (esas se configuran en Mundo.tscn, ver
	# herramientas usado para armarlo) -- mismo set y mismo orden acá para
	# poder probar "elegir Inventario" de forma realista.
	var opciones: Array[OpcionMenuOS] = [
		load("res://escenas/ui/menu_accesos_os/opciones/PersonajeOS.tres"),
		load("res://escenas/ui/menu_accesos_os/opciones/InventarioOS.tres"),
		load("res://escenas/ui/menu_accesos_os/opciones/MapaOS.tres"),
		load("res://escenas/ui/menu_accesos_os/opciones/HabilidadesOS.tres"),
		load("res://escenas/ui/menu_accesos_os/opciones/MisionesOS.tres"),
		load("res://escenas/ui/menu_accesos_os/opciones/ConfiguracionOS.tres"),
	]
	_menu.opciones = opciones
	contenedor.add_child(_menu)


func _verificar_inicial_y_alternar() -> void:
	_arranca_oculto_ok = not _menu.visible
	print("Arranca oculto (esperado true): %s" % _arranca_oculto_ok)

	_menu.alternar()
	_alternar_muestra_ok = _menu.visible
	print("alternar() lo muestra (esperado true): %s" % _alternar_muestra_ok)

	var grid: GridContainer = _menu.get_node("Grid")
	_cantidad_botones_ok = grid.get_child_count() == _menu.opciones.size()
	print("Un botón por opción configurada (esperado true, %d): %s" % [
		_menu.opciones.size(), _cantidad_botones_ok])

	_columnas_ok = grid.columns <= 4
	print("A lo sumo 4 columnas (esperado true, columns=%d): %s" % [grid.columns, _columnas_ok])

	_tamano_real_ok = _menu.size.x > 0.0 and _menu.size.y > 0.0
	print("Tamaño real, no 0x0 (esperado true, size=%s): %s" % [_menu.size, _tamano_real_ok])

	# Pedido explícito del usuario: texto SIEMPRE visible debajo del ícono,
	# nada de tooltip (el juego es para celular, sin hover que lo dispare).
	var primera_celda: VBoxContainer = grid.get_child(1)  # Inventario, ver opciones[].
	var boton_celda := primera_celda.get_child(0) as Button
	var etiqueta_celda := primera_celda.get_child(1) as Label
	_etiqueta_visible_sin_tooltip_ok = etiqueta_celda != null and etiqueta_celda.text == "Inventario" \
		and etiqueta_celda.visible and boton_celda.tooltip_text == ""
	print("Cada opción muestra su nombre como texto fijo, no como tooltip (esperado true): %s" % \
		_etiqueta_visible_sin_tooltip_ok)


func _elegir_opcion() -> void:
	# La opción de Inventario (índice 1, ver MenuAccesosOS.opciones en
	# Mundo.tscn) debería dejar el TabContainer en la pestaña 3.
	var opcion_inventario: OpcionMenuOS = _menu.opciones[1]
	_menu._al_elegir(opcion_inventario)

	var tabs: TabContainer = _os_principal.get_node("ColorRect/Margin/VBox/TabContainer")
	_elige_abre_tab_correcto_ok = _os_principal.color_rect.visible and tabs.current_tab == 3
	print("Elegir 'Inventario' abre el panel OS en la pestaña 3 (esperado true, tab=%d): %s" % [
		tabs.current_tab, _elige_abre_tab_correcto_ok])

	_vuelve_a_ocultarse_ok = not _menu.visible
	print("La cuadrícula se vuelve a ocultar al elegir (esperado true): %s" % _vuelve_a_ocultarse_ok)


func _informar() -> bool:
	var exito := _arranca_oculto_ok and _alternar_muestra_ok and _cantidad_botones_ok \
		and _columnas_ok and _tamano_real_ok and _elige_abre_tab_correcto_ok and _vuelve_a_ocultarse_ok \
		and _etiqueta_visible_sin_tooltip_ok
	print("PRUEBA MENU ACCESOS OS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
