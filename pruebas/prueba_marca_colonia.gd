# =============================================================================
# Prueba de "Marca de la Colonia" (ver HabilidadMarcaColonia.gd), pedida por
# el usuario: mecánica que agrega dificultad sin desbalancear solo vs grupo —
# marca a un jugador AL AZAR entre los cercanos y, al vencer la cuenta
# regresiva, detona dañando al marcado Y a cualquiera parado muy cerca.
#   1. Al activarse (chequeado en el MISMO instante, sin dejar correr ningún
#      fotograma -- ver prueba_pisoton_reina.gd para el porqué), EXACTAMENTE
#      uno de los dos candidatos (parados juntos) queda marcado
#      (MarcaComponente + buff "marca_colonia").
#   2. Con margen de sobra, al vencer la marca LOS DOS (el marcado y su
#      vecino pegado) pierden vida -- no importa cuál haya sido el elegido.
#   3. Un tercer jugador lejos (fuera de radio_busqueda, y lejos del par)
#      no pierde nada.
#   godot --headless --path . --script res://pruebas/prueba_marca_colonia.gd
# =============================================================================
extends SceneTree

const DURACION_MARCA_PRUEBA := 0.3

var _fotogramas := 0
var _reina
var _marca
var _par_a
var _par_b
var _lejano

var _vida_a_antes := 0.0
var _vida_b_antes := 0.0
var _vida_lejano_antes := 0.0

var _marco_exactamente_uno_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_activar_y_verificar_marca()
		30:  # Margen de sobra sobre DURACION_MARCA_PRUEBA: ya detonó.
			return _informar()
	return false


func _montar() -> void:
	var contenedor := Node2D.new()
	contenedor.name = "Enemigos"
	root.add_child(contenedor)
	current_scene = contenedor

	_reina = (load("res://escenas/enemigos/EnemigoReinaHormigas.tscn") as PackedScene).instantiate()
	contenedor.add_child(_reina)
	_reina.global_position = Vector2.ZERO
	_reina.get_node("ArbolComportamiento").process_mode = Node.PROCESS_MODE_DISABLED

	_marca = _reina.get_node("Habilidades/HabilidadMarcaColonia")
	_marca.duracion_marca = DURACION_MARCA_PRUEBA
	_marca.radio_busqueda = 500.0
	_marca.radio_detonacion = 80.0

	# El par: candidatos válidos (dentro de radio_busqueda), pegados entre
	# sí (dentro de radio_detonacion el uno del otro) -- cualquiera de los
	# dos que salga marcado, el otro cae dentro de la explosión igual.
	# Todo Jugador nace con 3s de invulnerabilidad de aparición (ver
	# TIEMPO_INVULNERABILIDAD_APARICION en Jugador.gd) -- sin quitarla acá,
	# ningún golpe de la prueba haría nada. Mismo criterio ya usado en
	# prueba_arana_reina_esqueleto.gd.
	_par_a = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_par_a.name = "1"
	contenedor.add_child(_par_a)
	_par_a.global_position = Vector2(200, 0)
	_par_a.get_node("VidaComponente")._invulnerable_restante = 0.0

	_par_b = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_par_b.name = "2"
	contenedor.add_child(_par_b)
	_par_b.global_position = Vector2(230, 0)
	_par_b.get_node("VidaComponente")._invulnerable_restante = 0.0

	_lejano = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_lejano.name = "3"
	contenedor.add_child(_lejano)
	_lejano.global_position = Vector2(2000, 0)  # Fuera de radio_busqueda.
	_lejano.get_node("VidaComponente")._invulnerable_restante = 0.0

	_vida_a_antes = _vida(_par_a)
	_vida_b_antes = _vida(_par_b)
	_vida_lejano_antes = _vida(_lejano)


func _vida(entidad: Node) -> float:
	var v := entidad.get_node_or_null("VidaComponente") as VidaComponente
	return v.obtener_vida() if v else 0.0


func _tiene_marca(jugador: Node) -> bool:
	var m := jugador.get_node_or_null("MarcaComponente")
	return m != null and m.esta_activa()


func _activar_y_verificar_marca() -> void:
	_marca.activar(Vector2.ZERO, 1.0)
	var marcados := int(_tiene_marca(_par_a)) + int(_tiene_marca(_par_b))
	_marco_exactamente_uno_ok = marcados == 1
	print("Marca a EXACTAMENTE uno de los dos candidatos cercanos (esperado true, marcados=%d): %s" % [
		marcados, _marco_exactamente_uno_ok])


func _informar() -> bool:
	var dano_a := _vida_a_antes - _vida(_par_a)
	var dano_b := _vida_b_antes - _vida(_par_b)
	var ambos_dañados_ok := dano_a > 0.0 and dano_b > 0.0
	print("Al detonar, TANTO el marcado como su vecino pegado pierden vida (esperado true, %.1f / %.1f): %s" % [
		dano_a, dano_b, ambos_dañados_ok])

	var dano_lejano := _vida_lejano_antes - _vida(_lejano)
	var lejano_ileso_ok := is_equal_approx(dano_lejano, 0.0)
	print("El jugador lejos de todo no pierde nada (esperado 0.0, %.1f): %s" % [
		dano_lejano, lejano_ileso_ok])

	var exito := _marco_exactamente_uno_ok and ambos_dañados_ok and lejano_ileso_ok
	print("PRUEBA MARCA DE LA COLONIA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
