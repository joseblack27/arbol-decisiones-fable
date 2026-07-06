extends Area2D
class_name AtaqueArañazo

# =============================================================================
# AtaqueArañazo  (hijo de Habilidades Marker2D)
#
# Su posición y rotación las maneja el Marker2D padre.
# Este nodo solo gestiona: cuándo está activo el hitbox y la animación.
#
# Para agregar otra habilidad al enemigo, simplemente añade otro nodo
# hermano de este dentro del Marker2D "Habilidades".
# =============================================================================

@onready var animacion: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D

## Emitida al detectar contacto con un cuerpo durante el hitbox activo.
## El Enemigo escucha esta señal para aplicar daño.
signal golpe_conectado(cuerpo: Node2D, golpe: float)
## Emitida al terminar el ataque completo.
signal ataque_completado()

@export var daño: float = 10.0
@export var tipo_dano: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC

var _activo: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entrada)


# =============================================================================
# API PÚBLICA
# =============================================================================

## Compatibilidad con SelectorHabilidades (ruta_nodo).
## Llamado automáticamente por el BT cuando esta habilidad es seleccionada.
func activar(_direccion: Vector2 = Vector2.ZERO, _poder: float = 1.0) -> void:
	lanzar()


## Ejecuta el ataque. Retorna false si ya hay un ataque en curso.
## La dirección la maneja el Marker2D padre — aquí no hace falta.
func lanzar() -> bool:
	if _activo:
		return false

	sprite_2d.global_rotation = 0.0
	_activo = true
	animacion.play("ataque_arañazo")
	await animacion.animation_finished

	_activo = false
	ataque_completado.emit()
	return true


# =============================================================================
# DETECCIÓN
# =============================================================================

func _on_area_entrada(area: Area2D) -> void:
	if not _activo:
		return
	golpe_conectado.emit(area, daño)
