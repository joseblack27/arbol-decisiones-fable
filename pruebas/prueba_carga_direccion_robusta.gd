# =============================================================================
# Prueba: HabilidadCarga._ejecutar() no cae al respaldo Vector2.RIGHT cuando
# recibe una dirección en cero (Vector2.ZERO) pero SÍ hay un objetivo válido
# en memoria — recalcula la dirección directo desde la posición real del
# objetivo en vez de confiar ciegamente en lo que le pasó el llamador.
#
# Reportado por el usuario: "el Caballero Esqueleto embiste mirando a la
# derecha, de vez en cuando" — no se pudo reproducir con un objetivo fijo (la
# dirección se rastrea bien en todos los casos probados), pero el mecanismo
# real (SelectorHabilidades lee agente.direccion_mirada UN INSTANTE antes de
# llamar a esta función) deja una ventana: si "objetivo" cambia justo en el
# medio (posible ahora que varios jugadores pueden competir por el objetivo,
# ver Enemigo._evaluar_objetivo/_priorizar_atacante), la dirección que llega
# acá puede quedar desactualizada o en cero — y antes, cero caía directo a
# Vector2.RIGHT ("mirando a la derecha").
#
# Verifica sobre un Caballero Esqueleto real:
#   1. Con el objetivo bien a la IZQUIERDA y direccion=ZERO al activar, la
#      carga igual apunta a la izquierda (no al respaldo RIGHT).
#   2. Sin objetivo válido en memoria Y direccion=ZERO, ahí sí cae al
#      respaldo RIGHT (comportamiento de última instancia, no debería pasar
#      en juego normal, pero tiene que seguir sin reventar).
#   godot --headless --path . --script res://pruebas/prueba_carga_direccion_robusta.gd
# =============================================================================
extends SceneTree

var _f := 0
var _mob
var _jugador: CharacterBody2D
var _carga

var _apunta_a_la_izquierda_ok := false
var _respaldo_sin_objetivo_ok := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			# Objetivo bien a la izquierda, pero se llama _ejecutar() con
			# direccion=ZERO (simula el caso reportado: el llamador no tenía
			# una dirección fresca a mano). Se llama _ejecutar() directo, sin
			# pasar por activar()/cooldown — acá interesa solo la cuenta de
			# la dirección, no el resto del ciclo de vida de la habilidad.
			_mob.memoria.establecer("objetivo", _jugador)
			_carga.call("_ejecutar", Vector2.ZERO, 1.0)
		4:
			var dir: Vector2 = _carga.obtener_direccion_carga()
			print("Dirección de carga con objetivo a la izquierda (esperado x < -0.9): %s" % dir)
			_apunta_a_la_izquierda_ok = dir.x < -0.9

			# Ahora sin objetivo válido: tiene que caer al respaldo sin reventar.
			_mob.memoria.establecer("objetivo", null)
			_carga.call("_ejecutar", Vector2.ZERO, 1.0)
		6:
			var dir2: Vector2 = _carga.obtener_direccion_carga()
			print("Dirección de carga sin objetivo (esperado RIGHT, respaldo de última instancia): %s" % dir2)
			_respaldo_sin_objetivo_ok = dir2 == Vector2.RIGHT
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	escena.add_child(_jugador)
	_jugador.global_position = Vector2(-300, 0)
	_jugador.get_node("VidaComponente").cancelar_invulnerabilidad()

	_mob = (load("res://escenas/enemigos/EnemigoCaballeroEsqueleto.tscn") as PackedScene).instantiate()
	escena.add_child(_mob)
	_mob.global_position = Vector2.ZERO
	# Sin IA: se ejercita HabilidadCarga a mano, sin que el árbol interfiera
	# con la memoria a mitad de la prueba.
	_mob.get_node("ArbolComportamiento").activo = false

	_carga = _mob.get_node("Habilidades/HabilidadCarga")


func _informar() -> bool:
	var exito := _apunta_a_la_izquierda_ok and _respaldo_sin_objetivo_ok
	print("  apunta al objetivo real aunque llegue direccion=ZERO: %s" % _apunta_a_la_izquierda_ok)
	print("  respaldo sin objetivo (última instancia): %s" % _respaldo_sin_objetivo_ok)
	print("PRUEBA CARGA DIRECCION ROBUSTA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
