# =============================================================================
# Regresión: pedido del usuario — "un hilo desde el jugador hasta el
# sprite [del gancho], y si este está atrayendo a alguien, el hilo también
# se esté recogiendo". HabilidadGancho ahora cuelga un Line2D del propio
# jugador que sigue al proyectil mientras vuela y al enganchado mientras
# dura el tirón (ver HabilidadGancho._process/_crear_hilo/_quitar_hilo).
#
# Verifica, con un gancho real (sin red):
#   1. Apenas se dispara, aparece un Line2D colgado del jugador.
#   2. Mientras el proyectil vuela, la punta del hilo se aleja del jugador
#      (sigue al proyectil en movimiento).
#   3. Tras enganchar, mientras dura el tirón, la punta del hilo se va
#      acercando al jugador a medida que arrastra al objetivo ("se
#      recoge").
#   4. Al terminar el tirón, el hilo desaparece (sin dejar un Line2D huérfano).
#   godot --headless --path . --script res://pruebas/prueba_gancho_hilo.gd
# =============================================================================
extends SceneTree

var _jugador
var _objetivo
var _habilidad
var _fotogramas := 0

var _hilo_aparecio_al_disparar := false
var _distancia_punta_crecio_en_vuelo := false
var _distancia_punta_bajo_durante_tiron := false
var _hilo_desaparecio_al_terminar := false

var _dist_vuelo_1 := -1.0
var _dist_vuelo_2 := -1.0
var _dist_tiron_1 := -1.0
var _dist_tiron_2 := -1.0


static func _script_objetivo() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
func quitar_vida(_cantidad: float, _fuente: Node = null, _tipo: int = 2, _critico: bool = false) -> void:
	pass
"""
	guion.reload()
	return guion


func _buscar_hilo() -> Line2D:
	for hijo in _jugador.get_children():
		if hijo is Line2D:
			return hijo
	return null


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_habilidad.activar(Vector2.RIGHT, 1.0)
		6:
			_hilo_aparecio_al_disparar = _buscar_hilo() != null
		8:
			# 3 fotogramas tras activar (~0.05s): a 600px/s recorrió ~30px de
			# los 80 hasta el objetivo — sigue en pleno vuelo.
			var hilo := _buscar_hilo()
			if hilo:
				_dist_vuelo_1 = hilo.points[1].length()
		12:
			# 7 fotogramas tras activar (~0.12s): ~70px recorridos, todavía
			# antes de llegar a los 80px del objetivo — sigue volando.
			var hilo := _buscar_hilo()
			if hilo:
				_dist_vuelo_2 = hilo.points[1].length()
				_distancia_punta_crecio_en_vuelo = _dist_vuelo_2 > _dist_vuelo_1
		20:
			# ~0.25s tras activar: ya enganchó y el tirón (0.5s) recién
			# empieza (mismo tiempo que usa prueba_gancho.gd para lo mismo).
			var hilo := _buscar_hilo()
			if hilo:
				_dist_tiron_1 = hilo.points[1].length()
		38:
			# ~0.55s tras activar: bien avanzado el tirón (empezó ~0.13s
			# tras activar, dura 0.5s => termina cerca de los 0.63s), justo
			# antes de que termine.
			var hilo := _buscar_hilo()
			if hilo:
				_dist_tiron_2 = hilo.points[1].length()
				_distancia_punta_bajo_durante_tiron = _dist_tiron_2 < _dist_tiron_1
		70:
			# ~1.08s tras activar: el tirón ya terminó de sobra.
			_hilo_desaparecio_al_terminar = _buscar_hilo() == null
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


func _informar() -> bool:
	print("Aparece un hilo apenas se dispara (esperado true): %s" % _hilo_aparecio_al_disparar)
	print("La punta del hilo se aleja mientras el proyectil vuela (esperado true): %s" % _distancia_punta_crecio_en_vuelo)
	print("La punta del hilo se acerca mientras dura el tirón (esperado true): %s" % _distancia_punta_bajo_durante_tiron)
	print("El hilo desaparece al terminar el tirón (esperado true): %s" % _hilo_desaparecio_al_terminar)

	var exito := _hilo_aparecio_al_disparar and _distancia_punta_crecio_en_vuelo \
		and _distancia_punta_bajo_durante_tiron and _hilo_desaparecio_al_terminar
	print("PRUEBA GANCHO HILO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
