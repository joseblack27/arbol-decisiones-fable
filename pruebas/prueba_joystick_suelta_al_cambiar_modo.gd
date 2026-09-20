# =============================================================================
# Regresión (bug reportado 19 sep 2026, probado en celular real): "muchas
# veces a pesar de soltar el joystick el jugador se queda moviendose en la
# ultima direccion que se movio". Causa real: ControlJuego.gd desactiva
# (PROCESS_MODE_DISABLED) TODO el subárbol del joystick apenas GestorUI
# cambia de modo (diálogo/OS/chat) -- eso apaga _input(), así que si el
# dedo seguía arrastrando el joystick justo en ese instante (típico:
# caminar hacia un NPC/cofre hasta que el auto-trigger abre su panel), el
# evento real de "soltado" nunca llega. Como ControlJuego solo REACTIVA el
# subárbol al volver a JUEGO sin soltar nada, ningún toque futuro corrige
# la dirección pegada (ver Joystick.gd, ya tenía una red de seguridad
# parecida para _notification()/focus-out, pero no para este caso).
#
# Arreglo: ControlJuego._on_modo_cambiado() llama Joystick.forzar_suelta()
# ANTES de desactivar el subárbol.
#   1. Simula un arrastre en curso (index != -1, direccion != ZERO).
#   2. Cambiar de modo (GestorUI.abrir_dialogo()) debe soltar el joystick
#      de verdad (index vuelve a -1, direccion vuelve a ZERO) Y desactivar
#      el subárbol -- no solo lo segundo.
#   godot --headless --path . --script res://pruebas/prueba_joystick_suelta_al_cambiar_modo.gd
# =============================================================================
extends SceneTree

var _f := 0
var _gestor_ui
var _control_juego
var _joystick

var _arrastre_en_curso_ok := false
var _suelta_al_cambiar_modo_ok := false
var _subarbol_desactivado_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			_simular_arrastre()
			_cambiar_de_modo_y_verificar()
			return _informar()
	return false


func _montar() -> void:
	_gestor_ui = root.get_node("/root/GestorUI")
	_gestor_ui.modo_actual = _gestor_ui.Modo.JUEGO

	_control_juego = Control.new()
	_control_juego.set_script(load("res://escenas/ui/ControlJuego.gd"))
	root.add_child(_control_juego)

	_joystick = (load("res://escenas/ui/joystick/joystick.tscn") as PackedScene).instantiate()
	_control_juego.add_child(_joystick)


func _simular_arrastre() -> void:
	_joystick._on_touch_iniciado(0, _joystick.global_position)
	_joystick._on_touch_movido(0, _joystick.global_position + Vector2(30, 0))

	_arrastre_en_curso_ok = _joystick.index == 0 and not _joystick.direccion.is_equal_approx(Vector2.ZERO)
	print("Arrastre en curso antes de cambiar de modo (esperado true): %s" % _arrastre_en_curso_ok)


func _cambiar_de_modo_y_verificar() -> void:
	_gestor_ui.abrir_dialogo()  # Mismo camino que un NPC abriendo su panel a mitad de arrastre.

	_suelta_al_cambiar_modo_ok = _joystick.index == -1 and _joystick.direccion.is_equal_approx(Vector2.ZERO)
	print("Cambiar de modo suelta el joystick de verdad (esperado true, index=%d, direccion=%s): %s" % [
		_joystick.index, _joystick.direccion, _suelta_al_cambiar_modo_ok])

	_subarbol_desactivado_ok = _control_juego.process_mode == Node.PROCESS_MODE_DISABLED
	print("El subárbol queda desactivado igual que antes (esperado true): %s" % _subarbol_desactivado_ok)


func _informar() -> bool:
	var exito := _arrastre_en_curso_ok and _suelta_al_cambiar_modo_ok and _subarbol_desactivado_ok
	print("PRUEBA JOYSTICK SUELTA AL CAMBIAR MODO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
