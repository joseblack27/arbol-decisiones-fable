# =============================================================================
# Prueba de EfectoCirculoBuffEquipo (el círculo verde que muestra hasta
# dónde llegó el Grito de Guerra, pedido del usuario) y de que
# HabilidadBuffEquipo NO lo instancia en headless (nadie lo vería en el
# servidor dedicado, no vale la pena).
#   godot --headless --path . --script res://pruebas/prueba_circulo_buff_equipo.gd
# =============================================================================
extends SceneTree

var _efecto
var _fotogramas := 0
## Bare "GestorPiscinas" no resuelve de forma confiable dentro del propio
## script --script de entrada (extends SceneTree) — mismo criterio que ya
## usa prueba_object_pooling.gd: resolver por NodePath explícito.
var _gestor_piscinas: Node

var _activo_tras_configurar := false
var _vuelve_a_la_piscina_al_vencer := false
var _no_instancia_nada_en_headless := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
			_efecto.configurar(120.0)
		2:
			_activo_tras_configurar = _efecto._activo
			print("Efecto activo tras configurar() (esperado true): %s" % _activo_tras_configurar)
		30:
			# duracion=0.4s por defecto (~24 fotogramas a 60fps) — a los 30
			# fotogramas ya debería haberse liberado solo a la piscina.
			_vuelve_a_la_piscina_al_vencer = not _gestor_piscinas._activos.has(_efecto)
			print("Vuelve solo a la piscina al vencer la duración (esperado true): %s" % _vuelve_a_la_piscina_al_vencer)
			_probar_headless()
		31:
			return _informar()
	return false


func _montar() -> void:
	_gestor_piscinas = root.get_node("/root/GestorPiscinas")
	var escena := load("res://escenas/habilidades/buff_equipo/EfectoCirculoBuffEquipo.tscn") as PackedScene
	_efecto = _gestor_piscinas.obtener(escena)


func _probar_headless() -> void:
	var antes: int = _gestor_piscinas._activos.size()
	var jugador := (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(jugador)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	jugador.add_child(contenedor)

	var guion := load("res://escenas/habilidades/buff_equipo/HabilidadBuffEquipo.gd") as GDScript
	var habilidad: Node = guion.new()
	habilidad.slot_index = 0
	habilidad.costo_energia = 0.0
	habilidad.duracion_recarga = 1.0
	contenedor.add_child(habilidad)
	habilidad.entidad_dueña = jugador

	habilidad.activar(Vector2.ZERO, 1.0)
	# DisplayServer.get_name() en --headless es literalmente "headless": el
	# guard de _mostrar_circulo_area() debe cortar ANTES de pedirle nada a
	# _gestor_piscinas — el conteo de activos no debe crecer más que por el
	# propio jugador/habilidad de arriba (ninguno es el círculo).
	_no_instancia_nada_en_headless = _gestor_piscinas._activos.size() == antes
	print("No instancia el círculo en headless (esperado true): %s" % _no_instancia_nada_en_headless)


func _informar() -> bool:
	var exito := _activo_tras_configurar and _vuelve_a_la_piscina_al_vencer and _no_instancia_nada_en_headless
	print("PRUEBA CIRCULO BUFF EQUIPO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
