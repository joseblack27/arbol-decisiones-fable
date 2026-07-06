# SkillData.gd
extends Resource
class_name SkillData

@export var name: String
@export var icon: Texture2D
@export var level: int = 0

@export_multiline var description: String

@export var cost_energy: int
@export var damage_base_min: int
@export var damage_base_max: int
@export var damage_calculated_min: int
@export var damage_calculated_max: int

@export var type_launch: Enums.Skill.TypeLaunch
@export var range_meters: int
@export var cooldown_seconds: float
