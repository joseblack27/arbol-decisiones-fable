# =============================================================================
# Prueba de humo: EnemigoGuardianQuebrado.tscn instancia sin errores, sus
# nodos clave existen, y corre unos cuantos fotogramas reales (IA incluida)
# sin reventar. No valida comportamiento fino de combate — eso ya lo cubren
# las pruebas puntuales de cada habilidad; esto es "¿la escena está bien
# armada?".
#   godot --headless --path . --script res://pruebas/prueba_guardian_escena_carga.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
	if _fotogramas == 90:
		return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	var escena := load("res://escenas/enemigos/EnemigoGuardianQuebrado.tscn")
	_jefe = escena.instantiate()
	raiz.add_child(_jefe)
	_jefe.global_position = Vector2.ZERO


func _informar() -> bool:
	var vida = _jefe.get_node_or_null("VidaComponente")
	var mov = _jefe.get_node_or_null("MovimientoComponente")
	var vision = _jefe.get_node_or_null("VisionComponente")
	var anim = _jefe.get_node_or_null("AnimacionComponente")
	var arbol = _jefe.get_node_or_null("ArbolComportamiento")
	var habilidades = _jefe.get_node_or_null("Habilidades")
	var combo = _jefe.get_node_or_null("Habilidades/HabilidadComboGuardian")
	var barrido = _jefe.get_node_or_null("Habilidades/HabilidadBarridoGuardian")
	var amague = _jefe.get_node_or_null("Habilidades/HabilidadAmagueGuardian")
	var golpe_transicion = _jefe.get_node_or_null("Habilidades/HabilidadGolpeVerdaderoTransicion")
	var selector_habilidades = _jefe.get_node_or_null(
		"ArbolComportamiento/Selector/Atacar/SelectorHabilidades")

	var nodos_ok := vida != null and mov != null and vision != null and anim != null \
		and arbol != null and habilidades != null and combo != null and barrido != null \
		and amague != null and golpe_transicion != null and selector_habilidades != null
	print("Nodos clave presentes (esperado true): %s" % nodos_ok)

	var vida_maxima_ok: bool = vida != null and vida.obtener_vida_maxima() == 2200.0
	print("Vida máxima viene del EnemigoDatos (esperado 2200): %s" % vida_maxima_ok)

	var habilidades_cargadas: bool = selector_habilidades != null \
		and selector_habilidades.habilidades.size() == 3
	print("SelectorHabilidades tiene las 3 habilidades de fase 1 (esperado true): %s" % \
		habilidades_cargadas)

	var no_murio: bool = _jefe != null and is_instance_valid(_jefe) and not _jefe.esta_muerto()
	print("Sigue vivo tras 90 fotogramas de IA real (esperado true): %s" % no_murio)

	var exito := nodos_ok and vida_maxima_ok and habilidades_cargadas and no_murio
	print("PRUEBA GUARDIAN ESCENA CARGA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
