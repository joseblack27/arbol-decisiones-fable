# =============================================================================
# Prueba de integración completa del Guardián Quebrado — la que su propio
# comentario de clase señalaba como faltante: "las 4 fases seguidas y las
# transiciones completas de punta a punta". prueba_guardian_fase4.gd YA
# recorre las 4 fases en una sola corrida, pero solo valida en detalle lo
# de fase 4 (refuerzos, arremetida, miedo) — el total de habilidades al
# final (10) no distingue SI CADA FASE agregó lo que le tocaba a ELLA, ni
# si el golpe de transición (GolpeVerdaderoGuardian, daño verdadero) pega
# de verdad en CADA cruce, ni si el jefe queda matable después de todo
# este camino. Esta prueba cierra esos huecos específicos:
#   1. Fase 1 -> 2: golpe de transición pega, se suman lluvia de lanzas y
#      francotirador AL SELECTOR CORRECTO (por identidad, no solo cuenta),
#      y combo/barrido quedan marcados deja_charco.
#   2. Fase 2 -> 3: golpe de transición pega, se suman golpe corrupto/muro/
#      escudo reflectante Y el castigo por cooldown de Corte a SU rama
#      propia (CastigoCorte/AtacarCastigo/SelectorCastigo).
#   3. Fase 3 -> 4: golpe de transición pega, se suman arremetida/miedo.
#   4. Tras las 3 transiciones, el jefe sigue siendo matable de verdad
#      (bajarlo a 0 lo mata, sin quedar trabado en ningún estado a mitad
#      de transición).
#
# Mismo criterio que prueba_guardian_fase4.gd: IA autónoma apagada
# (ArbolComportamiento.process_mode = DISABLED) para que la única fuente
# de daño al jugador sean los golpes de transición que se están probando,
# y esperas por fotogramas (pausa_cambio_fase=1.3s de sobra) en vez de
# await real, para no bloquear el bucle _process() de la prueba.
#   godot --headless --path . --script res://pruebas/prueba_guardian_4_fases_completas.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _jugador
var _vida_jugador
var _vida_jefe

var _vida_jugador_antes_transicion := 0.0

var _fase1_a_2_golpe_ok := false
var _fase1_a_2_habilidades_ok := false
var _fase2_a_3_golpe_ok := false
var _fase2_a_3_habilidades_ok := false
var _fase3_a_4_golpe_ok := false
var _fase3_a_4_habilidades_ok := false
var _jefe_sigue_matable_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_cruzar_a_fase(2, 600.0)  # 2200 -> 1600 (0.727) <= UMBRAL_FASE_2 (0.75).
		# pausa_cambio_fase=1.3s a ~60 físicas/seg -> ~78 fotogramas; de sobra.
		250:
			_verificar_fase2()
			_cruzar_a_fase(3, 550.0)  # 1600 -> 1050 (0.477) <= UMBRAL_FASE_3 (0.50).
		500:
			_verificar_fase3()
			_cruzar_a_fase(4, 550.0)  # 1050 -> 500 (0.227) <= UMBRAL_FASE_4 (0.25).
		750:
			_verificar_fase4()
			_probar_jefe_sigue_matable()
			return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	_jefe = (load("res://escenas/enemigos/EnemigoGuardianQuebrado.tscn") as PackedScene).instantiate()
	raiz.add_child(_jefe)
	_jefe.global_position = Vector2.ZERO
	# Apaga la IA autónoma — la única fuente de daño al jugador en esta
	# prueba tienen que ser los golpes de transición, no ataques sueltos
	# elegidos al azar por el árbol de comportamiento.
	_jefe.get_node("ArbolComportamiento").process_mode = Node.PROCESS_MODE_DISABLED
	_vida_jefe = _jefe.get_node("VidaComponente")

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador.name = "1"
	raiz.add_child(_jugador)
	_jugador.global_position = Vector2(60, 0)
	_vida_jugador = _jugador.get_node("VidaComponente")
	_vida_jugador.salud_maxima = 100000.0
	_vida_jugador.salud_actual = 100000.0
	_vida_jugador.cancelar_invulnerabilidad()

	# Defensa alta a propósito (mismo criterio que prueba_guardian_fase4.gd):
	# el golpe de transición usa ignora_defensa=true, así que tiene que pegar
	# casi entero IGUAL con esto puesto — si algún día alguien le saca ese
	# flag por error, esta prueba lo detecta.
	var atributos = _jugador.get_node_or_null("AtributosComponente")
	if atributos and atributos.base:
		atributos.base.defensa = 500.0
		atributos.base.resistencia_fisica = 80.0
		# Sin esto, la regeneración pasiva (un % de salud_maxima=100000, un
		# número enorme por tick) tapaba por completo el golpe de transición
		# durante los ~4s de espera entre cruzar el umbral y revisar el
		# resultado — la "pérdida" medida daba negativa, no porque el golpe
		# fallara sino porque el propio regen la superaba. Esta prueba mide
		# el golpe de transición en sí, no la interacción con el regen.
		atributos.base.regeneracion_vida = 0.0
		atributos.base.regeneracion_vida_plana = 0.0

	var memoria = _jefe.get_node("ArbolComportamiento/MemoriaBT")
	memoria.establecer("objetivo", _jugador)


func _cruzar_a_fase(_fase_esperada: int, dano: float) -> void:
	_vida_jugador_antes_transicion = _vida_jugador.salud_actual
	_vida_jefe.quitar_vida(dano)


func _verificar_fase2() -> void:
	var perdida: float = _vida_jugador_antes_transicion - _vida_jugador.salud_actual
	_fase1_a_2_golpe_ok = perdida >= 25.0 and _jefe.get("_fase") == 2
	print("Fase 1->2: golpe de transición pega y _fase pasa a 2 (esperado true, perdida=%.1f, fase=%s): %s" % [
		perdida, _jefe.get("_fase"), _fase1_a_2_golpe_ok])

	var selector_atacar = _jefe.get_node_or_null("ArbolComportamiento/Selector/Atacar/SelectorHabilidades")
	var tiene_lanzas: bool = selector_atacar != null and selector_atacar.habilidades.has(_jefe.habilidad_lluvia_lanzas_bt)
	var tiene_francotirador: bool = selector_atacar != null and selector_atacar.habilidades.has(_jefe.habilidad_francotirador_bt)
	var combo = _jefe.get_node_or_null("Habilidades/HabilidadComboGuardian")
	var barrido = _jefe.get_node_or_null("Habilidades/HabilidadBarridoGuardian")
	var dejan_charco: bool = combo != null and combo.deja_charco and barrido != null and barrido.deja_charco
	_fase1_a_2_habilidades_ok = tiene_lanzas and tiene_francotirador and dejan_charco
	print("Fase 2 suma lluvia de lanzas + francotirador al selector correcto y activa deja_charco (esperado true): %s" \
		% _fase1_a_2_habilidades_ok)


func _verificar_fase3() -> void:
	var perdida: float = _vida_jugador_antes_transicion - _vida_jugador.salud_actual
	_fase2_a_3_golpe_ok = perdida >= 25.0 and _jefe.get("_fase") == 3
	print("Fase 2->3: golpe de transición pega y _fase pasa a 3 (esperado true, perdida=%.1f, fase=%s): %s" % [
		perdida, _jefe.get("_fase"), _fase2_a_3_golpe_ok])

	var selector_atacar = _jefe.get_node_or_null("ArbolComportamiento/Selector/Atacar/SelectorHabilidades")
	var tiene_corrupto: bool = selector_atacar != null and selector_atacar.habilidades.has(_jefe.habilidad_golpe_corrupto_bt)
	var tiene_muro: bool = selector_atacar != null and selector_atacar.habilidades.has(_jefe.habilidad_muro_bt)
	var tiene_escudo: bool = selector_atacar != null and selector_atacar.habilidades.has(_jefe.habilidad_escudo_reflectante_bt)
	var selector_castigo = _jefe.get_node_or_null(
		"ArbolComportamiento/Selector/CastigoCorte/AtacarCastigo/SelectorCastigo")
	var tiene_castigo: bool = selector_castigo != null and selector_castigo.habilidades.has(_jefe.habilidad_castigo_bt)
	_fase2_a_3_habilidades_ok = tiene_corrupto and tiene_muro and tiene_escudo and tiene_castigo
	print("Fase 3 suma golpe corrupto/muro/escudo reflectante y el castigo por cooldown a su propia rama (esperado true): %s" \
		% _fase2_a_3_habilidades_ok)


func _verificar_fase4() -> void:
	var perdida: float = _vida_jugador_antes_transicion - _vida_jugador.salud_actual
	_fase3_a_4_golpe_ok = perdida >= 25.0 and _jefe.get("_fase") == 4
	print("Fase 3->4: golpe de transición pega y _fase pasa a 4 (esperado true, perdida=%.1f, fase=%s): %s" % [
		perdida, _jefe.get("_fase"), _fase3_a_4_golpe_ok])

	var selector_atacar = _jefe.get_node_or_null("ArbolComportamiento/Selector/Atacar/SelectorHabilidades")
	var tiene_arremetida: bool = selector_atacar != null and selector_atacar.habilidades.has(_jefe.habilidad_arremetida_bt)
	var tiene_miedo: bool = selector_atacar != null and selector_atacar.habilidades.has(_jefe.habilidad_miedo_bt)
	_fase3_a_4_habilidades_ok = tiene_arremetida and tiene_miedo
	print("Fase 4 suma arremetida y miedo al selector correcto (esperado true): %s" % _fase3_a_4_habilidades_ok)


## El punto central de esta prueba: después de las 3 transiciones (pausas,
## invulnerabilidad temporal del jefe, reanudaciones), el jefe TIENE que
## seguir siendo un enemigo normal y matable — nada de esto lo deja
## trabado a mitad de una fase o inmune para siempre.
func _probar_jefe_sigue_matable() -> void:
	_vida_jefe.quitar_vida(100000.0)
	_jefe_sigue_matable_ok = _jefe.get("_muerto") == true
	print("Tras las 3 transiciones, el jefe sigue siendo matable de verdad (esperado true): %s" \
		% _jefe_sigue_matable_ok)


func _informar() -> bool:
	var exito := _fase1_a_2_golpe_ok and _fase1_a_2_habilidades_ok \
		and _fase2_a_3_golpe_ok and _fase2_a_3_habilidades_ok \
		and _fase3_a_4_golpe_ok and _fase3_a_4_habilidades_ok \
		and _jefe_sigue_matable_ok
	print("PRUEBA GUARDIAN 4 FASES COMPLETAS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
