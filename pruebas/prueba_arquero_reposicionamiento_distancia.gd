# =============================================================================
# Prueba de AccionAtacarArquero._elegir_destino_reposicionamiento: a
# diferencia de la clase base (AccionAtacar), que orbita a la distancia
# ACTUAL del agente al objetivo, el arquero debe apuntar cerca de su rango
# MÁXIMO de disparo — reportado por el usuario: "cuando se reposicionan
# quedan muy cerca del jugador" (la distancia actual ya venía reducida,
# p. ej. porque el jugador se acercó durante la pose de disparo).
#
# Se llama al método directo (mismo criterio que otras pruebas de este mob:
# es matemática pura, sin nada de red/animación de por medio) con el
# arquero puesto A PROPÓSITO muy cerca del objetivo, para confirmar que el
# destino elegido NO hereda esa cercanía.
#   godot --headless --path . --script res://pruebas/prueba_arquero_reposicionamiento_distancia.gd
# =============================================================================
extends SceneTree

const _RANGO_DISPARO := 380.0
const _MARGEN_ESPERADO := _RANGO_DISPARO * 0.9

func _process(_delta: float) -> bool:
	# Cargar Jugador.tscn PRIMERO (aunque acá solo haga falta como
	# "objetivo" con posición): fuerza a que los autoloads que
	# HabilidadProyectil.gd necesita (GestorPiscinas) ya estén resueltos
	# antes de instanciar la escena del arquero — instanciarla de entrada
	# "en frío" cuelga en silencio (ver memoria del proyecto).
	var jugador := (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(jugador)
	jugador.global_position = Vector2.ZERO

	var mob := (load("res://escenas/enemigos/EnemigoEsqueletoArquero.tscn") as PackedScene).instantiate()
	root.add_child(mob)
	# A propósito MUY cerca (100px, bien por debajo del rango de disparo)
	# — simula haber quedado cerca tras la pose de disparo.
	mob.global_position = Vector2(100, 0)

	var accion := mob.get_node("ArbolComportamiento/Selector/Atacar")
	accion._elegir_destino_reposicionamiento(mob, jugador)
	var destino: Vector2 = accion._destino_reposicionamiento
	var distancia_destino := destino.distance_to(jugador.global_position)

	var ok := distancia_destino > _RANGO_DISPARO * 0.8 and distancia_destino < _RANGO_DISPARO * 1.0
	print("Arquero muy cerca (100px) del jugador -> destino de reposicionamiento a %.1fpx (esperado ~%.1fpx, rango 80-100%% del máximo %.0f): %s" % [
		distancia_destino, _MARGEN_ESPERADO, _RANGO_DISPARO, ok
	])
	print("PRUEBA ARQUERO REPOSICIONAMIENTO DISTANCIA %s" % ("OK" if ok else "FALLIDA"))
	quit(0 if ok else 1)
	return true
