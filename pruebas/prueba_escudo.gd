# =============================================================================
# Prueba de HabilidadEscudo/EscudoComponente:
#   1. Sin escudo activo: quitar_vida() aplica el daño normal.
#   2. Con escudo al 100% (bloqueo total): el daño no pasa nada de vida.
#   3. Con escudo al 50%: pasa la mitad.
#   4. Al vencerse el tiempo, vuelve a aplicarse el daño normal.
#   godot --headless --path . --script res://pruebas/prueba_escudo.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _entidad: Node2D
var _vida: VidaComponente
var _habilidad: Node


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			# Sin escudo: 20 de daño debería pasar entero.
			_vida.quitar_vida(20.0)
		6:
			print("Sin escudo (esperado 80): %.0f" % _vida.obtener_vida())
			_habilidad.set("reduccion", 1.0)
			_habilidad.set("duracion_escudo", 1.0)
			_habilidad.activar()
		7:
			_vida.quitar_vida(50.0)
		8:
			print("Con escudo 100%% (esperado 80, no debería bajar): %.0f" % _vida.obtener_vida())
			_habilidad.set("reduccion", 0.5)
			_habilidad.set("duracion_escudo", 1.0)
			_habilidad.activar()
		9:
			_vida.quitar_vida(20.0)
		10:
			print("Con escudo 50%% (esperado 70): %.0f" % _vida.obtener_vida())
		# Esperar a que venza el escudo del paso anterior (duracion_escudo=1.0s).
		90:
			_vida.quitar_vida(10.0)
		91:
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

	var guion := load("res://escenas/habilidades/escudo/HabilidadEscudo.gd") as GDScript
	_habilidad = guion.new()
	# Sin recarga: la prueba reactiva el escudo varias veces en pocos
	# fotogramas para probar distintos porcentajes de reducción.
	_habilidad.set("duracion_recarga", 0.0)
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _entidad


func _informar() -> bool:
	var vida_final := _vida.obtener_vida()
	print("Tras vencerse el escudo, daño normal de nuevo (esperado 60): %.0f" % vida_final)
	var exito := is_equal_approx(vida_final, 60.0)
	print("PRUEBA ESCUDO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
