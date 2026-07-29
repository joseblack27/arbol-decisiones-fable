# =============================================================================
# Prueba de HabilidadCuracion (HoT — a propósito distinta de una poción
# instantánea): al activarse, restaura cantidad_curacion repartida en ticks
# de 1 segundo a lo largo de duracion_curacion — nada de golpe, y termina
# sola sin pasarse del total.
#   godot --headless --path . --script res://pruebas/prueba_curacion.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _entidad: Node2D
var _vida: VidaComponente
var _habilidad: Node
var _vida_justo_tras_activar := 0.0
var _no_fue_de_golpe := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_vida.quitar_vida(50.0)  # vida: 100 -> 50
		6:
			print("Tras el golpe (esperado 50): %.0f" % _vida.obtener_vida())
			_habilidad.activar()
			_vida_justo_tras_activar = _vida.obtener_vida()
		# Un tick y medio (~90 fotogramas) después de activar: debería haber
		# subido un solo tick (~60, no 80 de golpe) pero ya haber arrancado.
		90:
			var vida_tras_un_tick := _vida.obtener_vida()
			print("Justo al activar, sin cambio todavía (esperado 50): %.0f" % _vida_justo_tras_activar)
			print("Tras ~1 tick (esperado ~60, NO 80 de golpe): %.0f" % vida_tras_un_tick)
			_no_fue_de_golpe = vida_tras_un_tick < 75.0 and vida_tras_un_tick > 55.0
			print("No curó de golpe: %s" % _no_fue_de_golpe)
		# Duración total 3s (180 fotogramas desde la activación en el 6) +
		# margen: ya se repartieron los 3 ticks completos.
		250:
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_entidad = Node2D.new()
	escena.add_child(_entidad)

	_vida = VidaComponente.new()
	_vida.name = "VidaComponente"
	_vida.salud_maxima = 100.0
	_entidad.add_child(_vida)
	_vida.restaurar_vida(100.0)

	var contenedor := Marker2D.new()
	contenedor.name = "Habilidades"
	_entidad.add_child(contenedor)

	var guion := load("res://escenas/habilidades/curacion/HabilidadCuracion.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.set("cantidad_curacion", 30.0)
	_habilidad.set("duracion_curacion", 3.0)
	_habilidad.set("duracion_recarga", 0.0)
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _entidad


func _informar() -> bool:
	var vida_final := _vida.obtener_vida()
	print("Tras terminar el HoT (esperado 80 = 50 + 30 repartidos): %.0f" % vida_final)
	var instantaneo_ok := is_equal_approx(_vida_justo_tras_activar, 50.0)
	var final_ok := is_equal_approx(vida_final, 80.0)
	var exito := instantaneo_ok and final_ok and _no_fue_de_golpe
	print("PRUEBA CURACION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
