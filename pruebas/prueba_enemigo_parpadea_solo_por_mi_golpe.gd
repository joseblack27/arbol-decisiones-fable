# =============================================================================
# Prueba de Enemigo.parpadear()/_es_mi_propio_golpe() (pedido del usuario:
# el parpadeo de "recibí daño" debe ser local a quien de verdad pegó, sin
# confundirse con golpes de otros jugadores — y un solo parpadeo, no 3).
#
# Simula "estar en red" con un ENetMultiplayerPeer real creado como
# servidor (create_server), SIN conectar ningún cliente de verdad — alcanza
# para que Utils.en_red() dé true y multiplayer.get_unique_id() sea
# determinístico (1), sin la fragilidad de levantar 2 procesos reales.
#   godot --path . --script res://pruebas/prueba_enemigo_parpadea_solo_por_mi_golpe.gd
# =============================================================================
extends SceneTree

var _enemigo
var _fotogramas := 0

var _sin_red_cualquiera_es_propio := false
var _en_red_mi_jugador_es_propio := false
var _en_red_otro_jugador_no_es_propio := false
var _un_solo_parpadeo_ok := false


static func _script_jugador_falso() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends Node
var peer_id_dueño: int = -1
"""
	guion.reload()
	return guion


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_probar_sin_red()
		3:
			_probar_en_red()
		4:
			_probar_un_solo_parpadeo_arranca()
		30:
			# duracion=0.1 -> el tween completo (ida y vuelta) dura 0.2s = 12
			# fotogramas; a los 30 ya debería haber terminado solo (si hiciera
			# 3 parpadeos, seguiría en rojo/a mitad de ciclo acá).
			_un_solo_parpadeo_ok = _enemigo.sprite.modulate.is_equal_approx(Color.WHITE)
			return _informar()
	return false


func _montar() -> void:
	var escena := load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene
	_enemigo = escena.instantiate()
	root.add_child(_enemigo)


func _probar_sin_red() -> void:
	var jugador_falso := Node.new()
	jugador_falso.set_script(_script_jugador_falso())
	jugador_falso.peer_id_dueño = 12345
	root.add_child(jugador_falso)
	_sin_red_cualquiera_es_propio = _enemigo._es_mi_propio_golpe(jugador_falso)
	jugador_falso.queue_free()


func _probar_en_red() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)  # puerto 0 = el SO elige uno libre; no hace falta que nadie se conecte.
	root.multiplayer.multiplayer_peer = peer

	var mi_id := root.multiplayer.get_unique_id()

	var jugador_propio := Node.new()
	jugador_propio.set_script(_script_jugador_falso())
	jugador_propio.peer_id_dueño = mi_id
	root.add_child(jugador_propio)

	var jugador_ajeno := Node.new()
	jugador_ajeno.set_script(_script_jugador_falso())
	jugador_ajeno.peer_id_dueño = mi_id + 999
	root.add_child(jugador_ajeno)

	_en_red_mi_jugador_es_propio = _enemigo._es_mi_propio_golpe(jugador_propio)
	_en_red_otro_jugador_no_es_propio = not _enemigo._es_mi_propio_golpe(jugador_ajeno)

	jugador_propio.queue_free()
	jugador_ajeno.queue_free()
	# Restaurar a un OfflineMultiplayerPeer nuevo (el default real de Godot),
	# NO a null: con null, Utils.en_red() (que solo mira "es Offline o no")
	# da true igual, pero sin peer de verdad — cualquier otro componente de
	# este mismo enemigo (EnergiaComponente, VidaComponente,
	# ArbolComportamiento...) que consulte multiplayer.get_unique_id() en su
	# propio _process() revienta ("No multiplayer peer is assigned").
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _probar_un_solo_parpadeo_arranca() -> void:
	_enemigo.parpadear(0.1)


func _informar() -> bool:
	print("Sin red, cualquier fuente es 'propia': %s" % _sin_red_cualquiera_es_propio)
	print("En red, mi propio jugador SÍ es 'propio': %s" % _en_red_mi_jugador_es_propio)
	print("En red, otro jugador NO es 'propio': %s" % _en_red_otro_jugador_no_es_propio)
	print("Un solo parpadeo (ya volvió a blanco sin más ciclos): %s" % _un_solo_parpadeo_ok)

	var exito := _sin_red_cualquiera_es_propio and _en_red_mi_jugador_es_propio \
		and _en_red_otro_jugador_no_es_propio and _un_solo_parpadeo_ok
	print("PRUEBA ENEMIGO PARPADEA SOLO POR MI GOLPE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
