# =============================================================================
# Regresión: pedido del usuario — "que los bots pudieran usar más
# habilidades y que no se ubicaran justo encima del mob... sino que se
# mantengan como a 40px".
#
# Con un Muñeco de Entrenamiento QUIETO (no persigue de vuelta, así se
# puede medir la distancia de combate sin el ruido de la persecución
# mutua) y DOS habilidades equipadas (golpe_basico en el slot 0, veneno en
# el slot 1), verifica:
#   1. Una vez estabilizado el combate, la distancia real se mantiene
#      dentro de distancia_combate ± tolerancia_distancia_combate (40±10),
#      nunca pegado encima del mob.
#   2. Con el tiempo, usa AMBAS habilidades (no solo la del slot 0) — se
#      detecta por tipo_habilidad distinto en BusEventos.habilidad_usada.
#   godot --headless --path . --script res://pruebas/prueba_bot_ia_distancia_y_habilidades.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _raiz: Node2D
var _jugador
var _muneco
var _tipos_vistos := {}
var _distancias_en_combate: Array[float] = []


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
	# A partir de ~3s (ya debería estar en rango de combate) muestrea la
	# distancia real cada 10 fotogramas, durante el resto de la corrida.
	if _fotogramas >= 180 and _fotogramas % 10 == 0:
		_distancias_en_combate.append(_jugador.global_position.distance_to(_muneco.global_position))
	if _fotogramas == 900:  # ~15s: de sobra para varios ciclos de ataque (1.1s cada uno).
		return _informar()
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
	var datos_veneno := load("res://recursos/habilidades/veneno.tres")
	_jugador.slot_habilidades.equipar(0, datos_golpe_basico)
	_jugador.slot_habilidades.equipar(1, datos_veneno)

	_muneco = (load("res://escenas/enemigos/MunecoEntrenamiento.tscn") as PackedScene).instantiate()
	_raiz.add_child(_muneco)
	_muneco.global_position = Vector2(200, 0)  # bien lejos, para ver que se acerca de verdad.

	var bus = root.get_node("/root/BusEventos")
	bus.habilidad_usada.connect(_on_habilidad_usada)


func _on_habilidad_usada(entidad: Node, tipo_habilidad: String) -> void:
	if entidad == _jugador:
		_tipos_vistos[tipo_habilidad] = true


func _informar() -> bool:
	var distancia_min := INF
	var distancia_max := -INF
	for d in _distancias_en_combate:
		distancia_min = minf(distancia_min, d)
		distancia_max = maxf(distancia_max, d)

	var min_esperado := 30.0  # distancia_combate(40) - tolerancia(10)
	var max_esperado := 50.0  # distancia_combate(40) + tolerancia(10)
	var distancia_ok: bool = _distancias_en_combate.size() > 0 \
		and distancia_min >= min_esperado - 2.0 and distancia_max <= max_esperado + 2.0
	var uso_ambas_ok: bool = _tipos_vistos.size() >= 2

	print("Distancia de combate observada: min=%.1f max=%.1f (esperado dentro de [%.0f, %.0f]): %s" % [
		distancia_min, distancia_max, min_esperado, max_esperado, distancia_ok])
	print("Tipos de habilidad distintos usados (esperado >= 2): %d %s" % [
		_tipos_vistos.size(), _tipos_vistos.keys()])

	var exito := distancia_ok and uso_ambas_ok
	print("PRUEBA BOT IA DISTANCIA Y HABILIDADES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
