extends Node
## Instancia (una sola vez) el Minero.tscn — ver Minero.gd — y guarda el
## almacén compartido donde deposita el mineral: mismo diseño que
## GestorLenador.gd (pozo real, validado por el servidor, la misma cantidad
## para todos los jugadores en todo momento), pero SIMPLIFICADO: el Minero
## nunca cruza de nivel (mina y almacén viven los dos dentro de NivelMina),
## así que alcanza con mantener activo un solo nivel, sin lógica de "cruce"
## como la que sí necesita el Leñador entre Ciudad y Pradera.
##
## Autoload de .gd puro (no de escena) — mismo criterio que GestorLenador.

const _RUTA_GUARDADO := "user://almacen_minero.save"
const _RUTA_MINA := "res://escenas/niveles/NivelMina.tscn"
const _ESCENA_MINERO := preload("res://escenas/npc/minero/Minero.tscn")

## PanelCofre.gd (modo almacén del minero, ver ese archivo) se autosuscribe
## para refrescar su grilla — se emite cada vez que almacen_replicado
## cambia, sea por depósito, retiro propio o eco de red.
signal almacen_actualizado()

## Ruta del DatosItem -> cantidad depositada. Única fuente de verdad del
## almacén — replicada a los clientes vía _recibir_almacen_red, NUNCA
## mutada directo por un cliente.
var _almacen: Dictionary = {}

## Espejo de solo lectura para la UI del cliente (ver PanelCofre.
## _obtener_items_almacen_minero) — se actualiza únicamente al recibir
## _recibir_almacen_red.
var almacen_replicado: Dictionary = {}

var _preparado_servidor := false


## Mismo motivo que GestorLenador._ready(): este autoload arranca antes de
## que exista un MultiplayerPeer real, así que el setup de verdad se pospone
## al primer GestorNiveles.nivel_cargado.
func _ready() -> void:
	GestorNiveles.nivel_cargado.connect(_al_nivel_cargado)


func _al_nivel_cargado(_nivel: NivelBase) -> void:
	if _preparado_servidor or not Utils.en_red() or not multiplayer.is_server():
		return
	_preparado_servidor = true
	_cargar_desde_disco()
	_actualizar_replica()

	var nivel_mina := GestorNiveles.asegurar_nivel_cargado_servidor(_RUTA_MINA)
	# Mismo pedido que ya se aplicó al Leñador: la mina se mantiene activa
	# aunque no haya ningún jugador ahí en este momento, o el Minero se
	# apagaría junto con el nivel.
	GestorNiveles.mantener_siempre_activo(_RUTA_MINA)
	GestorNiveles.peer_listo.connect(_al_peer_listo)

	var contenedor := GestorNiveles.contenedor_errantes()
	if contenedor and nivel_mina:
		var minero := _ESCENA_MINERO.instantiate()
		contenedor.add_child(minero)
		# "En casa" al arrancar: junto al almacén, mismo criterio que el
		# Leñador arrancando junto al portal de Ciudad.
		var almacen := nivel_mina.get_node_or_null("Decoraciones/AlmacenMinero1")
		if almacen:
			minero.global_position = almacen.global_position


## SOLO lo llama el propio minero, server-side (o local sin red) — nunca lo
## dispara un jugador, no necesita RPC de pedido. Broadcast a todos: el pozo
## es el mismo para todos, así que todos necesitan enterarse al instante.
func depositar_servidor(item: DatosItem) -> void:
	if item == null:
		return
	var ruta := item.resource_path
	_almacen[ruta] = int(_almacen.get(ruta, 0)) + item.quantity
	_actualizar_replica()
	_guardar_a_disco()
	if Utils.en_red():
		rpc("_recibir_almacen_red", _almacen)


## Pedido de retiro: cliente sin red o servidor local aplica directo; en red,
## el cliente pide y el servidor valida antes de aplicar — mismo patrón de 4
## pasos que GestorLenador.pedir_retirar/ObjetoRecolectable._pedir_recolectar_red.
func pedir_retirar(ruta_item: String, cantidad: int) -> void:
	if not Utils.en_red():
		_retirar_local(Utils.jugador_local(), ruta_item, cantidad)
		return
	if multiplayer.is_server():
		_retirar_local(Utils.jugador_local(), ruta_item, cantidad)
		return
	rpc_id(1, "_pedir_retirar_red", ruta_item, cantidad)


@rpc("any_peer", "reliable")
func _pedir_retirar_red(ruta_item: String, cantidad: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var jugador := InteresEspacial.jugador_de_peer(peer_id)
	if jugador == null:
		return
	_retirar_local(jugador, ruta_item, cantidad)


func _retirar_local(jugador: Node, ruta_item: String, cantidad: int) -> void:
	if cantidad <= 0:
		return
	if int(_almacen.get(ruta_item, 0)) < cantidad:
		return
	var item := load(ruta_item) as DatosItem
	if item == null:
		return
	_almacen[ruta_item] = int(_almacen[ruta_item]) - cantidad
	if _almacen[ruta_item] <= 0:
		_almacen.erase(ruta_item)
	_actualizar_replica()
	_guardar_a_disco()
	# silencioso=false a propósito: acá SÍ es botín nuevo para este jugador.
	var inventario: Node = null
	if jugador and is_instance_valid(jugador):
		inventario = jugador.get_node_or_null("InventarioComponente")
	if inventario:
		inventario.agregar_item(item, cantidad)
	if Utils.en_red() and multiplayer.is_server():
		rpc("_recibir_almacen_red", _almacen)


@rpc("authority", "reliable")
func _recibir_almacen_red(almacen: Dictionary) -> void:
	_almacen = almacen
	_actualizar_replica()


func _al_peer_listo(peer_id: int) -> void:
	rpc_id(peer_id, "_recibir_almacen_red", _almacen)


func _actualizar_replica() -> void:
	almacen_replicado = _almacen.duplicate()
	almacen_actualizado.emit()


func _guardar_a_disco() -> void:
	var archivo := FileAccess.open(_RUTA_GUARDADO, FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_string(JSON.stringify(_almacen))


func _cargar_desde_disco() -> void:
	if not FileAccess.file_exists(_RUTA_GUARDADO):
		return
	var archivo := FileAccess.open(_RUTA_GUARDADO, FileAccess.READ)
	if archivo == null:
		return
	var datos = JSON.parse_string(archivo.get_as_text())
	if datos is Dictionary:
		_almacen = datos
