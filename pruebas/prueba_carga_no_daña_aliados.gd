# =============================================================================
# Prueba: HabilidadCarga (dash de mobs) NO debe dañar a otro mob que se
# cruce en el corredor del embiste ("los enemigos se golpean entre ellos"
# reportado en juego real, tras quitarles la colisión física entre ellos —
# ver Enemigo.gd) — pero SÍ debe seguir dañando a un jugador que se cruce.
#   godot --headless --path . --script res://pruebas/prueba_carga_no_daña_aliados.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _atacante: CharacterBody2D
var _mob_aliado: CharacterBody2D
var _jugador: CharacterBody2D
var _vida_aliado: VidaComponente
var _vida_jugador: VidaComponente
var _habilidad: Node
var _movimiento: Node


## HabilidadCarga solo considera un objetivo válido si expone quitar_vida()
## en el propio cuerpo (mismo criterio que Enemigo.gd/Jugador.gd reales,
## que reenvían a su VidaComponente) — un CharacterBody2D pelado no alcanza.
static func _script_quitar_vida() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
func quitar_vida(cantidad: float, fuente: Node = null, _tipo: int = 2, _critico: bool = false) -> void:
	var vida := get_node_or_null("VidaComponente")
	if vida:
		vida.quitar_vida(cantidad, fuente)
"""
	guion.reload()
	return guion


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_habilidad.call("activar", Vector2.RIGHT, 1.0)
		30:
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_atacante = CharacterBody2D.new()
	_atacante.add_to_group("enemigos")
	# Capa 2, igual que Enemigo.gd real: los mobs ya NO colisionan
	# físicamente entre sí (ver enemigo.tscn) — sin esto, el dash se
	# frenaría contra el cuerpo del aliado antes de llegar al jugador,
	# dando un falso negativo que no refleja el juego real.
	_atacante.collision_layer = 2
	_atacante.collision_mask  = 1
	escena.add_child(_atacante)
	var forma_atacante := CollisionShape2D.new()
	var circ_atacante := CircleShape2D.new()
	circ_atacante.radius = 10.0
	forma_atacante.shape = circ_atacante
	_atacante.add_child(forma_atacante)

	_movimiento = (load("res://componentes/MovimientoComponente.gd") as GDScript).new()
	_movimiento.name = "MovimientoComponente"
	_movimiento.jugador = _atacante
	_movimiento.velocidad_base = 100.0
	_atacante.add_child(_movimiento)

	# Otro mob (mismo equipo) parado justo en el camino del dash.
	_mob_aliado = CharacterBody2D.new()
	_mob_aliado.set_script(_script_quitar_vida())
	_mob_aliado.add_to_group("enemigos")
	_mob_aliado.collision_layer = 2
	_mob_aliado.collision_mask  = 1
	_mob_aliado.global_position = Vector2(40, 0)
	escena.add_child(_mob_aliado)
	var forma_aliado := CollisionShape2D.new()
	var circ_aliado := CircleShape2D.new()
	circ_aliado.radius = 12.0
	forma_aliado.shape = circ_aliado
	_mob_aliado.add_child(forma_aliado)
	_vida_aliado = VidaComponente.new()
	_vida_aliado.name = "VidaComponente"
	_vida_aliado.salud_maxima = 100.0
	_mob_aliado.add_child(_vida_aliado)
	_vida_aliado.restaurar_vida(100.0)

	# Un jugador un poco más lejos en la misma línea — SÍ debe recibir daño.
	_jugador = CharacterBody2D.new()
	_jugador.set_script(_script_quitar_vida())
	_jugador.add_to_group("jugadores")
	_jugador.global_position = Vector2(90, 0)
	escena.add_child(_jugador)
	var forma_jugador := CollisionShape2D.new()
	var circ_jugador := CircleShape2D.new()
	circ_jugador.radius = 12.0
	forma_jugador.shape = circ_jugador
	_jugador.add_child(forma_jugador)
	_vida_jugador = VidaComponente.new()
	_vida_jugador.name = "VidaComponente"
	_vida_jugador.salud_maxima = 100.0
	_jugador.add_child(_vida_jugador)
	_vida_jugador.restaurar_vida(100.0)

	var contenedor := Marker2D.new()
	contenedor.name = "Habilidades"
	_atacante.add_child(contenedor)

	var guion := load("res://escenas/habilidades/carga/HabilidadCarga.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.set("componente_movimiento", _movimiento)
	_habilidad.set("duracion_preparacion", 0.0)
	_habilidad.set("multiplicador_velocidad_carga", 6.0)
	_habilidad.set("distancia_maxima_dash", 300.0)
	_habilidad.set("dano_carga", 20.0)
	_habilidad.set("duracion_recarga", 0.0)
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _atacante


func _informar() -> bool:
	var vida_aliado := _vida_aliado.obtener_vida()
	var vida_jugador := _vida_jugador.obtener_vida()
	print("Vida del mob aliado tras el dash (esperado 100, SIN daño): %.0f" % vida_aliado)
	print("Vida del jugador tras el dash (esperado < 100, SÍ con daño): %.0f" % vida_jugador)
	var aliado_ok := is_equal_approx(vida_aliado, 100.0)
	var jugador_ok := vida_jugador < 100.0
	var exito := aliado_ok and jugador_ok
	print("PRUEBA CARGA NO DAÑA ALIADOS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
