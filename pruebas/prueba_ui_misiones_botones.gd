# =============================================================================
# Prueba de PanelMisiones — visibilidad de los botones Abandonar/Rastrear
# según el estado real de la misión, y que abandonar pide confirmación
# antes de aplicar (y que abandonar una misión EN_PROGRESO la devuelve a
# "pendiente", no la borra de la lista). Pedido explícito del usuario tras
# probar el sistema en juego real.
#   godot --headless --path . --script res://pruebas/prueba_ui_misiones_botones.gd
# =============================================================================
extends SceneTree

var _jugador
var _misiones
var _panel: Control
var _datos_mision: DatosMision

var _disponible_oculta_abandonar_muestra_rastrear_ok := false
var _en_progreso_muestra_ambos_ok := false
var _completada_oculta_ambos_ok := false
var _presionar_abandonar_no_abandona_de_una_ok := false
var _confirmar_abandona_de_verdad_ok := false
var _abandonar_en_progreso_vuelve_a_disponible_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_disponible()
	_probar_en_progreso()
	_probar_completada()
	_probar_abandonar_pide_confirmacion()
	return _informar()


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_misiones = _jugador.get_node("MisionesComponente")

	var objetivo := DatosObjetivoMision.new()
	objetivo.id = "obj1"
	objetivo.descripcion = "Objetivo de prueba"
	objetivo.tipo = Enums.Mision.TipoObjetivo.MATAR
	objetivo.id_meta = "algo"
	objetivo.cantidad_meta = 1

	_datos_mision = DatosMision.new()
	_datos_mision.id = "mision_ui_prueba"
	_datos_mision.titulo = "Misión UI"
	_datos_mision.objetivos = [objetivo]
	_datos_mision.recompensas = DatosRecompensaMision.new()

	var catalogo: Array[DatosMision] = [_datos_mision]
	root.get_node("/root/GestorMisiones").catalogo = catalogo

	_panel = (load("res://escenas/ui/panel_os/paneles/misiones/PanelMisiones.tscn") as PackedScene).instantiate()
	root.add_child(_panel)


func _abandon_button() -> Button:
	return _panel.get_node("MarginContainer/HBox/PanelDetalleMision/MarginContainer/VBoxDetalle/ButtonBar/AbandonButton")


func _track_button() -> Button:
	return _panel.get_node("MarginContainer/HBox/PanelDetalleMision/MarginContainer/VBoxDetalle/ButtonBar/TrackButton")


func _probar_disponible() -> void:
	_panel.show_mission(_datos_mision)
	_disponible_oculta_abandonar_muestra_rastrear_ok = not _abandon_button().visible and _track_button().visible
	print("Misión DISPONIBLE: Abandonar oculto, Rastrear visible (esperado true): %s" % _disponible_oculta_abandonar_muestra_rastrear_ok)


func _probar_en_progreso() -> void:
	_misiones.aceptar_mision(_datos_mision)
	_panel.show_mission(_datos_mision)
	_en_progreso_muestra_ambos_ok = _abandon_button().visible and _track_button().visible
	print("Misión EN_PROGRESO: los dos botones visibles (esperado true): %s" % _en_progreso_muestra_ambos_ok)


func _probar_completada() -> void:
	_misiones.notificar_matar(_crear_datos_enemigo("algo"))
	_misiones.completar_mision(_datos_mision)
	_panel.show_mission(_datos_mision)
	_completada_oculta_ambos_ok = not _abandon_button().visible and not _track_button().visible
	print("Misión COMPLETADA: los dos botones ocultos (esperado true): %s" % _completada_oculta_ambos_ok)


func _crear_datos_enemigo(id_objetivo: String) -> EnemigoDatos:
	var datos := EnemigoDatos.new()
	datos.id = id_objetivo
	return datos


func _probar_abandonar_pide_confirmacion() -> void:
	# Reaceptar sobre una misión completada no hace nada (_aceptar_mision_
	# local exige que no haya entrada en progreso) — se arma una SEGUNDA
	# misión fresca en progreso puntualmente para esta prueba.
	var mision2 := DatosMision.new()
	mision2.id = "mision_ui_prueba_2"
	mision2.objetivos = []
	mision2.recompensas = DatosRecompensaMision.new()
	root.get_node("/root/GestorMisiones").catalogo.append(mision2)
	_misiones.aceptar_mision(mision2)
	_panel.show_mission(mision2)

	_abandon_button().pressed.emit()
	_presionar_abandonar_no_abandona_de_una_ok = _misiones.estado_de(mision2.id) == Enums.Mision.Estado.EN_PROGRESO
	print("Presionar Abandonar NO abandona sin confirmar (esperado true, sigue EN_PROGRESO): %s" % _presionar_abandonar_no_abandona_de_una_ok)

	_panel.confirmar_abandonar.confirmed.emit()
	_confirmar_abandona_de_verdad_ok = _misiones.estado_de(mision2.id) == Enums.Mision.Estado.BLOQUEADA
	print("Confirmar abandona de verdad (esperado true, ya no hay entrada): %s" % _confirmar_abandona_de_verdad_ok)

	# BLOQUEADA (sin entrada) es justo lo que _estado_efectivo() de
	# PanelMisiones reclasifica como DISPONIBLE/"pendiente" para mostrar.
	_abandonar_en_progreso_vuelve_a_disponible_ok = _panel._estado_efectivo(mision2.id) == Enums.Mision.Estado.DISPONIBLE
	print("Misión abandonada vuelve a mostrarse como pendiente (esperado true): %s" % _abandonar_en_progreso_vuelve_a_disponible_ok)


func _informar() -> bool:
	var exito := _disponible_oculta_abandonar_muestra_rastrear_ok and _en_progreso_muestra_ambos_ok \
		and _completada_oculta_ambos_ok and _presionar_abandonar_no_abandona_de_una_ok \
		and _confirmar_abandona_de_verdad_ok and _abandonar_en_progreso_vuelve_a_disponible_ok
	print("PRUEBA UI MISIONES BOTONES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
