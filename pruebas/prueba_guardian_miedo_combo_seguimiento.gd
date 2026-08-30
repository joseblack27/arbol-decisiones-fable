# =============================================================================
# Regresión: pedido del usuario — "un combo de habilidades que congenien
# unas con otras". Miedo (empuja + aturde 0.5s) ahora encadena un Combo
# real ~0.3s después, directo sobre el objetivo que la IA persigue de
# verdad — mientras el objetivo sigue sin poder moverse (aturdido), así
# el segundo golpe no depende de la suerte.
#
# Activa Miedo real sobre un jugador real (con Corte inactivo, para medir
# solo el combo) y confirma:
#   1. El jugador queda aturdido (EfectoAturdir) apenas se activa Miedo.
#   2. Unos fotogramas después, Combo también le pega de verdad (vida
#      baja una SEGUNDA vez, más allá del golpe inicial de Miedo si lo
#      hubiera — acá Miedo no hace daño, así que cualquier baja de vida
#      viene del Combo encadenado).
#   godot --headless --path . --script res://pruebas/prueba_guardian_miedo_combo_seguimiento.gd
# =============================================================================
extends SceneTree

var _jefe
var _jugador
var _vida_jugador
var _habilidad_miedo
var _fotogramas := 0
var _vio_aturdido := false
var _vida_antes_combo := 0.0
var _recibio_dano_del_combo := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
			_habilidad_miedo.activar(Vector2.ZERO, 1.0)
		5:
			# Aturdir se aplica en el mismo fotograma que Miedo — confirmar
			# que el efecto quedó pegado.
			var tiene_aturdir := false
			for hijo in _jugador.get_children():
				if hijo.get_script() == load("res://escenas/efectos/EfectoAturdir.gd"):
					tiene_aturdir = true
			_vio_aturdido = tiene_aturdir
			_vida_antes_combo = _vida_jugador.salud_actual
		30:
			# ~0.3s tras Miedo (18 fotogramas): el combo ya debería haber
			# arrancado (timer de 0.3s = 18 fotogramas justo, se da margen).
			return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	var escena_jefe := load("res://escenas/enemigos/EnemigoGuardianQuebrado.tscn")
	_jefe = escena_jefe.instantiate()
	raiz.add_child(_jefe)
	_jefe.global_position = Vector2.ZERO

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena_jugador.instantiate()
	_jugador.name = "1"
	raiz.add_child(_jugador)
	_jugador.global_position = Vector2(60, 0)  # dentro del radio de Miedo (100) y de Combo (~116)
	_vida_jugador = _jugador.get_node("VidaComponente")
	_vida_jugador.salud_maxima = 100000.0
	_vida_jugador.salud_actual = 100000.0
	_vida_jugador.cancelar_invulnerabilidad()

	_jefe.memoria.establecer("objetivo", _jugador)
	_habilidad_miedo = _jefe.get_node("Habilidades/HabilidadMiedoGuardian")


func _informar() -> bool:
	_recibio_dano_del_combo = _vida_jugador.salud_actual < _vida_antes_combo
	print("El jugador queda aturdido al activarse Miedo (esperado true): %s" % _vio_aturdido)
	print("El Combo encadenado le baja la vida mientras sigue aturdido (esperado true): %s" % _recibio_dano_del_combo)
	var exito := _vio_aturdido and _recibio_dano_del_combo
	print("PRUEBA GUARDIAN MIEDO COMBO SEGUIMIENTO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
