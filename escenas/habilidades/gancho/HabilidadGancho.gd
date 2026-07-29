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

var _direccion_lanzada := Vector2.RIGHT


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Gancho"
	tipo_habilidad   = "gancho"


func _ejecutar(direccion: Vector2, poder: float) -> void:
	_direccion_lanzada = direccion.normalized() if direccion.length() > 0.1 else Vector2.RIGHT
	var proy := GestorPiscinas.obtener(escena_proyectil) as GanchoProyectil
	proy.global_position = entidad_dueña.global_position
	proy.alcance_base = alcance_maximo
	var poder_efectivo := poder if alcance_segun_poder else 1.0
	proy.configurar(_direccion_lanzada, poder_efectivo, _calcular_dano(int(daño_proyectil)), entidad_dueña, tipo_dano)
	proy.poner_textura_icono(_icono if usar_icono_como_sprite else null)
	proy.habilidad_dueña = self
	# Bloqueo EXTENDIDO más allá del margen fijo de HabilidadBase.activar()
	# (que ya se soltó ANTES de llegar acá, ver ese archivo): se vuelve a
	# bloquear apenas el proyectil sale, y recién se libera cuando se
	# resuelve (ver _al_resolver_gancho). Corre igual en los dos lados
	# (predicción del cliente dueño Y autoridad del servidor — cada uno
	# ejecuta su propia _ejecutar(), ver HabilidadBase._disparar()), sin
	# necesitar ningún RPC nuevo para esta parte.
	if is_instance_valid(entidad_dueña) and entidad_dueña.has_method("bloquear_control"):
		entidad_dueña.bloquear_control()


## Llamado por GanchoProyectil al resolverse (enganchó o se quedó sin
## alcance). Si no enganchó a nadie, soltar al jugador ya. Si enganchó,
## arrancar el tirón (que suelta al terminar, ver _terminar_tiron).
func _al_resolver_gancho(impacto: bool, objetivo: Node) -> void:
	if not impacto or objetivo == null or not is_instance_valid(objetivo):
		_liberar_lanzador()
		return
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
		get_tree().create_timer(duracion_tiron).timeout.connect(_liberar_lanzador)
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
	_liberar_lanzador()
