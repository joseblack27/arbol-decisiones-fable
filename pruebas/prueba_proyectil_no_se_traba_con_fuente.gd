# =============================================================================
# Prueba: el proyectil nace en la MISMA posición que quien lo disparó (así
# lo hace HabilidadProyectil._ejecutar() siempre) — el primer cast_motion()
# del primer fotograma detecta casi seguro al propio lanzador como "primer
# contacto en el camino", pero NO es un objetivo válido (defensor ==
# entidad_fuente). Antes, el proyectil se quedaba solo con la fracción de
# movimiento hasta ESE contacto inválido y nunca completaba el resto del
# fotograma — quedaba prácticamente trabado sobre su propio lanzador para
# siempre, viéndose como si "a veces simplemente no funcionara".
#   godot --headless --path . --script res://pruebas/prueba_proyectil_no_se_traba_con_fuente.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _atacante: CharacterBody2D
var _proy
var _pos_inicial: Vector2


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
	elif _fotogramas == 30:
		return _informar()
	return false


func _montar() -> void:
	_atacante = CharacterBody2D.new()
	_atacante.add_to_group("jugadores")
	var col := CollisionShape2D.new()
	col.shape = CircleShape2D.new()
	_atacante.add_child(col)
	root.add_child(_atacante)
	current_scene = _atacante
	_atacante.global_position = Vector2(200, 200)

	# El propio lanzador tiene VidaComponente, como cualquier jugador/mob —
	# es justo lo que el cast_motion del primer fotograma va a "chocar"
	# primero, al nacer el proyectil exactamente en su posición.
	var vida = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	vida.name = "VidaComponente"
	_atacante.add_child(vida)

	_proy = root.get_node("/root/GestorPiscinas").call(
		"obtener", load("res://escenas/habilidades/proyectil/Proyectil.tscn")
	)
	_proy.global_position = _atacante.global_position
	_proy.alcance_base = 400.0
	_proy.configurar(Vector2.RIGHT, 1.0, 10, _atacante, Enums.Habilidad.TipoDano.FISICO)
	_pos_inicial = _proy.global_position


func _informar() -> bool:
	var avance: float = _proy.global_position.distance_to(_pos_inicial)
	# A velocidad_base=450px/s, 29 fotogramas (~0.48s) deberían mover el
	# proyectil unos 217px si no se trabó — cualquier cosa muy por debajo
	# de eso confirma que se quedó pegado cerca del origen.
	var no_se_traba_ok: bool = avance > 150.0
	print("Avance tras 29 fotogramas (esperado > 150px, ~217px si no se traba): %.1f" % avance)
	print("PRUEBA PROYECTIL NO SE TRABA CON FUENTE %s" % ("OK" if no_se_traba_ok else "FALLIDA"))
	quit(0 if no_se_traba_ok else 1)
	return true
