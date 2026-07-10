extends Node
## GestorExperiencia (autoload) — FACADE de compatibilidad, Fase 1 del plan
## de migración a multijugador. El dato real ya NO vive acá: vive en
## ExperienciaComponente, colgado de cada Jugador. Ver GestorInventario.gd
## para la explicación completa del patrón (mismo criterio acá, incluido
## por qué se carga con load() adentro de una función y no con preload/
## tipado estático a nivel de clase).

var _respaldo = null


func _obtener_componente():
	var jugador := Utils.jugador_local()
	if jugador:
		var c = jugador.get_node_or_null("ExperienciaComponente")
		if c:
			return c
	if _respaldo == null:
		_respaldo = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	return _respaldo


var xp_total: int:
	get:
		return _obtener_componente().xp_total
	set(value):
		_obtener_componente().xp_total = value


func agregar_xp(cantidad: int) -> void:
	_obtener_componente().agregar_xp(cantidad)
