class_name Arañazo
extends Area2D
## Hitbox + visual efímero del ataque Arañazo.
## Se obtiene de HabilidadArañazo._ejecutar() vía GestorPiscinas (reutilizado
## entre golpes en vez de crearse/destruirse cada vez), aplica daño al
## aparecer y vuelve a la piscina al terminar la animación.

var _daño: float = 15.0
var _entidad_fuente: Node = null
var _tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO
## Ver el comentario grande en GolpeBasico.gd: la consulta de física de
## _aplicar_daño() tiene que correr en _physics_process, no en el paso idle
## (antes era call_deferred, medido como costo real bajo carga real).
var _daño_pendiente: bool = false

@onready var _col_shape: CollisionShape2D = $CollisionShape2D
@onready var _animacion: AnimationPlayer  = $AnimationPlayer
var _forma: CircleShape2D


func _ready() -> void:
	_forma = _col_shape.shape as CircleShape2D
	_animacion.animation_finished.connect(_on_animacion_terminada)


## Misma firma que GolpeBasico.configurar() — compatible con HabilidadGolpeBasico._ejecutar().
## duracion se ignora: el tiempo de vida lo controla la animación.
func configurar(cantidad_daño: float, radio: float, fuente: Node, _duracion: float,
		tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO) -> void:
	_daño           = cantidad_daño
	_forma.radius   = radio
	_entidad_fuente = fuente
	_tipo_dano      = tipo
	set_deferred("monitorable", true)
	_animacion.play("ataque_arañazo")
	_daño_pendiente = true

## GestorPiscinas.liberar() llama esto justo antes de esconder el nodo: sin
## esto, un arañazo "en espera" en la piscina seguiría siendo un collider
## válido para las queries de otros golpes mientras está oculto.
func _al_liberar_a_piscina() -> void:
	set_deferred("monitorable", false)


func _aplicar_daño() -> void:
	Combate.golpear_area(self, _forma, _daño, _entidad_fuente, _tipo_dano, "arañazo")


func _physics_process(_delta: float) -> void:
	if _daño_pendiente:
		_daño_pendiente = false
		_aplicar_daño()


func _on_animacion_terminada(_anim_name: String) -> void:
	GestorPiscinas.liberar(self)
