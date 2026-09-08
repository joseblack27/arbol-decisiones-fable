# =============================================================================
# Prueba de ObjetoRecolectable — pedido del usuario: "árboles como
# decoraciones pero que se puedan talar/recolectar sin hacha, del cual se
# pueda obtener leña" + "que fuera genérico... más fácil crear nuevas
# fuentes de recursos" + "que cambie de sprite, no permita recoger más y
# cambie de sprite más adelante como en 2 minutos dejando recoger de
# nuevo". Usa ArbolTalable.tscn (la primera "configuración" del script
# genérico) como instancia real.
#
# Cubre:
#   1. Sin red: interactuar() da el ítem SIN validar ningún equipo, cambia
#      el sprite a "agotado" y un segundo toque mientras está agotado no
#      hace nada. _al_timeout_respawn() (se llama directo, no se espera el
#      Timer real de 120s — mismo criterio que el resto de la suite con
#      timers reales) vuelve a dejarlo disponible.
#   2. Con red: mismo patrón "sin transporte real" que prueba_tienda_
#      comprar_item.gd — multiplayer.get_remote_sender_id() devuelve 0 al
#      llamar el RPC DIRECTO (sin nadie conectado de verdad), así que
#      jugador.name = "0" simula "el pedido vino de ese jugador de
#      verdad" (ver InteresEspacial.jugador_de_peer). Cubre: sender sin
#      jugador identificable rechaza, jugador identificable pero LEJOS del
#      árbol rechaza (anti-spoof de proximidad), jugador cerca de verdad
#      acepta.
#   godot --headless --path . --script res://pruebas/prueba_objeto_recolectable.gd
# =============================================================================
extends SceneTree

const _ARBOL_SCENE_PATH := "res://escenas/objetos/ArbolTalable.tscn"

var _jugador
var _inventario
var _arbol

var _recolecta_da_item_y_agota_ok := false
var _agotado_no_recolecta_de_nuevo_ok := false
var _respawn_vuelve_a_dejar_disponible_ok := false
var _spoof_sin_jugador_rechaza_ok := false
var _spoof_lejos_rechaza_ok := false
var _red_cerca_acepta_ok := false
var _servidor_coincide_con_boton_local_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_recolecta_da_item_y_agota()
	_probar_agotado_no_recolecta_de_nuevo()
	_probar_respawn_vuelve_a_dejar_disponible()
	_probar_validacion_red()
	_probar_servidor_coincide_con_boton_local()
	return _informar()


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_inventario = _jugador.get_node("InventarioComponente")

	_arbol = (load(_ARBOL_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_arbol)


func _cantidad_leña() -> int:
	var total := 0
	for item: DatosItem in _inventario.items:
		if item.name == "Leña":
			total += item.quantity
	return total


## Sin red: interactuar() aplica directo, sin validar ningún equipo del
## jugador (ver DatosItem — no hay ningún "hacha" ni check de can_equip acá).
## Verifica la animación ("cortado"/"completo", pedido explícito del
## usuario) en vez de la textura directa — ObjetoRecolectable ya no
## asigna sprite.texture a mano, lo hace el AnimationPlayer.
func _probar_recolecta_da_item_y_agota() -> void:
	_arbol.interactuar()
	print("Recolectar da Leña (esperado 1): %d" % _cantidad_leña())
	print("Queda agotado (esperado true): %s" % _arbol._agotado)
	print("La animación pasa a 'cortado' (esperado true): %s" % \
		(_arbol.animation_player.current_animation == "cortado"))
	_recolecta_da_item_y_agota_ok = _cantidad_leña() == 1 and _arbol._agotado \
		and _arbol.animation_player.current_animation == "cortado"


func _probar_agotado_no_recolecta_de_nuevo() -> void:
	_arbol.interactuar()
	print("Tocarlo agotado no da más leña (esperado 1): %d" % _cantidad_leña())
	_agotado_no_recolecta_de_nuevo_ok = _cantidad_leña() == 1


## _al_timeout_respawn() en vez de esperar el Timer real (120s) — mismo
## criterio que el resto de la suite con timers reales de gameplay.
func _probar_respawn_vuelve_a_dejar_disponible() -> void:
	_arbol._al_timeout_respawn()
	print("Tras el respawn, ya no está agotado (esperado false): %s" % _arbol._agotado)
	print("La animación vuelve a 'completo' (esperado true): %s" % \
		(_arbol.animation_player.current_animation == "completo"))
	# Captura ANTES de volver a interactuar — el segundo interactuar() ya
	# deja el árbol agotado de nuevo, evaluar esto DESPUÉS estaría
	# comparando el estado equivocado.
	var quedo_disponible_ok: bool = not _arbol._agotado \
		and _arbol.animation_player.current_animation == "completo"

	_arbol.interactuar()
	print("Y se puede volver a recolectar (esperado 2): %d" % _cantidad_leña())
	_respawn_vuelve_a_dejar_disponible_ok = quedo_disponible_ok and _cantidad_leña() == 2


## Mismo patrón que prueba_tienda_comprar_item.gd: ENetMultiplayerPeer de
## servidor SIN transporte real — get_remote_sender_id() da 0 al llamar el
## RPC directo. Usa un árbol y jugador NUEVOS (limpios, agotado=false).
func _probar_validacion_red() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer

	var arbol = (load(_ARBOL_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(arbol)
	arbol.global_position = Vector2.ZERO

	var jugador2 = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(jugador2)
	var inventario2 = jugador2.get_node("InventarioComponente")

	# Sender sin ningún jugador con ese nombre (InteresEspacial.jugador_de_
	# peer(0) no lo encuentra) — rechaza sin tocar nada.
	jugador2.name = "999"
	# InteresEspacial cachea jugador_de_peer() por fotograma físico (ver ese
	# archivo) — sin invalidar a mano acá, un renombrado DENTRO del mismo
	# fotograma (no hay transporte real de por medio) seguiría leyendo el
	# valor viejo. En juego real esto nunca hace falta.
	root.get_node("/root/InteresEspacial").invalidar_cache_jugadores()
	jugador2.global_position = arbol.global_position
	arbol._pedir_recolectar_red()
	print("Sender sin jugador identificable rechaza (esperado 0, false): %d, %s" % [
		_cantidad_en(inventario2), arbol._agotado
	])
	_spoof_sin_jugador_rechaza_ok = _cantidad_en(inventario2) == 0 and not arbol._agotado

	# Jugador identificable (nombre "0" == get_remote_sender_id()) pero
	# LEJOS del árbol — anti-spoof de proximidad, rechaza igual.
	jugador2.name = "0"
	root.get_node("/root/InteresEspacial").invalidar_cache_jugadores()
	jugador2.global_position = Vector2(5000, 5000)
	arbol._pedir_recolectar_red()
	print("Jugador identificable pero lejos rechaza (esperado 0, false): %d, %s" % [
		_cantidad_en(inventario2), arbol._agotado
	])
	_spoof_lejos_rechaza_ok = _cantidad_en(inventario2) == 0 and not arbol._agotado

	# Jugador identificable Y de verdad cerca — acepta. peer_id_dueño=0
	# (coincide con el "0" de arriba): sin esto, la confirmación al dueño
	# intentaría un rpc_id(-1, ...) inválido (el default de Jugador.gd).
	jugador2.peer_id_dueño = 0
	jugador2.global_position = arbol.global_position
	arbol._pedir_recolectar_red()
	print("Jugador identificable y cerca acepta (esperado 1, true): %d, %s" % [
		_cantidad_en(inventario2), arbol._agotado
	])
	_red_cerca_acepta_ok = _cantidad_en(inventario2) == 1 and arbol._agotado


## Bug real reportado: "la interacción de talar no sirve, no veo que haga
## nada" — con la instancia ESCALADA 2x igual que en NivelPradera.tscn, el
## servidor comparaba contra el origen sin escalar del StaticBody2D en vez
## de la posición real de area_interaccion (con su offset y la escala
## aplicados) — la misma posición que hace aparecer el botón local podía
## quedar afuera del radio que el servidor aceptaba. Coloca al jugador
## exactamente donde area_interaccion.global_position dice que está (lo
## mismo que dispara _al_entrar_interaccion/el botón) y confirma que el
## servidor AHORA acepta ese mismo punto.
func _probar_servidor_coincide_con_boton_local() -> void:
	# _probar_validacion_red() ya dejó un jugador llamado "0" (nunca lo
	# sacó del árbol) — InteresEspacial.jugador_de_peer() busca por NOMBRE
	# exacto, así que sin sacarlo primero, add_child() de abajo lo
	# renombraría solo (colisión de nombres) y jugador_de_peer(0) seguiría
	# encontrando el VIEJO, quieto en la posición de la prueba anterior.
	var viejo := root.get_node_or_null("0")
	if viejo:
		root.remove_child(viejo)
		viejo.queue_free()

	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer

	# scale ANTES de add_child(): _ready() (donde se deriva radio_
	# interaccion_servidor de area_interaccion.global_scale) corre EN el
	# add_child() — fijarlo después llegaría tarde, mismo motivo por el que
	# el .tscn de NivelPradera.tscn ya trae "scale" como valor inicial del
	# nodo en vez de asignarlo por código más tarde.
	var arbol = (load(_ARBOL_SCENE_PATH) as PackedScene).instantiate()
	arbol.position = Vector2(300, 300)
	arbol.scale = Vector2(2, 2)  # mismo factor que ArbolTalable1 en NivelPradera.tscn.
	root.add_child(arbol)

	var jugador2 = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(jugador2)
	jugador2.name = "0"
	root.get_node("/root/InteresEspacial").invalidar_cache_jugadores()
	jugador2.peer_id_dueño = 0
	var area := arbol.get_node("AreaInteraccion") as Area2D
	jugador2.global_position = area.global_position
	var inventario2 = jugador2.get_node("InventarioComponente")

	arbol._pedir_recolectar_red()
	print("Parado donde aparece el botón local, el servidor acepta (esperado 1, true): %d, %s" % [
		_cantidad_en(inventario2), arbol._agotado
	])
	_servidor_coincide_con_boton_local_ok = _cantidad_en(inventario2) == 1 and arbol._agotado


func _cantidad_en(inventario) -> int:
	var total := 0
	for item: DatosItem in inventario.items:
		if item.name == "Leña":
			total += item.quantity
	return total


func _informar() -> bool:
	var exito := _recolecta_da_item_y_agota_ok and _agotado_no_recolecta_de_nuevo_ok \
		and _respawn_vuelve_a_dejar_disponible_ok and _spoof_sin_jugador_rechaza_ok \
		and _spoof_lejos_rechaza_ok and _red_cerca_acepta_ok \
		and _servidor_coincide_con_boton_local_ok
	print("  recolectar da el ítem y agota: %s" % _recolecta_da_item_y_agota_ok)
	print("  agotado no recolecta de nuevo: %s" % _agotado_no_recolecta_de_nuevo_ok)
	print("  respawn vuelve a dejarlo disponible: %s" % _respawn_vuelve_a_dejar_disponible_ok)
	print("  anti-spoof, sin jugador identificable: %s" % _spoof_sin_jugador_rechaza_ok)
	print("  anti-spoof, jugador lejos: %s" % _spoof_lejos_rechaza_ok)
	print("  jugador cerca de verdad acepta: %s" % _red_cerca_acepta_ok)
	print("  servidor coincide con dónde aparece el botón local (instancia 2x): %s" % _servidor_coincide_con_boton_local_ok)
	print("PRUEBA OBJETO RECOLECTABLE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
