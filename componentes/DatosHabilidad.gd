extends Resource
class_name DatosHabilidad
## Recurso unificado: datos de juego + estadísticas para el panel OS.

# ── Identidad ──────────────────────────────────────────────────────────────────
@export var nombre: String = ""
@export var icono: Texture2D = null
@export_multiline var descripcion: String = ""

# ── Gameplay ───────────────────────────────────────────────────────────────────
@export var escena: PackedScene = null
@export var nivel: int = 0
@export var costo_energia: int = 0

# ── Estadísticas (panel OS) ────────────────────────────────────────────────────
@export_group("Estadísticas")
@export var dano_base_min: int = 0
@export var dano_base_max: int = 0
@export var dano_calculado_min: int = 0
@export var dano_calculado_max: int = 0
@export var tipo_lanzamiento: Enums.Skill.TypeLaunch = Enums.Skill.TypeLaunch.PROYECTIL
@export var tipo_dano: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC
@export var alcance_metros: int = 0
@export var radio_golpe: float = 0.0
@export var enfriamiento: float = 0.0
## Solo proyectiles: si está activo, estirar menos el joystick acorta el
## disparo. Apagado: el proyectil siempre viaja hasta el alcance máximo.
@export var alcance_segun_poder := false

# ── Aliases en inglés (panel OS) ───────────────────────────────────────────────
var name: String:
	get:
		return nombre
var icon: Texture2D:
	get:
		return icono
var level: int:
	get:
		return nivel
var description: String:
	get:
		return descripcion
var cost_energy: int:
	get:
		return costo_energia
var damage_base_min: int:
	get:
		return dano_base_min
var damage_base_max: int:
	get:
		return dano_base_max
var damage_calculated_min: int:
	get:
		return dano_calculado_min
var damage_calculated_max: int:
	get:
		return dano_calculado_max
var type_launch: Enums.Skill.TypeLaunch:
	get:
		return tipo_lanzamiento
var type_damage: Enums.Skill.TypeDamage:
	get:
		return tipo_dano
var range_meters: int:
	get:
		return alcance_metros
var cooldown_seconds: float:
	get:
		return enfriamiento
