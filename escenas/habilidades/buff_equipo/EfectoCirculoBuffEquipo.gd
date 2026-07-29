class_name EfectoCirculoBuffEquipo
extends Node2D
## Círculo verde que muestra el área real que alcanzó el Grito de Guerra
## (ver HabilidadBuffEquipo) — puramente visual, sin colisión: el efecto
## de juego (el bono de daño) ya se aplicó directo en la habilidad, esto
## solo lo hace VISIBLE un instante para saber hasta dónde llegó. Mismo
## criterio de "dibujar el área real" que ya usan GolpeBasico/AreaEfecto
## para sus propios golpes, pero sin Area2D/CollisionShape2D: acá no hay
## nada que detectar, solo mostrar.

@export var duracion: float = 0.4

var _radio: float = 100.0
var _timer: float = 0.0
var _activo: bool = false


func configurar(radio: float) -> void:
	_radio = radio
	_timer = 0.0
	_activo = true
	queue_redraw()


## GestorPiscinas.liberar() llama esto justo antes de esconder el nodo —
## sin esto, un efecto "en espera" en la piscina seguiría corriendo su
## propio timer y se liberaría a sí mismo de nuevo (inofensivo, pero de
## más) apenas volviera a exponerse.
func _al_liberar_a_piscina() -> void:
	_activo = false


func _process(delta: float) -> void:
	if not _activo:
		return
	_timer += delta
	if _timer >= duracion:
		GestorPiscinas.liberar(self)


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radio, Color(0.2, 0.9, 0.3, 0.25))
	draw_arc(Vector2.ZERO, _radio, 0.0, TAU, 48, Color(0.2, 0.9, 0.3, 0.9), 2.0)
