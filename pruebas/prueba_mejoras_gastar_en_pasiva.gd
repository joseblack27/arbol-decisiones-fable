# =============================================================================
# Prueba de gastar puntos de mejora en una pasiva de ESTADÍSTICA (ver
# MejorasComponente._gastar_en_pasiva_local / reaplicar_pasivas_compradas)
# — sin RPC de red todavía (eso se prueba más adelante), solo la lógica
# real de aplicar el gasto.
#
# Cubre:
#   1. Gastar suma OTRO tier del bono (además del gratis que ya dio el
#      desbloqueo automático por nivel) y descuenta los puntos.
#   2. Rechaza sin puntos suficientes.
#   3. Respeta max_niveles.
#   4. Respeta el requisito de nivel de personaje (nivel_requerido).
#   5. Reconexión: reaplicar_pasivas_compradas() reaplica los tiers YA
#      comprados sin duplicar (tras el reseteo a línea de base que hace
#      restaurar_xp()).
#   godot --headless --path . --script res://pruebas/prueba_mejoras_gastar_en_pasiva.gd
# =============================================================================
extends SceneTree

var _jugador
var _atributos
var _experiencia
var _mejoras
var _pasiva: PasivaStatDesbloqueo

var _gasto_suma_tier_ok := false
var _rechaza_sin_puntos_ok := false
var _respeta_tope_ok := false
var _respeta_nivel_requerido_ok := false
var _sobrevive_reconexion_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_gasto_basico()
	_probar_sin_puntos()
	_probar_tope()
	_probar_nivel_requerido()
	_probar_reconexion()
	return _informar()


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	_atributos = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	_atributos.name = "AtributosComponente"
	_atributos.base = AtributosBase.new()
	_jugador.add_child(_atributos)
	_atributos._ready()

	_pasiva = PasivaStatDesbloqueo.new()
	_pasiva.resource_path = "res://pruebas/fixtures/PasivaStatDePrueba.tres"
	_pasiva.nivel_requerido = 3
	_pasiva.max_niveles = 2
	_pasiva.costo_puntos_por_nivel = 1
	_pasiva.bono = AtributosBase.new()
	_pasiva.bono.defensa = 4.0

	_experiencia = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	_experiencia.name = "ExperienciaComponente"
	_experiencia.pasivas_stat = [_pasiva] as Array[PasivaStatDesbloqueo]
	_jugador.add_child(_experiencia)

	_mejoras = (load("res://componentes/MejorasComponente.gd") as GDScript).new()
	_mejoras.name = "MejorasComponente"
	_jugador.add_child(_mejoras)

	# Curva triangular: XP para nivel 3 = 100*2*3/2 = 300.
	_experiencia.agregar_xp(300)  # desbloquea el tier gratis (defensa = 4)


func _probar_gasto_basico() -> void:
	print("Defensa tras el desbloqueo gratis (esperado 4): %.1f" % _atributos.base.defensa)
	print("Puntos disponibles en nivel 3 (esperado 3): %d" % _mejoras.puntos_disponibles())

	var resultado: bool = _mejoras._gastar_en_pasiva_local(_pasiva)
	print("Gasto del primer tier comprado (esperado true): %s" % resultado)
	print("Defensa tras comprar un tier (esperado 8 = 4 gratis + 4 comprado): %.1f" % _atributos.base.defensa)
	print("Puntos tras gastar 1 (esperado 2): %d" % _mejoras.puntos_disponibles())

	_gasto_suma_tier_ok = resultado and is_equal_approx(_atributos.base.defensa, 8.0) \
		and _mejoras.puntos_disponibles() == 2


func _probar_sin_puntos() -> void:
	_mejoras.puntos_gastados = 99  # deja el disponible en negativo
	var resultado: bool = _mejoras._gastar_en_pasiva_local(_pasiva)
	print("Gasto sin puntos suficientes (esperado false): %s" % resultado)
	_rechaza_sin_puntos_ok = not resultado
	_mejoras.puntos_gastados = 1  # deshace, para las pruebas siguientes


func _probar_tope() -> void:
	# max_niveles = 2, ya se compró 1 tier arriba — un segundo gasto debe
	# alcanzar el tope; un tercero debe rechazarse.
	var segundo: bool = _mejoras._gastar_en_pasiva_local(_pasiva)
	print("Segundo tier, llega al tope (esperado true): %s" % segundo)
	var tercero: bool = _mejoras._gastar_en_pasiva_local(_pasiva)
	print("Tercer tier, pasado el tope de %d (esperado false): %s" % [_pasiva.max_niveles, tercero])
	_respeta_tope_ok = segundo and not tercero


func _probar_nivel_requerido() -> void:
	var pasiva_alta := PasivaStatDesbloqueo.new()
	pasiva_alta.resource_path = "res://pruebas/fixtures/PasivaStatAltaDePrueba.tres"
	pasiva_alta.nivel_requerido = 50  # muy por encima del nivel 3 actual
	pasiva_alta.max_niveles = 5
	pasiva_alta.costo_puntos_por_nivel = 1
	pasiva_alta.bono = AtributosBase.new()
	pasiva_alta.bono.defensa = 1.0

	var resultado: bool = _mejoras._gastar_en_pasiva_local(pasiva_alta)
	print("Gasto en pasiva de nivel muy alto, sin alcanzarlo (esperado false): %s" % resultado)
	_respeta_nivel_requerido_ok = not resultado


func _probar_reconexion() -> void:
	# En este punto: 1 tier gratis (defensa=4) + 2 tiers comprados (defensa
	# +4+4=8) = defensa total 12. restaurar_xp() resetea a línea de base y
	# reaplica SOLO el crecimiento por nivel (el tier gratis) — hace falta
	# reaplicar_pasivas_compradas() para que los 2 comprados no se pierdan.
	print("Defensa antes de reconectar (esperado 12): %.1f" % _atributos.base.defensa)
	_experiencia.restaurar_xp(_experiencia.xp_total)
	print("Defensa tras restaurar_xp, SIN reaplicar mejoras todavía (esperado 4, solo el gratis): %.1f" % \
		_atributos.base.defensa)
	_mejoras.reaplicar_pasivas_compradas(_experiencia.pasivas_stat)
	print("Defensa tras reaplicar_pasivas_compradas (esperado 12 de nuevo): %.1f" % _atributos.base.defensa)

	# Reconectar una SEGUNDA vez no debe duplicar (mismo criterio que toda
	# reconexión: llamar el flujo completo varias veces da el mismo resultado).
	_experiencia.restaurar_xp(_experiencia.xp_total)
	_mejoras.reaplicar_pasivas_compradas(_experiencia.pasivas_stat)
	print("Defensa tras una SEGUNDA reconexión (esperado 12, no duplica): %.1f" % _atributos.base.defensa)

	_sobrevive_reconexion_ok = is_equal_approx(_atributos.base.defensa, 12.0)


func _informar() -> bool:
	var exito := _gasto_suma_tier_ok and _rechaza_sin_puntos_ok and _respeta_tope_ok \
		and _respeta_nivel_requerido_ok and _sobrevive_reconexion_ok
	print("  gastar suma un tier y descuenta puntos: %s" % _gasto_suma_tier_ok)
	print("  rechaza sin puntos suficientes: %s" % _rechaza_sin_puntos_ok)
	print("  respeta max_niveles: %s" % _respeta_tope_ok)
	print("  respeta nivel_requerido: %s" % _respeta_nivel_requerido_ok)
	print("  sobrevive a reconexión sin duplicar: %s" % _sobrevive_reconexion_ok)
	print("PRUEBA MEJORAS GASTAR EN PASIVA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
