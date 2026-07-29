# =============================================================================
# Prueba de que UIHabilidad (el botón táctil de cada habilidad) solo
# reacciona a la ENERGÍA/COOLDOWN del jugador LOCAL — bug reportado como
# "gravísimo": "la energía se comparte entre los jugadores, o al menos
# cuando gasto toda la energía en un jugador, los demás jugadores no
# pueden lanzar habilidades por falta de energía".
#
# Causa real: BusEventos.energia_cambiada/recarga_iniciada/recarga_
# terminada son señales GLOBALES que disparan para CUALQUIER jugador
# visible en pantalla (el propio Y las réplicas de los demás) —
# _on_energia_cambiada/_on_recarga_iniciada/_on_recarga_terminada solo
# comprobaban "entidad.is_in_group('jugadores')" (cierto para cualquiera),
# nunca que la entidad fuera el jugador PROPIO. Como _sin_energia/
# _cd_restante bloquean el _input() real (el toque se descarta ANTES de
# mandar nada al servidor, ver _input() más abajo en UIHabilidad.gd), el
# gasto de energía (o el cooldown) de OTRO jugador terminaba bloqueándote
# el botón a vos.
#
# Usa un peer local (creado pero sin conectar a nadie) para que Utils.
# jugador_local() distinga de verdad "mi" jugador de uno "ajeno" — mismo
# patrón que prueba_oclusion_solo_jugador_local.gd. Sin esto, en modo sin
# red Utils.jugador_local() devolvería siempre el PRIMERO del grupo, sin
# poder simular la diferencia entre propio y ajeno.
#   godot --headless --path . --script res://pruebas/prueba_ui_habilidad_solo_jugador_local.gd
# =============================================================================
extends SceneTree

var _boton
var _jugador_local
var _jugador_ajeno
var _slot_hab
var _fotogramas := 0

var _energia_ajena_no_bloquea := false
var _energia_propia_si_bloquea := false
var _recarga_ajena_no_afecta := false
var _recarga_propia_si_afecta := false


static func _script_jugador_falso() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var peer_id_dueño: int = -1
"""
	guion.reload()
	return guion


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_probar_energia()
		6:
			_probar_recarga()
			return _informar()
	return false


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer
	var mi_id := root.multiplayer.get_unique_id()

	_jugador_local = CharacterBody2D.new()
	_jugador_local.set_script(_script_jugador_falso())
	_jugador_local.peer_id_dueño = mi_id
	_jugador_local.add_to_group("jugadores")
	root.add_child(_jugador_local)

	_jugador_ajeno = CharacterBody2D.new()
	_jugador_ajeno.set_script(_script_jugador_falso())
	_jugador_ajeno.peer_id_dueño = mi_id + 999
	_jugador_ajeno.add_to_group("jugadores")
	root.add_child(_jugador_ajeno)

	# Hijo del jugador LOCAL (no de root): así Utils.slot_habilidades_local()
	# (jugador_local().get_children() buscando un SlotHabilidades) lo
	# encuentra solo, sin pelear con el _conectar_slot() diferido de abajo.
	_slot_hab = SlotHabilidades.new()
	_jugador_local.add_child(_slot_hab)
	var hab_fake := HabilidadBase.new()
	hab_fake.costo_energia = 50.0
	_slot_hab._instancias[0] = hab_fake

	var escena := load("res://escenas/ui/ui_habilidad/UIHabilidad.tscn") as PackedScene
	_boton = escena.instantiate()
	_boton.slot_index = 0
	root.add_child(_boton)


func _probar_energia() -> void:
	# Energía del jugador AJENO cae a 0 (por debajo del costo de 50 de mi
	# habilidad equipada): NO debe bloquear mi botón.
	_boton._on_energia_cambiada(_jugador_ajeno, 0.0, 100.0)
	_energia_ajena_no_bloquea = not _boton._sin_energia

	# Mi propia energía cae a 0: AHORA sí debe bloquear.
	_boton._on_energia_cambiada(_jugador_local, 0.0, 100.0)
	_energia_propia_si_bloquea = _boton._sin_energia


func _probar_recarga() -> void:
	_boton._on_recarga_iniciada(_jugador_ajeno, 0, 2.0)
	_recarga_ajena_no_afecta = _boton._cd_restante <= 0.0

	_boton._on_recarga_iniciada(_jugador_local, 0, 2.0)
	_recarga_propia_si_afecta = _boton._cd_restante > 0.0


func _informar() -> bool:
	print("Energía de OTRO jugador NO bloquea mi botón (esperado true): %s" % _energia_ajena_no_bloquea)
	print("Mi PROPIA energía SÍ bloquea mi botón (esperado true): %s" % _energia_propia_si_bloquea)
	print("Cooldown de OTRO jugador NO me afecta (esperado true): %s" % _recarga_ajena_no_afecta)
	print("Mi PROPIO cooldown SÍ me afecta (esperado true): %s" % _recarga_propia_si_afecta)

	var exito := _energia_ajena_no_bloquea and _energia_propia_si_bloquea \
		and _recarga_ajena_no_afecta and _recarga_propia_si_afecta
	print("PRUEBA UI HABILIDAD SOLO JUGADOR LOCAL %s" % ("OK" if exito else "FALLIDA"))
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	quit(0 if exito else 1)
	return true
