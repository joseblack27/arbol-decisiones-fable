# =============================================================================
# Prueba de fase 2 ("Cazador") del Guardián Quebrado:
#   1. HabilidadBarridoGuardian.golpear() con deja_charco=true deja un
#      EfectoCharcoJefe en el punto de impacto (mismo mecanismo que ya usa
#      un jefe real, ver escenas/habilidades/charco_jefe/).
#   2. HabilidadFrancotiradorGuardian: tras la pose (pose+timer real, no
#      llamado directo — es la pieza genuinamente nueva de esta fase),
#      el disparo sale y conecta daño.
#   3. Al entrar en fase 2 (vida <= _UMBRAL_FASE_2), el SelectorHabilidades
#      suma lluvia de lanzas y francotirador, y combo/barrido activan
#      deja_charco.
#
# Sin tipos estáticos hacia clases nuevas del jefe en el TOP-LEVEL del
# script (ver cabecera de prueba_area_no_daña_aliados.gd) — todo por
# load()/instantiate() en runtime, dentro de _process().
#   godot --headless --path . --script res://pruebas/prueba_guardian_fase2.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _jugador
var _vida_jugador
var _vida_antes_franco := 0.0

var _charco_aparece_ok := false
var _franco_dano_ok := false
var _fase2_agrega_habilidades_ok := false
var _fase2_activa_charco_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_probar_charco()
			_disparar_francotirador()
		195:
			# duracion_pose_ataque=1.8s del francotirador — 190 fotogramas de
			# margen (igual criterio de sobra que ya usó la prueba de combate
			# de fase 1 para timers reales en --script).
			_probar_dano_francotirador()
			_disparar_transicion_fase2()
		400:
			# _reanudar_fase() llega recién tras pausa_cambio_fase (1.3s) vía
			# _telegrafiar_pausa_de_fase — no es sincrónico con quitar_vida().
			# Margen generoso, mismo criterio que arriba.
			_probar_transicion_fase2()
			return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	var escena_jefe := load("res://escenas/enemigos/EnemigoGuardianQuebrado.tscn")
	_jefe = escena_jefe.instantiate()
	raiz.add_child(_jefe)
	_jefe.global_position = Vector2.ZERO
	# Apaga la IA autónoma: esta prueba dispara habilidades/transiciones a
	# mano en fotogramas EXACTOS — con jitter_prioridad + furia final
	# (pedido del usuario, "IA más inteligente"), dejar la IA real corriendo
	# en paralelo podía elegir sus propias habilidades y pisar el timing
	# esperado (bug real encontrado: fallas intermitentes al agregar esa
	# variedad). Mismo mecanismo que usa EfectoAturdir para pausar la IA.
	_jefe.get_node("ArbolComportamiento").process_mode = Node.PROCESS_MODE_DISABLED

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena_jugador.instantiate()
	_jugador.name = "1"
	raiz.add_child(_jugador)
	_jugador.global_position = Vector2(400, 0)
	_vida_jugador = _jugador.get_node("VidaComponente")
	_vida_jugador.salud_maxima = 100000.0
	_vida_jugador.salud_actual = 100000.0
	_vida_jugador.cancelar_invulnerabilidad()

	# Objetivo forzado a mano en la memoria del jefe (sin depender de que la
	# IA real lo detecte a tiempo) — el francotirador reapunta leyendo esta
	# misma clave.
	var memoria = _jefe.get_node("ArbolComportamiento/MemoriaBT")
	memoria.establecer("objetivo", _jugador)


func _probar_charco() -> void:
	var script_barrido := load("res://escenas/habilidades/barrido_guardian/HabilidadBarridoGuardian.gd")
	script_barrido.call("golpear", _jefe, Vector2.RIGHT, 150.0, 90.0, 20.0, 0, true)
	var charco: Node = _jefe.get_parent().get_node_or_null("EfectoCharcoJefe")
	# El charco no tiene nombre fijo garantizado (instantiate() genera uno
	# genérico) — se busca por tipo entre los hijos del contenedor en su lugar.
	if charco == null:
		for hijo in _jefe.get_parent().get_children():
			if hijo.get_script() != null and hijo.get_script().resource_path.ends_with("EfectoDoT.gd"):
				charco = hijo
				break
	_charco_aparece_ok = charco != null
	print("Barrido con deja_charco=true deja un EfectoDoT en la escena (esperado true): %s" % _charco_aparece_ok)


func _disparar_francotirador() -> void:
	var franco = _jefe.get_node("Habilidades/HabilidadFrancotiradorGuardian")
	_vida_antes_franco = _vida_jugador.salud_actual
	franco.activar(Vector2.RIGHT, 1.0)


func _probar_dano_francotirador() -> void:
	_franco_dano_ok = _vida_jugador.salud_actual < _vida_antes_franco
	print("Francotirador conecta daño tras la pose real (esperado que baje de %.1f): %.1f" % [
		_vida_antes_franco, _vida_jugador.salud_actual])


func _disparar_transicion_fase2() -> void:
	var vida_jefe = _jefe.get_node("VidaComponente")
	# Justo por debajo del umbral de fase 2 (0.75 de 2200 = 1650): deja
	# 1450 (0.659), cómodamente por debajo.
	vida_jefe.quitar_vida(750.0)


func _probar_transicion_fase2() -> void:
	var selector = _jefe.get_node_or_null(
		"ArbolComportamiento/Selector/Atacar/SelectorHabilidades")
	# 3 de fase 1 (combo/barrido/amague) + 2 de fase 2 (lanzas/francotirador).
	_fase2_agrega_habilidades_ok = selector != null and selector.habilidades.size() == 5
	print("Fase 2 suma lluvia de lanzas y francotirador al selector (esperado true, size=%d): %s" % [
		selector.habilidades.size() if selector else -1, _fase2_agrega_habilidades_ok])

	var combo = _jefe.get_node_or_null("Habilidades/HabilidadComboGuardian")
	var barrido = _jefe.get_node_or_null("Habilidades/HabilidadBarridoGuardian")
	_fase2_activa_charco_ok = combo != null and barrido != null \
		and combo.deja_charco and barrido.deja_charco
	print("Fase 2 activa deja_charco en combo y barrido (esperado true): %s" % _fase2_activa_charco_ok)


func _informar() -> bool:
	var exito := _charco_aparece_ok and _franco_dano_ok and _fase2_agrega_habilidades_ok \
		and _fase2_activa_charco_ok
	print("PRUEBA GUARDIAN FASE2 %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
