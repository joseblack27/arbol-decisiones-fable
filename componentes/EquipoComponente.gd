extends Node
class_name EquipoComponente
## EquipoComponente: lo que ESTE jugador tiene puesto ahora. GestorEquipo
## (autoload) es una fachada que delega acá.

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


## Equipar desde el menú (PanelInventario → GestorEquipo → acá) ocurre en el
## CLIENTE, pero el daño y la defensa los calcula el SERVIDOR con su propio
## AtributosComponente (ver AtributosComponente.calcular_pipeline). Por eso el
## cambio se sincroniza por RPC (ver _sincronizar_equipo_red), como las
## habilidades en SlotHabilidades.gd; _procesando_rpc_red evita reenviar
## mientras se aplica lo que llegó del otro lado.
var _procesando_rpc_red := false

func _sincronizar_equipo_red(items: Array[DatosItem]) -> void:
	if _procesando_rpc_red or not Utils.en_red() or multiplayer.is_server():
		return
	var jugador := get_parent()
	if not is_instance_valid(jugador) or not ("peer_id_dueño" in jugador):
		return
	if jugador.peer_id_dueño != multiplayer.get_unique_id():
		return
	# id_recurso: la ruta del .tres original (ver DatosItem.gd), con
	# resource_path de respaldo si vino vacío (como
	# InventarioComponente.agregar_item()). Una ruta vacía la descarta el
	# servidor en silencio, y el equipo cambiaría solo en la vista previa
	# del cliente.
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
