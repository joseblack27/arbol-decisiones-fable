class_name PieCooldown
extends Control
## Overlay de recarga tipo "pastel" para UIHabilidad.
## Es el único elemento que se sigue dibujando a mano (un arco progresivo no
## tiene nodo equivalente); vive en su propio nodo para renderizarse POR
## ENCIMA de los sprites del botón.

var radio: float = 40.0:
	set(valor):
		radio = valor
		queue_redraw()

## 0.0 = sin recarga, 1.0 = recarga completa pendiente.
var ratio: float = 0.0:
	set(valor):
		ratio = valor
		queue_redraw()


func _draw() -> void:
	if ratio <= 0.0:
		return
	var angulo_inicio := -PI / 2.0
	draw_arc(
		Vector2.ZERO, radio / 2.0,
		angulo_inicio, angulo_inicio + TAU * ratio,
		64, Color(0.0, 0.0, 0.0, 0.55), radio,
	)
