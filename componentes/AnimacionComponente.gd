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
	# El servidor headless (Docker) nunca dibuja nada, pero el AnimationTree
	# evalúa su blend tree / máquina de estados cada fotograma igual si
	# active=true — por cada mob del mapa. Apagarlo ahí no pierde nada
	# observable (nadie mira ese lado): establecer_condicion()/actualizar_
	# blend() siguen fijando parámetros normalmente, y reproducir() sigue
	# funcionando porque toca animation_player directo, no depende del árbol.
	if DisplayServer.get_name() == "headless":
		animation_tree.active = false


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


## Fuerza que la máquina de estados viaje al estado indicado, sin depender
## de que el estado ACTUAL tenga una arista de salida directa gateada por
## la condición correspondiente — establecer_condicion() sola solo
## funciona si existe esa arista desde donde el mob esté PARADO en ese
## momento. Godot recorre el camino más corto por las aristas que sí
## existan (con su propio crossfade), o salta directo si no hay ninguna
## conexión. Reportado con el arquero: atacar mientras seguía en CAMINAR
## (p. ej. recién saliendo de reposicionarse) lo dejaba pegado ahí para
## siempre, porque el grafo solo tenía IDLE->ATACAR, no CAMINAR->ATACAR.
func viajar_a_estado(nombre: StringName) -> void:
	if not animation_tree:
		return
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	if playback:
		playback.travel(nombre)


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
