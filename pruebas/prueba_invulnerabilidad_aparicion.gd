# =============================================================================
# Prueba de la invulnerabilidad de aparición (VidaComponente.activar_
# invulnerabilidad + Jugador.TIEMPO_INVULNERABILIDAD_APARICION).
#
# Reportado por el usuario: "a veces al iniciar la conexion al servidor y
# cargar al jugador recibe daño pero nunca se de que es, quiero que no
# reciba daño mientras carga el jugador" — el cuerpo del jugador ya existe
# y es atacable en el servidor mientras el cliente todavía carga el nivel y
# funde desde negro, así que los mobs cerca del punto de aparición pegan
# sin que se llegue a ver de dónde vino el golpe.
#
# Verifica:
#   1. Un VidaComponente recién invulnerable ignora TODO el daño.
#   2. La invulnerabilidad vence sola con el tiempo y el daño vuelve a entrar.
#   3. activar_invulnerabilidad() NUNCA acorta una ya en curso más larga.
#   4. La curación SÍ entra durante la invulnerabilidad (solo bloquea daño).
#   5. Un Jugador recién instanciado arranca invulnerable (protección de
#      aparición), y la pierde al vencer el tiempo.
#   godot --headless --path . --script res://pruebas/prueba_invulnerabilidad_aparicion.gd
# =============================================================================
extends SceneTree

var _vida
var _jugador
var _fotogramas := 0

var _ignora_dano_mientras_es_invulnerable := false
var _el_dano_vuelve_a_entrar_al_vencer := false
var _no_acorta_una_mas_larga := false
var _la_curacion_si_entra := false
var _jugador_nace_invulnerable := false
var _jugador_pierde_la_proteccion := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			# 0.25s de invulnerabilidad: corta, para que venza dentro de la prueba.
			_vida.activar_invulnerabilidad(0.25)
			# Intentar acortarla con una más chica no debe tener efecto.
			_vida.activar_invulnerabilidad(0.05)
			_no_acorta_una_mas_larga = _vida.es_invulnerable()

			_vida.quitar_vida(40.0)
			_ignora_dano_mientras_es_invulnerable = is_equal_approx(_vida.obtener_vida(), 100.0)
			print("Ignora el daño mientras es invulnerable (esperado true, vida=%.0f): %s" % [
				_vida.obtener_vida(), _ignora_dano_mientras_es_invulnerable])

			# La curación no está bloqueada: solo el daño.
			_vida.restaurar_vida(60.0)
			_vida.agregar_vida(15.0)
			_la_curacion_si_entra = is_equal_approx(_vida.obtener_vida(), 75.0)
			print("La curación sí entra durante la invulnerabilidad (esperado true, vida=%.0f): %s" % [
				_vida.obtener_vida(), _la_curacion_si_entra])
		30:
			# ~0.48s reales: los 0.25s ya vencieron (y la de 0.05s nunca la
			# acortó — si lo hubiera hecho, el paso anterior habría fallado).
			print("Sigue invulnerable tras vencer el tiempo (esperado false): %s" % _vida.es_invulnerable())
			_vida.quitar_vida(25.0)
			_el_dano_vuelve_a_entrar_al_vencer = is_equal_approx(_vida.obtener_vida(), 50.0)
			print("El daño vuelve a entrar al vencer (esperado true, 75-25=50, vida=%.0f): %s" % [
				_vida.obtener_vida(), _el_dano_vuelve_a_entrar_al_vencer])

			# Un Jugador REAL recién creado: debe nacer protegido.
			_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
			root.add_child(_jugador)
		32:
			var vida_jugador = _jugador.get_node("VidaComponente")
			_jugador_nace_invulnerable = vida_jugador.es_invulnerable()
			print("Un Jugador recién aparecido nace invulnerable (esperado true): %s" % _jugador_nace_invulnerable)
			# Acortarla a mano para no esperar los 3s reales de
			# TIEMPO_INVULNERABILIDAD_APARICION dentro de la prueba.
			vida_jugador._invulnerable_restante = 0.1
		45:
			var vida_jugador = _jugador.get_node("VidaComponente")
			_jugador_pierde_la_proteccion = not vida_jugador.es_invulnerable()
			print("El Jugador pierde la protección al vencer (esperado true): %s" % _jugador_pierde_la_proteccion)
			return _informar()
	return false


func _montar() -> void:
	var portador := Node2D.new()
	root.add_child(portador)

	_vida = VidaComponente.new()
	_vida.name = "VidaComponente"
	_vida.salud_maxima = 100.0
	# Sin regeneración: acá interesa solo lo que hace quitar_vida/invulnerable,
	# un tick de regen a mitad de prueba ensuciaría los números esperados.
	_vida.intervalo_regeneracion = 0.0
	portador.add_child(_vida)
	_vida.restaurar_vida(100.0)


func _informar() -> bool:
	var exito := _ignora_dano_mientras_es_invulnerable and _el_dano_vuelve_a_entrar_al_vencer \
		and _no_acorta_una_mas_larga and _la_curacion_si_entra \
		and _jugador_nace_invulnerable and _jugador_pierde_la_proteccion
	print("PRUEBA INVULNERABILIDAD APARICION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
