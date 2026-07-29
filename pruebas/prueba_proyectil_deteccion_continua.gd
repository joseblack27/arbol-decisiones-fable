# =============================================================================
# Prueba de detección continua del Proyectil (cast_motion en vez de mover-y-
# esperar-overlap):
#   1. Un proyectil MUY rápido (paso por fotograma mayor que el objetivo
#      entero) SIGUE detectando el impacto — con el "position += paso"
#      viejo, un paso así de grande podía saltar por encima del objetivo
#      sin que ningún fotograma llegara a solaparlo ("a veces no recibe el
#      golpe", reportado).
#   2. Al impactar, el proyectil se reubica en el punto de contacto real
#      (no más allá) y se destruye — no queda "vivo" tras hacer daño (el
#      "hace daño pero no se destruye" reportado).
#   godot --headless --path . --script res://pruebas/prueba_proyectil_deteccion_continua.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _atacante: Node2D
var _objetivo
var _proy
var _vida_antes: float


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
	elif _fotogramas == 2:
		return _informar()
	return false


func _montar() -> void:
	_atacante = Node2D.new()
	_atacante.add_to_group("jugadores")
	root.add_child(_atacante)
	current_scene = _atacante
	_atacante.global_position = Vector2(-1000, 0)

	_objetivo = (load("res://escenas/enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	root.add_child(_objetivo)
	_objetivo.global_position = Vector2(0, 0)
	var vida: Node = _objetivo.get_node("VidaComponente")
	_vida_antes = vida.obtener_vida()

	# Arrancar el proyectil bien antes del objetivo, con velocidad brutal:
	# a 60 FPS, un solo fotograma (delta ~0.0166s) lo mueve ~166px — mucho
	# más que el radio del objetivo (~12-14px). Con detección discreta
	# (mover y recién después mirar el overlap), esto saltaría por encima
	# del ratón sin tocarlo jamás.
	# Por GestorPiscinas.obtener(), como en el juego real — instanciarlo
	# suelto (bypaseando la piscina) hace que liberar() no lo reconozca
	# como "activo" y nunca lo esconda, dando un falso "no se destruyó".
	_proy = root.get_node("/root/GestorPiscinas").call(
		"obtener", load("res://escenas/habilidades/proyectil/Proyectil.tscn")
	)
	_proy.velocidad_base = 10000.0
	_proy.global_position = Vector2(-30, 0)
	_proy.alcance_base = 2000.0
	_proy.configurar(Vector2.RIGHT, 1.0, 15, _atacante, Enums.Habilidad.TipoDano.FISICO)


func _informar() -> bool:
	var vida: Node = _objetivo.get_node("VidaComponente")
	var vida_despues: float = vida.obtener_vida()
	var golpeo_ok := vida_despues < _vida_antes
	print("Vida del objetivo antes/después (esperado que baje): %.1f -> %.1f" % [_vida_antes, vida_despues])
	print("¿Detectó el impacto pese al paso gigante? (esperado true): %s" % golpeo_ok)

	# El proyectil debe haber vuelto a la piscina (invisible/desactivado),
	# no seguir "vivo" volando tras haber hecho daño.
	var destruido_ok: bool = not _proy.visible
	print("Proyectil destruido/pooled tras el impacto (esperado true): %s" % destruido_ok)

	var exito := golpeo_ok and destruido_ok
	print("PRUEBA PROYECTIL DETECCIÓN CONTINUA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
