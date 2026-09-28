# =============================================================================
# Regresión (bug reportado 19 sep 2026, probado en celular real): "las
# hormigas despues del llamado, no responde a un segundo llamado y tambien
# las que quedaron vivas y vuelven a su puesto, dejan de detectar al
# jugador". Una hormiga que no puede llegar al punto de la llamada quedaba con
# "en_llamada_auxilio" en true PARA SIEMPRE — como ResponderLlamada es la rama
# de MÁS prioridad del árbol, quedaba bloqueada de Atacar/Perseguir/Deambular.
#
# Desde el 27 sep 2026 AccionIrAPunto ya no se rinde por tiempo TOTAL (eso
# hacía abandonar a todas las hormigas lejanas a los 6s, ver
# prueba_llamada_reina_llega_por_tuneles.gd) sino tras
# segundos_sin_progreso_para_rendirse sin avanzar por la ruta. Esta prueba la
# traba de verdad (inmovilizada, sin tocar campos internos) hacia un destino
# lejano y alcanzable, y confirma:
#   1. Al segundo sigue respondiendo (todavía no se rindió).
#   2. Tras unos segundos sin poder avanzar, suelta la llamada sola.
#   godot --headless --path . --script res://pruebas/prueba_llamada_auxilio_hormiga_atascada.gd
# =============================================================================
extends SceneTree

const _MS_PRIMER_CHEQUEO := 1000
const _MS_SEGUNDO_CHEQUEO := 5000

var _f := 0
var _inicio_ms := 0
var _hormiga
var _memoria
var _primer_chequeo_hecho := false

var _sigue_atendiendo_al_principio_ok := false
var _se_libera_tras_atascarse_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	if _f == 1:
		_montar()
		return false
	if _f < 30:
		return false  # la malla del nivel tarda unos fotogramas en sincronizar.
	if _f == 30:
		_memoria.establecer("en_llamada_auxilio", true)
		_memoria.establecer("destino_llamada", _destino)
		_inicio_ms = Time.get_ticks_msec()
		return false
	var transcurrido := Time.get_ticks_msec() - _inicio_ms
	if not _primer_chequeo_hecho and transcurrido >= _MS_PRIMER_CHEQUEO:
		_primer_chequeo_hecho = true
		_sigue_atendiendo_al_principio_ok = _memoria.obtener("en_llamada_auxilio", false)
		print("Al segundo sigue respondiendo la llamada (esperado true): %s" % _sigue_atendiendo_al_principio_ok)
	if transcurrido >= _MS_SEGUNDO_CHEQUEO:
		return _informar()
	return false


var _destino := Vector2.ZERO

func _montar() -> void:
	var nivel := (load("res://escenas/niveles/NivelHormiguero.tscn") as PackedScene).instantiate()
	root.add_child(nivel)
	current_scene = nivel
	var enemigos := nivel.get_node("Enemigos")
	var reina: Node2D = enemigos.get_node("EnemigoReinaHormigas")
	reina.get_node("ArbolComportamiento").process_mode = Node.PROCESS_MODE_DISABLED
	_destino = reina.global_position

	_hormiga = (load("res://escenas/enemigos/EnemigoHormigaObrera.tscn") as PackedScene).instantiate()
	enemigos.add_child(_hormiga)
	_hormiga.global_position = nivel.get_node("PuntoAparicion").global_position
	_memoria = _hormiga.get_node("ArbolComportamiento/MemoriaBT")
	# Trabada de verdad: no puede moverse, así que nunca avanza por la ruta.
	_hormiga.get_node("MovimientoComponente").agregar_inmovilizacion()


func _informar() -> bool:
	_se_libera_tras_atascarse_ok = not _memoria.obtener("en_llamada_auxilio", true)
	print("Tras unos segundos sin poder avanzar, suelta la llamada sola (esperado true): %s" % \
		_se_libera_tras_atascarse_ok)
	var exito := _sigue_atendiendo_al_principio_ok and _se_libera_tras_atascarse_ok
	print("PRUEBA LLAMADA AUXILIO HORMIGA ATASCADA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
