# =============================================================================
# Prueba: al subir de nivel, vida y energía quedan al 100% (no solo +10/+5
# de siempre) — pedido del usuario tras notar que quedaban a medias si ya
# estaban dañadas/gastadas antes de subir.
#   godot --headless --path . --script res://pruebas/prueba_curacion_al_subir_nivel.gd
# =============================================================================
# Sin tipos estáticos hacia clases del juego (VidaComponente, EnergiaComponente,
# ExperienciaComponente...): en modo --script se compilan ANTES de que
# existan los autoloads que usan (Utils, BusEventos) y revienta la
# compilación — mismo motivo por el que las demás pruebas usan load() en
# runtime y variables sin tipar.
extends SceneTree

var _fotogramas := 0
var _jugador: CharacterBody2D
var _vida
var _energia
var _experiencia


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			# Dañar y gastar energía ANTES de subir de nivel — el punto es
			# comprobar que sube de golpe al 100%, no que "ya estaba llena".
			_vida.quitar_vida(80.0)
			_energia.consumir(90.0)
		5:
			print("Vida antes de subir de nivel (esperado 20 de 100): %.0f / %.0f" \
				% [_vida.obtener_vida(), _vida.obtener_vida_maxima()])
			print("Energía antes de subir de nivel (esperado 10 de 100): %.0f / %.0f" \
				% [_energia.obtener_energia(), _energia.obtener_energia_maxima()])
			# TablaNiveles: 100 XP para pasar del nivel 1 al 2.
			_experiencia.agregar_xp(100)
		6:
			return _informar()
	return false


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	_vida = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	_vida.name = "VidaComponente"
	_vida.salud_maxima = 100.0
	_vida.intervalo_regeneracion = 0.0  # sin regen de fondo que ensucie la prueba
	_jugador.add_child(_vida)

	_energia = (load("res://componentes/EnergiaComponente.gd") as GDScript).new()
	_energia.name = "EnergiaComponente"
	_energia.energia_maxima = 100.0
	_jugador.add_child(_energia)

	_experiencia = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	_experiencia.name = "ExperienciaComponente"
	_jugador.add_child(_experiencia)


func _informar() -> bool:
	var vida_actual: float = _vida.obtener_vida()
	var vida_maxima: float = _vida.obtener_vida_maxima()
	var energia_actual: float = _energia.obtener_energia()
	var energia_maxima: float = _energia.obtener_energia_maxima()
	print("Nivel tras subir (esperado 2): %d" % _experiencia.nivel)
	print("Vida tras subir de nivel (esperado == máxima, 110): %.0f / %.0f" % [vida_actual, vida_maxima])
	print("Energía tras subir de nivel (esperado == máxima, 105): %.0f / %.0f" % [energia_actual, energia_maxima])
	var exito: bool = _experiencia.nivel == 2 \
		and is_equal_approx(vida_maxima, 110.0) and is_equal_approx(vida_actual, vida_maxima) \
		and is_equal_approx(energia_maxima, 105.0) and is_equal_approx(energia_actual, energia_maxima)
	print("PRUEBA CURACION AL SUBIR NIVEL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
