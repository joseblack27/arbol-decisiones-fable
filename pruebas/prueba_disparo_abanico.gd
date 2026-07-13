# =============================================================================
# Prueba: HabilidadProyectilAbanico dispara N proyectiles repartidos en
# abanico alrededor de la dirección apuntada, en una sola activación.
#   godot --headless --path . --script res://pruebas/prueba_disparo_abanico.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _habilidad: Node
var _proyectiles: Array[Node] = []

const CANTIDAD := 5
const ANGULO_TOTAL_GRADOS := 40.0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		return false
	if _fotogramas == 5:
		_habilidad.activar(Vector2.RIGHT, 1.0)
		var contenedor := root.get_node("/root/GestorPiscinas/InstanciasPiscina")
		for hijo in contenedor.get_children():
			if hijo is Area2D:
				_proyectiles.append(hijo)
	if _fotogramas == 8:
		return _informar()
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

	var guion := load("res://escenas/habilidades/proyectil/custom/HabilidadProyectilAbanico.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.set("cantidad_proyectiles", CANTIDAD)
	_habilidad.set("angulo_total_grados", ANGULO_TOTAL_GRADOS)
	contenedor.add_child(_habilidad)


func _informar() -> bool:
	var cantidad_ok := _proyectiles.size() == CANTIDAD
	print("Proyectiles disparados (esperado %d): %d" % [CANTIDAD, _proyectiles.size()])

	# Verificar que los ángulos queden repartidos simétricamente alrededor
	# de 0° (RIGHT), de -20° a +20° en pasos de 10° para 5 proyectiles / 40°.
	var angulos: Array[float] = []
	for p in _proyectiles:
		var dir: Vector2 = p.get("_direccion")
		angulos.append(rad_to_deg(dir.angle()))
	angulos.sort()
	print("Ángulos obtenidos (esperado ~[-20,-10,0,10,20]): %s" % [angulos])

	var paso := ANGULO_TOTAL_GRADOS / (CANTIDAD - 1)
	var esperado_inicial := -ANGULO_TOTAL_GRADOS / 2.0
	var angulos_ok := true
	for i in CANTIDAD:
		if not is_equal_approx(angulos[i], esperado_inicial + paso * i):
			angulos_ok = false

	var exito := cantidad_ok and angulos_ok
	print("PRUEBA DISPARO ABANICO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
