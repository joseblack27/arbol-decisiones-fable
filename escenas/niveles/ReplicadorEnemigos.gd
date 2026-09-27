class_name ReplicadorEnemigos
extends Node
## ÚNICA fuente de verdad, en red, de qué entidades (todo lo que extienda
## Enemigo) existen en el contenedor "Enemigos" de un nivel. Reemplaza al
## MultiplayerSpawner del nivel y a los respaldos manuales que se le fueron
## sumando: con dos mecanismos creando el mismo nodo en el cliente aparecían
## copias huérfanas — mobs que se ven normales pero no se mueven, no pegan y
## no reciben daño (ver bug-huevos-multiplayerspawner-desincronizado.md).
##
## Vive en la misma ruta en servidor y cliente. El servidor observa el
## contenedor y manda altas/bajas en lote, y cada INTERVALO_RECONCILIACION
## segundos la lista completa de lo vivo: el cliente crea lo que le falta y
## despacha lo que le sobra, así cualquier desincronización se cura sola.

const INTERVALO_RECONCILIACION := 2.0

var _contenedor: Node
var _nivel: NivelBase
var _altas_pendientes: Array[Node] = []
var _bajas_pendientes: Array[String] = []
var _tiempo_para_reconciliar := INTERVALO_RECONCILIACION
var _escenas_cacheadas: Dictionary = {}

## CLIENTE: si las altas/bajas incrementales andan bien, la reconciliación no
## tiene nada que corregir salvo la primera (al entrar al nivel). Lo lee el
## bot herramientas/carga/bot_replicacion_enemigos.gd.
var reconciliaciones_recibidas := 0
var correcciones_tras_la_primera := 0


func configurar(contenedor: Node, nivel: NivelBase) -> void:
	_contenedor = contenedor
	_nivel = nivel


func _ready() -> void:
	if not (Utils.en_red() and multiplayer.is_server()):
		set_physics_process(false)
		return
	# Antes que los mobs: el alta de un mob nuevo tiene que salir antes que su
	# primer _recibir_estado_red (ver Enemigo._physics_process).
	process_physics_priority = -100
	_contenedor.child_entered_tree.connect(_al_entrar_hijo)
	_contenedor.child_exiting_tree.connect(_al_salir_hijo)
	GestorNiveles.peer_listo.connect(_al_peer_listo)


static func es_replicable(nodo: Node) -> bool:
	return nodo is Enemigo and nodo.scene_file_path != ""


## El ReplicadorEnemigos del nivel de "nodo", o null (sin red, o fuera de un
## nivel).
static func de(nodo: Node) -> ReplicadorEnemigos:
	var actual := nodo
	while actual != null and not (actual is NivelBase):
		actual = actual.get_parent()
	if actual == null:
		return null
	return actual.get_node_or_null("ReplicadorEnemigos") as ReplicadorEnemigos


# =============================================================================
# SERVIDOR
# =============================================================================

func _al_entrar_hijo(nodo: Node) -> void:
	if es_replicable(nodo):
		_altas_pendientes.append(nodo)


func _al_salir_hijo(nodo: Node) -> void:
	if not es_replicable(nodo):
		return
	_altas_pendientes.erase(nodo)
	_bajas_pendientes.append(String(nodo.name))


## Llamado al morir (Enemigo._desvanecer_y_eliminar): el nodo sigue 0.8s más en
## el árbol desvaneciéndose, y la baja por child_exiting_tree llegaría tarde.
func avisar_muerte(nodo: Node) -> void:
	var nombre := String(nodo.name)
	if not _bajas_pendientes.has(nombre):
		_bajas_pendientes.append(nombre)


## Para quien necesite mandar un RPC que referencie a un mob recién creado
## (p. ej. HabilidadPuestaHuevos._difundir_guardianes): el alta tiene que salir
## antes, por el mismo canal confiable, o el cliente no encuentra el nodo.
func enviar_pendientes() -> void:
	_enviar_pendientes(_peers_del_nivel())


func _physics_process(delta: float) -> void:
	var peers := _peers_del_nivel()
	_enviar_pendientes(peers)
	_tiempo_para_reconciliar -= delta
	if _tiempo_para_reconciliar <= 0.0:
		_tiempo_para_reconciliar = INTERVALO_RECONCILIACION
		if not peers.is_empty():
			var datos := manifiesto()
			for peer_id in peers:
				rpc_id(peer_id, "_reconciliar", datos)


## En lote y un fotograma después del add_child: quien crea un mob casi siempre
## le pone la posición DESPUÉS de agregarlo, así que leerla en
## child_entered_tree daría el origen del contenedor.
func _enviar_pendientes(peers: Array[int]) -> void:
	if _altas_pendientes.is_empty() and _bajas_pendientes.is_empty():
		return
	var altas: Array = []
	for nodo in _altas_pendientes:
		if is_instance_valid(nodo) and nodo.get_parent() == _contenedor \
				and not (nodo as Enemigo).esta_muerto():
			altas.append(_datos_de(nodo))
	var bajas := _bajas_pendientes.duplicate()
	_altas_pendientes.clear()
	_bajas_pendientes.clear()
	for peer_id in peers:
		# Bajas antes que altas: un jefe repuesto con el MISMO nombre en el mismo
		# fotograma (NivelNidoArañaReina._respawnear_reina) suelta primero al viejo.
		if not bajas.is_empty():
			rpc_id(peer_id, "_recibir_bajas", bajas)
		if not altas.is_empty():
			rpc_id(peer_id, "_recibir_altas", altas)


func manifiesto() -> Array:
	var datos: Array = []
	for hijo in _contenedor.get_children():
		if es_replicable(hijo) and not (hijo as Enemigo).esta_muerto():
			datos.append(_datos_de(hijo))
	return datos


func _datos_de(nodo: Node) -> Array:
	return [nodo.scene_file_path, String(nodo.name), (nodo as Node2D).global_position]


func _peers_del_nivel() -> Array[int]:
	var resultado: Array[int] = []
	for peer_id in InteresEspacial.peers_conectados_listos():
		if GestorNiveles.nivel_de_peer(peer_id) == _nivel:
			resultado.append(peer_id)
	return resultado


## Diferido: otros oyentes de peer_listo pueden reponer un jefe en este mismo
## instante (NivelNidoArañaReina/NivelSantuarioGuardian), y el manifiesto tiene
## que salir con el jefe nuevo ya adentro.
func _al_peer_listo(peer_id: int) -> void:
	if GestorNiveles.nivel_de_peer(peer_id) != _nivel:
		return
	_enviar_manifiesto_a.call_deferred(peer_id)


func _enviar_manifiesto_a(peer_id: int) -> void:
	if not multiplayer.get_peers().has(peer_id):
		return
	var datos := manifiesto()
	print("[REPLICADOR] peer=%d nivel=%s entidades=%d" % [peer_id, _nivel.nombre_nivel, datos.size()])
	rpc_id(peer_id, "_reconciliar", datos)


# =============================================================================
# CLIENTE
# =============================================================================

@rpc("authority", "reliable")
func _recibir_altas(datos: Array) -> void:
	for entrada in datos:
		_asegurar_existe(entrada)


@rpc("authority", "reliable")
func _recibir_bajas(nombres: Array) -> void:
	for nombre in nombres:
		var nodo := _contenedor.get_node_or_null(String(nombre)) as Enemigo
		if nodo != null:
			_despachar(nodo)


## A lo que ya existe NO se le toca la posición: de eso se encarga
## Enemigo._recibir_estado_red, y pisarla con un dato de hasta 2s de
## antigüedad haría saltar a los mobs hacia atrás.
@rpc("authority", "reliable")
func _reconciliar(datos: Array) -> void:
	var correcciones := 0
	var vivos_en_servidor := {}
	for entrada in datos:
		vivos_en_servidor[String(entrada[1])] = true
		if _asegurar_existe(entrada):
			correcciones += 1
	for hijo in _contenedor.get_children():
		if es_replicable(hijo) and not vivos_en_servidor.has(String(hijo.name)) \
				and not (hijo as Enemigo).esta_muerto():
			_despachar(hijo as Enemigo)
			correcciones += 1
	reconciliaciones_recibidas += 1
	if reconciliaciones_recibidas > 1 and correcciones > 0:
		correcciones_tras_la_primera += correcciones
		print("[REPLICADOR] la reconciliación corrigió %d entidades" % correcciones)


## true si tuvo que crear el nodo.
func _asegurar_existe(entrada: Array) -> bool:
	var ruta: String = entrada[0]
	var nombre: String = entrada[1]
	var pos: Vector2 = entrada[2]
	if nombre == "":
		return false
	var existente := _contenedor.get_node_or_null(nombre) as Enemigo
	if existente != null:
		if not existente.esta_muerto():
			return false
		# El viejo con el mismo nombre todavía se está desvaneciendo: se le
		# cambia el nombre para liberarle la ruta al nuevo.
		existente.name = "%s_muriendo_%d" % [nombre, existente.get_instance_id()]
	var escena := _escena(ruta)
	if escena == null:
		return false
	var nodo := escena.instantiate() as Node2D
	nodo.name = nombre
	_contenedor.add_child(nodo)
	# Después de add_child: antes, global_position se toma como local, y en un
	# nivel desplazado (GestorNiveles.desplazamiento_de_nivel) el mob quedaría
	# al doble de distancia, fuera del mapa.
	nodo.global_position = pos
	if "_posicion_replicada" in nodo:
		nodo.set("_posicion_replicada", pos)
	return true


func _despachar(nodo: Enemigo) -> void:
	if not nodo.esta_muerto():
		nodo.desvanecer_replica()


func _escena(ruta: String) -> PackedScene:
	if not _escenas_cacheadas.has(ruta):
		_escenas_cacheadas[ruta] = load(ruta) as PackedScene
	return _escenas_cacheadas[ruta]
