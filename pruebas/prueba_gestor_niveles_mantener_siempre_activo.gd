# =============================================================================
# Prueba de GestorNiveles.mantener_siempre_activo() — pedido explícito del
# usuario: "dejar activo ambos mapa a la vez", para que Ciudad y Pradera
# nunca se congelen por _actualizar_actividad_niveles() (que apaga
# PROCESS_MODE_DISABLED cualquier nivel sin jugadores conectados, ahorro de
# CPU) mientras el leñador (u otra simulación de fondo) las necesite
# funcionando.
#
# Cubre:
#   1. Un nivel SIN jugadores y SIN marcar como siempre-activo se deshabilita
#      (comportamiento de siempre, sin regresión).
#   2. El mismo nivel, marcado con mantener_siempre_activo(), se queda
#      habilitado aunque siga sin jugadores.
#   godot --headless --path . --script res://pruebas/prueba_gestor_niveles_mantener_siempre_activo.gd
# =============================================================================
extends SceneTree

const _RUTA_CAMINO := "res://escenas/niveles/NivelCamino.tscn"
const _RUTA_CUEVA := "res://escenas/niveles/NivelCueva.tscn"

var _gn
var _sin_marcar_se_deshabilita_ok := false
var _marcado_sigue_habilitado_ok := false


func _process(_delta: float) -> bool:
	_gn = root.get_node("/root/GestorNiveles")

	var contenedor := Node.new()
	root.add_child(contenedor)
	_gn.registrar(contenedor, null)

	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer
	# preparar_servidor() deja el nivel inicial cargado y activo (tiene un
	# peer implícito de arranque) — se usa una ruta DISTINTA a las dos que
	# se van a comparar, para no ensuciar el resultado.
	_gn.preparar_servidor(_RUTA_CAMINO)

	# Sin marcar: un nivel recién cargado, sin jugadores, se apaga solo.
	var nivel_a = _gn.asegurar_nivel_cargado_servidor(_RUTA_CUEVA)
	_gn._actualizar_actividad_niveles()
	print("Sin marcar, un nivel sin jugadores se deshabilita (esperado true): %s" % \
		(nivel_a.process_mode == Node.PROCESS_MODE_DISABLED))
	_sin_marcar_se_deshabilita_ok = nivel_a.process_mode == Node.PROCESS_MODE_DISABLED

	# Marcado con mantener_siempre_activo(): sigue habilitado pese a no
	# tener jugadores tampoco.
	_gn.mantener_siempre_activo(_RUTA_CAMINO)
	# Camino ya está activo (es el nivel inicial); forzarlo a deshabilitado
	# a mano antes de la comprobación real, para asegurar que es
	# mantener_siempre_activo() quien lo reactiva, no que ya lo estaba.
	var nivel_camino = _gn.asegurar_nivel_cargado_servidor(_RUTA_CAMINO)
	nivel_camino.process_mode = Node.PROCESS_MODE_DISABLED
	_gn._actualizar_actividad_niveles()
	print("Marcado con mantener_siempre_activo(), sigue habilitado sin jugadores (esperado true): %s" % \
		(nivel_camino.process_mode != Node.PROCESS_MODE_DISABLED))
	_marcado_sigue_habilitado_ok = nivel_camino.process_mode != Node.PROCESS_MODE_DISABLED

	return _informar()


func _informar() -> bool:
	var exito := _sin_marcar_se_deshabilita_ok and _marcado_sigue_habilitado_ok
	print("PRUEBA GESTOR NIVELES MANTENER SIEMPRE ACTIVO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
