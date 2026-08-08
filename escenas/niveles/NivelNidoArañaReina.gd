extends NivelBase
## Nido de la Araña Reina — el único nivel con un jefe colocado A MANO en la
## escena (Enemigos/EnemigoArañaReina), no generado por SpawnerMobs.
##
## El servidor NUNCA libera un nivel ya cargado (ver GestorNiveles.
## _asegurar_nivel_cargado), así que si la reina se dejara morir sin más, el
## nivel se quedaría sin ella hasta que el servidor reinicie de cero. Mientras
## el juego sigue en pruebas, pedido del usuario: "quiero que respawnee cada
## vez que entre a la cueva" — apenas el primer peer que confirma haber
## cargado el nivel (ver GestorNiveles.peer_listo) llega y la encuentra
## muerta, el SERVIDOR le repone una reina fresca.
##
## Por qué en la MISMA RUTA (Enemigos/EnemigoArañaReina) y no vía
## SpawnerMobs/MultiplayerSpawner: el CLIENTE libera y reinstancia la escena
## ENTERA cada vez que (re)carga un nivel (ver GestorNiveles._cargar) — como
## la reina está horneada en el .tscn, cada entrada ya crea sola una copia
## LOCAL en esa ruta exacta, con o sin reina real del lado del servidor. Si
## el servidor repone la suya EN ESA MISMA RUTA, la sincronización genérica
## por RPC de Enemigo.gd (la MISMA que ya hace funcionar el primer encuentro,
## antes de que muera la primera vez — ver Enemigo._despawn_red/_recibir_
## estado_red, dirigidas por ruta de nodo, no por MultiplayerSpawner) vuelve
## a encontrar un nodo del otro lado y sigue andando sola. Meterla en el
## MultiplayerSpawner de "Enemigos" (pensado para mobs de generadores y
## invocaciones, ver NivelBase._configurar_spawner_red) traería DOS copias
## en el cliente: la horneada del .tscn (que ya existe sola) más la
## replicada por el spawner.
##
## Reportes anteriores que este mecanismo también evita: "aparece bugueada,
## no se mueve, no ataca y no recibe daño" (la copia fantasma sin servidor
## real detrás) y "vuelvo a entrar y se muere sola, instantáneamente" (un
## intento anterior que la ocultaba en vez de reponerla, reusando encima el
## desvanecido de "murió peleando" sin que hubiera pelea).

const _RUTA_REINA := "Enemigos/EnemigoArañaReina"
const _ESCENA_REINA := preload("res://escenas/enemigos/EnemigoArañaReina.tscn")

var _reina_muerta := false
## Dónde vivía la reina original — para reponer la respawneada en el mismo
## lugar. Capturada en _ready(), antes de que pueda morir.
var _posicion_reina: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	if not Utils.en_red() or not multiplayer.is_server():
		return
	var reina := get_node_or_null(_RUTA_REINA)
	if reina:
		_posicion_reina = reina.global_position
		_conectar_muerte(reina)
	GestorNiveles.peer_listo.connect(_al_peer_listo)


func _conectar_muerte(reina: Node) -> void:
	if reina.componente_vida and not reina.componente_vida.muerte.is_connected(_al_morir_reina):
		reina.componente_vida.muerte.connect(_al_morir_reina)


func _al_morir_reina(_valor: float) -> void:
	_reina_muerta = true


## Cubre TANTO a quien vuelve a entrar tras matarla como a un jugador nuevo
## que llega después de que otro ya la mató — los dos casos pasan por acá,
## por igual. Solo dispara el respawn UNA vez por muerte: _reina_muerta
## pasa a false enseguida, así que si dos peers entran casi juntos, el
## segundo ya la encuentra viva y no hace nada.
func _al_peer_listo(peer_id: int) -> void:
	if not _reina_muerta:
		return
	if GestorNiveles.nivel_de_peer(peer_id) != self:
		return
	_respawnear_reina()


## SERVIDOR: repone una reina fresca en la ruta de siempre. Los adds, el
## escudo, la fase y la furia final son todos estado propio de la instancia
## vieja (EnemigoArañaReina.gd) — al crear una instancia NUEVA quedan en su
## valor inicial solos, sin necesidad de resetear nada a mano acá.
func _respawnear_reina() -> void:
	_reina_muerta = false
	var contenedor := get_node_or_null("Enemigos")
	if contenedor == null:
		return
	# Por si el free() diferido de la muerte real (el desvanecido de 0.8s,
	# ver Enemigo._desvanecer_y_eliminar) todavía no terminó de correr —
	# sin este chequeo, dos nodos con el mismo nombre en la misma ruta
	# rompería _RUTA_REINA para todo lo que dependa de ella.
	var vieja := contenedor.get_node_or_null("EnemigoArañaReina")
	if vieja:
		vieja.free()
	var reina := _ESCENA_REINA.instantiate()
	contenedor.add_child(reina)
	reina.global_position = _posicion_reina
	_conectar_muerte(reina)
