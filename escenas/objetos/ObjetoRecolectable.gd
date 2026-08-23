extends StaticBody2D
class_name ObjetoRecolectable
## Objeto de mundo recolectable — GENÉRICO a propósito (pedido del usuario:
## "me gustaría que fuera genérico, un script tanto para madera como piedra
## o hierbas... así sería más fácil crear nuevas fuentes de recursos"): no
## sabe nada de árboles/rocas/hierbas en particular, todo lo que lo hace
## "un árbol" o "una roca" son sus @export (item, texturas, texto del
## botón) — crear una fuente de recurso nueva es armar una escena chica
## nueva con este MISMO script (ver ArbolTalable.tscn como plantilla), sin
## tocar código. Ni siquiera valida ningún equipo del jugador (sin hacha,
## sin pico) — pedido explícito del usuario, cualquiera que se acerque y
## toque el botón de interacción recibe [item_recurso].
##
## Combina el patrón visual de DecoracionOcluible (sprite + área de
## oclusión que se desvanece si tapa al jugador local) con el de
## proximidad/interacción de Cofre.gd (área de interacción +
## GestorInteraccion + botón táctil fijo).
##
## A diferencia de un Cofre (contenido POR JUGADOR, sin RPC — cada uno
## tiene su propia copia, ver ese archivo), el estado "agotado" es
## COMPARTIDO: todos los jugadores conectados deben verlo con el mismo
## sprite al mismo tiempo. Por eso, a diferencia de Cofre.gd, este SÍ
## necesita validación server-autoritativa (RPC de 4 pasos, mismo patrón
## que MejorasComponente._pedir_gastar_pasiva_red) y un broadcast reliable
## cuando cambia (mismo patrón que Enemigo._despawn_red) — más el resync a
## un peer que se conecta DESPUÉS de que ya quedó agotado (GestorNiveles.
## peer_listo, mismo patrón que NivelNidoArañaReina._al_peer_listo).
## Pedido del usuario: "que cambie de sprite, no permita recoger más y
## cambie de sprite más adelante como en 2 minutos dejando recoger de
## nuevo".

const CAPA_CUERPO_JUGADOR := 8
## Nombres fijos de las 2 animaciones que CADA flavor debe definir (ver
## ArbolTalable.tscn) — pedido del usuario: "quisiera que las animaciones
## se llamen 'completo' y 'cortado'". Cada animación es un solo frame que
## fija texture/position/scale del sprite juntos (el árbol entero y el
## tocón tienen tamaños distintos, no alcanza con cambiar solo la textura
## — por eso AnimationPlayer en vez de asignar sprite.texture a mano).
const _ANIM_COMPLETO := "completo"
const _ANIM_CORTADO := "cortado"

@export var sprite: Sprite2D
@export var area_oclusion: Area2D
@export var area_interaccion: Area2D
@export var animation_player: AnimationPlayer
## Para la lista de objetos cuando hay otro interactuable superpuesto cerca
## (ver GestorInteraccion) — vacío por defecto para no romper instancias ya
## armadas antes de este campo; en ese caso se usa texto_interaccion.
@export var nombre: String = ""
@export var texto_interaccion: String = "Recolectar"
## Ítem que se entrega al recolectar — ej. res://recursos/items/recursos/lena_1.tres.
@export var item_recurso: DatosItem
## Segundos hasta que vuelve a estar disponible tras agotarse.
@export var segundos_respawn: float = 120.0
## Radio (px, en el LOCAL de area_interaccion, sin escalar) de respaldo si
## area_interaccion no tiene un CircleShape2D del que derivarlo solo (ver
## _ready()) — normalmente no hace falta tocarlo a mano.
@export var radio_interaccion_servidor: float = 64.0

@export_group("Oclusión")
@export_range(0.1, 1.0) var opacidad_oculto := 0.45
@export var velocidad_fundido := 5.0

var _cuerpos_dentro_oclusion := 0
var _cuerpos_dentro_interaccion := 0
var _agotado := false

@onready var _timer_respawn: Timer = $TimerRespawn


func _ready() -> void:
	set_physics_process(false)
	if area_oclusion and sprite:
		area_oclusion.collision_mask = CAPA_CUERPO_JUGADOR
		area_oclusion.body_entered.connect(_al_entrar_oclusion)
		area_oclusion.body_exited.connect(_al_salir_oclusion)
	if area_interaccion:
		area_interaccion.collision_mask = CAPA_CUERPO_JUGADOR
		area_interaccion.body_entered.connect(_al_entrar_interaccion)
		area_interaccion.body_exited.connect(_al_salir_interaccion)
		# Bug real reportado: "la interacción de talar no sirve, no veo que
		# haga nada" — el botón (gatillado por área_interaccion, que SÍ
		# respeta su offset local y la escala de la instancia) aparecía,
		# pero el servidor comparaba contra self.global_position (el
		# origen del StaticBody2D, sin el offset -16/-72 típico ni la
		# escala 2x que usan las instancias en el nivel) con un radio fijo
		# sin escalar — un área totalmente distinta a la que el jugador
		# veía, así que el RPC se rechazaba en silencio casi siempre.
		# Deriva el radio real (escalado) del propio CircleShape2D de
		# area_interaccion en vez de un número aparte que hay que
		# mantener sincronizado a mano por cada instancia/escala.
		for hijo in area_interaccion.get_children():
			if hijo is CollisionShape2D and hijo.shape is CircleShape2D:
				radio_interaccion_servidor = hijo.shape.radius * area_interaccion.global_scale.x
				break
	_timer_respawn.one_shot = true
	_timer_respawn.wait_time = segundos_respawn
	_timer_respawn.timeout.connect(_al_timeout_respawn)
	# Arranca en "completo" siempre — no depende de que el .tscn haya
	# dejado el Sprite2D ya puesto a mano en ese estado.
	_aplicar_estado_visual(false)
	# Resync para quien se conecta (o reconecta) DESPUÉS de que este objeto
	# ya quedó agotado — sin esto, lo vería disponible hasta el próximo
	# cambio real (que podría tardar hasta segundos_respawn, o nunca si
	# nadie más lo toca).
	if not Utils.en_red() or multiplayer.is_server():
		GestorNiveles.peer_listo.connect(_al_peer_listo)


## Mismo criterio que DecoracionOcluible._physics_process: solo reacciona
## al jugador LOCAL (cada cliente decide su propio desvanecido, no un rayo
## X que revela a los demás jugadores que pasan detrás).
func _physics_process(delta: float) -> void:
	var objetivo := 1.0
	var jugador := Utils.jugador_local()
	if is_instance_valid(jugador) and area_oclusion.overlaps_body(jugador) \
			and global_position.y > jugador.global_position.y:
		objetivo = opacidad_oculto
	sprite.modulate.a = move_toward(sprite.modulate.a, objetivo, velocidad_fundido * delta)
	if _cuerpos_dentro_oclusion == 0 and is_equal_approx(sprite.modulate.a, 1.0):
		set_physics_process(false)


func _al_entrar_oclusion(cuerpo: Node2D) -> void:
	if cuerpo == Utils.jugador_local():
		_cuerpos_dentro_oclusion += 1
		set_physics_process(true)


func _al_salir_oclusion(cuerpo: Node2D) -> void:
	if cuerpo == Utils.jugador_local():
		_cuerpos_dentro_oclusion = maxi(0, _cuerpos_dentro_oclusion - 1)


func _al_entrar_interaccion(cuerpo: Node2D) -> void:
	if cuerpo != Utils.jugador_local():
		return
	_cuerpos_dentro_interaccion += 1
	if _cuerpos_dentro_interaccion == 1 and not _agotado:
		GestorInteraccion.registrar(self, nombre if nombre != "" else texto_interaccion, acciones_interaccion())


func _al_salir_interaccion(cuerpo: Node2D) -> void:
	if cuerpo != Utils.jugador_local():
		return
	_cuerpos_dentro_interaccion = maxi(0, _cuerpos_dentro_interaccion - 1)
	if _cuerpos_dentro_interaccion == 0:
		GestorInteraccion.quitar(self)


## Una sola acción por ahora ("Recolectar"/"Talar", según texto_interaccion)
## — lista de un elemento para calzar con el contrato genérico de
## GestorInteraccion (ver ese archivo). El día que este mismo script sirva
## para un árbol con fruta (recolectar fruta O talar, dos acciones
## distintas sobre el mismo objeto — mencionado por el usuario como caso
## futuro), esto es lo único que hay que ampliar: agregar una entrada más
## a este array.
func acciones_interaccion() -> Array[Dictionary]:
	return [{"texto": texto_interaccion, "callback": interactuar}]


## Llamado al tocar la acción de interacción (ver ListaInteraccion.gd)
## mientras este objeto está en rango — corre en el CLIENTE que lo tocó.
## Sin red (o si el servidor tuviera un jugador local propio, caso raro con
## el ServidorDedicado headless de este proyecto) aplica directo; si no, le
## pide al servidor que lo aplique.
func interactuar() -> void:
	if _agotado:
		return
	if not Utils.en_red():
		_recolectar_local(Utils.jugador_local())
		return
	if multiplayer.is_server():
		_recolectar_local(Utils.jugador_local())
		return
	rpc_id(1, "_pedir_recolectar_red")


## SERVIDOR: valida que quien pide recolectar sea de verdad un jugador
## cerca de ESTE objeto (anti-spoof) antes de aplicar nada — mismo criterio
## de 4 pasos que MejorasComponente._pedir_gastar_pasiva_red, adaptado: acá
## no hay "dueño" fijo (cualquiera lo puede recolectar), así que el paso 2
## es "¿el jugador de ese peer está de verdad dentro de area_interaccion?"
## en vez de comparar contra un peer_id_dueño guardado.
@rpc("any_peer", "reliable")
func _pedir_recolectar_red() -> void:
	if not multiplayer.is_server():
		return
	if _agotado:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var jugador := InteresEspacial.jugador_de_peer(peer_id)
	if jugador == null:
		return
	var centro := area_interaccion.global_position if area_interaccion else global_position
	if centro.distance_to(jugador.global_position) > radio_interaccion_servidor:
		return
	_recolectar_local(jugador)


## SERVIDOR (o local sin red): aplica el agotamiento de verdad, avisa a
## TODOS los clientes conectados (broadcast reliable, mismo criterio que
## Enemigo._despawn_red: "algo cambió de forma visible para todos, evento
## raro, no hace falta throttle de InteresEspacial") y le da el recurso al
## jugador que recolectó.
func _recolectar_local(jugador: Node) -> void:
	_agotado = true
	_aplicar_estado_visual(true)
	_timer_respawn.start()
	if Utils.en_red():
		rpc("_recibir_estado_red", true)
	_dar_recurso(jugador)


## Sin ningún chequeo de equipo — pedido explícito del usuario.
func _dar_recurso(jugador: Node) -> void:
	if item_recurso == null:
		return
	var inventario: Node = null
	if jugador and is_instance_valid(jugador):
		inventario = jugador.get_node_or_null("InventarioComponente")
	if inventario:
		inventario.agregar_item(item_recurso)
	else:
		GestorInventario.agregar_item(item_recurso)
	if not Utils.en_red() or not multiplayer.is_server():
		return
	if jugador and "peer_id_dueño" in jugador:
		var confirmaciones := jugador.get_node_or_null("ComponenteConfirmacionesRed")
		if confirmaciones:
			confirmaciones.rpc_id(jugador.peer_id_dueño, "_recibir_botin_red", item_recurso.resource_path, item_recurso.quantity)


func esta_agotado() -> bool:
	return _agotado


## Recolección por un NPC no-jugador (ver Lenador.gd): mismo camino de
## estado agotado/animación/timer/broadcast que _recolectar_local(), pero
## sin pasar por _dar_recurso() — ese método asume un Jugador con
## InventarioComponente y, si no lo encuentra, el ítem cae en el facade
## GestorInventario de respaldo (pensado para un jugador local; en el
## servidor headless el ítem se perdería). El NPC se hace cargo del
## DatosItem devuelto por su cuenta.
func recolectar_para_npc() -> DatosItem:
	if _agotado:
		return null
	_agotado = true
	_aplicar_estado_visual(true)
	_timer_respawn.start()
	if Utils.en_red():
		rpc("_recibir_estado_red", true)
	return item_recurso


func _al_timeout_respawn() -> void:
	_agotado = false
	_aplicar_estado_visual(false)
	if Utils.en_red() and multiplayer.is_server():
		rpc("_recibir_estado_red", false)


@rpc("authority", "reliable")
func _recibir_estado_red(agotado: bool) -> void:
	_agotado = agotado
	_aplicar_estado_visual(agotado)


## play() + seek(0.0, true): aplica el frame YA, en el mismo llamado — sin
## el seek, AnimationPlayer recién aplica las keys en el próximo _process
## real (1 frame de demora en juego, y en una prueba --script de un solo
## frame directamente nunca llega a aplicarse).
func _aplicar_estado_visual(agotado: bool) -> void:
	if animation_player:
		animation_player.play(_ANIM_CORTADO if agotado else _ANIM_COMPLETO)
		animation_player.seek(0.0, true)
	if area_interaccion and _cuerpos_dentro_interaccion > 0:
		if agotado:
			GestorInteraccion.quitar(self)
		else:
			GestorInteraccion.registrar(self, nombre if nombre != "" else texto_interaccion, acciones_interaccion())


## Cubre tanto reconexión como conexión tardía — mismo criterio que
## NivelNidoArañaReina._al_peer_listo: si este objeto YA está agotado
## cuando un peer nuevo termina de cargar SU nivel, hay que avisarle el
## estado real (dirigido, no broadcast — a nadie más le cambió nada).
func _al_peer_listo(peer_id: int) -> void:
	if not _agotado:
		return
	if GestorNiveles.nivel_de_peer(peer_id) != _mi_nivel():
		return
	rpc_id(peer_id, "_recibir_estado_red", true)


func _mi_nivel() -> NivelBase:
	var nodo := get_parent()
	while nodo != null:
		if nodo is NivelBase:
			return nodo
		nodo = nodo.get_parent()
	return null
