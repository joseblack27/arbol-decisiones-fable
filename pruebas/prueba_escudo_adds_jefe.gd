# =============================================================================
# Prueba: el mecanismo de escudo por adds de EnemigoArañaReina — mientras
# vivan los refuerzos invocados, un EscudoComponente propio reduce el daño
# recibido 70%; al morir el último, se apaga solo en <=1s (EscudoComponente
# no tiene un desactivar() explícito — se renueva cada tick, así que basta
# con dejar de llamar activar() para que se agote solo).
#   godot --headless --path . --script res://pruebas/prueba_escudo_adds_jefe.gd
# =============================================================================
extends SceneTree

var _reina
var _lobo1
var _lobo2
var _f := 0

var _escudo_activo_con_adds := false
var _reduccion_correcta := false
var _escudo_cae_tras_morir := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		3:
			var escudo = _reina.get_node_or_null("EscudoComponente")
			_escudo_activo_con_adds = escudo != null and escudo.esta_activo()
			print("Escudo activo mientras viven los adds (esperado true): %s" % _escudo_activo_con_adds)
			var reducido = escudo.aplicar(100.0) if escudo else 100.0
			_reduccion_correcta = is_equal_approx(reducido, 30.0)
			print("Reduce el daño al 70%% (esperado 30.0, %.1f): %s" % [reducido, _reduccion_correcta])

			# Matar a los dos adds.
			_lobo1.get_node("VidaComponente").quitar_vida(99999.0)
			_lobo2.get_node("VidaComponente").quitar_vida(99999.0)
		65:
			# El escudo se refresca con duracion=1.0 cada tick mientras hay
			# adds — 65 fotogramas (~1.1s reales) de sobra para que, tras
			# dejar de refrescarse, se agote solo.
			var escudo = _reina.get_node_or_null("EscudoComponente")
			_escudo_cae_tras_morir = escudo == null or not escudo.esta_activo()
			print("Escudo cae en <=1s tras morir todos los adds (esperado true): %s" % \
				_escudo_cae_tras_morir)
			return _informar()
	return false


func _montar() -> void:
	var contenedor := Node2D.new()
	contenedor.name = "Enemigos"
	root.add_child(contenedor)
	current_scene = contenedor

	var escena_reina := load("res://escenas/enemigos/EnemigoArañaReina.tscn") as PackedScene
	_reina = escena_reina.instantiate()
	contenedor.add_child(_reina)
	_reina.global_position = Vector2.ZERO

	var escena_lobo := load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene
	var lista: Array[PackedScene] = [escena_lobo, escena_lobo]
	_reina._invocar_refuerzos(lista)

	_lobo1 = _reina._adds[0]
	_lobo2 = _reina._adds[1]
	# Sin IA: solo interesa el escudo, no que anden deambulando.
	_lobo1.get_node("ArbolComportamiento").activo = false
	_lobo2.get_node("ArbolComportamiento").activo = false


func _informar() -> bool:
	var exito := _escudo_activo_con_adds and _reduccion_correcta and _escudo_cae_tras_morir
	print("PRUEBA ESCUDO ADDS JEFE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
