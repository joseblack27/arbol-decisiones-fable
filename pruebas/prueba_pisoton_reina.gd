# =============================================================================
# Prueba de "Pisotón Sísmico" (ver HabilidadPisotonReina.gd), pedida por el
# usuario para que "haya que tener cuidado al combatir contra ella": golpe de
# área centrado en la propia Reina, telegrafiado (el radio real queda
# visible mientras se prepara) antes de golpear fuerte a quien siga adentro.
#   1. Al activarse, entra en preparación (esta_preparando()==true) --
#      chequeado en el MISMO instante, sin dejar pasar ningún fotograma: el
#      primer delta real tras armar la escena puede ser bastante más grande
#      de lo que dura un fotograma típico (instanciar Reina+jugadores no es
#      gratis), así que esperar UN fotograma para chequear "sigue
#      preparando" es fresco -- podría haber terminado ya.
#   2. Con margen de sobra (30 fotogramas), ya golpeó: daña a un jugador
#      DENTRO del radio.
#   3. Un jugador FUERA del radio no recibe nada.
#   godot --headless --path . --script res://pruebas/prueba_pisoton_reina.gd
# =============================================================================
extends SceneTree

const DURACION_PREP_PRUEBA := 0.3

var _fotogramas := 0
var _reina
var _pisoton
var _jugador_cerca
var _jugador_lejos

var _vida_cerca_antes := 0.0
var _vida_lejos_antes := 0.0

var _entro_en_preparacion_ok := false
var _dano_al_cercano_ok := false
var _sin_dano_al_lejano_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_activar_y_verificar_preparacion()
		30:  # Margen de sobra sobre DURACION_PREP_PRUEBA: ya golpeó.
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

	_pisoton = _reina.get_node("Habilidades/HabilidadPisotonReina")
	_pisoton.duracion_preparacion = DURACION_PREP_PRUEBA

	_jugador_cerca = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador_cerca.name = "1"
	contenedor.add_child(_jugador_cerca)
	_jugador_cerca.global_position = Vector2(60, 0)  # Dentro de radio=110.
	# Todo Jugador nace con 3s de invulnerabilidad de aparición (ver
	# TIEMPO_INVULNERABILIDAD_APARICION en Jugador.gd) -- sin quitarla acá,
	# el golpe de la prueba no le haría nada. Mismo criterio ya usado en
	# prueba_arana_reina_esqueleto.gd.
	_jugador_cerca.get_node("VidaComponente")._invulnerable_restante = 0.0

	_jugador_lejos = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador_lejos.name = "2"
	contenedor.add_child(_jugador_lejos)
	_jugador_lejos.global_position = Vector2(400, 0)  # Fuera de radio=110.
	_jugador_lejos.get_node("VidaComponente")._invulnerable_restante = 0.0

	_vida_cerca_antes = _vida(_jugador_cerca)
	_vida_lejos_antes = _vida(_jugador_lejos)


func _vida(entidad: Node) -> float:
	var v := entidad.get_node_or_null("VidaComponente") as VidaComponente
	return v.obtener_vida() if v else 0.0


func _activar_y_verificar_preparacion() -> void:
	_pisoton.activar(Vector2.ZERO, 1.0)
	# Chequeo en el MISMO instante, sin dejar correr ningún fotograma más --
	# ver el comentario de arriba.
	_entro_en_preparacion_ok = _pisoton.esta_preparando()
	print("Al activarse entra en preparación (esperado true): %s" % _entro_en_preparacion_ok)


func _informar() -> bool:
	var dano_cerca := _vida_cerca_antes - _vida(_jugador_cerca)
	_dano_al_cercano_ok = dano_cerca > 0.0
	print("El jugador DENTRO del radio recibe daño (esperado >0, perdió %.1f): %s" % [
		dano_cerca, _dano_al_cercano_ok])

	var dano_lejos := _vida_lejos_antes - _vida(_jugador_lejos)
	_sin_dano_al_lejano_ok = is_equal_approx(dano_lejos, 0.0)
	print("El jugador FUERA del radio no recibe nada (esperado 0.0, %.1f): %s" % [
		dano_lejos, _sin_dano_al_lejano_ok])

	var exito := _entro_en_preparacion_ok and _dano_al_cercano_ok and _sin_dano_al_lejano_ok
	print("PRUEBA PISOTON REINA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
