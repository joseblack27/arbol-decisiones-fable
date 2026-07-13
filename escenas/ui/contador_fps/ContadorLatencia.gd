extends Label
class_name ContadorLatencia
## Muestra la latencia (RTT al servidor) debajo del contador de FPS. Solo
## tiene sentido como CLIENTE en red — contra el servidor (peer id 1). En un
## solo jugador, o corriendo como el propio servidor dedicado, se oculta:
## ninguno de los dos tiene un "ping a sí mismo" que mostrar.
## process_mode ALWAYS: igual que ContadorFPS, sigue actualizando con el
## juego en pausa (menú OS abierto).

## No hace falta consultar esto cada fotograma como los FPS — la latencia no
## cambia tan rápido, y ENetPacketPeer.get_statistic() no es gratis.
const _INTERVALO_ACTUALIZACION := 0.5

var _acumulador := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	# Se recalcula cada frame (no solo en _ready): al principio de una
	# conexión Utils.en_red() ya da true aunque create_client() todavía no
	# haya confirmado nada (ver Mundo._conectar_como_cliente) — si termina
	# cayendo a modo local, este contador tiene que desaparecer solo.
	visible = Utils.en_red() and not multiplayer.is_server()
	if not visible:
		return
	_acumulador += delta
	if _acumulador < _INTERVALO_ACTUALIZACION:
		return
	_acumulador = 0.0
	var latencia := _obtener_latencia_ms()
	text = ("%d ms" % latencia) if latencia >= 0 else "-- ms"


## RTT (ida y vuelta) contra el servidor en milisegundos, o -1 si todavía no
## hay estadística disponible (recién conectando).
func _obtener_latencia_ms() -> int:
	var peer := multiplayer.multiplayer_peer
	if not (peer is ENetMultiplayerPeer):
		return -1
	var enet_peer := (peer as ENetMultiplayerPeer).get_peer(1)
	if enet_peer == null:
		return -1
	return enet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
