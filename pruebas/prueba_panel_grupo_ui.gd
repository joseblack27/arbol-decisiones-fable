# =============================================================================
# UI de grupos (Feature C) — PanelGrupo, BarraGrupo, PanelInvitacionGrupo.
# Solo el lado de PRESENTACIÓN (reacciona a GestorGrupos.roster/mi_grupo y
# a sus señales) — la lógica de red de GestorGrupos ya se prueba aparte en
# prueba_gestor_grupos_ciclo_completo.gd, acá no se clickea ningún botón
# que dispare RPCs, solo se verifica qué se muestra/oculta.
#
# Verifica:
#   1. PanelGrupo: sin grupo, muestra el roster de conectados (menos a vos
#      mismo); con grupo, muestra a los miembros y oculta el roster.
#   2. BarraGrupo: oculta sin grupo, visible con una fila por miembro
#      cuando GestorGrupos.mi_grupo tiene datos.
#   3. PanelInvitacionGrupo: oculto por defecto, aparece al recibir
#      invitacion_recibida con el nombre del invitante en el texto.
#   godot --headless --path . --script res://pruebas/prueba_panel_grupo_ui.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _gg
var _panel_grupo
var _barra_grupo
var _panel_invitacion

var _roster_sin_grupo_ok := false
var _propio_peer_excluido_ok := false
var _vista_de_grupo_ok := false
var _barra_oculta_sin_grupo_ok := false
var _barra_visible_con_grupo_ok := false
var _toggle_oculta_y_muestra_ok := false
var _invitacion_oculta_por_defecto_ok := false
var _invitacion_muestra_nombre_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	if _fotogramas == 2:
		return _informar()
	return false


func _montar() -> void:
	_gg = root.get_node("/root/GestorGrupos")

	_panel_grupo = (load("res://escenas/ui/panel_os/paneles/grupo/PanelGrupo.tscn") as PackedScene).instantiate()
	root.add_child(_panel_grupo)
	_barra_grupo = (load("res://escenas/ui/hud/BarraGrupo.tscn") as PackedScene).instantiate()
	root.add_child(_barra_grupo)
	_panel_invitacion = (load("res://escenas/ui/panel_invitacion_grupo/PanelInvitacionGrupo.tscn") as PackedScene).instantiate()
	root.add_child(_panel_invitacion)

	_invitacion_oculta_por_defecto_ok = not _panel_invitacion.visible
	_barra_oculta_sin_grupo_ok = not _barra_grupo.visible

	_probar_roster_sin_grupo()
	_probar_vista_de_grupo()
	_probar_invitacion()


func _probar_roster_sin_grupo() -> void:
	_gg.roster = [
		{"peer_id": root.multiplayer.get_unique_id(), "nombre": "Yo mismo"},
		{"peer_id": 42, "nombre": "Beto"},
	]
	_gg.roster_actualizado.emit()

	var lista_roster: VBoxContainer = _panel_grupo.get_node("VBox/Scroll/Contenido/ListaRoster")
	_roster_sin_grupo_ok = lista_roster.visible and lista_roster.get_child_count() == 1
	# La única fila que quedó tiene que ser la de Beto, no la propia.
	var etiqueta: Label = lista_roster.get_child(0).get_child(0)
	_propio_peer_excluido_ok = etiqueta.text == "Beto"
	print("Con roster de 2 (uno sos vos), PanelGrupo muestra 1 fila para invitar (esperado true): %s" \
		% _roster_sin_grupo_ok)
	print("La fila mostrada es la del OTRO jugador, no la propia (esperado 'Beto'): %s" % etiqueta.text)


func _probar_vista_de_grupo() -> void:
	_gg.mi_grupo = {
		"id_grupo": "g1",
		"lider": "id_a",
		"soy_lider": true,
		"miembros": [
			{"id_unico": "id_a", "nombre": "Ana", "vida": 80.0, "vida_maxima": 100.0},
			{"id_unico": "id_b", "nombre": "Beto", "vida": 40.0, "vida_maxima": 100.0},
		],
	}
	_gg.grupo_actualizado.emit()

	var lista_roster: VBoxContainer = _panel_grupo.get_node("VBox/Scroll/Contenido/ListaRoster")
	var lista_grupo: VBoxContainer = _panel_grupo.get_node("VBox/Scroll/Contenido/ListaGrupo")
	_vista_de_grupo_ok = not lista_roster.visible and lista_grupo.visible \
		and lista_grupo.get_child_count() == 2
	print("Con grupo, PanelGrupo oculta el roster y muestra 2 miembros (esperado true): %s" \
		% _vista_de_grupo_ok)

	_barra_visible_con_grupo_ok = _barra_grupo.visible \
		and _barra_grupo.get_node("Panel/Lista").get_child_count() == 2
	print("BarraGrupo se muestra con una fila por miembro (esperado true): %s" \
		% _barra_visible_con_grupo_ok)

	# Pedido del usuario: "que este panel se pueda ocultar y mostrar" — el
	# botón colapsa/expande el contenido sin ocultar el botón mismo.
	var panel_contenido: PanelContainer = _barra_grupo.get_node("Panel")
	var boton: Button = _barra_grupo.get_node("BotonToggle")
	var expandido_por_defecto := panel_contenido.visible
	boton.pressed.emit()
	var colapsado_tras_un_toque := not panel_contenido.visible
	boton.pressed.emit()
	var expandido_de_nuevo := panel_contenido.visible
	_toggle_oculta_y_muestra_ok = expandido_por_defecto and colapsado_tras_un_toque and expandido_de_nuevo
	print("El botón de BarraGrupo oculta y vuelve a mostrar el contenido (esperado true): %s" \
		% _toggle_oculta_y_muestra_ok)


func _probar_invitacion() -> void:
	_gg.invitacion_recibida.emit("Cora")
	var texto: Label = _panel_invitacion.get_node("Fondo/MarginContainer/VBox/Texto")
	_invitacion_muestra_nombre_ok = _panel_invitacion.visible and texto.text.find("Cora") != -1
	print("PanelInvitacionGrupo aparece con el nombre de quien invitó (esperado true): %s" \
		% _invitacion_muestra_nombre_ok)


func _informar() -> bool:
	var exito := _roster_sin_grupo_ok and _propio_peer_excluido_ok and _vista_de_grupo_ok \
		and _barra_oculta_sin_grupo_ok and _barra_visible_con_grupo_ok and _toggle_oculta_y_muestra_ok \
		and _invitacion_oculta_por_defecto_ok and _invitacion_muestra_nombre_ok
	print("PRUEBA PANEL GRUPO UI %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
