class_name Arañazo
extends Area2D
## Hitbox + visual efímero del ataque Arañazo.
## Se obtiene de HabilidadArañazo._ejecutar() vía GestorPiscinas (reutilizado
## entre golpes en vez de crearse/destruirse cada vez), aplica daño al
## aparecer y vuelve a la piscina al terminar la animación.

var _daño: float = 15.0
var _entidad_fuente: Node = null
var _tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO

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
	call_deferred("_aplicar_daño")

## GestorPiscinas.liberar() llama esto justo antes de esconder el nodo: sin
## esto, un arañazo "en espera" en la piscina seguiría siendo un collider
## válido para las queries de otros golpes mientras está oculto.
func _al_liberar_a_piscina() -> void:
	set_deferred("monitorable", false)


func _aplicar_daño() -> void:
	Combate.golpear_area(self, _forma, _daño, _entidad_fuente, _tipo_dano, "arañazo")


func _on_animacion_terminada(_anim_name: String) -> void:
	GestorPiscinas.liberar(self)
