# =============================================================================
# Prueba central del diseño del Guardián Quebrado: con el parry direccional
# de HabilidadCorte activo y de cara al jefe...
#   1. HabilidadBarridoGuardian.golpear() (golpe de ÁREA, vía
#      Combate.golpear_area()) SÍ queda bloqueado — es la mecánica que
#      justifica toda la habilidad Corte.
#   2. GolpeVerdaderoGuardian (golpe único, sin es_area) NO queda bloqueado
#      — el jugador tiene que aprender a leer cuál es cuál, no puede
#      simplemente parar Corte en cada ataque.
#
# Se llama a HabilidadBarridoGuardian.golpear() DIRECTO (estático), sin
# pasar por el timer de pose: ese mecanismo de telegraph ya es una copia
# probada de HabilidadFlechaArquero, lo nuevo y de riesgo real es golpear().
#   godot --headless --path . --script res://pruebas/prueba_guardian_corte_bloquea_barrido.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe: CharacterBody2D
var _jugador: CharacterBody2D
var _vida_jugador: VidaComponente

var _barrido_bloqueado_ok := false
var _golpe_verdadero_no_bloqueado_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_activar_parry()
			var antes := _vida_jugador.salud_actual
			# Sin tipos estáticos hacia HabilidadBarridoGuardian (ver cabecera
			# de prueba_area_no_daña_aliados.gd): golpear() es static, así que
			# se llama vía .call() sobre el GDScript cargado en runtime, no
			# por referencia directa a la clase — esa referencia obligaría a
			# compilar Combate.gd (y su Utils) ANTES de que existan los
			# autoloads, y revienta.
			var script_barrido := load("res://escenas/habilidades/barrido_guardian/HabilidadBarridoGuardian.gd")
			script_barrido.call("golpear", _jefe, Vector2.RIGHT, 150.0, 90.0, 30.0,
				Enums.Habilidad.TipoDano.FISICO, false)
			_barrido_bloqueado_ok = _vida_jugador.salud_actual == antes
			print("Barrido (área) bloqueado por el parry (esperado sin cambio): %.1f -> %.1f" % [
				antes, _vida_jugador.salud_actual])

			var piscinas := root.get_node("/root/GestorPiscinas")
			var golpe = piscinas.obtener(
				load("res://escenas/habilidades/golpe_verdadero_guardian/GolpeVerdaderoGuardian.tscn"))
			golpe.global_position = _jugador.global_position - Vector2(4, 0)
			golpe.configurar(30.0, 56.0, _jefe, 0.15, Enums.Habilidad.TipoDano.FISICO, false)
		6:
			_golpe_verdadero_no_bloqueado_ok = _vida_jugador.salud_actual < 200.0
			print("Golpe verdadero NO bloqueado por el mismo parry (esperado que baje de 200): %.1f" % \
				_vida_jugador.salud_actual)
			return _informar()
	return false


func _activar_parry() -> void:
	var parry = (load("res://componentes/ParryComponente.gd") as GDScript).new()
	parry.name = "ParryComponente"
	_jugador.add_child(parry)
	# El jefe está a la IZQUIERDA del jugador -> guardia hacia la izquierda,
	# la orientación más favorable posible para que el parry bloquee.
	parry.activar(5.0, Vector2.LEFT)


func _crear_entidad(pos: Vector2, grupo: String) -> CharacterBody2D:
	var e := CharacterBody2D.new()
	e.add_to_group(grupo)
	e.collision_layer = 2
	root.add_child(e)
	e.global_position = pos
	var vida = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	vida.name = "VidaComponente"
	vida.salud_maxima = 200.0
	e.add_child(vida)
	vida.salud_actual = 200.0
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 12.0
	forma.shape = circ
	vida.add_child(forma)
	return e


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	_jefe = _crear_entidad(Vector2.ZERO, "enemigos")
	_jugador = _crear_entidad(Vector2(60, 0), "jugadores")
	_vida_jugador = _jugador.get_node("VidaComponente") as VidaComponente


func _informar() -> bool:
	var exito := _barrido_bloqueado_ok and _golpe_verdadero_no_bloqueado_ok
	print("  barrido bloqueado por el parry: %s" % _barrido_bloqueado_ok)
	print("  golpe verdadero NO bloqueado: %s" % _golpe_verdadero_no_bloqueado_ok)
	print("PRUEBA GUARDIAN CORTE BLOQUEA BARRIDO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
