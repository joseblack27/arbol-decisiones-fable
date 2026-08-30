# =============================================================================
# Regresión: Cepo ahora tiene sprite real (Bear_Trap.png) — "puesto"
# mientras espera, "pisado" (mordida) al activarse. Verifica que el
# AnimatedSprite2D real cambia de animación en el momento justo, no solo
# que el daño/inmovilización funcionen (ya cubierto por prueba_cepo.gd).
#
# Dos fases: primero el enemigo queda LEJOS del cepo unos fotogramas (para
# confirmar "puesto" de verdad, sin que se dispare al toque), después se lo
# teletransporta encima para confirmar que pasa a "pisado".
#   godot --headless --path . --script res://pruebas/prueba_cepo_sprite.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jugador
var _enemigo
var _habilidad_cepo
var _cepo_colocado
var _ok := true
var _vio_animacion_puesto := false
var _vio_animacion_pisado := false
var _ya_acerco_enemigo := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		_habilidad_cepo.activar(Vector2.RIGHT, 1.0)
	if _cepo_colocado == null:
		_cepo_colocado = _encontrar_cepo()
	if _cepo_colocado:
		var sprite: AnimatedSprite2D = _cepo_colocado.get_node("AnimatedSprite2D")
		if sprite.animation == &"puesto":
			_vio_animacion_puesto = true
		elif sprite.animation == &"pisado":
			_vio_animacion_pisado = true
		# Recién después de confirmar "puesto" de verdad se acerca al
		# enemigo — si no, el cuerpo podría estar ya encima desde el
		# primer fotograma y nunca se vería la espera.
		if _vio_animacion_puesto and not _ya_acerco_enemigo:
			_ya_acerco_enemigo = true
			_enemigo.global_position = _cepo_colocado.global_position
	if _fotogramas == 60:
		return _informar()
	return false


## Cepo se obtiene de GestorPiscinas, que lo cuelga de su propio contenedor
## "InstanciasPiscina" (autoload, NO de current_scene — ver GestorPiscinas.
## _contenedor, para sobrevivir a un cambio de nivel a mitad de vuelo).
func _encontrar_cepo() -> Node:
	# Por ruta absoluta, no por el identificador bare del autoload: en modo
	# --script un identificador de autoload suelto puede fallar a resolver
	# en la compilación de un proceso recién arrancado (mismo criterio que
	# el resto de las pruebas de este proyecto).
	var gestor := root.get_node_or_null("GestorPiscinas")
	if gestor == null:
		return null
	var contenedor := gestor.get_node_or_null("InstanciasPiscina")
	if contenedor == null:
		return null
	for hijo in contenedor.get_children():
		if hijo.get_script() == load("res://escenas/habilidades/cepo/Cepo.gd"):
			return hijo
	return null


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena_jugador.instantiate()
	_jugador.name = "1"
	raiz.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO

	var escena_enemigo := load("res://escenas/enemigos/EnemigoLobo.tscn")
	_enemigo = escena_enemigo.instantiate()
	raiz.add_child(_enemigo)
	_enemigo.global_position = Vector2(400, 400)  # bien lejos del cepo
	var vida_enemigo = _enemigo.get_node("VidaComponente")
	vida_enemigo.salud_maxima = 100000.0
	vida_enemigo.salud_actual = 100000.0
	vida_enemigo.cancelar_invulnerabilidad()

	var escena_habilidad = load("res://recursos/habilidades/cepo.tres")
	_habilidad_cepo = escena_habilidad.escena.instantiate()
	_habilidad_cepo.entidad_dueña = _jugador
	_habilidad_cepo.aplicar_datos(escena_habilidad)
	_jugador.add_child(_habilidad_cepo)
	_habilidad_cepo.alcance_maximo = 20.0


func _informar() -> bool:
	print("Se vio la animación 'puesto' antes de activarse (esperado true): %s" % _vio_animacion_puesto)
	print("Se vio la animación 'pisado' al activarse (esperado true): %s" % _vio_animacion_pisado)
	_ok = _ok and _vio_animacion_puesto and _vio_animacion_pisado
	print("PRUEBA CEPO SPRITE %s" % ("OK" if _ok else "FALLIDA"))
	quit(0 if _ok else 1)
	return true
