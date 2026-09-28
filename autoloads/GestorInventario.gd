extends Node
## GestorInventario (autoload): fachada de compatibilidad. El dato real vive en
## InventarioComponente, colgado de cada Jugador (ver Jugador.tscn); este
## autoload delega al del jugador local, para el código que ya lo usaba directo
## (PanelInventario, Enemigo, GestorGuardado...).
##
## Si no hay ningún jugador con InventarioComponente (pruebas que arman un
## "jugador" a mano, herramientas sueltas), cae a una instancia propia de
## respaldo (el mismo InventarioComponente, nunca colgado del árbol).
##
## InventarioComponente no se tipa ni se precarga en el cuerpo de la clase: ese
## script usa BusEventos, y resolverlo durante el arranque de este autoload
## (antes de que existan todos) rompe la compilación. Se carga en tiempo de
## ejecución, dentro de una función.

## null hasta el primer uso — ver _obtener_componente().
var _respaldo = null


func _obtener_componente():
	var jugador := Utils.jugador_local()
	if jugador:
		var c = jugador.get_node_or_null("InventarioComponente")
		if c:
			return c
	if _respaldo == null:
		_respaldo = (load("res://componentes/InventarioComponente.gd") as GDScript).new()
	return _respaldo


var items: Array[DatosItem]:
	get:
		return _obtener_componente().items
	set(value):
		_obtener_componente().items = value


func agregar_item(item: DatosItem, cantidad: int = -1, silencioso: bool = false) -> void:
	_obtener_componente().agregar_item(item, cantidad, silencioso)


func quitar_item(item: DatosItem) -> void:
	_obtener_componente().quitar_item(item)


func quitar_cantidad(item: DatosItem, cantidad: int) -> bool:
	return _obtener_componente().quitar_cantidad(item, cantidad)


func tiene_item(nombre: String) -> bool:
	return _obtener_componente().tiene_item(nombre)


func usar_item(item: DatosItem) -> void:
	_obtener_componente().usar_item(item)
