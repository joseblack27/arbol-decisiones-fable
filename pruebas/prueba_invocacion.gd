# =============================================================================
# Prueba de HabilidadInvocacion: invoca un aliado temporal (AliadoInvocado)
# que pelea contra los enemigos por un tiempo limitado y se desvanece solo.
#
# Verifica:
#   1. El aliado invocado queda en el grupo "jugadores" (no "enemigos") —
#      mismo equipo que quien lo invocó, sin fuego amigo.
#   2. Ataca solo al enemigo, nunca al dueño ni a otros jugadores.
#   3. Le hace daño real al enemigo con el correr de los ticks.
#   4. Aparece el ícono del buff en el dueño mientras el aliado está activo.
#   5. Al vencer la duración, el aliado desaparece solo (y el buff con él).
#   6. El daño se atribuye al DUEÑO (no al aliado mismo) en BusEventos.
#      daño_aplicado — reportado: "no se ve el daño... quiero números
#      flotantes" — GestorNumerosDano solo pinta el número si fuente u
#      objetivo es Utils.jugador_local(); con el aliado (sin peer_id_dueño)
#      como fuente, el filtro nunca lo reconocía como "mi" golpe.
#   godot --headless --path . --script res://pruebas/prueba_invocacion.gd
# =============================================================================
extends SceneTree

var _jugador
var _mob
var _habilidad
var _aliado
var _fotogramas := 0

var _queda_en_equipo_jugadores := false
var _no_ataca_al_dueño := false
var _le_hace_dano_al_enemigo := false
var _aparece_icono_buff := false
var _descripcion_buff_muestra_dano := false
var _desaparece_al_vencer := false
var _buff_desaparece_con_el := false
var _fuente_del_dano_es_el_dueño := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_habilidad._ejecutar(Vector2.ZERO, 1.0)
		4:
			# add_child.call_deferred() ya corrió — buscar al aliado recién
			# creado (el único OTRO miembro de "jugadores" además de _jugador).
			for j in get_nodes_in_group("jugadores"):
				if j != _jugador:
					_aliado = j
					break
			_queda_en_equipo_jugadores = _aliado != null and _aliado.is_in_group("jugadores") \
				and not _aliado.is_in_group("enemigos")
			print("El aliado queda en el equipo del jugador (esperado true): %s" % _queda_en_equipo_jugadores)

			var buffs = _jugador.get_node_or_null("BuffsComponente")
			_aparece_icono_buff = buffs != null and buffs.esta_activo("invocacion")
			print("Aparece el ícono de invocación en el dueño (esperado true): %s" % _aparece_icono_buff)

			# Reportado por el usuario: "sigo sin ver el daño... que al menos
			# el invocador pudiera ver el daño de la invocación" — el texto
			# del BUFF ACTIVO (lo que ve el invocador, no solo la pantalla de
			# equipar) debe incluir el daño real del aliado (dano_ataque=10
			# en esta prueba).
			var buff_invocacion = buffs.obtener("invocacion") if buffs else null
			_descripcion_buff_muestra_dano = buff_invocacion != null and buff_invocacion.descripcion.contains("10")
			print("La descripción del buff activo muestra el daño (esperado true, \"%s\"): %s" % [
				buff_invocacion.descripcion if buff_invocacion else "", _descripcion_buff_muestra_dano])
		40:
			# ~0.6s reales: de sobra para varios ticks de ataque (intervalo=0.2s).
			_le_hace_dano_al_enemigo = _mob.golpes > 0
			_no_ataca_al_dueño = _jugador.golpes == 0
			print("Le hace daño al enemigo (esperado true, golpes=%d): %s" % [_mob.golpes, _le_hace_dano_al_enemigo])
			print("Nunca ataca al dueño (esperado true): %s" % _no_ataca_al_dueño)
			_fuente_del_dano_es_el_dueño = _mob.ultima_fuente == _jugador
			print("quitar_vida() atribuye el golpe al dueño, no al aliado (esperado true): %s" % \
				_fuente_del_dano_es_el_dueño)
		200:
			# duracion_invocacion=2s (120 fotogramas) desde que se invocó (~frame
			# 2), MÁS el fundido de _desvanecer_y_eliminar() (dos tweens de
			# 0.4s cada uno, ~48 fotogramas) antes de que queue_free() lo saque
			# de verdad — con margen de sobra para todo eso.
			_desaparece_al_vencer = not is_instance_valid(_aliado) or not _aliado.is_inside_tree()
			var buffs = _jugador.get_node_or_null("BuffsComponente")
			_buff_desaparece_con_el = buffs == null or not buffs.esta_activo("invocacion")
			print("El aliado desaparece al vencer la duración (esperado true): %s" % _desaparece_al_vencer)
			print("El buff desaparece junto con él (esperado true): %s" % _buff_desaparece_con_el)
			return _informar()
	return false


static func _script_objetivo() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var golpes := 0
var ultima_fuente: Node = null
func quitar_vida(_cantidad: float, _f: Node = null, _t: int = 2, _cr: bool = false) -> void:
	golpes += 1
	ultima_fuente = _f
"""
	guion.reload()
	return guion


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.set_script(_script_objetivo())
	_jugador.add_to_group("jugadores")
	_jugador.global_position = Vector2.ZERO
	root.add_child(_jugador)
	current_scene = _jugador

	_mob = CharacterBody2D.new()
	_mob.set_script(_script_objetivo())
	_mob.add_to_group("enemigos")
	_mob.global_position = Vector2(25, 0)
	root.add_child(_mob)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 8.0
	forma.shape = circ
	_mob.add_child(forma)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var escena := load("res://escenas/habilidades/invocacion/HabilidadInvocacion.tscn") as PackedScene
	_habilidad = escena.instantiate()
	_habilidad.slot_index = 0
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador
	_habilidad.duracion_invocacion = 2.0
	_habilidad.intervalo_ataque = 0.2
	_habilidad.rango_ataque = 40.0
	_habilidad.costo_energia = 0.0


func _informar() -> bool:
	var exito := _queda_en_equipo_jugadores and _no_ataca_al_dueño and _le_hace_dano_al_enemigo \
		and _aparece_icono_buff and _descripcion_buff_muestra_dano and _desaparece_al_vencer \
		and _buff_desaparece_con_el and _fuente_del_dano_es_el_dueño
	print("PRUEBA INVOCACION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
