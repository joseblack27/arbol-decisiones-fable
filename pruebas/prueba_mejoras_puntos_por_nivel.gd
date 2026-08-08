# =============================================================================
# Prueba de la economía de puntos de MejorasComponente: se ganan por nivel
# de personaje, DERIVADOS (nivel * PUNTOS_POR_NIVEL - puntos_gastados) igual
# que vida_maxima/energia_maxima — nunca se guarda un contador de "puntos
# ganados" aparte, solo lo GASTADO.
#
# Cubre:
#   1. Subir de nivel aumenta los puntos disponibles.
#   2. Gastar puntos (puntos_gastados directo, sin pasar por compra real
#      todavía — eso lo cubren las pruebas de gastar_en_pasiva/habilidad)
#      los descuenta de los disponibles.
#   3. restaurar_xp() (reconexión) re-deriva los disponibles a partir del
#      nivel real, sin duplicar ni perder lo ya gastado.
#   godot --headless --path . --script res://pruebas/prueba_mejoras_puntos_por_nivel.gd
# =============================================================================
extends SceneTree

var _jugador
var _experiencia
var _mejoras

var _puntos_suben_con_nivel_ok := false
var _gasto_descuenta_ok := false
var _sobrevive_reconexion_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_puntos_por_nivel()
	_probar_gasto_descuenta()
	_probar_reconexion()
	return _informar()


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	_experiencia = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	_experiencia.name = "ExperienciaComponente"
	_jugador.add_child(_experiencia)

	_mejoras = (load("res://componentes/MejorasComponente.gd") as GDScript).new()
	_mejoras.name = "MejorasComponente"
	_jugador.add_child(_mejoras)


func _probar_puntos_por_nivel() -> void:
	print("Puntos en nivel 1 (esperado 1): %d" % _mejoras.puntos_disponibles())
	var ok_nivel_1: bool = _mejoras.puntos_disponibles() == 1

	# Curva triangular: XP para nivel 4 = 100*3*4/2 = 600.
	_experiencia.agregar_xp(600)
	print("Nivel tras 600 XP (esperado 4): %d" % _experiencia.nivel)
	print("Puntos en nivel 4 (esperado 4): %d" % _mejoras.puntos_disponibles())
	_puntos_suben_con_nivel_ok = ok_nivel_1 and _experiencia.nivel == 4 \
		and _mejoras.puntos_disponibles() == 4


func _probar_gasto_descuenta() -> void:
	_mejoras.puntos_gastados = 3
	print("Puntos tras gastar 3 de 4 (esperado 1): %d" % _mejoras.puntos_disponibles())
	_gasto_descuenta_ok = _mejoras.puntos_disponibles() == 1


func _probar_reconexion() -> void:
	_experiencia.restaurar_xp(_experiencia.xp_total)  # simula reconexión con la misma XP
	print("Nivel tras restaurar_xp (esperado 4): %d" % _experiencia.nivel)
	print("Puntos tras reconectar, con 3 ya gastados (esperado 1, no duplica): %d" % \
		_mejoras.puntos_disponibles())
	_sobrevive_reconexion_ok = _experiencia.nivel == 4 and _mejoras.puntos_disponibles() == 1


func _informar() -> bool:
	var exito := _puntos_suben_con_nivel_ok and _gasto_descuenta_ok and _sobrevive_reconexion_ok
	print("  puntos suben con el nivel: %s" % _puntos_suben_con_nivel_ok)
	print("  gastar puntos los descuenta: %s" % _gasto_descuenta_ok)
	print("  sobrevive a reconexión sin duplicar: %s" % _sobrevive_reconexion_ok)
	print("PRUEBA MEJORAS PUNTOS POR NIVEL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
