# =============================================================================
# Prueba de HabilidadOndaChoque: AoE centrada en quien la usa que daña Y
# empuja lejos a los enemigos alcanzados.
#
# Verifica:
#   1. Los enemigos dentro del radio reciben daño.
#   2. Los enemigos dentro del radio quedan con velocidad de empuje
#      apuntando lejos del centro (MovimientoComponente.aplicar_empuje).
#   3. Un aliado (mismo equipo que quien la usa) ni recibe daño ni empuje —
#      sin fuego amigo, mismo criterio que Combate.mismo_equipo en todos
#      lados.
#   godot --headless --path . --script res://pruebas/prueba_onda_choque.gd
# =============================================================================
extends SceneTree

var _jugador
var _habilidad
var _mob_derecha
var _mob_abajo
var _aliado
var _fotogramas := 0
## Ver el mismo comentario en prueba_vortice.gd: la consulta de daño ahora
## corre en _physics_process, así que hay que esperar a que AVANCE un
## fotograma físico real, no solo contar fotogramas idle de este script.
var _fisica_en_activacion := -1

var _dano_a_enemigos := false
var _empuje_apunta_lejos_derecha := false
var _empuje_apunta_lejos_abajo := false
var _aliado_sin_dano_ni_empuje := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	if _fotogramas == 2:
		_habilidad._ejecutar(Vector2.ZERO, 1.0)
		_fisica_en_activacion = Engine.get_physics_frames()
		return false
	if _fotogramas > 2 and Engine.get_physics_frames() == _fisica_en_activacion:
		return false  # todavía no corrió ningún _physics_process nuevo.

	_dano_a_enemigos = _mob_derecha.golpes == 1 and _mob_abajo.golpes == 1
	print("Daña a los enemigos en el radio (esperado true): %s" % _dano_a_enemigos)

	var mov_derecha = _mob_derecha.get_node("MovimientoComponente")
	var mov_abajo = _mob_abajo.get_node("MovimientoComponente")
	# El mob a la derecha (positivo en X) debe empujarse hacia +X;
	# el de abajo (positivo en Y) hacia +Y.
	_empuje_apunta_lejos_derecha = mov_derecha._empuje_restante > 0.0 and mov_derecha._empuje_velocidad.x > 0.0
	_empuje_apunta_lejos_abajo = mov_abajo._empuje_restante > 0.0 and mov_abajo._empuje_velocidad.y > 0.0
	print("Empuje del mob a la derecha apunta lejos (+X) (esperado true, vel=%s): %s" % [
		mov_derecha._empuje_velocidad, _empuje_apunta_lejos_derecha])
	print("Empuje del mob de abajo apunta lejos (+Y) (esperado true, vel=%s): %s" % [
		mov_abajo._empuje_velocidad, _empuje_apunta_lejos_abajo])

	var mov_aliado = _aliado.get_node("MovimientoComponente")
	_aliado_sin_dano_ni_empuje = _aliado.golpes == 0 and mov_aliado._empuje_restante <= 0.0
	print("El aliado no recibe daño ni empuje (esperado true): %s" % _aliado_sin_dano_ni_empuje)
	return _informar()


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
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	_jugador.global_position = Vector2.ZERO
	root.add_child(_jugador)
	current_scene = _jugador

	_mob_derecha = _crear_objetivo(Vector2(50, 0), "enemigos")
	_mob_abajo   = _crear_objetivo(Vector2(0, 50), "enemigos")
	_aliado      = _crear_objetivo(Vector2(20, 0), "jugadores")

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var escena := load("res://escenas/habilidades/onda_choque/HabilidadOndaChoque.tscn") as PackedScene
	_habilidad = escena.instantiate()
	_habilidad.slot_index = 0
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador
	_habilidad.daño_onda = 10.0
	_habilidad.radio_onda = 90.0
	_habilidad.fuerza_empuje = 400.0
	_habilidad.costo_energia = 0.0


func _informar() -> bool:
	var exito := _dano_a_enemigos and _empuje_apunta_lejos_derecha \
		and _empuje_apunta_lejos_abajo and _aliado_sin_dano_ni_empuje
	print("PRUEBA ONDA CHOQUE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
