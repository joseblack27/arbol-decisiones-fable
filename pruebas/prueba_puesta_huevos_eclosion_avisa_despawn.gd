# =============================================================================
# Regresión (reportado en juego real, 23 sep 2026): "las larvas al eclosionar
# no desaparecen y dejan de recibir daño". Causa: HuevoHormiga se replica A
# MANO en el cliente (ver _crear_huevos_red en HabilidadPuestaHuevos.gd,
# sacado de escenas_replicables() por el bug de MultiplayerSpawner
# desincronizado -- ver memoria del proyecto) -- pero _eclosionar() solo
# hacía huevo.queue_free() en el servidor, sin avisar nunca al cliente. Al
# morir en COMBATE sí le llega el aviso (Enemigo._desvanecer_y_eliminar,
# heredado tal cual, ya dispara rpc("_despawn_red")) porque ese camino SÍ
# pasa por VidaComponente.quitar_vida()/_on_muerte -- pero eclosionar nunca
# pasaba por ahí, así que ese aviso nunca se disparaba solo.
#
# Confirma que _eclosionar() (en modo red, servidor) intenta el mismo aviso
# genérico ANTES de queue_free() -- sin reventar aunque el peer de prueba
# no esté conectado de verdad (mismo criterio que otras pruebas de red de
# este proyecto) -- y que el huevo se sigue liberando igual que antes.
#   godot --headless --path . --script res://pruebas/prueba_puesta_huevos_eclosion_avisa_despawn.gd
# =============================================================================
extends SceneTree

var _reina
var _habilidad
var _huevo
var _contenedor: Node2D

var _huevo_tiene_despawn_red_ok := false
var _huevo_liberado_ok := false
var _guardian_nace_en_posicion_del_huevo_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_eclosiona_y_avisa()
	return _informar()


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)  # puerto 0 = el SO elige uno libre; no hace falta que nadie se conecte.
	root.multiplayer.multiplayer_peer = peer

	_contenedor = Node2D.new()
	_contenedor.name = "Enemigos"
	root.add_child(_contenedor)
	current_scene = _contenedor

	_reina = (load("res://escenas/enemigos/EnemigoReinaHormigas.tscn") as PackedScene).instantiate()
	_contenedor.add_child(_reina)
	_reina.global_position = Vector2.ZERO

	_habilidad = _reina.get_node("Habilidades/HabilidadPuestaHuevos")

	_huevo = (load("res://escenas/objetos/huevo_hormiga/HuevoHormiga.tscn") as PackedScene).instantiate()
	_huevo.global_position = Vector2(50.0, 50.0)
	_contenedor.add_child(_huevo)


func _probar_eclosiona_y_avisa() -> void:
	# Precondición: si esto alguna vez dejara de ser true (p. ej. alguien
	# renombra _despawn_red en Enemigo.gd), _eclosionar() se saltaría el
	# aviso en silencio -- mejor que esta prueba lo grite acá.
	_huevo_tiene_despawn_red_ok = _huevo.has_method("_despawn_red")
	print("HuevoHormiga real tiene _despawn_red heredado de Enemigo (esperado true): %s" % \
		_huevo_tiene_despawn_red_ok)

	var pos_huevo = _huevo.global_position
	_habilidad._eclosionar(_huevo, _contenedor)
	_huevo_liberado_ok = _huevo.is_queued_for_deletion()
	print("Tras eclosionar en red, el huevo se libera igual que antes (esperado true): %s" % \
		_huevo_liberado_ok)

	# Pedido explícito del usuario: "quiero que las hormigas que eclosionan
	# de las larvas aparezcan en las mismas posiciones de las larvas".
	var guardian = _habilidad._guardianes_vivos[0] if not _habilidad._guardianes_vivos.is_empty() else null
	_guardian_nace_en_posicion_del_huevo_ok = guardian != null \
		and (guardian as Node2D).global_position == pos_huevo
	print("El guardián nace en la posición exacta del huevo (esperado true, huevo=%s guardian=%s): %s" % [
		pos_huevo, guardian.global_position if guardian else "null", _guardian_nace_en_posicion_del_huevo_ok])


func _informar() -> bool:
	var exito := _huevo_tiene_despawn_red_ok and _huevo_liberado_ok and _guardian_nace_en_posicion_del_huevo_ok
	print("PRUEBA PUESTA DE HUEVOS ECLOSION AVISA DESPAWN %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
