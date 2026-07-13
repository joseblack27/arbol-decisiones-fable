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
func peers_cercanos(posicion: Vector2) -> Array[int]:
	var resultado: Array[int] = []
	for peer_id in multiplayer.get_peers():
		if es_relevante_para_peer(posicion, peer_id):
			resultado.append(peer_id)
	return resultado
