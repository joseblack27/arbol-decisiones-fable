# =============================================================================
# Prueba del Esqueleto Arquero: a diferencia de Lobo/Caballero (cuerpo a
# cuerpo), su única habilidad es un disparo de flecha a distancia
# (rango_maximo=380 en FlechaArquero.tres, ver AccionAtacar.
# usar_rango_de_habilidades). Verifica que:
#   1. Se acerca al jugador cuando está fuera de rango de disparo.
#   2. Se DETIENE al llegar a rango de disparo — nunca cierra hasta
#      distancia de melee (a diferencia de un mob cuerpo a cuerpo).
#   3. Dispara y hace daño de verdad al jugador, sin acercarse más.
#   godot --headless --path . --script res://pruebas/prueba_esqueleto_arquero_mantiene_distancia.gd
# =============================================================================
extends SceneTree

var _mob
var _jugador
var _fotogramas := 0
var _distancia_inicial := 0.0
var _vida_inicial := 0.0

## Arranca a 450px: fuera del rango de disparo (380) pero dentro del
## distancia_abandono de AccionPerseguir (500), para que persiga en línea
## recta (sin malla de navegación en esta prueba aislada) en vez de
## rendirse de entrada.
const _DISTANCIA_INICIAL := 450.0
const _RANGO_DISPARO := 380.0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_distancia_inicial = _mob.global_position.distance_to(_jugador.global_position)
			_vida_inicial = _jugador.componente_vida.obtener_vida()
		# ~14s de combate (840 fotogramas a 60fps): tiempo de sobra para
		# acercarse a rango y disparar varias veces. HabilidadFlechaArquero
		# ya no dispara instantáneo (ver esa clase): aim (0.25s) + pose
		# quieto antes del disparo (duracion_pose_ataque=1.2s) + vuelo de la
		# flecha + recuperación COMPLETA recién arrancada después de la pose
		# (AccionAtacar reinicia _fin_recuperacion al soltar "ataque_en_
		# curso" — ver el comentario de esa clase) suman bastante más que
		# los 2s de cooldown de antes por ciclo; 6s alcanzaba a duras penas
		# para UN solo impacto y la prueba salía intermitente según cuánto
		# tardara cada fotograma en tiempo real bajo --headless.
		840:
			return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO

	_mob = (load("res://escenas/enemigos/EnemigoEsqueletoArquero.tscn") as PackedScene).instantiate()
	root.add_child(_mob)
	_mob.global_position = Vector2(_DISTANCIA_INICIAL, 0)
	_mob.memoria.establecer("objetivo", _jugador)
	_mob.memoria.establecer("jugador_detectado", true)


func _informar() -> bool:
	var distancia_final: float = _mob.global_position.distance_to(_jugador.global_position)
	var vida_final: float = _jugador.componente_vida.obtener_vida()

	var se_acerco: bool = distancia_final < _distancia_inicial
	# Margen sobre el rango de disparo: nunca debería acercarse de más una
	# vez dentro de rango (ver AccionAtacar._on_ejecutar: "en rango" siempre
	# devuelve EXITOSO, sin volver a pedir acercarse).
	var no_llego_a_melee: bool = distancia_final > _RANGO_DISPARO * 0.5
	var hizo_dano: bool = vida_final < _vida_inicial

	print("Distancia inicial->final (se acercó, sin llegar a melee): %.0f -> %.0f" % [
		_distancia_inicial, distancia_final
	])
	print("Vida jugador inicial->final (disparó e hizo daño a distancia): %.1f -> %.1f" % [
		_vida_inicial, vida_final
	])

	var exito := se_acerco and no_llego_a_melee and hizo_dano
	print("PRUEBA ESQUELETO ARQUERO MANTIENE DISTANCIA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
