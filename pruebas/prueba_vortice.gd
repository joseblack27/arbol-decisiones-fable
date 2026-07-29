# =============================================================================
# Prueba de HabilidadVortice: se lanza a distancia (como HabilidadAreaEfecto)
# y queda FIJO en el punto donde cae, atrayendo repetidamente hacia su
# centro a los enemigos en su radio durante TODA su duración — no un solo
# tirón al activarse (a diferencia de OndaChoque), sino un campo sostenido
# para agrupar y MANTENER agrupados a los enemigos. Sin daño propio.
#
# Verifica:
#   1. Se coloca en el punto de caída (desplazado del jugador según
#      dirección/poder), no centrado en el jugador.
#   2. Los enemigos dentro del radio quedan con velocidad de atracción
#      apuntando HACIA el centro del campo.
#   3. La atracción se SOSTIENE más allá de la duración de un solo tirón
#      (duracion_empuje_por_tiron) — prueba de que de verdad tira más de
#      una vez, no un solo impulso al activarse.
#   4. NO hace daño.
#   5. Un aliado no recibe atracción (sin fuego amigo) y un enemigo FUERA
#      del radio tampoco.
#   6. Al vencer duracion_vortice, el campo se libera a la piscina (deja de
#      estar activo).
#   godot --headless --path . --script res://pruebas/prueba_vortice.gd
# =============================================================================
extends SceneTree

var _jugador
var _habilidad
var _piscinas
var _vortice
var _mob_cerca_a
var _mob_cerca_b
var _mob_lejos
var _aliado
var _fotogramas := 0

var _cae_en_el_punto_de_apuntado := false
var _atrae_hacia_el_centro_a := false
var _atrae_hacia_el_centro_b := false
var _sin_dano_a_los_enemigos := false
var _aliado_sin_atraccion_ni_dano := false
var _mob_lejos_sin_atraccion := false
var _sigue_atrayendo_pasado_un_solo_tiron := false
var _se_libera_al_vencer_la_duracion := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_habilidad._ejecutar(Vector2.RIGHT, 1.0)
		4:
			# configurar() difiere el primer tirón un fotograma (call_deferred).
			_vortice = _piscinas._activos[-1]
			_cae_en_el_punto_de_apuntado = _vortice.global_position.distance_to(Vector2(100, 0)) < 1.0
			print("El campo cae en el punto de apuntado, no en el jugador (esperado true, pos=%s): %s" % [
				_vortice.global_position, _cae_en_el_punto_de_apuntado])

			var mov_a = _mob_cerca_a.get_node("MovimientoComponente")
			var mov_b = _mob_cerca_b.get_node("MovimientoComponente")
			_atrae_hacia_el_centro_a = mov_a._empuje_restante > 0.0 and mov_a._empuje_velocidad.x < 0.0
			_atrae_hacia_el_centro_b = mov_b._empuje_restante > 0.0 and mov_b._empuje_velocidad.y < 0.0
			print("Atrae al mob A hacia el centro (esperado true, vel=%s): %s" % [mov_a._empuje_velocidad, _atrae_hacia_el_centro_a])
			print("Atrae al mob B hacia el centro (esperado true, vel=%s): %s" % [mov_b._empuje_velocidad, _atrae_hacia_el_centro_b])

			_sin_dano_a_los_enemigos = _mob_cerca_a.golpes == 0 and _mob_cerca_b.golpes == 0
			print("No hace daño a los enemigos (esperado true): %s" % _sin_dano_a_los_enemigos)

			var mov_aliado = _aliado.get_node("MovimientoComponente")
			_aliado_sin_atraccion_ni_dano = _aliado.golpes == 0 and mov_aliado._empuje_restante <= 0.0
			print("El aliado no recibe atracción ni daño (esperado true): %s" % _aliado_sin_atraccion_ni_dano)

			var mov_lejos = _mob_lejos.get_node("MovimientoComponente")
			_mob_lejos_sin_atraccion = mov_lejos._empuje_restante <= 0.0
			print("El mob fuera del radio no recibe atracción (esperado true): %s" % _mob_lejos_sin_atraccion)
		30:
			# ~0.43s reales desde el primer tirón: duracion_empuje_por_tiron=0.4s
			# ya venció, pero intervalo_atraccion=0.3s ya debería haber disparado
			# un SEGUNDO tirón que lo renovó — si solo tirara una vez (como
			# OndaChoque), acá _empuje_restante ya estaría en 0.
			var mov_a = _mob_cerca_a.get_node("MovimientoComponente")
			_sigue_atrayendo_pasado_un_solo_tiron = mov_a._empuje_restante > 0.0
			print("Sigue atrayendo más allá de un solo tirón (esperado true, sostenido): %s" % \
				_sigue_atrayendo_pasado_un_solo_tiron)
		280:
			# duracion_vortice=3.5s (~210 fotogramas) desde que se lanzó (~frame
			# 2) — con margen de sobra, el campo ya debería haberse liberado.
			_se_libera_al_vencer_la_duracion = not _piscinas._activos.has(_vortice)
			print("El campo se libera a la piscina al vencer su duración (esperado true): %s" % \
				_se_libera_al_vencer_la_duracion)
			return _informar()
	return false


static func _script_objetivo() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var golpes := 0
func quitar_vida(_cantidad: float, _f: Node = null, _t: int = 2, _cr: bool = false) -> void:
	golpes += 1
"""
	guion.reload()
	return guion


func _crear_objetivo(pos: Vector2, grupo: String) -> Node:
	var obj := CharacterBody2D.new()
	obj.set_script(_script_objetivo())
	obj.add_to_group(grupo)
	obj.global_position = pos
	root.add_child(obj)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 8.0
	forma.shape = circ
	obj.add_child(forma)

	var mov = (load("res://componentes/MovimientoComponente.gd") as GDScript).new()
	mov.name = "MovimientoComponente"
	mov.jugador = obj
	obj.add_child(mov)
	return obj


func _montar() -> void:
	_piscinas = root.get_node("/root/GestorPiscinas")

	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	_jugador.global_position = Vector2.ZERO
	root.add_child(_jugador)
	current_scene = _jugador

	# El campo va a caer en (100, 0) (dirección RIGHT, poder=1.0,
	# desplazamiento_maximo=100 en la prueba) — los mobs "cerca" están
	# dentro de radio_vortice (90px) de ESE punto, no del jugador.
	_mob_cerca_a = _crear_objetivo(Vector2(150, 0), "enemigos")
	_mob_cerca_b = _crear_objetivo(Vector2(100, 50), "enemigos")
	_mob_lejos   = _crear_objetivo(Vector2(400, 0), "enemigos")
	_aliado      = _crear_objetivo(Vector2(130, 0), "jugadores")

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var escena := load("res://escenas/habilidades/vortice/HabilidadVortice.tscn") as PackedScene
	_habilidad = escena.instantiate()
	_habilidad.slot_index = 0
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador
	_habilidad.desplazamiento_maximo = 100.0
	_habilidad.radio_vortice = 90.0
	_habilidad.duracion_vortice = 3.5
	_habilidad.fuerza_atraccion = 300.0
	_habilidad.intervalo_atraccion = 0.3
	_habilidad.costo_energia = 0.0


func _informar() -> bool:
	var exito := _cae_en_el_punto_de_apuntado and _atrae_hacia_el_centro_a and _atrae_hacia_el_centro_b \
		and _sin_dano_a_los_enemigos and _aliado_sin_atraccion_ni_dano and _mob_lejos_sin_atraccion \
		and _sigue_atrayendo_pasado_un_solo_tiron and _se_libera_al_vencer_la_duracion
	print("PRUEBA VORTICE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
