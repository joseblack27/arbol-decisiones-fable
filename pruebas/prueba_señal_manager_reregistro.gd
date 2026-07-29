# =============================================================================
# Prueba de la regresión reportada en juego real: tras varias reconexiones
# seguidas al servidor (reload_current_scene() en Mundo._al_perder_conexion,
# que crea un Joystick/UIHabilidad totalmente nuevo con su propio signal_id),
# la consola se llenaba de "Señal 'joystick_movimiento' ya esta registrada" y
# después, en cada emisión, "Señal 'X' no coincide con la señal registrada" —
# SeñalManager.registrar() rechazaba la segunda registración (la de la
# partida NUEVA) y dejaba el id de la partida VIEJA para siempre, silenciando
# el joystick y las habilidades enteras después de cualquier reconexión.
#
# Verifica que registrar() ahora SOBRESCRIBE en vez de rechazar:
#   1. Registrar "x" con id A, luego otra vez con id B (simula la UI nueva
#      tras un reload) -> no debe rechazar, y el id vigente pasa a ser B.
#   2. emitir("x", B, ...) despacha normalmente (antes: "no coincide").
#   3. Un suscriptor conectado ANTES del segundo registrar() (la UI vieja,
#      ya liberada en la práctica) no debe seguir recibiendo nada -- el
#      segundo registrar() also limpia los suscriptores viejos.
#   godot --headless --path . --script res://pruebas/prueba_señal_manager_reregistro.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _sm
var _recibidos_viejo: Array = []
var _recibidos_nuevo: Array = []

var _segunda_registracion_no_rechaza := false
var _emitir_con_id_nuevo_despacha := false
var _suscriptor_viejo_no_recibe_tras_reregistro := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
	if _fotogramas == 3:
		_reregistrar_y_emitir()
	if _fotogramas == 5:
		return _informar()
	return false


func _montar() -> void:
	_sm = root.get_node("/root/SeñalManager")
	_sm.registrar("x", "A", {"valor": TYPE_INT})
	_sm.conectar("x", self, "_on_recibido_viejo")
	_sm.emitir("x", "A", [1])  # el suscriptor viejo SÍ debe recibir esto.


func _on_recibido_viejo(valor: int) -> void:
	_recibidos_viejo.append(valor)


func _on_recibido_nuevo(valor: int) -> void:
	_recibidos_nuevo.append(valor)


func _reregistrar_y_emitir() -> void:
	# Simula la UI de una reconexión: mismo nombre de señal, id NUEVO (un
	# Joystick/UIHabilidad recién creado tras reload_current_scene()).
	_sm.registrar("x", "B", {"valor": TYPE_INT})
	_segunda_registracion_no_rechaza = _sm.registros["x"]["id"] == "B"

	_sm.conectar("x", self, "_on_recibido_nuevo")
	_sm.emitir("x", "B", [2])
	_emitir_con_id_nuevo_despacha = _recibidos_nuevo.has(2)
	_suscriptor_viejo_no_recibe_tras_reregistro = not _recibidos_viejo.has(2)


func _informar() -> bool:
	print("Segunda registración no rechaza, id vigente pasa a ser el nuevo (esperado true): %s" % _segunda_registracion_no_rechaza)
	print("emitir() con el id nuevo despacha normalmente (esperado true): %s" % _emitir_con_id_nuevo_despacha)
	print("El suscriptor viejo no sigue recibiendo tras el re-registro (esperado true): %s" % _suscriptor_viejo_no_recibe_tras_reregistro)
	var exito := _segunda_registracion_no_rechaza and _emitir_con_id_nuevo_despacha \
		and _suscriptor_viejo_no_recibe_tras_reregistro
	print("PRUEBA SEÑAL MANAGER REREGISTRO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
