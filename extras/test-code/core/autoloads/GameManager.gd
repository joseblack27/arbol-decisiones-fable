extends Node
## Global game state manager.
## Tracks the player reference, pause state, and game-wide settings.

var player: CharacterBody2D = null
var is_paused: bool = false

func _ready() -> void:
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)

## Called by the Player entity on _ready so other systems can find it.
func register_player(p: CharacterBody2D) -> void:
	player = p

func get_player() -> CharacterBody2D:
	return player

func _on_game_paused() -> void:
	is_paused = true
	get_tree().paused = true

func _on_game_resumed() -> void:
	is_paused = false
	get_tree().paused = false
