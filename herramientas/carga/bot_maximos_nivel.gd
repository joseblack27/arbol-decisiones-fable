# =============================================================================
# bot_maximos_nivel.gd — comprueba contra el SERVIDOR REAL que al reconectar
# el jugador recupera los máximos de vida/energía de su nivel, en vez de nacer
# de nuevo como nivel 1 (vida tope 100, energía tope 100).
#
# Reportado: "no recalcula la nueva vida cuando se loguea y siempre tiene 100,
# y la energía sigue bugueada, no crece más de 105".
#
# Se corre en dos pasadas contra el mismo servidor, con la MISMA cuenta:
#
#   godot --headless --path . --script res://herramientas/carga/bot_maximos_nivel.gd -- --sembrar
#       Se conecta, se pone XP de nivel 6 y guarda. Es exactamente lo que
#       hace un jugador que subió de nivel jugando: el cliente manda su
#       xp_total en la partida y el servidor la escribe en SQLite.
#
#   godot --headless --path . --script res://herramientas/carga/bot_maximos_nivel.gd
#       Reconecta con la misma cuenta e informa qué máximos tiene el jugador
#       AUTORITATIVO (llegan replicados del servidor, no se calculan acá) y
#       si una jeringa de adrenalina sube la energía por encima de 100.
#
# Usa Mundo.tscn tal cual, como los demás bots: mismo camino de conexión,
# identidad, spawn y réplica que un cliente real.
# =============================================================================
extends SceneTree

## XP acumulada para estar en nivel 6 (curva triangular de TablaNiveles).
const XP_NIVEL_6 := 1500
const VIDA_ESPERADA := 150.0
const ENERGIA_ESPERADA := 125.0
## Cuenta fija: la gracia de la prueba es RECONECTAR sobre la misma partida.
const CUENTA := "botmaximos"
const PIN := "4242"

var _ip := "127.0.0.1"
var _sembrar := false
var _mundo: Node2D
var _jugador: CharacterBody2D
var _tiempo := 0.0
var _tiempo_con_jugador := 0.0
var _sembrado := false


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ip="):
			_ip = arg.substr(5)
		elif arg == "--sembrar":
			_sembrar = true


func _process(delta: float) -> bool:
	_tiempo += delta

	if _mundo == null:
		var utils = root.get_node("/root/Utils")
		utils.ip_conexion = _ip
		utils.puerto_conexion = 8920
		utils.modo_local_pruebas = false
		utils.nombre_conexion = CUENTA
		utils.pin_conexion = PIN
		print("[BOT] conectando a %s:8920 como '%s' (%s)" % [
			_ip, CUENTA, "sembrar" if _sembrar else "verificar"])
		_mundo = (load("res://escenas/mundo/Mundo.tscn") as PackedScene).instantiate()
		root.add_child(_mundo)
		current_scene = _mundo
		return false

	if _jugador == null or not is_instance_valid(_jugador):
		_buscar_jugador_propio()
		if _tiempo > 30.0:
			print("[BOT] ABANDONA: nunca spawneó.")
			quit(1)
			return true
		return false

	_tiempo_con_jugador += delta

	if _sembrar:
		return _paso_sembrar()
	# Margen para que llegue la partida del servidor, se aplique la XP y
	# vuelvan replicados los máximos reales.
	if _tiempo_con_jugador < 8.0:
		return false
	return _informar()


func _paso_sembrar() -> bool:
	# 4 s: que la carga de partida del servidor termine ANTES de pisar la XP,
	# si no el propio _recibir_partida_red la vuelve a bajar al valor viejo.
	if _tiempo_con_jugador < 4.0:
		return false
	if not _sembrado:
		_sembrado = true
		var experiencia = root.get_node("/root/GestorExperiencia")
		experiencia.xp_total = XP_NIVEL_6
		print("[BOT] XP local puesta en %d (nivel %d)" % [
			experiencia.xp_total, experiencia.nivel])
		root.get_node("/root/GestorGuardado").guardar_partida()
		return false
	# Margen para que el guardado viaje al servidor y entre en su buffer.
	if _tiempo_con_jugador < 8.0:
		return false
	print("[BOT] sembrado listo — reconectá sin --sembrar para verificar.")
	quit(0)
	return true


func _informar() -> bool:
	var vida = _jugador.get_node_or_null("VidaComponente")
	var energia = _jugador.get_node_or_null("EnergiaComponente")
	var experiencia = _jugador.get_node_or_null("ExperienciaComponente")
	if vida == null or energia == null:
		print("[BOT] el jugador no tiene los componentes esperados.")
		quit(1)
		return true

	var vida_max: float = vida.obtener_vida_maxima()
	var energia_max: float = energia.obtener_energia_maxima()
	print("[BOT] nivel del cliente: %d" % (experiencia.nivel if experiencia else -1))
	print("[BOT] vida    %.0f / %.0f  (esperado máximo %.0f)" % [
		vida.obtener_vida(), vida_max, VIDA_ESPERADA])
	print("[BOT] energía %.0f / %.0f  (esperado máximo %.0f)" % [
		energia.obtener_energia(), energia_max, ENERGIA_ESPERADA])

	var vida_ok := is_equal_approx(vida_max, VIDA_ESPERADA)
	var energia_ok := is_equal_approx(energia_max, ENERGIA_ESPERADA)
	print("[BOT] vida máxima correcta: %s" % vida_ok)
	print("[BOT] energía máxima correcta: %s" % energia_ok)
	print("BOT MAXIMOS NIVEL %s" % ("OK" if (vida_ok and energia_ok) else "FALLIDO"))
	quit(0 if (vida_ok and energia_ok) else 1)
	return true


func _buscar_jugador_propio() -> void:
	for nodo in root.get_tree().get_nodes_in_group(&"jugadores"):
		if nodo is CharacterBody2D and nodo.is_multiplayer_authority():
			_jugador = nodo
			print("[BOT] jugador propio encontrado.")
			return
