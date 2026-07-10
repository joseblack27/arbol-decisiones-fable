class_name GolpeBasico
extends Area2D
## Hitbox de corta duración para golpe cuerpo a cuerpo.
## Se reutiliza vía GestorPiscinas en vez de crearse/destruirse en cada golpe.

var _daño: float           = 15.0
var _duracion: float       = 0.15
var _timer: float          = 0.0
var _entidad_fuente: Node  = null
var _configurado: bool     = false
var _tipo_dano: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC

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
func configurar(cantidad_daño: float, radio: float, fuente: Node, duracion: float, tipo: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC) -> void:
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
	call_deferred("_aplicar_daño")

## GestorPiscinas.liberar() llama esto justo antes de esconder el nodo: sin
## esto, un golpe "en espera" en la piscina seguiría siendo un collider
## válido para las queries de OTROS golpes/proyectiles mientras está oculto.
func _al_liberar_a_piscina() -> void:
	set_deferred("monitorable", false)

func _aplicar_daño() -> void:
	Combate.golpear_area(self, _forma, _daño, _entidad_fuente, _tipo_dano, "golpe_basico")

func _process(delta: float) -> void:
	if not _configurado:
		return
	_timer += delta
	if _timer >= _duracion:
		GestorPiscinas.liberar(self)

func _draw() -> void:
	if _forma:
		draw_circle(Vector2.ZERO, _forma.radius, Color(1.0, 1.0, 1.0, 0.25))
