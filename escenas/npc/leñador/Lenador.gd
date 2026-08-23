extends CharacterBody2D
class_name Lenador
## NPC autónomo (sin control de jugador): sale de la Ciudad, camina hasta la
## Pradera, corta el árbol disponible más cercano, vuelve a la Ciudad y
## deposita la madera en el almacén compartido (ver GestorLenador.gd).
## Pedido del usuario: "un npc leñador, que salga de la ciudad, hacia la
## pradera para cortar arboles y vuelva a la ciudad y deje la madera en un
## cofre... este npc no debe ser atacado por los mobs, ni tener colision
## con sus habilidades".
##
## INMUNIDAD A COMBATE: a propósito NO extiende Enemigo.gd (que fuerza
## add_to_group("enemigos") en su _ready()), NO tiene VidaComponente ni
## ningún método quitar_vida() en ningún hijo, y NO pertenece a los grupos
## "jugadores"/"enemigos". Eso solo ya lo vuelve invisible para
## VisionComponente (aggro de mobs, exige grupo "jugadores"),
## Combate.golpear_area() (melee/AoE de TODAS las habilidades, solo daña
## VidaComponente o algo con quitar_vida()) y Proyectil._resolver_colision()
## (mismo filtro) — confirmado por precedente real: escenas/npc/Npc.gd (el
## comerciante) ya está construido exactamente así. La capa física propia
## (CAPA_NPC_ERRANTE) es cinturón y tirantes, no la protección real.
##
## VIAJE ENTRE NIVELES — SEGUNDA VUELTA DE ESTE DISEÑO: la primera versión
## usaba DOS instancias (una por nivel) coordinadas por una bandera
## compartida. Bug real reportado ("el leñador no se mueve"): un jugador
## conectado a UN SOLO nivel a la vez hace que GestorNiveles apague
## (PROCESS_MODE_DISABLED) el otro nivel completo por falta de jugadores —
## el leñador podía quedar congelado en el nivel que nadie estaba mirando,
## y como ninguna instancia lograba terminar su tramo, la otra tampoco se
## activaba nunca. Peor aún: reparentar entre los NPCs de cada nivel también
## rompía la réplica en cualquier cliente que NO tuviera ese nivel cargado
## (las RPC dirigidas a un nodo se resuelven por su RUTA en el árbol, y esa
## ruta cambiaba con cada cruce).
##
## Solución (pedido explícito del usuario: "que el leñador use el mismo tp
## que uso yo para moverme por los mapas"): UNA sola instancia, que vive
## SIEMPRE colgada de GestorNiveles.contenedor_errantes() — un contenedor
## fijo, hermano de "Jugadores", FUERA de cualquier nivel — exactamente
## igual que un jugador real, que jamás se reparenta al cruzar un portal
## (ver GestorNiveles: "los jugadores cuelgan de Jugadores, fuera de los
## niveles"). "Cruzar" acá es solo cambiar global_position al punto de
## llegada del otro lado (mismo criterio que
## GestorNiveles._colocar_peer_en_aparicion) + avisarle a GestorNiveles en
## qué nivel está ahora (fijar_nivel_de_entidad) para que la navegación siga
## la malla correcta. Como la ruta del nodo en el árbol NUNCA cambia, las
## RPC de réplica resuelven en cualquier cliente conectado, esté donde esté
## — el mismo mecanismo que ya usa la réplica de otros jugadores.
## Ciudad y Pradera además se mantienen SIEMPRE activas (ver
## GestorNiveles.mantener_siempre_activo, llamado desde GestorLenador) —
## pedido explícito del usuario, cinturón y tirantes sobre el rediseño de
## arriba.

const CAPA_NPC_ERRANTE := 16  # primer bit libre (1 mundo, 2 mob, 4 obstáculos, 8 jugador)
const MARGEN_LLEGADA := 16.0
const _ESPERA_EN_CASA := 4.0
const _ESPERA_SIN_ARBOL := 3.0
const _FOTOGRAMAS_KEEPALIVE_RED := 30
const _UMBRAL_REPLICAR := 4.0
## Salto de posición (px) a partir del cual el cliente directamente
## teletransporta su réplica en vez de deslizarla — cruzar de Ciudad a
## Pradera mueve al leñador decenas de miles de px de golpe (mismo
## desplazamiento entre niveles que usa GestorNiveles), un lerp() ahí se
## vería como un tirón cruzando toda la pantalla.
const _UMBRAL_SNAP_CLIENTE := 300.0

const _RUTA_CIUDAD := "res://escenas/niveles/NivelCiudad.tscn"
const _RUTA_PRADERA := "res://escenas/niveles/NivelPradera.tscn"

enum Estado {
	ESPERANDO_CASA,          # en Ciudad: quieto un rato antes de salir
	YENDO_AL_PORTAL_CIUDAD,  # en Ciudad: caminando al portal para cruzar a Pradera
	BUSCANDO_ARBOL,          # en Pradera: eligiendo el árbol más cercano disponible
	ESPERANDO_ARBOL,         # en Pradera: no hay ninguno disponible, reintenta
	YENDO_AL_ARBOL,          # en Pradera: caminando al árbol elegido
	CORTANDO,                # en Pradera: acción instantánea de tala
	YENDO_AL_PORTAL_PRADERA, # en Pradera: caminando al portal para volver a Ciudad
	YENDO_AL_ALMACEN,        # en Ciudad: caminando al almacén a depositar
	DEPOSITANDO,             # en Ciudad: acción instantánea de depósito
}

@onready var movimiento: MovimientoComponente = $MovimientoComponente
@onready var componente_animacion: AnimacionComponente = $AnimacionComponente

var direccion: Vector2 = Vector2.ZERO
var direccion_mirada: Vector2 = Vector2.DOWN
var _posicion_replicada: Vector2 = Vector2.ZERO

var _estado: int = Estado.ESPERANDO_CASA
var _espera_restante: float = 0.0
var _arbol_objetivo: ObjetoRecolectable = null
var _carga_actual: DatosItem = null

## Resueltos una sola vez en _ready(), server-side — ver el comentario de
## arriba sobre por qué no son @export NodePath: esta instancia vive fuera
## de ambos niveles, así que ninguno de los dos puede referenciarla (ni
## viceversa) con una ruta relativa fijada en el editor.
var _nivel_ciudad: NivelBase
var _nivel_pradera: NivelBase
var _portal_ciudad: Node2D    # PortalAPradera, adentro de NivelCiudad
var _portal_pradera: Node2D   # PortalACiudad, adentro de NivelPradera
var _almacen_punto: AlmacenLenador
var _contenedor_arboles: Node

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
		_almacen_punto = _nivel_ciudad.get_node_or_null("Decoraciones/AlmacenLenador1")
	if _nivel_pradera:
		_portal_pradera = _nivel_pradera.get_node_or_null("PortalACiudad")
		_contenedor_arboles = _nivel_pradera.get_node_or_null("Decoraciones")

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
				_estado = Estado.BUSCANDO_ARBOL

		Estado.BUSCANDO_ARBOL:
			_arbol_objetivo = _arbol_mas_cercano()
			if _arbol_objetivo == null:
				_espera_restante = _ESPERA_SIN_ARBOL
				_estado = Estado.ESPERANDO_ARBOL
			else:
				_estado = Estado.YENDO_AL_ARBOL

		Estado.ESPERANDO_ARBOL:
			movimiento.detener()
			_espera_restante -= delta
			if _espera_restante <= 0.0:
				_estado = Estado.BUSCANDO_ARBOL

		Estado.YENDO_AL_ARBOL:
			if _arbol_objetivo == null or not is_instance_valid(_arbol_objetivo) \
					or _arbol_objetivo.esta_agotado():
				_estado = Estado.BUSCANDO_ARBOL
				return
			var destino := _arbol_objetivo.area_interaccion.global_position \
					if _arbol_objetivo.area_interaccion else _arbol_objetivo.global_position
			movimiento.comandar_destino(destino)
			# El margen de llegada acá es el radio de interacción REAL del
			# árbol (mismo que usa el servidor para aceptar la recolección
			# de un jugador real, ver ObjetoRecolectable._pedir_recolectar_
			# red) Y movimiento.llego_al_destino() en vez de una comparación
			# de distancia a secas — bug real reportado ("el leñador no se
			# mueve", visto en juego): caminar hasta el CENTRO exacto del
			# área de interacción apunta a un punto que puede quedar pegado
			# al cuerpo sólido del tronco (no navegable), y el agente de
			# navegación jamás termina de acercarse más de lo que la malla
			# permite — sin llego_al_destino(), el leñador se quedaba
			# caminando en el lugar para siempre esperando un margen
			# imposible de alcanzar.
			if movimiento.llego_al_destino(_arbol_objetivo.radio_interaccion_servidor):
				movimiento.detener()
				_estado = Estado.CORTANDO

		Estado.CORTANDO:
			if _arbol_objetivo != null and is_instance_valid(_arbol_objetivo):
				_carga_actual = _arbol_objetivo.recolectar_para_npc()
			_arbol_objetivo = null
			_estado = Estado.YENDO_AL_PORTAL_PRADERA

		Estado.YENDO_AL_PORTAL_PRADERA:
			if _portal_pradera == null:
				return
			movimiento.comandar_destino(_portal_pradera.global_position)
			if movimiento.llego_al_destino(MARGEN_LLEGADA):
				_cruzar_a_ciudad()
				_estado = Estado.YENDO_AL_ALMACEN

		Estado.YENDO_AL_ALMACEN:
			if _almacen_punto == null:
				return
			var destino_almacen := _almacen_punto.area_interaccion.global_position \
					if _almacen_punto.area_interaccion else _almacen_punto.global_position
			movimiento.comandar_destino(destino_almacen)
			# Mismo motivo que YENDO_AL_ARBOL: el origen exacto del mueble
			# puede quedar pegado a su colisión sólida.
			if movimiento.llego_al_destino(_almacen_punto.radio_interaccion):
				movimiento.detener()
				_estado = Estado.DEPOSITANDO

		Estado.DEPOSITANDO:
			if _carga_actual != null:
				GestorLenador.depositar_servidor(_carga_actual)
				_carga_actual = null
			_espera_restante = _ESPERA_EN_CASA
			_estado = Estado.ESPERANDO_CASA


## "Cruzar" = teletransportarse al punto de llegada del otro nivel (mismo
## criterio que GestorNiveles._colocar_peer_en_aparicion con un jugador
## real) + avisarle a GestorNiveles en qué nivel está ahora, para que
## MovimientoComponente._usar_mapa_del_nivel() ligue el próximo
## comandar_destino() a la malla correcta. Nunca se reparenta — sigue
## colgado del mismo contenedor_errantes() de siempre.
##
## rpc("_recibir_visibilidad_red", false) ANTES de saltar: bug real
## reportado ("el leñador nunca desaparece... queda la instancia ahí en el
## círculo del tp"). InteresEspacial.peers_cercanos() solo manda posición
## nueva a quien está CERCA de la posición ACTUAL — un cliente parado en
## Ciudad deja de recibir cualquier actualización en cuanto el leñador
## cruza a Pradera (a 100.000 px, nunca "cerca"), así que su sprite se
## queda dibujado para siempre en el último punto que sí vio. El broadcast
## de "ocultarme" llega a TODOS sin importar la distancia, así que no deja
## fantasma; _recibir_estado_red() se encarga de volver a mostrarlo apenas
## alguien esté lo bastante cerca como para recibir posición de nuevo.
func _cruzar_a_pradera() -> void:
	movimiento.detener()
	# rpc() NO se llama a sí mismo del lado de quien lo emite — hay que
	# aplicar el cambio acá TAMBIÉN, no solo mandarlo (mismo criterio que
	# ObjetoRecolectable._recolectar_local, que fija _agotado=true directo
	# antes de avisarle a los demás por RPC).
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


## Recorre _contenedor_arboles y elige el ObjetoRecolectable disponible más
## cercano — genérico a propósito (mismo criterio que ObjetoRecolectable en
## sí): sirve igual si más adelante hay varios árboles, o rocas/hierbas.
func _arbol_mas_cercano() -> ObjetoRecolectable:
	if _contenedor_arboles == null:
		return null
	var mejor: ObjetoRecolectable = null
	var mejor_distancia := INF
	for hijo in _contenedor_arboles.get_children():
		if hijo is ObjetoRecolectable and not (hijo as ObjetoRecolectable).esta_agotado():
			var distancia := global_position.distance_to((hijo as Node2D).global_position)
			if distancia < mejor_distancia:
				mejor_distancia = distancia
				mejor = hijo
	return mejor


# =============================================================================
# PRESENTACIÓN / RED — mismo patrón que Enemigo.gd
# =============================================================================

## Única lógica de presentación, compartida entre servidor/single-player y
## cliente replicado (ver Jugador.gd:660-669 para la misma API).
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
	# Recibir posición real de nuevo significa que estamos lo bastante cerca
	# como para que InteresEspacial nos la mande — es la señal de "ya estoy
	# donde me pueden ver" tras cruzar (ver _cruzar_a_pradera/_cruzar_a_
	# ciudad), sin depender de que la RPC de visibilidad (unreliable no, esa
	# es reliable, pero por las dudas) llegue en el orden esperado.
	visible = true
	_posicion_replicada = pos
	direccion = dir
	direccion_mirada = mirada


## Broadcast reliable a TODOS, sin filtrar por distancia — ver el porqué en
## _cruzar_a_pradera/_cruzar_a_ciudad: evita el fantasma dibujado en la
## última posición vista por un cliente que ya no está lo bastante cerca
## como para recibir más actualizaciones de posición.
@rpc("authority", "reliable")
func _recibir_visibilidad_red(visible_ahora: bool) -> void:
	visible = visible_ahora


## Recién conectado: avisarle dónde está el leñador AHORA — sin filtrar por
## nivel (a diferencia de NivelNidoArañaReina/ObjetoRecolectable): esta
## instancia no pertenece a ningún nivel en particular, así que cualquier
## peer nuevo puede necesitarlo apenas se acerque.
func _al_peer_listo(peer_id: int) -> void:
	rpc_id(peer_id, "_recibir_estado_red", global_position, direccion, direccion_mirada)
