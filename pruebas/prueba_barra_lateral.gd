# =============================================================================
# BarraLateral (HUD) — combina Grupo y Misiones en un panel colapsable con
# pestañas laterales, en la misma posición que antes ocupaba BarraGrupo
# (ver Mundo.tscn). Pedido explícito del usuario (1 sep 2026):
#   "si esta oculto y presionas cualquiera de los dos botones del tab, se
#    muestra el tab con la opcion seleccionada, si se presiona un tab
#    distinto con el tab abierto, debe cambiar al tab seleccionado, pero si
#    se presiona el boton del mismo tab que esta abierto, debe ocultarse
#    el panel"
#
# Verifica:
#   1. Cerrado por defecto.
#   2. Cerrado + tocar Grupo -> abre en el tab Grupo.
#   3. Abierto en Grupo + tocar Misiones -> cambia a Misiones, sigue abierto.
#   4. Abierto en Misiones + tocar Misiones de nuevo -> se cierra.
#   5. Tab Grupo: sin grupo muestra "Sin grupo"; con grupo, una fila por
#      miembro (mismo contenido que tenía BarraGrupo.gd, ahora fusionado).
#   6. Tab Misiones: sin misiones activas muestra "Sin misiones activas";
#      con una misión EN_PROGRESO, título + progreso de cada objetivo
#      habilitado ("descripción (actual/meta)").
#   7. Bug real reportado (1 sep 2026): "la barra lateral no muestra las
#      misiones que tengo" — una misión EN_PROGRESO restaurada de una
#      partida guardada (nunca pasa por aceptar_mision(), así que ninguna
#      de las señales de mision_aceptada/progreso avisa) tiene que
#      aparecer igual al terminar de cargar (GestorGuardado.partida_cargada).
#   godot --headless --path . --script res://pruebas/prueba_barra_lateral.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _gg
var _gm
var _barra
var _jugador
var _misiones

var _cerrado_por_defecto_ok := false
var _abre_en_grupo_ok := false
var _cambia_a_misiones_sigue_abierto_ok := false
var _cierra_con_mismo_tab_ok := false
var _grupo_vacio_ok := false
var _grupo_con_miembros_ok := false
var _misiones_vacio_ok := false
var _mision_con_progreso_ok := false
var _refresca_al_cargar_partida_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_probar_estado_inicial_y_vacios()
			_probar_toggle()
			_probar_refresca_al_cargar_partida()
			return _informar()
	return false


func _montar() -> void:
	_gg = root.get_node("/root/GestorGrupos")
	_gm = root.get_node("/root/GestorMisiones")

	var objetivo := DatosObjetivoMision.new()
	objetivo.id = "obj1"
	objetivo.descripcion = "Matar lobos"
	objetivo.tipo = Enums.Mision.TipoObjetivo.MATAR
	objetivo.id_meta = "lobo"
	objetivo.cantidad_meta = 3

	var mision := DatosMision.new()
	mision.id = "m1"
	mision.titulo = "Plaga de lobos"
	mision.objetivos = [objetivo]
	mision.recompensas = DatosRecompensaMision.new()

	# Segunda misión, usada solo por _probar_refresca_al_cargar_partida():
	# se inyecta directo en progreso (sin pasar por aceptar_mision()), para
	# simular una misión que ya venía EN_PROGRESO de una partida guardada.
	var mision_restaurada := DatosMision.new()
	mision_restaurada.id = "m2"
	mision_restaurada.titulo = "Misión Restaurada"
	mision_restaurada.objetivos = []
	mision_restaurada.recompensas = DatosRecompensaMision.new()

	_gm.catalogo = [mision, mision_restaurada] as Array[DatosMision]

	_barra = (load("res://escenas/ui/hud/BarraLateral.tscn") as PackedScene).instantiate()
	root.add_child(_barra)

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador.name = "1"
	root.add_child(_jugador)
	_misiones = _jugador.get_node("MisionesComponente")


func _probar_estado_inicial_y_vacios() -> void:
	_cerrado_por_defecto_ok = not _barra.get_node("Panel").visible
	print("Cerrado por defecto (esperado true): %s" % _cerrado_por_defecto_ok)

	var lista_grupo: VBoxContainer = _barra.get_node("Panel/ScrollGrupo/ListaGrupo")
	_grupo_vacio_ok = lista_grupo.get_child_count() == 1 \
		and (lista_grupo.get_child(0) as Label).text == "Sin grupo"
	print("Tab Grupo sin grupo muestra 'Sin grupo' (esperado true): %s" % _grupo_vacio_ok)

	var lista_misiones: VBoxContainer = _barra.get_node("Panel/ScrollMisiones/ListaMisiones")
	_misiones_vacio_ok = lista_misiones.get_child_count() == 1 \
		and (lista_misiones.get_child(0) as Label).text == "Sin misiones activas"
	print("Tab Misiones sin nada activo muestra 'Sin misiones activas' (esperado true): %s" % _misiones_vacio_ok)

	_gg.mi_grupo = {
		"id_grupo": "g1", "lider": "id_a", "soy_lider": true,
		"miembros": [
			{"id_unico": "id_a", "nombre": "Ana", "vida": 80.0, "vida_maxima": 100.0},
			{"id_unico": "id_b", "nombre": "Beto", "vida": 40.0, "vida_maxima": 100.0},
		],
	}
	_gg.grupo_actualizado.emit()
	_grupo_con_miembros_ok = lista_grupo.get_child_count() == 2
	print("Tab Grupo con 2 miembros muestra 2 filas (esperado true): %s" % _grupo_con_miembros_ok)

	_misiones.aceptar_mision(_gm.obtener_por_id("m1"))
	_misiones._avanzar_objetivos(Enums.Mision.TipoObjetivo.MATAR, "lobo")
	var fila_mision: VBoxContainer = lista_misiones.get_child(0) if lista_misiones.get_child_count() > 0 else null
	var titulo_ok: bool = fila_mision != null and (fila_mision.get_child(0) as Label).text == "Plaga de lobos"
	var progreso_ok: bool = fila_mision != null and fila_mision.get_child_count() > 1 \
		and "Matar lobos (1/3)" in (fila_mision.get_child(1) as Label).text
	_mision_con_progreso_ok = lista_misiones.get_child_count() == 1 and titulo_ok and progreso_ok
	print("Tab Misiones muestra título + progreso de la misión activa (esperado true): %s" % _mision_con_progreso_ok)


func _probar_toggle() -> void:
	var panel: PanelContainer = _barra.get_node("Panel")
	var boton_grupo: Button = _barra.get_node("TirasTabs/BotonGrupo")
	var boton_misiones: Button = _barra.get_node("TirasTabs/BotonMisiones")

	boton_grupo.pressed.emit()
	_abre_en_grupo_ok = panel.visible and _barra._tab_activo == _barra.Tab.GRUPO
	print("Cerrado + tocar Grupo -> abre en Grupo (esperado true): %s" % _abre_en_grupo_ok)

	boton_misiones.pressed.emit()
	_cambia_a_misiones_sigue_abierto_ok = panel.visible and _barra._tab_activo == _barra.Tab.MISIONES
	print("Abierto en Grupo + tocar Misiones -> cambia y sigue abierto (esperado true): %s" \
		% _cambia_a_misiones_sigue_abierto_ok)

	boton_misiones.pressed.emit()
	_cierra_con_mismo_tab_ok = not panel.visible
	print("Abierto en Misiones + tocar Misiones de nuevo -> se cierra (esperado true): %s" \
		% _cierra_con_mismo_tab_ok)


## Bug real reportado: "la barra lateral no muestra las misiones que
## tengo" — inyecta "m2" EN_PROGRESO directo en progreso, sin pasar por
## aceptar_mision() (así se ve GestorGuardado._restaurar_misiones, que
## arma el progreso a mano al cargar partida, no llamando aceptar_mision()
## como haría un jugador de verdad). Sin la conexión a GestorGuardado.
## partida_cargada, ninguna señal avisa y la barra se queda mostrando lo
## de antes para siempre.
func _probar_refresca_al_cargar_partida() -> void:
	_misiones.progreso["m2"] = {"estado": Enums.Mision.Estado.EN_PROGRESO, "objetivos": {}}

	var lista_misiones: VBoxContainer = _barra.get_node("Panel/ScrollMisiones/ListaMisiones")
	var titulos_antes: Array = []
	for fila in lista_misiones.get_children():
		if fila.get_child_count() > 0:
			titulos_antes.append((fila.get_child(0) as Label).text)
	var no_aparece_sin_senial_ok: bool = not ("Misión Restaurada" in titulos_antes)

	root.get_node("/root/GestorGuardado").partida_cargada.emit()

	var titulos_despues: Array = []
	for fila in lista_misiones.get_children():
		if fila.get_child_count() > 0:
			titulos_despues.append((fila.get_child(0) as Label).text)
	var aparece_tras_cargar_ok: bool = "Misión Restaurada" in titulos_despues

	_refresca_al_cargar_partida_ok = no_aparece_sin_senial_ok and aparece_tras_cargar_ok
	print("Una misión restaurada (sin señal de aceptar) aparece al emitir partida_cargada (esperado true — antes=%s, después=%s): %s" % [
		titulos_antes, titulos_despues, _refresca_al_cargar_partida_ok])


func _informar() -> bool:
	var exito := _cerrado_por_defecto_ok and _abre_en_grupo_ok and _cambia_a_misiones_sigue_abierto_ok \
		and _cierra_con_mismo_tab_ok and _grupo_vacio_ok and _grupo_con_miembros_ok \
		and _misiones_vacio_ok and _mision_con_progreso_ok and _refresca_al_cargar_partida_ok
	print("PRUEBA BARRA LATERAL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
