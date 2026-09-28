extends Node
## Base de los almacenes compartidos de los NPC (GestorLenador, GestorMinero):
## un pozo REAL, validado por el servidor, con la misma cantidad para todos los
## jugadores (a diferencia de los cofres, que son por jugador; ver
## Cofre.gd/CofresComponente). El NPC deposita en el servidor
## (depositar_servidor) y los jugadores retiran pidiéndoselo al servidor
## (pedir_retirar). Cada gestor define dónde se guarda (_ruta_guardado) y
## instancia su NPC y deja activos sus niveles (_preparar_mundo).
##
## Los gestores heredan por ruta (extends "res://...") y no por class_name,
## para no depender del caché de clases que actualiza el editor. Autoload de .gd
## puro (no de escena): no guarda recursos editables en el Inspector.

## PanelCofre.gd (modo almacén) se autosuscribe para refrescar su grilla: se
## emite cada vez que almacen_replicado cambia (depósito, retiro propio o eco de
## red, ver _actualizar_replica).
signal almacen_actualizado()

## Ruta del DatosItem -> cantidad depositada. Única fuente de verdad del
## almacén, replicada a los clientes vía _recibir_almacen_red; un cliente NUNCA
## la muta directo.
var _almacen: Dictionary = {}

## Espejo de solo lectura para la UI del cliente (ver PanelCofre): se
## actualiza únicamente al recibir _recibir_almacen_red.
var almacen_replicado: Dictionary = {}

var _preparado_servidor := false


## Archivo donde el servidor guarda este almacén.
func _ruta_guardado() -> String:
	return ""


## SERVIDOR: instanciar el NPC y dejar cargados y activos sus niveles.
func _preparar_mundo() -> void:
	pass


## Los autoloads arrancan (_ready) ANTES de que ServidorDedicado arme el
## MultiplayerPeer, así que acá Utils.en_red()/multiplayer.is_server() darían
## false. El setup real se pospone al primer GestorNiveles.nivel_cargado, que
## recién llega con la red ya armada.
func _ready() -> void:
	GestorNiveles.nivel_cargado.connect(_al_nivel_cargado)


func _al_nivel_cargado(_nivel: NivelBase) -> void:
	if _preparado_servidor or not Utils.en_red() or not multiplayer.is_server():
		return
	_preparado_servidor = true
	_cargar_desde_disco()
	_actualizar_replica()
	GestorNiveles.peer_listo.connect(_al_peer_listo)
	_preparar_mundo()


## SOLO lo llama el NPC, en el servidor (o sin red): ningún jugador lo dispara,
## no necesita RPC de pedido. Aviso a todos: el pozo es el mismo para todos,
## así que todos necesitan enterarse al instante.
func depositar_servidor(item: DatosItem) -> void:
	if item == null:
		return
	var ruta := item.resource_path
	_almacen[ruta] = int(_almacen.get(ruta, 0)) + item.quantity
	_actualizar_replica()
	_guardar_a_disco()
	if Utils.en_red():
		rpc("_recibir_almacen_red", _almacen)


## Pedido de retiro: sin red o en el servidor se aplica directo; un cliente
## pide y el servidor valida antes de aplicar (el mismo patrón de 4 pasos que
## ObjetoRecolectable._pedir_recolectar_red).
func pedir_retirar(ruta_item: String, cantidad: int) -> void:
	if not Utils.en_red() or multiplayer.is_server():
		_retirar_local(Utils.jugador_local(), ruta_item, cantidad)
		return
	rpc_id(1, "_pedir_retirar_red", ruta_item, cantidad)


## SERVIDOR: cualquier jugador puede retirar; se le da al que lo pidió.
@rpc("any_peer", "reliable")
func _pedir_retirar_red(ruta_item: String, cantidad: int) -> void:
	if not multiplayer.is_server():
		return
	var jugador := InteresEspacial.jugador_de_peer(multiplayer.get_remote_sender_id())
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
	# silencioso=false a propósito, a diferencia de desequipar: acá SÍ es botín
	# nuevo para este jugador y corresponde la notificación.
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
	var archivo := FileAccess.open(_ruta_guardado(), FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_string(JSON.stringify(_almacen))


func _cargar_desde_disco() -> void:
	if not FileAccess.file_exists(_ruta_guardado()):
		return
	var archivo := FileAccess.open(_ruta_guardado(), FileAccess.READ)
	if archivo == null:
		return
	var datos = JSON.parse_string(archivo.get_as_text())
	if datos is Dictionary:
		_almacen = datos
