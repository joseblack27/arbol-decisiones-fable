extends Node
class_name EquipoComponente
## EquipoComponente — lo que ESTE jugador tiene puesto ahora mismo (Fase 1
## del plan de migración a multijugador). Antes vivía en el autoload
## GestorEquipo; ver ese archivo, que ahora es una fachada de compatibilidad.

var equipados: Array[DatosItem] = []


func actualizar(items: Array[DatosItem]) -> void:
	equipados = items
	BusEventos.equipo_cambiado.emit(equipados)
	# Recalcular los atributos del PROPIO jugador (hermano directo, ver
	# Jugador.tscn) va acá, no escuchando el bus global de arriba: ese bus
	# es una única señal por proceso — en el cliente la escuchaban TODOS
	# los Jugador en pantalla (incluidas réplicas de otros), y en el
	# servidor (con un Jugador por peer conectado) el filtro por dueño no
	# tiene forma de saber "cuál de todos ellos" cambió solo con la señal.
	# Llamando directo al propio hermano, cada EquipoComponente actualiza
	# SOLO su propio AtributosComponente, sin ambigüedad, en cliente Y
	# servidor por igual.
	var jugador := get_parent()
	if jugador:
		var atributos := jugador.get_node_or_null("AtributosComponente")
		if atributos:
			atributos.recalcular_con_equipo(items)
	_sincronizar_equipo_red(items)


## Fase 7 del plan de multijugador: equipar algo desde el menú (PanelInventario
## → GestorEquipo → acá) solo tocaba el lado del CLIENTE — el servidor, que
## es quien de verdad calcula daño/defensa en combate (ver
## AtributosComponente.calcular_pipeline, leído del AtributosComponente del
## nodo del SERVIDOR, nunca del cliente), nunca se enteraba del equipo real.
## Resultado: equipar mejor armadura/arma no cambiaba nada en combates de
## verdad, solo en la vista previa local de quien lo equipó (mismo patrón y
## mismo bug ya resuelto para las habilidades, ver SlotHabilidades.gd).
var _procesando_rpc_red := false

func _sincronizar_equipo_red(items: Array[DatosItem]) -> void:
	if _procesando_rpc_red or not Utils.en_red() or multiplayer.is_server():
		return
	var jugador := get_parent()
	if not is_instance_valid(jugador) or not ("peer_id_dueño" in jugador):
		return
	if jugador.peer_id_dueño != multiplayer.get_unique_id():
		return
	# id_recurso: la ruta del .tres original (ver DatosItem.gd). Respaldo a
	# resource_path si id_recurso vino vacío (mismo criterio que
	# InventarioComponente.agregar_item()) — sin esto, un ítem cuyo campo
	# id_recurso nunca se estampó (p. ej. un .tres de fábrica al que se le
	# olvidó ponerlo, ver recursos/items/equipables/*.tres) mandaba una ruta
	# vacía al servidor, que la descartaba en silencio: el equipo cambiaba
	# de verdad solo en la vista previa del cliente, nunca en el servidor
	# (bug reportado: "al desequipar un item no se actualizan los atributos"
	# — pasaba igual al EQUIPAR, pero se notaba menos porque la vista previa
	# local ya mostraba el bono aplicado).
	var rutas: PackedStringArray = []
	for item in items:
		if item == null:
			rutas.append("")
		else:
			rutas.append(item.id_recurso if item.id_recurso != "" else item.resource_path)
	rpc_id(1, "_equipar_red", rutas)


@rpc("any_peer", "reliable")
func _equipar_red(rutas: PackedStringArray) -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not is_instance_valid(jugador) or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	var items: Array[DatosItem] = []
	for ruta in rutas:
		if ruta != "" and ResourceLoader.exists(ruta):
			items.append(load(ruta) as DatosItem)
	_procesando_rpc_red = true
	actualizar(items)
	_procesando_rpc_red = false
