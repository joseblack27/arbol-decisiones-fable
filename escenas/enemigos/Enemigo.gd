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

# --- Componentes ---
@export var componente_vida: VidaComponente
@export var componente_maquina_de_estados: MaquinaDeEstadosComponente
@export var componente_movimiento: MovimientoComponente
@export var componente_vision: VisionComponente
@export var componente_animacion: AnimacionComponente
@export var memoria: MemoriaBT

@export var datos: EnemigoDatos
@export_range(0.0, 1.0, 0.05) var umbral_vida_baja: float = 0.3

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


## Fase 6: lo que se replica NO es global_position directo — es esta
## variable, para poder interpolar del lado del cliente (ver _physics_process)
## en vez de saltar de golpe a cada actualización de red.
var _posicion_replicada: Vector2 = Vector2.ZERO
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
	_aplicar_datos()
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
		# "Caminando" se infiere del movimiento real (no hay velocity local).
		_aplicar_presentacion(diferencia.length() > 1.0)
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
		if cambio or _fotogramas_sin_enviar >= _FOTOGRAMAS_KEEPALIVE_RED:
			# Fase 1 del plan de escalado a MMO (interés espacial): antes esto
			# era rpc() — broadcast a TODOS los peers conectados, sin importar
			# dónde estuvieran parados. Con 100 jugadores dispersos por el
			# mapa, cada mob mandaba su posición a jugadores que ni siquiera
			# lo tenían cerca — tráfico y costo de simulación que crecían como
			# mobs × jugadores. Ahora solo a quien lo tiene a RADIO_INTERES.
			for peer_id in InteresEspacial.peers_cercanos(global_position):
				rpc_id(peer_id, "_recibir_estado_red", global_position, direccion, direccion_mirada)
			_ultima_pos_enviada    = global_position
			_ultima_dir_enviada    = direccion
			_ultima_mirada_enviada = direccion_mirada
			_fotogramas_sin_enviar = 0


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
		componente_animacion.establecer_condicion("parameters/conditions/debeCaminar", caminando)
		componente_animacion.establecer_condicion("parameters/conditions/debeIdle",    not caminando)
		# El sprite se orienta con la MIRADA de combate cuando existe
		# (quieto entre ataques o kiteando debe VERSE mirando al objetivo);
		# fuera de combate, direccion_mirada es ZERO y cae a la dirección
		# de paseo/huida de siempre.
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

func quitar_vida(cantidad: float, fuente: Node = null) -> void:
	if componente_vida:
		componente_vida.quitar_vida(cantidad, fuente)


# =============================================================================
# SEÑALES DE COMPONENTES
# =============================================================================

func _on_objetivo_detectado(area: Area2D) -> void:
	memoria.establecer("objetivo",          area.owner)
	memoria.establecer("jugador_detectado", true)


func _on_objetivo_perdido(_area: Area2D) -> void:
	memoria.establecer("jugador_detectado", false)


func _on_vida_cambiada(nuevo_valor: float) -> void:
	memoria.establecer("vida", nuevo_valor)


func _on_daño_aplicado(objetivo: Node, _cantidad: float, fuente: Node) -> void:
	if objetivo == self:
		_ultimo_atacante = fuente


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
		_ultimo_atacante.rpc_id(dueño, "_recibir_botin_red", item.resource_path, item.quantity)


func _otorgar_xp(cantidad: int) -> void:
	var componente := _componente_del_atacante("ExperienciaComponente")
	if componente:
		componente.agregar_xp(cantidad)
	else:
		GestorExperiencia.agregar_xp(cantidad)
	var dueño := _peer_dueño_del_atacante()
	if dueño >= 0:
		_ultimo_atacante.rpc_id(dueño, "_recibir_xp_red", cantidad)


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
func _desvanecer_y_eliminar() -> void:
	# Diferido: _on_muerte() puede llegar desde dentro de un callback de
	# física (un golpe cuerpo a cuerpo), donde cambiar capas de colisión
	# de golpe dispara "flushing queries".
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
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
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
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


# =============================================================================
# DATOS / PLANTILLA  (sobreescribir en subclases para stats propios)
# =============================================================================

func _aplicar_datos() -> void:
	if not datos:
		return
	if componente_vida:
		componente_vida.salud_maxima = datos.vida_maxima
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
