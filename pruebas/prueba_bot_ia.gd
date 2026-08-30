# =============================================================================
# BotIA: cerebro simple para un Jugador manejado por IA (Utils.modo_bot) —
# pedido del usuario: probar el servidor con varias instancias de Godot
# peleando solas. Verifica, sin red (single player):
#   1. Con Utils.modo_bot=true, Jugador._ready() cuelga un nodo "BotIA".
#   2. Deambulando (sin ningún enemigo cerca), el bot SE MUEVE de verdad
#      (su posición cambia con el tiempo).
#   3. Con un enemigo real dentro del radio de detección, el bot lo
#      persigue y le baja la vida con golpe_basico (slot 0, ya equipado
#      por defecto) sin intervención manual.
#
# Sin tipos estáticos hacia Jugador (no tiene class_name) en el TOP-LEVEL
# del script — mismo criterio que el resto de las pruebas del proyecto.
#   godot --headless --path . --script res://pruebas/prueba_bot_ia.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _raiz: Node2D
var _jugador
var _enemigo
var _pos_inicial := Vector2.ZERO

var _bot_creado_ok := false
var _se_movio_deambulando_ok := false
var _enemigo_perdio_vida_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_bot_creado_ok = _jugador.get_node_or_null("BotIA") != null
			_pos_inicial = _jugador.global_position
		120:
			# ~2s deambulando, sin enemigo todavía en el mapa: confirma que el
			# bot camina solo antes de meter el enemigo (para no mezclar
			# "se movió porque perseguía" con "se movió deambulando").
			_se_movio_deambulando_ok = _jugador.global_position.distance_to(_pos_inicial) > 15.0
			_agregar_enemigo()
		600:
			# ~8s más de sobra para que la visión lo detecte, se acerque
			# (dentro de radio_deteccion=250, tiene que cerrar bastante
			# distancia) y golpe_basico (cooldown 1.0s) conecte varias veces.
			return _informar()
	return false


func _montar() -> void:
	# Por ruta absoluta, no por el identificador bare del autoload: en modo
	# --script puede fallar a resolver en la compilación de un proceso
	# recién arrancado (mismo criterio que el resto de las pruebas).
	root.get_node("/root/Utils").modo_bot = true

	_raiz = Node2D.new()
	root.add_child(_raiz)
	current_scene = _raiz

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena_jugador.instantiate()
	_jugador.name = "1"
	_raiz.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO
	# Un Jugador recién instanciado (sin pasar por Mundo.tscn/GestorGuardado)
	# no trae ningún slot equipado — golpe_basico vive en el catálogo, pero
	# equiparlo de entrada es cosa del flujo real de cuenta nueva/guardado,
	# que esta prueba no reproduce. Se equipa a mano acá, mismo estado que
	# tendría cualquier cuenta real con el kit inicial ya puesto.
	var datos_golpe_basico := load("res://recursos/habilidades/golpe_basico.tres")
	_jugador.slot_habilidades.equipar(0, datos_golpe_basico)


func _agregar_enemigo() -> void:
	var escena_enemigo := load("res://escenas/enemigos/EnemigoLobo.tscn")
	_enemigo = escena_enemigo.instantiate()
	_raiz.add_child(_enemigo)
	# Bien dentro del radio_deteccion del bot (250) pero fuera del alcance
	# de golpe_basico (50) — para que el bot tenga que perseguir de verdad,
	# no solo pegar desde donde ya estaba parado.
	_enemigo.global_position = _jugador.global_position + Vector2(150, 0)
	var vida = _enemigo.get_node("VidaComponente")
	vida.salud_maxima = 100000.0
	vida.salud_actual = 100000.0
	vida.cancelar_invulnerabilidad()


func _informar() -> bool:
	var vida_enemigo = _enemigo.get_node("VidaComponente")
	_enemigo_perdio_vida_ok = vida_enemigo.salud_actual < 100000.0
	print("Utils.modo_bot crea el nodo BotIA (esperado true): %s" % _bot_creado_ok)
	print("El bot se mueve solo deambulando, sin enemigos cerca (esperado true): %s" % _se_movio_deambulando_ok)
	print("El bot persigue y golpea al enemigo real sin intervención manual (esperado que baje de 100000.0): %.1f" % vida_enemigo.salud_actual)

	var exito := _bot_creado_ok and _se_movio_deambulando_ok and _enemigo_perdio_vida_ok
	print("PRUEBA BOT IA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
