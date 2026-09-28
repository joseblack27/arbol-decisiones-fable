extends "res://escenas/npc/NpcAutonomo.gd"
## NPC que vive fuera de los niveles (leñador, minero, cazador): UNA sola
## instancia, colgada SIEMPRE de GestorNiveles.contenedor_errantes() (un
## contenedor fijo, hermano de "Jugadores"). Igual que un jugador, nunca se
## reparenta al cruzar de nivel: solo cambia global_position (ver _cruzar_a),
## así su ruta en el árbol no cambia y las RPC de réplica resuelven en
## cualquier cliente, tenga cargado el nivel que tenga. (Reparentarlo entre los
## niveles rompía esas RPC en los clientes sin ese nivel cargado; dos
## instancias, una por nivel, quedaban congeladas en el nivel sin jugadores.)


func _ready() -> void:
	super._ready()
	if Utils.en_red() and multiplayer.is_server():
		GestorNiveles.peer_listo.connect(_al_peer_listo)


## "Cruzar" = teletransportarse a "punto" (el portal de llegada del otro nivel,
## como GestorNiveles._colocar_peer_en_aparicion con un jugador) y avisarle a
## GestorNiveles en qué nivel está, para que
## MovimientoComponente._usar_mapa_del_nivel() use la malla correcta.
##
## Se oculta ANTES de saltar, avisando a todos: la posición solo les llega a
## los peers cerca de la posición actual, así que un cliente del nivel de origen
## dejaría de recibir actualizaciones y su sprite quedaría dibujado en el último
## punto visto. _recibir_estado_red() lo vuelve a mostrar cuando alguien está lo
## bastante cerca como para recibir posición.
func _cruzar_a(punto: Node2D, ruta_nivel: String) -> void:
	movimiento.detener()
	# rpc() no se llama a sí mismo en quien lo emite: aplicar el cambio acá también.
	visible = false
	rpc("_recibir_visibilidad_red", false)
	if punto:
		global_position = punto.global_position
	GestorNiveles.fijar_nivel_de_entidad(self, ruta_nivel)


## A TODOS, sin filtrar por distancia (ver _cruzar_a).
@rpc("authority", "reliable")
func _recibir_visibilidad_red(visible_ahora: bool) -> void:
	visible = visible_ahora


## Recién conectado: avisarle dónde está AHORA, sin filtrar por nivel: esta
## instancia no pertenece a ningún nivel, y cualquier peer nuevo puede
## necesitarla apenas se acerque.
func _al_peer_listo(peer_id: int) -> void:
	rpc_id(peer_id, "_recibir_estado_red", global_position, direccion, direccion_mirada)
