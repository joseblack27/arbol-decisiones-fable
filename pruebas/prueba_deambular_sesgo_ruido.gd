# =============================================================================
# Prueba: AccionDeambular sesga su próximo destino hacia un aviso de "ruido"
# (ver Enemigo._priorizar_atacante) sin dejar de respetar su radio normal de
# deambulación.
#
# Pedido del usuario, tras aclarar cómo quería la reacción a un golpe desde
# fuera de la visión: "que el mob deambule en tu dirección, sin detectarte
# como objetivo, acotado a su distancia máxima de deambular" — ni un golpe
# gratis (comportamiento viejo) ni una persecución a ciegas (lo que se había
# implementado primero, y el usuario corrigió).
#
# Verifica sobre un Lobo real:
#   1. Con "ruido_posicion" puesto lejos hacia el ESTE, el destino elegido
#      queda dentro del cono de dispersión alrededor de esa dirección — no
#      al azar.
#   2. Esa distancia sigue acotada al radio_deambulacion normal (30-100px en
#      esta prueba), NUNCA más lejos, aunque el ruido viniera de mucho más
#      lejos (1000px).
#   3. "ruido_posicion" se consume: desaparece de memoria tras usarse.
#   4. Sin ruido (ya consumido), el siguiente destino vuelve a ser libre —
#      solo se verifica que sigue dentro del radio (el ángulo es al azar).
#   5. Un aviso de ruido INTERRUMPE un paseo/pausa ya en curso — sin esto,
#      el mob podía tardar varios segundos en reaccionar (hasta terminar
#      solo el destino viejo), y la reacción a un golpe se sentía como si
#      no pasara nada (reportado por el usuario tras probarlo en el juego).
#   godot --headless --path . --script res://pruebas/prueba_deambular_sesgo_ruido.gd
# =============================================================================
extends SceneTree

const RADIO := 100.0
const DISPERSION_GRADOS := 35.0

var _fotogramas := 0
var _mob: Node
var _deambular


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_mob = (load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	escena.add_child(_mob)
	_mob.global_position = Vector2.ZERO
	# Sin IA propia: se ejercita AccionDeambular a mano, tick por tick, para
	# no depender de que el Selector la elija en el momento justo.
	(_mob.get_node("ArbolComportamiento")).activo = false

	_deambular = _mob.get_node("ArbolComportamiento/Selector/Deambular")
	_deambular.radio_deambulacion = RADIO
	_deambular.dispersion_ruido_grados = DISPERSION_GRADOS

	_mob.memoria.establecer("posicion_origen", Vector2.ZERO)


func _informar() -> bool:
	# --- Caso 1: con ruido, bien lejos hacia el ESTE ---
	_mob.memoria.establecer("ruido_posicion", Vector2(1000, 0))
	_deambular.call("_elegir_destino")
	var destino_1: Vector2 = _deambular.get("_destino")

	var angulo_grados := rad_to_deg(absf(destino_1.angle()))
	var dentro_del_cono := angulo_grados <= DISPERSION_GRADOS + 0.01
	print("Destino sesgado hacia el ruido: %s (ángulo %.1f°, esperado <= %.0f°)" % [
		destino_1, angulo_grados, DISPERSION_GRADOS])

	var distancia_1 := destino_1.length()
	var dentro_del_radio := distancia_1 >= RADIO * 0.3 - 0.01 and distancia_1 <= RADIO + 0.01
	print("Distancia acotada al radio normal (esperado entre %.0f y %.0f): %.1f" % [
		RADIO * 0.3, RADIO, distancia_1])

	var ruido_consumido: bool = not _mob.memoria.existe("ruido_posicion")
	print("El ruido se consume tras usarse (esperado true): %s" % ruido_consumido)

	# --- Caso 2: sin ruido (ya consumido), el ángulo es libre pero la
	# distancia sigue acotada igual ---
	_deambular.call("_elegir_destino")
	var destino_2: Vector2 = _deambular.get("_destino")
	var distancia_2 := destino_2.length()
	var sigue_acotado_sin_ruido := distancia_2 >= RADIO * 0.3 - 0.01 and distancia_2 <= RADIO + 0.01
	print("Sin ruido, la distancia sigue acotada igual (esperado true): %s (%.1f)" % [
		sigue_acotado_sin_ruido, distancia_2])

	# --- Caso 5: un aviso de ruido interrumpe un paseo/pausa YA en curso —
	# no hace falta esperar a que termine solo (ver AccionDeambular._on_ejecutar,
	# ver también el destino viejo apuntando al NORTE, sin relación) ---
	_deambular.set("_tiene_destino", true)
	_deambular.set("_destino", Vector2(0, -1000))
	_deambular.set("_fin_espera", 999999.0)
	_mob.memoria.establecer("ruido_posicion", Vector2(1000, 0))  # ESTE
	_deambular.call("ejecutar")
	var destino_3: Vector2 = _deambular.get("_destino")
	var angulo_3 := rad_to_deg(absf(destino_3.angle()))
	var interrumpe_paseo_ok := angulo_3 <= DISPERSION_GRADOS + 0.01
	print("Un golpe interrumpe el paseo/pausa en curso (esperado true): %s (ángulo %.1f°, destino %s)" % [
		interrumpe_paseo_ok, angulo_3, destino_3])

	var exito: bool = dentro_del_cono and dentro_del_radio and ruido_consumido \
		and sigue_acotado_sin_ruido and interrumpe_paseo_ok
	print("PRUEBA DEAMBULAR SESGO RUIDO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
