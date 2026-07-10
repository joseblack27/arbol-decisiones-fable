extends Node2D
## Servidor dedicado headless del juego real — pensado para correr SOLO
## dentro de Docker (ver prototipos/red/Dockerfile, apunta acá en vez de al
## prototipo de juguete). Autoritativo: instancia un Jugador.tscn real por
## cada peer que se conecta, carga el nivel real (los mobs ya son
## conscientes de red desde antes — ver SpawnerMobs.gd) y reparte el
## combate/botín/XP exactamente igual que en un solo jugador.
##
## El nombre de la raíz de esta escena ("Mundo") tiene que coincidir con el
## de Mundo.tscn (el cliente real) — MultiplayerSpawner replica por path
## desde la raíz, y ambos peers deben verla idéntica.

@export_file("*.tscn") var nivel_inicial := "res://escenas/niveles/NivelPradera.tscn"

const ESCENA_JUGADOR := preload("res://escenas/jugador/Jugador.tscn")

@onready var _jugadores: Node2D = $Jugadores

## Peers conectados cuyo Jugador todavía NO se creó: se espera a que cada
## uno confirme que terminó de cargar el nivel (GestorNiveles.peer_listo)
## para que el mapa exista completo en su pantalla ANTES que su personaje.
var _peers_pendientes: Dictionary = {}
## Respaldo: si el ack nunca llega (cliente colgado, versión vieja), el
## jugador se crea igual pasado este tiempo — mejor un spawn sobre un mapa
## a medio cargar que un jugador que no aparece nunca.
const _ESPERA_MAXIMA_PEER_LISTO := 5.0


func _ready() -> void:
	get_tree().current_scene = self
	GestorNiveles.registrar($ContenedorNivel, null)
	GestorNiveles.cambiar_nivel(nivel_inicial)

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(Utils.PUERTO_JUEGO, 16)
	if error != OK:
		push_error("ServidorDedicado: no se pudo abrir el puerto %d (error %d)." % [Utils.PUERTO_JUEGO, error])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_al_conectar)
	multiplayer.peer_disconnected.connect(_al_desconectar)
	GestorNiveles.peer_listo.connect(_al_peer_listo)
	print("ServidorDedicado escuchando en el puerto %d." % Utils.PUERTO_JUEGO)


func _al_conectar(id: int) -> void:
	print("Peer conectado: %d" % id)
	# Timeout corto: si un cliente se cierra SIN desconectar limpio (matar
	# la ventana, crash), ENet tarda por defecto hasta ~30s en darlo por
	# muerto — su Jugador quedaba como "fantasma" en escena, y si el mismo
	# jugador reconectaba antes veía DOS jugadores (el suyo nuevo + el
	# fantasma del anterior). Con esto el fantasma desaparece en ~3s.
	var peer_enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer_enet:
		peer_enet.get_peer(id).set_timeout(1000, 2000, 3000)
	# El Jugador NO se crea todavía: el cliente primero carga el mapa entero
	# (nivel, navegación, mobs) y avisa con _marcar_listo_red — recién ahí
	# (_al_peer_listo) aparece su personaje, ya sobre un mundo completo.
	_peers_pendientes[id] = true
	get_tree().create_timer(_ESPERA_MAXIMA_PEER_LISTO).timeout.connect(
		_spawnear_si_sigue_pendiente.bind(id))


func _al_peer_listo(id: int) -> void:
	if _peers_pendientes.has(id):
		_spawnear_jugador(id)


## Respaldo por si el ack de "nivel cargado" nunca llegó (ver _ESPERA_MAXIMA
## _PEER_LISTO). Si el peer ya se desconectó, _al_desconectar lo sacó de
## pendientes y esto no hace nada.
func _spawnear_si_sigue_pendiente(id: int) -> void:
	if _peers_pendientes.has(id):
		_spawnear_jugador(id)


func _spawnear_jugador(id: int) -> void:
	_peers_pendientes.erase(id)
	var jugador := ESCENA_JUGADOR.instantiate()
	jugador.name = str(id)
	_jugadores.add_child(jugador, true)
	GestorNiveles.asignar_jugador(jugador)
	# No hace falta equipar nada acá: en cuanto el cliente ve aparecer su
	# propio jugador (Mundo.gd) equipa golpe_basico localmente, y
	# SlotHabilidades._sincronizar_equipo_red() manda ese equipo acá por
	# RPC — un solo lugar decide qué se equipa, sin duplicar la llamada.


func _al_desconectar(id: int) -> void:
	print("Peer desconectado: %d" % id)
	_peers_pendientes.erase(id)
	var jugador := _jugadores.get_node_or_null(str(id))
	if jugador:
		# Avisarle a los mobs ANTES de liberar el nodo: la memoria de su
		# árbol de comportamiento guarda al jugador como "objetivo", y esa
		# referencia liberada hacía reventar cada tick del BT con "Trying to
		# cast a freed object" (spam infinito en el log del servidor).
		for mob in get_tree().get_nodes_in_group("enemigos"):
			if not ("memoria" in mob):
				continue
			var memoria = mob.get("memoria")
			if memoria and memoria.obtener("objetivo") == jugador:
				memoria.establecer("objetivo", null)
				memoria.establecer("jugador_detectado", false)
				memoria.establecer("en_combate", false)
		jugador.queue_free()
