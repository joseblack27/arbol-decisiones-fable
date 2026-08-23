extends Node
## Instancia (una sola vez) el Lenador.tscn del leñador — ver Lenador.gd — y
## guarda el almacén compartido donde deposita la madera: un pozo REAL,
## validado por el servidor, la misma cantidad para todos los jugadores en
## todo momento (a diferencia de los cofres normales del juego, que son por
## jugador — ver Cofre.gd/CofresComponente). Pedido explícito del usuario
## tras preguntarle.
##
## El leñador es UNA sola instancia (no dos, ver el comentario de
## GestorNiveles.registrar_errantes para el porqué del rediseño: reparentar
## entre los NPCs de cada nivel rompía la réplica en cualquier cliente que
## no tuviera ese nivel cargado — bug real reportado "el leñador no se
## mueve"). Vive colgada de GestorNiveles.contenedor_errantes(), fuera de
## cualquier nivel, y solo cambia de global_position al "cruzar" — igual que
## un jugador cruzando un portal.
##
## Autoload de .gd puro (no de escena): no guarda ningún recurso editable
## en Inspector, mismo criterio que GestorInventario/GestorEquipo.

const _RUTA_GUARDADO := "user://almacen_lenador.save"
const _RUTA_CIUDAD := "res://escenas/niveles/NivelCiudad.tscn"
const _RUTA_PRADERA := "res://escenas/niveles/NivelPradera.tscn"
const _ESCENA_LENADOR := preload("res://escenas/npc/leñador/Lenador.tscn")

## PanelCofre.gd (modo almacén, ver ese archivo) se autosuscribe para
## refrescar su grilla — se emite cada vez que almacen_replicado cambia,
## sea por depósito, retiro propio o eco de red (ver _actualizar_replica).
signal almacen_actualizado()

## Ruta del DatosItem -> cantidad depositada. Única fuente de verdad del
## almacén — replicada a los clientes vía _recibir_almacen_red, NUNCA
## mutada directo por un cliente.
var _almacen: Dictionary = {}

## Espejo de solo lectura para la UI del cliente (ver PanelCofre.
## _obtener_items_almacen) — se actualiza únicamente al recibir
## _recibir_almacen_red.
var almacen_replicado: Dictionary = {}


var _preparado_servidor := false


## OJO: este autoload arranca (_ready) ANTES que ServidorDedicado.gd
## siquiera exista — los autoloads se inicializan al arrancar el motor,
## bastante antes de que la escena principal cree el ENetMultiplayerPeer y
## llame GestorNiveles.preparar_servidor() (ver ServidorDedicado.gd:42-76).
## Un chequeo directo de Utils.en_red()/multiplayer.is_server() ACÁ siempre
## daría false, así que el setup real (asegurar niveles, engancharse a
## peer_listo) queda pospuesto al primer GestorNiveles.nivel_cargado —esa
## señal solo se emite después de que ServidorDedicado ya dejó
## multiplayer.multiplayer_peer armado, así que para cuando llega acá el
## chequeo de red ya es correcto. Conectar la señal en sí no depende de
## nada de esto, así que eso sí puede pasar siempre.
func _ready() -> void:
	GestorNiveles.nivel_cargado.connect(_al_nivel_cargado)


func _al_nivel_cargado(_nivel: NivelBase) -> void:
	if _preparado_servidor or not Utils.en_red() or not multiplayer.is_server():
		return
	_preparado_servidor = true
	_cargar_desde_disco()
	_actualizar_replica()

	var nivel_ciudad := GestorNiveles.asegurar_nivel_cargado_servidor(_RUTA_CIUDAD)
	GestorNiveles.asegurar_nivel_cargado_servidor(_RUTA_PRADERA)
	# Pedido explícito del usuario: "dejar activo ambos mapa a la vez" — sin
	# esto, GestorNiveles._actualizar_actividad_niveles() apagaba el nivel
	# donde NO había ningún jugador conectado (ahorro de CPU, ver ese
	# comentario), y el que quedaba apagado se llevaba puesto al leñador si
	# estaba ahí en ese momento.
	GestorNiveles.mantener_siempre_activo(_RUTA_CIUDAD)
	GestorNiveles.mantener_siempre_activo(_RUTA_PRADERA)
	GestorNiveles.peer_listo.connect(_al_peer_listo)

	var contenedor := GestorNiveles.contenedor_errantes()
	if contenedor and nivel_ciudad:
		var lenador := _ESCENA_LENADOR.instantiate()
		contenedor.add_child(lenador)
		# "En casa" al arrancar: junto al portal de salida de Ciudad, mismo
		# criterio que el punto de aparición de un jugador.
		var portal := nivel_ciudad.get_node_or_null("PortalAPradera")
		if portal:
			lenador.global_position = portal.global_position


## SOLO lo llama el propio leñador, server-side (o local sin red) — nunca lo
## dispara un jugador, no necesita RPC de pedido. Broadcast a todos: el pozo
## es el mismo para todos, así que todos necesitan enterarse al instante, no
## solo quien interactúa (a diferencia de un cofre por jugador).
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
## pasos que ObjetoRecolectable._pedir_recolectar_red.
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
	# silencioso=false a propósito, a diferencia del caso de desequipar: acá
	# SÍ es botín nuevo para este jugador — corresponde la notificación.
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
