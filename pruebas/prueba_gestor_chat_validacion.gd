# =============================================================================
# GestorChat — Feature B del plan MMO (chat global). Sin transporte de red
# real (mismo criterio que prueba_tienda_comprar_item.gd): con un
# ENetMultiplayerPeer de servidor pero sin nadie conectado,
# multiplayer.get_remote_sender_id() devuelve 0 al llamar _pedir_enviar_
# mensaje_red() DIRECTO — por eso el Jugador de prueba se nombra "0", así
# InteresEspacial.jugador_de_peer(0) lo resuelve como "el dueño real".
#
# Verifica:
#   1. El texto se recorta (strip_edges) y el nombre lo resuelve el SERVIDOR
#      desde el propio Jugador (nombre_visible) — _pedir_enviar_mensaje_red
#      ni siquiera recibe un nombre como parámetro, estructuralmente no se
#      puede suplantar.
#   2. Mensajes vacíos/solo espacios se descartan.
#   3. El cooldown por jugador frena un segundo envío inmediato, y se libera
#      pasado COOLDOWN_ENVIO_SEGUNDOS.
#   4. _validar_y_difundir recorta a LARGO_MAXIMO_MENSAJE caracteres.
#   5. El historial nunca crece más allá de HISTORIAL_MAXIMO (descarta los
#      más viejos primero).
#   godot --headless --path . --script res://pruebas/prueba_gestor_chat_validacion.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _gestor_chat
var _jugador
var _tamano_tras_primer_envio := 0

var _nombre_resuelto_del_servidor_ok := false
var _texto_recortado_ok := false
var _vacio_descartado_ok := false
var _cooldown_frena_envio_inmediato_ok := false
var _cooldown_libera_pasado_el_tiempo_ok := false
var _largo_maximo_ok := false
var _historial_limitado_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		_probar_envio_y_cooldown_inmediato()
		return false
	# COOLDOWN_ENVIO_SEGUNDOS=0.5 a ~60 físicas/seg: de sobra con 40 fotogramas.
	if _fotogramas == 40:
		_probar_cooldown_liberado()
		_probar_largo_maximo_y_vacio()
		_probar_historial_limitado()
		return _informar()
	return false


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer

	_gestor_chat = root.get_node("/root/GestorChat")

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador.name = "0"  # ver cabecera: get_remote_sender_id() da 0 sin transporte real.
	root.add_child(_jugador)
	_jugador.nombre_visible = "Fulano"


func _probar_envio_y_cooldown_inmediato() -> void:
	_gestor_chat._pedir_enviar_mensaje_red("  Hola mundo  ")
	_tamano_tras_primer_envio = _gestor_chat.historial.size()
	var ultimo: Dictionary = _gestor_chat.historial[_gestor_chat.historial.size() - 1]
	_nombre_resuelto_del_servidor_ok = ultimo.get("nombre", "") == "Fulano"
	_texto_recortado_ok = ultimo.get("texto", "") == "Hola mundo"
	print("Nombre resuelto del lado servidor (esperado 'Fulano'): %s" % ultimo.get("nombre", ""))
	print("Texto recortado (esperado 'Hola mundo'): '%s'" % ultimo.get("texto", ""))

	# Segundo envío en el MISMO fotograma: el cooldown debe frenarlo.
	_gestor_chat._pedir_enviar_mensaje_red("Otro mensaje")
	_cooldown_frena_envio_inmediato_ok = _gestor_chat.historial.size() == _tamano_tras_primer_envio
	print("El cooldown frena un segundo envío inmediato (esperado true): %s" % _cooldown_frena_envio_inmediato_ok)


func _probar_cooldown_liberado() -> void:
	_gestor_chat._pedir_enviar_mensaje_red("Tercer mensaje")
	_cooldown_libera_pasado_el_tiempo_ok = _gestor_chat.historial.size() == _tamano_tras_primer_envio + 1
	print("El cooldown se libera pasado el tiempo (esperado true): %s" % _cooldown_libera_pasado_el_tiempo_ok)


func _probar_largo_maximo_y_vacio() -> void:
	var tamano_antes = _gestor_chat.historial.size()
	_gestor_chat._validar_y_difundir("Fulano", "   ")
	_vacio_descartado_ok = _gestor_chat.historial.size() == tamano_antes
	print("Mensaje vacío/solo espacios descartado (esperado true): %s" % _vacio_descartado_ok)

	var texto_largo := "a".repeat(500)
	_gestor_chat._validar_y_difundir("Fulano", texto_largo)
	var ultimo: Dictionary = _gestor_chat.historial[_gestor_chat.historial.size() - 1]
	_largo_maximo_ok = (ultimo.get("texto", "") as String).length() == _gestor_chat.LARGO_MAXIMO_MENSAJE
	print("Texto recortado a LARGO_MAXIMO_MENSAJE=%d (obtenido %d): %s" % [
		_gestor_chat.LARGO_MAXIMO_MENSAJE, (ultimo.get("texto", "") as String).length(), _largo_maximo_ok])


func _probar_historial_limitado() -> void:
	for i in (_gestor_chat.HISTORIAL_MAXIMO + 20):
		_gestor_chat._validar_y_difundir("Relleno", "mensaje %d" % i)
	_historial_limitado_ok = _gestor_chat.historial.size() == _gestor_chat.HISTORIAL_MAXIMO
	print("El historial no crece más allá de HISTORIAL_MAXIMO=%d (obtenido %d): %s" % [
		_gestor_chat.HISTORIAL_MAXIMO, _gestor_chat.historial.size(), _historial_limitado_ok])


func _informar() -> bool:
	var exito := _nombre_resuelto_del_servidor_ok and _texto_recortado_ok and _vacio_descartado_ok \
		and _cooldown_frena_envio_inmediato_ok and _cooldown_libera_pasado_el_tiempo_ok \
		and _largo_maximo_ok and _historial_limitado_ok
	print("PRUEBA GESTOR CHAT VALIDACION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
