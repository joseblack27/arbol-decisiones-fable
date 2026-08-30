# =============================================================================
# Regresión: "al hacer la embestida se queda pegado al final" — y de paso,
# el bug de "siempre mirando a la izquierda en reposo": las dos cosas eran
# EL MISMO problema. HabilidadArremetidaGuardian hereda las 3 señales de
# HabilidadCarga (preparacion_iniciada/carga_iniciada/carga_terminada), pero
# HabilidadCarga.gd no toca memoria["ataque_en_curso"] por su cuenta — eso
# lo hace el MOB dueño, conectado a esas señales (ver EnemigoLobo.gd). Sin
# conectarlas (el bug real), "ataque_en_curso" se quedaba en true para
# siempre tras la primera embestida — y AccionAtacar._on_ejecutar() corta
# ANTES de actualizar direccion_mirada mientras esa clave esté en true (ver
# el comentario de esa función: "la mirada queda congelada en la dirección
# con la que arrancó el ataque"), así que el jefe quedaba congelado
# mirando para siempre hacia donde apuntaba esa última embestida — la IA
# entera se trababa (AccionAtacar._on_ejecutar también corta temprano con
# ataque_en_curso=true, nunca vuelve a intentar nada) Y la mirada se
# quedaba fija, ambos reportes del usuario con la misma causa.
#
# Esta prueba dispara la arremetida REAL (pose+dash real, no llamado
# directo) y confirma que, tras terminar, memoria["ataque_en_curso"] vuelve
# a false Y direccion_mirada vuelve a actualizarse hacia el jugador.
#   godot --headless --path . --script res://pruebas/prueba_guardian_arremetida_no_se_traba.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _jugador
var _memoria

var _ataque_en_curso_resetea_ok := false
var _mirada_vuelve_a_actualizarse_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			var arremetida = _jefe.get_node("Habilidades/HabilidadArremetidaGuardian")
			arremetida.activar(Vector2.RIGHT, 1.0)
		400:
			# duracion_preparacion=0.6s + tiempo de dash real (350px a
			# velocidad*multiplicador) + margen generoso, mismo criterio que
			# el resto de las pruebas de fase con timers reales.
			_probar_ataque_en_curso_resetea()
			_mover_jugador_y_probar_mirada()
		430:
			# El reapuntado real necesita un tick más del árbol (0.1s) —
			# margen generoso para no depender de la cadencia exacta.
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
	_jugador.global_position = Vector2(500, 0)
	var vida_jugador = _jugador.get_node("VidaComponente")
	vida_jugador.salud_maxima = 100000.0
	vida_jugador.salud_actual = 100000.0
	vida_jugador.cancelar_invulnerabilidad()

	_memoria = _jefe.get_node("ArbolComportamiento/MemoriaBT")
	_memoria.establecer("objetivo", _jugador)
	# El árbol real reintentaría constantemente y podría interferir con el
	# estado que se está probando a mano — se apaga para conducir la
	# arremetida de forma controlada, mismo criterio que otras pruebas que
	# manipulan un mob sin dejar que su propia IA decida.
	_jefe.get_node("ArbolComportamiento").activo = false


func _probar_ataque_en_curso_resetea() -> void:
	var valor = _memoria.obtener("ataque_en_curso", true)
	_ataque_en_curso_resetea_ok = valor == false
	print("ataque_en_curso vuelve a false tras la embestida (esperado true): %s" % \
		_ataque_en_curso_resetea_ok)


func _mover_jugador_y_probar_mirada() -> void:
	# Reactivar la IA real (AccionAtacar) y mover al jugador a un costado
	# distinto — si direccion_mirada sigue viva, debería reapuntar hacia
	# la nueva posición en el próximo tick real del árbol (0.1s).
	_jefe.get_node("ArbolComportamiento").activo = true
	_jugador.global_position = Vector2(0, -300)
	_jefe.direccion_mirada = Vector2.RIGHT  # valor "viejo" a propósito.


func _informar() -> bool:
	var mirada: Vector2 = _jefe.direccion_mirada
	_mirada_vuelve_a_actualizarse_ok = mirada != Vector2.RIGHT
	print("direccion_mirada vuelve a actualizarse tras la embestida (esperado true, mirada=%s): %s" % [
		mirada, _mirada_vuelve_a_actualizarse_ok])

	var exito := _ataque_en_curso_resetea_ok and _mirada_vuelve_a_actualizarse_ok
	print("PRUEBA GUARDIAN ARREMETIDA NO SE TRABA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
