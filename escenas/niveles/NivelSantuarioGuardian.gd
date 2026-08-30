extends NivelBase
## Santuario del Guardián Quebrado — mismo patrón exacto que
## NivelNidoArañaReina.gd (ver ese archivo para el porqué completo): el jefe
## vive COLOCADO A MANO en la escena (Enemigos/EnemigoGuardianQuebrado), no
## generado por SpawnerMobs/MultiplayerSpawner, porque el servidor nunca
## libera un nivel ya cargado — sin reponerlo a mano, el nivel se quedaría
## sin jefe para siempre tras la primera muerte.
##
## Reposición en la MISMA ruta de nodo (no vía MultiplayerSpawner) por el
## mismo motivo documentado en NivelNidoArañaReina.gd: el cliente reinstancia
## la escena ENTERA al (re)cargar el nivel, así que el jefe horneado en el
## .tscn ya existe solo del lado del cliente — reponerlo del lado del
## servidor en esa misma ruta deja que la sincronización genérica por RPC de
## Enemigo.gd (dirigida por ruta de nodo) lo encuentre y siga funcionando,
## sin la copia fantasma que daría meterlo en el MultiplayerSpawner.

const _RUTA_JEFE := "Enemigos/EnemigoGuardianQuebrado"
const _ESCENA_JEFE := preload("res://escenas/enemigos/EnemigoGuardianQuebrado.tscn")

var _jefe_muerto := false
## Dónde vivía el jefe original — para reponer al respawneado en el mismo
## lugar. Capturada en _ready(), antes de que pueda morir.
var _posicion_jefe: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	if not Utils.en_red() or not multiplayer.is_server():
		return
	var jefe := get_node_or_null(_RUTA_JEFE)
	if jefe:
		_posicion_jefe = jefe.global_position
		_conectar_muerte(jefe)
	GestorNiveles.peer_listo.connect(_al_peer_listo)


func _conectar_muerte(jefe: Node) -> void:
	if jefe.componente_vida and not jefe.componente_vida.muerte.is_connected(_al_morir_jefe):
		jefe.componente_vida.muerte.connect(_al_morir_jefe)


func _al_morir_jefe(_valor: float) -> void:
	_jefe_muerto = true


## Cubre tanto a quien vuelve a entrar tras matarlo como a un jugador nuevo
## que llega después de que otro ya lo mató. Solo dispara el respawn UNA vez
## por muerte: _jefe_muerto pasa a false enseguida, así que si dos peers
## entran casi juntos, el segundo ya lo encuentra vivo y no hace nada.
func _al_peer_listo(peer_id: int) -> void:
	if not _jefe_muerto:
		return
	if GestorNiveles.nivel_de_peer(peer_id) != self:
		return
	_respawnear_jefe()


## SERVIDOR: repone un jefe fresco en la ruta de siempre. Todo el estado de
## fase (umbral de vida, fase actual) es propio de la instancia vieja
## (EnemigoGuardianQuebrado.gd) — una instancia NUEVA arranca en fase 1 sola,
## sin necesidad de resetear nada a mano acá.
func _respawnear_jefe() -> void:
	_jefe_muerto = false
	var contenedor := get_node_or_null("Enemigos")
	if contenedor == null:
		return
	# Por si el free() diferido de la muerte real (el desvanecido de la
	# muerte, ver Enemigo._desvanecer_y_eliminar) todavía no terminó de
	# correr — sin este chequeo, dos nodos con el mismo nombre en la misma
	# ruta rompería _RUTA_JEFE para todo lo que dependa de ella.
	var viejo := contenedor.get_node_or_null("EnemigoGuardianQuebrado")
	if viejo:
		viejo.free()
	var jefe := _ESCENA_JEFE.instantiate()
	contenedor.add_child(jefe)
	jefe.global_position = _posicion_jefe
	_conectar_muerte(jefe)
