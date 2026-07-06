class_name HUD
extends Control
## Main HUD: health bar, left movement joystick, right ability buttons.
## Listens to EventBus for state changes.

@onready var _health_bar: ProgressBar       = $TopBar/HealthBar
@onready var _health_label: Label           = $TopBar/HealthLabel
@onready var _movement_joystick: VirtualJoystick = $BottomLayer/Left/VirtualJoystick
@onready var _state_label: Label            = $TopBar/StateLabel

func _ready() -> void:
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_died.connect(_on_player_died)

func _on_player_health_changed(current: float, max_hp: float) -> void:
	_health_bar.max_value = max_hp
	_health_bar.value = current
	_health_label.text = "%d / %d" % [int(current), int(max_hp)]

func _on_player_died() -> void:
	_health_label.text = "DEAD"
