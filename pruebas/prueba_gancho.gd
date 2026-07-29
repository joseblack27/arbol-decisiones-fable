# =============================================================================
# Prueba de HabilidadGancho (sin red): dispara un proyectil que, si
# engancha a un enemigo, lo arrastra en un tirón rápido hasta una
# posición fija enfrente del jugador. Pedido explícito del usuario:
#   - Mientras el gancho está resolviendo (vuelo + tirón), el jugador que
#     lo lanzó NO se puede mover ni activar NINGUNA otra habilidad.
#   - Mientras dura el tirón, el enganchado tampoco se mueve por su
#     cuenta (MovimientoComponente inmovilizado).
#   - El tirón dura ~0.5s y termina justo enfrente del jugador.
#
# Verifica:
#   1. Al activar, el jugador queda con el control bloqueado de inmediato
#      (no solo el margen breve de HabilidadBase.activar() — ver
#      HabilidadGancho._ejecutar()).
#   2. Mientras el gancho sigue resolviendo, intentar activar OTRA
#      habilidad no hace nada (el chequeo nuevo en HabilidadBase.activar()).
#   3. Tras enganchar al objetivo, éste queda inmovilizado
#      (MovimientoComponente._contador_inmovilizacion > 0) MIENTRAS el
#      jugador sigue bloqueado.
#   4. Al terminar el tirón (~0.5s después de enganchar): el objetivo
#      queda justo enfrente del jugador, se libera la inmovilización, y
#      el jugador recupera el control — y AHORA sí puede activar la otra
#      habilidad.
#   godot --headless --path . --script res://pruebas/prueba_gancho.gd
# =============================================================================
extends SceneTree

var _jugador
var _objetivo
var _habilidad
var _otra_habilidad
var _fotogramas := 0

var _bloqueado_tras_activar := false
var _otra_habilidad_bloqueada_en_pleno_gancho := false
var _objetivo_inmovilizado_durante_tiron := false
var _jugador_sigue_bloqueado_durante_tiron := false
var _objetivo_termino_enfrente := false
var _inmovilizacion_liberada := false
var _jugador_libre_al_final := false
var _otra_habilidad_funciona_al_final := false


static func _script_objetivo() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
func quitar_vida(_cantidad: float, _fuente: Node = null, _tipo: int = 2, _critico: bool = false) -> void:
	pass
"""
	guion.reload()
	return guion


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_habilidad.activar(Vector2.RIGHT, 1.0)
		6:
			_bloqueado_tras_activar = _jugador._bloqueos_control > 0
			_otra_habilidad.activar()
			_otra_habilidad_bloqueada_en_pleno_gancho = _otra_habilidad.obtener_recarga_restante() <= 0.0
		20:
			# ~0.23s tras activar: el proyectil (600px/s) ya recorrió sobra
			# para enganchar al objetivo a 80px, pero el tirón (0.5s) recién
			# empieza — el jugador debe seguir bloqueado.
			var mov := _objetivo.get_node("MovimientoComponente") as MovimientoComponente
			_objetivo_inmovilizado_durante_tiron = mov._contador_inmovilizacion > 0
			_jugador_sigue_bloqueado_durante_tiron = _jugador._bloqueos_control > 0
		70:
			# ~1.08s tras activar: de sobra para que el tirón (0.5s) ya haya
			# terminado.
			var destino: Vector2 = _jugador.global_position + Vector2.RIGHT * 40.0
			_objetivo_termino_enfrente = _objetivo.global_position.distance_to(destino) < 2.0
			var mov := _objetivo.get_node("MovimientoComponente") as MovimientoComponente
			_inmovilizacion_liberada = mov._contador_inmovilizacion == 0
			_jugador_libre_al_final = _jugador._bloqueos_control == 0
			_otra_habilidad.activar()
			_otra_habilidad_funciona_al_final = _otra_habilidad.obtener_recarga_restante() > 0.0
			return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO

	_objetivo = CharacterBody2D.new()
	_objetivo.set_script(_script_objetivo())
	_objetivo.add_to_group("enemigos")
	_objetivo.collision_layer = 2
	_objetivo.global_position = Vector2(80, 0)
	root.add_child(_objetivo)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 12.0
	forma.shape = circ
	_objetivo.add_child(forma)
	var mov := MovimientoComponente.new()
	mov.name = "MovimientoComponente"
	_objetivo.add_child(mov)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var guion := load("res://escenas/habilidades/gancho/HabilidadGancho.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.slot_index = 0
	_habilidad.escena_proyectil = load("res://escenas/habilidades/gancho/GanchoProyectil.tscn")
	_habilidad.daño_proyectil = 0.0
	_habilidad.duracion_recarga = 2.0
	_habilidad.costo_energia = 0.0
	_habilidad.duracion_tiron = 0.5
	_habilidad.distancia_frente = 40.0
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador

	# Habilidad DISTINTA en otro slot, para probar que el bloqueo de
	# "control" del gancho también impide activar OTRA cosa mientras
	# resuelve — no solo moverse.
	_otra_habilidad = HabilidadBase.new()
	_otra_habilidad.slot_index = 1
	_otra_habilidad.duracion_recarga = 1.0
	_otra_habilidad.costo_energia = 0.0
	contenedor.add_child(_otra_habilidad)
	_otra_habilidad.entidad_dueña = _jugador


func _informar() -> bool:
	print("Jugador bloqueado apenas activa el gancho (esperado true): %s" % _bloqueado_tras_activar)
	print("Otra habilidad NO se activa en pleno gancho (esperado true): %s" % _otra_habilidad_bloqueada_en_pleno_gancho)
	print("Objetivo inmovilizado durante el tirón (esperado true): %s" % _objetivo_inmovilizado_durante_tiron)
	print("Jugador sigue bloqueado durante el tirón (esperado true): %s" % _jugador_sigue_bloqueado_durante_tiron)
	print("Objetivo terminó justo enfrente del jugador (esperado true): %s" % _objetivo_termino_enfrente)
	print("Inmovilización liberada al terminar (esperado true): %s" % _inmovilizacion_liberada)
	print("Jugador libre al terminar (esperado true): %s" % _jugador_libre_al_final)
	print("Otra habilidad SÍ funciona una vez libre (esperado true): %s" % _otra_habilidad_funciona_al_final)

	var exito := _bloqueado_tras_activar and _otra_habilidad_bloqueada_en_pleno_gancho \
		and _objetivo_inmovilizado_durante_tiron and _jugador_sigue_bloqueado_durante_tiron \
		and _objetivo_termino_enfrente and _inmovilizacion_liberada \
		and _jugador_libre_al_final and _otra_habilidad_funciona_al_final
	print("PRUEBA GANCHO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
