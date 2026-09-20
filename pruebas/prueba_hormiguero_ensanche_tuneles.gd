# =============================================================================
# Regresión (bug reportado en juego real, 20 sep 2026, confirmado con una
# captura del panel de Mapa): "sigue el mismo problema de quedarse trabado
# en las esquinas" -- incluso caminando normal, sin ninguna habilidad, y
# también usando una y colisionando con el borde. Causa real: el túnel
# entre dos salas tenía un radio CONSTANTE (2.5 tiles) mucho más angosto
# que el radio de la sala (9x7 tiles) -- la transición sala->túnel era un
# "hombro" cóncavo BRUSCO (un escalón ancho, no un simple pellizco de una
# sola celda diagonal, por eso ningún análisis geométrico puntual anterior
# lo había encontrado). Confirmado visualmente comparando el panel de Mapa
# real (que dibuja el Terreno real, ver PanelMapa.gd) contra un render
# propio de la forma calculada del nivel.
#
# Arreglo (aplicado directo sobre NivelHormiguero.tscn, sin regenerar el
# nivel entero -- eso hubiera borrado spawners/activadores/Reina ya
# colocados): el radio del túnel ahora crece gradualmente cerca de cada
# punta, MEDIDO DESDE EL BORDE de la sala (no desde su centro -- un primer
# intento medía desde el centro y desperdiciaba casi todo el margen DENTRO
# de la propia elipse, terminando en un ensanche casi inexistente, ver
# commit e24e684 -- corregido acá).  Ahora el radio decae de RADIO_ENSANCHE
# =7.0 (casi igual al propio radio de la sala) a RADIO_TUNEL=2.5 a lo largo
# de DISTANCIA_ENSANCHE=15 tiles, medidos desde el borde real de la elipse.
#
# Prueba: un punto claramente FUERA de la elipse de la sala 0 (dx=15,dy=5
# desde su centro) que antes daba pared (fuera del radio viejo 2.5) y con
# el ensanche nuevo da piso real (radio local ahí ~5.2). Un punto lejos de
# cualquier ensanche (mitad del túnel) sigue siendo pared, igual que
# antes -- confirma que el arreglo es LOCAL a las puntas, no ensanchó el
# túnel entero.
#   godot --headless --path . --script res://pruebas/prueba_hormiguero_ensanche_tuneles.gd
# =============================================================================
extends SceneTree

const PIEDRA := Vector2i(17, 30)
const PIEDRA_GRIETA := Vector2i(16, 29)

var _celda_ensanchada_es_piso_ok := false
var _mitad_tunel_sigue_pared_ok := false
var _nivel_sigue_completo_ok := false


func _process(_delta: float) -> bool:
	var nivel := (load("res://escenas/niveles/NivelHormiguero.tscn") as PackedScene).instantiate()
	root.add_child(nivel)
	current_scene = nivel

	var terreno := nivel.get_node("Terreno") as TileMapLayer

	# 15 tiles hacia sala 1 desde el centro de sala 0 (-100,-20), 5 tiles
	# perpendicular -- claramente fuera de la elipse de la sala (9x7) Y
	# fuera del radio viejo de túnel (2.5), pero dentro del nuevo ensanche
	# (~5.2 ahí, ver comentario grande de arriba).
	var celda_ensanchada := Vector2i(-100 + 15, -20 + 5)
	var atlas_ensanchada := terreno.get_cell_atlas_coords(celda_ensanchada)
	_celda_ensanchada_es_piso_ok = atlas_ensanchada == PIEDRA or atlas_ensanchada == PIEDRA_GRIETA
	print("Celda %s (en la zona de ensanche) es piso real (esperado true, atlas=%s): %s" % [
		celda_ensanchada, atlas_ensanchada, _celda_ensanchada_es_piso_ok])

	# Mitad de camino entre sala 0 (-100,-20) y sala 1 (-50,-20): x=-75, bien
	# lejos de DISTANCIA_ENSANCHE=12 de cualquiera de las dos puntas -- ahí
	# el túnel se queda angosto (radio 2.5) como siempre, así que 4 tiles
	# perpendicular sigue siendo pared, igual que antes del arreglo.
	var celda_mitad_tunel := Vector2i(-75, -20 + 4)
	var atlas_mitad := terreno.get_cell_atlas_coords(celda_mitad_tunel)
	_mitad_tunel_sigue_pared_ok = atlas_mitad != PIEDRA and atlas_mitad != PIEDRA_GRIETA
	print("Celda %s (mitad del túnel, sin ensanche) sigue siendo pared (esperado true, atlas=%s): %s" % [
		celda_mitad_tunel, atlas_mitad, _mitad_tunel_sigue_pared_ok])

	var enemigos := nivel.get_node_or_null("Enemigos")
	var reina := nivel.get_node_or_null("Enemigos/EnemigoReinaHormigas")
	_nivel_sigue_completo_ok = enemigos != null and enemigos.get_child_count() >= 8 and reina != null
	print("El nivel sigue con sus spawners/Reina intactos tras el parche (esperado true): %s" % \
		_nivel_sigue_completo_ok)

	var exito := _celda_ensanchada_es_piso_ok and _mitad_tunel_sigue_pared_ok and _nivel_sigue_completo_ok
	print("PRUEBA HORMIGUERO ENSANCHE TUNELES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
