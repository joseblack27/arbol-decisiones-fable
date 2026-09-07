class_name GolpeBasico
extends Area2D
## Hitbox de corta duración para golpe cuerpo a cuerpo.
## Se reutiliza vía GestorPiscinas en vez de crearse/destruirse en cada golpe.

var _daño: float           = 15.0
var _duracion: float       = 0.15
var _timer: float          = 0.0
var _entidad_fuente: Node  = null
var _configurado: bool     = false
var _tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO
## true = aplicar el daño en el próximo _physics_process(). Antes esto era
## call_deferred("_aplicar_daño"), que corre en el paso IDLE — una consulta
## de física (direct_space_state.intersect_shape, ver _aplicar_daño) fuera de
## _physics_process obliga al motor a sincronizar todo el estado físico
## pendiente antes de responder, un costo que crece con la cantidad de
## cuerpos en el mundo. Medido en una prueba de carga real: con varios
## jugadores golpeando, Performance.TIME_PROCESS (el paso idle) subía a
## ~17-20ms de golpe apenas había combate real, mientras TIME_PHYSICS_
## PROCESS se mantenía sano — la firma clásica de una consulta de física mal
## ubicada. Un fotograma físico de espera (en vez de uno idle) es la misma
## demora que ya había, solo que en el lugar correcto.
var _daño_pendiente: bool  = false

@onready var _col_shape: CollisionShape2D = $CollisionShape2D
var _forma: CircleShape2D

func _ready() -> void:
	_forma = _col_shape.shape as CircleShape2D

## Configura el golpe y aplica el daño en el siguiente frame.
## cantidad_daño — daño aplicado a cada objetivo alcanzado.
## radio         — radio del área de golpe.
## fuente        — entidad que realizó el golpe (evita auto-daño).
## duracion      — segundos antes de que se destruya el nodo.
## tipo          — tipo de daño (afecta resistencias del defensor).
func configurar(cantidad_daño: float, radio: float, fuente: Node, duracion: float, tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO) -> void:
	_daño           = cantidad_daño
	_forma.radius   = radio
	_entidad_fuente = fuente
	_duracion       = duracion
	_tipo_dano      = tipo
	_configurado    = true
	# Reinicio para reutilización desde la piscina (ver GestorPiscinas): esta
	# instancia puede llegar recién creada o reciclada de un golpe anterior.
	_timer = 0.0
	set_deferred("monitorable", true)
	_daño_pendiente = true

## GestorPiscinas.liberar() llama esto justo antes de esconder el nodo: sin
## esto, un golpe "en espera" en la piscina seguiría siendo un collider
## válido para las queries de OTROS golpes/proyectiles mientras está oculto.
func _al_liberar_a_piscina() -> void:
	set_deferred("monitorable", false)

func _aplicar_daño() -> void:
	Combate.golpear_area(self, _forma, _daño, _entidad_fuente, _tipo_dano, "golpe_basico")

func _physics_process(_delta: float) -> void:
	if _daño_pendiente:
		_daño_pendiente = false
		_aplicar_daño()

func _process(delta: float) -> void:
	if not _configurado:
		return
	_timer += delta
	if _timer >= _duracion:
		GestorPiscinas.liberar(self)

func _draw() -> void:
	if _forma:
		draw_circle(Vector2.ZERO, _forma.radius, Color(1.0, 1.0, 1.0, 0.25))
