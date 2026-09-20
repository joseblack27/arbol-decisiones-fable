# =============================================================================
# Regresión (bug reportado 19 sep 2026, probado en celular real): "las
# hormigas despues del llamado, no responde a un segundo llamado y tambien
# las que quedaron vivas y vuelven a su puesto, dejan de detectar al
# jugador". Causa real: AccionIrAPunto.gd (usada por "Llamada de Auxilio"
# de la Reina, ver ese script) comparaba una DISTANCIA CRUDA contra
# margen_llegada en vez de usar MovimientoComponente.llego_al_destino()
# (que sí usan AccionDeambular y compañía). Si el punto exacto de la
# llamada quedaba en un tramo bloqueado por la topología de túneles del
# Hormiguero, esa distancia cruda nunca se cumplía y "en_llamada_auxilio"
# quedaba en true PARA SIEMPRE -- como ResponderLlamada es la rama de MÁS
# prioridad del árbol de cada hormiga, la hormiga quedaba bloqueada de
# Atacar/Perseguir/Deambular indefinidamente: se veía como "dejó de
# detectar al jugador" y "un segundo llamado no hace nada" (seguía
# atendiendo el primero, nunca se soltaba).
#
# Prueba: fuerza a una hormiga a quedar "atascada" respondiendo a la
# llamada (más de _TIEMPO_MAXIMO_INTENTANDO_LLEGAR sin llegar ni terminar
# la navegación -- ver MovimientoComponente.gd) y confirma que
# llego_al_destino() la libera igual, sin depender de llegar de verdad.
#   godot --headless --path . --script res://pruebas/prueba_llamada_auxilio_hormiga_atascada.gd
# =============================================================================
extends SceneTree

var _f := 0
var _hormiga
var _memoria
var _movimiento

var _sigue_atendiendo_antes_del_atasco_ok := false
var _se_libera_tras_atascarse_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		30:  # Margen de sobra para que el árbol (10Hz, ver intervalo_tick) ya haya tickeado al menos una vez.
			_verificar_sigue_atendiendo()
			_forzar_atasco()
		60:  # Otro margen de sobra para un tick más, ya con el atasco forzado.
			return _informar()
	return false


func _montar() -> void:
	var nivel := (load("res://escenas/niveles/NivelHormiguero.tscn") as PackedScene).instantiate()
	root.add_child(nivel)
	current_scene = nivel
	var enemigos := nivel.get_node("Enemigos")

	_hormiga = (load("res://escenas/enemigos/EnemigoHormigaObrera.tscn") as PackedScene).instantiate()
	enemigos.add_child(_hormiga)
	_hormiga.global_position = nivel.get_node("PuntoAparicion").global_position

	_memoria = _hormiga.get_node("ArbolComportamiento/MemoriaBT")
	_movimiento = _hormiga.get_node("MovimientoComponente")

	# Mismo mecanismo que activa HabilidadLlamadaAuxilio -- un destino bien
	# lejos (varias salas), imposible de alcanzar en unos pocos fotogramas.
	_memoria.establecer("en_llamada_auxilio", true)
	_memoria.establecer("destino_llamada", _hormiga.global_position + Vector2(5000, 5000))


func _verificar_sigue_atendiendo() -> void:
	# A los pocos fotogramas, ni llegó ni pasaron los 6s del timeout --
	# tiene que seguir respondiendo la llamada (comportamiento normal, no
	# el bug).
	_sigue_atendiendo_antes_del_atasco_ok = _memoria.obtener("en_llamada_auxilio", false)
	print("A los pocos fotogramas sigue respondiendo la llamada, normal (esperado true): %s" % \
		_sigue_atendiendo_antes_del_atasco_ok)


## Salta directo a "llevamos más de 6s atascados" sin tener que simular
## esos 6 segundos reales de fotogramas -- mismo campo que consulta
## MovimientoComponente.llego_al_destino() (ver ese script).
func _forzar_atasco() -> void:
	_movimiento._tiempo_en_destino_actual = 999.0


func _informar() -> bool:
	_se_libera_tras_atascarse_ok = not _memoria.obtener("en_llamada_auxilio", true)
	print("Tras atascarse más de 6s, en_llamada_auxilio se apaga sola (esperado true): %s" % \
		_se_libera_tras_atascarse_ok)

	var exito := _sigue_atendiendo_antes_del_atasco_ok and _se_libera_tras_atascarse_ok
	print("PRUEBA LLAMADA AUXILIO HORMIGA ATASCADA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
