# =============================================================================
# Prueba de la Mordida Ácida de las hormigas (pedido del usuario: golpe +
# debuff -20% velocidad + daño con el tiempo, "no acumulable, si otra
# hormiga te da una mordida ácida, solo se resetea el contador").
#
# Verifica sobre un jugador real golpeado por DOS hormigas distintas:
#   1. El primer golpe hace daño real Y deja pegados EfectoVeneno +
#      EfectoLentitud (uno de cada, con el factor/daño configurados).
#   2. La lentitud se aplica de verdad al MovimientoComponente del jugador
#      (0.8 = -20%, no solo un nodo colgado sin efecto).
#   3. Un SEGUNDO golpe, de OTRA hormiga, NO agrega un segundo par de
#      efectos (sigue habiendo exactamente uno de cada) -- solo renueva la
#      duración del que ya estaba.
#   4. Pasado el tiempo de la duración ORIGINAL (pero dentro de la
#      renovada), el efecto sigue activo -- confirma que de verdad se
#      renovó y no es casualidad de que las duraciones coincidan.
#   5. Pasada también la duración renovada, los efectos se limpian solos y
#      la lentitud real se levanta.
#   godot --headless --path . --script res://pruebas/prueba_mordida_acida_no_acumulable.gd
# =============================================================================
extends SceneTree

var _jugador
var _hormiga_1
var _hormiga_2
var _mordida_1
var _mordida_2
var _vida: float
var _fotogramas := 0

var _daño_ok := false
var _un_veneno_y_una_lentitud_ok := false
var _lentitud_real_aplicada_ok := false
var _segundo_golpe_no_apila_ok := false
var _renovacion_real_ok := false
var _limpieza_al_vencer_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_vida = _jugador.get_node("VidaComponente").salud_actual
			_mordida_1.activar(Vector2.RIGHT, 1.0)
		4:
			_verificar_primer_golpe()
		240:  # 4s reales -- a mitad de la duración original (4s) pero
			# ANTES de que vuelva a chequearse tras la renovación.
			_mordida_2.activar(Vector2.LEFT, 1.0)  # hormiga_2 está a la derecha del jugador.
		242:
			_verificar_segundo_golpe()
		420:  # 7s desde el inicio -- pasó la duración ORIGINAL (4s) pero
			# no la renovada (renovada en t=4s + 4s = vence en t=8s).
			_verificar_renovacion()
		540:  # 9s desde el inicio -- ya pasó la duración renovada (vence t=8s).
			return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador.name = "1"
	raiz.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO
	_jugador.get_node("VidaComponente").cancelar_invulnerabilidad()
	_jugador.get_node("VidaComponente").salud_maxima = 1000.0
	_jugador.get_node("VidaComponente").salud_actual = 1000.0

	_hormiga_1 = (load("res://escenas/enemigos/EnemigoHormigaObrera.tscn") as PackedScene).instantiate()
	raiz.add_child(_hormiga_1)
	_hormiga_1.global_position = Vector2(-30, 0)
	_hormiga_1.get_node("ArbolComportamiento").process_mode = Node.PROCESS_MODE_DISABLED
	_mordida_1 = _hormiga_1.get_node("Habilidades/HabilidadMordidaAcida")

	_hormiga_2 = (load("res://escenas/enemigos/EnemigoHormigaSoldado.tscn") as PackedScene).instantiate()
	raiz.add_child(_hormiga_2)
	_hormiga_2.global_position = Vector2(30, 0)
	_hormiga_2.get_node("ArbolComportamiento").process_mode = Node.PROCESS_MODE_DISABLED
	_mordida_2 = _hormiga_2.get_node("Habilidades/HabilidadMordidaAcida")


func _venenos() -> Array:
	return _jugador.get_children().filter(func(h): return h is EfectoVeneno)


func _lentitudes() -> Array:
	return _jugador.get_children().filter(func(h): return h is EfectoLentitud)


func _verificar_primer_golpe() -> void:
	var vida_ahora: float = _jugador.get_node("VidaComponente").salud_actual
	_daño_ok = vida_ahora < _vida
	print("La Mordida Ácida hace daño real (esperado true, %.1f -> %.1f): %s" % [_vida, vida_ahora, _daño_ok])

	var venenos := _venenos()
	var lentitudes := _lentitudes()
	_un_veneno_y_una_lentitud_ok = venenos.size() == 1 and lentitudes.size() == 1 \
		and venenos[0].id_debuff == "mordida_acida" and lentitudes[0].id_debuff == "mordida_acida"
	print("Deja pegado exactamente 1 EfectoVeneno + 1 EfectoLentitud (esperado true): %s" % _un_veneno_y_una_lentitud_ok)

	var movimiento = _jugador.get_node("MovimientoComponente")
	_lentitud_real_aplicada_ok = movimiento._factores_lentitud.has(0.8)
	print("La lentitud -20%% se aplica de verdad al movimiento (esperado true): %s" % _lentitud_real_aplicada_ok)


func _verificar_segundo_golpe() -> void:
	var venenos := _venenos()
	var lentitudes := _lentitudes()
	_segundo_golpe_no_apila_ok = venenos.size() == 1 and lentitudes.size() == 1
	print("El golpe de la SEGUNDA hormiga no apila, sigue habiendo 1 de cada (esperado true, venenos=%d lentitudes=%d): %s" % [
		venenos.size(), lentitudes.size(), _segundo_golpe_no_apila_ok])


func _verificar_renovacion() -> void:
	var venenos := _venenos()
	var lentitudes := _lentitudes()
	_renovacion_real_ok = venenos.size() == 1 and lentitudes.size() == 1
	print("A los 7s (pasada la duración ORIGINAL de 4s) el debuff sigue activo -- se renovó de verdad (esperado true): %s" % _renovacion_real_ok)


func _informar() -> bool:
	var venenos := _venenos()
	var lentitudes := _lentitudes()
	var movimiento = _jugador.get_node("MovimientoComponente")
	_limpieza_al_vencer_ok = venenos.is_empty() and lentitudes.is_empty() \
		and not movimiento._factores_lentitud.has(0.8)
	print("A los 9s (pasada la duración renovada) se limpia solo y la lentitud real se levanta (esperado true): %s" % _limpieza_al_vencer_ok)

	var exito := _daño_ok and _un_veneno_y_una_lentitud_ok and _lentitud_real_aplicada_ok \
		and _segundo_golpe_no_apila_ok and _renovacion_real_ok and _limpieza_al_vencer_ok
	print("PRUEBA MORDIDA ACIDA NO ACUMULABLE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
