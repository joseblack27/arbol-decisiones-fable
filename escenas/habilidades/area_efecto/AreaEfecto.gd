class_name AreaEfecto
extends Area2D
## Área temporal que daña todos los VidaComponentes dentro al activarse.
## Se reutiliza vía GestorPiscinas en vez de crearse/destruirse cada vez.

@export var radio_base: float       = 80.0
@export var daño: float             = 30.0
@export var duracion_efecto: float  = 0.4

var entidad_fuente: Node = null
var tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO

@onready var _col_shape: CollisionShape2D = $CollisionShape2D
var _forma: CircleShape2D
var _timer: float   = 0.0
var _activado: bool = false

func _ready() -> void:
	_forma = _col_shape.shape as CircleShape2D

## Configura el área antes de que empiece a procesar.
## cantidad_daño — daño a aplicar a cada objetivo.
## fuente        — entidad que originó el área (evita auto-daño).
## tipo          — tipo de daño (afecta resistencias del defensor).
func configurar(cantidad_daño: float, fuente: Node, tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO) -> void:
	daño           = cantidad_daño
	entidad_fuente = fuente
	tipo_dano      = tipo
	_forma.radius  = radio_base
	# Reinicio para reutilización desde la piscina (ver GestorPiscinas): esta
	# instancia puede llegar recién creada o reciclada de una activación anterior.
	_timer      = 0.0
	_activado   = false
	set_deferred("monitorable", true)
	call_deferred("_aplicar_daño")

## GestorPiscinas.liberar() llama esto justo antes de esconder el nodo: sin
## esto, un área "en espera" en la piscina seguiría siendo un collider válido
## para las queries de otros golpes mientras está oculta.
func _al_liberar_a_piscina() -> void:
	set_deferred("monitorable", false)

func _aplicar_daño() -> void:
	_activado = true
	# respetar_equipo por defecto (true): los AoE tampoco tienen fuego amigo —
	# ni entre jugadores ni entre enemigos (antes golpeaban a TODO lo que
	# pisaran, aliados incluidos; se cambió junto con el resto de habilidades).
	Combate.golpear_area(self, _forma, daño, entidad_fuente, tipo_dano, "area_efecto")

func _process(delta: float) -> void:
	if not _activado:
		return
	_timer += delta
	if _timer >= duracion_efecto:
		GestorPiscinas.liberar(self)

func _draw() -> void:
	if _forma:
		draw_circle(Vector2.ZERO, _forma.radius, Color(0.8, 0.2, 0.8, 0.35))
		draw_arc(Vector2.ZERO, _forma.radius, 0.0, TAU, 32, Color(0.8, 0.2, 0.8, 0.9), 2.0)
