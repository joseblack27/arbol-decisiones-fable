extends CharacterBody2D
class_name Enemigo

# =============================================================================
# 🧠 ENEMIGO — CLASE BASE
# Contiene solo la lógica común a todos los tipos de enemigo:
# componentes, memoria, visión, vida y física.
# Las habilidades van en cada subclase (EnemigoLobo, EnemigoRapido…).
# =============================================================================

## Capa física de obstáculos creados por habilidades del jugador (ver
## Muro.CAPA_BLOQUEO): todos los mobs la incluyen en su collision_mask para
## chocar contra ellos cuando bloquean; el jugador no la incluye en la suya,
## así que nunca queda atrapado por sus propias habilidades.
const CAPA_OBSTACULOS_HABILIDAD := 4

## Los mobs viven en su propia capa física (CAPA_MOB, fijada por CÓDIGO en
## _ready — no confiar en los .tscn: EnemigoLobo/Araña/Caballero/Raton son
## escenas independientes, no heredan de enemigo.tscn, y sus raíces seguían
## en la capa 1 — por eso "el dash chocaba en seco con los enemigos" aunque
## la base ya estuviera en la 2). Máscara: mundo (1) + Muro (4). Nadie choca
## con nadie: mob-mob no (ni capa 2 ni 8 en la máscara), mob-jugador no (el
## jugador vive en la capa 8, ver Jugador.tscn, y su máscara es solo 1).
## El daño entre mobs ya estaba bloqueado aparte, por equipo (ver
## Combate.mismo_equipo — ambos en el grupo "enemigos" cuentan como aliados).
const CAPA_MOB := 2
const CAPA_MUNDO := 1

const _FUENTE_NOMBRE := preload("res://assets/fonts/jet brain mono/JetBrainsMono-Medium.ttf")
const _COLOR_CONTORNO_NOMBRE := Color(0.0, 0.0, 0.0, 0.9)
## 2 con fuente 8 es el punto de equilibrio, verificado sobre terreno claro Y
## oscuro (ver BarraVidaEnergiaComponente, de donde se heredó este valor).
const _GROSOR_CONTORNO_NOMBRE := 2

## Cuánto más cerca (en px) tiene que estar un candidato nuevo para robarle
## el objetivo al actual — ver _evaluar_objetivo.
const MARGEN_CAMBIO_OBJETIVO := 40.0

# --- Componentes ---
@export var componente_vida: VidaComponente
@export var componente_maquina_de_estados: MaquinaDeEstadosComponente
@export var componente_movimiento: MovimientoComponente
@export var componente_vision: VisionComponente
@export var componente_animacion: AnimacionComponente
@export var memoria: MemoriaBT

@export var datos: EnemigoDatos
@export_range(0.0, 1.0, 0.05) var umbral_vida_baja: float = 0.3

@export_group("Objetivo por vida baja")
## Bajo qué fracción de vida un CANDIDATO/objetivo detectado se vuelve
## "tentador" para que el mob lo prefiera aunque no sea el más cercano (ver
## _tienta_por_vida_baja). Es la vida de ese candidato, no la propia del
## mob (eso es umbral_vida_baja, arriba).
@export_range(0.0, 1.0, 0.05) var umbral_vida_tentadora: float = 0.35
## Probabilidad de preferir a un candidato tentador en vez del criterio de
## distancia de siempre. 0 = nunca tienta (el criterio queda sin efecto),
## 1 = siempre que haya alguien por debajo del umbral. Pedido de diseño:
## "atacar por probabilidad a quien tenga menos vida" — se SUMA al
## criterio de distancia existente, no lo reemplaza.
@export_range(0.0, 1.0, 0.05) var probabilidad_rematar_vida_baja: float = 0.5

@export_group("Nombre")
## "Nv.X Nombre" arriba del mob, leído de EnemigoDatos. Vive ACÁ (no en
## BarraVidaEnergiaComponente, donde estaba antes) porque el nombre es una
## propiedad de la ENTIDAD, no de sus barras de vida/energía — quedaba raro
## que un mob sin EnergiaComponente (que ya oculta esa barra sola) pudiera
## arrastrar el nombre con ella el día que alguien quisiera ocultarla aparte.
## Sin "datos" asignado (p. ej. AliadoInvocado) no se dibuja nada.
@export var mostrar_nombre: bool = true
## Dorado en los jefes (ver EnemigoJefeEsqueleto) para diferenciarlos de un
## vistazo; blanco por defecto en el resto.
@export var color_nombre: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var tamano_fuente_nombre: int = 8
## Y local (relativo al origen del enemigo) donde se apoya la base del
## texto. Cada mob tiene un tamaño de sprite distinto — ver overrides en
## Araña (-37) y Ratón (-27), más chicos que el resto (-53).
@export var altura_nombre: float = -53.0

@export_group("Íconos de estado")
## Fila de íconos (veneno, lentitud, aturdido...) ENCIMA del nombre — pedido
## del usuario: "una barra de estados así como los efectos del jugador, para
## saber cuando está aturdido, ralentizado, o tenga algún efecto presente".
## Se dibujan con el mismo BuffsComponente que ya llenan Veneno/Lentitud/
## Aturdido (ver esos scripts) — nada que registrar acá por tipo.
@export var tamano_icono_estado: float = 16.0
@export var separacion_iconos_estado: float = 3.0
## Separación entre el borde superior del texto del nombre y el borde
## inferior de los íconos.
@export var margen_iconos_estado: float = 4.0

## Ítems que este enemigo puede soltar al morir — van directo al inventario
## del jugador (GestorInventario), nunca quedan tirados en el suelo. Cada
## entrada tiene su propia probabilidad independiente; puede soltar varias
## a la vez (o ninguna). Export directo aquí (no en EnemigoDatos) para no
## depender de tener ese recurso asignado.
@export var tabla_botin: Array[LootDrop] = []

## Experiencia otorgada al jugador (GestorExperiencia) al morir. Todavía sin
## tabla de niveles: por ahora solo se acumula.
@export var xp_otorgada: int = 10

var direccion: Vector2 = Vector2.ZERO
## Hacia dónde debería apuntar/mirar el enemigo (habilidades, torso) cuando
## difiere de hacia dónde camina — p. ej. en combate, siempre mirando al
## jugador aunque el pathfinding lo haga rodear un árbol de costado o hacia
## atrás. Vector2.ZERO = sin preferencia, usar "direccion" (de movimiento)
## también para apuntar, como en deambular/perseguir.
var direccion_mirada: Vector2 = Vector2.ZERO
var esta_atacando: bool = false

## Quién dio el último golpe — normalmente el mismo Node que las
## habilidades pasan como "fuente" a BusEventos.daño_aplicado (el jugador
## dueño, un Muro, etc.). Fase 4 del plan de multijugador: el botín/XP se le
## reparte a ESTE atacante puntual, no "al primer jugador de la escena" (que
## era lo que hacían GestorInventario/GestorExperiencia antes de esto —
## incorrecto en cuanto hay más de un jugador conectado).
var _ultimo_atacante: Node = null

## true desde el primer instante de _on_muerte (antes incluso del fotograma
## diferido de _procesar_muerte) — cualquier sistema con su PROPIO bucle de
## física independiente del árbol de comportamiento (p. ej. HabilidadCarga
## durante el dash, que mueve el cuerpo directo en su _physics_process, sin
## pasar por MovimientoComponente) debe consultar esto para cortarse solo:
## apagar arbol.activo no lo alcanza, porque esas habilidades no tickean por
## el árbol una vez activadas.
var _muerto: bool = false

@onready var habilidades: Marker2D = $Habilidades
## Para el parpadeo de "recibí daño" (ver parpadear()) — mismo nodo que ya
## usa cada subclase para su propia animación (AnimacionComponente).
@onready var sprite: Sprite2D = $Sprite2D
var _tween_parpadeo: Tween = null

var _texto_nombre: String = ""
## Nodo de dibujo puro para el nombre — SIN script propio: no es otro
## "componente" reutilizable, es la entidad dibujando su propio nombre. Se
## crea por código en _ready() (no en el .tscn) para no tener que tocar las
## 7 escenas, y a propósito DESPUÉS de que Sprite2D ya existe: Godot pinta
## hermanos en orden de árbol, así que quedar último garantiza dibujarse
## ENCIMA del sprite (si viviera en el _draw() de esta misma raíz, Godot
## pinta el contenido propio de un nodo ANTES que el de sus hijos, y el
## nombre quedaría tapado por sprites grandes como el del Jefe Esqueleto).
var _nodo_nombre: Node2D = null

## BuffsComponente puede no existir todavía cuando el mob arranca (recién se
## crea con el PRIMER debuff, ver EfectoVeneno._anotar_icono y similares) —
## por eso se reintenta cada _INTERVALO_REINTENTO_BUFFS en vez de buscarlo
## una sola vez, mismo criterio que BarraBuffs.gd (la versión del jugador).
var _buffs: BuffsComponente = null
var _buffs_activos: Array[String] = []
const _INTERVALO_REINTENTO_BUFFS := 0.5
var _acumulador_reintento_buffs := 0.0


## Fase 6: lo que se replica NO es global_position directo — es esta
## variable, para poder interpolar del lado del cliente (ver _physics_process)
## en vez de saltar de golpe a cada actualización de red.
var _posicion_replicada: Vector2 = Vector2.ZERO
## Posición del fotograma anterior en un cliente puro — para inferir
## "caminando" del desplazamiento REAL en pantalla (ver _physics_process).
var _posicion_render_anterior: Vector2 = Vector2.ZERO
## Desplazamiento mínimo por fotograma físico para considerarse "caminando"
## en un cliente (0.1px/frame ≈ 6px/s, muy por debajo de cualquier
## velocidad real de mob, incluso ralentizado).
const _UMBRAL_CAMINANDO_RED := 0.1
# Antes en 12.0, luego en 20.0: con cada valor el mob visual del cliente
# queda un poco MÁS atrás de su posición real en el servidor (constante de
# tiempo ≈ 1/valor: ~50ms de rezago con 20.0). Ese rezago es justo la causa
# de "el proyectil impacta pero no hace daño" en red — el disparo del
# cliente conecta contra la posición ATRASADA que ve, pero el servidor (el
# único que decide el daño real) simula el mismo tiro contra la posición
# REAL y actualizada, que para cuando el proyectil llega ya se movió más
# allá. 30.0 (~33ms de rezago) es una mitigación PARCIAL: reduce cuánto se
# nota, no lo elimina — solución completa requeriría rebobinar la posición
# en el servidor al momento exacto del disparo (lag compensation/rollback),
# fuera de alcance de este cambio. Contrapartida de subir este valor: con
# paquetes perdidos o picos de lag, la corrección se nota un poco más
# (menos "amortiguada") que con 20.0.
const VELOCIDAD_INTERPOLACION_RED := 30.0

## Último estado replicado por RPC — para no reenviar lo mismo cada physics
## frame cuando el mob está quieto (con varios mobs idle era tráfico y
## deserialización de sobra en cada cliente, ~60 paquetes/seg POR MOB).
var _ultima_pos_enviada := Vector2.INF
var _ultima_dir_enviada := Vector2.INF
var _ultima_mirada_enviada := Vector2.INF
var _fotogramas_sin_enviar := 0
## Quiénes tenían a este mob dentro de RADIO_INTERES el fotograma anterior —
## para detectar un peer RECIÉN entrado y mandarle su primer estado real de
## inmediato (ver más abajo), en vez de esperar al próximo cambio real o al
## keepalive (hasta _FOTOGRAMAS_KEEPALIVE_RED fotogramas). Sin esto, un mob
## generado lejos y quieto por un buen rato (nada "cambia" para el chequeo de
## abajo) podía dejar a un jugador que recién se acerca sin ningún
## _recibir_estado_red hasta el próximo keepalive — mientras tanto, su cliente
## ya tiene el NODO creado (MultiplayerSpawner replica sin filtrar por
## distancia) pero con direccion/direccion_mirada todavía en el default de la
## escena, así que actualizar_blend()/_aplicar_presentacion() no tienen nada
## real que animar: el sprite queda pegado en la pose con la que se creó el
## nodo (reportado: "un lobo respawneado fuera del área jugable, al entrar
## se queda siempre con el mismo sprite").
var _peers_relevantes_anterior: Array[int] = []
## Aunque nada cambie, reenviar cada tanto igual (~2 veces/seg): el RPC es
## unreliable — si el último paquete antes de quedarse quieto se perdió, sin
## este keepalive el cliente quedaría desincronizado para siempre.
const _FOTOGRAMAS_KEEPALIVE_RED := 30



## Fase 5 del plan de multijugador: en red, todos los mobs son autoridad
## del SERVIDOR (nunca de un peer puntual, a diferencia del Jugador). La
## posición se replica por RPC explícito (ver _physics_process/_recibir_
## posicion_red) en vez de un MultiplayerSynchronizer: para mobs YA
## PRESENTES en el nivel (colocados a mano en el .tscn, no spawneados por
## MultiplayerSpawner) un Synchronizer armado por código nunca llegó a
## sincronizar nada de forma confiable en pruebas reales — el mob se movía
## del lado del servidor pero el cliente quedaba congelado en su posición
## de spawn para siempre. RPC directo, con el mismo patrón ya probado en
## _despawn_red, es más simple y sí funciona.
func _enter_tree() -> void:
	if not Utils.en_red():
		return
	_posicion_replicada = global_position


func _ready() -> void:
	add_to_group("enemigos")
	collision_layer = CAPA_MOB
	collision_mask = CAPA_MUNDO | CAPA_OBSTACULOS_HABILIDAD
	_posicion_render_anterior = global_position
	_aplicar_datos()
	_crear_nombre_mob()
	# ── Memoria inicial ───────────────────────────────────────────────────────
	memoria.establecer("agente",                        self)
	memoria.establecer("componente_movimiento",         componente_movimiento)
	memoria.establecer("componente_vision",             componente_vision)
	memoria.establecer("componente_maquina_estados",    componente_maquina_de_estados)
	memoria.establecer("objetivo",                      null)
	memoria.establecer("jugador_detectado",             false)
	memoria.establecer("en_combate",                    false)
	memoria.establecer("en_recuperacion",               false)
	memoria.establecer("esta_huyendo",                  false)
	memoria.establecer("huida_en_cooldown",             false)
	memoria.establecer("tiempo_cooldown_huida",         0.0)

	if componente_vida:
		memoria.establecer("vida",      componente_vida.obtener_vida())
		memoria.establecer("vida_baja", false)
		memoria.establecer("vida_cero", false)
		componente_vida.cambio_valor_vida.connect(_on_vida_cambiada)
		componente_vida.muerte.connect(_on_muerte)

	BusEventos.daño_aplicado.connect(_on_daño_aplicado)

	if componente_vision:
		componente_vision.objetivo_detectado.connect(_on_objetivo_detectado)
		componente_vision.objetivo_perdido.connect(_on_objetivo_perdido)

	memoria.variable_cambiada.connect(_on_memoria_variable_cambiada)

	if componente_maquina_de_estados:
		componente_maquina_de_estados.cambiar_estado("EstadoIdle")


## Solo reintenta encontrar BuffsComponente (ver _intentar_conectar_buffs_
## estado) — se crea recién con el primer debuff, no siempre existe todavía
## cuando el mob arranca.
func _process(delta: float) -> void:
	if _buffs != null or _nodo_nombre == null:
		return
	_acumulador_reintento_buffs += delta
	if _acumulador_reintento_buffs >= _INTERVALO_REINTENTO_BUFFS:
		_acumulador_reintento_buffs = 0.0
		_intentar_conectar_buffs_estado()


func _physics_process(delta: float) -> void:
	# Fase 6: en red, el cliente nunca corre la IA de este mob (Fase 5), así
	# que nadie más mueve el cuerpo acá — solo interpola hacia la posición
	# replicada por el servidor. La PRESENTACIÓN (rotación de apuntado,
	# orientación del sprite, caminar/reposo) la calcula el propio cliente
	# con EXACTAMENTE el mismo código que el servidor (_aplicar_presentacion)
	# a partir del estado crudo replicado: direccion y direccion_mirada. Así
	# no hay dos lógicas visuales que mantener sincronizadas — un mob que
	# huye mira hacia donde huye, un kiter apunta al jugador, etc., igual
	# que en un solo jugador.
	if Utils.en_red() and not multiplayer.is_server():
		var diferencia := _posicion_replicada - global_position
		# Movimientos bruscos (el dash del lobo cruza media pantalla en
		# fotogramas) dejan a la interpolación suave MUY atrás: el golpe
		# llegaba "desde lejos" y después el mob del cliente se arrastraba
		# lento hasta su posición real. Más allá de este umbral, saltar
		# directo — un teletransporte corto se ve mejor que un mob fantasma
		# pegando a distancia.
		if diferencia.length() > 50.0:
			global_position = _posicion_replicada
		else:
			global_position = global_position.lerp(
				_posicion_replicada, clampf(delta * VELOCIDAD_INTERPOLACION_RED, 0.0, 1.0)
			)
		# "Caminando" se infiere del desplazamiento REAL de este fotograma
		# (no hay velocity local en un cliente). OJO: antes se usaba la
		# BRECHA de interpolación (diferencia > 1.0px) — pero un mob lento
		# (p. ej. ralentizado al 50% por EfectoLentitud: 40px/s ≈ 0.67px
		# por fotograma) avanza menos de lo que la interpolación alcanza a
		# cerrar, la brecha quedaba bajo el umbral y el cliente lo animaba
		# en IDLE aunque seguía avanzando ("no entiendo porque no sigue
		# usando la animacion de caminar" — reportado). Medir cuánto se
		# movió de verdad en pantalla no depende de qué tan al día vaya la
		# interpolación.
		var avance := global_position.distance_to(_posicion_render_anterior)
		_posicion_render_anterior = global_position
		_aplicar_presentacion(avance > _UMBRAL_CAMINANDO_RED)
		return

	var tiempo_cd: float = memoria.obtener("tiempo_cooldown_huida", 0.0)
	if tiempo_cd > 0.0:
		var nuevo_cd := maxf(tiempo_cd - delta, 0.0)
		memoria.establecer("tiempo_cooldown_huida", nuevo_cd)
		if nuevo_cd <= 0.0:
			memoria.establecer("huida_en_cooldown", false)

	if componente_maquina_de_estados:
		componente_maquina_de_estados.procesar_estado(delta)

	_aplicar_presentacion(velocity != Vector2.ZERO)

	# El servidor (o el único jugador, sin red) es la autoridad — replica el
	# ESTADO CRUDO (posición + direcciones), no resultados visuales: el
	# cliente corre la misma _aplicar_presentacion con estos datos.
	_posicion_replicada = global_position
	if Utils.en_red() and multiplayer.is_server():
		_fotogramas_sin_enviar += 1
		var cambio := global_position.distance_squared_to(_ultima_pos_enviada) > 0.25 \
			or direccion != _ultima_dir_enviada \
			or direccion_mirada != _ultima_mirada_enviada
		var peers_relevantes := InteresEspacial.peers_cercanos(global_position)
		var peers_nuevos: Array[int] = []
		for peer_id in peers_relevantes:
			if not _peers_relevantes_anterior.has(peer_id):
				peers_nuevos.append(peer_id)
		_peers_relevantes_anterior = peers_relevantes
		if cambio or _fotogramas_sin_enviar >= _FOTOGRAMAS_KEEPALIVE_RED:
			# Fase 1 del plan de escalado a MMO (interés espacial): antes esto
			# era rpc() — broadcast a TODOS los peers conectados, sin importar
			# dónde estuvieran parados. Con 100 jugadores dispersos por el
			# mapa, cada mob mandaba su posición a jugadores que ni siquiera
			# lo tenían cerca — tráfico y costo de simulación que crecían como
			# mobs × jugadores. Ahora solo a quien lo tiene a RADIO_INTERES.
			for peer_id in peers_relevantes:
				rpc_id(peer_id, "_recibir_estado_red", global_position, direccion, direccion_mirada)
			_ultima_pos_enviada    = global_position
			_ultima_dir_enviada    = direccion
			_ultima_mirada_enviada = direccion_mirada
			_fotogramas_sin_enviar = 0
		elif not peers_nuevos.is_empty():
			# Peer recién entrado al radio de interés (ver el comentario largo
			# en _peers_relevantes_anterior) — no esperar a que "cambie" algo
			# ni al próximo keepalive: mandarle YA su primer estado real, sin
			# tocar el resto del throttle (no cuenta como el envío normal).
			for peer_id in peers_nuevos:
				rpc_id(peer_id, "_recibir_estado_red", global_position, direccion, direccion_mirada)


## ÚNICA lógica de presentación, compartida entre servidor/single-player y
## cliente replicado: rotación de apuntado (habilidades) y animación.
func _aplicar_presentacion(caminando: bool) -> void:
	# Apuntar con "direccion_mirada" si hay una preferencia explícita (p. ej.
	# AccionAtacar mirando al jugador durante el combate); si no, apuntar
	# hacia donde se está caminando, como antes.
	var hacia_donde_mirar := direccion_mirada if direccion_mirada != Vector2.ZERO else direccion
	if hacia_donde_mirar != Vector2.ZERO and not memoria.obtener("congelar_rotacion", false):
		habilidades.rotation = hacia_donde_mirar.angle()

	if componente_animacion:
		# Mientras dure un ataque con fases propias (p. ej. la pose del
		# Esqueleto Arquero o la mordida del Lobo, ver memoria["ataque_en_
		# curso"]), ESA habilidad es dueña de debeCaminar/debeIdle — este
		# bloque corre TODOS los fotogramas y, sin este chequeo, pisaba
		# debeIdle a true cada vez (el mob está quieto = caminando=false)
		# justo encima del debeIdle=false que la habilidad acababa de poner,
		# y el árbol de animación parpadeaba entre IDLE y su propio estado
		# (reportado con el arquero: "parpadeando entre idle y atacar").
		if not memoria.obtener("ataque_en_curso", false):
			componente_animacion.establecer_condicion("parameters/conditions/debeCaminar", caminando)
			componente_animacion.establecer_condicion("parameters/conditions/debeIdle",    not caminando)
		# El sprite se orienta con la MIRADA de combate cuando existe
		# (quieto entre ataques o kiteando debe VERSE mirando al objetivo);
		# fuera de combate, direccion_mirada es ZERO y cae a la dirección
		# de paseo/huida de siempre. Esto sí sigue corriendo durante un
		# ataque en curso: mantiene el blend space (incluido uno propio
		# como ATACAR, si está en params_blend_adicionales) orientado hacia
		# el objetivo.
		componente_animacion.actualizar_blend(hacia_donde_mirar)


## unreliable_ordered: es estado continuo (~60 veces/seg) — un paquete
## perdido no importa (el siguiente lo corrige), y así no compite con los
## RPCs reliable de combate/loot por ancho de banda.
@rpc("authority", "unreliable_ordered")
func _recibir_estado_red(pos: Vector2, dir: Vector2, mirada: Vector2) -> void:
	_posicion_replicada = pos
	direccion = dir
	direccion_mirada = mirada


# =============================================================================
# API PÚBLICA
# =============================================================================

func quitar_vida(cantidad: float, fuente: Node = null,
		tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO,
		critico: bool = false) -> void:
	if componente_vida:
		componente_vida.quitar_vida(cantidad, fuente, tipo, critico)


# =============================================================================
# SEÑALES DE COMPONENTES
# =============================================================================

## Con un solo jugador cerca esto se resuelve solo (el primero detectado es
## el único candidato). Con varios, no se queda con "el último que entró en
## rango" (comportamiento viejo, reportado como indeciso/errático) — ver
## _evaluar_objetivo.
func _on_objetivo_detectado(area: Area2D) -> void:
	memoria.establecer("jugador_detectado", true)
	_evaluar_objetivo(area)


## Sin objetivo todavía, el candidato nuevo se toma directo. Con uno ya
## puesto, se lo reemplaza si: (a) el nuevo tiene vida baja y "tienta" al
## mob por probabilidad a rematarlo en vez de seguir con el actual (ver
## _tienta_por_vida_baja — se SUMA al criterio de distancia, no lo
## reemplaza), o (b) está claramente más cerca (MARGEN_CAMBIO_OBJETIVO de
## histéresis) — sin este margen, dos jugadores a distancia parecida harían
## temblar al mob entre uno y otro cada vez que alguno entra o sale de rango.
func _evaluar_objetivo(candidato: Area2D) -> void:
	if not is_instance_valid(candidato) or not (candidato.owner is Node2D):
		return
	var nuevo := candidato.owner as Node2D
	var actual = memoria.obtener("objetivo")
	if not is_instance_valid(actual):
		memoria.establecer("objetivo", nuevo)
		return
	if actual == nuevo:
		return
	if _tienta_por_vida_baja(candidato):
		memoria.establecer("objetivo", nuevo)
		return
	var dist_actual := global_position.distance_to((actual as Node2D).global_position)
	var dist_nuevo := global_position.distance_to(nuevo.global_position)
	if dist_nuevo + MARGEN_CAMBIO_OBJETIVO < dist_actual:
		memoria.establecer("objetivo", nuevo)


## "jugador_detectado" refleja si queda ALGUIEN detectado, no solo si el área
## puntual que se acaba de ir era el único — antes, con dos jugadores cerca,
## que se fuera cualquiera de los dos (aunque no fuera el objetivo actual)
## apagaba la bandera igual y el mob se quedaba pasivo con el otro todavía
## ahí delante.
func _on_objetivo_perdido(area: Area2D) -> void:
	var quedan_candidatos := componente_vision and not componente_vision.areas_detectadas.is_empty()
	memoria.establecer("jugador_detectado", quedan_candidatos)

	var actual = memoria.obtener("objetivo")
	if not is_instance_valid(area) or not is_instance_valid(actual) or actual != area.owner:
		return
	# El que se fue era justo el objetivo actual: no abandonar la pelea de
	# golpe si queda alguien más cerca — retomar con el mejor candidato que
	# siga a la vista.
	memoria.establecer("objetivo", null)
	if quedan_candidatos:
		_retomar_mejor_objetivo()


## Se llama solo cuando el objetivo actual se acaba de perder Y quedan otros
## candidatos detectados — recorre lo que queda y se queda con el más cerca,
## salvo que alguno con vida baja "tiente" por probabilidad (mismo criterio
## que _evaluar_objetivo, ver _tienta_por_vida_baja); el primero que tienta
## en el recorrido gana, no hace falta que sea el más tentador de todos.
func _retomar_mejor_objetivo() -> void:
	var mejor: Node2D = null
	var mejor_dist := INF
	var tentado: Node2D = null
	for area in componente_vision.areas_detectadas.values():
		if not is_instance_valid(area) or not (area.owner is Node2D):
			continue
		var candidato := area.owner as Node2D
		if tentado == null and _tienta_por_vida_baja(area):
			tentado = candidato
		var dist := global_position.distance_to(candidato.global_position)
		if dist < mejor_dist:
			mejor_dist = dist
			mejor = candidato
	if tentado or mejor:
		memoria.establecer("objetivo", tentado if tentado else mejor)


## Un candidato con vida baja tiene una chance (probabilidad_rematar_vida_
## baja) de "tentar" al mob a preferirlo aunque no sea el más cercano — ver
## el export de arriba para el porqué. "area" es el Area2D que ya detectó
## VisionComponente — VidaComponente extends Area2D, así que es la MISMA
## área, no hace falta ir a buscar al dueño para llegar a su vida.
func _tienta_por_vida_baja(area: Area2D) -> bool:
	var vida := area as VidaComponente
	if vida == null or vida.obtener_vida_maxima() <= 0.0:
		return false
	if vida.obtener_vida() / vida.obtener_vida_maxima() > umbral_vida_tentadora:
		return false
	return randf() <= probabilidad_rematar_vida_baja


## Reacción a un golpe de alguien que NO es el objetivo actual — depende de
## si el mob lo tiene detectado (con visión real) en este instante:
##   - Detectado: pasa a ser el objetivo al instante (ya sabe bien dónde
##     está, puede perseguirlo de verdad).
##   - NO detectado (a distancia, detrás de un obstáculo, o desde
##     camuflaje — que igual se corta solo al atacar, ver CamuflajeComponente):
##     NO se convierte en un objetivo fantasma que el mob persigue a ciegas
##     sin haberlo visto — eso sería "detectarlo" a cualquier distancia con
##     solo golpearlo una vez. En cambio, deja un aviso de "ruido" que sesga
##     el PRÓXIMO paso de AccionDeambular hacia esa dirección (ver
##     AccionDeambular._elegir_destino), acotado igual al radio de
##     deambulación normal del mob — se ve como si fuera a mirar hacia
##     donde vino el golpe, sin que eso equivalga a detectar a esa
##     distancia. Pedido explícito del usuario: antes un golpe desde fuera
##     de la visión no generaba ninguna reacción, y eso volvía gratis
##     pegarle a un mob desde fuera de su rango de detección.
func _priorizar_atacante(fuente: Node) -> void:
	if not is_instance_valid(fuente) or fuente == self or not (fuente is Node2D):
		return
	if memoria.obtener("objetivo") == fuente:
		return
	# Mismo filtro de grupo que usa VisionComponente para detección normal
	# (grupos_objetivo) — un mob configurado para solo fijarse en
	# "jugadores" no debería reaccionar a cualquier otra fuente de daño.
	if componente_vision and not componente_vision.grupos_objetivo.is_empty():
		var en_grupo := componente_vision.grupos_objetivo.any(func(g): return fuente.is_in_group(g))
		if not en_grupo:
			return

	if componente_vision:
		for area in componente_vision.areas_detectadas.values():
			if is_instance_valid(area) and area.owner == fuente:
				memoria.establecer("objetivo",          fuente)
				memoria.establecer("jugador_detectado", true)
				return

	memoria.establecer("ruido_posicion", (fuente as Node2D).global_position)


func _on_vida_cambiada(nuevo_valor: float) -> void:
	memoria.establecer("vida", nuevo_valor)


## El daño ya lo aplica la propia habilidad internamente — aquí solo
## notificamos al BT. Nombre heredado de cuando solo lo conectaba el
## arañazo (ver _ready() de EnemigoLobo/EnemigoCaballeroEsqueleto, que la
## siguen cableando a SU HabilidadArañazo.habilidad_activada) — la lógica
## en sí no tiene nada de arañazo específico, por eso vive acá compartida
## en vez de repetida en cada subclase que la usa.
func _on_arañazo_activado(_habilidad: HabilidadBase) -> void:
	componente_animacion.establecer_condicion("parameters/conditions/debeIdle", true)
	memoria.establecer("habilidad_lanzada", true)


## En el cliente REAL (a diferencia del servidor/single-player, donde esto
## dispara al instante desde la propia habilidad) esta señal solo llega acá
## cuando VidaComponente._recibir_vida_red() confirma el daño replicado por
## el servidor — no antes. Por eso alcanza con este único chequeo para
## cumplir las dos condiciones pedidas: "esperar la confirmación real" Y
## "que sea mi propio golpe" (ver _es_mi_propio_golpe) — ambas ya vienen
## resueltas por cómo funciona esta señal, sin tocar Proyectil/Arañazo/
## HabilidadCarga/Combate para nada.
func _on_daño_aplicado(objetivo: Node, _cantidad: float, fuente: Node, _tipo: int = 2, _critico: bool = false) -> void:
	if objetivo == self:
		_ultimo_atacante = fuente
		if _es_mi_propio_golpe(fuente):
			parpadear()
		_priorizar_atacante(fuente)


## true si "fuente" es el jugador que controla ESTE cliente — el parpadeo
## de abajo es local a propósito (pedido del usuario: feedback de "mi
## golpe conectó" sin confundirse con los golpes de otros jugadores). Sin
## red (un solo jugador) cualquier golpe es siempre "propio".
func _es_mi_propio_golpe(fuente: Node) -> bool:
	if not is_instance_valid(fuente):
		return false
	if not Utils.en_red():
		return true
	if not ("peer_id_dueño" in fuente):
		return false
	return fuente.peer_id_dueño == multiplayer.get_unique_id()


## Un solo parpadeo (pedido del usuario — antes eran varios seguidos, ver
## el mismo cambio en Jugador.gd). Mata cualquier tween anterior antes de
## arrancar uno nuevo: con golpes más frecuentes que la duración del
## parpadeo, dos tweens vivos a la vez se pelean por el mismo modulate y
## el sprite queda trabado en rojo en vez de volver a blanco.
func parpadear(duracion: float = 0.1) -> void:
	if not sprite:
		return
	if _tween_parpadeo and _tween_parpadeo.is_valid():
		_tween_parpadeo.kill()
		sprite.modulate = Color.WHITE
	_tween_parpadeo = create_tween()
	_tween_parpadeo.tween_property(sprite, "modulate", Color(1, 0.2, 0.2), duracion)
	_tween_parpadeo.tween_property(sprite, "modulate", Color.WHITE, duracion)


## Getter público — mismo criterio que ObjetoRecolectable.esta_agotado():
## _muerto en sí es privado, pero quien necesita saber "¿este mob sigue
## vivo?" desde AFUERA (ej. Cazador._presa_mas_cercana()) no debería tocar
## el campo directo.
func esta_muerto() -> bool:
	return _muerto


func _on_muerte(_valor: float) -> void:
	_muerto = true
	memoria.establecer("vida_cero", true)
	memoria.establecer("vida",      0.0)
	# Apagar el cerebro y frenar el cuerpo: un muerto no decide ni camina.
	var arbol := get_node_or_null("ArbolComportamiento") as ArbolComportamiento
	if arbol:
		arbol.activo = false
	if componente_movimiento:
		componente_movimiento.detener()
	# El golpe que mata llega desde un callback de física (area_entered /
	# body_entered de Proyectil, Arañazo, GolpeBasico, AreaEfecto...). Repartir
	# botín, sumar XP e instanciar filas de notificación en ese mismo stack
	# se sintió como un tirón notable en Android — se difiere un fotograma
	# (call_deferred) para que ese trabajo corra fuera del paso de física.
	call_deferred("_procesar_muerte")


func _procesar_muerte() -> void:
	_otorgar_botin()
	if xp_otorgada > 0:
		_otorgar_xp(xp_otorgada)
	_notificar_objetivo_matar()
	_desvanecer_y_eliminar()


## Reparte tabla_botin directo al inventario de quien dio el último golpe
## — nunca queda tirado en el suelo. Cada entrada tira su propia
## probabilidad de forma independiente, así un mob puede soltar varias
## cosas a la vez (o ninguna).
func _otorgar_botin() -> void:
	for entrada in tabla_botin:
		if entrada == null or entrada.item == null:
			continue
		if randf() <= entrada.probabilidad:
			_otorgar_item_al_atacante(entrada.item)


## Le da el ítem al InventarioComponente de _ultimo_atacante si es un
## jugador identificable; si no (sin atacante registrado, un solo jugador
## sin componentes propios, etc.) cae al comportamiento de siempre —
## GestorInventario, que en esos casos apunta al único jugador que hay.
func _otorgar_item_al_atacante(item: DatosItem) -> void:
	var componente := _componente_del_atacante("InventarioComponente")
	if componente:
		componente.agregar_item(item)
	else:
		GestorInventario.agregar_item(item)
	var dueño := _peer_dueño_del_atacante()
	if dueño >= 0:
		var confirmaciones := _componente_del_atacante("ComponenteConfirmacionesRed")
		if confirmaciones:
			confirmaciones.rpc_id(dueño, "_recibir_botin_red", item.resource_path, item.quantity)


## Objetivos de misión tipo MATAR (ver MisionesComponente.notificar_matar)
## — mismo despacho DIRECTO que _otorgar_botin/_otorgar_xp, al
## MisionesComponente del atacante correcto, no un broadcast.
func _notificar_objetivo_matar() -> void:
	if datos == null:
		return
	var componente := _componente_del_atacante("MisionesComponente")
	if componente:
		componente.notificar_matar(datos)


func _otorgar_xp(cantidad: int) -> void:
	var componente := _componente_del_atacante("ExperienciaComponente")
	if componente:
		componente.agregar_xp(cantidad)
	else:
		GestorExperiencia.agregar_xp(cantidad)
	var dueño := _peer_dueño_del_atacante()
	if dueño >= 0:
		var confirmaciones := _componente_del_atacante("ComponenteConfirmacionesRed")
		if confirmaciones:
			confirmaciones.rpc_id(dueño, "_recibir_xp_red", cantidad)


func _componente_del_atacante(nombre_componente: String) -> Node:
	if not is_instance_valid(_ultimo_atacante):
		return null
	return _ultimo_atacante.get_node_or_null(nombre_componente)


## Peer id dueño de _ultimo_atacante, o -1 si no aplica (sin multiplayer
## activo, sin atacante identificado, servidor corriendo esto para otro
## servidor, etc.) — en ese caso no hay a quién avisarle por RPC, y el
## comportamiento sigue siendo el de siempre (todo local).
func _peer_dueño_del_atacante() -> int:
	if not Utils.en_red() or not multiplayer.is_server():
		return -1
	if not is_instance_valid(_ultimo_atacante) or not ("peer_id_dueño" in _ultimo_atacante):
		return -1
	return _ultimo_atacante.peer_id_dueño


## Hace desaparecer el cuerpo (queda en idle, se pone negro y luego se
## desvanece) y lo libera de verdad.
## NO se recicla (sin object pooling): un mob arrastra demasiado estado
## propio (memoria del árbol de comportamiento, agente de navegación,
## áreas de visión, cooldowns de habilidades) para reutilizarlo con
## garantías, y muere pocas veces por partida — a diferencia de un
## proyectil o un número de daño (ver GestorPiscinas), el coste de crear
## uno nuevo la próxima vez es insignificante.
##
## Quien necesite saber "este mob ya no existe" (p. ej. SpawnerMobs, para
## liberar un hueco) puede escuchar la señal nativa `tree_exiting`, que
## dispara justo cuando queue_free() lo retira de verdad — no hace falta
## una señal propia.
## Apaga la colisión del cuerpo Y de cualquier VidaComponente hijo (un
## Area2D con capas/máscara PROPIAS, independientes del cuerpo — zerar solo
## las del CharacterBody2D no alcanza). En mobs cuyo VidaComponente lleva
## forma de colisión real (Araña, Ratón — a diferencia de Lobo/Caballero,
## que detectan golpes solo por el cuerpo), sin esto el cadáver seguía
## siendo "golpeable" por esa área durante todo el fundido de 0.4s,
## consumiendo proyectiles/dashes del jugador contra un mob ya muerto
## (reportado: "aun chocan con las habilidades del jugador").
func _apagar_colision_de_muerto() -> void:
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if componente_vida:
		componente_vida.set_deferred("collision_layer", 0)
		componente_vida.set_deferred("collision_mask", 0)
		componente_vida.set_deferred("monitorable", false)
		componente_vida.set_deferred("monitoring", false)


func _desvanecer_y_eliminar() -> void:
	# Diferido: _on_muerte() puede llegar desde dentro de un callback de
	# física (un golpe cuerpo a cuerpo), donde cambiar capas de colisión
	# de golpe dispara "flushing queries".
	_apagar_colision_de_muerto()
	set_physics_process(false)
	velocity = Vector2.ZERO
	var barra := get_node_or_null("BarraVidaEnergia") as CanvasItem
	if barra:
		barra.hide()
	if componente_animacion:
		# Si murió a mitad de una animación puntual (ataque, etc.), esa
		# override tiene el AnimationTree apagado: cancelarla primero o las
		# condiciones de abajo no tendrían ningún efecto.
		componente_animacion.cancelar_override()
		# Fijar el blend en la última dirección mirada ANTES de que
		# _physics_process (que la actualizaba cada frame) se apague, para
		# que el idle quede mirando hacia donde miraba, quieto. MISMO criterio
		# que _aplicar_presentacion (no "direccion" a secas): un mob que
		# muere en combate suele estar mirando al jugador vía
		# direccion_mirada (AccionAtacar), no hacia donde caminó por última
		# vez — usar solo "direccion" giraba el cadáver hacia un lado
		# random al morir (reportado con la araña).
		var hacia_donde_mirar := direccion_mirada if direccion_mirada != Vector2.ZERO else direccion
		componente_animacion.actualizar_blend(hacia_donde_mirar)
		componente_animacion.establecer_condicion("parameters/conditions/debeCaminar", false)
		componente_animacion.establecer_condicion("parameters/conditions/debeIdle",    true)
	# Fase 5 del plan de multijugador: la réplica automática de "este nodo
	# desapareció" (que en teoría hace MultiplayerSpawner solo con el
	# queue_free() de más abajo) no le está llegando al cliente — se queda
	# viendo al mob quieto para siempre aunque el servidor ya lo haya
	# eliminado. En vez de perseguir esa causa, se avisa explícito por RPC
	# (mismo criterio ya probado con el loot/XP): confiable y fácil de
	# razonar, sin depender de un mecanismo interno que no está andando.
	if Utils.en_red() and multiplayer.is_server():
		rpc("_despawn_red")

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.BLACK, 0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


## El cliente recibe acá el aviso de que este mob murió del lado del
## servidor — reproduce el mismo desvanecido visual y se libera, sin volver
## a pasar por toda la lógica de muerte (botín, XP, etc., que ya se resolvió
## en el servidor).
@rpc("authority", "reliable")
func _despawn_red() -> void:
	_muerto = true
	_apagar_colision_de_muerto()
	if componente_animacion:
		# Mismo motivo que en _desvanecer_y_eliminar(): fijar el idle ANTES
		# de apagar _physics_process, o el cliente ve el desvanecido
		# congelado a mitad de la animación que estuviera corriendo
		# (caminar, ataque) en vez de quieto en reposo.
		componente_animacion.cancelar_override()
		# Mismo criterio que _desvanecer_y_eliminar(): direccion_mirada
		# primero (mirando al jugador en combate), direccion como respaldo.
		var hacia_donde_mirar := direccion_mirada if direccion_mirada != Vector2.ZERO else direccion
		componente_animacion.actualizar_blend(hacia_donde_mirar)
		componente_animacion.establecer_condicion("parameters/conditions/debeCaminar", false)
		componente_animacion.establecer_condicion("parameters/conditions/debeIdle",    true)
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.BLACK, 0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func _on_memoria_variable_cambiada(nombre: String, _anterior, _nuevo) -> void:
	if nombre != "vida":
		return
	var vida_actual: float = memoria.obtener("vida", 100.0)
	var vida_max: float    = componente_vida.obtener_vida_maxima() if componente_vida else 100.0
	var baja: bool = vida_actual > 0.0 and (vida_actual / vida_max) <= umbral_vida_baja
	memoria.establecer("vida_baja", baja)
	if baja and not memoria.obtener("jugador_detectado", false):
		# Validar ANTES de castear: un objetivo liberado (jugador
		# desconectado en red) revienta el "as" con "Trying to cast a freed
		# object" en vez de devolver null.
		var obj_raw = memoria.obtener("objetivo")
		if is_instance_valid(obj_raw):
			memoria.establecer("jugador_detectado", true)


## "Respiro" telegrafiado al cambiar de fase de un jefe multi-fase: apaga
## el árbol de comportamiento, frena el movimiento, fuerza la animación de
## reposo — y tras "duracion" segundos, si el jefe sigue vivo y en el
## árbol, reactiva el árbol y llama a "al_reanudar" con lo que haga falta
## agregar (habilidades nuevas, refuerzos, etc.). Compartido por los jefes
## con fases (EnemigoJefeEsqueleto, EnemigoArañaReina) — antes cada uno
## tenía su propia copia casi idéntica de este mismo patrón.
func _telegrafiar_pausa_de_fase(duracion: float, al_reanudar: Callable) -> void:
	var arbol := get_node_or_null("ArbolComportamiento") as ArbolComportamiento
	if arbol:
		arbol.activo = false
	if componente_movimiento:
		componente_movimiento.detener()
	if componente_animacion:
		componente_animacion.establecer_condicion("parameters/conditions/debeCaminar", false)
		componente_animacion.establecer_condicion("parameters/conditions/debeIdle", true)
	get_tree().create_timer(duracion).timeout.connect(func() -> void:
		if not is_inside_tree() or _muerto:
			return
		if arbol:
			arbol.activo = true
		al_reanudar.call())


# =============================================================================
# DATOS / PLANTILLA  (sobreescribir en subclases para stats propios)
# =============================================================================

func _aplicar_datos() -> void:
	if not datos:
		return
	if componente_vida:
		componente_vida.salud_maxima = datos.vida_maxima
		# VidaComponente._ready() (un HIJO — corre ANTES que este _ready() del
		# padre) ya fijó salud_actual = salud_maxima usando el valor por
		# DEFECTO del export (100.0), antes de que datos.vida_maxima pisara
		# salud_maxima acá arriba — sin este restaurar_vida(), un mob con
		# vida_maxima distinta de 100 (Caballero=150, Tanque=250, Rápido=60,
		# cualquier boss) arrancaba con la vida real vieja (100) aunque la
		# barra mostrara el máximo correcto. Bug real, no solo del jefe —
		# encontrado al armar uno con vida_maxima=400 (moría de 30 de golpe).
		componente_vida.restaurar_vida(datos.vida_maxima)
	if componente_movimiento:
		componente_movimiento.velocidad_base = datos.velocidad_base
	var comp_energia := get_node_or_null("EnergiaComponente") as EnergiaComponente
	if comp_energia:
		comp_energia.energia_maxima        = datos.energia_maxima
		comp_energia.regeneracion_por_tick = datos.regeneracion_energia
	# Si el mob tiene atributos, la regeneración por tick manda desde ahí
	# (ver EnergiaComponente._cantidad_regen) — escribir el valor de la
	# plantilla en el ATRIBUTO para que la plantilla siga siendo la fuente.
	var comp_atributos := get_node_or_null("AtributosComponente") as AtributosComponente
	if comp_atributos and comp_atributos.base:
		comp_atributos.base.regeneracion_energia = datos.regeneracion_energia
		# También en la copia "de fábrica": recalcular_con_equipo() parte de
		# ella — sin esto, cualquier recálculo revertiría el valor de la
		# plantilla (los mobs hoy no equipan nada, pero mejor no dejar la mina).
		if comp_atributos._base_sin_equipo:
			comp_atributos._base_sin_equipo.regeneracion_energia = datos.regeneracion_energia
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		spr.modulate = datos.color


## Sin "datos" (p. ej. un aliado invocado por el jugador) no se dibuja nada
## — mismo criterio que tenía antes BarraVidaEnergiaComponente.
func _crear_nombre_mob() -> void:
	if not mostrar_nombre or datos == null:
		return
	var nombre: String = datos.nombre_tipo.strip_edges()
	if nombre == "":
		nombre = String(name)
	_texto_nombre = ("Nv.%d %s" % [datos.nivel, nombre]) if datos.nivel > 0 else nombre
	if _texto_nombre == "":
		return

	_nodo_nombre = Node2D.new()
	_nodo_nombre.name = "NombreMob"
	_nodo_nombre.position = Vector2(0.0, altura_nombre)
	add_child(_nodo_nombre)
	_nodo_nombre.draw.connect(_dibujar_nombre_mob)
	# Los íconos de estado usan el MISMO nodo/draw que el nombre (no uno
	# aparte): así quedan garantizados en el mismo orden de dibujo, encima
	# del sprite, sin duplicar la lógica de "quedar último en el árbol" de
	# arriba.
	_nodo_nombre.draw.connect(_dibujar_iconos_estado_mob)
	_nodo_nombre.queue_redraw()
	_intentar_conectar_buffs_estado()


## Centrado sobre el mob. El texto puede ser más ancho que el sprite (nombres
## largos como "Caballero Esqueleto"), se centra igual y desborda parejo a
## los dos lados en vez de recortarse.
func _dibujar_nombre_mob() -> void:
	var ancho_texto := _FUENTE_NOMBRE.get_string_size(
		_texto_nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente_nombre).x
	var pos := Vector2(-ancho_texto / 2.0, 0.0)
	_nodo_nombre.draw_string_outline(_FUENTE_NOMBRE, pos, _texto_nombre,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente_nombre,
		_GROSOR_CONTORNO_NOMBRE, _COLOR_CONTORNO_NOMBRE)
	_nodo_nombre.draw_string(_FUENTE_NOMBRE, pos, _texto_nombre,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente_nombre, color_nombre)


func _intentar_conectar_buffs_estado() -> void:
	if _buffs != null:
		return
	var comp := get_node_or_null("BuffsComponente") as BuffsComponente
	if comp == null:
		return
	_buffs = comp
	_buffs.buff_agregado.connect(_al_cambiar_buffs_estado)
	_buffs.buff_quitado.connect(_al_cambiar_buffs_estado)
	_al_cambiar_buffs_estado("")


## Se relee la lista completa en vez de agregar/quitar un id puntual: son
## como mucho un puñado de íconos por mob, y así el orden en pantalla queda
## siempre el mismo que el de inserción real en BuffsComponente.
func _al_cambiar_buffs_estado(_id: String) -> void:
	_buffs_activos = _buffs.activos()
	if _nodo_nombre:
		_nodo_nombre.queue_redraw()


## Y local (dentro de NombreMob) donde se apoya la fila de íconos. El texto
## crece hacia arriba desde su línea base en y=0 (ver _dibujar_nombre_mob),
## así que la fila va más arriba todavía: por eso resta la altura REAL de
## la fuente (no un número fijo), y sigue quedando bien despegada del texto
## aunque cambie tamano_fuente_nombre. Función aparte (no inline en el
## _draw) para que se pueda verificar por fuera que el resultado da negativo
## de verdad — "arriba del nombre" en los hechos, no solo en la intención.
func _altura_iconos_estado() -> float:
	var altura_texto := _FUENTE_NOMBRE.get_height(tamano_fuente_nombre)
	return -(altura_texto + margen_iconos_estado + tamano_icono_estado)


func _dibujar_iconos_estado_mob() -> void:
	Utils.dibujar_iconos_estado(_nodo_nombre, _buffs, _buffs_activos,
		tamano_icono_estado, separacion_iconos_estado, _COLOR_CONTORNO_NOMBRE,
		_altura_iconos_estado())
