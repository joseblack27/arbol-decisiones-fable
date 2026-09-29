## Jugador.gd
## Controlador principal del jugador: orquesta el flujo de datos y eventos entre
## sus componentes. Los que están en Jugador.tscn se referencian desde el
## Inspector; tres más los crea _ready() por código, en todos los peers:
##   DestrabeJugador: la red de seguridad contra quedar trabado en paredes.
##   IconosEstadoJugador: la fila de íconos de estado sobre la cabeza.
##   IdentidadJugador: id_unico, nombre, cuenta con PIN y expulsión del fantasma.
## Acá quedan el movimiento en red (input del dueño, predicción y
## reconciliación, réplica de posición), la muerte/reaparición y la activación
## de habilidades, que comparten el mismo estado (direccion, _muerto, bloqueos).

extends CharacterBody2D

const _DestrabeJugador := preload("res://escenas/jugador/DestrabeJugador.gd")
const _IconosEstadoJugador := preload("res://escenas/jugador/IconosEstadoJugador.gd")
const _IdentidadJugador := preload("res://escenas/jugador/IdentidadJugador.gd")

# --- Referencias de componentes (se asignan en el Inspector) ---
@export var componente_vida: VidaComponente # Componente de vida.
@export var componente_movimiento: MovimientoComponente # Componente de movimiento.

# --- Variables de estado ---
var componentes_de_acciones: Dictionary = {}
var _vida_anterior: float = 0.0
var direccion: Vector2
## Dirección de la última habilidad direccional lanzada: tiene prioridad sobre
## la de movimiento para orientar el sprite (lanzar hacia un lado gira al
## personaje aunque siga caminando hacia otro). Pulso de un fotograma: lo
## consume _aplicar_presentacion, y lo que persiste es _ultima_direccion.
var direccion_mirada: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var slot_habilidades: SlotHabilidades = $SlotHabilidades
@onready var camara: Camera2D = $Camara
@onready var componente_atributos: AtributosComponente = $AtributosComponente
@onready var componente_animacion: AnimacionComponente = $AnimacionComponente
@onready var componente_energia: EnergiaComponente = $EnergiaComponente
@onready var _etiqueta_nombre: Label = $EtiquetaNombre

var _destrabe: Node
var _identidad: Node

var _ultima_direccion: Vector2 = Vector2.RIGHT
## Posición del fotograma anterior — SOLO para inferir "caminando" en la
## réplica de OTRO jugador en mi pantalla (ver _physics_process), donde no
## hay velocity local propio para consultar. Mismo criterio que Enemigo.gd.
var _posicion_render_anterior: Vector2 = Vector2.ZERO
## Desplazamiento mínimo por fotograma físico para considerarse "caminando"
## en esa réplica (mismo valor que Enemigo.gd).
const _UMBRAL_CAMINANDO_RED := 0.1

# ── Muerte / reaparición ─────────────────────────────────────────────────────
## Segundos entre morir y reaparecer en el punto de aparición del nivel.
const TIEMPO_REAPARICION := 5.0
## Invulnerabilidad al APARECER (conectarse, cambiar de nivel, reaparecer).
## El cuerpo ya es atacable en el servidor mientras el cliente todavía carga
## el nivel y funde desde negro; esto cubre esa ventana con margen (el fundido
## de GestorNiveles dura 0.3 s por lado, más lo que tarde el celular).
const TIEMPO_INVULNERABILIDAD_APARICION := 3.0
## Invulnerabilidad al REVIVIR: más larga que la de aparición, porque se revive
## donde pueden seguir los mobs que lo mataron. Mientras dura, ningún mob puede
## tomarlo de objetivo (ver VisionComponente._intentar_registrar).
const TIEMPO_INVULNERABILIDAD_REVIVIR := 5.0
var _muerto := false
## Colisiones originales, para restaurarlas al revivir (se apagan al morir
## para que los mobs pierdan al "cadáver" — su visión y sus golpes son
## físicos, así que sin colisión dejan de detectarlo y atacarlo solos).
var _capa_colision_original: int = 0
var _mascara_colision_original: int = 0

## En red real (ENet, no el OfflineMultiplayerPeer por defecto; ver
## Utils.en_red()) el nombre del nodo ES el peer id dueño, que asigna quien lo
## spawnea. Sin red (un jugador, y todas las pruebas) queda en -1.
var peer_id_dueño: int = -1

## Nombre para mostrar en logs/UI (en red, el nombre de nodo es el peer id). El
## dueño lo manda al servidor al aparecer (_registrar_identidad_red) y de ahí
## se replica por el MultiplayerSynchronizer. Leerlo con
## Utils.nombre_visible(nodo), que cae al nombre de nodo si está vacío. Puede
## repetirse entre jugadores: es solo estético.
##
## El setter mantiene sincronizado el cartel "EtiquetaNombre". La replicación
## puede llegar antes de que el @onready exista; para ese caso, _ready() vuelve
## a copiar el valor.
var nombre_visible: String = "":
	set(valor):
		nombre_visible = valor
		if is_instance_valid(_etiqueta_nombre):
			_etiqueta_nombre.text = valor

## Identidad ÚNICA y persistente del dueño (Utils.id_jugador_local, un UUID
## guardado en su disco, o la de su cuenta si entra con PIN). El servidor la
## usa como clave de la partida (ver GestorGuardado); nombre_visible NUNCA
## sirve para eso, porque dos jugadores pueden llamarse igual. No se muestra ni
## se replica.
var id_unico: String = ""

## Lo que se replica no es global_position directo sino esta variable: así el
## cliente interpola hacia acá cada fotograma sin pelearse con el valor recién
## llegado. El servidor la mantiene igual a global_position (ver
## _physics_process).
var _posicion_replicada: Vector2 = Vector2.ZERO
## Qué tan rápido el cliente alcanza la posición replicada (más alto = más
## "pegado" a la red pero más notorio el salto; más bajo = más suave pero
## más "elástico"). 1/seg ≈ alcanza el 63% de la distancia cada segundo.
const VELOCIDAD_INTERPOLACION_RED := 12.0
## Por debajo de esta distancia (px) entre la predicción local y el último eco
## del servidor no se corrige nada: corregir el ruido normal de red se siente
## como vibración al moverse.
const _UMBRAL_RECONCILIACION := 4.0
## Segundos que quedan de "copiar la posición del servidor tal cual, sin
## suavizar" — ver el uso en _physics_process y sincronizar_posicion_dura().
var _sincronizacion_dura := 0.0

## Llegada a un nivel nuevo: segundos que el jugador queda quieto y sin
## habilidades (ver bloquear_por_transicion). Mismo largo que la
## invulnerabilidad que lo acompaña.
const TIEMPO_BLOQUEO_TRANSICION := 3.0
var _bloqueo_transicion := 0.0

## Movimiento en red como ESTADO de input, no como eventos: con "moverme" y
## "parate" por canales distintos, un "moverme" viejo podía llegar después del
## "parate" y dejar al cuerpo del servidor caminando solo. El cliente dueño
## manda su dirección actual con un número de secuencia (al instante si arranca
## o frena, y si no cada _FOTOGRAMAS_REENVIO_INPUT); el servidor se queda con
## la más nueva. Soltar el joystick es mandar dirección cero; si ese paquete se
## pierde, el siguiente lo corrige.
const _FOTOGRAMAS_REENVIO_INPUT := 4
var _secuencia_input := 0
var _ultima_direccion_input_enviada := Vector2.INF
var _fotogramas_desde_envio_input := 0

## SERVIDOR: la intención más nueva del cliente dueño. "direccion" (la que
## mueve el cuerpo) se recalcula cada fotograma a partir de esta, forzada a
## cero mientras haya un bloqueo — así, al terminar el bloqueo, el cuerpo
## retoma lo que el cliente está pidiendo AHORA, no un pedido viejo.
var _direccion_pedida := Vector2.ZERO
var _ultima_secuencia_input_recibida := 0
const _SALTO_SECUENCIA_REINICIO := 1000
## Sin input del dueño por este tiempo (app en segundo plano, conexión
## cortándose) el servidor lo frena en vez de dejarlo caminando.
const _SEGUNDOS_SIN_INPUT_PARA_FRENAR := 0.5
var _segundos_sin_input := 0.0


## Defensa en profundidad: aunque ahora solo el dueño local se suscribe a
## SeñalManager (ver _ready), desconectar acá evita el mismo tipo de
## referencia colgante si algún día alguien más se suscribe — SeñalManager
## no limpia solo a sus suscriptores liberados.
func _exit_tree() -> void:
	var nombres := ["joystick_movimiento"]
	for i in _total_slots_habilidad():
		nombres.append("slot_%d_activar" % i)
		nombres.append("slot_%d_lanzar" % i)
	for nombre in nombres:
		if SeñalManager.registros.has(nombre) and SeñalManager.registros[nombre].suscriptores.has(self):
			SeñalManager.desconectar(nombre, self)


func _enter_tree() -> void:
	if not Utils.en_red():
		return
	# Antes de _ready() y del primer sync del spawn: armado más tarde, a veces llega
	# tarde y se ve un "ERR_UNCONFIGURED" benigno en el primer fotograma.
	var sync := get_node_or_null("Sync") as MultiplayerSynchronizer
	if sync == null:
		return
	_posicion_replicada = global_position
	var config := SceneReplicationConfig.new()
	# _posicion_replicada NO va acá: viaja por RPC solo a los peers cercanos (ver
	# _replicar_posicion_red e InteresEspacial), igual que la de los mobs. Un
	# add_visibility_filter() sobre este Synchronizer rompía el MultiplayerSpawner
	# ("spawner is null" y desconexión de ambos peers). El Synchronizer queda para
	# lo que va a todos por igual (nombre_visible).
	config.add_property(NodePath(".:nombre_visible"))
	config.property_set_replication_mode(
		NodePath(".:nombre_visible"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
	)
	sync.replication_config = config


func _ready():
	add_to_group("jugadores")
	# Por si la replicación de nombre_visible llegó antes de que este
	# @onready se resolviera (ver el setter de nombre_visible más arriba).
	_etiqueta_nombre.text = nombre_visible
	# Capa propia (8, fijada en Jugador.tscn) con máscara solo-mundo (1):
	# los personajes NO chocan físicamente entre sí — ni jugador-jugador,
	# ni jugador-mob (los mobs viven en la capa 2 con el mismo criterio,
	# ver Enemigo.gd). El daño/detección no depende de esto: hitboxes y
	# dashes usan queries con máscara completa, y la visión de los mobs
	# usa el área VidaComponente. OJO: toda Area2D que necesite detectar
	# CUERPOS de personajes debe incluir las capas 2 y 8 en su máscara
	# (ver muro.tscn, EfectoDoT.tscn, EfectoInmovilizar.tscn).
	_capa_colision_original    = collision_layer
	_mascara_colision_original = collision_mask
	_destrabe = _agregar_componente(_DestrabeJugador, "DestrabeJugador")
	_identidad = _agregar_componente(_IdentidadJugador, "IdentidadJugador")
	if Utils.en_red():
		var nombre_str := String(name)
		peer_id_dueño = int(nombre_str) if nombre_str.is_valid_int() else -1
		# Con varios Jugador.tscn en el mismo árbol (uno por peer conectado),
		# cada uno trae su propia Camera2D — sin esto todas quedan
		# "enabled=true" y cuál gana de "current" queda a criterio del
		# motor. Solo la cámara del jugador propio debe estar activa.
		if camara:
			camara.enabled = (peer_id_dueño == multiplayer.get_unique_id())
			resetear_camara()
		# El dueño registra su nombre (para mostrar, se replica a todos; ver
		# _enter_tree) y su identidad única (solo para el servidor, nunca se
		# muestra ni se replica; ver id_unico).
		if peer_id_dueño == multiplayer.get_unique_id():
			_identidad.enviar_al_servidor()
	else:
		nombre_visible = Utils.nombre_jugador_local()
		id_unico = Utils.id_jugador_local()
		resetear_camara()
	# 1. Conectar señales de los componentes.
	if componente_vida:
		# Conectar la muerte del componente de vida.
		componente_vida.muerte.connect(self.manejar_muerte)
		componente_vida.cambio_valor_vida.connect(_on_vida_cambiada)
		componente_vida.cambio_valor_vida.connect(_on_vida_cambiada_para_grupo)
		_vida_anterior = componente_vida.obtener_vida_maxima()
		# Protección de aparición — ver TIEMPO_INVULNERABILIDAD_APARICION.
		# Se activa en TODOS los peers, no solo en el servidor: allá es lo
		# que de verdad bloquea el golpe (quitar_vida corta por acá), y en el
		# cliente es lo que dispara el destello de "estoy protegido" de
		# _actualizar_visual_invulnerable(). Ambos arrancan su cuenta al
		# aparecer el nodo, así que no hace falta replicar nada.
		componente_vida.activar_invulnerabilidad(TIEMPO_INVULNERABILIDAD_APARICION)
	
	# 2. Registrar componentes.
	componentes_de_acciones["Movimiento"] = componente_movimiento
	componentes_de_acciones["Vida"] = componente_vida
	
	# SeñalManager es un bus GLOBAL que no desconecta solo a los nodos liberados:
	# solo el jugador PROPIO se suscribe a la UI (joystick y botones de habilidad),
	# nunca las réplicas de otros jugadores (al desconectarse uno, su suscripción
	# colgada reventaba la próxima habilidad de cualquiera). El servidor dedicado
	# no tiene UI: ahí el input llega siempre por RPC.
	var soy_dueño_local := not Utils.en_red() or peer_id_dueño == multiplayer.get_unique_id()
	if soy_dueño_local and not (Utils.en_red() and multiplayer.is_server()):
		if Utils.modo_bot:
			# Modo bot (ver Utils.modo_bot): en vez de la UI real cuelga el cerebro
			# autónomo BotIA, que llama _joystick_movimiento() y _activar_slot() por su
			# cuenta, para probar el servidor con varias instancias peleando solas.
			var bot = (preload("res://escenas/jugador/BotIA.gd") as GDScript).new()
			bot.name = "BotIA"
			add_child(bot)
		else:
			SeñalManager.conectar("joystick_movimiento", self, "_joystick_movimiento")
			# Un slot_N_activar/lanzar por CADA slot posible (no solo los que se
			# ven a la vez en el HUD): PaginadorHabilidades reasigna qué slot_index
			# muestra cada botón físico según la página, así que hay que estar
			# suscripto a los 10 de entrada, aunque el HUD solo muestre 5 por vez.
			for i in _total_slots_habilidad():
				SeñalManager.conectar("slot_%d_activar" % i, self, "_on_slot_%d_activar" % i)
				SeñalManager.conectar("slot_%d_lanzar"  % i, self, "_on_slot_%d_lanzar"  % i)

	# Para CUALQUIER jugador (dueño local y réplicas): igual que el nombre de un
	# mob, es visible para cualquiera que lo mire, no solo el dueño.
	_agregar_componente(_IconosEstadoJugador, "IconosEstadoJugador")

	# Los bonos de atributos del equipo se recalculan en
	# EquipoComponente.actualizar(), no acá por BusEventos.equipo_cambiado: ese
	# bus es global y en el servidor no sabía a qué jugador recalcular.


func _agregar_componente(script: GDScript, nombre: String) -> Node:
	var componente: Node = script.new()
	componente.name = nombre
	add_child(componente)
	return componente


## Contador de bloqueos de control (ráfaga en curso, etc.): mientras sea
## > 0, el joystick NO mueve ni gira al personaje. Contador y no bool, por
## si dos efectos se solapan alguna vez (mismo patrón que
## MovimientoComponente.agregar_inmovilizacion). Ver HabilidadRafaga.
var _bloqueos_control := 0


func bloquear_control() -> void:
	_bloqueos_control += 1
	# Frenar en seco YA: si el joystick venía empujado, direccion conservaba
	# el último valor y el personaje seguía caminando "bloqueado".
	direccion = Vector2.ZERO
	# Cliente dueño: avisarle ya al servidor (sin esperar al próximo reenvío)
	# para que el cuerpo autoritativo no siga caminando mientras acá ya se ve
	# quieto — el desfase que hacía salir proyectiles desde posiciones corridas.
	if _soy_dueño_cliente_red():
		_enviar_input_red()


func desbloquear_control() -> void:
	_bloqueos_control = maxi(0, _bloqueos_control - 1)


## Contador APARTE de _bloqueos_control: bloquea SOLO el movimiento
## (_aplicar_input_servidor lo respeta, ver ahí), nunca la activación de
## habilidades (esta_bloqueado()/_activar_red NO lo consultan). Necesario
## porque HabilidadBase.activar() lo pone ANTES de que la propia habilidad
## dispare de verdad (ver _congelar_real_red) — si usara _bloqueos_control,
## el propio _activar_red de ESA misma habilidad se auto-rechazaría por
## "esta_bloqueado()" antes de llegar a disparar.
var _congelamientos_disparo := 0


func congelar_disparo_pendiente() -> void:
	_congelamientos_disparo += 1
	direccion = Vector2.ZERO


func descongelar_disparo_pendiente() -> void:
	_congelamientos_disparo = maxi(0, _congelamientos_disparo - 1)


## Rectificador del joystick: compara el estado REAL del joystick
## (Joystick.esta_presionado(), no una inferencia por falta de movimiento) con
## "direccion". Si el evento de soltar se pierde (p. ej. por un tirón de
## fotogramas en un pico de ping), lo corrige en el próximo fotograma físico.
##
## Solo donde el joystick existe: el dueño local (sin red o cliente dueño);
## nunca en el servidor dedicado ni en réplicas de otros jugadores.
var _joystick_local: Node = null

## Al servidor no hace falta avisarle nada acá: el flujo de input (ver
## _enviar_input_red) ya le lleva la dirección cero en el próximo envío.
func _verificar_joystick_soltado() -> void:
	if direccion == Vector2.ZERO:
		return
	# BotIA mueve por _joystick_movimiento() sin tocar el joystick real: sin
	# este corte el rectificador lo frenaba en cada fotograma.
	if Utils.modo_bot:
		return
	if Utils.en_red() and peer_id_dueño != multiplayer.get_unique_id():
		return
	if not is_instance_valid(_joystick_local):
		_joystick_local = null
		for hijo in get_tree().get_root().find_children("*", "", true, false):
			if hijo.has_method("esta_presionado"):
				_joystick_local = hijo
				break
	if _joystick_local == null or _joystick_local.esta_presionado():
		return
	# También velocity, no solo direccion, por si algo mueve el cuerpo antes de que
	# componente_movimiento corra este fotograma.
	velocity = Vector2.ZERO
	_joystick_movimiento(Vector2.ZERO)


func _joystick_movimiento(_direccion: Vector2):
	if _muerto:
		return
	# Soltar (dirección cero) se respeta siempre, incluso con el control
	# bloqueado: el corte es para no ARRANCAR un movimiento, y si también tragara
	# el "ya solté", direccion quedaría pegada en su último valor.
	if _bloqueos_control > 0 and _direccion != Vector2.ZERO:
		return
	# En red: el joystick es local a CADA cliente (SeñalManager es un bus
	# global, sin esto los joysticks de otros jugadores también moverían este
	# cuerpo). Solo el dueño cambia su dirección — que sirve para predecir
	# localmente y viaja al servidor por _enviar_input_red.
	if Utils.en_red() and peer_id_dueño != multiplayer.get_unique_id():
		return
	direccion = _direccion


## SERVIDOR: el dueño registra su identidad y su nombre (ver IdentidadJugador).
## "any_peer", pero solo se acepta del dueño real.
@rpc("any_peer", "reliable")
func _registrar_identidad_red(id: String, nombre: String, pin: String = "") -> void:
	if Utils.pedido_del_dueño(self):
		_identidad.registrar(id, nombre, pin)


## CLIENTE dueño: el servidor rechazó la cuenta (PIN incorrecto).
@rpc("authority", "reliable")
func _rechazar_cuenta_red(motivo: String) -> void:
	if Utils.en_red() and peer_id_dueño != multiplayer.get_unique_id():
		return
	_identidad.anotar_rechazo(motivo)


func _soy_dueño_cliente_red() -> bool:
	return Utils.en_red() and not multiplayer.is_server() \
		and peer_id_dueño == multiplayer.get_unique_id()


## CLIENTE dueño: manda la dirección actual al servidor — al instante si
## arranca o frena, cada 2 fotogramas como mucho si solo cambia de rumbo, y
## si no cada _FOTOGRAMAS_REENVIO_INPUT aunque nada cambie (así un paquete
## perdido se corrige solo en ~65 ms).
func _enviar_input_red() -> void:
	_fotogramas_desde_envio_input += 1
	var arranca_o_frena := (direccion == Vector2.ZERO) != (_ultima_direccion_input_enviada == Vector2.ZERO)
	var cambio_de_rumbo := direccion != _ultima_direccion_input_enviada and _fotogramas_desde_envio_input >= 2
	if not (arranca_o_frena or cambio_de_rumbo or _fotogramas_desde_envio_input >= _FOTOGRAMAS_REENVIO_INPUT):
		return
	_secuencia_input += 1
	_ultima_direccion_input_enviada = direccion
	_fotogramas_desde_envio_input = 0
	rpc_id(1, "_recibir_input_red", _secuencia_input, direccion)


## SERVIDOR: "any_peer" pero solo se acepta del dueño real. unreliable_ordered
## a propósito: es estado continuo, el próximo envío corrige cualquier pérdida,
## y la secuencia descarta cualquier paquete viejo que llegue tarde.
@rpc("any_peer", "unreliable_ordered")
func _recibir_input_red(secuencia: int, direccion_pedida: Vector2) -> void:
	if not Utils.pedido_del_dueño(self):
		return
	# Un salto grande hacia atrás no es un paquete viejo (esos llegan a lo sumo
	# unos pocos detrás): es el cliente que reinició su contador.
	var retraso := _ultima_secuencia_input_recibida - secuencia
	if retraso >= 0 and retraso < _SALTO_SECUENCIA_REINICIO:
		return
	_ultima_secuencia_input_recibida = secuencia
	# Nunca más rápido que el joystick a fondo, aunque el cliente mande otra cosa.
	_direccion_pedida = direccion_pedida.limit_length(1.0)
	_segundos_sin_input = 0.0


## SERVIDOR: la dirección que mueve el cuerpo este fotograma. Cero mientras
## haya un bloqueo — _congelamientos_disparo va aparte de _bloqueos_control a
## propósito (ver congelar_disparo_pendiente): frena el movimiento sin que
## esta_bloqueado() rechace la propia habilidad que lo puso.
func _aplicar_input_servidor(delta: float) -> void:
	_segundos_sin_input += delta
	if _segundos_sin_input > _SEGUNDOS_SIN_INPUT_PARA_FRENAR:
		_direccion_pedida = Vector2.ZERO
	var bloqueado := _muerto or _bloqueos_control > 0 or _congelamientos_disparo > 0 \
		or _bloqueo_transicion > 0.0
	direccion = Vector2.ZERO if bloqueado else _direccion_pedida


func _physics_process(delta: float) -> void:
	# *** ORQUESTACIÓN FÍSICA ***

	# Aterrizando en un nivel nuevo: quieto y sin habilidades (ver
	# bloquear_por_transicion). Se anula la dirección ACÁ, un único lugar
	# para las tres ramas de abajo — y corre igual en el servidor, que es
	# quien de verdad manda la posición.
	if _bloqueo_transicion > 0.0:
		_bloqueo_transicion = maxf(0.0, _bloqueo_transicion - delta)
		direccion = Vector2.ZERO
		velocity = Vector2.ZERO

	_verificar_joystick_soltado()
	if _soy_dueño_cliente_red():
		_enviar_input_red()
	elif Utils.en_red() and multiplayer.is_server():
		_aplicar_input_servidor(delta)

	# En red, el cliente que NO es dueño de este cuerpo (la réplica de OTRO
	# jugador en mi pantalla) no lo mueve directo: solo interpola hacia la
	# posición replicada.
	if Utils.en_red() and not multiplayer.is_server():
		if peer_id_dueño == multiplayer.get_unique_id():
			# Predicción local del PROPIO dueño: mover YA con la misma
			# dirección que ya le mandamos al servidor (ver
			# _enviar_input_red), sin esperar la ida y vuelta de red —
			# el servidor corre exactamente el mismo componente_movimiento
			# con la misma dirección, así que ambos deberían coincidir.
			if componente_movimiento:
				componente_movimiento.physics_process(delta, direccion)
			_aplicar_presentacion(velocity != Vector2.ZERO)
			# Ventana de sincronización DURA: copia la posición autoritativa sin
			# suavizar. Al cruzar un portal, el servidor ya movió el cuerpo mientras
			# este cliente carga el mapa nuevo; corregir esa diferencia acá, con la
			# pantalla todavía en negro, evita verlo deslizarse al aparecer.
			if _sincronizacion_dura > 0.0:
				_sincronizacion_dura -= delta
				global_position = _posicion_replicada
				return
			# Reconciliación suave con la posición autoritativa (el
			# servidor manda la real): un muro, un empujón u otra causa
			# que el cliente no simula igual puede hacer que diverja poco a
			# poco. Corrección chica y progresiva; solo un salto brusco
			# (drift grande — conexión que se recupera, etc.) se corrige
			# de un tirón, igual que Enemigo.gd con los mobs.
			var diferencia := _posicion_replicada - global_position
			var distancia_diferencia := diferencia.length()
			if distancia_diferencia > 60.0:
				global_position = _posicion_replicada
			elif distancia_diferencia > _UMBRAL_RECONCILIACION:
				global_position = global_position.lerp(
					_posicion_replicada, clampf(delta * VELOCIDAD_INTERPOLACION_RED, 0.0, 1.0)
				)
			# Debajo del umbral no se corrige nada: con ecos de posición a 60/s,
			# corregir cada diferencia de 1-2 px se ve como temblor. La predicción local
			# manda mientras la diferencia sea ruido de red.
			return
		# Réplica de OTRO jugador: no hay velocity local, así que "caminando" se
		# infiere del desplazamiento real en pantalla (mismo criterio que Enemigo.gd).
		# OJO con el orden: primero el lerp y recién después medir contra
		# _posicion_render_anterior; medir antes da avance 0 siempre y nunca anima la
		# caminata.
		global_position = global_position.lerp(
			_posicion_replicada, clampf(delta * VELOCIDAD_INTERPOLACION_RED, 0.0, 1.0)
		)
		var avance := global_position.distance_to(_posicion_render_anterior)
		_aplicar_presentacion(avance > _UMBRAL_CAMINANDO_RED)
		_posicion_render_anterior = global_position
		return

	# Delegamos la aplicación de física al componente de movimiento.
	if componente_movimiento:
		componente_movimiento.physics_process(delta, direccion)
	_destrabe.verificar(delta)
	# El servidor (o el único jugador, sin red) es quien manda la posición
	# real — mantener esto sincronizado es lo que efectivamente se replica.
	_posicion_replicada = global_position

	_aplicar_presentacion(velocity != Vector2.ZERO)

	if Utils.en_red() and multiplayer.is_server():
		_replicar_posicion_red()


## Único punto que aplica la animación de caminar/idle según la dirección
## actual — mismo patrón que Enemigo._aplicar_presentacion(), para que
## jugador y mobs se comporten igual ante quien mire el código. Prioridad
## de orientación: apunte de la última habilidad lanzada (direccion_mirada,
## un pulso de un solo fotograma) > dirección de movimiento > última
## dirección recordada (mantiene la pose de reposo orientada, no vuelve a
## mirar a la derecha por defecto). _ultima_direccion se actualiza ACÁ,
## centralizado, para las tres ramas de _physics_process que llaman esto.
func _aplicar_presentacion(caminando: bool) -> void:
	_actualizar_visual_invulnerable()
	if not componente_animacion:
		return
	componente_animacion.establecer_condicion("parameters/conditions/debeCaminar", caminando)
	componente_animacion.establecer_condicion("parameters/conditions/debeIdle",    not caminando)
	var hacia_donde_mirar := direccion_mirada if direccion_mirada != Vector2.ZERO \
		else (direccion if direccion != Vector2.ZERO else _ultima_direccion)
	direccion_mirada = Vector2.ZERO
	if hacia_donde_mirar != Vector2.ZERO:
		_ultima_direccion = hacia_donde_mirar
	componente_animacion.actualizar_blend(hacia_donde_mirar)


## Destello AMARILLO intermitente mientras dura la protección de aparición o
## de revivir: sin señal visible, "no recibo daño" no se distingue de "los
## mobs no me ven todavía", y al cortarse el primer golpe llegaría de la nada.
## Pisar el modulate entero es seguro: siendo invulnerable, quitar_vida corta
## antes del daño, así que parpadear() nunca corre a la vez (ver
## _on_vida_cambiada).
##
## _muerto corta: un cadáver ya tiene su propio modulate y no debe latir.
var _estaba_invulnerable := false

func _actualizar_visual_invulnerable() -> void:
	if not sprite or not componente_vida:
		return
	# Camuflado: translúcido y estable (no late). Va ANTES de la protección
	# porque son estados distintos y no deben mezclarse en un mismo color; si
	# se solapan, manda el destello amarillo de la protección, que es el que
	# avisa de algo con tiempo crítico.
	var camuflaje = get_node_or_null("CamuflajeComponente")
	var oculto: bool = camuflaje != null and camuflaje.esta_activo() and not _muerto
	var invulnerable: bool = componente_vida.es_invulnerable() and not _muerto
	if oculto and not invulnerable:
		sprite.modulate = Color(0.75, 0.85, 1.0, 0.35)
		_estaba_invulnerable = true  # para que al salir se restaure el color
		return
	if invulnerable:
		# Parpadeo DURO (no un latido suave): opaco y semitransparente cada 0.25 s,
		# siempre teñido de amarillo.
		var fase := int(Time.get_ticks_msec() / 250) % 2
		var alpha := 1.0 if fase == 0 else 0.4
		sprite.modulate = Color(1.0, 1.0, 0.0, alpha)
		_estaba_invulnerable = true
	elif _estaba_invulnerable:
		# Una sola vez al terminar (no cada fotograma): devolver el color
		# normal.
		sprite.modulate = Color.WHITE
		_estaba_invulnerable = false


## Posición por RPC manual y no por MultiplayerSynchronizer: mismo throttle por
## cambio + keepalive que los mobs, dirigido SOLO a los peers que tienen a este
## jugador cerca (ver InteresEspacial). Mandarla a todos era tráfico
## O(jugadores²).
var _ultima_pos_enviada := Vector2.INF
## También viaja la orientación: sin ella, la réplica en otras pantallas
## siempre miraba a la derecha (mismo patrón que Enemigo._recibir_estado_red).
var _ultima_dir_enviada := Vector2.INF
var _fotogramas_sin_enviar_pos := 0
const _FOTOGRAMAS_KEEPALIVE_POS := 30

func _replicar_posicion_red() -> void:
	_fotogramas_sin_enviar_pos += 1
	# Se manda _ultima_direccion y no "direccion": esa es solo la del joystick
	# (cero al detenerse), así que un giro por apuntar una habilidad estando quieto
	# nunca viajaba. _ultima_direccion ya tiene resuelta la prioridad (apunte >
	# movimiento > última; ver _aplicar_presentacion).
	var cambio := global_position.distance_squared_to(_ultima_pos_enviada) > 0.25 \
		or _ultima_direccion != _ultima_dir_enviada
	if not (cambio or _fotogramas_sin_enviar_pos >= _FOTOGRAMAS_KEEPALIVE_POS):
		return
	for peer_id in InteresEspacial.peers_cercanos(global_position):
		# El propio dueño también recibe su posición replicada (interpola
		# igual que ve a los demás) — el filtro de InteresEspacial ya lo
		# incluye siempre a sí mismo (ver es_relevante_para_peer).
		rpc_id(peer_id, "_recibir_posicion_red", global_position, _ultima_direccion)
	_ultima_pos_enviada = global_position
	_ultima_dir_enviada = _ultima_direccion
	_fotogramas_sin_enviar_pos = 0


## unreliable_ordered: estado continuo (~60/s), el próximo paquete corrige
## cualquier pérdida (mismo criterio que Enemigo._recibir_estado_red). "dir"
## es la _ultima_direccion del emisor, que la réplica usa como "direccion"
## para orientarse.
##
## OJO: este RPC también le llega al propio DUEÑO (eco para reconciliar
## _posicion_replicada). Para él, "direccion" no es orientación sino el input
## real que mueve la predicción local: pisarlo con el eco (que casi nunca es
## cero) lo hacía seguir caminando solo después de soltar el joystick.
@rpc("authority", "unreliable_ordered")
func _recibir_posicion_red(pos: Vector2, dir: Vector2 = Vector2.ZERO) -> void:
	_posicion_replicada = pos
	if Utils.en_red() and peer_id_dueño == multiplayer.get_unique_id():
		return
	direccion = dir
	if dir != Vector2.ZERO:
		_ultima_direccion = dir


## La señal "muerte" de VidaComponente solo se emite donde el daño es real
## (servidor o un solo jugador — el gate de quitar_vida bloquea al cliente),
## así que acá siempre corre la AUTORIDAD: apaga el cuerpo, avisa a los
## clientes por RPC y programa la reaparición.
func manejar_muerte(_vida_actual: float) -> void:
	if _muerto:
		return
	_morir()
	if Utils.en_red() and multiplayer.is_server():
		rpc("_morir_red")
	get_tree().create_timer(TIEMPO_REAPARICION).timeout.connect(_reaparecer)


## Presentación + apagado del cuerpo — corre igual en todos los peers.
func _morir() -> void:
	_muerto = true
	velocity = Vector2.ZERO
	direccion = Vector2.ZERO
	# Diferido: la muerte llega desde un callback de física (el golpe).
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if componente_vida:
		componente_vida.set_deferred("monitorable", false)
	# Cadáver: oscurecido y semitransparente hasta reaparecer.
	modulate = Color(0.35, 0.35, 0.35, 0.6)
	if _es_dueño_local():
		BusEventos.jugador_murio.emit(TIEMPO_REAPARICION)
		# Suelta cualquier joystick de habilidad que siguiera sostenido al
		# morir — ver comentario de UIHabilidad.cancelar_todos_los_apuntes.
		if is_inside_tree():
			UIHabilidad.cancelar_todos_los_apuntes(get_tree())


## Solo la autoridad (servidor / un solo jugador): cura, teletransporta al
## punto de aparición del nivel y revive en todos los peers.
func _reaparecer() -> void:
	if not is_inside_tree():
		return
	# nivel_de_jugador y no nivel_actual(): en el servidor hay varios niveles
	# cargados a la vez y hay que reaparecer en el propio, no en el primero
	# que encuentre (te teletransportaría al mapa de otro jugador).
	var nivel = GestorNiveles.nivel_de_jugador(self)
	if nivel != null:
		var punto: Node2D = nivel.punto_aparicion()
		if punto != null:
			global_position = punto.global_position
			_posicion_replicada = global_position
	# agregar_vida/agregar_energia (no restaurar_*): ya replican el valor al
	# cliente por su cuenta.
	if componente_vida:
		componente_vida.agregar_vida(componente_vida.obtener_vida_maxima())
	if componente_energia:
		componente_energia.agregar_energia(componente_energia.obtener_energia_maxima())
	_revivir()
	if Utils.en_red() and multiplayer.is_server():
		rpc("_revivir_red", global_position)


func _revivir() -> void:
	_muerto = false
	set_deferred("collision_layer", _capa_colision_original)
	set_deferred("collision_mask", _mascara_colision_original)
	if componente_vida:
		componente_vida.set_deferred("monitorable", true)
		# Misma idea que al aparecer, pero más larga (ver
		# TIEMPO_INVULNERABILIDAD_REVIVIR): se revive EN EL PUNTO DE
		# APARICIÓN (ver _reaparecer), donde pueden seguir los mismos mobs
		# que te mataron — sin esto, morir cerca del spawn encadena muerte
		# tras muerte sin poder reaccionar.
		componente_vida.activar_invulnerabilidad(TIEMPO_INVULNERABILIDAD_REVIVIR)
	modulate = Color.WHITE
	if _es_dueño_local():
		BusEventos.jugador_reaparecio.emit(global_position)
	# Reaparecer teletransporta al spawn — sin esto la cámara se desliza
	# desde donde moriste hasta ahí, un "fantasma" visible cruzando el mapa.
	resetear_camara()


@rpc("authority", "reliable")
func _morir_red() -> void:
	_morir()


@rpc("authority", "reliable")
func _revivir_red(pos: Vector2) -> void:
	# Salto directo (sin lerp): reaparecer cruza medio mapa — interpolar
	# se vería como un fantasma deslizándose hasta el spawn.
	global_position = pos
	_posicion_replicada = pos
	_revivir()


func _es_dueño_local() -> bool:
	if not Utils.en_red():
		return true
	return peer_id_dueño == multiplayer.get_unique_id()


## Cuántos slots de habilidad hay que escuchar por SeñalManager (0..N-1) —
## la MISMA fuente de verdad que SlotHabilidades.total_slots, para no
## mantener dos números "10" copiados a mano que puedan desincronizarse.
## Con fallback fijo por si esto corre antes de que el nodo exista o
## después de liberado (ver _exit_tree, donde el hijo puede ya no ser válido).
func _total_slots_habilidad() -> int:
	if is_instance_valid(slot_habilidades):
		return slot_habilidades.total_slots
	return 10


## Activa la habilidad del slot indicado.
func _activar_slot(index: int, dir: Vector2 = Vector2.ZERO, poder: float = 1.0) -> void:
	# En red, SeñalManager es un bus global: sin este corte, apretar un
	# botón de habilidad activaría el slot de TODOS los jugadores en
	# pantalla (el propio y los replicados de otros), no solo el mío.
	if Utils.en_red() and peer_id_dueño != multiplayer.get_unique_id():
		return
	var h := slot_habilidades.obtener(index)
	# Muerto o recién llegado a un nivel nuevo: nada de habilidades. La
	# excepción son las que declaran ignora_bloqueos (ver HabilidadBase.
	# activar y HabilidadCorte): esas se lanzan aunque estés aturdido, pero
	# nunca estando muerto — por eso ahí se mira solo _muerto.
	if h and h.ignora_bloqueos_de_control():
		if _muerto:
			return
	elif esta_bloqueado():
		return
	if h:
		var d := dir if dir.length() > 0.1 else _ultima_direccion
		# Girar hacia donde se lanza, solo si la habilidad usa dirección: un botón
		# sin apuntar (curación, escudo…) no debe girar al personaje.
		if h.requiere_direccion:
			direccion_mirada = d
		h.activar(d, poder)

func _on_slot_0_activar()                    -> void: _activar_slot(0)
func _on_slot_0_lanzar(d: Vector2, p: float) -> void: _activar_slot(0, d, p)
func _on_slot_1_activar()                    -> void: _activar_slot(1)
func _on_slot_1_lanzar(d: Vector2, p: float) -> void: _activar_slot(1, d, p)
func _on_slot_2_activar()                    -> void: _activar_slot(2)
func _on_slot_2_lanzar(d: Vector2, p: float) -> void: _activar_slot(2, d, p)
func _on_slot_3_activar()                    -> void: _activar_slot(3)
func _on_slot_3_lanzar(d: Vector2, p: float) -> void: _activar_slot(3, d, p)
func _on_slot_4_activar()                    -> void: _activar_slot(4)
func _on_slot_4_lanzar(d: Vector2, p: float) -> void: _activar_slot(4, d, p)
func _on_slot_5_activar()                    -> void: _activar_slot(5)
func _on_slot_5_lanzar(d: Vector2, p: float) -> void: _activar_slot(5, d, p)
func _on_slot_6_activar()                    -> void: _activar_slot(6)
func _on_slot_6_lanzar(d: Vector2, p: float) -> void: _activar_slot(6, d, p)
func _on_slot_7_activar()                    -> void: _activar_slot(7)
func _on_slot_7_lanzar(d: Vector2, p: float) -> void: _activar_slot(7, d, p)
func _on_slot_8_activar()                    -> void: _activar_slot(8)
func _on_slot_8_lanzar(d: Vector2, p: float) -> void: _activar_slot(8, d, p)
func _on_slot_9_activar()                    -> void: _activar_slot(9)
func _on_slot_9_lanzar(d: Vector2, p: float) -> void: _activar_slot(9, d, p)


## Recibe daño externo (carga, habilidades enemigas). Delega al componente.
func quitar_vida(cantidad: float, fuente: Node = null,
		tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO,
		critico: bool = false) -> void:
	if componente_vida:
		componente_vida.quitar_vida(cantidad, fuente, tipo, critico)


## Copia la posición autoritativa TAL CUAL (sin interpolar) durante "segundos".
## La usa GestorNiveles al cambiar de nivel, para que el reacomodo ocurra
## mientras la pantalla está en negro. Nunca acorta una ventana más larga que
## ya esté en curso.
func sincronizar_posicion_dura(segundos: float) -> void:
	_sincronizacion_dura = maxf(_sincronizacion_dura, segundos)


## Llegada a un nivel nuevo: deja al jugador QUIETO y sin habilidades durante
## "segundos", con invulnerabilidad por el mismo rato (que además lo saca de la
## mira de los mobs, ver VisionComponente._intentar_registrar).
##
## Se llama en los DOS lados: el servidor manda el movimiento y el daño, y el
## cliente bloquea su propia UI. No hace falta que arranquen en el mismo
## instante; la ventana es generosa.
func bloquear_por_transicion(segundos: float = TIEMPO_BLOQUEO_TRANSICION) -> void:
	_bloqueo_transicion = maxf(_bloqueo_transicion, segundos)
	if componente_vida:
		componente_vida.activar_invulnerabilidad(segundos)


## true mientras el jugador no puede actuar: muerto, recién llegado a un nivel
## nuevo o con el control tomado (aturdido, canal de Ráfaga/Lanzallamas...).
## Único lugar que decide esto: lo consultan la UI de habilidades (para no
## armar el joystick de apuntado), el manejo de toques y el servidor.
func esta_bloqueado() -> bool:
	return _muerto or _bloqueo_transicion > 0.0 or _bloqueos_control > 0


## GestorNiveles la llama tras cada cambio de nivel para que la cámara no
## muestre el vacío fuera del mapa. rect vacío (nivel sin Terreno) = sin límite.
func aplicar_limites_camara(rect: Rect2) -> void:
	if camara == null:
		return
	if rect.size == Vector2.ZERO:
		camara.limit_left = -10000000
		camara.limit_top = -10000000
		camara.limit_right = 10000000
		camara.limit_bottom = 10000000
		return
	camara.limit_left = int(rect.position.x)
	camara.limit_top = int(rect.position.y)
	camara.limit_right = int(rect.position.x + rect.size.x)
	camara.limit_bottom = int(rect.position.y + rect.size.y)


## Corta en seco el "arrastre" suave (position_smoothing) de la cámara para
## que salte DIRECTO a la posición del jugador en vez de deslizarse desde
## donde estaba antes — se nota sobre todo apenas arranca el juego (la
## cámara parte del origen del mundo y se desliza hasta el spawn) y en
## cualquier teletransporte real: cambio de nivel, reaparición tras morir,
## carga de partida. GestorNiveles la llama igual que aplicar_limites_camara
## (mismo patrón has_method/call, sin acoplarse a Jugador directo).
func resetear_camara() -> void:
	if camara:
		camara.reset_smoothing()


var _tween_parpadeo: Tween = null

## Un solo parpadeo por golpe. Mata el tween anterior antes de arrancar otro:
## con golpes más seguidos que el parpadeo, dos tweens se peleaban el modulate
## y el jugador quedaba parpadeando sin parar (o teñido de rojo).
func parpadear(duracion: float = 0.1) -> void:
	if _tween_parpadeo and _tween_parpadeo.is_valid():
		_tween_parpadeo.kill()
		sprite.modulate = Color.WHITE
	_tween_parpadeo = create_tween()
	_tween_parpadeo.tween_property(sprite, "modulate", Color(1, 0.2, 0.2), duracion)
	_tween_parpadeo.tween_property(sprite, "modulate", Color.WHITE,        duracion)


## Solo el dueño parpadea: "cambio_valor_vida" se emite en todos los peers que
## tienen a este jugador replicado (ver VidaComponente._recibir_vida_red), y el
## aviso del golpe es para quien lo recibe, no para quien lo mira.
func _on_vida_cambiada(nueva_vida: float) -> void:
	if nueva_vida < _vida_anterior and _es_dueño_local():
		parpadear()
	_vida_anterior = nueva_vida


## SERVIDOR: empuja la vida actualizada a los compañeros de grupo (ver
## GestorGrupos.notificar_cambio_vida — solo se la manda a ELLOS, nunca a
## todos los jugadores). Corre en la copia autoritativa de cada Jugador; en
## un cliente puro esto no hace nada (GestorGrupos.notificar_cambio_vida ya
## se guarda de aplicar nada fuera del servidor).
func _on_vida_cambiada_para_grupo(nueva_vida: float) -> void:
	if id_unico != "":
		GestorGrupos.notificar_cambio_vida(id_unico, nueva_vida, componente_vida.obtener_vida_maxima())
