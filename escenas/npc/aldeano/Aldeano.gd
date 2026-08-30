extends CharacterBody2D
class_name Aldeano
## NPC de fondo, puramente ambiental — deambula en un radio chico alrededor
## de su posición de aparición dentro de la Ciudad (nunca cruza de nivel,
## vive colgado directo del contenedor "NPCs" del propio NivelCiudad.tscn,
## a diferencia de Lenador.gd/Cazador.gd) y, si el jugador le habla, se
## detiene a conversar y retoma su recorrido al cerrarse el diálogo.
## Pedido explícito del usuario: "quiero que la ciudad se vea un poco más
## viva... aldeanos de fondo, que tenga un diálogo si les hablas y al
## interactuar con ellos que se detengan para hablarte".
##
## INMUNIDAD A COMBATE — mismo criterio que Lenador.gd/Cazador.gd: a
## propósito NO extiende Enemigo.gd, sin VidaComponente, fuera de los
## grupos "jugadores"/"enemigos".
##
## DEAMBULAR reimplementado a mano (mismo cálculo que AccionDeambular.gd,
## sin árbol de comportamiento — este NPC no tiene ArbolComportamiento):
## elige un punto al azar dentro de radio_deambulacion de su posición de
## aparición, movimiento.comandar_destino() hasta ahí (pathfinding real,
## nunca sale de la malla de navegación — a diferencia de comandar_
## direccion(), ver el bug real ya arreglado en AccionHuir.gd), espera un
## rato, repite.
##
## "SE DETIENEN PARA HABLARTE": la máquina de estados (quién puede mover al
## aldeano) la decide el SERVIDOR, igual que cualquier otro NPC — pero
## quién sabe "estoy hablando con este aldeano ahora mismo" es cada
## CLIENTE (GestorUI.modo_actual es puramente local, ver GestorUI.gd). Por
## eso el cliente le avisa al servidor por RPC cuándo empieza y cuándo
## termina de hablar (_avisar_hablando), y el servidor cuenta cuántos
## jugadores están "hablando" ahora mismo (_hablantes, mismo criterio de
## contador que Npc.gd._cuerpos_dentro: puede haber más de uno a la vez,
## no alcanza un booleano) — mientras ese contador sea > 0, la máquina de
## estados se queda quieta en HABLANDO en vez de retomar el deambular.

const CAPA_NPC_ERRANTE := 16  # misma capa que ya usa Lenador.gd/Cazador.gd.
const _FOTOGRAMAS_KEEPALIVE_RED := 30
const _UMBRAL_REPLICAR := 4.0
const _RADIO_LLEGADA := 10.0
const _CAPA_CUERPO_JUGADOR := 8

@export_group("Diálogo")
## Obligatorio: todo aldeano habla (mismo criterio que Npc.gd).
@export var datos_dialogo: DatosDialogo
@export var nombre: String = "Aldeano"
@export var texto_interaccion: String = "Hablar"

@export_group("Deambular")
@export var velocidad: float = 60.0
@export var radio_deambulacion: float = 200.0
@export var espera_en_destino: float = 2.0

enum Estado { DEAMBULANDO, ESPERANDO, HABLANDO }

@onready var movimiento: MovimientoComponente = $MovimientoComponente
@onready var componente_animacion: AnimacionComponente = $AnimacionComponente
@onready var _area_interaccion: Area2D = $AreaInteraccion

var direccion: Vector2 = Vector2.ZERO
var direccion_mirada: Vector2 = Vector2.DOWN
var _posicion_replicada: Vector2 = Vector2.ZERO

var _estado: int = Estado.DEAMBULANDO
var _posicion_origen: Vector2 = Vector2.ZERO
var _destino: Vector2 = Vector2.ZERO
var _espera_restante: float = 0.0
## SERVIDOR: cuántos jugadores tienen el diálogo de ESTE aldeano abierto
## ahora mismo — ver el comentario de arriba.
var _hablantes: int = 0
## CLIENTE: ¿el diálogo que tengo abierto YO ahora mismo es el de este
## aldeano? Distingue "se cerró MI diálogo con este aldeano" de "se cerró
## cualquier otro panel" en _al_cambiar_modo().
var _hablando_localmente := false

var _cuerpos_dentro: int = 0

var _ultima_posicion_enviada: Vector2 = Vector2.ZERO
var _fotogramas_desde_envio := 0


func _ready() -> void:
	collision_layer = CAPA_NPC_ERRANTE
	collision_mask = 1  # CAPA_MUNDO — solo terreno.
	_posicion_origen = global_position
	_posicion_replicada = global_position
	if _area_interaccion:
		_area_interaccion.collision_mask = _CAPA_CUERPO_JUGADOR
		_area_interaccion.body_entered.connect(_al_entrar_cuerpo)
		_area_interaccion.body_exited.connect(_al_salir_cuerpo)
	# Corre en TODOS los peers (no solo servidor) — cada cliente necesita
	# saber cuándo SU PROPIO diálogo con este aldeano se cerró.
	GestorUI.modo_cambiado.connect(_al_cambiar_modo)
	if not (Utils.en_red() and multiplayer.is_server()):
		return  # Cliente: réplica visual pura, ver _physics_process/_recibir_estado_red.
	_destino = _elegir_destino()
	_estado = Estado.DEAMBULANDO


func _physics_process(delta: float) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		_aplicar_presentacion(global_position.distance_to(_posicion_replicada) > 1.0)
		global_position = global_position.lerp(_posicion_replicada, 0.2)
		return
	_procesar_estado(delta)
	_aplicar_presentacion(velocity != Vector2.ZERO)
	_replicar_si_corresponde()


# =============================================================================
# MÁQUINA DE ESTADOS (solo servidor)
# =============================================================================

func _procesar_estado(delta: float) -> void:
	if _hablantes > 0:
		if _estado != Estado.HABLANDO:
			movimiento.detener()
			_estado = Estado.HABLANDO
		return
	elif _estado == Estado.HABLANDO:
		# Recién dejó de hablar nadie — vuelve a pasear tras la misma
		# espera de siempre en vez de salir disparado de inmediato.
		_espera_restante = espera_en_destino
		_estado = Estado.ESPERANDO

	match _estado:
		Estado.DEAMBULANDO:
			movimiento.comandar_destino(_destino, velocidad)
			if movimiento.llego_al_destino(_RADIO_LLEGADA):
				movimiento.detener()
				_espera_restante = espera_en_destino
				_estado = Estado.ESPERANDO

		Estado.ESPERANDO:
			movimiento.detener()
			_espera_restante -= delta
			if _espera_restante <= 0.0:
				_destino = _elegir_destino()
				_estado = Estado.DEAMBULANDO


func _elegir_destino() -> Vector2:
	var angulo := randf_range(0.0, TAU)
	var distancia := randf_range(radio_deambulacion * 0.3, radio_deambulacion)
	return _posicion_origen + Vector2.from_angle(angulo) * distancia


# =============================================================================
# INTERACCIÓN / DIÁLOGO
# =============================================================================

func _al_entrar_cuerpo(cuerpo: Node2D) -> void:
	if cuerpo != Utils.jugador_local():
		return
	_cuerpos_dentro += 1
	if _cuerpos_dentro == 1:
		GestorInteraccion.registrar(self, nombre, acciones_interaccion())


func _al_salir_cuerpo(cuerpo: Node2D) -> void:
	if cuerpo != Utils.jugador_local():
		return
	_cuerpos_dentro = maxi(0, _cuerpos_dentro - 1)
	if _cuerpos_dentro == 0:
		GestorInteraccion.quitar(self)


## Llamado al tocar la acción "Hablar" (ver ListaInteraccion.gd) — corre en
## el CLIENTE que lo tocó, igual que Npc.interactuar().
func interactuar() -> void:
	if datos_dialogo == null:
		return
	_hablando_localmente = true
	_avisar_hablando(true)
	BusEventos.dialogo_solicitado.emit(self, datos_dialogo)


func acciones_interaccion() -> Array[Dictionary]:
	return [{"texto": texto_interaccion, "callback": interactuar}]


## PanelDialogo cierra volviendo GestorUI.Modo a JUEGO (ver GestorUI.
## cerrar_dialogo()) — mismo camino que cerrar el menú OS, así que hace
## falta el flag local _hablando_localmente para saber que ESTE cierre es
## el de MI conversación con este aldeano en particular, no cualquier otro
## panel cerrándose.
func _al_cambiar_modo(modo: int) -> void:
	if _hablando_localmente and modo == GestorUI.Modo.JUEGO:
		_hablando_localmente = false
		_avisar_hablando(false)


func _avisar_hablando(hablando: bool) -> void:
	if not Utils.en_red():
		_hablantes = 1 if hablando else 0
		return
	if multiplayer.is_server():
		_cambiar_hablantes(1 if hablando else -1)
	else:
		rpc_id(1, "_avisar_hablando_red", hablando)


@rpc("any_peer", "reliable")
func _avisar_hablando_red(hablando: bool) -> void:
	if not multiplayer.is_server():
		return
	_cambiar_hablantes(1 if hablando else -1)


func _cambiar_hablantes(delta: int) -> void:
	_hablantes = maxi(0, _hablantes + delta)


# =============================================================================
# PRESENTACIÓN / RED — mismo patrón que Lenador.gd/Cazador.gd, sin cruce de
# nivel ni RPC de visibilidad (este NPC vive siempre dentro de la Ciudad,
# nunca "desaparece" de un nivel a otro).
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
	_posicion_replicada = pos
	direccion = dir
	direccion_mirada = mirada
