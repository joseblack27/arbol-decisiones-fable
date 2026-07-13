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
		# restaurar_xp() (no una asignación directa): re-sincroniza el nivel
		# derivado y su crecimiento acumulado (vida_maxima/energia_maxima/
		# daños) — necesario al cargar una partida guardada, ver
		# GestorGuardado y la nota en ExperienciaComponente.restaurar_xp().
		_obtener_componente().restaurar_xp(value)


## Nivel actual del jugador — derivado de xp_total, ver TablaNiveles.
var nivel: int:
	get:
		return _obtener_componente().nivel


func agregar_xp(cantidad: int) -> void:
	_obtener_componente().agregar_xp(cantidad)
