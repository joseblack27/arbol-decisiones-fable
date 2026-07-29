# =============================================================================
# Prueba de que HabilidadLanzallamas SÍ avisa el fin del canal cuando lo
# corta el SERVIDOR por su cuenta (energía agotada o tiempo máximo) — bug
# reportado: "no detiene la animación cuando se acaba la energía o el
# tiempo, solo se detiene si se suelta antes de estos dos casos".
#
# Antes, _detener_canal() solo avisaba a espectadores cuando lo llamaba
# _terminar_canal_red() (el CLIENTE pidiendo parar). Si el corte lo
# decidía el SERVIDOR por su cuenta (el único lado que corre el consumo de
# energía real — ver el gate "Utils.en_red() and not multiplayer.is_
# server()" en _process — y también quien puede ganarle de mano al
# cliente en el tope de duración), nadie se enteraba: ni los espectadores
# ni, sobre todo, el propio dueño remoto, cuya predicción (_canalizando)
# seguía en true hasta soltar el dedo a mano.
#
# No arma una red real de 2 clientes+servidor (ver prueba_lanzallamas_
# visual_remoto.gd: mismo motivo, entorno lento/flaky para eso) — en
# cambio, verifica los dos extremos del arreglo por separado, llamando
# directo a la lógica real sin transporte de red:
#   1. Lado SERVIDOR: al cortar el canal con autoridad real, _detener_
#      canal() ahora SÍ dispara el aviso a espectadores (antes solo lo
#      hacía _terminar_canal_red(), nunca un corte decidido acá mismo).
#   2. Lado CLIENTE DUEÑO: al recibir el aviso de fin (_recibir_fin_
#      visual_chorro_red, lo que en el juego real manda el servidor), si
#      esta copia es la del dueño real (peer_id_dueño == mi unique_id) y
#      seguía "canalizando", corta la predicción local YA (_canalizando a
#      false, entra en cooldown) sin esperar a que el jugador suelte el
#      dedo.
#   3. Lado ESPECTADOR (peer_id_dueño ajeno): el mismo aviso NO le toca el
#      _canalizando de un dueño que no es el propio.
#   godot --headless --path . --script res://pruebas/prueba_lanzallamas_detiene_canal_por_servidor.gd
# =============================================================================
extends SceneTree

var _jugador
var _habilidad
var _fotogramas := 0

var _servidor_avisa_espectadores := false
var _servidor_corta_canalizando := false
var _servidor_entra_en_cooldown := false
var _dueño_corta_canalizando := false
var _dueño_entra_en_cooldown := false
var _espectador_no_le_tocan_canalizando := false


static func _script_habilidad_espia() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends HabilidadLanzallamas
var aviso_espectadores_llamado := false
func _avisar_fin_visual_a_espectadores() -> void:
	aviso_espectadores_llamado = true
"""
	guion.reload()
	return guion


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
			_probar_lado_servidor()
		2:
			_probar_lado_dueño()
		3:
			_probar_lado_espectador()
			return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	_habilidad = _script_habilidad_espia().new()
	_habilidad.slot_index = 0
	_habilidad.set("costo_energia", 0.0)
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador
	_habilidad.duracion_recarga = 2.0


## Simula al SERVIDOR (autoridad real) cortando el canal por su cuenta —
## energía agotada o tope de duración, detectados dentro de _process, no
## por un aviso del cliente.
func _probar_lado_servidor() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer
	_jugador.peer_id_dueño = 55  # dueño real: un CLIENTE distinto del servidor.

	_habilidad._canalizando = true
	_habilidad._detener_canal()

	_servidor_corta_canalizando = not _habilidad._canalizando
	_servidor_entra_en_cooldown = _habilidad.obtener_recarga_restante() > 0.0
	_servidor_avisa_espectadores = _habilidad.aviso_espectadores_llamado
	print("Servidor corta _canalizando al cortar por su cuenta (esperado true): %s" % _servidor_corta_canalizando)
	print("Servidor entra en cooldown (esperado true): %s" % _servidor_entra_en_cooldown)
	print("Servidor avisa a espectadores (antes NUNCA pasaba en este caso, esperado true): %s" % _servidor_avisa_espectadores)


## Simula al CLIENTE DUEÑO recibiendo el aviso de fin que el servidor
## manda tras el corte de arriba — su propia predicción (_canalizando)
## nunca se hubiera enterado sola de la energía agotada.
func _probar_lado_dueño() -> void:
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 34599)  # puerto sin nadie escuchando: no hace falta que conecte.
	root.multiplayer.multiplayer_peer = peer
	var mi_id := root.multiplayer.get_unique_id()
	_jugador.peer_id_dueño = mi_id  # ahora ESTA copia es la del dueño real.

	_habilidad._canalizando = true  # seguía prediciendo el canal como activo.
	_habilidad._recibir_fin_visual_chorro_red()

	_dueño_corta_canalizando = not _habilidad._canalizando
	_dueño_entra_en_cooldown = _habilidad.obtener_recarga_restante() > 0.0
	print("Dueño corta su propia predicción al recibir el aviso (esperado true): %s" % _dueño_corta_canalizando)
	print("Dueño entra en cooldown tras el aviso (esperado true): %s" % _dueño_entra_en_cooldown)


## Un ESPECTADOR (peer_id_dueño ajeno) recibiendo el mismo aviso NO debe
## forzar el corte de un _canalizando que no es el suyo.
func _probar_lado_espectador() -> void:
	_jugador.peer_id_dueño = 999  # ya no coincide con mi unique_id.
	_habilidad._canalizando = true
	_habilidad._recibir_fin_visual_chorro_red()
	_espectador_no_le_tocan_canalizando = _habilidad._canalizando
	print("Espectador NO le tocan su _canalizando ajeno (esperado true, sin cambios): %s" % _espectador_no_le_tocan_canalizando)

	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _informar() -> bool:
	var exito := _servidor_corta_canalizando and _servidor_entra_en_cooldown \
		and _servidor_avisa_espectadores and _dueño_corta_canalizando \
		and _dueño_entra_en_cooldown and _espectador_no_le_tocan_canalizando
	print("PRUEBA LANZALLAMAS DETIENE CANAL POR SERVIDOR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
