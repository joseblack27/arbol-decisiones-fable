# =============================================================================
# Prueba de HabilidadAmagueGuardian:
#   1. _probabilidad_golpe_unico() lee de verdad el cooldown de Corte del
#      objetivo — CHEQUEO DETERMINÍSTICO (sin randf() de por medio): con
#      Corte disponible devuelve la probabilidad base (0.5), con Corte en
#      cooldown devuelve base+0.4 (0.9). La versión anterior de esta prueba
#      NO detectaba esto: _jefe era un CharacterBody2D sin script, sin la
#      propiedad "memoria" — _objetivo_actual() siempre devolvía null y la
#      probabilidad quedaba fija en la base para los DOS lotes, así que la
#      comparación estadística entre lotes en realidad comparaba dos
#      muestras de la MISMA distribución (fallaba ~50% de las corridas, sin
#      relación con el mecanismo real). Corregido dándole a _jefe una
#      "memoria" real (MemoriaBT) con "objetivo" apuntando al jugador.
#   2. La MISMA pose puede terminar en barrido real (área, bloqueable por
#      el parry de Corte) o en golpe único (no bloqueable) — probado UNA
#      vez cada rama de forma determinística (mismo patrón ya usado en
#      prueba_guardian_corte_bloquea_barrido.gd), no por conteo estadístico.
#
# Se llama _al_terminar_pose() directo (con el guard de _id_ataque puesto a
# mano) en vez de esperar el timer real de pose — el mecanismo de pose+timer
# ya está probado por HabilidadBarridoGuardian/HabilidadFlechaArquero.
#
# Sin tipos estáticos hacia HabilidadAmagueGuardian (ver cabecera de
# prueba_area_no_daña_aliados.gd).
#   godot --headless --path . --script res://pruebas/prueba_guardian_fase1_amague.gd
# =============================================================================
extends SceneTree

var _jefe
var _jugador
var _vida_jugador
var _amague
var _memoria

var _f := 0

var _prob_disponible_ok := false
var _prob_cooldown_ok := false
var _rama_barrido_ok := false
var _rama_unico_ok := false


static func _script_jefe() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var memoria = null
"""
	guion.reload()
	return guion


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		5:
			_probar_probabilidad()
			_probar_rama_barrido()
			_probar_rama_unico_antes = _vida_jugador.salud_actual
			_amague.call("_golpear_unico", _jefe, Vector2.RIGHT)
		6:
			# _golpear_unico() aplica el daño deferred (GolpeVerdaderoGuardian
			# .configurar) — recién acá, un fotograma después, se puede leer.
			_probar_rama_unico_resultado()
			return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	_jefe = CharacterBody2D.new()
	_jefe.set_script(_script_jefe())
	_jefe.add_to_group("enemigos")
	_jefe.collision_layer = 2
	raiz.add_child(_jefe)
	_jefe.global_position = Vector2.ZERO
	var vida_jefe = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	vida_jefe.name = "VidaComponente"
	vida_jefe.salud_maxima = 1000.0
	_jefe.add_child(vida_jefe)
	vida_jefe.salud_actual = 1000.0

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena_jugador.instantiate()
	_jugador.name = "1"
	raiz.add_child(_jugador)
	_jugador.global_position = Vector2(60, 0)
	_vida_jugador = _jugador.get_node("VidaComponente")
	_vida_jugador.salud_maxima = 100000.0
	_vida_jugador.salud_actual = 100000.0
	# Jugador.tscn arranca con invulnerabilidad de aparición.
	_vida_jugador.cancelar_invulnerabilidad()

	var slots = _jugador.get_node("SlotHabilidades")
	slots.equipar(0, load("res://recursos/habilidades/corte.tres"))

	_memoria = (load("res://componentes/arbol_comportamiento/MemoriaBT.gd") as GDScript).new()
	raiz.add_child(_memoria)
	_memoria.establecer("objetivo", _jugador)
	_jefe.memoria = _memoria

	_amague = (load("res://escenas/habilidades/amague_guardian/HabilidadAmagueGuardian.gd") as GDScript).new()
	_amague.entidad_dueña = _jefe
	_amague.probabilidad_golpe_unico = 0.5
	_amague.dano_barrido = 300.0
	_amague.dano_golpe_verdadero = 300.0
	_jefe.add_child(_amague)


func _hab_corte():
	var slots = _jugador.get_node("SlotHabilidades")
	return slots.obtener(0)


func _probar_probabilidad() -> void:
	_hab_corte()._recarga_restante = 0.0
	var prob_disponible: float = _amague.call("_probabilidad_golpe_unico")
	_prob_disponible_ok = is_equal_approx(prob_disponible, 0.5)
	print("Corte disponible -> probabilidad base (esperado 0.50): %.2f" % prob_disponible)

	_hab_corte()._recarga_restante = 5.0
	var prob_cooldown: float = _amague.call("_probabilidad_golpe_unico")
	_prob_cooldown_ok = is_equal_approx(prob_cooldown, 0.9)
	print("Corte en cooldown -> probabilidad + sesgo (esperado 0.90): %.2f" % prob_cooldown)

	_hab_corte()._recarga_restante = 0.0


func _probar_rama_barrido() -> void:
	var parry = (load("res://componentes/ParryComponente.gd") as GDScript).new()
	parry.name = "ParryComponente"
	_jugador.add_child(parry)
	parry.activar(5.0, Vector2.LEFT)

	var antes: float = _vida_jugador.salud_actual
	_amague._id_ataque += 1
	# HabilidadBarridoGuardian.golpear() directo (rama "barrido"), no
	# _al_terminar_pose() — evita depender de randf() para forzar la rama.
	var script_barrido := load("res://escenas/habilidades/barrido_guardian/HabilidadBarridoGuardian.gd")
	script_barrido.call("golpear", _jefe, Vector2.RIGHT, _amague.largo, _amague.ancho,
		_amague.dano_barrido, 0, false)
	_rama_barrido_ok = _vida_jugador.salud_actual == antes
	print("Rama barrido: bloqueada por el parry (esperado sin cambio): %.1f -> %.1f" % [
		antes, _vida_jugador.salud_actual])


var _probar_rama_unico_antes := 0.0


func _probar_rama_unico_resultado() -> void:
	_rama_unico_ok = _vida_jugador.salud_actual < _probar_rama_unico_antes
	print("Rama golpe único: NO bloqueada por el mismo parry (esperado que baje de %.1f): %.1f" % [
		_probar_rama_unico_antes, _vida_jugador.salud_actual])


func _informar() -> bool:
	var exito := _prob_disponible_ok and _prob_cooldown_ok and _rama_barrido_ok and _rama_unico_ok
	print("PRUEBA GUARDIAN FASE1 AMAGUE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
