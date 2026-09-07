# =============================================================================
# Prueba de integración completa del Heraldo de la Corrupción (jefe de la
# rama Corrupción, ver el plan "Mina — Corrupción" en C:\Users\USER\.claude\
# plans\cheeky-mixing-melody.md) — mirror de
# prueba_forja_4_fases_completas.gd.
#   1. Fase 1 -> 2 (<=0.75): golpe de transición pega, se suman Golpe
#      Corrupto y Muro de Corrupción.
#   2. Fase 2 -> 3 (<=0.50): golpe de transición pega, se suman Grito de
#      Terror y Velo de Sombras.
#   3. Fase 3 -> 4 (<=0.25): golpe de transición pega, se suma Embestida de
#      las Sombras, se invocan los 2 refuerzos, se activa la furia final.
#   4. Tras las 3 transiciones, el jefe sigue siendo matable de verdad.
#   godot --headless --path . --script res://pruebas/prueba_corrupcion_4_fases_completas.gd
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
var _fase4_refuerzos_ok := false
var _jefe_sigue_matable_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_cruzar_a_fase(700.0)  # 2400 -> 1700 (0.708) <= UMBRAL_FASE_2 (0.75).
		250:
			_verificar_fase2()
			_cruzar_a_fase(600.0)  # 1700 -> 1100 (0.458) <= UMBRAL_FASE_3 (0.50).
		500:
			_verificar_fase3()
			_cruzar_a_fase(600.0)  # 1100 -> 500 (0.208) <= UMBRAL_FASE_4 (0.25).
		750:
			_verificar_fase4()
			_probar_jefe_sigue_matable()
			return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	_jefe = (load("res://escenas/enemigos/EnemigoHeraldoCorrupcion.tscn") as PackedScene).instantiate()
	raiz.add_child(_jefe)
	_jefe.global_position = Vector2.ZERO
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

	var atributos = _jugador.get_node_or_null("AtributosComponente")
	if atributos and atributos.base:
		atributos.base.defensa = 500.0
		atributos.base.resistencia_fisica = 80.0
		atributos.base.regeneracion_vida = 0.0
		atributos.base.regeneracion_vida_plana = 0.0

	var memoria = _jefe.get_node("ArbolComportamiento/MemoriaBT")
	memoria.establecer("objetivo", _jugador)


func _cruzar_a_fase(dano: float) -> void:
	_vida_jugador_antes_transicion = _vida_jugador.salud_actual
	_vida_jefe.quitar_vida(dano)


func _verificar_fase2() -> void:
	var perdida: float = _vida_jugador_antes_transicion - _vida_jugador.salud_actual
	_fase1_a_2_golpe_ok = perdida >= 25.0 and _jefe.get("_fase") == 2
	print("Fase 1->2: golpe de transición pega y _fase pasa a 2 (esperado true, perdida=%.1f, fase=%s): %s" % [
		perdida, _jefe.get("_fase"), _fase1_a_2_golpe_ok])

	var selector = _jefe.get_node_or_null("ArbolComportamiento/Selector/Atacar/SelectorHabilidades")
	var tiene_golpe_corrupto: bool = selector != null and selector.habilidades.has(_jefe.habilidad_golpe_corrupto_bt)
	var tiene_muro: bool = selector != null and selector.habilidades.has(_jefe.habilidad_muro_bt)
	_fase1_a_2_habilidades_ok = tiene_golpe_corrupto and tiene_muro
	print("Fase 2 suma Golpe Corrupto + Muro al selector correcto (esperado true): %s" % _fase1_a_2_habilidades_ok)


func _verificar_fase3() -> void:
	var perdida: float = _vida_jugador_antes_transicion - _vida_jugador.salud_actual
	_fase2_a_3_golpe_ok = perdida >= 25.0 and _jefe.get("_fase") == 3
	print("Fase 2->3: golpe de transición pega y _fase pasa a 3 (esperado true, perdida=%.1f, fase=%s): %s" % [
		perdida, _jefe.get("_fase"), _fase2_a_3_golpe_ok])

	var selector = _jefe.get_node_or_null("ArbolComportamiento/Selector/Atacar/SelectorHabilidades")
	var tiene_miedo: bool = selector != null and selector.habilidades.has(_jefe.habilidad_miedo_bt)
	var tiene_escudo: bool = selector != null and selector.habilidades.has(_jefe.habilidad_escudo_bt)
	_fase2_a_3_habilidades_ok = tiene_miedo and tiene_escudo
	print("Fase 3 suma Miedo + Escudo Reflectante al selector correcto (esperado true): %s" % _fase2_a_3_habilidades_ok)


func _verificar_fase4() -> void:
	var perdida: float = _vida_jugador_antes_transicion - _vida_jugador.salud_actual
	_fase3_a_4_golpe_ok = perdida >= 25.0 and _jefe.get("_fase") == 4
	print("Fase 3->4: golpe de transición pega y _fase pasa a 4 (esperado true, perdida=%.1f, fase=%s): %s" % [
		perdida, _jefe.get("_fase"), _fase3_a_4_golpe_ok])

	var selector = _jefe.get_node_or_null("ArbolComportamiento/Selector/Atacar/SelectorHabilidades")
	var tiene_embestida: bool = selector != null and selector.habilidades.has(_jefe.habilidad_embestida_bt)
	var tamaño: int = selector.habilidades.size() if selector else -1
	_fase3_a_4_habilidades_ok = tiene_embestida and tamaño == 7
	print("Fase 4 suma Embestida al selector (esperado true, size=%d esperado 7): %s" % [
		tamaño, _fase3_a_4_habilidades_ok])

	var contenedor = _jefe.get_parent()
	var refuerzos := 0
	for hijo in contenedor.get_children():
		if hijo == _jefe or hijo == _jugador:
			continue
		var script: Script = hijo.get_script()
		if script and (script.resource_path.ends_with("EnemigoLobo.gd") \
				or script.resource_path.ends_with("EnemigoAraña.gd")):
			refuerzos += 1
	_fase4_refuerzos_ok = refuerzos == 2
	print("Fase 4 invoca los 2 refuerzos (Lobo + Araña) (esperado true, encontrados=%d): %s" % [
		refuerzos, _fase4_refuerzos_ok])


func _probar_jefe_sigue_matable() -> void:
	_vida_jefe.quitar_vida(100000.0)
	_jefe_sigue_matable_ok = _jefe.get("_muerto") == true
	print("Tras las 3 transiciones, el jefe sigue siendo matable de verdad (esperado true): %s" \
		% _jefe_sigue_matable_ok)


func _informar() -> bool:
	var exito := _fase1_a_2_golpe_ok and _fase1_a_2_habilidades_ok \
		and _fase2_a_3_golpe_ok and _fase2_a_3_habilidades_ok \
		and _fase3_a_4_golpe_ok and _fase3_a_4_habilidades_ok \
		and _fase4_refuerzos_ok and _jefe_sigue_matable_ok
	print("PRUEBA CORRUPCION 4 FASES COMPLETAS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
