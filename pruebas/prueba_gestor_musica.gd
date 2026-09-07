# =============================================================================
# Prueba de GestorMusica (música de fondo, separada de GestorSonido/SFX):
#   1. Crea un bus "Music" propio al arrancar (independiente del bus "SFX").
#   2. aplicar_volumen() vuelca Utils.volumen_musica (0.0-1.0) al bus real
#      como dB (linear_to_db) — 0 = silencio absoluto, 1 = sin atenuar.
#   3. En su propio _ready() ya arrancó reproduciendo la pista por defecto
#      (Path_to_the_Moonlit_Grove.mp3) en loop, sin que nadie tenga que
#      llamar nada — "música de fondo" tiene que sonar sola.
#   4. reproducir() con la MISMA pista que ya suena no la reinicia (no pisa
#      el progreso de reproducción); con una pista DISTINTA sí cambia.
#   godot --headless --path . --script res://pruebas/prueba_gestor_musica.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _gestor: Node
var _utils: Node


func _process(_d: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			return _informar()
	return false


func _montar() -> void:
	_gestor = root.get_node("/root/GestorMusica")
	_utils = root.get_node("/root/Utils")


func _informar() -> bool:
	var idx_bus := AudioServer.get_bus_index("Music")
	var bus_creado_ok: bool = idx_bus != -1
	print("Existe el bus 'Music' (esperado true): %s" % bus_creado_ok)

	var bus_distinto_de_sfx_ok: bool = idx_bus != AudioServer.get_bus_index("SFX")
	print("El bus 'Music' es distinto del bus 'SFX' (esperado true): %s" % bus_distinto_de_sfx_ok)

	var reproductor: AudioStreamPlayer = _gestor._reproductor
	var arranca_solo_ok: bool = reproductor.stream != null and reproductor.playing \
		and reproductor.bus == "Music"
	print("Arranca solo reproduciendo la pista por defecto en el bus 'Music' (esperado true): %s" % arranca_solo_ok)

	var pista_original: AudioStream = reproductor.stream

	# Volumen máximo (1.0) -> 0 dB (sin atenuar).
	_utils.volumen_musica = 1.0
	_gestor.aplicar_volumen()
	var volumen_maximo_ok: bool = is_equal_approx(AudioServer.get_bus_volume_db(idx_bus), 0.0)
	print("volumen_musica=1.0 -> 0 dB en el bus (esperado true): %s" % volumen_maximo_ok)

	# Volumen 0 -> silencio real.
	_utils.volumen_musica = 0.0
	_gestor.aplicar_volumen()
	var volumen_cero_ok: bool = AudioServer.get_bus_volume_db(idx_bus) < -60.0
	print("volumen_musica=0.0 -> silencio real en el bus (esperado true): %s" % volumen_cero_ok)

	# Llamar reproducir() con la MISMA pista no la reinicia (mismo stream sigue puesto).
	_gestor.reproducir(pista_original)
	var no_reinicia_misma_pista_ok: bool = reproductor.stream == pista_original
	print("reproducir() con la misma pista no la reemplaza (esperado true): %s" % no_reinicia_misma_pista_ok)

	# Cambiar a otra pista real sí cambia el stream.
	var otra_pista := load("res://assets/audio/sfx/loot_pickup.wav")
	_gestor.reproducir(otra_pista)
	var cambia_a_otra_pista_ok: bool = reproductor.stream == otra_pista and reproductor.playing
	print("reproducir() con una pista distinta sí la reemplaza (esperado true): %s" % cambia_a_otra_pista_ok)

	var exito := bus_creado_ok and bus_distinto_de_sfx_ok and arranca_solo_ok \
		and volumen_maximo_ok and volumen_cero_ok and no_reinicia_misma_pista_ok and cambia_a_otra_pista_ok
	print("PRUEBA GESTOR MUSICA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
