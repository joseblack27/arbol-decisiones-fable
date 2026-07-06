extends Resource
class_name DatosEvento

@export var id: String

# 0=WORLD_BOSS,1=DUNGEON,2=INVASION,3=WORLD_CHANGE,4=FACTION
@export var event_type: int = 0
# 0=UPCOMING,1=ACTIVE,2=COMPLETED,3=FAILED,4=CANCELLED
@export var status: int = 0

@export var title: String
@export var subtitle: String
@export_multiline var description: String

@export var start_time: int
@export var end_time: int

@export var priority: int = 0

@export var icon: Texture2D
@export var location_id: String
@export var location_name: String

@export var is_persistent: bool = false
@export var is_global: bool = true
@export var is_repeatable: bool = false
@export var is_visible: bool = true
