# =============================================================================
# Regresión (reportado en juego real, 23 sep 2026): "las hormigas siguen
# generándose después de pasar por la sala, no antes". Causa real:
# SpawnerMobs._tiempo_restante empieza a correr desde _ready() SIN importar
# "activo" (_process resta delta primero y recién DESPUÉS corta por "not
# activo") -- para cuando ActivadorSalaSpawners activa la sala (spawner
# arrancado con activo=false a propósito), ese temporizador podía estar
# recién reiniciado, tardando un intervalo_spawn ENTERO en generar la
# primera hormiga -- de sobra para que el jugador ya hubiera cruzado la
# sala. activar() ahora fuerza _tiempo_restante a 0 para que la primera
# generación pase en el próximo _process(), no en un momento arbitrario.
#   godot --headless --path . --script res://pruebas/prueba_spawner_activar_reinicia_temporizador.gd
# =============================================================================
extends SceneTree

var _spawner
var _f := 0
var _reinicia_temporizador_al_activar_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		3:
			_probar()
			return _informar()
	return false


func _montar() -> void:
	_spawner = (load("res://escenas/enemigos/SpawnerMobs.gd") as GDScript).new()
	_spawner.activo = false
	_spawner.intervalo_spawn = 999.0  # bien largo, para que un reinicio real se note.
	root.add_child(_spawner)


func _probar() -> void:
	# _tiempo_restante ya viene puesto en intervalo_spawn desde _ready()
	# (corre sin importar "activo", ver el comentario grande de arriba).
	var antes_de_activar = _spawner._tiempo_restante
	_spawner.activar()
	_reinicia_temporizador_al_activar_ok = antes_de_activar > 500.0 and _spawner._tiempo_restante <= 0.0
	print("activar() reinicia el temporizador de generación a YA (esperado true, antes=%.1f ahora=%.1f): %s" % [
		antes_de_activar, _spawner._tiempo_restante, _reinicia_temporizador_al_activar_ok])


func _informar() -> bool:
	var exito := _reinicia_temporizador_al_activar_ok
	print("PRUEBA SPAWNER ACTIVAR REINICIA TEMPORIZADOR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
