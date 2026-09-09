class_name Trampa
extends Area2D
## Trampa oculta: a diferencia de GolpeBasico/AreaEfecto (que dañan apenas
## se instancian), esta se queda ESPERANDO hasta que un enemigo entra en
## su radio de detección. Recién ahí explota con daño en área y se
## libera. Si nadie la pisa, se apaga sola a los duracion_maxima segundos
## (para que no queden clavadas para siempre). Se reutiliza vía
## GestorPiscinas en vez de crearse/destruirse cada vez.
##
## Mientras espera queda apenas visible, y SOLO para quien la colocó (ver
## _draw): un marcador tenue del radio de detección, no una zona pintada
## a pleno como la explosión — para los demás jugadores y para los mobs
## sigue siendo invisible de verdad (mismo criterio "local-only" que ya
## usa el resto de la UI de este proyecto, ver Utils.jugador_local()).

## Capa física de los mobs (ver Enemigo.CAPA_MOB) — la trampa SOLO
## reacciona a esto, nunca a jugadores ni obstáculos.
const _CAPA_MOB := 2

@export var radio_deteccion: float = 15.0
@export var radio_dano: float      = 30.0
@export var daño: float            = 45.0
@export var duracion_maxima: float = 20.0
## Cuánto queda visible el destello al activarse antes de volver a la
## piscina (mismo criterio que AreaEfecto.duracion_efecto).
@export var duracion_destello: float = 0.3

var entidad_fuente: Node = null
var tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO
## A quién avisarle si ESTA copia (la real, con detección) se activa — ver
## _on_body_entrada() y HabilidadTrampa._ejecutar()/avisar_trampa_activada().
## null en las copias puramente visuales (ver mostrar_solo_visual).
var _habilidad_dueña = null

@onready var _col_shape: CollisionShape2D = $CollisionShape2D
var _forma_deteccion: CircleShape2D
var _timer: float        = 0.0
var _activada: bool      = false
var _configurada: bool   = false


func _ready() -> void:
	_forma_deteccion = _col_shape.shape as CircleShape2D
	collision_mask = _CAPA_MOB
	body_entered.connect(_on_body_entrada)


## Arma la trampa antes de dejarla en el mapa.
## cantidad_daño   — daño del área al activarse.
## radio_det       — radio de detección (cuándo se dispara).
## radio_impacto   — radio del área de daño al activarse.
## fuente          — quien la colocó (evita auto-daño, escala con sus atributos).
## duracion        — segundos que espera antes de apagarse sola sin usar.
## tipo            — tipo de daño (afecta resistencias del defensor).
func configurar(cantidad_daño: float, radio_det: float, radio_impacto: float,
		fuente: Node, duracion: float,
		tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO,
		habilidad_dueña = null) -> void:
	daño              = cantidad_daño
	_forma_deteccion.radius = radio_det
	radio_dano        = radio_impacto
	entidad_fuente    = fuente
	duracion_maxima   = duracion
	tipo_dano         = tipo
	_habilidad_dueña  = habilidad_dueña
	# Reinicio para reutilización desde la piscina (ver GestorPiscinas):
	# esta instancia puede llegar recién creada o reciclada de una trampa
	# anterior.
	_timer      = 0.0
	_activada   = false
	_configurada = true
	set_deferred("monitoring", true)
	queue_redraw()


## Copia SOLO visual, para todo peer que no tenga autoridad real — mismo
## criterio que Cepo.mostrar_solo_visual (ver el comentario grande ahí):
## antes cada peer instanciaba y posicionaba su PROPIA trampa a partir de
## su propia vista de la posición del dueño, así que la explosión (cuando
## de verdad se activaba) podía verse en un punto distinto en cada
## pantalla. Sin "monitoring": nunca decide nada por su cuenta, solo
## refleja lo que le avisa el servidor vía activar_visual().
func mostrar_solo_visual(duracion: float, fuente: Node = null) -> void:
	duracion_maxima  = duracion
	entidad_fuente   = fuente
	_habilidad_dueña = null
	_timer      = 0.0
	_activada   = false
	_configurada = true
	set_deferred("monitoring", false)
	queue_redraw()


## GestorPiscinas.liberar() llama esto justo antes de esconder el nodo —
## sin esto, una trampa "en espera" en la piscina seguiría reaccionando a
## cuerpos que pasen cerca mientras está oculta.
func _al_liberar_a_piscina() -> void:
	set_deferred("monitoring", false)
	_configurada = false


func _on_body_entrada(_cuerpo: Node2D) -> void:
	if _activada or not _configurada:
		return
	_activar()


func _activar() -> void:
	_activada = true
	_timer = 0.0
	var forma_dano := CircleShape2D.new()
	forma_dano.radius = radio_dano
	Combate.golpear_area(self, forma_dano, daño, entidad_fuente, tipo_dano, "trampa")
	if is_instance_valid(_habilidad_dueña):
		_habilidad_dueña.avisar_trampa_activada(global_position)
	queue_redraw()


## El servidor avisó (HabilidadTrampa._activar_trampa_visual_red) que la
## copia REAL ya explotó — reproduce el mismo cambio visual acá, sin volver
## a decidir nada ni aplicar ningún daño por su cuenta.
func activar_visual() -> void:
	if _activada or not _configurada:
		return
	_activada = true
	_timer = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not _configurada:
		return
	_timer += delta
	if _activada:
		if _timer >= duracion_destello:
			GestorPiscinas.liberar(self)
		return
	if _timer >= duracion_maxima:
		GestorPiscinas.liberar(self)


func _draw() -> void:
	if _activada:
		draw_circle(Vector2.ZERO, radio_dano, Color(0.9, 0.6, 0.1, 0.35))
		draw_arc(Vector2.ZERO, radio_dano, 0.0, TAU, 32, Color(0.9, 0.6, 0.1, 0.9), 2.0)
		return
	# Marca del radio de detección — SOLO en la pantalla de quien la colocó
	# (ver comentario de clase). Un jugador ajeno o un mob nunca deberían
	# poder "verla venir" mirando la pantalla de otro. Círculo exterior
	# relleno negro + centro rojo, se dejan ver el suelo/objetos de abajo
	# (pedido del usuario: "que se vean más transparente" ambos) sin dejar
	# de notarse.
	if _configurada and is_instance_valid(entidad_fuente) and entidad_fuente == Utils.jugador_local():
		draw_circle(Vector2.ZERO, _forma_deteccion.radius, Color(0.0, 0.0, 0.0, 0.35))
		draw_circle(Vector2.ZERO, 6.0, Color(0.85, 0.1, 0.1, 0.4))
