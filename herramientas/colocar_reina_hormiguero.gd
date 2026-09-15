# =============================================================================
# colocar_reina_hormiguero.gd — agrega la Reina de las Hormigas ya construida
# a la cámara final (sala 9) de NivelHormiguero.tscn. Misma técnica segura
# que poblar_nivel_hormiguero.gd (instantiate + add_child + pack, sin tocar
# set_script() de ningún nodo YA existente).
#
# Posición = centro de sala 9 en generar_nivel_hormiguero.gd
# (CENTROS_SALA[9] = Vector2i(-100, 25) -> _tile_a_px = Vector2(-3184, 816)),
# ya confirmada dentro del área conectada por verificar_navegacion_bfs.gd
# (3618/3618 celdas alcanzables, sala 9 incluida) -- ver esa herramienta si
# se vuelve a regenerar el terreno antes de tocar esto.
#   godot --headless --path . --script res://herramientas/colocar_reina_hormiguero.gd
# =============================================================================
extends SceneTree

const RUTA_NIVEL := "res://escenas/niveles/NivelHormiguero.tscn"
const POSICION_SALA_REINA := Vector2(-3184, 816)


func _initialize() -> void:
	var nivel := (load(RUTA_NIVEL) as PackedScene).instantiate()
	var enemigos := nivel.get_node("Enemigos")

	if enemigos.get_node_or_null("EnemigoReinaHormigas") != null:
		push_error("La reina ya está colocada -- abortando para no duplicarla.")
		quit(1)
		return

	var reina := (load("res://escenas/enemigos/EnemigoReinaHormigas.tscn") as PackedScene).instantiate()
	enemigos.add_child(reina)
	reina.owner = nivel
	reina.global_position = POSICION_SALA_REINA

	var escena := PackedScene.new()
	if escena.pack(nivel) != OK:
		push_error("No se pudo empaquetar %s." % RUTA_NIVEL)
		quit(1)
		return
	if ResourceSaver.save(escena, RUTA_NIVEL) != OK:
		push_error("No se pudo guardar %s." % RUTA_NIVEL)
		quit(1)
		return
	print("Reina colocada en sala 9 (%s) de %s." % [POSICION_SALA_REINA, RUTA_NIVEL])
	quit(0)
