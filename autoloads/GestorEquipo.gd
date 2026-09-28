extends Node
## GestorEquipo (autoload): fachada de compatibilidad. El dato real vive en
## EquipoComponente, colgado de cada Jugador. Mismo patrón que
## GestorInventario.gd (ver ahí por qué se carga con load() dentro de una
## función y no con preload ni tipado a nivel de clase).

var _respaldo = null


func _obtener_componente():
	var jugador := Utils.jugador_local()
	if jugador:
		var c = jugador.get_node_or_null("EquipoComponente")
		if c:
			return c
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
