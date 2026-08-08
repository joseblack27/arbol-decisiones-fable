# =============================================================================
# Prueba de la pestaña "Pasivas" dentro de PanelHabilidades (ver
# PanelHabilidades._poblar_pasivas / ItemPasiva / PanelDetallePasiva) —
# pedido del usuario: pestaña propia (mismo patrón de la barra de tabs de
# OsPrincipal: botones toggle + TabContainer con tabs_visible=false), y
# como el juego es mobile, tocar una fila muestra la descripción en el
# panel de detalle en vez de un tooltip (no hay hover táctil).
#
# Cubre:
#   1. Una pasiva de ESTADÍSTICA ya desbloqueada (nivel_requerido <= nivel
#      actual) aparece en la lista de la pestaña Pasivas.
#   2. Una pasiva de estadística que TODAVÍA no se alcanza NO aparece.
#   3. Una pasiva de GATILLO ya desbloqueada (PasivasComponente) aparece.
#   4. Tocar (togglear) una fila muestra su nombre/descripción en
#      PanelDetallePasiva — no en un tooltip.
#   5. El botón "Pasivas" cambia la pestaña activa del TabContainer, y deja
#      la lista de habilidades ACTIVAS intacta en la otra pestaña.
#   godot --headless --path . --script res://pruebas/prueba_panel_habilidades_pasivas.gd
# =============================================================================
extends SceneTree

const RUTA_PASIVA_PRUEBA := "res://pruebas/fixtures/PasivaDePrueba.tscn"

var _jugador
var _panel
var _fotogramas := 0

var _stat_desbloqueada_aparece_ok := false
var _stat_bloqueada_no_aparece_ok := false
var _gatillo_aparece_ok := false
var _seleccion_muestra_detalle_ok := false
var _boton_cambia_pestaña_ok := false
var _activas_no_se_mezclan_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_panel.populate()
			_probar_lista_y_pestaña()
			return _informar()
	return false


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	var experiencia = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	experiencia.name = "ExperienciaComponente"
	var stat_ok := PasivaStatDesbloqueo.new()
	stat_ok.nivel_requerido = 1
	stat_ok.nombre = "Stat Desbloqueada"
	stat_ok.descripcion = "ya la tengo"
	stat_ok.bono = AtributosBase.new()
	var stat_bloqueada := PasivaStatDesbloqueo.new()
	stat_bloqueada.nivel_requerido = 99
	stat_bloqueada.nombre = "Stat Bloqueada"
	stat_bloqueada.descripcion = "todavía no"
	stat_bloqueada.bono = AtributosBase.new()
	experiencia.pasivas_stat = [stat_ok, stat_bloqueada] as Array[PasivaStatDesbloqueo]
	_jugador.add_child(experiencia)

	var pasivas = (load("res://componentes/PasivasComponente.gd") as GDScript).new()
	pasivas.name = "PasivasComponente"
	_jugador.add_child(pasivas)
	pasivas.desbloquear_gatillo(RUTA_PASIVA_PRUEBA)

	# populate() también lee el SlotHabilidades local (habilidades activas,
	# no el foco de esta prueba) — se agrega uno vacío para no depender de
	# ese camino, mismo patrón que prueba_guardado_partida.gd.
	var slots = (load("res://componentes/SlotHabilidades.gd") as GDScript).new()
	slots.jugador = _jugador
	_jugador.add_child(slots)

	var escena := load("res://escenas/ui/panel_os/paneles/habilidades/PanelHabilidades.tscn") as PackedScene
	_panel = escena.instantiate()
	root.add_child(_panel)


func _nombres_de_pasivas_en_lista() -> Array:
	var nombres := []
	for hijo in _panel.pasivas_list_panel.get_children():
		if hijo is ItemPasiva:
			nombres.append(hijo.nombre_pasiva.text)
	return nombres


func _fila_de(nombre: String):
	for hijo in _panel.pasivas_list_panel.get_children():
		if hijo is ItemPasiva and hijo.nombre_pasiva.text == nombre:
			return hijo
	return null


func _probar_lista_y_pestaña() -> void:
	# La primera fila se autoselecciona (mismo criterio que la lista de
	# habilidades activas) — su descripción tiene que estar YA en el panel
	# de detalle, sin tocar nada.
	print("Panel de detalle tras poblar (esperado 'ya la tengo' o 'Instinto...'/etc, no vacío): '%s'" % \
		_panel.pasivas_detail_panel.description_label.text)
	var hubo_algo_por_defecto: bool = _panel.pasivas_detail_panel.description_label.text != ""

	# Tocar explícitamente la fila de gatillo (Pasiva de Prueba) y verificar
	# que el detalle cambia a SU descripción — no un tooltip.
	var fila_gatillo = _fila_de("Pasiva de Prueba")
	fila_gatillo.button_pressed = true
	print("Detalle tras seleccionar 'Pasiva de Prueba' (esperado 'descripción de prueba'): '%s'" % \
		_panel.pasivas_detail_panel.description_label.text)
	print("Nombre en el detalle (esperado 'Pasiva de Prueba'): '%s'" % _panel.pasivas_detail_panel.name_label.text)
	_seleccion_muestra_detalle_ok = hubo_algo_por_defecto \
		and _panel.pasivas_detail_panel.description_label.text == "descripción de prueba" \
		and _panel.pasivas_detail_panel.name_label.text == "Pasiva de Prueba"

	# El botón "Pasivas" tiene que cambiar la pestaña activa del TabContainer.
	_panel.btn_pasivas.pressed.emit()
	print("Pestaña activa tras tocar 'Pasivas' (esperado 1): %d" % _panel.tabs.current_tab)
	_boton_cambia_pestaña_ok = _panel.tabs.current_tab == 1

	# La lista de habilidades ACTIVAS no se mezcla con las pasivas — sigue
	# viviendo en su propio contenedor, sin filas de ItemPasiva adentro.
	var mezcladas := false
	for hijo in _panel.skill_list_panel.get_children():
		if hijo is ItemPasiva:
			mezcladas = true
	_activas_no_se_mezclan_ok = not mezcladas


func _informar() -> bool:
	var nombres := _nombres_de_pasivas_en_lista()
	print("Filas de pasiva en la lista: %s" % str(nombres))

	_stat_desbloqueada_aparece_ok = nombres.has("Stat Desbloqueada")
	_stat_bloqueada_no_aparece_ok = not nombres.has("Stat Bloqueada")
	_gatillo_aparece_ok = nombres.has("Pasiva de Prueba")

	print("  pasiva de stat YA desbloqueada aparece: %s" % _stat_desbloqueada_aparece_ok)
	print("  pasiva de stat AÚN bloqueada no aparece: %s" % _stat_bloqueada_no_aparece_ok)
	print("  pasiva de gatillo desbloqueada aparece: %s" % _gatillo_aparece_ok)
	print("  seleccionar una fila muestra su descripción en el detalle: %s" % _seleccion_muestra_detalle_ok)
	print("  el botón Pasivas cambia la pestaña: %s" % _boton_cambia_pestaña_ok)
	print("  la lista de activas no se mezcla con pasivas: %s" % _activas_no_se_mezclan_ok)

	var exito := _stat_desbloqueada_aparece_ok and _stat_bloqueada_no_aparece_ok and _gatillo_aparece_ok \
		and _seleccion_muestra_detalle_ok and _boton_cambia_pestaña_ok and _activas_no_se_mezclan_ok
	print("PRUEBA PANEL HABILIDADES PASIVAS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
