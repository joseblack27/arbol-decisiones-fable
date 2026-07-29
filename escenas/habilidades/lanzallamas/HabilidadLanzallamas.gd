class_name HabilidadLanzallamas
extends HabilidadBase
## Lanzallamas: cono de daño continuo mientras mantienes el dedo sobre el
## joystick de esta habilidad — a diferencia del resto (que se "activan" una
## vez, ver HabilidadBase.activar()), acá el disparo dura lo que dure el
## toque. Por eso NO usa ese flujo: escucha DIRECTO las señales crudas de su
## propio slot (apunte/lanzar/cancelar — ver UIHabilidad.gd), igual que hace
## ZonaCancelacion, y arma su propio protocolo de red de "canal" en vez del
## de "un solo golpe" (_activar_red/_reproducir_visual_red).
##
## costo_energia (heredado de HabilidadBase) se reinterpreta acá como costo
## POR TICK, no una vez al activar — gasto fijo mientras mantenés
## presionado, se corta solo si te quedás sin combustible. duracion_recarga
## (también heredado) SÍ es un cooldown de verdad acá: arranca al SOLTAR
## (o al llegar a duracion_maxima_canal, o quedarte sin energía) — aunque
## hayas disparado un solo segundo, entra en cooldown igual.
##
## El cono de DAÑO real (_construir_forma_cono/Combate.golpear_area) solo
## corre en el cliente dueño (predicción) y en el servidor (autoridad, el
## daño de verdad) — nunca en un espectador, no tendría sentido que
## calculara daño ajeno. El SPRITE del chorro sí se avisa a los demás
## clientes cercanos por un RPC de broadcast propio (ver _avisar_visual_a_
## espectadores más abajo, mismo patrón que HabilidadBase._reproducir_
## visual_red pero adaptado al protocolo de canal continuo de esta clase),
## para que un jugador viendo a otro usar esto también vea el chorro.

@export_group("Cono")
## Daño de un golpe COMPLETO (pasa por _calcular_dano, respeta dano_base_
## min/max del recurso equipado) — el tick real solo aplica una FRACCIÓN de
## esto, ver multiplicador_dano_tick. Repartir el daño total en varios
## ticks (en vez de éste completo por tick) es lo que evita que un
## lanzallamas encimado a un objetivo lo derrita en un tick — balance
## pedido por el usuario tras probarlo.
@export var dano_por_tick: float = 6.0
## Fracción de dano_por_tick que se aplica en cada tick real (0.2 = 20%).
@export_range(0.05, 1.0, 0.05) var multiplicador_dano_tick := 0.2
@export var intervalo_tick: float = 0.2
@export var alcance_cono: float = 220.0
@export var angulo_cono_grados: float = 50.0
## Tope duro de cuánto puede durar UN chorro, sin importar que sigas con el
## dedo puesto — al llegar acá se corta solo (y entra en cooldown) como si
## hubieras soltado.
@export var duracion_maxima_canal: float = 5.0

## Marca para ZonaCancelacion: las habilidades de canal continuo no se
## "cancelan" (soltar YA es parar) — la zona de cancelar no aparece para
## esta habilidad. Solo importa que la propiedad EXISTA (se detecta con
## `"es_canal_continuo" in hab`).
var es_canal_continuo := true

var _canalizando := false
var _direccion_canal := Vector2.RIGHT
var _acumulador_tick := 0.0
var _tiempo_canalizando := 0.0
## true cuando el canal terminó SOLO (tiempo máximo o sin energía) con el
## dedo todavía puesto: el "apunte" sigue llegando cada fotograma, y sin
## este cerrojo, apenas venciera el cooldown el chorro rearrancaba solo sin
## que el jugador lo pidiera (reportado). Se libera únicamente al SOLTAR.
var _esperando_soltar := false

var _sig_apunte := ""
var _sig_lanzar := ""
var _sig_cancelar := ""

## Alcance (px, tamaño nativo del PNG en pixel art — ver assets/efectos/
## lanzallamas.png, 4 frames de 48px de ancho cada uno; medido a mano
## revisando el alfa real de cada frame, no a ojo) al que llega el arte de
## ChorroVisual a escala 1:1, desde el punto de anclaje (offset, x=0, el
## lado angosto) hasta la punta — la base para escalar el sprite según
## alcance_cono, así el visual sigue coincidiendo con el alcance real
## aunque se ajuste el recurso equipado o se cambie el arte de nuevo.
const _LARGO_SPRITE_BASE := 46.0
## get_node_or_null (no "$"): instancias armadas a mano sin pasar por este
## .tscn (p. ej. pruebas/prueba_lanzallamas.gd, que arma la habilidad desde
## el script pelado) no tienen este hijo — sin esto, cada una imprimía un
## ERROR de consola por "Node not found" aunque el resto funcionara bien.
@onready var _chorro_visual: Sprite2D = get_node_or_null("ChorroVisual")

## true si esto muestra el sprite del chorro por un AVISO DE RED (soy un
## espectador viendo a OTRO jugador usar esto), separado a propósito de
## _canalizando: ese otro campo también dispara el resto de _process()
## (daño, consumo de energía, tope de duración, bloquear/desbloquear
## control...) — nada de eso debe correr en la réplica de un espectador,
## que solo tiene que MOSTRAR lo que el servidor avisó, no simularlo.
var _mostrar_visual_remoto := false
var _direccion_visual_remoto := Vector2.RIGHT


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Lanzallamas"
	tipo_habilidad   = "lanzallamas"
	# duracion_recarga NO se fuerza acá: la fija el recurso equipado (ver
	# aplicar_datos, "enfriamiento") — sí es un cooldown real.
	_sig_apunte   = "slot_%d_apunte"   % slot_index
	_sig_lanzar   = "slot_%d_lanzar"   % slot_index
	_sig_cancelar = "slot_%d_cancelar" % slot_index
	SeñalManager.conectar(_sig_apunte,   self, "_on_apunte")
	SeñalManager.conectar(_sig_lanzar,   self, "_on_soltar")
	SeñalManager.conectar(_sig_cancelar, self, "_on_soltar")


func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	alcance_cono = d.alcance_metros * ESCALA_METROS_PIXEL


func _process(delta: float) -> void:
	super._process(delta)  # Tick normal de recarga heredado (pie del cooldown).
	_actualizar_visual_chorro()
	if not _canalizando:
		return
	if not is_instance_valid(entidad_dueña) \
			or (("_muerto" in entidad_dueña) and entidad_dueña.get("_muerto")):
		_detener_canal()
		return
	# El tope de duración corre en AMBOS lados (cliente dueño y servidor,
	# cada uno con su propio timer independiente pero determinista — mismo
	# duracion_maxima_canal en los dos): el cliente necesita cortar su
	# propia predicción visual a tiempo, no solo esperar a que el servidor
	# se lo diga.
	_tiempo_canalizando += delta
	if _tiempo_canalizando >= duracion_maxima_canal:
		_detener_canal()
		return
	# El daño/consumo real de energía SOLO donde hay autoridad de verdad:
	# el servidor, o el único jugador sin red (mismo gate que
	# VidaComponente.quitar_vida) — en un cliente puro esto es predicción
	# visual pura, sin efecto real.
	if Utils.en_red() and not multiplayer.is_server():
		return
	_acumulador_tick += delta
	if _acumulador_tick < intervalo_tick:
		return
	_acumulador_tick -= intervalo_tick
	if costo_energia > 0.0:
		var energia := entidad_dueña.get_node_or_null("EnergiaComponente") as EnergiaComponente
		if energia and not energia.consumir(costo_energia):
			_detener_canal()
			return
	# Base SIN escalar (solo el random 4-8 del recurso) — golpear_area aplica
	# el pipeline de atributos completo (bono plano + potencia + crítico +
	# resistencias) y RECIÉN AHÍ multiplica por multiplicador_dano_tick,
	# mismo orden que usa el panel de detalle para calcular la descripción.
	var dano_base := _calcular_dano(int(dano_por_tick))
	Combate.golpear_area(entidad_dueña, _construir_forma_cono(), dano_base, entidad_dueña, tipo_dano, "lanzallamas", true, multiplicador_dano_tick)


func _construir_forma_cono() -> Shape2D:
	const SEGMENTOS := 8
	var mitad := deg_to_rad(angulo_cono_grados) / 2.0
	var puntos := PackedVector2Array([Vector2.ZERO])
	for i in (SEGMENTOS + 1):
		var angulo := lerpf(-mitad, mitad, float(i) / float(SEGMENTOS))
		puntos.append(_direccion_canal.rotated(angulo) * alcance_cono)
	var forma := ConvexPolygonShape2D.new()
	forma.points = puntos
	return forma


## Puramente visual (ChorroVisual, ver assets/efectos/lanzallamas.png,
## sprite del usuario en 4 frames) — no afecta el daño real, que sigue
## siendo _construir_forma_cono()/Combate.golpear_area de arriba. El
## parpadeo de los 4 frames lo maneja solo el AnimationPlayer hermano
## (autoplay, en loop — ver el .tscn); acá solo hace falta prender/apagar
## la visibilidad y seguir la posición/dirección del dueño, la animación
## en sí corre sin que este script tenga que tocarla. Solo tiene sentido
## dibujar algo donde de verdad hay pantalla: se chequea DisplayServer, no
## la red, porque en un solo jugador (sin red) TAMBIÉN hace falta
## mostrarlo.
##
## Se muestra por _canalizando (dueño local o servidor) O por
## _mostrar_visual_remoto (espectador avisado por RPC — ver
## _avisar_visual_a_espectadores/_recibir_inicio_visual_chorro_red): un
## espectador nunca tiene _canalizando en true (nunca le llega ni
## _on_apunte —_soy_quien_controla lo corta— ni _iniciar_canal_red —solo
## corre en el servidor—), así que sin el aviso de red se quedaría sin ver
## nada (reportado por el usuario, arreglado acá).
func _actualizar_visual_chorro() -> void:
	if not _chorro_visual or DisplayServer.get_name() == "headless":
		return
	var mostrar := _canalizando or _mostrar_visual_remoto
	_chorro_visual.visible = mostrar
	if not mostrar or not is_instance_valid(entidad_dueña):
		return
	var direccion_mostrada := _direccion_canal if _canalizando else _direccion_visual_remoto
	_chorro_visual.global_position = (entidad_dueña as Node2D).global_position
	_chorro_visual.rotation = direccion_mostrada.angle()
	_chorro_visual.scale = Vector2.ONE * (alcance_cono / _LARGO_SPRITE_BASE)


# ── Entrada cruda del propio slot (ver UIHabilidad.gd) ────────────────────────

func _on_apunte(direccion: Vector2, _poder: float) -> void:
	if not _soy_quien_controla():
		return
	if direccion.length() < 0.1:
		return
	if _esperando_soltar:
		return  # El canal anterior terminó solo — soltar antes de repetir.
	_orientar_hacia(direccion)
	if not _canalizando:
		_iniciar_canal(direccion)
		return
	_direccion_canal = direccion
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_actualizar_direccion_canal_red", direccion)


## Gira al dueño hacia donde apunta el chorro — mismo giro que HabilidadBase.
## activar() ya hace para el resto de las habilidades (ver ese archivo), pero
## acá hay que repetirlo a mano: Lanzallamas NO pasa por activar() (ver
## comentario de clase), así que sin esto el personaje nunca giraba hacia
## donde apunta mientras canaliza — ni en el cliente dueño (reapunta cada
## fotograma mientras arrastra el joystick) ni para los DEMÁS jugadores
## (que ven la copia autoritativa del servidor, replicada vía
## Jugador._ultima_direccion — ver _iniciar_canal_red/_actualizar_direccion_
## canal_red más abajo, que llaman esto mismo del lado del servidor).
## Acotado a "jugadores" por la misma razón que el hook de HabilidadBase: los
## mobs manejan su propio direccion_mirada desde su IA (AccionAtacar), y
## HabilidadLanzallamas hoy no la usa ningún enemigo, pero mejor no dejar la
## mina si algún día la usara.
func _orientar_hacia(direccion: Vector2) -> void:
	if is_instance_valid(entidad_dueña) and entidad_dueña.is_in_group("jugadores") \
			and "direccion_mirada" in entidad_dueña:
		entidad_dueña.direccion_mirada = direccion.normalized()


func _on_soltar(_direccion: Vector2 = Vector2.ZERO, _poder: float = 0.0) -> void:
	if not _soy_quien_controla():
		return
	_detener_canal()
	# DESPUÉS de _detener_canal (que lo pone en true): soltar es justamente
	# lo que libera el cerrojo de "no rearrancar solo".
	_esperando_soltar = false


## true si esto corre donde de verdad hay que decidir (un solo jugador, el
## servidor, o el cliente dueño de este cuerpo) — evita que la réplica de
## OTRO jugador en mi pantalla reaccione a mi propio joystick (SeñalManager
## es un bus global sin distinción de a quién pertenece cada slot).
func _soy_quien_controla() -> bool:
	if not Utils.en_red():
		return true
	if not is_instance_valid(entidad_dueña) or not ("peer_id_dueño" in entidad_dueña):
		return false
	if multiplayer.is_server():
		return true
	return entidad_dueña.peer_id_dueño == multiplayer.get_unique_id()


func _iniciar_canal(direccion: Vector2) -> void:
	# puede_usarse() (heredado): en cooldown desde la última vez que se
	# soltó — no deja arrancar un chorro nuevo hasta que termine.
	if not puede_usarse():
		return
	if ("_muerto" in entidad_dueña) and entidad_dueña.get("_muerto"):
		return
	_canalizando = true
	_direccion_canal = direccion
	_acumulador_tick = 0.0
	_tiempo_canalizando = 0.0
	if entidad_dueña.has_method("bloquear_control"):
		entidad_dueña.bloquear_control()
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_iniciar_canal_red", direccion)


func _detener_canal() -> void:
	if not _canalizando:
		return
	_aplicar_fin_canal_local()
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_terminar_canal_red")
	elif Utils.en_red() and multiplayer.is_server():
		# Esto corrió con autoridad real (energía agotada o tiempo máximo,
		# detectados ACÁ mismo en _process — no por un aviso del cliente):
		# avisar a los espectadores Y al propio dueño remoto. Sin esto, un
		# cliente puro nunca se entera de que el SERVIDOR cortó su canal
		# por estas razones (nunca corre esa lógica él mismo, ver el gate
		# de _process más abajo) — su propia predicción seguía
		# "canalizando" (chorro animando) hasta que soltara el dedo a mano
		# (reportado: "no detiene la animación cuando se acaba la energía
		# o el tiempo, solo si se suelta antes").
		_avisar_fin_visual_a_espectadores()


## Cierre LOCAL del canal (predicción/UI/cooldown): separado de
## _detener_canal() para poder reutilizarlo también cuando el SERVIDOR
## avisa que cortó el canal por su cuenta (ver _recibir_fin_visual_chorro_
## red) — ahí no hay que volver a mandar ningún RPC, solo reflejar el
## corte en esta copia.
func _aplicar_fin_canal_local() -> void:
	_canalizando = false
	# Si esto llegó por tiempo máximo/energía agotada el dedo puede seguir
	# puesto: exigir soltar antes del próximo chorro. Si llegó por soltar,
	# _on_soltar lo limpia justo después.
	_esperando_soltar = true
	# Soltar también el APUNTADO de la UI aunque el dedo siga puesto
	# (pedido del usuario): el botón se desengancha del toque y emite
	# cancelar — con eso el indicador de apunte y la zona de cancelación se
	# esconden ya, en vez de quedarse "apuntando" un chorro que ya no
	# existe. OJO: ese cancelar dispara _on_soltar (conectado a la señal),
	# que re-entra acá (corta por _canalizando=false de arriba) y limpia
	# _esperando_soltar — correcto: el toque quedó desenganchado, así que
	# ya no llega ningún apunte que pudiera rearrancar nada.
	if is_inside_tree():
		UIHabilidad.cancelar_apunte_de_slot(get_tree(), slot_index)
	if is_instance_valid(entidad_dueña) and entidad_dueña.has_method("desbloquear_control"):
		entidad_dueña.desbloquear_control()
	# El cooldown empieza al SOLTAR (o cortarse solo), no al empezar a
	# disparar — mismo criterio que _iniciar_recarga() ya usa en el resto
	# de las habilidades, solo que acá el disparo puede durar variable
	# (1s o los 5s completos) y en ambos casos entra en cooldown igual.
	_iniciar_recarga()


# ── Servidor: mismo canal, con autoridad real ──────────────────────────────────

@rpc("any_peer", "reliable")
func _iniciar_canal_red(direccion: Vector2) -> void:
	if not multiplayer.is_server() or not _validar_remitente():
		return
	if not puede_usarse():
		return
	if ("_muerto" in entidad_dueña) and entidad_dueña.get("_muerto"):
		return
	_canalizando = true
	_direccion_canal = direccion.normalized() if direccion.length() > 0.1 else Vector2.RIGHT
	_orientar_hacia(_direccion_canal)
	_acumulador_tick = 0.0
	_tiempo_canalizando = 0.0
	if entidad_dueña.has_method("bloquear_control"):
		entidad_dueña.bloquear_control()
	_avisar_visual_a_espectadores("_recibir_inicio_visual_chorro_red", _direccion_canal)


@rpc("any_peer", "unreliable_ordered")
func _actualizar_direccion_canal_red(direccion: Vector2) -> void:
	if not multiplayer.is_server() or not _canalizando or not _validar_remitente():
		return
	if direccion.length() > 0.1:
		_direccion_canal = direccion.normalized()
		_orientar_hacia(_direccion_canal)
		_avisar_visual_a_espectadores("_recibir_actualizacion_visual_chorro_red", _direccion_canal)


@rpc("any_peer", "reliable")
func _terminar_canal_red() -> void:
	if not multiplayer.is_server() or not _validar_remitente():
		return
	_detener_canal()


func _validar_remitente() -> bool:
	if not is_instance_valid(entidad_dueña) or not ("peer_id_dueño" in entidad_dueña):
		return false
	return multiplayer.get_remote_sender_id() == entidad_dueña.peer_id_dueño


# ── Réplica visual a espectadores (pedido del usuario) ────────────────────────

## Avisa a los peers cercanos (ver InteresEspacial, mismo patrón que
## Jugador._replicar_posicion_red/Enemigo._physics_process) que este
## jugador está canalizando el lanzallamas — para que también muestren el
## ChorroVisual, aunque no sean su dueño ni corran el daño real (eso sigue
## gateado a servidor/single-player en _process, ver arriba). Incluye al
## propio dueño en la lista (InteresEspacial ya se filtra así siempre) sin
## problema: para él es un aviso redundante e inofensivo, ya se muestra
## solo por su propia predicción (_canalizando).
func _avisar_visual_a_espectadores(metodo: String, direccion: Vector2) -> void:
	if not is_instance_valid(entidad_dueña) or not (entidad_dueña is Node2D):
		return
	for peer_id in InteresEspacial.peers_cercanos((entidad_dueña as Node2D).global_position):
		rpc_id(peer_id, metodo, direccion)


func _avisar_fin_visual_a_espectadores() -> void:
	if not is_instance_valid(entidad_dueña) or not (entidad_dueña is Node2D):
		return
	for peer_id in InteresEspacial.peers_cercanos((entidad_dueña as Node2D).global_position):
		rpc_id(peer_id, "_recibir_fin_visual_chorro_red")


@rpc("authority", "reliable")
func _recibir_inicio_visual_chorro_red(direccion: Vector2) -> void:
	_mostrar_visual_remoto = true
	_direccion_visual_remoto = direccion


@rpc("authority", "unreliable_ordered")
func _recibir_actualizacion_visual_chorro_red(direccion: Vector2) -> void:
	if _mostrar_visual_remoto:
		_direccion_visual_remoto = direccion


@rpc("authority", "reliable")
func _recibir_fin_visual_chorro_red() -> void:
	_mostrar_visual_remoto = false
	# Si además SOY el dueño real de este canal, esto significa que el
	# SERVIDOR lo cortó por su cuenta (energía agotada o tiempo máximo,
	# ver _detener_canal()) sin que yo se lo pidiera — mi propia
	# predicción (_canalizando) nunca se hubiera enterado sola, porque el
	# consumo de energía real solo corre server-side (ver el gate en
	# _process). Sin esto, mi chorro seguía "canalizando" en mi pantalla
	# hasta soltar el dedo a mano (reportado).
	if _canalizando and is_instance_valid(entidad_dueña) and ("peer_id_dueño" in entidad_dueña) \
			and entidad_dueña.peer_id_dueño == multiplayer.get_unique_id():
		_aplicar_fin_canal_local()
