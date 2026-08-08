# =============================================================================
# Prueba de la pasiva de gatillo "Cosecha de Vida" (ver
# escenas/pasivas/cosecha_de_vida/PasivaCosechaDeVida.gd): al matar a un
# enemigo de un golpe PROPIO, cura un 5% de la vida máxima. No hay evento de
# "maté a X" — se detecta con daño_aplicado + fuente == dueño + la vida del
# objetivo llegando a 0 (quitar_vida() ya deja salud_actual en 0 ANTES de que
# el llamador emita daño_aplicado, ver Combate.gd/VidaComponente.gd).
#
# Cubre:
#   1. Golpe que MATA a un enemigo propio → cura un 5% de la vida máxima.
#   2. Golpe que NO mata (el enemigo sigue con vida) → no cura nada.
#   3. Golpe que mata pero de OTRO jugador (no el dueño de la pasiva) → no
#      cura al dueño (daño_aplicado es global, hay que filtrar por fuente).
#   godot --headless --path . --script res://pruebas/prueba_pasiva_cosecha_de_vida.gd
# =============================================================================
extends SceneTree

const VIDA_MAXIMA_DUEÑO := 100.0
const VIDA_INICIAL_DUEÑO := 50.0
const PORCENTAJE_CURACION := 0.05

var _dueño
var _vida_dueño
var _ajeno
var _bus

var _cura_al_matar_ok := false
var _no_cura_sin_matar_ok := false
var _no_cura_si_no_soy_yo_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_mata_cura()
	_probar_no_mata_no_cura()
	_probar_otro_mata_no_me_cura()
	return _informar()


func _montar() -> void:
	_dueño = CharacterBody2D.new()
	_dueño.add_to_group("jugadores")
	root.add_child(_dueño)
	_vida_dueño = VidaComponente.new()
	_vida_dueño.name = "VidaComponente"
	_vida_dueño.salud_maxima = VIDA_MAXIMA_DUEÑO
	_vida_dueño.intervalo_regeneracion = 0.0
	_dueño.add_child(_vida_dueño)
	_vida_dueño.restaurar_vida(VIDA_INICIAL_DUEÑO)

	_ajeno = CharacterBody2D.new()
	_ajeno.add_to_group("jugadores")
	root.add_child(_ajeno)

	var pasiva := (load("res://escenas/pasivas/cosecha_de_vida/PasivaCosechaDeVida.tscn") as PackedScene).instantiate()
	pasiva.entidad_dueña = _dueño
	_dueño.add_child(pasiva)

	_bus = root.get_node("/root/BusEventos")


func _crear_enemigo(vida_inicial: float) -> Dictionary:
	var enemigo := CharacterBody2D.new()
	root.add_child(enemigo)
	var vida := VidaComponente.new()
	vida.name = "VidaComponente"
	vida.salud_maxima = 30.0
	vida.intervalo_regeneracion = 0.0
	enemigo.add_child(vida)
	vida.restaurar_vida(vida_inicial)
	return {"nodo": enemigo, "vida": vida}


func _probar_mata_cura() -> void:
	var enemigo := _crear_enemigo(10.0)
	var vida_enemigo: VidaComponente = enemigo["vida"]
	# Golpe letal, mismo orden que Combate.gd: primero quitar_vida() de
	# verdad, DESPUÉS el aviso global.
	vida_enemigo.quitar_vida(9999.0, _dueño, 0, false)
	_bus.daño_aplicado.emit(enemigo["nodo"], 9999.0, _dueño, 0, false)
	print("Vida del dueño tras rematar un enemigo propio (esperado %.1f = %.0f + 5%%): %.1f" % [
		VIDA_INICIAL_DUEÑO + VIDA_MAXIMA_DUEÑO * PORCENTAJE_CURACION, VIDA_INICIAL_DUEÑO, _vida_dueño.obtener_vida()])
	_cura_al_matar_ok = is_equal_approx(
		_vida_dueño.obtener_vida(), VIDA_INICIAL_DUEÑO + VIDA_MAXIMA_DUEÑO * PORCENTAJE_CURACION)


func _probar_no_mata_no_cura() -> void:
	var vida_antes: float = _vida_dueño.obtener_vida()
	var enemigo := _crear_enemigo(30.0)
	var vida_enemigo: VidaComponente = enemigo["vida"]
	vida_enemigo.quitar_vida(5.0, _dueño, 0, false)  # sigue con vida
	_bus.daño_aplicado.emit(enemigo["nodo"], 5.0, _dueño, 0, false)
	print("Vida del dueño SIN cambios tras un golpe que no mata (esperado %.1f): %.1f" % [
		vida_antes, _vida_dueño.obtener_vida()])
	_no_cura_sin_matar_ok = is_equal_approx(_vida_dueño.obtener_vida(), vida_antes)


func _probar_otro_mata_no_me_cura() -> void:
	var vida_antes: float = _vida_dueño.obtener_vida()
	var enemigo := _crear_enemigo(10.0)
	var vida_enemigo: VidaComponente = enemigo["vida"]
	vida_enemigo.quitar_vida(9999.0, _ajeno, 0, false)  # lo mató OTRO jugador
	_bus.daño_aplicado.emit(enemigo["nodo"], 9999.0, _ajeno, 0, false)
	print("Vida del dueño SIN cambios cuando mata otro jugador (esperado %.1f): %.1f" % [
		vida_antes, _vida_dueño.obtener_vida()])
	_no_cura_si_no_soy_yo_ok = is_equal_approx(_vida_dueño.obtener_vida(), vida_antes)


func _informar() -> bool:
	var exito := _cura_al_matar_ok and _no_cura_sin_matar_ok and _no_cura_si_no_soy_yo_ok
	print("  matar un enemigo propio cura 5%%: %s" % _cura_al_matar_ok)
	print("  un golpe que no mata no cura: %s" % _no_cura_sin_matar_ok)
	print("  matar de otro jugador no me cura: %s" % _no_cura_si_no_soy_yo_ok)
	print("PRUEBA PASIVA COSECHA DE VIDA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
