# =============================================================================
# Prueba de HabilidadRafaga:
#   1. Al activar, el lanzador queda con el control BLOQUEADO (no moverse ni
#      girar) y el primer proyectil sale de inmediato.
#   2. Salen 5 proyectiles en total, uno cada 0.25s, todos en la MISMA
#      dirección (un objetivo en línea recta recibe los 5 impactos).
#   3. Al terminar la ráfaga, el control se DESBLOQUEA (contador en cero).
#   godot --headless --path . --script res://pruebas/prueba_rafaga.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _tirador: CharacterBody2D
var _objetivo: CharacterBody2D
var _habilidad: Node
var _lock_tras_activar := -1
var _hits_temprano := -1


## El tirador expone el mismo par bloquear/desbloquear_control que
## Jugador.gd real (contador), y el objetivo cuenta cuántos impactos recibió.
static func _script_tirador() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var bloqueos := 0
func bloquear_control() -> void:
	bloqueos += 1
func desbloquear_control() -> void:
	bloqueos = max(0, bloqueos - 1)
"""
	guion.reload()
	return guion


static func _script_objetivo() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var golpes := 0
func quitar_vida(_cantidad: float, _fuente: Node = null, _tipo: int = 2, _critico: bool = false) -> void:
	golpes += 1
"""
	guion.reload()
	return guion


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		10:
			_habilidad.call("activar", Vector2.RIGHT, 1.0)
		12:
			_lock_tras_activar = _tirador.get("bloqueos")
		40:
			# ~0.5s tras activar: deberían haber salido 2-3 proyectiles, no
			# los 5 (verifica que es una ráfaga escalonada, no una descarga).
			_hits_temprano = _objetivo.get("golpes")
		130:
			# ~2s tras activar: ráfaga completa (1s) + vuelo de sobra.
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_tirador = CharacterBody2D.new()
	_tirador.set_script(_script_tirador())
	_tirador.add_to_group("jugadores")
	escena.add_child(_tirador)

	# Objetivo en línea recta a la derecha — con área de vida generosa para
	# que los 5 proyectiles (misma dirección) lo impacten todos.
	_objetivo = CharacterBody2D.new()
	_objetivo.set_script(_script_objetivo())
	_objetivo.add_to_group("enemigos")
	_objetivo.collision_layer = 2
	_objetivo.global_position = Vector2(120, 0)
	escena.add_child(_objetivo)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 14.0
	forma.shape = circ
	_objetivo.add_child(forma)

	var contenedor := Marker2D.new()
	contenedor.name = "Habilidades"
	_tirador.add_child(contenedor)

	var guion := load("res://escenas/habilidades/rafaga/HabilidadRafaga.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.set("duracion_recarga", 0.0)
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _tirador


func _informar() -> bool:
	var golpes: int = _objetivo.get("golpes")
	var bloqueos_final: int = _tirador.get("bloqueos")
	print("Control bloqueado durante la ráfaga (esperado 1): %d" % _lock_tras_activar)
	print("Impactos a ~0.5s (esperado 2 o 3, ráfaga escalonada): %d" % _hits_temprano)
	print("Impactos totales (esperado 5): %d" % golpes)
	print("Control liberado al terminar (esperado 0): %d" % bloqueos_final)
	var exito := _lock_tras_activar == 1 and _hits_temprano >= 2 and _hits_temprano <= 3 \
		and golpes == 5 and bloqueos_final == 0
	print("PRUEBA RAFAGA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
