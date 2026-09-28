extends Node
## GestorEquipo (autoload): el equipo del jugador LOCAL. El dato real vive en
## EquipoComponente, colgado de cada Jugador. Mismo patrón que
## GestorInventario.gd: en el servidor no hay jugador local (usarlo ahí es un
## error), y ver ahí por qué se carga con load() dentro de una función.

var _respaldo = null


func _obtener_componente():
	var jugador := Utils.jugador_local()
	if jugador:
		var c = jugador.get_node_or_null("EquipoComponente")
		if c:
			return c
	if Utils.en_red() and multiplayer.is_server():
		push_error("GestorEquipo es el equipo del jugador LOCAL y en el servidor no hay ninguno: usar el EquipoComponente del jugador que corresponde.")
	if _respaldo == null:
		_respaldo = (load("res://componentes/EquipoComponente.gd") as GDScript).new()
	return _respaldo


var equipados: Array[DatosItem]:
	get:
		return _obtener_componente().equipados
	set(value):
		_obtener_componente().equipados = value


func actualizar(items: Array[DatosItem]) -> void:
	_obtener_componente().actualizar(items)
