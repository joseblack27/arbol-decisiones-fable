extends Resource
class_name AtaqueConfig

## ⚔️ ATAQUE CONFIG - Clase para parametrizar ataques de enemigos
## Permite configurar valores de ataques de forma reutilizable y exportable

@export var nombre: String = "Ataque"
@export var daño: float = 10.0
@export var alcance: float = 50.0
@export var cooldown: float = 1.0
@export var tiempo_animacion: float = 0.5
@export var velocidad_proyectil: float = 200.0  # Para ataques a distancia
@export var radiús_efectos: float = 30.0  # Radio de efecto (explosión, AOE)

func _init(p_nombre: String = "Ataque", p_daño: float = 10.0, p_alcance: float = 50.0, 
           p_cooldown: float = 1.0, p_tiempo_anim: float = 0.5) -> void:
	nombre = p_nombre
	daño = p_daño
	alcance = p_alcance
	cooldown = p_cooldown
	tiempo_animacion = p_tiempo_anim

func obtener_info() -> String:
	return "%s - Daño: %.1f | Alcance: %.1f | Cooldown: %.1f" % [nombre, daño, alcance, cooldown]