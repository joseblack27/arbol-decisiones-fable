extends "res://escenas/npc/NpcAutonomo.gd"
class_name Aldeano
## NPC de fondo, puramente ambiental: deambula en un radio chico alrededor de
## donde apareció en la Ciudad (nunca cruza de nivel: vive en el contenedor
## "NPCs" de NivelCiudad.tscn, a diferencia de Lenador.gd y Cazador.gd) y, si
## el jugador le habla, se detiene a conversar y retoma al cerrarse el diálogo.
## Réplica, presentación e inmunidad a combate: ver NpcAutonomo.gd.
##
## DEAMBULAR reimplementado a mano (mismo cálculo que AccionDeambular.gd; este
## NPC no tiene ArbolComportamiento): un punto al azar dentro de
## radio_deambulacion, movimiento.comandar_destino() hasta ahí (pathfinding
## real, nunca sale de la malla, a diferencia de comandar_direccion()), una
## espera, y de nuevo.
##
## "SE DETIENE PARA HABLARTE": la máquina de estados la decide el SERVIDOR,
## pero quién está hablando con este aldeano lo sabe cada CLIENTE
## (GestorUI.modo_actual es local). El cliente avisa por RPC cuándo empieza y
## termina de hablar (_avisar_hablando), y el servidor anota quiénes hablan a la
## vez (_hablantes): mientras haya alguno, se queda en HABLANDO.

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

@onready var _area_interaccion: Area2D = $AreaInteraccion

var _estado: int = Estado.DEAMBULANDO
var _posicion_origen: Vector2 = Vector2.ZERO
var _destino: Vector2 = Vector2.ZERO
var _espera_restante: float = 0.0
## SERVIDOR: quiénes tienen el diálogo de ESTE aldeano abierto ahora (peer id
## -> true; 0 = el jugador sin red). Un conjunto y no un contador: cada
## jugador solo se agrega o se saca a sí mismo, y si se desconecta con el
## diálogo abierto se lo saca (ver _al_desconectar_peer). Con un contador,
## esa desconexión dejaba al aldeano congelado "hablando" para siempre.
var _hablantes: Dictionary = {}
## CLIENTE: ¿el diálogo que tengo abierto YO ahora mismo es el de este
## aldeano? Distingue "se cerró MI diálogo con este aldeano" de "se cerró
## cualquier otro panel" en _al_cambiar_modo().
var _hablando_localmente := false

var _cuerpos_dentro: int = 0


func _ready() -> void:
	_posicion_origen = global_position
	_posicion_replicada = global_position
	if _area_interaccion:
		_area_interaccion.collision_mask = _CAPA_CUERPO_JUGADOR
		_area_interaccion.body_entered.connect(_al_entrar_cuerpo)
		_area_interaccion.body_exited.connect(_al_salir_cuerpo)
	# Corre en TODOS los peers (no solo servidor) — cada cliente necesita
	# saber cuándo SU PROPIO diálogo con este aldeano se cerró.
	GestorUI.modo_cambiado.connect(_al_cambiar_modo)
	super._ready()


func _preparar_servidor() -> void:
	multiplayer.peer_disconnected.connect(_al_desconectar_peer)
	_destino = _elegir_destino()
	_estado = Estado.DEAMBULANDO


# =============================================================================
# MÁQUINA DE ESTADOS (solo servidor)
# =============================================================================

func _procesar_estado(delta: float) -> void:
	if not _hablantes.is_empty():
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
		_marcar_hablante(0, hablando)
		return
	if multiplayer.is_server():
		_marcar_hablante(multiplayer.get_unique_id(), hablando)
	else:
		rpc_id(1, "_avisar_hablando_red", hablando)


## SERVIDOR: cualquier jugador puede avisar que habla con este aldeano, pero
## solo por sí mismo (su peer id es la clave).
@rpc("any_peer", "reliable")
func _avisar_hablando_red(hablando: bool) -> void:
	if not multiplayer.is_server():
		return
	_marcar_hablante(multiplayer.get_remote_sender_id(), hablando)


func _marcar_hablante(peer_id: int, hablando: bool) -> void:
	if hablando:
		_hablantes[peer_id] = true
	else:
		_hablantes.erase(peer_id)


func _al_desconectar_peer(peer_id: int) -> void:
	_hablantes.erase(peer_id)
