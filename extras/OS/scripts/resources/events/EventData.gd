extends Resource
class_name EventData

@export var id: String

@export var event_type: Enums.Event.Type
@export var status: Enums.Event.Status

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
