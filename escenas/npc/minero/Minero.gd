extends CharacterBody2D
class_name Minero
## NPC autónomo (sin control de jugador): pica el mineral disponible más
## cercano dentro de la mina y lo deposita en el almacén compartido (ver
## GestorMinero.gd). Mismo diseño que Lenador.gd (ver ese archivo para el
## porqué completo de cada decisión: inmunidad a combate, réplica de
## posición, etc.), SIMPLIFICADO porque acá el NPC nunca cruza de nivel —
## mina y almacén viven los dos dentro de NivelMina, así que no hace falta
## la máquina de "ir al portal / cruzar / volver al portal" que sí necesita
## el Leñador entre Ciudad y Pradera.
##
## INMUNIDAD A COMBATE: a propósito NO extiende Enemigo.gd, NO tiene
## VidaComponente ni ningún método quitar_vida(), y NO pertenece a los
## grupos "jugadores"/"enemigos" — mismo contrato que Lenador.gd/Npc.gd.

const CAPA_NPC_ERRANTE := 16  # primer bit libre (1 mundo, 2 mob, 4 obstáculos, 8 jugador)
const MARGEN_LLEGADA := 16.0
const _ESPERA_ANTES_DE_PICAR := 2.0
const _ESPERA_SIN_VETA := 3.0
const _FOTOGRAMAS_KEEPALIVE_RED := 30
const _UMBRAL_REPLICAR := 4.0
const _UMBRAL_SNAP_CLIENTE := 300.0

const _RUTA_MINA := "res://escenas/niveles/NivelMina.tscn"

enum Estado {
	BUSCANDO_VETA,       # eligiendo la veta más cercana disponible
	ESPERANDO_VETA,      # no hay ninguna disponible, reintenta
	YENDO_A_LA_VETA,     # caminando a la veta elegida
	PICANDO,             # acción instantánea de picar
	YENDO_AL_ALMACEN,    # caminando al almacén a depositar
	DEPOSITANDO,         # acción instantánea de depósito
}

@onready var movimiento: MovimientoComponente = $MovimientoComponente
@onready var componente_animacion: AnimacionComponente = $AnimacionComponente

var direccion: Vector2 = Vector2.ZERO
var direccion_mirada: Vector2 = Vector2.DOWN
var _posicion_replicada: Vector2 = Vector2.ZERO

var _estado: int = Estado.BUSCANDO_VETA
var _espera_restante: float = 0.0
var _veta_objetivo: ObjetoRecolectable = null
var _carga_actual: DatosItem = null

## Resueltos una sola vez en _ready(), server-side.
var _almacen_punto: AlmacenMinero
var _contenedor_vetas: Node

var _ultima_posicion_enviada: Vector2 = Vector2.ZERO
var _fotogramas_desde_envio := 0


func _ready() -> void:
	collision_layer = CAPA_NPC_ERRANTE
	collision_mask = 1  # CAPA_MUNDO — solo terreno, nada más.
	if not (Utils.en_red() and multiplayer.is_server()):
		return  # Cliente: réplica visual pura, ver _physics_process/_recibir_estado_red.

	var nivel_mina := GestorNiveles.asegurar_nivel_cargado_servidor(_RUTA_MINA)
	if nivel_mina:
		_almacen_punto = nivel_mina.get_node_or_null("Decoraciones/AlmacenMinero1")
		_contenedor_vetas = nivel_mina.get_node_or_null("Decoraciones")

	GestorNiveles.fijar_nivel_de_entidad(self, _RUTA_MINA)
	_estado = Estado.BUSCANDO_VETA
	GestorNiveles.peer_listo.connect(_al_peer_listo)


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
# MÁQUINA DE ESTADOS (solo servidor)
# =============================================================================

func _procesar_estado(delta: float) -> void:
	match _estado:
		Estado.BUSCANDO_VETA:
			_veta_objetivo = _veta_mas_cercana()
			if _veta_objetivo == null:
				_espera_restante = _ESPERA_SIN_VETA
				_estado = Estado.ESPERANDO_VETA
			else:
				_estado = Estado.YENDO_A_LA_VETA

		Estado.ESPERANDO_VETA:
			movimiento.detener()
			_espera_restante -= delta
			if _espera_restante <= 0.0:
				_estado = Estado.BUSCANDO_VETA

		Estado.YENDO_A_LA_VETA:
			if _veta_objetivo == null or not is_instance_valid(_veta_objetivo) \
					or _veta_objetivo.esta_agotado():
				_estado = Estado.BUSCANDO_VETA
				return
			var destino := _veta_objetivo.area_interaccion.global_position \
					if _veta_objetivo.area_interaccion else _veta_objetivo.global_position
			movimiento.comandar_destino(destino)
			# Mismo motivo que Lenador.YENDO_AL_ARBOL: el radio de interacción
			# REAL de la veta, no una comparación de distancia a secas — el
			# centro exacto puede caer sobre el cuerpo sólido no navegable.
			if movimiento.llego_al_destino(_veta_objetivo.radio_interaccion_servidor):
				movimiento.detener()
				_estado = Estado.PICANDO

		Estado.PICANDO:
			if _veta_objetivo != null and is_instance_valid(_veta_objetivo):
				_carga_actual = _veta_objetivo.recolectar_para_npc()
			_veta_objetivo = null
			_estado = Estado.YENDO_AL_ALMACEN

		Estado.YENDO_AL_ALMACEN:
			if _almacen_punto == null:
				return
			var destino_almacen := _almacen_punto.area_interaccion.global_position \
					if _almacen_punto.area_interaccion else _almacen_punto.global_position
			movimiento.comandar_destino(destino_almacen)
			if movimiento.llego_al_destino(_almacen_punto.radio_interaccion):
				movimiento.detener()
				_estado = Estado.DEPOSITANDO

		Estado.DEPOSITANDO:
			if _carga_actual != null:
				GestorMinero.depositar_servidor(_carga_actual)
				_carga_actual = null
			_estado = Estado.BUSCANDO_VETA


## Recorre _contenedor_vetas y elige el ObjetoRecolectable disponible más
## cercano — genérico a propósito (mismo criterio que Lenador._arbol_mas_
## cercano), sirve igual si más adelante hay varios tipos de veta.
func _veta_mas_cercana() -> ObjetoRecolectable:
	if _contenedor_vetas == null:
		return null
	var mejor: ObjetoRecolectable = null
	var mejor_distancia := INF
	for hijo in _contenedor_vetas.get_children():
		if hijo is ObjetoRecolectable and not (hijo as ObjetoRecolectable).esta_agotado():
			var distancia := global_position.distance_to((hijo as Node2D).global_position)
			if distancia < mejor_distancia:
				mejor_distancia = distancia
				mejor = hijo
	return mejor


# =============================================================================
# PRESENTACIÓN / RED — mismo patrón que Lenador.gd/Enemigo.gd
# =============================================================================

func _aplicar_presentacion(caminando: bool) -> void:
	if direccion != Vector2.ZERO:
		direccion_mirada = direccion
	if not componente_animacion:
		return
	componente_animacion.establecer_condicion("parameters/conditions/debeCaminar", caminando)
	componente_animacion.establecer_condicion("parameters/conditions/debeIdle", not caminando)
	componente_animacion.actualizar_blend(direccion_mirada)


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


@rpc("authority", "unreliable_ordered")
func _recibir_estado_red(pos: Vector2, dir: Vector2, mirada: Vector2) -> void:
	visible = true
	_posicion_replicada = pos
	direccion = dir
	direccion_mirada = mirada


## Recién conectado: avisarle dónde está el minero AHORA.
func _al_peer_listo(peer_id: int) -> void:
	rpc_id(peer_id, "_recibir_estado_red", global_position, direccion, direccion_mirada)
