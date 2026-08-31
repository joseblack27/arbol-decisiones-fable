extends Node
## InteresEspacial (autoload) — Fase 1 del plan de escalado a MMO.
##
## Hasta acá, TODO se replicaba a TODOS los peers conectados sin importar la
## distancia: la posición del jugador viaja por MultiplayerSynchronizer en
## modo ALWAYS (sin throttle, cada tick de sync, a TODOS); los mobs mandan su
## estado por RPC de broadcast (con throttle por cambio, pero también a
## TODOS). Con eso, el tráfico y el costo de simulación por jugador crecen
## más rápido que la cantidad de jugadores — confirmado en la prueba de
## carga (Fase 4): ~0.25ms/jugador a 14 conectados, ~0.55ms/jugador a 42.
## Es la firma clásica de O(jugadores × entidades) sin ningún filtro.
##
## Esto NO es una grilla espacial (innecesario a la escala objetivo — 100
## jugadores × 100 chequeos de distancia por evaluación es sub-milisegundo,
## trivial comparado con el costo real que se está eliminando: los ENVÍOS
## de red de más). Un filtro de distancia lineal, recalculado solo cuando
## hace falta (ver _actualizar_visibilidad en Jugador.gd), alcanza y sobra
## para esta fase — si en el futuro el CHEQUEO en sí se vuelve el cuello de
## botella (escala mucho mayor), ahí sí vale la pena una grilla de celdas.
##
## SOLO tiene sentido del lado del SERVIDOR: es el único que conoce la
## posición real de todos los jugadores a la vez.

## Radio (px) dentro del cual un jugador/mob es relevante para otro peer.
## Generoso respecto al área visible en pantalla, con margen para que
## entidades no aparezcan/desaparezcan de golpe justo en el borde de cámara.
const RADIO_INTERES := 1400.0
const RADIO_INTERES_CUADRADO := RADIO_INTERES * RADIO_INTERES


## Devuelve el Jugador (CharacterBody2D) que corresponde a un peer_id, o
## null si no existe. Mismo criterio que GestorGuardado._jugador_de_peer —
## centralizado acá porque ahora lo necesitan varios sistemas.
func jugador_de_peer(peer_id: int) -> Node2D:
	for jugador in get_tree().get_nodes_in_group("jugadores"):
		if String(jugador.name) == str(peer_id):
			return jugador as Node2D
	return null


## true si la posición dada está a RADIO_INTERES o menos del jugador de ese
## peer. Si el jugador de ese peer no existe todavía (recién conectado, aún
## sin spawnear), se asume visible — mejor de más que perderse el primer
## estado real por una carrera de timing.
func es_relevante_para_peer(posicion: Vector2, peer_id: int) -> bool:
	var jugador := jugador_de_peer(peer_id)
	if jugador == null:
		return true
	return posicion.distance_squared_to(jugador.global_position) <= RADIO_INTERES_CUADRADO


## Todos los peer_id conectados cuyo jugador está a RADIO_INTERES o menos de
## "posicion". Usado por Enemigo.gd para mandar su estado solo a quien le
## importa, en vez de rpc() (broadcast a TODOS) — ver _physics_process ahí.
## Se saltan los peers que todavía NO confirmaron haber terminado de cargar el
## nivel actual: sus nodos de mob aún no existen, así que cada RPC que se les
## mande lo rechaza el motor con "Invalid packet received. Requested node was
## not found". Eran miles de líneas de error por cada cambio de nivel (peor
## cuanto más tarda en cargar el aparato — un celular tarda muchísimo más que
## un PC), y no se perdía nada real: en cuanto el peer avisa que está listo
## vuelve a entrar acá, y SpawnerMobs le hace un resync completo (ver
## [RESYNC] en el log del servidor).
func peers_cercanos(posicion: Vector2) -> Array[int]:
	var resultado: Array[int] = []
	for peer_id in _peers_enviables():
		if es_relevante_para_peer(posicion, peer_id):
			resultado.append(peer_id)
	return resultado


## Todos los peers a los que tiene sentido mandarles algo AHORA MISMO, sin
## filtro de distancia — para lo que sí debe llegar a todo el servidor sin
## importar el mapa/posición (ej. GestorChat, canal "Mundo"). Mismo criterio
## defensivo que peers_cercanos (ver _peers_enviables): evita el chaparrón de
## "Unable to send packet" contra un peer que ENet ya dio por caído.
func peers_conectados_listos() -> Array[int]:
	return _peers_enviables()


## Peers a los que TIENE SENTIDO mandarles algo ahora mismo, calculado UNA vez
## por fotograma físico y reusado por todos los mobs (antes cada mob rehacía
## esta lista entera en cada fotograma).
##
## El filtro por estado de ENet no es paranoia: `multiplayer.get_peers()` sigue
## listando a un peer que ENet ya dio por caído hasta que Godot emite
## peer_disconnected, y mandarle algo en esa ventana revienta con "Unable to
## send packet on channel 1, max channels: 0" — MILES de líneas por sesión (se
## midieron 1524 con sólo dos jugadores quietos, y 9114 en otra corrida). Ese
## chaparrón de errores por consola es lo bastante caro como para hacer perder
## la conexión a los demás, así que un jugador cayéndose se llevaba puestos a
## los otros. Bug viejo, sin relación con los niveles: aparece apenas hay dos
## jugadores conectados a la vez.
var _peers_enviables_cache: Array[int] = []
var _fotograma_cache: int = -1

func _peers_enviables() -> Array[int]:
	var fotograma := Engine.get_physics_frames()
	if fotograma == _fotograma_cache:
		return _peers_enviables_cache
	_fotograma_cache = fotograma
	_peers_enviables_cache = []
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	for peer_id in multiplayer.get_peers():
		# Todavía cargando su nivel: sus nodos no existen y el motor le
		# rechazaría cada paquete con "Requested node was not found".
		if not GestorNiveles.peer_listo_para_nivel_actual(peer_id):
			continue
		if enet != null:
			var par := enet.get_peer(peer_id)
			if par == null or par.get_state() != ENetPacketPeer.STATE_CONNECTED:
				continue
		_peers_enviables_cache.append(peer_id)
	return _peers_enviables_cache
