extends CharacterBody2D
## Base de los NPC autónomos (sin control de jugador): leñador, minero, cazador
## y aldeano. La IA (_procesar_estado) corre SOLO en el servidor; en un
## cliente el NPC es una réplica visual pura que interpola hacia la posición
## que manda el servidor a los peers cercanos (InteresEspacial).
##
## INMUNIDAD A COMBATE: a propósito NO extienden Enemigo.gd, no tienen
## VidaComponente ni quitar_vida() y no están en los grupos
## "jugadores"/"enemigos": para VisionComponente, Combate.golpear_area() y
## Proyectil._resolver_colision() no existen (igual que escenas/npc/Npc.gd, el
## comerciante). La capa física propia (CAPA_NPC_ERRANTE) es cinturón y
## tirantes.
##
## Las subclases heredan por ruta (extends "res://...") y no por class_name,
## para no depender del caché de clases que actualiza el editor.

const CAPA_NPC_ERRANTE := 16  # primer bit libre (1 mundo, 2 mob, 4 obstáculos, 8 jugador)
const MARGEN_LLEGADA := 16.0
const _FOTOGRAMAS_KEEPALIVE_RED := 30
const _UMBRAL_REPLICAR := 4.0
## Salto de posición (px) a partir del cual el cliente teletransporta su
## réplica en vez de deslizarla: cruzar de nivel mueve al NPC decenas de miles
## de px, y un lerp() ahí se vería como un tirón cruzando la pantalla.
const _UMBRAL_SNAP_CLIENTE := 300.0

@onready var movimiento: MovimientoComponente = $MovimientoComponente
@onready var componente_animacion: AnimacionComponente = $AnimacionComponente

var direccion: Vector2 = Vector2.ZERO
var direccion_mirada: Vector2 = Vector2.DOWN
var _posicion_replicada: Vector2 = Vector2.ZERO

var _ultima_posicion_enviada: Vector2 = Vector2.ZERO
var _fotogramas_desde_envio := 0


func _ready() -> void:
	collision_layer = CAPA_NPC_ERRANTE
	collision_mask = 1  # CAPA_MUNDO: solo terreno.
	if not (Utils.en_red() and multiplayer.is_server()):
		return  # Cliente: réplica visual pura, ver _physics_process/_recibir_estado_red.
	_preparar_servidor()


## SERVIDOR: resolver referencias y arrancar la máquina de estados. Lo
## implementa cada NPC.
func _preparar_servidor() -> void:
	pass


## SERVIDOR: un paso de la máquina de estados. Lo implementa cada NPC.
func _procesar_estado(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		_aplicar_presentacion(global_position.distance_to(_posicion_replicada) > 1.0)
		if global_position.distance_to(_posicion_replicada) > _UMBRAL_SNAP_CLIENTE:
			global_position = _posicion_replicada
		else:
			global_position = global_position.lerp(_posicion_replicada, 0.2)
		return
	_procesar_estado(delta)
	_aplicar_presentacion(velocity != Vector2.ZERO)
	_replicar_si_corresponde()


# =============================================================================
# AYUDAS PARA LA MÁQUINA DE ESTADOS
# =============================================================================

## Punto al que caminar para usar "objeto": su área de interacción si tiene
## (ObjetoRecolectable, almacenes), o su origen. El origen puede quedar pegado
## a la colisión sólida del objeto, donde el agente de navegación no llega.
func _punto_de_interaccion(objeto: Node2D) -> Vector2:
	var area = objeto.get("area_interaccion")
	return (area as Node2D).global_position if area else objeto.global_position


## El ObjetoRecolectable disponible (no agotado) más cercano entre los hijos
## de "contenedor". Genérico: sirve igual para árboles, vetas o hierbas.
func _recolectable_mas_cercano(contenedor: Node) -> ObjetoRecolectable:
	if contenedor == null:
		return null
	var mejor: ObjetoRecolectable = null
	var mejor_distancia := INF
	for hijo in contenedor.get_children():
		if hijo is ObjetoRecolectable and not (hijo as ObjetoRecolectable).esta_agotado():
			var distancia := global_position.distance_to((hijo as Node2D).global_position)
			if distancia < mejor_distancia:
				mejor_distancia = distancia
				mejor = hijo
	return mejor


# =============================================================================
# PRESENTACIÓN / RED — mismo patrón que Enemigo.gd
# =============================================================================

## Única lógica de presentación, compartida entre el servidor y la réplica.
func _aplicar_presentacion(caminando: bool) -> void:
	if direccion != Vector2.ZERO:
		direccion_mirada = direccion
	if not componente_animacion:
		return
	componente_animacion.establecer_condicion("parameters/conditions/debeCaminar", caminando)
	componente_animacion.establecer_condicion("parameters/conditions/debeIdle", not caminando)
	componente_animacion.actualizar_blend(direccion_mirada)


## Manda la posición a los peers cercanos cuando cambia, y un keepalive cada
## _FOTOGRAMAS_KEEPALIVE_RED por si se perdió el último paquete.
func _replicar_si_corresponde() -> void:
	if not Utils.en_red():
		return
	_fotogramas_desde_envio += 1
	var cambio_relevante := global_position.distance_to(_ultima_posicion_enviada) > _UMBRAL_REPLICAR
	if not cambio_relevante and _fotogramas_desde_envio < _FOTOGRAMAS_KEEPALIVE_RED:
		return
	_fotogramas_desde_envio = 0
	_ultima_posicion_enviada = global_position
	for peer_id in InteresEspacial.peers_cercanos(global_position):
		rpc_id(peer_id, "_recibir_estado_red", global_position, direccion, direccion_mirada)


## Recibir posición significa estar lo bastante cerca como para que
## InteresEspacial la mande: también es la señal de "ya se me puede ver" tras
## cruzar de nivel (ver NpcErrante._cruzar_a).
@rpc("authority", "unreliable_ordered")
func _recibir_estado_red(pos: Vector2, dir: Vector2, mirada: Vector2) -> void:
	visible = true
	_posicion_replicada = pos
	direccion = dir
	direccion_mirada = mirada
