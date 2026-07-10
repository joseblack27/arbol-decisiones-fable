extends Node
## GestorInventario (autoload) — FACADE de compatibilidad, Fase 1 del plan
## de migración a multijugador. El dato real ya NO vive acá: vive en
## InventarioComponente, colgado de cada Jugador (ver Jugador.tscn) — así,
## más adelante, cada jugador conectado puede tener el suyo propio en vez de
## uno global compartido. Este autoload solo delega al componente del
## jugador que encuentre en escena, para no tener que tocar todo el código
## que ya lo usaba directo (PanelInventario, Enemigo, GestorGuardado...).
##
## Si no hay ningún jugador en escena con InventarioComponente (pruebas
## que arman un "jugador" a mano sin componentes, herramientas sueltas),
## cae a una instancia propia de respaldo — mismo comportamiento de
## siempre, sin duplicar la lógica (reutiliza el propio InventarioComponente,
## solo que nunca colgado del árbol).
##
## Sin tipar (ni precargar en el cuerpo de la clase) InventarioComponente en
## ningún lado: ese script referencia BusEventos en sus métodos, y resolverlo
## durante el arranque de este autoload (antes de que todos los autoloads
## existan) revienta la compilación — se carga recién en tiempo de
## ejecución, adentro de una función (mismo artefacto que las pruebas
## --script; ver otras notas del proyecto).

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


func tiene_item(nombre: String) -> bool:
	return _obtener_componente().tiene_item(nombre)
