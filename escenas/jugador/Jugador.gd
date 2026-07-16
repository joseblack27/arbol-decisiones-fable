## Jugador.gd
## Controlador principal del jugador. Su única responsabilidad es orquestar el flujo de datos y eventos entre los componentes.
## Toda la lógica de física y el estado de los componentes deben estar referenciados y configurados desde el Inspector de Godot.

extends CharacterBody2D

# --- Referencias de Componentes ---
# Estos componentes deben estar adjuntos como nodos hijos de este jugador y deben existir
# en la escena de Godot. El usuario debe arrastrar las referencias aquí en el Inspector.
@export var componente_vida: VidaComponente # Componente de vida.
@export var componente_movimiento: MovimientoComponente # Componente de movimiento.
#@export var arbol_comportamiento: ArbolComportamiento # Referencia principal del sistema de IA.

# --- Variables de estado ---
var componentes_de_acciones: Dictionary = {}
var _vida_anterior: float = 0.0
var direccion: Vector2

@onready var sprite: Sprite2D = $Sprite2D
@onready var slot_habilidades: SlotHabilidades = $SlotHabilidades
@onready var camara: Camera2D = $Camara
@onready var componente_atributos: AtributosComponente = $AtributosComponente

var _ultima_direccion: Vector2 = Vector2.RIGHT

# ── Muerte / reaparición ─────────────────────────────────────────────────────
## Segundos entre morir y reaparecer en el punto de aparición del nivel.
const TIEMPO_REAPARICION := 5.0
var _muerto := false
## Colisiones originales, para restaurarlas al revivir (se apagan al morir
## para que los mobs pierdan al "cadáver" — su visión y sus golpes son
## físicos, así que sin colisión dejan de detectarlo y atacarlo solos).
var _capa_colision_original: int = 0
var _mascara_colision_original: int = 0
## Cartel "Has muerto" — solo se crea para el dueño local (ver _morir).
var _aviso_muerte: Label = null

## Fase 2 del plan de multijugador: si esto corre bajo un MultiplayerPeer de
## red real (ENet, no el OfflineMultiplayerPeer que Godot asigna por
## defecto — ver Utils.en_red()), el nombre del nodo ES el peer id dueño (lo
## asigna quien lo spawnea — ver prototipos/red/Servidor.gd). Sin red real
## (el juego de un jugador de siempre, incluidas TODAS las pruebas
## existentes), nada de esto entra en juego — el comportamiento es
## exactamente el de antes.
var peer_id_dueño: int = -1

## Nombre para mostrar en logs/UI (el nombre de nodo NO sirve para eso: en
## red es el peer id, un número pelado). El dueño se lo manda al servidor al
## aparecer (_registrar_identidad_red) y de ahí viaja a todos los peers por
## el mismo MultiplayerSynchronizer que ya replica la posición. Leerlo
## siempre vía Utils.nombre_visible(nodo), que cae al nombre de nodo si está
## vacío. PUEDE repetirse entre jugadores sin problema — es solo estético.
var nombre_visible: String = ""

## Fase 0 del plan de escalado a MMO: identidad ÚNICA y persistente del
## dueño (ver Utils.id_jugador_local — un UUID guardado en su disco, NO el
## nombre de Windows). El SERVIDOR la usa como clave real para encontrar/
## guardar la partida de este jugador (ver GestorGuardado) — nombre_visible
## NUNCA debe usarse para eso, dos jugadores con el mismo nombre de Windows
## ("Usuario", "Admin"...) compartirían sin querer la misma partida.
## No se muestra nunca en pantalla, solo viaja al servidor.
var id_unico: String = ""

## Fase 6 del plan de multijugador: lo que se replica NO es global_position
## directo — es esta variable. Así el cliente puede suavizar el movimiento
## (interpolar hacia acá cada fotograma en vez de saltar de golpe a cada
## actualización de red, que llega más espaciada que los fotogramas de
## render) sin pelearse con el valor recién llegado. El servidor la
## mantiene igual a global_position en todo momento (ver _physics_process).
var _posicion_replicada: Vector2 = Vector2.ZERO
## Qué tan rápido el cliente alcanza la posición replicada (más alto = más
## "pegado" a la red pero más notorio el salto; más bajo = más suave pero
## más "elástico"). 1/seg ≈ alcanza el 63% de la distancia cada segundo.
const VELOCIDAD_INTERPOLACION_RED := 12.0


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
	# Antes de _ready() (y antes del primer intento de sync del spawn): si
	# esto se arma más tarde a veces llega tarde y se ve un
	# "ERR_UNCONFIGURED" benigno en el primer fotograma (mismo caso que
	# prototipos/red/JugadorRed.gd).
	var sync := get_node_or_null("Sync") as MultiplayerSynchronizer
	if sync == null:
		return
	_posicion_replicada = global_position
	var config := SceneReplicationConfig.new()
	# _posicion_replicada NO va acá (ver _fisica_servidor/_recibir_posicion_
	# red): Fase 1 del plan de escalado a MMO probó primero un
	# add_visibility_filter() de distancia sobre este mismo Synchronizer,
	# pero rompió la integración con MultiplayerSpawner en vivo ("spawner is
	# null", "ID not found in cache", desconexión inmediata de ambos peers)
	# — riesgo real de tocar el sistema de spawn de Godot. En vez de eso, la
	# posición usa el MISMO patrón ya probado y funcionando de Enemigo.gd:
	# RPC manual dirigido solo a los peers cercanos (ver InteresEspacial),
	# con el Synchronizer reservado para lo que replica a TODOS igual
	# (nombre_visible — pocos jugadores lo necesitan lejos, pero es un
	# cambio raro y barato, no vale la pena filtrarlo).
	config.add_property(NodePath(".:nombre_visible"))
	config.property_set_replication_mode(
		NodePath(".:nombre_visible"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
	)
	sync.replication_config = config


func _ready():
	add_to_group("jugadores")
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
		# El dueño registra su nombre (para mostrar, se replica a todos —
		# ver _enter_tree) y su identidad única (solo para el servidor,
		# nunca se muestra ni se replica — ver id_unico). Ninguno de los dos
		# lo puede saber el servidor solo: ambos viven en el cliente.
		if peer_id_dueño == multiplayer.get_unique_id():
			nombre_visible = Utils.nombre_jugador_local()
			rpc_id(1, "_registrar_identidad_red", Utils.id_jugador_local(), nombre_visible)
	else:
		nombre_visible = Utils.nombre_jugador_local()
		id_unico = Utils.id_jugador_local()
		resetear_camara()
	# 1. Conectar señales de los componentes.
	if componente_vida:
		# Conectar la muerte del componente de vida.
		componente_vida.muerte.connect(self.manejar_muerte)
		componente_vida.cambio_valor_vida.connect(_on_vida_cambiada)
		_vida_anterior = componente_vida.obtener_vida_maxima()
	
	# 2. Registrar componentes.
	componentes_de_acciones["Movimiento"] = componente_movimiento
	componentes_de_acciones["Vida"] = componente_vida
	
	# SeñalManager es un bus GLOBAL de un solo proceso: solo el jugador
	# PROPIO debe suscribirse a la UI (joystick/botones de habilidad) — no
	# cada réplica de OTROS jugadores que aparece en pantalla. Antes esto se
	# suscribía en TODO Jugador.tscn instanciado en el cliente (el propio Y
	# las réplicas), y SeñalManager nunca desconecta solo al perder el nodo:
	# cuando ese OTRO jugador se desconectaba y su réplica se liberaba, su
	# suscripción quedaba colgando en el diccionario de SeñalManager — la
	# siguiente vez que CUALQUIERA (vos) usaba una habilidad, emitir()
	# intentaba llamar has_method() sobre esa instancia ya liberada y
	# reventaba ("intento de spawnear 2 jugadores y al desaparecer el
	# primero, usar una habilidad da error").
	# El servidor dedicado tampoco tiene UI que registre estas señales — del
	# lado del servidor el input SIEMPRE llega por RPC, nunca por acá.
	var soy_dueño_local := not Utils.en_red() or peer_id_dueño == multiplayer.get_unique_id()
	if soy_dueño_local and not (Utils.en_red() and multiplayer.is_server()):
		SeñalManager.conectar("joystick_movimiento", self, "_joystick_movimiento")
		# Un slot_N_activar/lanzar por CADA slot posible (no solo los que se
		# ven a la vez en el HUD): PaginadorHabilidades reasigna qué slot_index
		# muestra cada botón físico según la página, así que hay que estar
		# suscripto a los 10 de entrada, aunque el HUD solo muestre 5 por vez.
		for i in _total_slots_habilidad():
			SeñalManager.conectar("slot_%d_activar" % i, self, "_on_slot_%d_activar" % i)
			SeñalManager.conectar("slot_%d_lanzar"  % i, self, "_on_slot_%d_lanzar"  % i)

	# Los bonos de atributos del equipo (armas, armaduras, anillos…) se
	# recalculan directo desde EquipoComponente.actualizar() (su propio
	# hermano AtributosComponente, ver ese archivo) — YA NO por acá vía
	# BusEventos.equipo_cambiado. Ese bus es GLOBAL (una sola instancia de
	# GestorEquipo por proceso): en el cliente recalculaba TODOS los
	# Jugador en pantalla (incluidas réplicas de otros), y en el SERVIDOR
	# era peor — el filtro por peer_id_dueño ahí comparaba contra
	# multiplayer.get_unique_id() (siempre 1 en el servidor, que ningún
	# jugador real tiene como dueño), así que NUNCA recalculaba a nadie:
	# equipar mejor armadura no cambiaba nada en combates reales.


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
	# En red: dejar de MANDAR movimiento (lo que ya hacía _joystick_movimiento
	# al cortar por _bloqueos_control) no alcanza — el SERVIDOR sigue
	# aplicando la ÚLTIMA dirección que le llegó, cada frame, hasta que se le
	# diga lo contrario (no hace falta reenviar "seguí" a cada frame para que
	# siga moviéndose). Sin este aviso explícito de "parate", el cuerpo
	# autoritativo del servidor seguía caminando durante toda la ida y vuelta
	# de red mientras el cliente ya se veía quieto — exactamente el desfase
	# de origen que hace fallar los proyectiles lanzados en movimiento.
	if Utils.en_red() and peer_id_dueño == multiplayer.get_unique_id():
		rpc_id(1, "_pedir_detener_red")


func desbloquear_control() -> void:
	_bloqueos_control = maxi(0, _bloqueos_control - 1)


func _joystick_movimiento(_direccion: Vector2):
	if _muerto or _bloqueos_control > 0:
		return
	if Utils.en_red():
		# En red: el joystick es local a CADA cliente (SeñalManager es un bus
		# global, sin esto los joysticks de otros jugadores también moverían
		# este cuerpo). Solo el dueño manda su intención, y se la manda al
		# SERVIDOR por RPC — el servidor es quien decide el movimiento real
		# (ver _physics_process y _pedir_mover_red).
		if peer_id_dueño != multiplayer.get_unique_id():
			return
		rpc_id(1, "_pedir_mover_red", _direccion)
		# TAMBIÉN local, para predicción — ver _physics_process: sin esto el
		# dueño no movía su propio cuerpo hasta que la posición volviera
		# replicada desde el servidor (1 ida y vuelta de red completa),
		# quedando su render siempre ATRASADO respecto a su posición real.
		# Eso desalineaba el ORIGEN del proyectil que ve el dueño (su
		# posición vieja) contra el que arma el servidor (su posición ya
		# actualizada) — "el golpe no acierta, sobre todo moviéndose".
		direccion = _direccion
		return
	direccion = _direccion


## El servidor recibe acá la intención de movimiento del cliente dueño de
## este cuerpo. "any_peer" = cualquiera puede llamarlo, pero se verifica que
## el remitente sea el dueño real antes de aceptarlo (autoridad real, no
## solo quién puede mandar el mensaje — mismo criterio que
## prototipos/red/JugadorRed.gd).
## El dueño registra acá su identidad (id_unico, la clave real de guardado —
## ver GestorGuardado) y su nombre para mostrar. Solo el servidor lo acepta
## (y solo del dueño real). id_unico se queda acá, solo el servidor lo lee;
## nombre_visible sí se replica por el Sync a todos (ver _enter_tree).
@rpc("any_peer", "reliable")
func _registrar_identidad_red(id: String, nombre: String) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id_dueño:
		return
	var id_limpio := id.strip_edges()
	if id_limpio != "":
		id_unico = id_limpio
	var nombre_limpio := nombre.strip_edges().substr(0, 24)
	if nombre_limpio != "":
		nombre_visible = nombre_limpio


@rpc("any_peer", "unreliable_ordered")
func _pedir_mover_red(direccion_pedida: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id_dueño:
		return
	if _muerto:
		return
	# La copia AUTORITATIVA también respeta el bloqueo de control (ráfaga en
	# curso): el cliente dueño ya no manda intención mientras está bloqueado,
	# pero un paquete rezagado (o manipulado) no debe mover el cuerpo real.
	if _bloqueos_control > 0:
		return
	direccion = direccion_pedida


## Aviso de "parate ya" — reliable (a diferencia de _pedir_mover_red, que es
## unreliable_ordered: estado continuo donde un paquete de más no importa).
## Este SÍ importa que llegue y en orden respecto al RPC de activar()
## siguiente (ver bloquear_control()/HabilidadBase.activar()): la ida y
## vuelta de red completa que tarda "activar la habilidad" es EXACTAMENTE
## la ventana en la que, si el servidor seguía moviendo este cuerpo con la
## última dirección recibida, terminaba spawneando el proyectil real desde
## un punto distinto al que el cliente ya mostraba quieto — "el golpe no
## acierta, más si disparo en movimiento". Mandarlo por el mismo canal
## reliable que _activar_red asegura que llegue ANTES (mismo orden de
## envío del lado del cliente, ver bloquear_control()).
@rpc("any_peer", "reliable")
func _pedir_detener_red() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id_dueño:
		return
	direccion = Vector2.ZERO


## Fase 4 del plan de multijugador: el SERVIDOR ya le dio este botín/XP de
## verdad a la copia autoritativa (ver Enemigo._otorgar_item_al_atacante) —
## esto es el aviso al cliente dueño para que su copia espejo (inventario/
## XP que ve en su propia UI) se entere. "authority" = solo el servidor
## puede llamarlo. Se usa self.get_node(...) en vez de la fachada
## GestorInventario/GestorExperiencia a propósito: el RPC ya llegó al nodo
## correcto por su ruta, no hace falta (ni conviene) volver a adivinar "cuál
## jugador" con la búsqueda por grupo que usa la fachada.
@rpc("authority", "reliable")
func _recibir_botin_red(ruta_item: String, cantidad: int) -> void:
	var item := load(ruta_item) as DatosItem
	if item == null:
		return
	var inventario := get_node_or_null("InventarioComponente")
	if inventario:
		inventario.agregar_item(item, cantidad)


@rpc("authority", "reliable")
func _recibir_xp_red(cantidad: int) -> void:
	var experiencia := get_node_or_null("ExperienciaComponente")
	if experiencia:
		experiencia.agregar_xp(cantidad)


func _physics_process(delta: float) -> void:
	# *** ORQUESTACIÓN FÍSICA ***

	# En red, el cliente que NO es dueño de este cuerpo (la réplica de OTRO
	# jugador en mi pantalla) no lo mueve directo — solo interpola hacia la
	# posición replicada (Fase 6: suaviza el "salto" entre actualizaciones de
	# red, que llegan más espaciadas que los fotogramas de render).
	if Utils.en_red() and not multiplayer.is_server():
		if peer_id_dueño == multiplayer.get_unique_id():
			# Predicción local del PROPIO dueño: mover YA con la misma
			# dirección que ya le mandamos al servidor (ver
			# _joystick_movimiento), sin esperar la ida y vuelta de red —
			# el servidor corre exactamente el mismo componente_movimiento
			# con la misma dirección, así que ambos deberían coincidir.
			if componente_movimiento:
				componente_movimiento.physics_process(delta, direccion)
			# Reconciliación suave con la posición autoritativa (el
			# servidor manda la real): un muro, un empujón u otra causa
			# que el cliente no simula igual puede hacer que diverja poco a
			# poco. Corrección chica y progresiva; solo un salto brusco
			# (drift grande — conexión que se recupera, etc.) se corrige
			# de un tirón, igual que Enemigo.gd con los mobs.
			var diferencia := _posicion_replicada - global_position
			if diferencia.length() > 60.0:
				global_position = _posicion_replicada
			else:
				global_position = global_position.lerp(
					_posicion_replicada, clampf(delta * VELOCIDAD_INTERPOLACION_RED, 0.0, 1.0)
				)
			return
		global_position = global_position.lerp(
			_posicion_replicada, clampf(delta * VELOCIDAD_INTERPOLACION_RED, 0.0, 1.0)
		)
		return

	# Delegamos la aplicación de física al componente de movimiento.
	if componente_movimiento:
		componente_movimiento.physics_process(delta, direccion)
	# El servidor (o el único jugador, sin red) es quien manda la posición
	# real — mantener esto sincronizado es lo que efectivamente se replica.
	_posicion_replicada = global_position

	if direccion != Vector2.ZERO:
		_ultima_direccion = direccion

	if Utils.en_red() and multiplayer.is_server():
		_replicar_posicion_red()


## Fase 1 del plan de escalado a MMO (interés espacial): mismo patrón que
## Enemigo._physics_process — antes esto viajaba por MultiplayerSynchronizer
## en modo ALWAYS (sin throttle, a TODOS los peers, cada tick de sync); con
## 100 jugadores dispersos por el mapa era tráfico O(jugadores²). Ahora es
## un RPC manual, con el mismo throttle por cambio + keepalive que ya usan
## los mobs, dirigido SOLO a los peers que tienen a este jugador cerca (ver
## InteresEspacial) — a quien está del otro lado del mapa no le llega nada.
var _ultima_pos_enviada := Vector2.INF
var _fotogramas_sin_enviar_pos := 0
const _FOTOGRAMAS_KEEPALIVE_POS := 30

func _replicar_posicion_red() -> void:
	_fotogramas_sin_enviar_pos += 1
	var cambio := global_position.distance_squared_to(_ultima_pos_enviada) > 0.25
	if not (cambio or _fotogramas_sin_enviar_pos >= _FOTOGRAMAS_KEEPALIVE_POS):
		return
	for peer_id in InteresEspacial.peers_cercanos(global_position):
		# El propio dueño también recibe su posición replicada (interpola
		# igual que ve a los demás) — el filtro de InteresEspacial ya lo
		# incluye siempre a sí mismo (ver es_relevante_para_peer).
		rpc_id(peer_id, "_recibir_posicion_red", global_position)
	_ultima_pos_enviada = global_position
	_fotogramas_sin_enviar_pos = 0


## unreliable_ordered: es estado continuo (~60 veces/seg) — un paquete
## perdido no importa, el siguiente lo corrige (mismo criterio que
## Enemigo._recibir_estado_red).
@rpc("authority", "unreliable_ordered")
func _recibir_posicion_red(pos: Vector2) -> void:
	_posicion_replicada = pos


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
		_mostrar_aviso_muerte()


## Solo la autoridad (servidor / un solo jugador): cura, teletransporta al
## punto de aparición del nivel y revive en todos los peers.
func _reaparecer() -> void:
	if not is_inside_tree():
		return
	var nivel = GestorNiveles.nivel_actual()
	if nivel != null:
		var punto: Node2D = nivel.punto_aparicion()
		if punto != null:
			global_position = punto.global_position
			_posicion_replicada = global_position
	# agregar_vida (no restaurar_vida): ya replica el valor al cliente.
	if componente_vida:
		componente_vida.agregar_vida(componente_vida.obtener_vida_maxima())
	_revivir()
	if Utils.en_red() and multiplayer.is_server():
		rpc("_revivir_red", global_position)


func _revivir() -> void:
	_muerto = false
	set_deferred("collision_layer", _capa_colision_original)
	set_deferred("collision_mask", _mascara_colision_original)
	if componente_vida:
		componente_vida.set_deferred("monitorable", true)
	modulate = Color.WHITE
	if _aviso_muerte:
		_aviso_muerte.hide()
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


func _mostrar_aviso_muerte() -> void:
	if _aviso_muerte == null:
		var capa := CanvasLayer.new()
		capa.layer = 90
		_aviso_muerte = Label.new()
		_aviso_muerte.text = "Has muerto"
		_aviso_muerte.add_theme_font_size_override("font_size", 36)
		_aviso_muerte.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_aviso_muerte.set_anchors_preset(Control.PRESET_CENTER)
		_aviso_muerte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		capa.add_child(_aviso_muerte)
		add_child(capa)
	_aviso_muerte.show()
	# Cuenta regresiva simple en el propio label.
	var restante := int(TIEMPO_REAPARICION)
	_aviso_muerte.text = "Has muerto\nReapareces en %d..." % restante
	for i in range(restante - 1, -1, -1):
		await get_tree().create_timer(1.0).timeout
		if _aviso_muerte == null or not _aviso_muerte.visible:
			return
		_aviso_muerte.text = "Has muerto\nReapareces en %d..." % i


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
	if _muerto:
		return
	var h := slot_habilidades.obtener(index)
	if h:
		var d := dir if dir.length() > 0.1 else _ultima_direccion
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
func quitar_vida(cantidad: float, fuente: Node = null) -> void:
	if componente_vida:
		componente_vida.quitar_vida(cantidad, fuente)


## GestorNiveles llama esto tras cada cambio de nivel para que la cámara no
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

func parpadear(veces: int = 3, duracion: float = 0.1) -> void:
	# Matar el parpadeo anterior antes de arrancar uno nuevo: con golpes
	# más frecuentes que la duración del parpadeo (p. ej. la araña pegando
	# cada segundo), varios tweens quedaban vivos a la vez peleándose por
	# el mismo modulate — el jugador quedaba parpadeando sin parar (y a
	# veces teñido de rojo permanente si un tween moría a mitad de ciclo).
	if _tween_parpadeo and _tween_parpadeo.is_valid():
		_tween_parpadeo.kill()
		sprite.modulate = Color.WHITE
	_tween_parpadeo = create_tween()
	for i in veces:
		_tween_parpadeo.tween_property(sprite, "modulate", Color(1, 0.2, 0.2), duracion)
		_tween_parpadeo.tween_property(sprite, "modulate", Color.WHITE,        duracion)


func _on_vida_cambiada(nueva_vida: float) -> void:
	if nueva_vida < _vida_anterior:
		parpadear()
	_vida_anterior = nueva_vida
