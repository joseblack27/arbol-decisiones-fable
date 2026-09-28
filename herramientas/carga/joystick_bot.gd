# =============================================================================
# joystick_bot.gd — cómo un bot mueve a su jugador: TOCANDO el joystick real
# del HUD, el mismo camino que un dedo.
#
# Emitir "joystick_movimiento" directo por SeñalManager ya no alcanza: el
# rectificador de Jugador (_verificar_joystick_soltado) anula cualquier
# dirección mientras el joystick real no esté presionado. Los bots que hacían
# eso quedaron quietos desde el 21 sep 2026 (las mediciones de
# prueba_carga.sh de esas fechas son con bots parados).
#
#   const JoystickBot := preload("res://herramientas/carga/joystick_bot.gd")
#   JoystickBot.mover(root, Vector2.RIGHT)   # aprieta / cambia de rumbo
#   JoystickBot.mover(root, Vector2.ZERO)    # suelta
# =============================================================================
extends RefCounted

## Distancia desde el centro del joystick a la que "apoya el dedo" (dentro del
## radio del joystick; la magnitud no importa, el movimiento se normaliza).
const _DISTANCIA_DEDO := 40.0

## El joystick cambia si Mundo se recarga (reconexión): se vuelve a buscar.
static var _joystick: Node = null


static func mover(raiz: Node, direccion: Vector2) -> void:
	var joystick := _buscar(raiz)
	if joystick == null:
		return
	var centro: Vector2 = joystick.global_position
	if direccion == Vector2.ZERO:
		if joystick.esta_presionado():
			joystick._on_touch_finalizado(0, centro)
		return
	var punto := centro + direccion.normalized() * _DISTANCIA_DEDO
	if joystick.esta_presionado():
		joystick._on_touch_movido(0, punto)
	else:
		joystick._on_touch_iniciado(0, punto)


static func _buscar(raiz: Node) -> Node:
	if is_instance_valid(_joystick) and _joystick.is_inside_tree():
		return _joystick
	_joystick = null
	for nodo in raiz.find_children("*", "", true, false):
		if nodo.has_method("esta_presionado"):
			_joystick = nodo
			break
	return _joystick
