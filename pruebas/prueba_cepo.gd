# =============================================================================
# Cepo: trampa oculta pedida por el usuario — "que esta inmovilice al
# objetivo 3 segundos y le haga daño por ticks de 0.5s". Mismo patrón que
# Trampa (espera a que un mob pise su radio de detección) pero en vez de
# una explosión única, pega un EfectoCepo (inmoviliza + daño por tick).
#
# Verifica, con un enemigo real:
#   1. Al pisar el radio de detección, queda inmovilizado (MovimientoComponente).
#   2. Recibe daño en cada tick de 0.5s (al menos 5 ticks en 3s reales).
#   3. Tras los 3s, la inmovilización se levanta sola.
#   godot --headless --path . --script res://pruebas/prueba_cepo.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jugador
var _enemigo
var _habilidad_cepo
var _vida_enemigo
var _mov_enemigo
var _ok := true
var _vio_inmovilizado := false
var _ticks_de_dano := 0
var _vida_anterior := 0.0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		_vida_anterior = _vida_enemigo.salud_actual
		_habilidad_cepo.activar(Vector2.RIGHT, 1.0)
	if _fotogramas >= 2 and _fotogramas <= 180:
		if _mov_enemigo._contador_inmovilizacion > 0:
			_vio_inmovilizado = true
		var vida_actual: float = _vida_enemigo.salud_actual
		if vida_actual < _vida_anterior:
			_ticks_de_dano += 1
		_vida_anterior = vida_actual
	if _fotogramas == 200:
		return _informar()
	return false


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
	_enemigo.global_position = Vector2(30, 0)
	_vida_enemigo = _enemigo.get_node("VidaComponente")
	_vida_enemigo.salud_maxima = 100000.0
	_vida_enemigo.salud_actual = 100000.0
	_vida_enemigo.cancelar_invulnerabilidad()
	_mov_enemigo = _enemigo.get_node("MovimientoComponente")

	# Sin tipado estático a HabilidadCepo/DatosHabilidad a propósito: ese
	# "as" fuerza la resolución EAGER de toda la clase en tiempo de
	# compilación del propio script de prueba (arrastra el preload de
	# Cepo.tscn -> Cepo.gd -> GestorPiscinas) antes de que los autoloads
	# estén listos en modo --script — mismo criterio ya documentado en
	# prueba_area_no_daña_aliados.gd: load() + duck typing, nunca tipado
	# estático a clases de juego con cadena hacia autoloads.
	var escena_habilidad = load("res://recursos/habilidades/cepo.tres")
	_habilidad_cepo = escena_habilidad.escena.instantiate()
	_habilidad_cepo.entidad_dueña = _jugador
	_habilidad_cepo.aplicar_datos(escena_habilidad)
	_jugador.add_child(_habilidad_cepo)
	# Alcance chico para esta prueba (el enemigo está a 30px) — el cepo se
	# coloca en la posición del jugador + dirección*alcance*poder, así que
	# con alcance_maximo por defecto (~160px) el cepo caería lejos del
	# enemigo. Se lo achica para que el cepo aparezca justo sobre él.
	_habilidad_cepo.alcance_maximo = 30.0


func _informar() -> bool:
	print("Se inmovilizó al enemigo (esperado true): %s" % _vio_inmovilizado)
	print("Cantidad de ticks de daño detectados en 3s (esperado >= 5): %d" % _ticks_de_dano)
	print("Inmovilización levantada tras los 3s (esperado true): %s" % (not _mov_enemigo._contador_inmovilizacion > 0))
	if not _vio_inmovilizado:
		_ok = false
	if _ticks_de_dano < 5:
		_ok = false
	if _mov_enemigo._contador_inmovilizacion > 0:
		_ok = false
	print("PRUEBA CEPO %s" % ("OK" if _ok else "FALLIDA"))
	quit(0 if _ok else 1)
	return true
