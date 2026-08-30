# =============================================================================
# Prueba de GolpeVerdaderoGuardian/HabilidadGolpeVerdaderoGuardian — el
# golpe único no-área que el Guardián Quebrado usa para el amague de fase 1,
# el castigo por cooldown de fase 3 y las transiciones de fase. La propiedad
# que importa de verdad: a diferencia de Combate.golpear_area(), este golpe
# NO debe ser bloqueado por un ParryComponente activo (HabilidadCorte del
# jugador), aunque esté mirando de frente al golpe.
#
# OJO: igual que GolpeBasico, el daño se aplica en _aplicar_daño() vía
# call_deferred (ver configurar()) — hay que esperar UN fotograma extra
# después de cada _ejecutar() antes de leer el resultado, no alcanza con
# consultarlo en el mismo fotograma.
#   godot --headless --path . --script res://pruebas/prueba_guardian_golpe_verdadero.gd
# =============================================================================
extends SceneTree

const _RUTA_HABILIDAD := "res://escenas/habilidades/golpe_verdadero_guardian/HabilidadGolpeVerdaderoGuardian.gd"

var _fotogramas := 0
var _jefe: CharacterBody2D
var _golpe
var _jugador: CharacterBody2D
var _vida_jugador: VidaComponente
var _otro_enemigo: CharacterBody2D
var _vida_otro: VidaComponente
var _antes := 0.0

var _dana_al_jugador_ok := false
var _parry_no_lo_bloquea_ok := false
var _no_dana_a_otro_enemigo_ok := false
var _ignora_defensa_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_antes = _vida_jugador.salud_actual
			_golpe._ejecutar(Vector2.RIGHT, 1.0)
		6:
			_dana_al_jugador_ok = _vida_jugador.salud_actual < _antes
			print("Golpe verdadero daña al jugador (esperado que baje de %.1f): %.1f" % [
				_antes, _vida_jugador.salud_actual])
			_activar_parry()
			_antes = _vida_jugador.salud_actual
			_golpe._ejecutar(Vector2.RIGHT, 1.0)
		7:
			_parry_no_lo_bloquea_ok = _vida_jugador.salud_actual < _antes
			print("Parry activo NO bloquea el golpe verdadero (esperado que baje de %.1f): %.1f" % [
				_antes, _vida_jugador.salud_actual])
			_antes = _vida_otro.salud_actual
			_golpe._ejecutar(Vector2.LEFT, 1.0)
		8:
			_no_dana_a_otro_enemigo_ok = _vida_otro.salud_actual == _antes
			print("No daña a otro enemigo (mismo equipo) (esperado sin cambio): %.1f -> %.1f" % [
				_antes, _vida_otro.salud_actual])
			_golpe.ignora_defensa = true
			_golpe.daño = 30.0
			_antes = _vida_jugador.salud_actual
			_golpe._ejecutar(Vector2.RIGHT, 1.0)
		9:
			var perdida := _antes - _vida_jugador.salud_actual
			# Con 25 defensa + 40 resistencia física, sin ignorar defensa un
			# golpe de 30 quedaría muy por debajo de 30 — con
			# ignora_defensa=true debería pasar prácticamente entero.
			_ignora_defensa_ok = perdida >= 25.0
			print("ignora_defensa=true pasa el daño casi entero (esperado >= 25.0): %.1f" % perdida)
			return _informar()
	return false


func _crear_entidad(pos: Vector2, grupo: String, con_defensa: bool) -> CharacterBody2D:
	var e := CharacterBody2D.new()
	e.add_to_group(grupo)
	e.collision_layer = 2
	root.add_child(e)
	e.global_position = pos

	var vida = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	vida.name = "VidaComponente"
	vida.salud_maxima = 500.0
	e.add_child(vida)
	vida.salud_actual = 500.0
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 12.0
	forma.shape = circ
	vida.add_child(forma)

	if con_defensa:
		var atrib = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
		atrib.name = "AtributosComponente"
		var base = (load("res://recursos/AtributosBase.gd") as GDScript).new()
		base.defensa = 25.0
		base.fortaleza = 40.0
		base.resistencia_fisica = 40.0
		atrib.base = base
		e.add_child(atrib)
	return e


func _activar_parry() -> void:
	var parry = (load("res://componentes/ParryComponente.gd") as GDScript).new()
	parry.name = "ParryComponente"
	_jugador.add_child(parry)
	# Guardia hacia la IZQUIERDA (de cara al jefe, que está a la izquierda
	# del jugador) — la orientación más favorable posible para que el parry
	# lo bloquee, si es que fuera a hacerlo.
	parry.activar(5.0, Vector2.LEFT)


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	_jefe = _crear_entidad(Vector2.ZERO, "enemigos", false)
	_jugador = _crear_entidad(Vector2(60, 0), "jugadores", true)
	_vida_jugador = _jugador.get_node("VidaComponente") as VidaComponente
	_otro_enemigo = _crear_entidad(Vector2(-60, 0), "enemigos", false)
	_vida_otro = _otro_enemigo.get_node("VidaComponente") as VidaComponente

	_golpe = (load(_RUTA_HABILIDAD) as GDScript).new()
	_golpe.entidad_dueña = _jefe
	_golpe.alcance_golpe = 60.0
	_golpe.radio_golpe = 56.0
	_golpe.ignora_defensa = false
	_jefe.add_child(_golpe)


func _informar() -> bool:
	var exito := _dana_al_jugador_ok and _parry_no_lo_bloquea_ok \
		and _no_dana_a_otro_enemigo_ok and _ignora_defensa_ok
	print("  daña al jugador: %s" % _dana_al_jugador_ok)
	print("  parry no lo bloquea: %s" % _parry_no_lo_bloquea_ok)
	print("  no daña a otro enemigo: %s" % _no_dana_a_otro_enemigo_ok)
	print("  ignora_defensa funciona: %s" % _ignora_defensa_ok)
	print("PRUEBA GUARDIAN GOLPE VERDADERO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
