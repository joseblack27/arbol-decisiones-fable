# =============================================================================
# Validación del remitente en los RPC "any_peer" (ver Utils.pedido_del_dueño) y
# el aldeano que quedaba congelado "hablando" si quien le hablaba se
# desconectaba con el diálogo abierto.
#
# Confirma:
#   1. Utils.pedido_del_dueño() da false fuera del servidor, con un dueño sin
#      peer_id_dueño y con un dueño que no es quien manda (fuera de un RPC el
#      remitente es 0).
#   2. El aldeano en el servidor: con dos jugadores hablando se queda en
#      HABLANDO; cuando uno cierra sigue hablando con el otro; cuando el otro
#      se DESCONECTA (sin cerrar) vuelve a moverse.
#   godot --headless --path . --script res://pruebas/prueba_validacion_remitente_rpc.gd
# =============================================================================
extends SceneTree

var _f := 0
var _aldeano
var _exito := true


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_probar_pedido_del_dueno_sin_red()
		var peer := ENetMultiplayerPeer.new()
		peer.create_server(0)
		root.multiplayer.multiplayer_peer = peer
		_probar_pedido_del_dueno_en_servidor()
		_aldeano = (load("res://escenas/npc/aldeano/Aldeano.tscn") as PackedScene).instantiate()
		root.add_child(_aldeano)
		return false
	if _f == 2:
		_aldeano._marcar_hablante(5, true)
		_aldeano._marcar_hablante(6, true)
		_aldeano._marcar_hablante(5, false)
		return false
	if _f == 4:
		_verificar("Con uno cerrando y otro todavía hablando, sigue en HABLANDO",
			_aldeano._estado == _aldeano.Estado.HABLANDO)
		root.multiplayer.peer_disconnected.emit(6)
		return false
	if _f == 6:
		_verificar("Si el que quedaba se desconecta, deja de hablar",
			_aldeano._hablantes.is_empty() and _aldeano._estado != _aldeano.Estado.HABLANDO)
		print("PRUEBA VALIDACION REMITENTE RPC %s" % ("OK" if _exito else "FALLIDA"))
		quit(0 if _exito else 1)
		return true
	return false


func _probar_pedido_del_dueno_sin_red() -> void:
	var dueño := Node.new()
	dueño.set_script(_script_con_dueno())
	dueño.set("peer_id_dueño", 0)
	_verificar("Sin red nunca es un pedido válido del dueño",
		not root.get_node("/root/Utils").pedido_del_dueño(dueño))
	dueño.free()


func _probar_pedido_del_dueno_en_servidor() -> void:
	var utils = root.get_node("/root/Utils")
	var sin_dueño := Node.new()
	_verificar("Un nodo sin peer_id_dueño no tiene dueño que valide",
		not utils.pedido_del_dueño(sin_dueño))
	sin_dueño.free()
	var dueño := Node.new()
	dueño.set_script(_script_con_dueno())
	dueño.set("peer_id_dueño", 7)
	_verificar("Si el remitente no es el dueño, no vale",
		not utils.pedido_del_dueño(dueño))
	dueño.free()


func _script_con_dueno() -> GDScript:
	var s := GDScript.new()
	s.source_code = "extends Node\nvar peer_id_dueño := -1\n"
	s.reload()
	return s


func _verificar(texto: String, ok: bool) -> void:
	_exito = _exito and ok
	print("%s (esperado true): %s" % [texto, ok])
