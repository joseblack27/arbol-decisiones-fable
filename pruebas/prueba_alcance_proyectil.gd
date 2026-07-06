# =============================================================================
# Prueba: el proyectil recorre el alcance máximo aunque el joystick se estire
# poco (alcance_segun_poder apagado); con el condicional activo, sí escala.
# Nota: se usa load() en tiempo de ejecución porque en modo --script los
# autoloads aún no existen cuando se compila este guion.
#   godot --headless --path . --script res://pruebas/prueba_alcance_proyectil.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _habilidad_fija: Node
var _habilidad_variable: Node
var _proyectiles: Array[Node] = []


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	if _fotogramas == 5:
		# Disparo con joystick apenas estirado (poder 0.3).
		_habilidad_fija.activar(Vector2.RIGHT, 0.3)
		_habilidad_variable.activar(Vector2.RIGHT, 0.3)
		# Los proyectiles ya no cuelgan de current_scene: viven en la
		# piscina de GestorPiscinas (object pooling), fuera del árbol del
		# nivel para sobrevivir a los cambios de nivel.
		var contenedor := root.get_node("/root/GestorPiscinas/InstanciasPiscina")
		for hijo in contenedor.get_children():
			if hijo is Area2D:
				_proyectiles.append(hijo)
	if _fotogramas == 8:
		if _proyectiles.size() < 2:
			print("PRUEBA ALCANCE FALLIDA (no se crearon los proyectiles)")
			quit(1)
			return true
		var alcance_fijo: float = _proyectiles[0].get("_alcance_maximo")
		var alcance_variable: float = _proyectiles[1].get("_alcance_maximo")
		print("Alcance con condicional apagado: %.0f (esperado 400)" % alcance_fijo)
		print("Alcance con condicional activo: %.0f (esperado 120)" % alcance_variable)
		var exito := is_equal_approx(alcance_fijo, 400.0) and is_equal_approx(alcance_variable, 120.0)
		print("PRUEBA ALCANCE %s" % ("OK" if exito else "FALLIDA"))
		quit(0 if exito else 1)
		return true
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	var entidad := CharacterBody2D.new()
	escena.add_child(entidad)
	var contenedor := Marker2D.new()
	contenedor.name = "Habilidades"
	entidad.add_child(contenedor)

	var guion := load("res://escenas/habilidades/proyectil/HabilidadProyectil.gd") as GDScript
	_habilidad_fija = guion.new()
	contenedor.add_child(_habilidad_fija)
	_habilidad_variable = guion.new()
	_habilidad_variable.set("alcance_segun_poder", true)
	contenedor.add_child(_habilidad_variable)
