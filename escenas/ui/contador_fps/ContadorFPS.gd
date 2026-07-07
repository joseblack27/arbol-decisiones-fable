extends Label
class_name ContadorFPS
## Muestra los FPS actuales, actualizado cada fotograma. Puramente
## informativo — process_mode ALWAYS para que siga contando incluso con el
## juego en pausa (p. ej. con el menú OS abierto).

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	text = "%d FPS" % Engine.get_frames_per_second()
