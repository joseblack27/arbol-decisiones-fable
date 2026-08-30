# =============================================================================
# Regresión: BotIA.tipos_objetivo — pedido del usuario: "si quiero que
# busque mobs específicos, cómo se hace" (a raíz de un bot que se quedó
# peleando con el Muñeco de Entrenamiento mientras una Araña lo atacaba).
#
# Con un Muñeco de Entrenamiento MÁS CERCA y un Lobo más lejos, pero
# tipos_objetivo=["Lobo"]: el bot tiene que ignorar al muñeco (no coincide)
# y enganchar al Lobo, aunque esté más lejos — confirma que el filtro
# realmente excluye tipos no pedidos en vez de solo preferirlos.
#   godot --headless --path . --script res://pruebas/prueba_bot_ia_filtro_tipo.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _raiz: Node2D
var _jugador
var _muneco
var _lobo

var _engancho_lobo_ok := false
var _nunca_engancho_muneco_ok := true


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		180:
			return _informar()
	if _fotogramas >= 2:
		var bot = _jugador.get_node_or_null("BotIA")
		if bot and bot._objetivo == _muneco:
			_nunca_engancho_muneco_ok = false
	return false


func _montar() -> void:
	root.get_node("/root/Utils").modo_bot = true

	_raiz = Node2D.new()
	root.add_child(_raiz)
	current_scene = _raiz

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena_jugador.instantiate()
	_jugador.name = "1"
	_raiz.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO
	var datos_golpe_basico := load("res://recursos/habilidades/golpe_basico.tres")
	_jugador.slot_habilidades.equipar(0, datos_golpe_basico)

	var bot = _jugador.get_node("BotIA")
	var tipos: Array[String] = ["Lobo"]
	bot.tipos_objetivo = tipos

	# Muñeco bien cerca (el más cercano si no hubiera filtro)...
	_muneco = (load("res://escenas/enemigos/MunecoEntrenamiento.tscn") as PackedScene).instantiate()
	_raiz.add_child(_muneco)
	_muneco.global_position = Vector2(60, 0)

	# ...Lobo más lejos, pero es el único tipo que el filtro permite.
	_lobo = load("res://escenas/enemigos/EnemigoLobo.tscn").instantiate()
	_raiz.add_child(_lobo)
	_lobo.global_position = Vector2(150, 0)
	var vida_lobo = _lobo.get_node("VidaComponente")
	vida_lobo.salud_maxima = 100000.0
	vida_lobo.salud_actual = 100000.0
	vida_lobo.cancelar_invulnerabilidad()


func _informar() -> bool:
	var bot = _jugador.get_node("BotIA")
	_engancho_lobo_ok = bot._objetivo == _lobo
	print("El bot ignora al muñeco más cercano en todo momento (esperado true): %s" % _nunca_engancho_muneco_ok)
	print("El bot engancha al Lobo, el único tipo permitido (esperado true): %s" % _engancho_lobo_ok)
	var exito := _engancho_lobo_ok and _nunca_engancho_muneco_ok
	print("PRUEBA BOT IA FILTRO TIPO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
