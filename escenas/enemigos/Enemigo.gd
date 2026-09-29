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

## Los mobs viven en su propia capa física, fijada por CÓDIGO en _ready (no
## confiar en los .tscn: varias escenas de mob no heredan de enemigo.tscn).
## Máscara: mundo (1) + obstáculos de habilidad (4). Nadie choca con nadie:
## ni mob-mob ni mob-jugador (el jugador vive en la capa 8 con máscara 1). El
## daño entre mobs se bloquea aparte, por equipo (Combate.mismo_equipo).
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
## distancia. 0 = nunca, 1 = siempre que haya alguien bajo el umbral. Se SUMA
## al criterio de distancia, no lo reemplaza.
@export_range(0.0, 1.0, 0.05) var probabilidad_rematar_vida_baja: float = 0.5

@export_group("Nombre")
## "Nv.X Nombre" arriba del mob, leído de EnemigoDatos. Vive en la entidad y
## no en BarraVidaEnergiaComponente porque el nombre no depende de las barras.
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
## Fila de íconos de estado (veneno, lentitud, aturdido...) ENCIMA del nombre,
## para ver de un vistazo qué efectos tiene el mob. Se dibujan desde el mismo
## BuffsComponente que llenan Veneno, Lentitud y Aturdido: nada que registrar
## acá por tipo.
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

## Quién dio el último golpe (el mismo Node que las habilidades pasan como
## "fuente" a BusEventos.daño_aplicado: el jugador dueño, un Muro, etc.). El
## botín y la XP se le reparten a ESTE atacante, no al primer jugador de la
## escena.
var _ultimo_atacante: Node = null

## true desde el primer instante de _on_muerte (antes del fotograma diferido
## de _procesar_muerte). Todo sistema con su PROPIO bucle de física (p. ej.
## HabilidadCarga durante el dash, que mueve el cuerpo sin pasar por
## MovimientoComponente) debe consultarlo para cortarse: apagar arbol.activo
## no lo alcanza.
var _muerto: bool = false

@onready var habilidades: Marker2D = $Habilidades
## Para el parpadeo de "recibí daño" (ver parpadear()) — mismo nodo que ya
## usa cada subclase para su propia animación (AnimacionComponente).
@onready var sprite: Sprite2D = $Sprite2D
var _tween_parpadeo: Tween = null

var _texto_nombre: String = ""
## Nodo de dibujo puro para el nombre (sin script propio). Se crea por código
## en _ready(), a propósito DESPUÉS del Sprite2D: Godot pinta hermanos en orden
## de árbol, así que quedar último lo dibuja ENCIMA del sprite. En el _draw()
## de la raíz quedaría tapado, porque un nodo pinta lo propio antes que a sus
## hijos.
var _nodo_nombre: Node2D = null

## BuffsComponente recién se crea con el PRIMER debuff (ver
## EfectoVeneno._anotar_icono y similares), así que se reintenta cada
## _INTERVALO_REINTENTO_BUFFS (mismo criterio que BarraBuffs.gd).
var _buffs: BuffsComponente = null
var _buffs_activos: Array[String] = []
const _INTERVALO_REINTENTO_BUFFS := 0.5
var _acumulador_reintento_buffs := 0.0


## Lo que se replica no es global_position directo sino esta variable, para
## interpolar del lado del cliente (ver _physics_process) en vez de saltar a
## cada actualización de red.
var _posicion_replicada: Vector2 = Vector2.ZERO
## Posición del fotograma anterior en un cliente puro — para inferir
## "caminando" del desplazamiento REAL en pantalla (ver _physics_process).
var _posicion_render_anterior: Vector2 = Vector2.ZERO
## Desplazamiento mínimo por fotograma físico para considerarse "caminando"
## en un cliente (0.1px/frame ≈ 6px/s, muy por debajo de cualquier
## velocidad real de mob, incluso ralentizado).
const _UMBRAL_CAMINANDO_RED := 0.1
# Constante de tiempo ≈ 1/valor (~33 ms de rezago del mob visual respecto del
# servidor). Ese rezago hace que un proyectil que en el cliente "conecta"
# contra la posición atrasada no dañe en el servidor, que usa la real. Subirlo
# reduce el efecto (arreglarlo del todo pediría compensación de lag en el
# servidor), a cambio de que las correcciones por paquetes perdidos se noten
# un poco más.
const VELOCIDAD_INTERPOLACION_RED := 30.0

## Último estado replicado por RPC, para no reenviar lo mismo cada fotograma
## físico cuando el mob está quieto.
var _ultima_pos_enviada := Vector2.INF
var _ultima_dir_enviada := Vector2.INF
var _ultima_mirada_enviada := Vector2.INF
var _fotogramas_sin_enviar := 0
## Quiénes tenían a este mob dentro de RADIO_INTERES el fotograma anterior,
## para mandarle YA su primer estado real a un peer RECIÉN entrado en vez de
## esperar a un cambio o al keepalive. Sin esto, un mob quieto se veía en la
## pantalla de quien se acerca pegado en la pose con la que se creó el nodo.
var _peers_relevantes_anterior: Array[int] = []
## Aunque nada cambie, reenviar cada tanto igual (~2 veces/seg): el RPC es
## unreliable — si el último paquete antes de quedarse quieto se perdió, sin
## este keepalive el cliente quedaría desincronizado para siempre.
const _FOTOGRAMAS_KEEPALIVE_RED := 30

## MEDICIÓN DE CARGA (ver ServidorDedicado._reportar_capacidad): microsegundos
## acumulados en la replicación de estado (peers_cercanos() + rpc_id de
## _recibir_estado_red) de TODOS los mobs desde el último reporte. Corre 60
## veces por segundo por cada mob vivo.
static var us_acumulados_replicacion_estado: int = 0



## En red, todos los mobs son autoridad del SERVIDOR. La posición viaja por
## RPC explícito (ver _physics_process/_recibir_estado_red) y no por un
## MultiplayerSynchronizer armado por código, que con los mobs colocados en el
## .tscn nunca sincronizó de forma confiable (el cliente los veía congelados).
## Qué mobs existen (altas y bajas) lo replica ReplicadorEnemigos.
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
	# En red, el cliente nunca corre la IA de este mob: solo interpola hacia la
	# posición replicada. La PRESENTACIÓN (apuntado, orientación del sprite,
	# caminar/reposo) la calcula el propio cliente con el mismo código que el
	# servidor (_aplicar_presentacion), a partir del estado crudo replicado
	# (direccion y direccion_mirada): una sola lógica visual para ambos lados.
	if Utils.en_red() and not multiplayer.is_server():
		var diferencia := _posicion_replicada - global_position
		# Movimientos bruscos (el dash del lobo cruza media pantalla en pocos
		# fotogramas) dejan muy atrás a la interpolación suave, y el golpe llegaba
		# "desde lejos". Más allá de este umbral se salta directo.
		if diferencia.length() > 50.0:
			global_position = _posicion_replicada
		else:
			global_position = global_position.lerp(
				_posicion_replicada, clampf(delta * VELOCIDAD_INTERPOLACION_RED, 0.0, 1.0)
			)
		# "Caminando" se infiere del desplazamiento REAL de este fotograma (no hay
		# velocity local en un cliente). No usar la brecha de interpolación: un mob
		# lento (p. ej. ralentizado) avanza menos de lo que la interpolación cierra
		# por fotograma y se animaba en reposo aunque siguiera avanzando.
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
		var _inicio_us := Time.get_ticks_usec()
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
			# Solo a quien lo tiene a RADIO_INTERES (ver InteresEspacial), no a
			# todos: mandarlo a todos crecía como mobs × jugadores.
			for peer_id in peers_relevantes:
				rpc_id(peer_id, "_recibir_estado_red", global_position, direccion, direccion_mirada)
			_ultima_pos_enviada    = global_position
			_ultima_dir_enviada    = direccion
			_ultima_mirada_enviada = direccion_mirada
			_fotogramas_sin_enviar = 0
		elif not peers_nuevos.is_empty():
			# Peer recién entrado al radio de interés (ver
			# _peers_relevantes_anterior): mandarle YA su primer estado, sin tocar
			# el resto del throttle (no cuenta como el envío normal).
			for peer_id in peers_nuevos:
				rpc_id(peer_id, "_recibir_estado_red", global_position, direccion, direccion_mirada)
		us_acumulados_replicacion_estado += Time.get_ticks_usec() - _inicio_us


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
		# Mientras dure un ataque con fases propias (ver memoria
		# ["ataque_en_curso"]), ESA habilidad es dueña de debeCaminar/debeIdle:
		# si este bloque, que corre todos los fotogramas, los pisara, el árbol de
		# animación parpadearía entre reposo y el ataque.
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

## Con un solo jugador cerca se resuelve solo (el primero detectado es el
## único candidato). Con varios, no se queda con "el último que entró en
## rango" (ver _evaluar_objetivo).
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


## "jugador_detectado" refleja si queda ALGUIEN detectado, no solo si se fue
## el área puntual: con dos jugadores cerca, que se vaya uno no debe dejar al
## mob pasivo con el otro todavía delante.
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


## Reacción a un golpe de alguien que NO es el objetivo actual, según si el mob
## lo tiene detectado (con visión real) en este instante:
##   - Detectado: pasa a ser el objetivo al instante.
##   - NO detectado (a distancia, detrás de un obstáculo o desde camuflaje):
##     no se vuelve un objetivo que el mob persigue a ciegas (eso sería
##     "detectarlo" a cualquier distancia con un solo golpe). Deja un aviso de
##     "ruido" que sesga el PRÓXIMO paso de AccionDeambular hacia esa dirección
##     (ver AccionDeambular._elegir_destino), acotado al radio de deambulación:
##     va a mirar de dónde vino el golpe. Así pegarle desde fuera de su visión
##     no es gratis.
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


## El daño ya lo aplica la propia habilidad: acá solo se notifica al BT. El
## nombre viene de cuando solo lo conectaba el arañazo (EnemigoLobo y
## EnemigoCaballeroEsqueleto lo siguen cableando a su
## HabilidadArañazo.habilidad_activada), pero la lógica es genérica.
func _on_arañazo_activado(_habilidad: HabilidadBase) -> void:
	componente_animacion.establecer_condicion("parameters/conditions/debeIdle", true)
	memoria.establecer("habilidad_lanzada", true)


## En un cliente, esta señal solo llega cuando VidaComponente._recibir_vida_red()
## confirma el daño replicado por el servidor. Por eso, con este único chequeo,
## el parpadeo espera la confirmación real y es solo para el propio golpe (ver
## _es_mi_propio_golpe).
func _on_daño_aplicado(objetivo: Node, _cantidad: float, fuente: Node, _tipo: int = 2, _critico: bool = false) -> void:
	if objetivo == self:
		_ultimo_atacante = fuente
		if _es_mi_propio_golpe(fuente):
			parpadear()
		_priorizar_atacante(fuente)


## true si "fuente" es el jugador que controla ESTE cliente: el parpadeo es
## feedback local de "mi golpe conectó", sin confundirse con los golpes de
## otros jugadores. Sin red, cualquier golpe es "propio".
func _es_mi_propio_golpe(fuente: Node) -> bool:
	if not is_instance_valid(fuente):
		return false
	if not Utils.en_red():
		return true
	if not ("peer_id_dueño" in fuente):
		return false
	return fuente.peer_id_dueño == multiplayer.get_unique_id()


## Un solo parpadeo. Mata el tween anterior antes de arrancar otro: con golpes
## más seguidos que el parpadeo, dos tweens se pelean el modulate y el sprite
## queda trabado en rojo.
func parpadear(duracion: float = 0.1) -> void:
	if not sprite:
		return
	if _tween_parpadeo and _tween_parpadeo.is_valid():
		_tween_parpadeo.kill()
		sprite.modulate = Color.WHITE
	_tween_parpadeo = create_tween()
	_tween_parpadeo.tween_property(sprite, "modulate", Color(1, 0.2, 0.2), duracion)
	_tween_parpadeo.tween_property(sprite, "modulate", Color.WHITE, duracion)


## Getter público: quien necesita saber desde AFUERA si el mob sigue vivo (p.
## ej. Cazador._presa_mas_cercana()) no debería tocar _muerto directo.
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
	# body_entered). Repartir botín, sumar XP e instanciar notificaciones en ese
	# mismo stack da un tirón notable en Android: se difiere un fotograma.
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


## Le da el ítem al InventarioComponente de _ultimo_atacante. Sin atacante
## identificable (daño ambiental, un jugador de prueba sin componentes) cae a
## GestorInventario, que es el jugador LOCAL: eso solo tiene sentido sin red.
## En el servidor no hay jugador local, así que ese botín no es de nadie.
func _otorgar_item_al_atacante(item: DatosItem) -> void:
	var componente := _componente_del_atacante("InventarioComponente")
	if componente:
		componente.agregar_item(item)
	elif not Utils.en_red():
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
	_otorgar_xp_a(_ultimo_atacante, cantidad)
	_repartir_xp_de_grupo(cantidad)


func _otorgar_xp_a(entidad: Node, cantidad: int) -> void:
	var componente := _componente_de(entidad, "ExperienciaComponente")
	if componente:
		componente.agregar_xp(cantidad)
	elif not Utils.en_red():
		# Mismo criterio que _otorgar_item_al_atacante: la fachada es el
		# jugador local, que solo existe sin red.
		GestorExperiencia.agregar_xp(cantidad)
	var dueño := _peer_dueño_de(entidad)
	if dueño >= 0:
		var confirmaciones := _componente_de(entidad, "ComponenteConfirmacionesRed")
		if confirmaciones:
			confirmaciones.rpc_id(dueño, "_recibir_xp_red", cantidad)


## Grupos: reparte la XP COMPLETA (sin dividir: nadie debe depender de otro
## para progresar) a cada compañero de grupo de _ultimo_atacante que esté a
## RADIO_PARTICIPACION_GRUPO_XP del punto donde murió el mob. Más chico que
## InteresEspacial.RADIO_INTERES a propósito: "participó del combate", no solo
## "estaba en el mapa". _ultimo_atacante ya recibió la suya en _otorgar_xp, por
## eso se salta. Sin grupo no hace nada.
const RADIO_PARTICIPACION_GRUPO_XP := 600.0

func _repartir_xp_de_grupo(cantidad: int) -> void:
	if not (Utils.en_red() and multiplayer.is_server()):
		return
	if not is_instance_valid(_ultimo_atacante) or not ("id_unico" in _ultimo_atacante):
		return
	var id_atacante: String = _ultimo_atacante.id_unico
	if id_atacante == "":
		return
	for id_miembro in GestorGrupos.miembros_del_grupo_de(id_atacante):
		if id_miembro == id_atacante:
			continue
		var jugador := GestorGrupos.jugador_de_id_unico(id_miembro)
		if jugador == null or not is_instance_valid(jugador):
			continue
		if jugador.global_position.distance_to(global_position) > RADIO_PARTICIPACION_GRUPO_XP:
			continue
		_otorgar_xp_a(jugador, cantidad)


func _componente_de(entidad: Node, nombre_componente: String) -> Node:
	if not is_instance_valid(entidad):
		return null
	return entidad.get_node_or_null(nombre_componente)


func _componente_del_atacante(nombre_componente: String) -> Node:
	return _componente_de(_ultimo_atacante, nombre_componente)


## Peer id dueño de "entidad", o -1 si no aplica (sin multiplayer activo,
## entidad no identificada, etc.) — en ese caso no hay a quién avisarle por
## RPC, y el comportamiento sigue siendo el de siempre (todo local).
func _peer_dueño_de(entidad: Node) -> int:
	if not Utils.en_red() or not multiplayer.is_server():
		return -1
	if not is_instance_valid(entidad) or not ("peer_id_dueño" in entidad):
		return -1
	return entidad.peer_id_dueño


func _peer_dueño_del_atacante() -> int:
	return _peer_dueño_de(_ultimo_atacante)


## Apaga la colisión del cuerpo Y la de su VidaComponente (un Area2D con capas
## propias): en mobs cuyo VidaComponente lleva forma de colisión (Araña,
## Ratón), el cadáver seguía consumiendo proyectiles y dashes del jugador
## durante el fundido.
func _apagar_colision_de_muerto() -> void:
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if componente_vida:
		componente_vida.set_deferred("collision_layer", 0)
		componente_vida.set_deferred("collision_mask", 0)
		componente_vida.set_deferred("monitorable", false)
		componente_vida.set_deferred("monitoring", false)


## Hace desaparecer el cuerpo (queda en reposo, se pone negro y se desvanece)
## y lo libera. No se recicla: un mob arrastra demasiado estado propio (memoria
## del árbol, agente de navegación, visión, cooldowns) para reutilizarlo con
## garantías, y crear uno nuevo es barato. Para enterarse de que ya no existe
## (p. ej. SpawnerMobs), alcanza con la señal nativa `tree_exiting`.
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
		# Fijar el blend en la última dirección mirada ANTES de apagar
		# _physics_process, para que el reposo quede orientado. Mismo criterio que
		# _aplicar_presentacion: direccion_mirada primero (en combate suele estar
		# mirando al jugador), "direccion" como respaldo.
		var hacia_donde_mirar := direccion_mirada if direccion_mirada != Vector2.ZERO else direccion
		componente_animacion.actualizar_blend(hacia_donde_mirar)
		componente_animacion.establecer_condicion("parameters/conditions/debeCaminar", false)
		componente_animacion.establecer_condicion("parameters/conditions/debeIdle",    true)
	if Utils.en_red() and multiplayer.is_server():
		var replicador := ReplicadorEnemigos.de(self)
		if replicador:
			replicador.avisar_muerte(self)

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.BLACK, 0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


## CLIENTE: ReplicadorEnemigos avisa que este mob ya no existe en el servidor
## — mismo desvanecido visual, sin volver a pasar por la lógica de muerte
## (botín, XP, etc., ya resuelta allá).
func desvanecer_replica() -> void:
	_muerto = true
	_apagar_colision_de_muerto()
	if componente_animacion:
		# Mismo motivo que en _desvanecer_y_eliminar(): fijar el idle ANTES
		# Mismo motivo que en _desvanecer_y_eliminar(): fijar el reposo ANTES
		# de apagar _physics_process, o el desvanecido se congela a mitad de la
		# animación que estuviera corriendo.
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


## "Respiro" telegrafiado al cambiar de fase de un jefe: apaga el árbol de
## comportamiento, frena el movimiento y fuerza el reposo; tras "duracion"
## segundos, si el jefe sigue vivo y en el árbol, reactiva el árbol y llama a
## "al_reanudar" (habilidades nuevas, refuerzos, etc.). Compartido por los
## jefes con fases.
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


## Reacciona a una "Llamada de Auxilio" (ver HabilidadLlamadaAuxilio.gd): deja
## lo que esté haciendo y viaja directo a "destino", ignorando jugadores en el
## camino. Vive en la base para que cualquier mob pueda responder sin código
## propio. Solo pone banderas en la memoria: lo mueve la rama
## "ResponderLlamada" (Secuencia + CondicionMemoria + AccionIrAPunto), que cada
## .tscn que responde trae como PRIMER hijo de su Selector (máxima prioridad).
func responder_llamada_auxilio(destino: Vector2) -> void:
	if _muerto or memoria == null:
		return
	memoria.establecer("en_llamada_auxilio", true)
	memoria.establecer("destino_llamada", destino)


# =============================================================================
# DATOS / PLANTILLA  (sobreescribir en subclases para stats propios)
# =============================================================================

func _aplicar_datos() -> void:
	if not datos:
		return
	if componente_vida:
		componente_vida.salud_maxima = datos.vida_maxima
		# VidaComponente._ready() (un HIJO, corre ANTES que este _ready()) ya fijó
		# salud_actual con el valor por defecto del export (100). Sin este
		# restaurar_vida(), un mob con otra vida_maxima arrancaba con 100 de vida
		# real aunque la barra mostrara el máximo correcto.
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
		# ella, y sin esto cualquier recálculo revertiría el valor de la plantilla.
		if comp_atributos._base_sin_equipo:
			comp_atributos._base_sin_equipo.regeneracion_energia = datos.regeneracion_energia
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		spr.modulate = datos.color


## Sin "datos" (p. ej. un aliado invocado) no se dibuja NADA, ni nombre ni
## íconos de estado.
##
## CON datos, _nodo_nombre (la superficie de dibujo compartida) se crea
## SIEMPRE, aunque mostrar_nombre sea false (los jefes con cartel propio,
## NombreJefe): sin ese nodo no se dibujan los íconos de estado, y los jefes
## nunca mostrarían sus debuffs.
func _crear_nombre_mob() -> void:
	if datos == null:
		return
	if mostrar_nombre:
		var nombre: String = datos.nombre_tipo.strip_edges()
		if nombre == "":
			nombre = String(name)
		_texto_nombre = ("Nv.%d %s" % [datos.nivel, nombre]) if datos.nivel > 0 else nombre

	_nodo_nombre = Node2D.new()
	_nodo_nombre.name = "NombreMob"
	_nodo_nombre.position = Vector2(0.0, altura_nombre)
	add_child(_nodo_nombre)
	if _texto_nombre != "":
		_nodo_nombre.draw.connect(_dibujar_nombre_mob)
	# Los íconos de estado usan el MISMO nodo y draw que el nombre: quedan en el
	# mismo orden de dibujo, encima del sprite.
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
## crece hacia arriba desde su línea base en y=0 (ver _dibujar_nombre_mob), así
## que se resta la altura REAL de la fuente, no un número fijo. Función aparte
## para poder verificar desde afuera que da negativo (arriba del nombre).
func _altura_iconos_estado() -> float:
	var altura_texto := _FUENTE_NOMBRE.get_height(tamano_fuente_nombre)
	return -(altura_texto + margen_iconos_estado + tamano_icono_estado)


func _dibujar_iconos_estado_mob() -> void:
	Utils.dibujar_iconos_estado(_nodo_nombre, _buffs, _buffs_activos,
		tamano_icono_estado, separacion_iconos_estado, _COLOR_CONTORNO_NOMBRE,
		_altura_iconos_estado())
