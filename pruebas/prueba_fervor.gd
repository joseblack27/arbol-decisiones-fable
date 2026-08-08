# =============================================================================
# Prueba de HabilidadFervor: mientras dura, el resto de las habilidades
# equipadas recargan más rápido — sin afectarse a sí misma, y sin afectar
# a nadie una vez que vence.
#   godot --headless --path . --script res://pruebas/prueba_fervor.gd
# =============================================================================
extends SceneTree

var _f := 0
var _jugador: CharacterBody2D
var _fervor
var _otra

var _no_se_afecta_a_si_misma_ok := false
var _acelera_otras_habilidades_ok := false
var _vuelve_a_normal_al_vencer_ok := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			# Con Fervor activo (0.3s de duración en esta prueba):
			_fervor.call("_ejecutar", Vector2.ZERO, 1.0)
		5:
			_no_se_afecta_a_si_misma_ok = is_equal_approx(_fervor.multiplicador_recarga, 1.0)
			_acelera_otras_habilidades_ok = is_equal_approx(_otra.multiplicador_recarga, _fervor.multiplicador_velocidad)
			print("Fervor no se acelera a sí misma (esperado true): %s" % _no_se_afecta_a_si_misma_ok)
			print("Fervor acelera a la otra habilidad (esperado x%.0f): %s (multiplicador real %.1f)" % [
				_fervor.multiplicador_velocidad, _acelera_otras_habilidades_ok, _otra.multiplicador_recarga])
		# duracion_fervor = 0.3s en esta prueba -> de sobra a los 40 fotogramas.
		40:
			_vuelve_a_normal_al_vencer_ok = is_equal_approx(_otra.multiplicador_recarga, 1.0)
			print("Al vencer Fervor, la otra habilidad vuelve a velocidad normal (esperado true): %s" % _vuelve_a_normal_al_vencer_ok)
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	escena.add_child(_jugador)

	var guion_fervor := load("res://escenas/habilidades/fervor/HabilidadFervor.gd") as GDScript
	_fervor = guion_fervor.new()
	_fervor.slot_index = 0
	_fervor.costo_energia = 0.0
	_fervor.duracion_recarga = 0.1
	_fervor.duracion_fervor = 0.3
	_fervor.multiplicador_velocidad = 3.0

	# Una segunda habilidad cualquiera (Golpe básico sirve, no importa cuál)
	# para comprobar que Fervor la acelera a ELLA, no a sí misma.
	var guion_otra := load("res://escenas/habilidades/golpe_basico/HabilidadGolpeBasico.gd") as GDScript
	_otra = guion_otra.new()
	_otra.slot_index = 1
	_otra.costo_energia = 0.0
	_otra.duracion_recarga = 5.0

	# Hijas DIRECTAS de _jugador (no de un contenedor intermedio): mismo
	# criterio que SlotHabilidades._instanciar() en el juego real —
	# Fervor busca hermanas con entidad_dueña.get_children() directo.
	_jugador.add_child(_fervor)
	_fervor.entidad_dueña = _jugador
	_jugador.add_child(_otra)
	_otra.entidad_dueña = _jugador


func _informar() -> bool:
	var exito := _no_se_afecta_a_si_misma_ok and _acelera_otras_habilidades_ok \
		and _vuelve_a_normal_al_vencer_ok
	print("  no se afecta a sí misma: %s" % _no_se_afecta_a_si_misma_ok)
	print("  acelera otras habilidades: %s" % _acelera_otras_habilidades_ok)
	print("  vuelve a normal al vencer: %s" % _vuelve_a_normal_al_vencer_ok)
	print("PRUEBA FERVOR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
