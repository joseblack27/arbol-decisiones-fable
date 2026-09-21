# =============================================================================
# Pedido explícito del usuario (20 sep 2026), probando el Hormiguero de
# punta a punta: "quiero que cuando la reina detecte un jugador, el area
# de detección se doble, para que sea un poco mas dificil perder al
# jugador" -- la Reina perdía el agro seguido con el radio normal.
#
# Confirma:
#   1. Arranca con el radio base (~200, ver CircleShape2D_itdr7 en
#      EnemigoReinaHormigas.tscn).
#   2. Un jugador dentro del radio base la hace detectarlo Y duplica el
#      radio de su VisionComponente.
#   3. Con el radio YA duplicado, el jugador puede alejarse más allá del
#      radio ORIGINAL (pero dentro del doble) sin que la Reina lo pierda
#      -- el punto central del pedido.
#   4. Recién más allá del radio DOBLE lo pierde de verdad, y ahí el
#      radio vuelve a su valor base (no se queda duplicado para siempre).
#   godot --headless --path . --script res://pruebas/prueba_reina_hormigas_radio_deteccion_doble.gd
# =============================================================================
extends SceneTree

var _f := 0
var _reina
var _jugador
var _radio_base := 0.0

var _arranca_con_radio_base_ok := false
var _detecta_y_duplica_radio_ok := false
var _sigue_detectando_mas_alla_del_radio_original_ok := false
var _pierde_mas_alla_del_radio_doble_y_revierte_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		3:
			_verificar_radio_base()
			_jugador.global_position = Vector2(100, 0)  # Bien dentro del radio base (~200).
		# Margen generoso (no 1-2 fotogramas): el área de detección real
		# necesita que el servidor de física procese de verdad el
		# solapamiento -- visto en otras pruebas de esta sesión, la
		# cantidad de fotogramas de este bucle no equivale 1 a 1 con pasos
		# físicos reales en este entorno headless.
		15:
			_verificar_detecta_y_duplica()
			_jugador.global_position = Vector2(300, 0)  # Más allá del radio original, dentro del doble (~400).
		27:
			_verificar_sigue_detectando()
			_jugador.global_position = Vector2(500, 0)  # Más allá también del radio doble.
		39:
			_verificar_pierde_y_revierte()
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_reina = (load("res://escenas/enemigos/EnemigoReinaHormigas.tscn") as PackedScene).instantiate()
	escena.add_child(_reina)
	_reina.global_position = Vector2.ZERO
	# Sin BT/habilidades reales de por medio -- solo interesa VisionComponente.
	_reina.get_node("ArbolComportamiento").process_mode = Node.PROCESS_MODE_DISABLED

	# Jugador arranca bien lejos, fuera de cualquiera de los dos radios.
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	escena.add_child(_jugador)
	_jugador.global_position = Vector2(1000, 0)
	# Jugador.gd activa 3s de invulnerabilidad de aparición en TODO _ready()
	# (ver TIEMPO_INVULNERABILIDAD_APARICION) -- sin cortarla, VisionComponente
	# nunca lo registra como objetivo válido (ver _es_objetivo_valido),
	# sin importar cuánto se acerque ni cuántos fotogramas se esperen.
	_jugador.componente_vida.cancelar_invulnerabilidad()


func _verificar_radio_base() -> void:
	_radio_base = _reina._radio_deteccion_base
	var forma: CircleShape2D = _reina._forma_deteccion()
	_arranca_con_radio_base_ok = _radio_base > 0.0 and is_equal_approx(forma.radius, _radio_base)
	print("Arranca con el radio de detección base (esperado true, radio=%.1f): %s" % [
		_radio_base, _arranca_con_radio_base_ok])


func _verificar_detecta_y_duplica() -> void:
	var detecta: bool = _reina.memoria.obtener("jugador_detectado", false)
	var forma: CircleShape2D = _reina._forma_deteccion()
	_detecta_y_duplica_radio_ok = detecta and is_equal_approx(forma.radius, _radio_base * 2.0)
	print("Detecta al jugador y duplica su radio (esperado true, radio=%.1f, esperado %.1f): %s" % [
		forma.radius, _radio_base * 2.0, _detecta_y_duplica_radio_ok])


func _verificar_sigue_detectando() -> void:
	var detecta: bool = _reina.memoria.obtener("jugador_detectado", false)
	_sigue_detectando_mas_alla_del_radio_original_ok = detecta
	print("A 300px (más allá del radio original ~%.0f, dentro del doble) sigue detectando (esperado true): %s" % [
		_radio_base, _sigue_detectando_mas_alla_del_radio_original_ok])


func _verificar_pierde_y_revierte() -> void:
	var detecta: bool = _reina.memoria.obtener("jugador_detectado", false)
	var forma: CircleShape2D = _reina._forma_deteccion()
	_pierde_mas_alla_del_radio_doble_y_revierte_ok = not detecta and is_equal_approx(forma.radius, _radio_base)
	print("A 500px (más allá del radio doble) lo pierde y el radio vuelve al base (esperado true, radio=%.1f): %s" % [
		forma.radius, _pierde_mas_alla_del_radio_doble_y_revierte_ok])


func _informar() -> bool:
	var exito := _arranca_con_radio_base_ok and _detecta_y_duplica_radio_ok \
		and _sigue_detectando_mas_alla_del_radio_original_ok and _pierde_mas_alla_del_radio_doble_y_revierte_ok
	print("PRUEBA REINA HORMIGAS RADIO DETECCION DOBLE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
