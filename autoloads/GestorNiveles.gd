extends Node
## GestorNiveles (autoload): administra los niveles del mundo.
##
## Funciona en DOS modos, a propósito distintos:
##
##  • CLIENTE y UN JUGADOR — hay UN nivel a la vez dentro del contenedor: al
##    cambiar se libera el anterior y se instancia el nuevo, con fundido a
##    negro y barra de progreso. Es el comportamiento de toda la vida.
##
##  • SERVIDOR DEDICADO — hay N niveles cargados A LA VEZ y cada jugador
##    pertenece a uno (ver _nivel_por_peer). Antes el servidor tenía un solo
##    nivel para todos: el primero que cruzaba un portal le cambiaba el mundo
##    abajo de los pies a todos los demás (se los llevaba puestos a la cueva).
##
## Para que dos niveles convivan en el MISMO mundo físico sin tocarse, cada
## uno se instancia DESPLAZADO (ver desplazamiento_de_nivel): la Pradera en
## x=0, la Cueva en x=100000. Así nunca se cruzan colisiones ni navegación, y
## de yapa sale gratis el filtrado de red: InteresEspacial ya sólo replica lo
## que está a menos de 1400 px de cada jugador, así que los mobs de un nivel
## dejan de viajarle a los jugadores de otro sin escribir ni un filtro nuevo.
##
## El desplazamiento TIENE que ser idéntico en servidor y cliente: las
## posiciones se replican como coordenadas absolutas.

signal nivel_cargado(nivel: NivelBase)
## Solo en el servidor: un peer confirmó (vía _marcar_listo_red) que terminó
## de cargar el nivel que le tocaba. ServidorDedicado la usa para recién
## entonces spawnear su Jugador — así el cliente carga el mapa completo ANTES
## de que exista su personaje.
signal peer_listo(peer_id: int)
## SERVIDOR: un peer dejó su nivel anterior por otro (cruzó un portal) — se
## emite ANTES de que ese nivel anterior se quede sin jugadores y
## _actualizar_actividad_niveles() le ponga PROCESS_MODE_DISABLED a todo su
## subárbol. Cualquier cosa "atada" a ese jugador en concreto que viva
## colgada del nivel viejo (por ejemplo un AliadoInvocado) tiene que
## reaccionar acá — una vez desactivado el subárbol, su propio
## _physics_process deja de correr y ya no puede notar el cambio solo.
signal jugador_cambio_de_nivel(peer_id: int)

## Segundos tras cambiar de nivel en los que se ignoran nuevas peticiones
## (evita rebotes si el jugador aparece cerca de un portal).
const GRACIA_TRAS_CARGA := 1.0
## Duración de cada mitad del fundido (a negro / desde negro).
const DURACION_FUNDIDO := 0.3

## Todos los niveles del juego. El ORDEN importa: define el desplazamiento con
## el que se instancia cada uno, y tiene que ser el mismo en servidor y
## cliente. Un nivel nuevo se agrega ACÁ (y nada más).
const NIVELES := [
	"res://escenas/niveles/NivelPradera.tscn",
	"res://escenas/niveles/NivelCueva.tscn",
	"res://escenas/niveles/NivelCamino.tscn",
	"res://escenas/niveles/NivelNidoArañaReina.tscn",
	"res://escenas/niveles/NivelCiudad.tscn",
	"res://escenas/niveles/NivelSantuarioGuardian.tscn",
	"res://escenas/niveles/NivelMina.tscn",
]
## Separación entre niveles. Enorme a propósito: tiene que superar de sobra
## el tamaño de cualquier mapa y el radio de interés (1400 px), para que dos
## niveles jamás se rocen ni por física ni por réplica de red. A 100.000 px un
## float de 32 bits todavía distingue centésimas de píxel, así que no hay
## problema de precisión.
const SEPARACION_NIVELES := 100000.0

var _contenedor: Node
var _jugador: Node2D
var _cargando := false
var _gracia := 0.0
## Nivel que el servidor ordenó cargar mientras había otra carga en curso —
## se aplica apenas termina (ver _cambiar_nivel_local).
var _ruta_pendiente := ""

# ── Estado del SERVIDOR DEDICADO ──────────────────────────────────────────
var _es_servidor := false
var _ruta_inicial := ""
## peer_id -> ruta del nivel donde está ese jugador.
var _nivel_por_peer: Dictionary = {}
## peer_id -> número de la última orden de nivel que se le mandó. El cliente
## lo devuelve al confirmar, así se distingue la confirmación de ESTA orden de
## la de una anterior (si cruzó dos portales seguidos, por ejemplo).
var _generacion_por_peer: Dictionary = {}
## peer_id -> segundos de gracia que le quedan (anti-rebote, por jugador).
var _gracia_por_peer: Dictionary = {}
## Peers que ya confirmaron tener cargado el nivel que les tocó.
var _peers_listos: Array[int] = []

# ── Estado del CLIENTE ────────────────────────────────────────────────────
## La generación que mandó el SERVIDOR con la orden de nivel que este cliente
## está cargando. Se le devuelve tal cual al confirmar.
##
## OJO, acá hubo una trampa que costó encontrar: antes el cliente confirmaba
## con un contador SUYO. Coincidía de casualidad mientras cliente y servidor
## cargaran la misma cantidad de veces, pero un cliente que entraba con el
## servidor ya en otro nivel confirmaba su carga nº1 contra un servidor que
## iba por la nº2: el servidor la descartaba por "vieja" y ese jugador quedaba
## para siempre fuera de la lista de listos — sin réplica de mobs, sin réplica
## de su propia posición, y con su personaje apareciendo sólo gracias al
## temporizador de respaldo.
var _generacion_servidor: int = 0

## Overlay de fundido autoconstruido: así el gestor no depende de que
## Mundo.tscn tenga un nodo concreto, y funciona igual desde cualquier
## escena que registre un contenedor.
var _velo: ColorRect


func _ready() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 100  # por encima de la UI del juego durante la transición
	_velo = ColorRect.new()
	_velo.color = Color.BLACK
	_velo.modulate.a = 0.0
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(_velo)
	add_child(capa)


func _process(delta: float) -> void:
	_gracia = maxf(0.0, _gracia - delta)
	if _gracia_por_peer.is_empty():
		return
	for peer_id in _gracia_por_peer.keys():
		var restante: float = float(_gracia_por_peer[peer_id]) - delta
		if restante <= 0.0:
			_gracia_por_peer.erase(peer_id)
		else:
			_gracia_por_peer[peer_id] = restante


## Mundo.tscn llama esto al arrancar.
func registrar(contenedor: Node, jugador: Node2D) -> void:
	_contenedor = contenedor
	_jugador = jugador


## Mundo.tscn/ServidorDedicado.tscn llaman esto al arrancar — contenedor
## FIJO, hermano de "Jugadores" y fuera de cualquier nivel (existe siempre,
## en todo cliente, sin importar qué nivel tenga cargado). Lo usan entidades
## no-jugador que igual necesitan moverse "entre niveles" replicándose bien
## a todos los clientes (el leñador, ver GestorLenador.gd/Lenador.gd): un
## jugador NUNCA se reparenta entre niveles al cruzar un portal (cuelga de
## "Jugadores" siempre, ver mapa_navegacion_de) — solo se le cambia
## global_position, así su ruta en el árbol nunca cambia y las RPC dirigidas
## a él siguen resolviendo en cualquier cliente, esté donde esté. Mismo
## criterio acá: reparentar entre los NPCs de cada nivel rompía las RPC de
## réplica en cualquier cliente que no tuviera ESE nivel cargado en ese
## momento (bug real reportado: "el leñador no se mueve").
var _contenedor_errantes: Node2D


func registrar_errantes(contenedor: Node2D) -> void:
	_contenedor_errantes = contenedor


func contenedor_errantes() -> Node2D:
	return _contenedor_errantes


## Dónde se instancia cada nivel. Los desconocidos van al origen: un nivel
## suelto (una prueba, algo a medio hacer) sigue funcionando como siempre.
func desplazamiento_de_nivel(ruta: String) -> Vector2:
	var indice := NIVELES.find(ruta)
	if indice <= 0:
		return Vector2.ZERO
	return Vector2(indice * SEPARACION_NIVELES, 0.0)


## El nivel del contenedor. En el cliente y en un jugador hay uno solo, así
## que esto es "el" nivel. En el SERVIDOR hay varios: ahí no sirve para
## decidir nada de un jugador concreto — usar nivel_de_peer/nivel_de_jugador.
func nivel_actual() -> NivelBase:
	if _contenedor == null:
		return null
	for hijo in _contenedor.get_children():
		if hijo is NivelBase:
			return hijo as NivelBase
	return null


func _nivel_por_ruta(ruta: String) -> NivelBase:
	if _contenedor == null:
		return null
	for hijo in _contenedor.get_children():
		if hijo is NivelBase and (hijo as NivelBase).scene_file_path == ruta:
			return hijo as NivelBase
	return null


# =============================================================================
# CLIENTE / UN JUGADOR — un nivel a la vez, se reemplaza
# =============================================================================

## Cambio de nivel del mundo entero. Sólo tiene sentido FUERA de la red (un
## jugador, pruebas): en red el servidor mueve jugador por jugador (ver
## mover_peer_a_nivel) y el cliente se limita a obedecer.
func cambiar_nivel(ruta_escena: String) -> void:
	if Utils.en_red():
		return
	_cambiar_nivel_local(ruta_escena)


## El cambio real. Devuelve false si se descartó (ya había una carga en curso,
## o cayó dentro de la ventana de gracia anti-rebote).
## forzar = orden del servidor: no se le aplica la gracia (el servidor ya la
## aplicó de su lado) y, si justo hay otra carga en curso, queda pendiente en
## vez de perderse — perderla dejaría a este cliente en otro nivel que el
## servidor, que es exactamente lo que hay que evitar.
func _cambiar_nivel_local(ruta_escena: String, forzar: bool = false) -> bool:
	if _cargando:
		if forzar:
			_ruta_pendiente = ruta_escena
		return false
	if not forzar and _gracia > 0.0:
		return false
	if _contenedor == null:
		push_error("GestorNiveles: nadie llamó a registrar(); no hay contenedor.")
		return false
	_cargando = true
	_cargar.call_deferred(ruta_escena)
	return true


func _cargar(ruta_escena: String) -> void:
	# Capturado ANTES de liberar el nivel viejo (unas líneas más abajo) —
	# _colocar_jugador_local() lo necesita para aparecer junto al portal de
	# regreso correspondiente, no siempre en el mismo PuntoAparicion fijo
	# (ver ese comentario).
	var nivel_anterior := nivel_actual()
	var ruta_origen := nivel_anterior.scene_file_path if nivel_anterior != null else ""

	var escena := await _cargar_escena_con_progreso(ruta_escena)
	if escena == null:
		push_error("GestorNiveles: no se pudo cargar '%s'." % ruta_escena)
		_cargando = false
		return

	# Fundido a negro: el intercambio de escena ocurre con la pantalla
	# tapada, así que el "pop" de instanciar/reposicionar nunca se ve.
	await _fundir(1.0)

	# Recoge cualquier proyectil/número de daño que siguiera "en vuelo" del
	# nivel anterior: viven en la piscina (fuera del árbol del nivel, ver
	# GestorPiscinas) precisamente para sobrevivir a este cambio, pero no
	# tiene sentido que sigan animándose sobre un nivel que ya no existe.
	GestorPiscinas.liberar_todos_los_activos()

	for hijo in _contenedor.get_children():
		hijo.free()

	# instantiate() + add_child() arman el árbol completo del nivel (terreno,
	# enemigos, portales, y el _ready() de NivelBase que despeja el terreno):
	# el segundo paso más caro del arranque, y sin ninguna API de porcentaje
	# — se informa como hito, entrando a la etapa antes y cerrándola después.
	GestorCarga.avanzar(&"mundo", 0.0)
	var nivel := escena.instantiate()
	if nivel is Node2D:
		(nivel as Node2D).position = desplazamiento_de_nivel(ruta_escena)
	_contenedor.add_child(nivel)
	GestorCarga.completar(&"mundo")

	if nivel is NivelBase:
		_colocar_jugador_local(nivel as NivelBase, ruta_origen)

	_gracia = GRACIA_TRAS_CARGA
	_cargando = false
	if nivel is NivelBase:
		nivel_cargado.emit(nivel)
		print("Nivel cargado: %s" % (nivel as NivelBase).nombre_nivel)
		if Utils.en_red() and not multiplayer.is_server():
			# Se devuelve la generación que mandó el SERVIDOR, no una local
			# (ver _generacion_servidor para por qué eso estaba mal).
			rpc_id(1, "_marcar_listo_red", _generacion_servidor)

	await _fundir(0.0)

	# Orden del servidor que llegó con esta carga en curso: recién ahora se
	# puede atender. Sin esto quedaría ignorada y este cliente se quedaría en
	# un nivel distinto al que el servidor cree que está.
	if _ruta_pendiente != "":
		var pendiente := _ruta_pendiente
		_ruta_pendiente = ""
		_cambiar_nivel_local(pendiente, true)


## Sólo el jugador LOCAL: en el cliente, las réplicas de los otros jugadores
## las coloca la red (y encima pueden estar en otro nivel), y en el servidor
## este camino no se usa para nada.
## ruta_origen: nivel del que viene (si cruzó un portal) — ver
## _punto_de_llegada() para cómo se usa.
func _colocar_jugador_local(nivel: NivelBase, ruta_origen: String = "") -> void:
	if _jugador == null:
		return
	var punto = _punto_de_llegada(nivel, ruta_origen)
	if punto != null:
		_jugador.global_position = punto
		if _jugador is CharacterBody2D:
			(_jugador as CharacterBody2D).velocity = Vector2.ZERO
		# Lo que se REPLICA es esta variable, no global_position (ver
		# Jugador._physics_process): sin ponerla acá, el cuerpo ya movido
		# seguiría anunciando la posición vieja durante un fotograma.
		if "_posicion_replicada" in _jugador:
			_jugador.set("_posicion_replicada", punto)
	# Mientras dura el fundido (y un poco más) el jugador copia la posición
	# del servidor sin suavizar: el servidor sigue moviendo el cuerpo con la
	# última dirección de joystick mientras este cliente carga, así que al
	# levantarse la pantalla había decenas de píxeles de diferencia y se veía
	# al personaje deslizarse solo hasta su lugar (reportado: "sale unos 70 px
	# a la derecha y después corrige su posición").
	if _jugador.has_method(&"sincronizar_posicion_dura"):
		_jugador.call(&"sincronizar_posicion_dura", DURACION_FUNDIDO * 2.0 + 0.2)
	# Quieto, sin habilidades e invulnerable mientras aterriza en el mapa
	# nuevo (ver Jugador.bloquear_por_transicion).
	if _jugador.has_method(&"bloquear_por_transicion"):
		_jugador.call(&"bloquear_por_transicion")
	if _jugador.has_method(&"aplicar_limites_camara"):
		_jugador.call(&"aplicar_limites_camara", nivel.limites_camara())
	if _jugador.has_method(&"resetear_camara"):
		_jugador.call(&"resetear_camara")


## En red, el jugador propio recién existe DESPUÉS de conectar (ver Mundo.gd)
## — el nivel ya está cargado para entonces, así que hay que reposicionarlo
## "a mano" en vez de esperar al próximo cambio de nivel.
func asignar_jugador(jugador: Node2D) -> void:
	_jugador = jugador
	var nivel := nivel_actual()
	if jugador == null or nivel == null:
		return
	_colocar_jugador_local(nivel)


# =============================================================================
# SERVIDOR DEDICADO — N niveles a la vez, un nivel por jugador
# =============================================================================

## Lo llama ServidorDedicado al arrancar, en vez de cambiar_nivel(): marca el
## modo servidor y deja cargado el nivel donde entra todo el mundo.
func preparar_servidor(ruta_inicial: String) -> void:
	_es_servidor = true
	_ruta_inicial = ruta_inicial
	var nivel := _asegurar_nivel_cargado(ruta_inicial)
	if nivel != null:
		nivel_cargado.emit(nivel)


## Deja el nivel cargado si todavía no lo estaba y lo devuelve. A diferencia
## del camino del cliente, acá NO se libera nada: los niveles se acumulan,
## porque cada uno puede tener jugadores adentro.
##
## Carga sincrónica siempre: en el servidor no hay barra de progreso que
## animar, y la carga en hilo directamente cuelga el proceso con un solo
## núcleo (ver _conviene_carga_sincronica).
func _asegurar_nivel_cargado(ruta: String) -> NivelBase:
	if _contenedor == null:
		push_error("GestorNiveles: nadie llamó a registrar(); no hay contenedor.")
		return null
	var ya := _nivel_por_ruta(ruta)
	if ya != null:
		return ya
	var escena := load(ruta) as PackedScene
	if escena == null:
		push_error("GestorNiveles: no se pudo cargar '%s'." % ruta)
		return null
	var nivel := escena.instantiate()
	if nivel is Node2D:
		(nivel as Node2D).position = desplazamiento_de_nivel(ruta)
	_contenedor.add_child(nivel)
	if nivel is NivelBase:
		print("Nivel cargado: %s" % (nivel as NivelBase).nombre_nivel)
		return nivel as NivelBase
	return null


## SERVIDOR: fuerza que un nivel esté cargado aunque todavía no lo haya
## pisado ningún jugador — lo necesitan entidades que viven cruzando
## niveles por su cuenta (el leñador, ver Lenador.gd/GestorLenador.gd), que
## sin esto no encontrarían su nivel "de destino" instanciado hasta que un
## jugador lo visitara primero por casualidad.
func asegurar_nivel_cargado_servidor(ruta: String) -> NivelBase:
	if not _es_servidor:
		return null
	return _asegurar_nivel_cargado(ruta)


## El nivel donde está ese jugador. Si no se sabe (todavía no se le asignó
## ninguno), cae al nivel inicial.
func nivel_de_peer(peer_id: int) -> NivelBase:
	var ruta: String = _nivel_por_peer.get(peer_id, "")
	if ruta == "":
		return nivel_actual()
	var nivel := _nivel_por_ruta(ruta)
	if nivel == null:
		return nivel_actual()
	return nivel


func ruta_de_peer(peer_id: int) -> String:
	return _nivel_por_peer.get(peer_id, _ruta_inicial)


## El nivel de un Jugador concreto. Fuera del servidor hay uno solo, así que
## devuelve ese. El nombre del nodo Jugador ES el peer id (ver Jugador.gd).
func nivel_de_jugador(jugador: Node) -> NivelBase:
	if not _es_servidor or jugador == null:
		return nivel_actual()
	var nombre := String(jugador.name)
	if not nombre.is_valid_int():
		return nivel_actual()
	return nivel_de_peer(int(nombre))


## SERVIDOR: manda a un jugador a otro nivel. Es el único camino por el que
## se viaja en red — y mueve SÓLO a ese jugador, que es la razón de ser de
## todo este archivo.
func mover_peer_a_nivel(peer_id: int, ruta: String) -> void:
	if not _es_servidor:
		return
	if not NIVELES.has(ruta):
		push_warning("GestorNiveles: nivel desconocido '%s'." % ruta)
		return
	# Anti-rebote por jugador, y nada que hacer si ya está en ese nivel.
	if _gracia_por_peer.has(peer_id):
		return
	if _nivel_por_peer.get(peer_id, "") == ruta:
		return
	var nivel := _asegurar_nivel_cargado(ruta)
	if nivel == null:
		return
	# Capturado ANTES de pisar _nivel_por_peer[peer_id] con el destino — ver
	# _punto_de_llegada() para cómo se usa (aparecer junto al portal de
	# regreso correspondiente, no siempre en el mismo PuntoAparicion fijo).
	var ruta_origen: String = _nivel_por_peer.get(peer_id, "")
	jugador_cambio_de_nivel.emit(peer_id)
	_nivel_por_peer[peer_id] = ruta
	_gracia_por_peer[peer_id] = GRACIA_TRAS_CARGA
	_colocar_peer_en_aparicion(peer_id, nivel, null, ruta_origen)
	_ordenar_nivel_a_peer(peer_id, ruta)
	# El nivel que deja puede quedar vacío y el nuevo tiene que despertar.
	_actualizar_actividad_niveles()


## SERVIDOR: coloca a un jugador recién creado en el punto de aparición del
## nivel que le toca (el suyo, no "el del mundo").
func colocar_jugador_nuevo(peer_id: int, jugador: Node2D) -> void:
	if not _es_servidor:
		return
	var ruta := ruta_de_peer(peer_id)
	_nivel_por_peer[peer_id] = ruta
	var nivel := _asegurar_nivel_cargado(ruta)
	if nivel == null:
		return
	_colocar_peer_en_aparicion(peer_id, nivel, jugador)
	_actualizar_actividad_niveles()


## ruta_origen: nivel del que viene (si cruzó un portal, ver
## mover_peer_a_nivel) — cadena vacía para un jugador recién conectado
## (colocar_jugador_nuevo), que no viene de ningún lado en particular.
func _colocar_peer_en_aparicion(peer_id: int, nivel: NivelBase, jugador: Node2D = null, ruta_origen: String = "") -> void:
	var cuerpo := jugador
	if cuerpo == null:
		cuerpo = InteresEspacial.jugador_de_peer(peer_id)
	if cuerpo == null:
		return
	var punto = _punto_de_llegada(nivel, ruta_origen)
	if punto == null:
		return
	cuerpo.global_position = punto
	if cuerpo is CharacterBody2D:
		(cuerpo as CharacterBody2D).velocity = Vector2.ZERO
	if "_posicion_replicada" in cuerpo:
		cuerpo.set("_posicion_replicada", punto)
	_bloquear_por_transicion(cuerpo)


## Dónde aparece un jugador al entrar a "nivel". Pedido del usuario: si
## cruzó un portal de verdad (ruta_origen no vacía) Y ese nivel tiene un
## PortalNivel que lleva DE VUELTA a ruta_origen, aparece en el
## PortalNivel.punto_llegada de ESE portal (el mismo por el que "saldría"
## si quisiera volver) — un Marker2D hijo del portal, elegido a mano en el
## editor para cada uno ("con eso se establece bien una buena posición de
## respawn": ver el comentario en PortalNivel.gd, reemplaza la versión
## anterior que dispersaba a un ángulo al azar, que podía caer hacia
## terreno no despejado). Sin portal de regreso identificable (llegada
## nueva al conectarse, o un nivel sin ese portal) cae al PuntoAparicion
## fijo de siempre — mismo comportamiento que antes.
func _punto_de_llegada(nivel: NivelBase, ruta_origen: String):
	if ruta_origen != "":
		var portal := _portal_de_regreso(nivel, ruta_origen)
		if portal != null and portal.punto_llegada != null:
			return portal.punto_llegada.global_position
	var punto_fijo := nivel.punto_aparicion()
	return punto_fijo.global_position if punto_fijo != null else null


## El PortalNivel de "nivel" cuya ruta_nivel_destino apunta de vuelta a
## ruta_origen — "el mismo círculo del tp correspondiente" que el jugador
## usaría para volver por donde vino.
func _portal_de_regreso(nivel: NivelBase, ruta_origen: String) -> PortalNivel:
	for portal in get_tree().get_nodes_in_group(&"portales_nivel"):
		if portal is PortalNivel and nivel.is_ancestor_of(portal) \
				and (portal as PortalNivel).ruta_nivel_destino == ruta_origen:
			return portal
	return null


func _bloquear_por_transicion(cuerpo: Node) -> void:
	# El servidor es la autoridad del movimiento y del daño: acá es donde el
	# bloqueo y la invulnerabilidad de llegada valen de verdad (el cliente
	# aplica el suyo al terminar de cargar, ver _colocar_jugador_local).
	# Además ataja de raíz el deslizamiento que se veía al llegar: sin esto
	# el servidor seguía caminando con la última dirección de joystick
	# mientras el cliente todavía fundía.
	if cuerpo.has_method(&"bloquear_por_transicion"):
		cuerpo.call(&"bloquear_por_transicion")


## SERVIDOR: le dice a un peer qué nivel tiene que tener cargado, y lo saca de
## la lista de listos hasta que confirme el nuevo.
func _ordenar_nivel_a_peer(peer_id: int, ruta: String) -> void:
	_peers_listos.erase(peer_id)
	var generacion: int = int(_generacion_por_peer.get(peer_id, 0)) + 1
	_generacion_por_peer[peer_id] = generacion
	# Sin red no hay a quién avisarle (pruebas headless del lado servidor):
	# rpc_id() sin peer real sólo ensuciaría con errores.
	if Utils.en_red():
		rpc_id(peer_id, "_recibir_cambio_nivel_red", ruta, generacion)


## SERVIDOR: se fue un jugador, olvidarlo todo. Sin esto sus entradas se
## acumulan para siempre y, peor, un peer id reciclado heredaría el nivel del
## anterior.
func olvidar_peer(peer_id: int) -> void:
	_nivel_por_peer.erase(peer_id)
	_generacion_por_peer.erase(peer_id)
	_gracia_por_peer.erase(peer_id)
	_peers_listos.erase(peer_id)
	# Si era el último de su nivel, ese nivel se duerme.
	_actualizar_actividad_niveles()


## nodo -> ruta del nivel donde está AHORA — mismo rol que _nivel_por_peer,
## pero para entidades no-jugador que tampoco viven dentro de un NivelBase
## (cuelgan de contenedor_errantes(), ver registrar_errantes): el leñador es
## la primera (ver Lenador.gd), pero cualquier NPC futuro que necesite
## "moverse entre niveles" sin reparentarse puede reusar esto.
var _nivel_por_entidad: Dictionary = {}


func fijar_nivel_de_entidad(nodo: Node, ruta: String) -> void:
	_nivel_por_entidad[nodo] = ruta


## El mapa de navegación que le corresponde a un nodo cualquiera.
##
## Cada nivel tiene el SUYO (ver NivelBase._crear_mapa_navegacion): con varios
## niveles cargados a la vez y separados 100.000 px, usar el mapa compartido
## del mundo hacía que un mob de un nivel sin malla propia rutease hacia la
## malla del otro nivel y se fuera caminando para allá.
##
## Los mobs viven DENTRO del nivel, así que se resuelve subiendo por el árbol.
## Los jugadores no (cuelgan de "Jugadores", fuera de los niveles), así que
## para ellos se pregunta en qué nivel están; las entidades errantes
## registradas en _nivel_por_entidad, lo mismo. Si no se puede determinar, se
## cae al mapa del mundo: es lo que había antes y nunca es peor.
func mapa_navegacion_de(nodo: Node) -> RID:
	if nodo == null or not nodo.is_inside_tree():
		return RID()
	var arriba: Node = nodo
	while arriba != null:
		if arriba is NivelBase:
			return (arriba as NivelBase).mapa_navegacion()
		arriba = arriba.get_parent()
	if nodo.is_in_group(&"jugadores"):
		var nivel := nivel_de_jugador(nodo)
		if nivel != null:
			return nivel.mapa_navegacion()
	if _nivel_por_entidad.has(nodo):
		var nivel_errante := _nivel_por_ruta(_nivel_por_entidad[nodo])
		if nivel_errante != null:
			return nivel_errante.mapa_navegacion()
	var nivel_puesto := nivel_actual()
	if nivel_puesto != null:
		return nivel_puesto.mapa_navegacion()
	return nodo.get_viewport().world_2d.navigation_map


## Apaga el procesamiento de los niveles SIN jugadores y lo enciende en los que
## sí tienen. Los niveles se quedan cargados (volver a instanciarlos en cada
## viaje sería peor), pero un nivel vacío no tiene por qué seguir pensando.
##
## Sin esto, el servidor seguía simulando la IA de TODOS los mobs de TODOS los
## niveles que alguien hubiera visitado alguna vez: con el Camino (90 mobs)
## medía 62-72% de CPU con NADIE conectado, y el contenedor tiene un solo
## núcleo. Apagando los vacíos, ese costo desaparece hasta que alguien entre.
##
## PROCESS_MODE_DISABLED corta _process y _physics_process de todo el subárbol
## (mobs, árboles de comportamiento, generadores, portales) sin sacar nada de
## la escena: la colisión y la malla de navegación siguen ahí, y al reactivarlo
## todo sigue donde estaba.
## Rutas que se mantienen activas SIEMPRE, tengan o no jugadores — pedido
## explícito del usuario ("dejar activo ambos mapa a la vez") para que
## Ciudad y Pradera nunca se congelen mientras el leñador (o cualquier otra
## simulación de fondo) las necesite funcionando.
var _rutas_siempre_activas: Array[String] = []


func mantener_siempre_activo(ruta: String) -> void:
	if not _rutas_siempre_activas.has(ruta):
		_rutas_siempre_activas.append(ruta)


func _actualizar_actividad_niveles() -> void:
	if not _es_servidor or _contenedor == null:
		return
	for hijo in _contenedor.get_children():
		if not (hijo is NivelBase):
			continue
		var nivel := hijo as NivelBase
		var hay_jugadores := hay_jugadores_en(nivel)
		var siempre_activo := _rutas_siempre_activas.has(nivel.scene_file_path)
		var modo := Node.PROCESS_MODE_INHERIT if (hay_jugadores or siempre_activo) else Node.PROCESS_MODE_DISABLED
		if nivel.process_mode != modo:
			nivel.process_mode = modo
		# Un nivel "siempre activo" (Pradera/Ciudad/Mina, por los NPCs
		# errantes que necesitan su terreno/portales funcionando — ver
		# mantener_siempre_activo()) no tiene por qué mantener a TODOS sus
		# mobs hostiles pensando sin nadie mirando: eso es la mayor parte del
		# costo real (medido en la VM de producción: ~200ms de física por
		# fotograma con 0 jugadores conectados, contra un presupuesto de
		# ~16ms). El terreno/navegación/portales del nivel siguen activos
		# arriba (siempre_activo los deja en INHERIT); acá se apaga aparte
		# solo "Enemigos" (IA + física de lobos/arañas/jefes, ver
		# NivelBase.contenedor_enemigos) cuando no hay jugadores, sin tocar
		# nada de lo que el leñador/cazador/minero necesitan.
		if siempre_activo:
			var enemigos := nivel.contenedor_enemigos()
			if enemigos:
				var modo_enemigos := Node.PROCESS_MODE_INHERIT if hay_jugadores else Node.PROCESS_MODE_DISABLED
				if enemigos.process_mode != modo_enemigos:
					enemigos.process_mode = modo_enemigos


## true si hay al menos un jugador dentro de ese nivel. Lo usa SpawnerMobs
## para no generar mobs en niveles vacíos.
func hay_jugadores_en(nivel: NivelBase) -> bool:
	# Fuera del servidor dedicado (un jugador, pruebas sueltas) o si no se
	# sabe de qué nivel se trata, no se bloquea nada: vale el comportamiento
	# de siempre. Sólo el servidor, que es el único con varios niveles a la
	# vez, deja de poblar los que están vacíos.
	if not _es_servidor or nivel == null:
		return true
	var ruta := nivel.scene_file_path
	for peer_id in _nivel_por_peer:
		if _nivel_por_peer[peer_id] == ruta:
			return true
	return false


## true si ese peer YA confirmó tener cargado el nivel que le tocó. Lo usa
## InteresEspacial para no mandarle estado de mobs a quien todavía está
## cargando: esos RPCs apuntan a nodos que en su árbol no existen todavía y el
## motor los rechaza uno por uno con "Invalid packet received. Requested node
## was not found" — eran miles de líneas de error por cada cambio de nivel, y
## peor cuanto más tarda en cargar el aparato (un celular tarda mucho más que
## un PC).
func peer_listo_para_nivel_actual(peer_id: int) -> bool:
	return _peers_listos.has(peer_id)


# =============================================================================
# RED
# =============================================================================

## Orden del servidor: este cliente carga el nivel que le digan, sin discutir.
@rpc("authority", "reliable")
func _recibir_cambio_nivel_red(ruta_escena: String, generacion: int) -> void:
	if multiplayer.is_server():
		return
	_generacion_servidor = generacion
	_cambiar_nivel_local(ruta_escena, true)


## Un cliente recién conectado pregunta qué nivel le toca cargar. Antes
## cargaba SIEMPRE nivel_inicial a ciegas (ver Mundo._al_conectar_ok): si el
## servidor no estaba en ese nivel, ese cliente arrancaba en un mapa distinto
## al del servidor desde el segundo cero.
@rpc("any_peer", "reliable")
func _pedir_nivel_actual_red() -> void:
	if not multiplayer.is_server():
		return
	var quien := multiplayer.get_remote_sender_id()
	var ruta := ruta_de_peer(quien)
	_nivel_por_peer[quien] = ruta
	_asegurar_nivel_cargado(ruta)
	_ordenar_nivel_a_peer(quien, ruta)
	_actualizar_actividad_niveles()


## La llama el cliente apenas se conecta, en vez de cargar nivel_inicial.
func pedir_nivel_actual_al_servidor() -> void:
	rpc_id(1, "_pedir_nivel_actual_red")


## CLIENTE: pide mudarse al nivel que traía su partida guardada (ver
## GestorGuardado._recibir_partida_red). Es un pedido, no una orden: el
## servidor valida contra NIVELES antes de moverlo.
func pedir_mudarse_a(ruta: String) -> void:
	if not Utils.en_red() or multiplayer.is_server():
		return
	rpc_id(1, "_pedir_mudarse_red", ruta)


@rpc("any_peer", "reliable")
func _pedir_mudarse_red(ruta: String) -> void:
	if not multiplayer.is_server():
		return
	if not NIVELES.has(ruta):
		return
	mover_peer_a_nivel(multiplayer.get_remote_sender_id(), ruta)


## El cliente avisa acá que ya terminó de cargar el nivel que le ordenaron.
## reliable: es un aviso puntual (no un flujo continuo), no puede perderse.
@rpc("any_peer", "reliable")
func _marcar_listo_red(generacion: int) -> void:
	if not multiplayer.is_server():
		return
	var quien := multiplayer.get_remote_sender_id()
	if generacion != int(_generacion_por_peer.get(quien, 0)):
		return  # Confirmación de una orden vieja — ya se le mandó otra.
	if not _peers_listos.has(quien):
		_peers_listos.append(quien)
		peer_listo.emit(quien)


# =============================================================================
# CARGA
# =============================================================================

## Carga el PackedScene del nivel EN UN HILO APARTE, reportando el progreso
## real a GestorCarga mientras tanto. Antes era un load() sincrónico: la
## etapa más cara de todo el arranque (NivelPradera.tscn pesa ~660 KB) y la
## única con un porcentaje genuino disponible — con load() el juego se
## congelaba sin poder informar nada, que es justo lo que la pantalla de
## carga tiene que evitar.
##
## Respaldo a load() sincrónico si la carga en hilo no se puede iniciar o
## falla: mejor un tirón que no cargar el nivel.
func _cargar_escena_con_progreso(ruta_escena: String) -> PackedScene:
	if _conviene_carga_sincronica():
		GestorCarga.completar(&"nivel")
		return load(ruta_escena) as PackedScene
	if ResourceLoader.load_threaded_request(ruta_escena) != OK:
		return load(ruta_escena) as PackedScene
	var progreso: Array = []
	while true:
		var estado := ResourceLoader.load_threaded_get_status(ruta_escena, progreso)
		match estado:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if not progreso.is_empty():
					GestorCarga.avanzar(&"nivel", float(progreso[0]))
				await get_tree().process_frame
			ResourceLoader.THREAD_LOAD_LOADED:
				GestorCarga.completar(&"nivel")
				return ResourceLoader.load_threaded_get(ruta_escena) as PackedScene
			_:
				# THREAD_LOAD_FAILED / INVALID_RESOURCE: que decida load().
				return load(ruta_escena) as PackedScene
	return null


## La carga EN HILO existe sólo para que la barra de progreso del cliente siga
## viva mientras carga (ver GestorCarga). Donde no hay barra que animar no
## aporta nada — y con un solo núcleo directamente CUELGA EL PROCESO.
##
## El contenedor del servidor corre con UN núcleo (`nproc` = 1, confirmado
## adentro). Con uno solo, el WorkerThreadPool de Godot se queda sin hilo
## donde correr la tarea de carga y load_threaded_get() bloquea el hilo
## PRINCIPAL esperando algo que nadie va a ejecutar: el proceso queda vivo
## pero con el bucle principal detenido (0% de CPU, deja de responderle a
## todo el mundo) y no se recupera solo — hay que reiniciar el servidor.
##
## Así se rompía volver de la Cueva: NivelPradera.tscn es la escena más
## pesada del juego y al recargarla el servidor se congelaba a mitad de
## camino. Desde afuera se veía exactamente como lo reportó el usuario: "al
## salir de la cueva se buguea, se pierde la conexión con el servidor y no me
## puedo mover", sin arreglo hasta reiniciar el servidor.
##
## Se cubre también el cliente de un solo núcleo (celulares viejos), que
## tendría el mismo problema: mejor un tirón corto que un cuelgue eterno.
func _conviene_carga_sincronica() -> bool:
	if OS.get_processor_count() <= 1:
		return true
	return Utils.en_red() and multiplayer.is_server()


## Anima el velo negro hacia la opacidad objetivo (1.0 = tapado, 0.0 = visible).
func _fundir(alfa_objetivo: float) -> void:
	var tween := create_tween()
	tween.tween_property(_velo, "modulate:a", alfa_objetivo, DURACION_FUNDIDO)
	await tween.finished
