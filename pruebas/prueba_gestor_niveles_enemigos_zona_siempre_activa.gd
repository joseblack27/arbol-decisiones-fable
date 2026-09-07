# =============================================================================
# Prueba de la optimización de rendimiento en producción: un nivel "siempre
# activo" (Pradera/Ciudad/Mina, por los NPCs errantes — ver
# mantener_siempre_activo()) ya no mantiene a TODOS sus mobs hostiles
# pensando cuando no hay jugadores. Diagnosticado en la VM real (2 vCPU/1GB):
# ~200ms de física por fotograma con 0 jugadores conectados, contra un
# presupuesto de ~16ms — el costo eran los mobs de las 3 zonas siempre
# activas simulando IA/física sin que nadie los viera.
#
# Cubre:
#   1. Nivel marcado siempre-activo, SIN jugadores: el nivel en sí sigue
#      habilitado (terreno/navegación/portales, que el leñador/cazador/
#      minero necesitan), pero su contenedor "Enemigos" se apaga aparte.
#   2. Con un jugador en ese nivel: "Enemigos" se reactiva.
#   3. Al irse ese jugador: "Enemigos" se vuelve a apagar (el nivel sigue
#      activo, sigue siendo siempre-activo).
#   godot --headless --path . --script res://pruebas/prueba_gestor_niveles_enemigos_zona_siempre_activa.gd
# =============================================================================
extends SceneTree

const _RUTA_CAMINO := "res://escenas/niveles/NivelCamino.tscn"
const _RUTA_CUEVA := "res://escenas/niveles/NivelCueva.tscn"
const _PEER_FALSO := 42

var _gn
var _nivel_activo_ok := false
var _enemigos_apagados_sin_jugadores_ok := false
var _enemigos_reactivan_con_jugador_ok := false
var _enemigos_se_reapagan_al_irse_ok := false


func _process(_delta: float) -> bool:
	_gn = root.get_node("/root/GestorNiveles")

	var contenedor := Node.new()
	root.add_child(contenedor)
	_gn.registrar(contenedor, null)

	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer
	_gn.preparar_servidor(_RUTA_CAMINO)

	var nivel_cueva = _gn.asegurar_nivel_cargado_servidor(_RUTA_CUEVA)
	var enemigos = nivel_cueva.contenedor_enemigos()
	_gn.mantener_siempre_activo(_RUTA_CUEVA)

	# Sin jugadores: el nivel sigue activo, "Enemigos" se apaga aparte.
	_gn._actualizar_actividad_niveles()
	_nivel_activo_ok = nivel_cueva.process_mode != Node.PROCESS_MODE_DISABLED
	_enemigos_apagados_sin_jugadores_ok = enemigos.process_mode == Node.PROCESS_MODE_DISABLED
	print("Nivel siempre-activo sigue habilitado sin jugadores (esperado true): %s" % _nivel_activo_ok)
	print("'Enemigos' se apaga aparte cuando no hay jugadores (esperado true): %s" % \
		_enemigos_apagados_sin_jugadores_ok)

	# Llega un jugador a ese nivel: "Enemigos" se reactiva.
	_gn._nivel_por_peer[_PEER_FALSO] = _RUTA_CUEVA
	_gn._actualizar_actividad_niveles()
	_enemigos_reactivan_con_jugador_ok = enemigos.process_mode != Node.PROCESS_MODE_DISABLED
	print("'Enemigos' se reactiva con un jugador en el nivel (esperado true): %s" % \
		_enemigos_reactivan_con_jugador_ok)

	# Se va: "Enemigos" se vuelve a apagar, el nivel sigue activo (siempre-activo).
	_gn._nivel_por_peer.erase(_PEER_FALSO)
	_gn._actualizar_actividad_niveles()
	_enemigos_se_reapagan_al_irse_ok = enemigos.process_mode == Node.PROCESS_MODE_DISABLED \
		and nivel_cueva.process_mode != Node.PROCESS_MODE_DISABLED
	print("'Enemigos' se reapaga al irse el jugador, el nivel sigue activo (esperado true): %s" % \
		_enemigos_se_reapagan_al_irse_ok)

	return _informar()


func _informar() -> bool:
	var exito := _nivel_activo_ok and _enemigos_apagados_sin_jugadores_ok \
		and _enemigos_reactivan_con_jugador_ok and _enemigos_se_reapagan_al_irse_ok
	print("PRUEBA GESTOR NIVELES ENEMIGOS ZONA SIEMPRE ACTIVA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
