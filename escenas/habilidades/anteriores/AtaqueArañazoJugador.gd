extends Area2D
class_name AtaqueArañazoJugador

# =============================================================================
# AtaqueArañazoJugador
#
# Hitbox de ataque cuerpo a cuerpo del jugador.
# Se activa durante `duracion_hitbox` segundos al llamar lanzar().
# Detecta CharacterBody2D enemigos vía body_entered y emite golpe_conectado
# para que Jugador.gd aplique el daño.
#
# ESTRUCTURA EN ESCENA:
#   Habilidades (Marker2D)            ← rota hacia la dirección de movimiento
#   └─ AtaqueArañazoJugador (Area2D)  ← este nodo, offset en X para el alcance
#       └─ CollisionShape2D
# =============================================================================

@export_group("Configuración")
## Daño que se aplica al enemigo por golpe.
@export var daño: float = 15.0
## Segundos que el hitbox permanece activo por ataque.
@export var duracion_hitbox: float = 0.15
## Tiempo mínimo entre ataques (cooldown simple).
@export var cooldown: float = 0.4

@onready var forma: CollisionShape2D = $CollisionShape2D

## Emitida al detectar un cuerpo golpeable durante el hitbox activo.
signal golpe_conectado(cuerpo: Node2D, golpe: float)
## Emitida cuando el hitbox se desactiva y el ataque termina.
signal ataque_completado()

var _activo: bool = false
var _en_cooldown: bool = false


func _ready() -> void:
	forma.disabled = true
	body_entered.connect(_on_cuerpo_entrada)


# =============================================================================
# API PÚBLICA
# =============================================================================

## Lanza el ataque. Retorna false si ya hay uno en curso o está en cooldown.
func lanzar() -> bool:
	if _activo or _en_cooldown:
		return false

	_activo = true
	forma.disabled = false

	await get_tree().create_timer(duracion_hitbox).timeout

	forma.disabled = true
	_activo = false
	ataque_completado.emit()

	# Cooldown: bloquea nuevos ataques hasta que pase el tiempo configurado.
	_en_cooldown = true
	await get_tree().create_timer(cooldown - duracion_hitbox).timeout
	_en_cooldown = false

	return true


# =============================================================================
# DETECCIÓN
# =============================================================================

func _on_cuerpo_entrada(cuerpo: Node2D) -> void:
	if not _activo:
		return
	# Solo golpea cuerpos que expongan quitar_vida() — es decir, enemigos.
	if cuerpo.has_method("quitar_vida"):
		golpe_conectado.emit(cuerpo, daño)
