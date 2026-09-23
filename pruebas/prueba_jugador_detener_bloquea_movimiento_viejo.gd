# =============================================================================
# Regresión (pedido explícito del usuario, sigue el bug del joystick con
# lag, 23 sep 2026 -- "el punto 2 sigue"): _verificar_joystick_soltado()
# ya corrige la copia LOCAL y manda _pedir_detener_red() (reliable) al
# soltar -- pero _pedir_mover_red() es unreliable_ordered A PROPÓSITO
# (estado continuo), y eso solo garantiza orden DENTRO de ese mismo canal,
# nunca contra el canal reliable de _pedir_detener_red (mismo problema ya
# documentado en el comentario de _pedir_detener_red, para el caso de una
# ráfaga/disparo). Un paquete VIEJO de "seguí moviéndome" -- mandado ANTES
# de soltar, pero rezagado por lag -- puede llegar DESPUÉS del aviso
# confiable de "parate", pisándolo -- y como el cliente ya se dio por
# corregido (no reintenta), el cuerpo autoritativo queda moviéndose solo
# para siempre. _bloqueo_movimiento_tras_detener cierra esa ventana.
#
# Confirma (todo SERVIDOR, RPCs llamados directo -- mismo criterio que
# otras pruebas de red de este proyecto, ver prueba_almacen_minero_
# compartido.gd):
#   1. _pedir_detener_red() detiene de verdad.
#   2. Un _pedir_mover_red() con dirección NO cero DENTRO de la ventana
#      posterior (el paquete viejo rezagado) se ignora -- sigue en CERO.
#   3. Un _pedir_mover_red() con dirección CERO sigue funcionando siempre,
#      incluso dentro de esa ventana (nunca bloquea "parar").
#   4. Pasada la ventana (tiempo REAL, no fotogramas -- ver el mismo
#      criterio en prueba_huevo_hormiga_lanzamiento_visual.gd), el
#      movimiento normal vuelve a funcionar.
#   godot --headless --path . --script res://pruebas/prueba_jugador_detener_bloquea_movimiento_viejo.gd
# =============================================================================
extends SceneTree

const MARGEN_ESPERA_VENTANA_MS := 900  # 3x _VENTANA_BLOQUEO_MOVIMIENTO_TRAS_DETENER (0.3s), de sobra.

var _jugador
var _momento_inicio_ms := 0
var _verificado := false

var _detener_funciona_ok := false
var _paquete_viejo_se_ignora_ok := false
var _parar_siempre_funciona_ok := false
var _movimiento_normal_vuelve_ok := false


func _process(_delta: float) -> bool:
	if _momento_inicio_ms == 0:
		_montar()
		_probar_detener_y_paquete_viejo()
		_momento_inicio_ms = Time.get_ticks_msec()
		return false
	if _verificado:
		return false
	if Time.get_ticks_msec() - _momento_inicio_ms >= MARGEN_ESPERA_VENTANA_MS:
		_verificado = true
		_probar_movimiento_normal_vuelve()
		return _informar()
	return false


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)  # puerto 0 = el SO elige uno libre; no hace falta que nadie se conecte.
	root.multiplayer.multiplayer_peer = peer

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador.name = "0"  # get_remote_sender_id() da 0 sin transporte real.
	_jugador.peer_id_dueño = 0
	root.add_child(_jugador)


func _probar_detener_y_paquete_viejo() -> void:
	_jugador._pedir_mover_red(Vector2.RIGHT)
	_jugador._pedir_detener_red()
	_detener_funciona_ok = _jugador.direccion == Vector2.ZERO
	print("_pedir_detener_red() detiene de verdad (esperado true): %s" % _detener_funciona_ok)

	# El paquete "viejo" -- se llama DESPUÉS acá, simulando que llegó tarde
	# por la red aunque se haya originado antes de soltar.
	_jugador._pedir_mover_red(Vector2.RIGHT)
	_paquete_viejo_se_ignora_ok = _jugador.direccion == Vector2.ZERO
	print("Un paquete viejo de movimiento DESPUÉS de detener se ignora (esperado true): %s" % \
		_paquete_viejo_se_ignora_ok)

	_jugador._pedir_mover_red(Vector2.ZERO)
	_parar_siempre_funciona_ok = _jugador.direccion == Vector2.ZERO
	print("Parar (dirección cero) sigue funcionando dentro de la ventana (esperado true): %s" % \
		_parar_siempre_funciona_ok)


func _probar_movimiento_normal_vuelve() -> void:
	_jugador._pedir_mover_red(Vector2.RIGHT)
	_movimiento_normal_vuelve_ok = _jugador.direccion == Vector2.RIGHT
	print("Pasada la ventana, el movimiento normal vuelve a funcionar (esperado true): %s" % \
		_movimiento_normal_vuelve_ok)


func _informar() -> bool:
	var exito := _detener_funciona_ok and _paquete_viejo_se_ignora_ok \
		and _parar_siempre_funciona_ok and _movimiento_normal_vuelve_ok
	print("PRUEBA JUGADOR DETENER BLOQUEA MOVIMIENTO VIEJO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
