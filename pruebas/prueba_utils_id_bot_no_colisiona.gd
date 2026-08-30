# =============================================================================
# Regresión: "hay un error al hacerlo desde el mismo pc, puse 2 bots y el
# que yo jugaré, 3 en total, y al iniciar yo, creaba en bucle todo el mundo
# una y otra vez y movía a todos los jugadores a la misma posición" —
# user://id_jugador.txt es por INSTALACIÓN, no por proceso: varias
# instancias de Godot en la misma PC compartían el mismo id_jugador_local(),
# así que el servidor los trataba como la MISMA cuenta reconectándose sin
# parar. En modo bot, Utils.id_jugador_local() ahora usa un UUID fresco en
# memoria, sin tocar el archivo compartido.
#
# Verifica:
#   1. Con modo_bot=false, id_jugador_local() lee/escribe el archivo
#      compartido de siempre (comportamiento sin cambios).
#   2. Con modo_bot=true, devuelve un id DISTINTO al de esa cuenta real.
#   3. Llamarlo de nuevo en modo bot devuelve el MISMO id (estable durante
#      toda la sesión del bot, no cambia en cada llamada).
#   4. El archivo compartido NO se tocó por las llamadas en modo bot — sigue
#      teniendo el id de la cuenta real de antes.
#   godot --headless --path . --script res://pruebas/prueba_utils_id_bot_no_colisiona.gd
# =============================================================================
extends SceneTree

var _id_real_antes := ""
var _id_bot_1 := ""
var _id_bot_2 := ""
var _id_real_archivo_despues := ""


func _process(_delta: float) -> bool:
	var utils = root.get_node("/root/Utils")

	utils.modo_bot = false
	_id_real_antes = utils.id_jugador_local()

	utils.modo_bot = true
	_id_bot_1 = utils.id_jugador_local()
	_id_bot_2 = utils.id_jugador_local()

	utils.modo_bot = false
	_id_real_archivo_despues = utils.id_jugador_local()

	var id_bot_distinto_del_real: bool = _id_bot_1 != "" and _id_bot_1 != _id_real_antes
	var id_bot_estable: bool = _id_bot_1 == _id_bot_2
	var archivo_compartido_intacto: bool = _id_real_archivo_despues == _id_real_antes

	print("Modo bot da un id distinto de la cuenta real (esperado true): %s" % id_bot_distinto_del_real)
	print("El id de bot es estable dentro de la misma sesión (esperado true): %s" % id_bot_estable)
	print("El archivo compartido no se tocó por el modo bot (esperado true): %s" % archivo_compartido_intacto)

	var exito := id_bot_distinto_del_real and id_bot_estable and archivo_compartido_intacto
	print("PRUEBA UTILS ID BOT NO COLISIONA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
