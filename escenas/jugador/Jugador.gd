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
## Dirección hacia la que apuntó la última habilidad direccional lanzada —
## tiene prioridad sobre la dirección de movimiento para orientar el sprite
## (mismo patrón que Enemigo.direccion_mirada): lanzar una habilidad hacia
## un lado debe girar al personaje hacia ahí, aunque en ese instante siga
## caminando hacia otro (reportado: "el personaje no cambia su dirección
## hacia donde lanzó la habilidad"). Pulso de un solo fotograma — ver
## _aplicar_presentacion, que la consume y la limpia enseguida; lo que
## persiste después es _ultima_direccion, ya actualizada con este valor.
var direccion_mirada: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var slot_habilidades: SlotHabilidades = $SlotHabilidades
@onready var camara: Camera2D = $Camara
@onready var componente_atributos: AtributosComponente = $AtributosComponente
@onready var componente_animacion: AnimacionComponente = $AnimacionComponente
@onready var componente_energia: EnergiaComponente = $EnergiaComponente
@onready var _etiqueta_nombre: Label = $EtiquetaNombre

var _ultima_direccion: Vector2 = Vector2.RIGHT
## Posición del fotograma anterior — SOLO para inferir "caminando" en la
## réplica de OTRO jugador en mi pantalla (ver _physics_process), donde no
## hay velocity local propio para consultar. Mismo criterio que Enemigo.gd.
var _posicion_render_anterior: Vector2 = Vector2.ZERO
## Desplazamiento mínimo por fotograma físico para considerarse "caminando"
## en esa réplica (mismo valor que Enemigo.gd — ver ese archivo para el
## razonamiento completo: más bajo que cualquier velocidad real, incluso
## ralentizado).
const _UMBRAL_CAMINANDO_RED := 0.1

# ── Muerte / reaparición ─────────────────────────────────────────────────────
## Segundos entre morir y reaparecer en el punto de aparición del nivel.
const TIEMPO_REAPARICION := 5.0
## Invulnerabilidad al APARECER (conectarse, cambiar de nivel, reaparecer
## tras morir) — reportado: "al iniciar la conexion al servidor y cargar al
## jugador recibe daño pero nunca se de que es". El cuerpo ya existe y es
## atacable en el servidor mientras el cliente todavía está cargando el
## nivel y fundiendo desde negro, así que los mobs que quedaron cerca del
## punto de aparición pegan sin que se llegue a ver de dónde vino. Cubre
## esa ventana con margen (el fundido de GestorNiveles dura 0.3s por lado,
## más lo que tarde el celular en asentarse).
const TIEMPO_INVULNERABILIDAD_APARICION := 3.0
## Invulnerabilidad al REVIVIR tras morir — más larga que la de aparición:
## acá SÍ hay mobs reales y ya identificados alrededor (los que mataron al
## jugador), no la incertidumbre de un cliente recién cargando. Pedido del
## usuario: 5 segundos, sin poder ser objetivo de ningún mob mientras dura
## (ver VisionComponente._intentar_registrar).
const TIEMPO_INVULNERABILIDAD_REVIVIR := 5.0
var _muerto := false
## Colisiones originales, para restaurarlas al revivir (se apagan al morir
## para que los mobs pierdan al "cadáver" — su visión y sus golpes son
## físicos, así que sin colisión dejan de detectarlo y atacarlo solos).
var _capa_colision_original: int = 0
var _mascara_colision_original: int = 0

@export_group("Íconos de estado")
## Fila de íconos (veneno, lentitud, aturdido...) ENCIMA del jugador — mismo
## criterio visual que Enemigo._dibujar_iconos_estado_mob. Pedido del
## usuario: a veces no se daba cuenta de estar aturdido hasta mirar
## BarraBuffs (la fila fija de la esquina) y lo confundía con lag — esto
## vive EN EL MUNDO, pegado al propio personaje (y visible para cualquiera
## que lo mire, réplicas incluidas), así que se nota de un vistazo sin
## desviar la mirada a la esquina.
@export var tamano_icono_estado: float = 16.0
@export var separacion_iconos_estado: float = 3.0
## Separación entre el borde superior REAL del sprite (calculado, ver
## _altura_iconos_estado) y el borde inferior de la fila de íconos — mismo
## criterio que Enemigo.margen_iconos_estado. Antes esto era un número Y
## fijo a ojo (altura_iconos_estado=-50.0): se quedó desactualizado la
## primera vez que el sprite cambió de escala (perdió su scale=0.75 al
## arreglar el pixel art) y los íconos pasaron a dibujarse ADENTRO del
## sprite en vez de arriba — regresión real, la agarró
## prueba_iconos_estado_jugador.
@export var margen_iconos_estado: float = 4.0
const _COLOR_CONTORNO_ICONOS_ESTADO := Color(0.0, 0.0, 0.0, 0.9)

var _nodo_iconos_estado: Node2D = null
## BuffsComponente puede no existir todavía cuando el jugador arranca (recién
## se crea con el PRIMER debuff, ver EfectoVeneno/EfectoAturdir._anotar_
## icono) — mismo criterio de reintento que ya usan Enemigo.gd y BarraBuffs.gd
## para el mismo problema.
var _buffs_estado: BuffsComponente = null
var _buffs_activos_estado: Array[String] = []
const _INTERVALO_REINTENTO_BUFFS_ESTADO := 0.5
var _acumulador_reintento_buffs_estado := 0.0

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
##
## Cartel de nombre sobre el personaje (nodo real "EtiquetaNombre", ver
## Jugador.tscn — mismo patrón que "NombreJefe" en EnemigoGuardianQuebrado):
## el setter lo mantiene sincronizado en cada asignación, tanto la local
## (_ready) como la que llega por replicación del MultiplayerSynchronizer.
## Guardado con is_instance_valid() porque la replicación puede llegar antes
## de que el @onready de _etiqueta_nombre esté resuelto — para ese caso,
## _ready() vuelve a copiar el valor ya recibido una vez que el Label existe.
var nombre_visible: String = "":
	set(valor):
		nombre_visible = valor
		if is_instance_valid(_etiqueta_nombre):
			_etiqueta_nombre.text = valor

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
## Por debajo de esta distancia (px) entre la posición predicha localmente y
## el último eco del servidor, NO se corrige nada — ver el uso en
## _physics_process. Sin este margen, corregir hasta el último píxel de
## ruido normal de red se sentía como vibración al moverse.
const _UMBRAL_RECONCILIACION := 4.0
## Segundos que quedan de "copiar la posición del servidor tal cual, sin
## suavizar" — ver el uso en _physics_process y sincronizar_posicion_dura().
var _sincronizacion_dura := 0.0

## Llegada a un nivel nuevo: segundos que el jugador queda quieto y sin poder
## lanzar habilidades (ver bloquear_por_transicion). Acompaña a la
## invulnerabilidad del mismo largo, así el rato en que no podés defenderte
## es exactamente el mismo en que no te pueden pegar.
const TIEMPO_BLOQUEO_TRANSICION := 3.0
var _bloqueo_transicion := 0.0


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
			rpc_id(1, "_registrar_identidad_red", Utils.id_jugador_local(), nombre_visible, Utils.pin_conexion)
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
		if Utils.modo_bot:
			# Modo bot (tildado en MenuInicio, ver Utils.modo_bot): en vez de
			# suscribirse a la UI real, cuelga el cerebro autónomo (BotIA) que
			# llama _joystick_movimiento()/_activar_slot() por su cuenta —
			# pedido del usuario: probar el servidor con varias instancias de
			# Godot peleando solas contra los mobs del mapa.
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

	# Corre para CUALQUIER jugador (dueño local y réplicas): igual que el
	# nombre de un mob, es visible para cualquiera que lo mire, no solo el
	# dueño (ver _crear_iconos_estado).
	_crear_iconos_estado()

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


## Contador APARTE de _bloqueos_control: bloquea SOLO el movimiento
## (_pedir_mover_red lo respeta, ver ahí), nunca la activación de
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


## Solo reintenta encontrar BuffsComponente (ver _intentar_conectar_buffs_
## estado) — se crea recién con el primer debuff, no siempre existe todavía
## cuando el jugador arranca. Mismo criterio que Enemigo.gd/BarraBuffs.gd.
func _process(delta: float) -> void:
	if _buffs_estado != null or _nodo_iconos_estado == null:
		return
	_acumulador_reintento_buffs_estado += delta
	if _acumulador_reintento_buffs_estado >= _INTERVALO_REINTENTO_BUFFS_ESTADO:
		_acumulador_reintento_buffs_estado = 0.0
		_intentar_conectar_buffs_estado()


func _crear_iconos_estado() -> void:
	_nodo_iconos_estado = Node2D.new()
	_nodo_iconos_estado.name = "IconosEstadoJugador"
	_nodo_iconos_estado.position = Vector2(0.0, _altura_iconos_estado())
	add_child(_nodo_iconos_estado)
	_nodo_iconos_estado.draw.connect(_dibujar_iconos_estado)
	_intentar_conectar_buffs_estado()


## Y local (negativo = arriba) donde se apoya la fila de íconos, contra el
## borde superior REAL del sprite — mismo criterio que
## Enemigo._altura_iconos_estado(), ver el comentario de
## margen_iconos_estado para el porqué de calcularlo en vez de fijarlo.
func _altura_iconos_estado() -> float:
	if not sprite or not sprite.texture or sprite.vframes <= 0:
		return -(margen_iconos_estado + tamano_icono_estado)
	var alto_frame := (sprite.texture.get_height() / float(sprite.vframes)) * sprite.scale.y
	var borde_superior_sprite := sprite.position.y - alto_frame / 2.0
	return borde_superior_sprite - margen_iconos_estado - tamano_icono_estado


func _intentar_conectar_buffs_estado() -> void:
	if _buffs_estado != null:
		return
	var comp := get_node_or_null("BuffsComponente") as BuffsComponente
	if comp == null:
		return
	_buffs_estado = comp
	_buffs_estado.buff_agregado.connect(_al_cambiar_buffs_estado)
	_buffs_estado.buff_quitado.connect(_al_cambiar_buffs_estado)
	_al_cambiar_buffs_estado("")


## Se relee la lista completa en vez de agregar/quitar un id puntual —
## mismo criterio que Enemigo._al_cambiar_buffs_estado.
func _al_cambiar_buffs_estado(_id: String) -> void:
	_buffs_activos_estado = _buffs_estado.activos()
	if _nodo_iconos_estado:
		_nodo_iconos_estado.queue_redraw()


func _dibujar_iconos_estado() -> void:
	Utils.dibujar_iconos_estado(_nodo_iconos_estado, _buffs_estado, _buffs_activos_estado,
		tamano_icono_estado, separacion_iconos_estado, _COLOR_CONTORNO_ICONOS_ESTADO)


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
func _registrar_identidad_red(id: String, nombre: String, pin: String = "") -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id_dueño:
		return
	var id_limpio := id.strip_edges()
	var nombre_limpio := nombre.strip_edges().substr(0, 24)
	if nombre_limpio != "":
		nombre_visible = nombre_limpio
	# Con PIN, la identidad real la resuelve la CUENTA (nombre+PIN), no el
	# dispositivo: así el progreso sigue al nombre aunque cambie de celular
	# (ver GestorCuentas.resolver_cuenta). Sin PIN, comportamiento clásico:
	# el id del dispositivo tal cual.
	if pin.strip_edges() != "" and nombre_limpio != "":
		var id_cuenta: String = GestorCuentas.resolver_cuenta(nombre_limpio, pin.strip_edges(), id_limpio)
		if id_cuenta == "":
			# PIN incorrecto: avisar al dueño y desconectarlo — jugar con la
			# identidad "equivocada" (la del dispositivo) sería peor, porque
			# creería estar en su cuenta y estaría escribiendo otra partida.
			rpc_id(peer_id_dueño, "_rechazar_cuenta_red", "PIN incorrecto para '%s'." % nombre_limpio)
			var peer := multiplayer.multiplayer_peer
			if peer is ENetMultiplayerPeer:
				# call_deferred() NO alcanza acá: solo pospone al mismo
				# fotograma, no le da tiempo real a ENet de transmitir el
				# RPC reliable por la red antes del corte (verificado con
				# pruebas en vivo: el RPC nunca llegaba a destino, el
				# cliente se quedaba sin el aviso y reintentaba con el
				# mismo PIN malo para siempre). Con un timer real de por
				# medio hay varios ciclos de red de por medio para que el
				# paquete salga antes de cortar.
				get_tree().create_timer(0.3).timeout.connect(
					(peer as ENetMultiplayerPeer).disconnect_peer.bind(peer_id_dueño, false)
				)
			return
		id_unico = id_cuenta
		_expulsar_fantasma_de_la_misma_identidad()
		GestorGrupos.registrar_conectado(peer_id_dueño, nombre_visible, id_unico)
		return
	if id_limpio != "":
		id_unico = id_limpio
		_expulsar_fantasma_de_la_misma_identidad()
		GestorGrupos.registrar_conectado(peer_id_dueño, nombre_visible, id_unico)


## SERVIDOR: si YA existe otro Jugador vivo con la MISMA identidad (mismo
## id_unico, otro peer_id_dueño), esa es una conexión vieja/fantasma —
## reportado en juego real: "una copia del jugador se crea al spawnear y
## todos los mobs lo atacan a el mientras yo puedo moverme libremente".
## Pasa cuando una reconexión deja dos conexiones simultáneas para la misma
## identidad antes de que ENet detecte la vieja como muerta (confirmado:
## ocurrió justo tras reiniciar el servidor, cuando el cliente reintenta
## conectarse solo — ver Mundo._programar_reintento — y una de esas
## conexiones queda sin limpiar). La IA de los mobs ya tenía al fantasma
## como objetivo y sigue atacándolo, mientras el jugador de verdad (la
## conexión nueva) queda libre de aggro.
##
## Se desconecta al fantasma acá, apenas se confirma la identidad real (ANTES
## de cargar la partida) — disconnect_peer() dispara peer_disconnected en el
## próximo fotograma, y ServidorDedicado._al_desconectar ya hace toda la
## limpieza correcta (memoria de los mobs, volcar progreso, liberar el nodo):
## no hace falta duplicar nada de eso acá.
func _expulsar_fantasma_de_la_misma_identidad() -> void:
	var fantasma := _buscar_fantasma_de_la_misma_identidad()
	if fantasma == null:
		return
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer and fantasma.peer_id_dueño >= 0:
		# NO cortar sincrónico acá adentro — mismo problema ya documentado en
		# _rechazar_cuenta_red (ver ese comentario): esto corre DENTRO del
		# procesamiento del RPC _registrar_identidad_red de OTRO peer, y
		# cortar la conexión del fantasma en ese mismo instante deja a ENet
		# en un estado a medio actualizar por varios fotogramas — cualquier
		# RPC/replicación que en ese lapso le mande un paquete al fantasma
		# (equipo, posición de mobs, energía...) revienta con "Unable to
		# send packet... max channels: 0" (reportado en juego real: "cada
		# vez que presiono cualquier boton se rompe el juego"). Un timer
		# real (no call_deferred: eso solo pospone al mismo fotograma, no
		# alcanza) le da tiempo a ENet de terminar de resolver esta llamada
		# antes de procesar el corte.
		var id_a_expulsar: int = fantasma.peer_id_dueño
		get_tree().create_timer(0.3).timeout.connect(
			(peer as ENetMultiplayerPeer).disconnect_peer.bind(id_a_expulsar, false)
		)


## Separado de _expulsar_fantasma_de_la_misma_identidad() para poder probar
## la lógica de detección (la parte propensa a errores: encontrar al
## fantasma correcto, sin falsos positivos entre jugadores distintos ni
## falsos negativos consigo mismo) sin necesitar un ENetMultiplayerPeer real
## — ver pruebas/prueba_expulsar_fantasma_identidad.gd.
func _buscar_fantasma_de_la_misma_identidad() -> Node:
	for otro in get_tree().get_nodes_in_group("jugadores"):
		if otro == self or not ("id_unico" in otro) or not ("peer_id_dueño" in otro):
			continue
		if otro.id_unico == id_unico and otro.peer_id_dueño != peer_id_dueño:
			return otro
	return null


## CLIENTE (dueño): el servidor rechazó la cuenta (PIN incorrecto). Solo
## ANOTA el motivo — no toca la escena ni el peer acá: el disconnect_peer()
## que el servidor manda justo después de esto dispara
## multiplayer.server_disconnected en este cliente de todos modos, y
## Mundo._al_perder_conexion() es quien de verdad decide qué hacer al
## desconectarse (ver ese archivo). Si esta función TAMBIÉN cambiara de
## escena, competiría en una carrera contra ese mismo evento — normalmente
## la pierde, porque _al_perder_conexion() ya tenía el hábito de recargar
## Mundo.tscn y reintentar conectarse SOLO (el diseño "nunca se rinde" de
## este juego, ver Mundo.gd), reintentando con el MISMO PIN malo para
## siempre en vez de mostrar el error (bug encontrado en pruebas).
@rpc("authority", "reliable")
func _rechazar_cuenta_red(motivo: String) -> void:
	if Utils.en_red() and peer_id_dueño != multiplayer.get_unique_id():
		return
	GestorLogRed.registrar("Cuenta rechazada: %s" % motivo)
	Utils.error_conexion = motivo


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
	# Congelamiento pendiente de disparo (ver congelar_disparo_pendiente() /
	# HabilidadBase._congelar_real_red) — aparte de _bloqueos_control a
	# propósito: esto SÍ tiene que rechazar movimiento, pero NO debe hacer
	# que esta_bloqueado() rechace la propia habilidad que lo puso cuando
	# llegue a disparar.
	if _congelamientos_disparo > 0:
		return
	direccion = direccion_pedida


## Aviso de "parate ya" — reliable (a diferencia de _pedir_mover_red, que es
## unreliable_ordered: estado continuo donde un paquete de más no importa).
## Zonzeo de una sola vez, redundante con el bloqueo de verdad: la
## protección real contra "el proyectil nace desde una posición ya corrida"
## la da _bloqueos_control (ver HabilidadBase.activar()) — el SERVIDOR se
## bloquea a sí mismo al recibir _activar_red, y _pedir_mover_red() ya
## descarta cualquier pedido de movimiento mientras ese bloqueo esté
## activo. Confiar en que ESTE aviso llegara ANTES que _activar_red (mismo
## canal reliable, orden de envío) no alcanzaba: si el jugador retomaba el
## joystick apenas se descongelaba localmente (mismo instante en que se
## mandaba el disparo), ese "seguí moviéndome" viajaba por el canal
## UNRELIABLE de _pedir_mover_red, sin ninguna garantía de orden contra
## esto — el bug seguía pasando con el margen ya funcionando (reportado
## con Cepo/Trampa). Se deja igual porque no molesta: zonzeo temprano de
## "quedate quieto" nunca está de más mientras se resuelve el bloqueo real.
@rpc("any_peer", "reliable")
func _pedir_detener_red() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id_dueño:
		return
	direccion = Vector2.ZERO


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
			_aplicar_presentacion(velocity != Vector2.ZERO)
			# Ventana de sincronización DURA: se copia la posición
			# autoritativa tal cual, sin suavizar. Al cruzar un portal el
			# servidor te teletransporta al punto de aparición y SIGUE
			# moviendo el cuerpo con la última dirección de joystick que le
			# mandaste, mientras este cliente todavía está cargando el mapa
			# nuevo y fundiendo desde negro. Para cuando la pantalla se
			# levantaba ya había varias decenas de píxeles de diferencia, y
			# la reconciliación suave de abajo los recorría a la vista:
			# reportado como "sale unos 70 px a la derecha y después corrige
			# su posición". Acá la corrección ocurre con la pantalla todavía
			# tapada, así que no se ve nada.
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
			# Debajo del umbral: no corregir nada — reportado "el personaje
			# tiembla" al mover con el servidor ya a 60 ticks/s (el doble de
			# ecos de posición por segundo que antes): cada eco nuevo,
			# aunque sea de 1-2px de diferencia con la predicción local,
			# disparaba una corrección visible; jugando seguido, eso se lee
			# como vibración en vez de fluidez. Un margen chico deja que la
			# predicción local mande sola mientras la diferencia sea
			# ruido de red normal, y sigue corrigiendo drift real por
			# encima del umbral.
			return
		# Réplica de OTRO jugador en mi pantalla: no hay velocity local que
		# consultar (nunca corre su componente_movimiento acá), así que
		# "caminando" se infiere del desplazamiento REAL en pantalla — mismo
		# criterio que Enemigo.gd con los mobs replicados. OJO con el ORDEN
		# (bug encontrado y corregido: quedaba SIEMPRE en 0, nunca animaba
		# — ver Enemigo._physics_process): el lerp que mueve global_position
		# va PRIMERO, recién después se mide cuánto se movió comparando
		# contra el valor de _posicion_render_anterior del fotograma
		# anterior. Calcularlo ANTES del lerp comparaba la posición contra
		# sí misma (nada había cambiado _posicion_render_anterior todavía
		# este fotograma), dando avance=0 siempre — se deslizaba a la
		# posición correcta pero JAMÁS entraba en la animación de caminar
		# (reportado: "se mueve en la dirección que mira, pero sin animación").
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


## Destello AMARILLO parpadeante mientras dura la protección de aparición o
## de revivir (ver TIEMPO_INVULNERABILIDAD_APARICION/_REVIVIR): sin señal
## visible, "no recibo daño" es indistinguible de "los mobs no me ven
## todavía" — y peor, al cortarse la protección el primer golpe llegaría de
## la nada. Pisa el modulate ENTERO (color + alpha) del sprite — a
## diferencia de antes (que solo tocaba el alpha para no pelearse con
## parpadear()), esto es seguro porque mientras es invulnerable quitar_vida
## corta ANTES de aplicar daño, así que cambio_valor_vida nunca dispara con
## una baja de vida real y parpadear() nunca corre en simultáneo (ver
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
		# Parpadeo DURO (no un latido suave): cambia de opaco a semitransparente
		# cada 0.25s en punto — pedido del usuario, más lento y más marcado
		# que el pulso continuo de antes. Siempre teñido de amarillo.
		var fase := int(Time.get_ticks_msec() / 250) % 2
		var alpha := 1.0 if fase == 0 else 0.4
		sprite.modulate = Color(1.0, 1.0, 0.0, alpha)
		_estaba_invulnerable = true
	elif _estaba_invulnerable:
		# Una sola vez al terminar (no cada fotograma): devolver el color
		# normal.
		sprite.modulate = Color.WHITE
		_estaba_invulnerable = false


## Fase 1 del plan de escalado a MMO (interés espacial): mismo patrón que
## Enemigo._physics_process — antes esto viajaba por MultiplayerSynchronizer
## en modo ALWAYS (sin throttle, a TODOS los peers, cada tick de sync); con
## 100 jugadores dispersos por el mapa era tráfico O(jugadores²). Ahora es
## un RPC manual, con el mismo throttle por cambio + keepalive que ya usan
## los mobs, dirigido SOLO a los peers que tienen a este jugador cerca (ver
## InteresEspacial) — a quien está del otro lado del mapa no le llega nada.
var _ultima_pos_enviada := Vector2.INF
## Sin esto, la réplica de un jugador en la pantalla de OTRO nunca se
## enteraba hacia dónde miraba — solo se replicaba la posición. Se quedaba
## siempre mirando a la derecha (el valor inicial de _ultima_direccion),
## incluso parado justo después de caminar hacia otro lado (reportado).
## Mismo patrón que Enemigo._recibir_estado_red, que sí manda "direccion".
var _ultima_dir_enviada := Vector2.INF
var _fotogramas_sin_enviar_pos := 0
const _FOTOGRAMAS_KEEPALIVE_POS := 30

func _replicar_posicion_red() -> void:
	_fotogramas_sin_enviar_pos += 1
	# Se manda _ultima_direccion (no "direccion" cruda): "direccion" es SOLO
	# la del joystick, cero en cuanto el jugador se detiene o lanza una
	# habilidad quieto — un giro por apunte de habilidad (ver
	# HabilidadBase.activar) nunca viajaba a los demás porque no había
	# movimiento que lo acompañara (reportado: "la dirección solo cambia en
	# el local"). _ultima_direccion ya tiene la prioridad correcta resuelta
	# (apunte > movimiento > última) — ver _aplicar_presentacion.
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


## unreliable_ordered: es estado continuo (~60 veces/seg) — un paquete
## perdido no importa, el siguiente lo corrige (mismo criterio que
## Enemigo._recibir_estado_red). "dir" viaja como _ultima_direccion del
## emisor (ver _replicar_posicion_red) — casi siempre distinto de cero, así
## que acá alcanza con guardarlo tal cual para que _aplicar_presentacion lo
## use directo como "direccion" (misma prioridad, sin caer a su propio
## _ultima_direccion local, que para una réplica nunca se actualizaría solo).
##
## OJO: este RPC también le llega de vuelta al propio DUEÑO (eco de su
## posición — ver _replicar_posicion_red/InteresEspacial, a propósito, para
## la reconciliación de _posicion_replicada). Para el dueño, "direccion" NO
## es un dato de orientación: es el input real que la rama de predicción
## local de _physics_process usa para mover el cuerpo. Pisarlo acá con el
## eco de red lo corrompía: _ultima_direccion casi nunca es CERO (una vez
## que te moviste, se queda apuntando para siempre — ver
## _aplicar_presentacion), así que apenas soltabas el joystick, el próximo
## eco volvía a poner "direccion" en esa dirección vieja y el cuerpo seguía
## caminando/deslizándose solo hacia allá sin que el jugador tocara nada
## (reportado: "en local se queda animando el caminar", y al lanzar una
## habilidad —que además fuerza esa dirección al apuntar— "se mueve sin
## animación hasta que sueltas el botón"). Para la réplica de OTRO jugador
## esto no aplica: ahí "direccion" es puramente orientación (nunca mueve el
## cuerpo, ver rama correspondiente de _physics_process), así que sigue
## haciendo falta guardarlo.
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
		# Girar a mirar hacia donde se lanza — reportado: "el personaje no
		# cambia su dirección hacia donde lanzó la habilidad". Solo si esta
		# habilidad de verdad usa una dirección (requiere_direccion): un
		# botón sin apuntar (curación, escudo…) no debería hacer girar al
		# personaje hacia el último rumbo que tenía el joystick.
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


## GestorNiveles llama esto tras cada cambio de nivel para que la cámara no
## muestre el vacío fuera del mapa. rect vacío (nivel sin Terreno) = sin límite.
## Copia la posición autoritativa TAL CUAL (sin interpolar) durante "segundos".
## La usa GestorNiveles al cambiar de nivel, para que el reacomodo ocurra
## mientras la pantalla está en negro y no se vea el personaje deslizándose.
## Nunca acorta una ventana ya en curso más larga.
func sincronizar_posicion_dura(segundos: float) -> void:
	_sincronizacion_dura = maxf(_sincronizacion_dura, segundos)


## Llegada a un nivel nuevo: deja al jugador QUIETO y sin poder lanzar
## habilidades durante "segundos", y le da invulnerabilidad por el mismo rato.
##
## El pedido fue explícito: sin movimiento durante la transición de mapa, y
## que ese rato sin poder actuar coincida con el rato en que nadie puede
## pegarte. La invulnerabilidad además te saca de la mira de los mobs (ver
## VisionComponente._intentar_registrar), así que aterrizás en un mapa nuevo
## sin que nada te esté pegando mientras la pantalla todavía funde.
##
## Se llama en los DOS lados (servidor y cliente dueño): el servidor es la
## autoridad del movimiento y del daño, el cliente bloquea su propia UI. No
## hace falta que arranquen en el mismo instante — la ventana es generosa.
func bloquear_por_transicion(segundos: float = TIEMPO_BLOQUEO_TRANSICION) -> void:
	_bloqueo_transicion = maxf(_bloqueo_transicion, segundos)
	if componente_vida:
		componente_vida.activar_invulnerabilidad(segundos)


## true mientras el jugador no puede actuar: muerto, recién llegado a un
## nivel nuevo, o con el control tomado (aturdido, canal de Ráfaga/
## Lanzallamas en curso...). Único lugar que decide esto — lo consultan la
## UI de habilidades, el manejo de toques y la autoridad del servidor.
## _bloqueos_control se sumó acá porque, sin esto, un toque NUEVO mientras
## el jugador estaba aturdido armaba igual el joystick de apuntado
## (UIHabilidad._dueño_muerto ya consultaba esta función) — se veía como si
## la habilidad fuera a salir, y en el fondo HabilidadBase.activar() ya lo
## iba a bloquear igual (mismo bug que ya se había resuelto para _muerto,
## pedido del usuario: "bloquear las habilidades mientras siga aturdido").
func esta_bloqueado() -> bool:
	return _muerto or _bloqueo_transicion > 0.0 or _bloqueos_control > 0


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

## Un solo parpadeo por golpe (antes eran 3 seguidos — pedido del usuario,
## mismo cambio en Enemigo.gd). Mata cualquier tween anterior antes de
## arrancar uno nuevo: con golpes más frecuentes que la duración del
## parpadeo (p. ej. la araña pegando cada segundo), dos tweens vivos a la
## vez se peleaban por el mismo modulate — el jugador quedaba parpadeando
## sin parar (y a veces teñido de rojo permanente si un tween moría a
## mitad de ciclo).
func parpadear(duracion: float = 0.1) -> void:
	if _tween_parpadeo and _tween_parpadeo.is_valid():
		_tween_parpadeo.kill()
		sprite.modulate = Color.WHITE
	_tween_parpadeo = create_tween()
	_tween_parpadeo.tween_property(sprite, "modulate", Color(1, 0.2, 0.2), duracion)
	_tween_parpadeo.tween_property(sprite, "modulate", Color.WHITE,        duracion)


## _es_dueño_local(): "cambio_valor_vida" se emite en TODOS los peers que
## tienen a este jugador replicado (ver VidaComponente._recibir_vida_red,
## que la dispara al final sin importar quién la reciba) — sin este
## chequeo, cuando un jugador recibía daño, CUALQUIERA que lo tuviera en
## pantalla lo veía parpadear también. Pedido del usuario: que sea un
## feedback solo para quien de verdad recibe el golpe, no algo que vean
## los demás jugadores mirando a ese jugador. Mismo criterio que el
## parpadeo "por mi propio golpe" en Enemigo.gd, pero del lado de quien
## RECIBE en vez de quien pega.
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
