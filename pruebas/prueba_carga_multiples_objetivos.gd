# =============================================================================
# Prueba del bug reportado: "si llego a golpear a más de un enemigo con el
# dash solo muestra el daño del primer mob" — HabilidadCargaJugador usaba un
# único booleano "_ya_impacto" que cerraba el daño para TODO el resto del
# dash apenas tocaba al primero. Ahora debe golpear a cada enemigo distinto
# que el corredor del dash toque, una sola vez por enemigo.
#   godot --headless --path . --script res://pruebas/prueba_carga_multiples_objetivos.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jugador: CharacterBody2D
var _habilidad: Node
var _raton_1: Node
var _raton_2: Node
var _vida_1_antes := 0.0
var _vida_2_antes := 0.0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_vida_1_antes = _obtener_vida(_raton_1)
			_vida_2_antes = _obtener_vida(_raton_2)
			_habilidad.call("activar", Vector2.RIGHT, 1.0)
		40:
			return _informar()
	return false


func _obtener_vida(entidad: Node) -> float:
	var vida: Node = entidad.get_node("VidaComponente")
	return vida.call("obtener_vida")


func _montar() -> void:
	var contenedor := Node2D.new()
	root.add_child(contenedor)
	current_scene = contenedor

	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	contenedor.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO

	var atributos := AtributosComponente.new()
	atributos.name = "AtributosComponente"
	var base := AtributosBase.new()
	base.danos = 5.0
	atributos.base = base
	_jugador.add_child(atributos)

	var movimiento := MovimientoComponente.new()
	movimiento.name = "MovimientoComponente"
	movimiento.jugador = _jugador
	movimiento.velocidad_base = 400.0
	_jugador.add_child(movimiento)

	_habilidad = (load("res://escenas/habilidades/carga_jugador/HabilidadCargaJugador.tscn") as PackedScene).instantiate()
	_habilidad.set("entidad_dueña", _jugador)
	_habilidad.set("componente_movimiento", movimiento)
	_habilidad.set("daño_carga", 15.0)
	_habilidad.set("distancia_maxima_dash", 120.0)
	_habilidad.set("multiplicador_velocidad_carga", 6.0)
	_habilidad.set("duracion_maxima", 0.5)
	_jugador.add_child(_habilidad)

	# Dos ratones en fila, sobre el corredor del dash (dirección derecha).
	_raton_1 = (load("res://enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	contenedor.add_child(_raton_1)
	_raton_1.global_position = Vector2(30, 0)
	var sin_botin_1: Array[LootDrop] = []
	_raton_1.tabla_botin = sin_botin_1
	_raton_1.xp_otorgada = 0

	_raton_2 = (load("res://enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	contenedor.add_child(_raton_2)
	_raton_2.global_position = Vector2(70, 0)
	var sin_botin_2: Array[LootDrop] = []
	_raton_2.tabla_botin = sin_botin_2
	_raton_2.xp_otorgada = 0


func _informar() -> bool:
	var dano_1 := _vida_1_antes - _obtener_vida(_raton_1)
	var dano_2 := _vida_2_antes - _obtener_vida(_raton_2)
	print("Daño al primer ratón (esperado > 0): %.1f" % dano_1)
	print("Daño al segundo ratón (esperado > 0, antes del fix era 0): %.1f" % dano_2)

	var exito := dano_1 > 0.0 and dano_2 > 0.0
	print("PRUEBA CARGA MULTIPLES OBJETIVOS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
