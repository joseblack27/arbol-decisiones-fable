# =============================================================================
# Prueba de GestorSonido (primer sistema de audio del proyecto):
#   1. Crea un bus "SFX" propio (no depende de un default_bus_layout.tres a
#      mano) al arrancar.
#   2. aplicar_volumen() vuelca Utils.volumen_sfx (0.0-1.0) al bus real como
#      dB (linear_to_db) — 0 = silencio absoluto (-inf dB), 1 = sin atenuar
#      (0 dB).
#   3. reproducir() usa un pool chico de AudioStreamPlayer reciclados (no
#      instancia uno nuevo por sonido) y de verdad les asigna el stream y los
#      pone a sonar (playing=true) — en --headless no hay salida de audio
#      real, pero el estado del nodo (stream/playing/bus) sí es verificable.
#   godot --headless --path . --script res://pruebas/prueba_gestor_sonido.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _gestor: Node
var _utils: Node
var _sonido: AudioStream


func _process(_d: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			return _informar()
	return false


func _montar() -> void:
	_gestor = root.get_node("/root/GestorSonido")
	_utils = root.get_node("/root/Utils")
	_sonido = load("res://assets/audio/sfx/loot_pickup.wav")


func _informar() -> bool:
	var idx_bus := AudioServer.get_bus_index("SFX")
	var bus_creado_ok: bool = idx_bus != -1
	print("Existe el bus 'SFX' (esperado true): %s" % bus_creado_ok)

	var pool_en_bus_ok := true
	for jugador in _gestor._pool:
		if jugador.bus != "SFX":
			pool_en_bus_ok = false
	print("Todo el pool reproduce en el bus 'SFX' (esperado true): %s" % pool_en_bus_ok)

	# Volumen máximo (1.0) -> 0 dB (sin atenuar).
	_utils.volumen_sfx = 1.0
	_gestor.aplicar_volumen()
	var volumen_maximo_ok: bool = is_equal_approx(AudioServer.get_bus_volume_db(idx_bus), 0.0)
	print("volumen_sfx=1.0 -> 0 dB en el bus (esperado true): %s" % volumen_maximo_ok)

	# Volumen 0 -> silencio real (-inf dB / mute efectivo).
	_utils.volumen_sfx = 0.0
	_gestor.aplicar_volumen()
	var volumen_cero_ok: bool = AudioServer.get_bus_volume_db(idx_bus) < -60.0
	print("volumen_sfx=0.0 -> silencio real en el bus (esperado true): %s" % volumen_cero_ok)

	# reproducir() asigna el stream y lo pone a sonar en un reproductor del
	# pool, sin instanciar nada nuevo.
	var jugadores_antes: int = _gestor._pool.size()
	_gestor.reproducir(_sonido)
	var jugador: AudioStreamPlayer = _gestor._pool[0]
	var reproduce_ok: bool = jugador.stream == _sonido and jugador.playing
	var sin_instanciar_de_mas_ok: bool = _gestor._pool.size() == jugadores_antes
	print("reproducir() asigna el stream y lo pone a sonar (esperado true): %s" % reproduce_ok)
	print("No instancia reproductores nuevos (esperado true, sigue en %d): %s" % [
		jugadores_antes, sin_instanciar_de_mas_ok])

	# Ronda siguiente: el segundo llamado usa OTRO reproductor del pool
	# (round-robin), no pisa el primero mientras siga sonando.
	_gestor.reproducir(_sonido)
	var round_robin_ok: bool = _gestor._siguiente == 2
	print("Dos llamados seguidos avanzan el pool (esperado true, _siguiente=%d): %s" % [
		_gestor._siguiente, round_robin_ok])

	var exito := bus_creado_ok and pool_en_bus_ok and volumen_maximo_ok \
		and volumen_cero_ok and reproduce_ok and sin_instanciar_de_mas_ok and round_robin_ok
	print("PRUEBA GESTOR SONIDO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
