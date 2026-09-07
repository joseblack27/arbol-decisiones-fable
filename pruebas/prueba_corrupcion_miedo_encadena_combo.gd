# =============================================================================
# Regresión: HabilidadMiedoGuardian._programar_combo_de_seguimiento() busca un
# hermano llamado LITERALMENTE "Habilidades/HabilidadComboGuardian" — el
# Heraldo de la Corrupción no lo tenía (a diferencia del Guardián Quebrado,
# de donde Miedo se reusó tal cual), así que el "Grito de Terror" nunca
# encadenaba el combo de remate. Se agregó ese nodo (reskin de
# HabilidadComboGuardian, deja_charco=true) en
# escenas/enemigos/EnemigoHeraldoCorrupcion.tscn.
#
# Miedo en sí no hace daño directo (solo empuje + aturdimiento) — cualquier
# pérdida de vida del jugador DESPUÉS de activar Miedo, con la IA apagada y
# sin llamar ninguna otra habilidad, solo puede venir del combo encadenado.
#   godot --headless --path . --script res://pruebas/prueba_corrupcion_miedo_encadena_combo.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _jugador
var _vida_jugador
var _vida_antes_miedo := 0.0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_vida_antes_miedo = _vida_jugador.salud_actual
			var miedo = _jefe.get_node("Habilidades/HabilidadMiedo")
			miedo.activar(Vector2.RIGHT, 1.0)
		120:
			return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	_jefe = (load("res://escenas/enemigos/EnemigoHeraldoCorrupcion.tscn") as PackedScene).instantiate()
	raiz.add_child(_jefe)
	_jefe.global_position = Vector2.ZERO
	_jefe.get_node("ArbolComportamiento").process_mode = Node.PROCESS_MODE_DISABLED

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	_jugador.name = "1"
	raiz.add_child(_jugador)
	_jugador.global_position = Vector2(60, 0)
	_vida_jugador = _jugador.get_node("VidaComponente")
	_vida_jugador.salud_maxima = 100000.0
	_vida_jugador.salud_actual = 100000.0
	_vida_jugador.cancelar_invulnerabilidad()

	var atributos = _jugador.get_node_or_null("AtributosComponente")
	if atributos and atributos.base:
		atributos.base.defensa = 0.0
		atributos.base.resistencia_fisica = 0.0
		atributos.base.regeneracion_vida = 0.0
		atributos.base.regeneracion_vida_plana = 0.0

	var memoria = _jefe.get_node("ArbolComportamiento/MemoriaBT")
	memoria.establecer("objetivo", _jugador)


func _informar() -> bool:
	var perdida: float = _vida_antes_miedo - _vida_jugador.salud_actual
	# Miedo no hace daño directo — más de un golpe de Combo (dano_por_golpe
	# default 14.0) conectando alcanza para probar que encadenó de verdad,
	# mismo criterio que prueba_guardian_combo.gd.
	var exito := perdida > 14.0
	print("Combo encadenado tras Miedo hace daño real (esperado > 14.0 de pérdida total): %.1f" % perdida)
	print("PRUEBA CORRUPCION MIEDO ENCADENA COMBO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
