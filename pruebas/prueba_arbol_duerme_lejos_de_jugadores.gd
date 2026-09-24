# =============================================================================
# Optimización de rendimiento del servidor (pedido explícito del usuario,
# 23 sep 2026): "arboles=" (el tiempo evaluando árboles de comportamiento de
# TODOS los mobs, ver ServidorDedicado._reportar_capacidad) es la línea que
# más escala con la cantidad de mobs en el log "[CARGA]" -- en un nivel
# grande (Camino, Hormiguero) la mayoría puede estar lejos de cualquier
# jugador en un momento dado, pensando en vano. ArbolComportamiento.
# radio_actividad ahora "duerme" el árbol (deja de tickear) cuando ningún
# jugador está lo bastante cerca, revisando la distancia cada
# _INTERVALO_REVISION_SUEÑO en vez de en cada fotograma.
#
# Nota sobre alcance de esta prueba: InteresEspacial.hay_jugador_cerca()
# depende de peers REALMENTE conectados por ENet (mismo criterio que el
# resto de InteresEspacial, ver el comentario de prueba_lenador_no_deja_
# fantasma.gd) -- este proyecto evita a propósito las pruebas de 2 peers
# reales por lentas/flaky (ver memoria del proyecto). Por eso el caso
# "hay un jugador cerca => despierta" se prueba a nivel de la bandera
# _dormido_por_distancia directamente (confirma que _process() respeta esa
# bandera, que es la integración real que importa acá), mientras que el
# caso "sin ningún peer conectado => duerme" SÍ se prueba de punta a punta
# con InteresEspacial real, porque eso no necesita un peer conectado para
# ser correcto.
#
# Confirma:
#   1. Sin ningún peer conectado, el árbol de un mob lejos de todo se
#      duerme solo (_revisar_sueño_por_distancia real) y dejar de tiquear
#      -- tick_actual no avanza aunque pase tiempo de sobra.
#   2. Forzando _dormido_por_distancia = false (simula "hay alguien cerca"
#      sin depender de un peer real), el árbol vuelve a tiquear.
#   3. Sin red (un solo jugador, sin multiplayer activo) el árbol NUNCA
#      duerme por distancia, sin importar qué tan lejos esté el agente --
#      protección de que esto no rompa partidas de un jugador.
#   4. "activo = false" (el mecanismo YA existente, usado por las pausas de
#      fase de los jefes) sigue cortando el tick sin importar el estado de
#      sueño -- las dos banderas no se pisan entre sí.
#   5. El default de radio_actividad es 0 (DESACTIVADO) -- ver el comentario
#      grande en ArbolComportamiento.gd: apagado a propósito (24 sep 2026)
#      para diagnosticar un reporte real de mobs fantasma en combate
#      ("si me quedo quieto en un grupo de hormigas, algunas se quedan
#      estáticas... y ya no reciben daño"), reportado empezando justo
#      después de activar esta optimización. El resto de esta prueba
#      prende radio_actividad a mano para seguir probando el MECANISMO en
#      sí, pero el comportamiento por defecto en producción hoy es "nunca
#      duerme" -- si esta prueba puntual (5) empieza a fallar, alguien
#      reactivó el default sin revisar antes esa investigación.
#   godot --headless --path . --script res://pruebas/prueba_arbol_duerme_lejos_de_jugadores.gd
# =============================================================================
extends SceneTree

const ESPERA_TICKS_MS := 500  # 5x intervalo_tick (0.1s), de sobra si está despierto.

var _mob
var _arbol
var _contenedor: Node2D
var _fase := 0
var _momento_fase_ms := 0

var _duerme_sin_peers_ok := false
var _nunca_duerme_si_detecto_jugador_ok := false
var _no_tiquea_dormido_ok := false
var _despierta_si_hay_alguien_cerca_ok := false
var _nunca_duerme_sin_red_ok := false
var _activo_false_sigue_cortando_ok := false
var _default_desactivado_ok := false
var _ticks_antes_de_despertar := 0


func _process(_delta: float) -> bool:
	match _fase:
		0:
			_montar()
			_probar_duerme_sin_peers()
			_probar_nunca_duerme_si_detecto_jugador()
			_fase = 1
			_momento_fase_ms = Time.get_ticks_msec()
		1:
			if Time.get_ticks_msec() - _momento_fase_ms >= ESPERA_TICKS_MS:
				_probar_no_tiquea_dormido()
				_probar_despierta_si_hay_alguien_cerca()
				_fase = 2
				_momento_fase_ms = Time.get_ticks_msec()
		2:
			if Time.get_ticks_msec() - _momento_fase_ms >= ESPERA_TICKS_MS:
				_probar_nunca_duerme_sin_red()
				_probar_activo_false_sigue_cortando()
				return _informar()
	return false


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)  # puerto 0 = el SO elige uno libre; no hace falta que nadie se conecte.
	root.multiplayer.multiplayer_peer = peer

	_contenedor = Node2D.new()
	_contenedor.name = "Enemigos"
	root.add_child(_contenedor)
	current_scene = _contenedor

	_mob = (load("res://escenas/enemigos/EnemigoHormigaObrera.tscn") as PackedScene).instantiate()
	_mob.global_position = Vector2(50000.0, 50000.0)  # bien lejos de cualquier cosa.
	_contenedor.add_child(_mob)

	_arbol = _mob.get_node("ArbolComportamiento")

	_default_desactivado_ok = _arbol.radio_actividad == 0.0
	print("El default de radio_actividad sigue en 0 (desactivado) (esperado true): %s" % \
		_default_desactivado_ok)

	# TEMPORALMENTE en 0 en producción (ver el comentario grande en
	# ArbolComportamiento.gd) -- esta prueba sigue probando el MECANISMO en
	# sí (para cuando se reactive), así que lo prende a mano acá.
	_arbol.radio_actividad = 1400.0


func _probar_duerme_sin_peers() -> void:
	# Sin llamar create_client/conectar nada: multiplayer.get_peers() da
	# vacío de verdad -- caso real y totalmente probable en un servidor
	# dedicado con varios niveles, alguno sin nadie todavía.
	_arbol._revisar_sueño_por_distancia()
	_duerme_sin_peers_ok = _arbol._dormido_por_distancia
	print("Sin peers conectados, el árbol se duerme solo (esperado true): %s" % _duerme_sin_peers_ok)


## Regresión (reportado en juego real, 23 sep 2026): "habían 3 [hormigas] y
## después de un tiempo solo 1 se me quedó pegando" -- un mob que YA
## detectó a un jugador (jugador_detectado, ver VisionComponente/Enemigo.
## _on_objetivo_detectado -- independiente del tick del árbol) nunca debe
## dormirse por distancia, sin importar qué diga el chequeo de distancia en
## sí. Sin peers conectados (0 jugadores "cerca" según InteresEspacial),
## pero CON jugador_detectado=true, tiene que seguir despierto igual.
func _probar_nunca_duerme_si_detecto_jugador() -> void:
	_mob.memoria.establecer("jugador_detectado", true)
	_arbol._dormido_por_distancia = true  # forzado, para confirmar que esto lo pisa a false.
	_arbol._revisar_sueño_por_distancia()
	_nunca_duerme_si_detecto_jugador_ok = not _arbol._dormido_por_distancia
	print("Con jugador_detectado=true, nunca se duerme aunque no haya peers cerca (esperado true): %s" % \
		_nunca_duerme_si_detecto_jugador_ok)
	_mob.memoria.establecer("jugador_detectado", false)  # no interferir con las fases siguientes.


func _probar_no_tiquea_dormido() -> void:
	var ticks_antes = _arbol.tick_actual
	_no_tiquea_dormido_ok = _arbol.tick_actual == ticks_antes and _arbol._dormido_por_distancia
	print("Dormido, tick_actual no avanzó tras %dms reales (esperado true, tick=%d): %s" % [
		ESPERA_TICKS_MS, _arbol.tick_actual, _no_tiquea_dormido_ok])


func _probar_despierta_si_hay_alguien_cerca() -> void:
	# Simula "hay un jugador cerca" a nivel de la bandera -- ver nota de
	# alcance en la cabecera del archivo sobre por qué no se arma un peer
	# real acá.
	_arbol._dormido_por_distancia = false
	_ticks_antes_de_despertar = _arbol.tick_actual


func _probar_nunca_duerme_sin_red() -> void:
	_despierta_si_hay_alguien_cerca_ok = _arbol.tick_actual > _ticks_antes_de_despertar
	print("Despierto (bandera forzada), tick_actual SÍ avanzó (esperado true, antes=%d ahora=%d): %s" % [
		_ticks_antes_de_despertar, _arbol.tick_actual, _despierta_si_hay_alguien_cerca_ok])

	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_arbol._dormido_por_distancia = true  # a mano, para confirmar que la revisión real lo pisa a false.
	_arbol._revisar_sueño_por_distancia()
	_nunca_duerme_sin_red_ok = not _arbol._dormido_por_distancia
	print("Sin red (un solo jugador), nunca duerme por distancia (esperado true): %s" % \
		_nunca_duerme_sin_red_ok)


func _probar_activo_false_sigue_cortando() -> void:
	_arbol._dormido_por_distancia = false  # "despierto" por distancia...
	_arbol.activo = false                  # ...pero activo=false (pausa de fase) igual corta.
	var ticks_antes = _arbol.tick_actual
	_arbol._process(0.2)  # más que intervalo_tick -- si esto tiqueara, sería un bug.
	_activo_false_sigue_cortando_ok = _arbol.tick_actual == ticks_antes
	print("activo=false sigue cortando el tick sin importar el sueño (esperado true): %s" % \
		_activo_false_sigue_cortando_ok)
	_arbol.activo = true


func _informar() -> bool:
	var exito := _duerme_sin_peers_ok and _nunca_duerme_si_detecto_jugador_ok and _no_tiquea_dormido_ok \
		and _despierta_si_hay_alguien_cerca_ok and _nunca_duerme_sin_red_ok and _activo_false_sigue_cortando_ok \
		and _default_desactivado_ok
	print("PRUEBA ARBOL DUERME LEJOS DE JUGADORES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
