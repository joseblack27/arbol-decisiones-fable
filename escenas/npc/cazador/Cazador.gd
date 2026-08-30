extends CharacterBody2D
class_name Cazador
## NPC autónomo (sin control de jugador): sale de la Ciudad, camina hasta la
## Pradera, caza a distancia la presa viva más cercana (combate REAL, no un
## kill instantáneo — a diferencia del leñador con los árboles) y vuelve a
## la Ciudad a descansar. Pedido explícito del usuario: "un npc cazador,
## que caze ratones y deje los recursos en el mismo cofre del leñador...
## combate real con el sistema existente, pero el cazador solo puede
## disparar flechas cada 1 segundo y a distancia". Comparte el pool de
## mobs de siempre (SpawnerMobs en la Pradera) — caza cualquiera que haya,
## sin spawner dedicado (confirmado con el usuario). Presas válidas (ver
## _presa_mas_cercana): Ratón, Lobo y Araña — pedido explícito del usuario
## de agregar estos dos últimos a la lista de cacería original (solo
## Ratón).
##
## Mismo patrón de NPC errante que Lenador.gd — ver ese archivo para el
## porqué completo del diseño (única instancia, vive en GestorNiveles.
## contenedor_errantes(), nunca se reparenta, cruza entre niveles como un
## jugador real). Reusa ese mismo razonamiento tal cual acá, sin repetirlo.
##
## INMUNIDAD A COMBATE — mismo criterio que Lenador.gd (confirmado con el
## usuario tras preguntarle): a propósito NO extiende Enemigo.gd, NO tiene
## VidaComponente, NO pertenece a los grupos "jugadores"/"enemigos". Un
## Ratón no le huye específicamente a él (su VisionComponente exige
## grupos_objetivo=["jugadores"]) y ningún otro mob lo ataca — pero el daño
## de sus flechas SÍ conecta igual, porque Combate.mismo_equipo() (que
## decide si un Proyectil hace daño) nunca da true si ninguno de los dos
## está en el mismo grupo (ver Proyectil._resolver_colision()).
##
## BOTÍN — sin viaje físico al almacén: a diferencia de la madera (el
## leñador la "carga" y tiene que caminar hasta AlmacenLenador para
## soltarla), el botín de un Ratón cazado se deposita SOLO, al instante,
## en cuanto muere — vía InventarioRedirectorAlmacen (hijo nombrado
## "InventarioComponente", ver ese archivo) + ExperienciaComponenteNoOp
## (hijo nombrado "ExperienciaComponente"): Enemigo._otorgar_item_al_
## atacante()/_otorgar_xp() buscan esos nombres EXACTOS en _ultimo_atacante
## (acá, el propio Cazador) por convención, sin que haga falta tocar
## Enemigo.gd. El ciclo de ir-y-volver a Ciudad es solo por coherencia
## visual con el leñador (confirmado con el usuario), no por necesidad de
## entrega.

const CAPA_NPC_ERRANTE := 16  # misma capa que ya usa Lenador.gd.
const MARGEN_LLEGADA := 16.0
const _ESPERA_EN_CASA := 4.0
const _ESPERA_SIN_PRESA := 3.0
const _FOTOGRAMAS_KEEPALIVE_RED := 30
const _UMBRAL_REPLICAR := 4.0
const _UMBRAL_SNAP_CLIENTE := 300.0

const _RUTA_CIUDAD := "res://escenas/niveles/NivelCiudad.tscn"
const _RUTA_PRADERA := "res://escenas/niveles/NivelPradera.tscn"

## Escena propia (no ProyectilFlecha.tscn genérica) — nunca debe dañar a un
## jugador que se cruce en la línea de tiro, ver ProyectilFlechaCazador.gd.
const _ESCENA_PROYECTIL := preload("res://escenas/habilidades/flecha/ProyectilFlechaCazador.tscn")

## Rango de tiro (px) — mismo que usa el Arquero Esqueleto (FlechaArquero.tres).
const _RANGO_DISPARO := 380.0
## Pedido explícito del usuario: "solo puede disparar flechas cada 1 segundo".
const _COOLDOWN_DISPARO := 1.0
## Pedido explícito del usuario: "la flecha debe hacer 10 de daño" — 10
## flechazos para los 100 HP de Ratón/Lobo/Araña, las tres presas válidas
## tienen la misma vida_maxima.
@export var dano_flecha: float = 10.0

enum Estado {
	ESPERANDO_CASA,          # en Ciudad: quieto un rato antes de salir
	YENDO_AL_PORTAL_CIUDAD,  # en Ciudad: caminando al portal para cruzar a Pradera
	BUSCANDO_PRESA,          # en Pradera: eligiendo la presa viva más cercana
	ESPERANDO_PRESA,         # en Pradera: no hay ninguna viva, reintenta
	YENDO_A_LA_PRESA,        # en Pradera: acercándose a rango de tiro
	CAZANDO,                 # en Pradera: dentro de rango, dispara c/1s hasta que el objetivo muera/desaparezca
	YENDO_AL_PORTAL_PRADERA, # en Pradera: caminando al portal para volver a Ciudad
}

@onready var movimiento: MovimientoComponente = $MovimientoComponente
@onready var componente_animacion: AnimacionComponente = $AnimacionComponente
@onready var _sprite: Sprite2D = $Sprite2D

var direccion: Vector2 = Vector2.ZERO
var direccion_mirada: Vector2 = Vector2.DOWN
var _posicion_replicada: Vector2 = Vector2.ZERO

var _estado: int = Estado.ESPERANDO_CASA
var _espera_restante: float = 0.0
var _presa_objetivo: Enemigo = null
var _tiempo_desde_disparo: float = 0.0

## Resueltos una sola vez en _ready(), server-side — mismo motivo que
## Lenador._nivel_ciudad/_portal_ciudad: esta instancia vive fuera de
## ambos niveles, ninguno de los dos puede referenciarla con una ruta fija
## en el editor.
var _nivel_ciudad: NivelBase
var _nivel_pradera: NivelBase
var _portal_ciudad: Node2D   # PortalAPradera, adentro de NivelCiudad
var _portal_pradera: Node2D  # PortalACiudad, adentro de NivelPradera

var _ultima_posicion_enviada: Vector2 = Vector2.ZERO
var _fotogramas_desde_envio := 0


func _ready() -> void:
	collision_layer = CAPA_NPC_ERRANTE
	collision_mask = 1  # CAPA_MUNDO — solo terreno, nada más.
	if not (Utils.en_red() and multiplayer.is_server()):
		return  # Cliente: réplica visual pura, ver _physics_process/_recibir_estado_red.

	_nivel_ciudad = GestorNiveles.asegurar_nivel_cargado_servidor(_RUTA_CIUDAD)
	_nivel_pradera = GestorNiveles.asegurar_nivel_cargado_servidor(_RUTA_PRADERA)
	if _nivel_ciudad:
		_portal_ciudad = _nivel_ciudad.get_node_or_null("PortalAPradera")
	if _nivel_pradera:
		_portal_pradera = _nivel_pradera.get_node_or_null("PortalACiudad")

	GestorNiveles.fijar_nivel_de_entidad(self, _RUTA_CIUDAD)
	_estado = Estado.ESPERANDO_CASA
	_espera_restante = _ESPERA_EN_CASA
	GestorNiveles.peer_listo.connect(_al_peer_listo)


func _physics_process(delta: float) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		_aplicar_presentacion(global_position.distance_to(_posicion_replicada) > 1.0)
		if global_position.distance_to(_posicion_replicada) > _UMBRAL_SNAP_CLIENTE:
			global_position = _posicion_replicada
		else:
			global_position = global_position.lerp(_posicion_replicada, 0.2)
		return
	_procesar_estado(delta)
	_aplicar_presentacion(velocity != Vector2.ZERO)
	_replicar_si_corresponde()


# =============================================================================
# MÁQUINA DE ESTADOS (solo servidor)
# =============================================================================

func _procesar_estado(delta: float) -> void:
	match _estado:
		Estado.ESPERANDO_CASA:
			movimiento.detener()
			_espera_restante -= delta
			if _espera_restante <= 0.0:
				_estado = Estado.YENDO_AL_PORTAL_CIUDAD

		Estado.YENDO_AL_PORTAL_CIUDAD:
			if _portal_ciudad == null:
				return
			movimiento.comandar_destino(_portal_ciudad.global_position)
			if movimiento.llego_al_destino(MARGEN_LLEGADA):
				_cruzar_a_pradera()
				_estado = Estado.BUSCANDO_PRESA

		Estado.BUSCANDO_PRESA:
			_presa_objetivo = _presa_mas_cercana()
			if _presa_objetivo == null:
				_espera_restante = _ESPERA_SIN_PRESA
				_estado = Estado.ESPERANDO_PRESA
			else:
				_estado = Estado.YENDO_A_LA_PRESA

		Estado.ESPERANDO_PRESA:
			movimiento.detener()
			_espera_restante -= delta
			if _espera_restante <= 0.0:
				_estado = Estado.BUSCANDO_PRESA

		Estado.YENDO_A_LA_PRESA:
			if not _objetivo_vivo():
				_presa_objetivo = null
				_estado = Estado.BUSCANDO_PRESA
				return
			movimiento.comandar_destino(_presa_objetivo.global_position)
			if global_position.distance_to(_presa_objetivo.global_position) <= _RANGO_DISPARO:
				_estado = Estado.CAZANDO

		Estado.CAZANDO:
			if not _objetivo_vivo():
				# Puede haber muerto por su propia flecha o por otra cosa
				# (ej. un jugador de paso) — cualquiera de las dos formas
				# termina la cacería igual, sin distinguir quién dio el
				# golpe final más allá de lo que ya resuelve _ultimo_atacante.
				_presa_objetivo = null
				_estado = Estado.YENDO_AL_PORTAL_PRADERA
				return
			if global_position.distance_to(_presa_objetivo.global_position) > _RANGO_DISPARO:
				_estado = Estado.YENDO_A_LA_PRESA
				return
			movimiento.detener()
			direccion = global_position.direction_to(_presa_objetivo.global_position)
			direccion_mirada = direccion
			_tiempo_desde_disparo += delta
			if _tiempo_desde_disparo >= _COOLDOWN_DISPARO:
				_tiempo_desde_disparo = 0.0
				_disparar_flecha()

		Estado.YENDO_AL_PORTAL_PRADERA:
			if _portal_pradera == null:
				return
			movimiento.comandar_destino(_portal_pradera.global_position)
			if movimiento.llego_al_destino(MARGEN_LLEGADA):
				_cruzar_a_ciudad()
				_espera_restante = _ESPERA_EN_CASA
				_estado = Estado.ESPERANDO_CASA


func _objetivo_vivo() -> bool:
	return _presa_objetivo != null and is_instance_valid(_presa_objetivo) \
		and not _presa_objetivo.esta_muerto()


## Combate real (ver Proyectil._resolver_colision()) — self como "fuente"
## deja a este Cazador como _ultimo_atacante del Ratón al impactar, lo que
## dispara el reparto de botín/XP de Enemigo.gd hacia InventarioRedirector
## Almacen/ExperienciaComponenteNoOp (ver el comentario de arriba).
func _disparar_flecha() -> void:
	if not _objetivo_vivo():
		return
	var proy: Proyectil = GestorPiscinas.obtener(_ESCENA_PROYECTIL)
	proy.global_position = global_position
	proy.configurar(direccion, 1.0, dano_flecha, self, Enums.Habilidad.TipoDano.FISICO)
	# _disparar_flecha() SOLO corre server-side (ver el guard de _ready()/
	# _physics_process) — sin red, este mismo proceso es el que renderiza,
	# así que lo de arriba ya alcanza. En red, el Proyectil de arriba vive
	# SOLO en el árbol del servidor (headless, no se ve) — a diferencia de
	# un mob, no pasa por ningún MultiplayerSpawner. Pedido del usuario:
	# "no se ve la flecha del cazador" — mismo patrón que HabilidadBase.
	# _reproducir_visual_red (ver ese archivo): cada cliente cerca recibe
	# un aviso y arma SU PROPIO Proyectil puramente visual (daño=0: la
	# muerte real ya la resolvió este de arriba, server-side).
	_pulso_disparo()
	if Utils.en_red():
		for peer_id in InteresEspacial.peers_cercanos(global_position):
			rpc_id(peer_id, "_reproducir_pulso_disparo_red")
			rpc_id(peer_id, "_reproducir_flecha_visual_red", direccion)


## Pedido del usuario: "el cazador no se ve cuando lanza la flecha, debe
## verse" — sin pose de disparo propia (el placeholder JugadorBase.png solo
## tiene caminar/quieto, ver el comentario de la clase), este pulso corto
## de escala es la señal visual mínima de "acabo de disparar" mientras no
## haya arte/animación dedicada.
func _pulso_disparo() -> void:
	if not _sprite:
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.35, 1.35), 0.05)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.15)


@rpc("authority", "unreliable")
func _reproducir_pulso_disparo_red() -> void:
	_pulso_disparo()


## Copia PURAMENTE visual del disparo, para el cliente — no aplica daño de
## verdad (dano=0.0): la muerte/botín real ya los resolvió el Proyectil del
## servidor en _disparar_flecha(), este es solo para que se VEA la flecha
## salir en cada pantalla. self.global_position acá es la posición YA
## replicada por _recibir_estado_red en este cliente, no la del servidor.
@rpc("authority", "unreliable")
func _reproducir_flecha_visual_red(dir: Vector2) -> void:
	var proy: Proyectil = GestorPiscinas.obtener(_ESCENA_PROYECTIL)
	proy.global_position = global_position
	proy.configurar(dir, 1.0, 0.0, self, Enums.Habilidad.TipoDano.FISICO)


## Recorre el grupo "enemigos" y se queda con la presa viva más cercana —
## mismo criterio que Lenador._arbol_mas_cercano(). Presas válidas: Ratón,
## Lobo, Araña (pedido explícito del usuario: agregar estos dos últimos a
## la lista original de solo Ratón) — Caballero/Arquero Esqueleto NO
## cuentan como presa. No filtra por nivel: hoy solo la Pradera tiene
## SpawnerMobs, así que el grupo ya contiene nada más que mobs de ahí
## (simplificación aceptada, ver el plan).
func _presa_mas_cercana() -> Enemigo:
	var mejor: Enemigo = null
	var mejor_distancia := INF
	for nodo in get_tree().get_nodes_in_group("enemigos"):
		if not (nodo is EnemigoRaton or nodo is EnemigoLobo or nodo is EnemigoAraña):
			continue
		if (nodo as Enemigo).esta_muerto():
			continue
		var distancia := global_position.distance_squared_to((nodo as Node2D).global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = nodo
	return mejor


## "Cruzar" = teletransportarse al punto de llegada del otro nivel — mismo
## patrón que Lenador._cruzar_a_pradera()/_cruzar_a_ciudad(), ver esos
## comentarios para el porqué completo (bug real del "leñador nunca
## desaparece", ya resuelto ahí y reusado acá tal cual).
func _cruzar_a_pradera() -> void:
	movimiento.detener()
	visible = false
	rpc("_recibir_visibilidad_red", false)
	if _portal_pradera:
		global_position = _portal_pradera.global_position
	GestorNiveles.fijar_nivel_de_entidad(self, _RUTA_PRADERA)


func _cruzar_a_ciudad() -> void:
	movimiento.detener()
	visible = false
	rpc("_recibir_visibilidad_red", false)
	if _portal_ciudad:
		global_position = _portal_ciudad.global_position
	GestorNiveles.fijar_nivel_de_entidad(self, _RUTA_CIUDAD)


# =============================================================================
# PRESENTACIÓN / RED — mismo patrón que Lenador.gd/Enemigo.gd
# =============================================================================

func _aplicar_presentacion(caminando: bool) -> void:
	if direccion != Vector2.ZERO:
		direccion_mirada = direccion
	if not componente_animacion:
		return
	componente_animacion.establecer_condicion("parameters/conditions/debeCaminar", caminando)
	componente_animacion.establecer_condicion("parameters/conditions/debeIdle", not caminando)
	componente_animacion.actualizar_blend(direccion_mirada)


func _replicar_si_corresponde() -> void:
	if not Utils.en_red():
		return
	_fotogramas_desde_envio += 1
	var cambio_relevante := global_position.distance_to(_ultima_posicion_enviada) > _UMBRAL_REPLICAR
	if not cambio_relevante and _fotogramas_desde_envio < _FOTOGRAMAS_KEEPALIVE_RED:
		return
	_fotogramas_desde_envio = 0
	_ultima_posicion_enviada = global_position
	for peer_id in InteresEspacial.peers_cercanos(global_position):
		rpc_id(peer_id, "_recibir_estado_red", global_position, direccion, direccion_mirada)


@rpc("authority", "unreliable_ordered")
func _recibir_estado_red(pos: Vector2, dir: Vector2, mirada: Vector2) -> void:
	visible = true
	_posicion_replicada = pos
	direccion = dir
	direccion_mirada = mirada


@rpc("authority", "reliable")
func _recibir_visibilidad_red(visible_ahora: bool) -> void:
	visible = visible_ahora


func _al_peer_listo(peer_id: int) -> void:
	rpc_id(peer_id, "_recibir_estado_red", global_position, direccion, direccion_mirada)
