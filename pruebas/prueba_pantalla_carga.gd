# =============================================================================
# Prueba de la pantalla de carga (autoload GestorCarga, ver
# escenas/ui/pantalla_carga/PantallaCarga.gd).
#
# Pedido del usuario: "colocame una pantalla de carga usando un progressbar
# con datos reales de lo que carga cuando esta cargando la escena inicial
# despues de iniciar la conexion, solo cuando todo este cargado es que debe
# quitarse".
#
# Verifica el MODELO DE PROGRESO (lo que se puede probar sin render real):
#   1. Los pesos de las etapas suman exactamente 1.0 — si no, la barra nunca
#      llegaría al 100% (o lo pasaría antes de terminar).
#   2. avanzar() ubica el total según el peso de las etapas anteriores más
#      la fracción de la actual.
#   3. Entrar a una etapa da por completadas las anteriores — así una etapa
#      que no llegue a reportarse (cuenta nueva sin partida guardada) no
#      deja la barra trabada.
#   4. El total NUNCA retrocede, aunque llegue un avance más viejo/menor.
#   5. Arranca oculta, mostrar() la enciende, y terminar() la deja en 100%
#      antes de apagarla (solo cuando todo cargó, no antes).
#   6. avanzar() antes de mostrar() no hace nada (no se enciende sola).
#   godot --headless --path . --script res://pruebas/prueba_pantalla_carga.gd
# =============================================================================
extends SceneTree

var _carga
var _fotogramas := 0

var _pesos_suman_uno := false
var _no_se_enciende_sola := false
var _arranca_oculta := false
var _mostrar_la_enciende := false
var _primera_etapa_en_cero := false
var _fraccion_intermedia_correcta := false
var _entrar_a_etapa_completa_las_previas := false
var _nunca_retrocede := false
var _terminar_llega_a_cien := false
var _terminar_la_apaga := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_probar_modelo()
		40:
			# terminar() deja ver el 100% un instante antes de apagarse
			# (~0.35s) — para el fotograma 40 (~0.6s) ya se apagó.
			_terminar_la_apaga = not _carga.visible
			print("terminar() termina apagando la pantalla (esperado true): %s" % _terminar_la_apaga)
			return _informar()
	return false


func _montar() -> void:
	_carga = root.get_node("/root/GestorCarga")

	var suma := 0.0
	for etapa in _carga.ETAPAS:
		suma += etapa["peso"]
	_pesos_suman_uno = is_equal_approx(suma, 1.0)
	print("Los pesos de las etapas suman 1.0 (esperado true, suma=%.4f): %s" % [suma, _pesos_suman_uno])

	_arranca_oculta = not _carga.visible and not _carga.esta_visible()
	print("Arranca oculta (esperado true): %s" % _arranca_oculta)

	# Sin mostrar() previo, avanzar() no debe hacer nada.
	_carga.avanzar(&"nivel", 1.0)
	_no_se_enciende_sola = not _carga.esta_visible() and is_equal_approx(_carga._total_mostrado, 0.0)
	print("avanzar() antes de mostrar() no hace nada (esperado true): %s" % _no_se_enciende_sola)


func _probar_modelo() -> void:
	_carga.mostrar()
	_mostrar_la_enciende = _carga.visible and _carga.esta_visible()
	print("mostrar() la enciende (esperado true): %s" % _mostrar_la_enciende)

	# Primera etapa recién empezada -> 0%.
	_carga.avanzar(&"conexion", 0.0)
	_primera_etapa_en_cero = is_equal_approx(_carga._total_mostrado, 0.0)
	print("La primera etapa arranca en 0%% (esperado true, real=%.3f): %s" % [
		_carga._total_mostrado, _primera_etapa_en_cero])

	# Mitad de "nivel" (peso 0.50), con "conexion" (0.10) ya completada por
	# haber entrado a una etapa posterior -> 0.10 + 0.50*0.5 = 0.35.
	_carga.avanzar(&"nivel", 0.5)
	_fraccion_intermedia_correcta = is_equal_approx(_carga._total_mostrado, 0.35)
	print("Mitad de 'nivel' da 35%% (esperado true, real=%.3f): %s" % [
		_carga._total_mostrado, _fraccion_intermedia_correcta])

	# Saltar directo a "jugador" (0.10+0.50+0.20 = 0.80 antes de ella): las
	# etapas previas se dan por completadas aunque "mundo" nunca se reportara.
	_carga.avanzar(&"jugador", 0.0)
	_entrar_a_etapa_completa_las_previas = is_equal_approx(_carga._total_mostrado, 0.80)
	print("Entrar a 'jugador' completa las previas -> 80%% (esperado true, real=%.3f): %s" % [
		_carga._total_mostrado, _entrar_a_etapa_completa_las_previas])

	# Un avance MÁS VIEJO (etapa anterior) no debe hacer retroceder la barra.
	_carga.avanzar(&"nivel", 0.1)
	_nunca_retrocede = is_equal_approx(_carga._total_mostrado, 0.80)
	print("Un avance viejo no hace retroceder la barra (esperado true, real=%.3f): %s" % [
		_carga._total_mostrado, _nunca_retrocede])

	_carga.terminar()
	_terminar_llega_a_cien = is_equal_approx(_carga._total_mostrado, 1.0)
	print("terminar() lleva la barra al 100%% (esperado true, real=%.3f): %s" % [
		_carga._total_mostrado, _terminar_llega_a_cien])


func _informar() -> bool:
	var exito := _pesos_suman_uno and _arranca_oculta and _no_se_enciende_sola \
		and _mostrar_la_enciende and _primera_etapa_en_cero and _fraccion_intermedia_correcta \
		and _entrar_a_etapa_completa_las_previas and _nunca_retrocede \
		and _terminar_llega_a_cien and _terminar_la_apaga
	print("PRUEBA PANTALLA CARGA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
