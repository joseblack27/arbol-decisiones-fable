extends Node
class_name AnimacionComponente

# =============================================================================
# AnimacionComponente.gd
# Componente puro de aplicación — sin lógica propia.
# No decide cuándo animar ni qué valores usar.
# Solo expone métodos para que el propietario (Enemigo, Jugador, etc.)
# aplique los valores que considere correctos.
#
# El propietario es responsable de:
#   - Llamar actualizar_blend() con la dirección actual.
#   - Llamar establecer_condicion() para cambiar estados del AnimationTree.
#   - Llamar reproducir() para animaciones puntuales (daño, muerte).
# =============================================================================

@export var animation_player: AnimationPlayer
@export var animation_tree: AnimationTree

@export_group("Parámetros AnimationTree")
## Blend positions adicionales actualizados con la dirección.
## Añade el path de cada BlendSpace2D de ataque o estado especial.
@export var params_blend_adicionales: Array[String] = []

var _en_override: bool = false

signal animacion_terminada(nombre: String)


func _ready() -> void:
	if not animation_player or not animation_tree:
		push_warning("AnimacionComponente: Faltan referencias.")
		return
	animation_player.animation_finished.connect(_on_animation_finished)


# =============================================================================
# BLEND POSITIONS
# =============================================================================

## Actualiza todos los blend positions registrados con la dirección dada.
## No toca condiciones — solo orienta los BlendSpace2D.
func actualizar_blend(direccion: Vector2) -> void:
	if not animation_tree or _en_override or direccion == Vector2.ZERO:
		return
	for param in params_blend_adicionales:
		animation_tree.set(param, direccion)


# =============================================================================
# CONDICIONES
# =============================================================================

## Activa o desactiva una condición del AnimationTree.
func establecer_condicion(param: String, valor: bool) -> void:
	if not animation_tree:
		return
	animation_tree.set(param, valor)


# =============================================================================
# OVERRIDE — animaciones puntuales (daño, muerte, reacción)
# =============================================================================

## Desactiva el AnimationTree y reproduce la animación directamente.
## Al terminar, el AnimationTree se reactiva solo.
func reproducir(nombre: String) -> void:
	if not animation_player or not animation_tree:
		return
	animation_tree.active = false
	_en_override = true
	animation_player.stop()
	animation_player.play(nombre)


## Cancela el override sin esperar a que termine la animación.
func cancelar_override() -> void:
	if not _en_override:
		return
	_en_override = false
	animation_tree.active = true


func esta_en_override() -> bool:
	return _en_override


# =============================================================================
# CALLBACKS
# =============================================================================

func _on_animation_finished(nombre: String) -> void:
	if _en_override:
		_en_override = false
		animation_tree.active = true
	animacion_terminada.emit(nombre)
