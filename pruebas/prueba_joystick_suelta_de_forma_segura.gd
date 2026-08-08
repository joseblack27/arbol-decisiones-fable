# =============================================================================
# Prueba: el joystick de movimiento no se puede quedar "pegado" con una
# dirección tras soltar — reportado por el usuario: "presiono el joystick
# hasta arriba y lo suelto, el jugador sigue subiendo, con la animación de
# idle". Dos causas de raíz cubiertas:
#
# 1. ComponenteToque.touch_finalizado() filtraba por posicion_dentro(), que
#    para un CONTROL (p. ej. BotonDisparo) puede fallar si el dedo terminó
#    arrastrado FUERA del rect del control al soltar — el evento de soltar
#    se perdía en silencio, sin llegar nunca a quien escucha. Ahora
#    touch_finalizado() siempre emite (quien escucha ya filtra por índice
#    de touch, ver Joystick._on_touch_finalizado).
#
# 2. Si el SO intercepta el gesto (p. ej. arrastrar "hasta arriba" entra en
#    la franja donde Android interpreta la barra de notificaciones) puede
#    que nunca llegue NINGÚN evento de touch, ni siquiera cancelado —
#    Joystick._notification() ahora fuerza la suelta si la aplicación
#    pierde el foco con el joystick todavía agarrado.
#   godot --headless --path . --script res://pruebas/prueba_joystick_suelta_de_forma_segura.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _joystick
var _boton_disparo

var _toque_fuera_del_rect_ok := false
var _suelta_en_perdida_de_foco_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_joystick = (load("res://escenas/ui/joystick/joystick.tscn") as PackedScene).instantiate()
		root.add_child(_joystick)
		_joystick.global_position = Vector2(500, 500)

		# BotonDisparo es un Control con un ComponenteToque hijo — a
		# diferencia del propio Joystick (Area2D), acá posicion_dentro() SÍ
		# aplica de verdad.
		_boton_disparo = (load("res://escenas/ui/boton_disparo/BotonDisparo.tscn") as PackedScene).instantiate()
		root.add_child(_boton_disparo)
		_boton_disparo.position = Vector2(0, 0)
		_boton_disparo.size = Vector2(100, 100)
		return false
	if _fotogramas < 3:
		return false  # dar tiempo a que _ready() corra (@onready var radio).

	_probar_touch_finalizado_siempre_emite()
	_probar_suelta_en_perdida_de_foco()

	var exito := _toque_fuera_del_rect_ok and _suelta_en_perdida_de_foco_ok
	print("PRUEBA JOYSTICK SUELTA DE FORMA SEGURA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true


## Presiona BotonDisparo (adentro de su rect) y suelta AFUERA de su rect —
## antes de este fix, la suelta nunca emitía y _presionado se quedaba
## pegado en true.
func _probar_touch_finalizado_siempre_emite() -> void:
	var toque = _boton_disparo.get_node("ComponenteToque")

	toque.touch_iniciado(0, Vector2(50, 50))  # adentro del rect 100x100.
	print("Presionado tras touch_iniciado adentro (esperado true): %s" % _boton_disparo._presionado)

	toque.touch_finalizado(0, Vector2(9999, 9999))  # bien afuera del rect.
	print("Presionado tras touch_finalizado AFUERA del rect (esperado false): %s" % _boton_disparo._presionado)
	_toque_fuera_del_rect_ok = _boton_disparo._presionado == false


func _probar_suelta_en_perdida_de_foco() -> void:
	_joystick.index = 3
	_joystick.direccion = Vector2(0, -1)
	_joystick.palanca.global_position = _joystick.global_position + Vector2(0, -72)
	print("Antes de perder foco: index=%d direccion=%s" % [_joystick.index, _joystick.direccion])
	_joystick._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	print("Tras perder foco (esperado -1 y ZERO): index=%d direccion=%s" % [_joystick.index, _joystick.direccion])
	_suelta_en_perdida_de_foco_ok = _joystick.index == -1 and _joystick.direccion == Vector2.ZERO
