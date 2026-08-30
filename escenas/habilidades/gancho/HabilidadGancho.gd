class_name HabilidadGancho
extends HabilidadProyectil
## Gancho: dispara un proyectil que, si engancha a un enemigo, lo arrastra
## en un tirón rápido hasta quedar justo enfrente del jugador.
##
## A diferencia del resto de las habilidades (que solo congelan al dueño
## un margen breve ANTES de disparar, ver HabilidadBase.activar()/
## _MARGEN_CONGELAMIENTO_RED), acá el bloqueo dura TODO lo que el gancho
## tarda en resolverse: desde que sale el proyectil hasta que se sabe si
## enganchó a alguien (y, si enganchó, hasta que termina el tirón) —
## pedido explícito del usuario: "desde que lance el proyectil el jugador
## no se podra mover ni hacer ninguna otra accion". El mismo bloqueo
## (movimiento Y otras habilidades, ver el chequeo agregado en
## HabilidadBase.activar()) se aplica también al ENGANCHADO mientras dura
## el tirón — ver _iniciar_tiron().

## Cuánto dura el tirón una vez que el gancho enganchó a alguien.
@export var duracion_tiron: float = 0.5
## Qué tan lejos, delante del jugador (en la dirección del disparo), cae
## el punto de llegada del tirón.
@export var distancia_frente: float = 40.0

@export_group("Hilo")
@export var color_hilo: Color = Color(0.45, 0.32, 0.18, 0.95)
@export var grosor_hilo: float = 3.0
## Offset del origen del hilo respecto a la posición del jugador — pedido
## del usuario, para que salga desde donde está el sprite (ej. la mano),
## no desde los pies. (0, -16) sube el origen 16px.
@export var offset_origen_hilo: Vector2 = Vector2(0, -16)
## Mismo criterio que offset_origen_hilo, pero para la PUNTA del hilo —
## pedido del usuario, para que quede atada al sprite del gancho (ver
## GanchoProyectil.tscn) en vez de a su origen físico (el Area2D). Se
## aplica igual mientras vuela (sigue al proyectil) y mientras dura el
## tirón (sigue al enganchado), para que no "salte" al cambiar de fase.
@export var offset_punta_hilo: Vector2 = Vector2(0, -8)

var _direccion_lanzada := Vector2.RIGHT

## Hilo visual entre el jugador y la punta del gancho — sigue al proyectil
## mientras vuela, y al enganchado mientras dura el tirón (ver _process),
## así se ve "recogerse" a medida que lo va trayendo. Puro efecto local:
## corre igual en cada peer porque cada uno ejecuta su propia _ejecutar()
## (ver el comentario de más abajo), sin RPC propio.
var _hilo: Line2D = null
var _proyectil_actual: GanchoProyectil = null
var _objetivo_enganchado: Node2D = null


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Gancho"
	tipo_habilidad   = "gancho"


func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(_hilo):
		return
	var punta: Node2D = _objetivo_enganchado if is_instance_valid(_objetivo_enganchado) else _proyectil_actual
	if not is_instance_valid(punta):
		_quitar_hilo()
		return
	_hilo.points = [Vector2.ZERO, _hilo.to_local(punta.global_position + offset_punta_hilo)]


func _ejecutar(direccion: Vector2, poder: float) -> void:
	_direccion_lanzada = direccion.normalized() if direccion.length() > 0.1 else Vector2.RIGHT
	var proy := GestorPiscinas.obtener(escena_proyectil) as GanchoProyectil
	proy.global_position = entidad_dueña.global_position
	proy.alcance_base = alcance_maximo
	var poder_efectivo := poder if alcance_segun_poder else 1.0
	proy.configurar(_direccion_lanzada, poder_efectivo, _calcular_dano(int(daño_proyectil)), entidad_dueña, tipo_dano)
	proy.poner_textura_icono(icono_provisional if usar_icono_como_sprite else null)
	proy.habilidad_dueña = self
	_proyectil_actual = proy
	_crear_hilo()
	# Bloqueo EXTENDIDO más allá del margen fijo de HabilidadBase.activar()
	# (que ya se soltó ANTES de llegar acá, ver ese archivo): se vuelve a
	# bloquear apenas el proyectil sale, y recién se libera cuando se
	# resuelve (ver _al_resolver_gancho). Corre igual en los dos lados
	# (predicción del cliente dueño Y autoridad del servidor — cada uno
	# ejecuta su propia _ejecutar(), ver HabilidadBase._disparar()), sin
	# necesitar ningún RPC nuevo para esta parte.
	if is_instance_valid(entidad_dueña) and entidad_dueña.has_method("bloquear_control"):
		entidad_dueña.bloquear_control()


## Colgado del propio jugador (no de current_scene): así el punto de origen
## (0,0 local, desplazado por offset_origen_hilo) es siempre la posición
## del jugador sin tener que rastrearla a mano, y desaparece solo si el
## jugador se libera a mitad de vuelo.
func _crear_hilo() -> void:
	if not is_instance_valid(entidad_dueña) or not (entidad_dueña is Node2D):
		return
	_hilo = Line2D.new()
	_hilo.position = offset_origen_hilo
	_hilo.width = grosor_hilo
	_hilo.default_color = color_hilo
	_hilo.z_index = -1  # detrás del sprite del gancho y de los personajes
	(entidad_dueña as Node2D).add_child(_hilo)


func _quitar_hilo() -> void:
	if is_instance_valid(_hilo):
		_hilo.queue_free()
	_hilo = null
	_proyectil_actual = null
	_objetivo_enganchado = null


## Llamado por GanchoProyectil al resolverse (enganchó o se quedó sin
## alcance). Si no enganchó a nadie, soltar al jugador ya. Si enganchó,
## arrancar el tirón (que suelta al terminar, ver _terminar_tiron).
func _al_resolver_gancho(impacto: bool, objetivo: Node) -> void:
	_proyectil_actual = null
	if not impacto or objetivo == null or not is_instance_valid(objetivo):
		_quitar_hilo()
		_liberar_lanzador()
		return
	# A partir de acá el hilo sigue al enganchado en vez del proyectil (ya
	# vuelto a la piscina) — ver _process().
	_objetivo_enganchado = objetivo as Node2D
	_iniciar_tiron(objetivo)


func _liberar_lanzador() -> void:
	if is_instance_valid(entidad_dueña) and entidad_dueña.has_method("desbloquear_control"):
		entidad_dueña.desbloquear_control()


## Arrastra al enganchado hasta el punto fijo enfrente del jugador (misma
## dirección con la que se lanzó el gancho). Dirección y destino se fijan
## ACÁ, en el instante del impacto: ni el jugador ni el enganchado se
## pueden mover mientras tanto (ver el bloqueo de HabilidadBase.activar()
## y la inmovilización de abajo), así que no hace falta recalcular nada
## mientras dura el tirón.
##
## El movimiento REAL de la posición del enganchado solo corre con
## autoridad real (servidor, o un jugador solo) — en un cliente puro es
## una réplica más, igual que cualquier otro enemigo (ver Enemigo.
## _physics_process): no hace falta ninguna predicción ni RPC nuevo acá,
## el cliente ve el tirón por la MISMA interpolación de posición que ya
## existe para todo enemigo. Lo único que sí corre en cualquier lado es
## el propio timer de soltar al lanzador — simétrico entre cliente y
## servidor, mismo criterio que el tope de duración del lanzallamas.
func _iniciar_tiron(objetivo: Node) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		# Acá no corre el tween (ver el comentario de arriba), pero el hilo
		# igual sigue al enganchado por su posición replicada (ver
		# _process) — solo hace falta soltarlo cuando termine.
		get_tree().create_timer(duracion_tiron).timeout.connect(_liberar_lanzador)
		get_tree().create_timer(duracion_tiron).timeout.connect(_quitar_hilo)
		return

	var mov := objetivo.get_node_or_null("MovimientoComponente") as MovimientoComponente
	var arbol := objetivo.get_node_or_null("ArbolComportamiento") as ArbolComportamiento
	if mov:
		mov.agregar_inmovilizacion()
	if arbol:
		arbol.establecer_activo(false)

	var destino: Vector2 = (entidad_dueña as Node2D).global_position + _direccion_lanzada * distancia_frente
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(objetivo, "global_position", destino, duracion_tiron)
	tween.finished.connect(_terminar_tiron.bind(objetivo, mov, arbol))


func _terminar_tiron(objetivo: Node, mov: MovimientoComponente, arbol: ArbolComportamiento) -> void:
	if is_instance_valid(mov):
		mov.quitar_inmovilizacion()
	if is_instance_valid(arbol):
		arbol.establecer_activo(true)
	_quitar_hilo()
	_liberar_lanzador()
