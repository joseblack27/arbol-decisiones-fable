# =============================================================================
# Prueba de que la rama "Jugadores" de Mundo.tscn participa en el mismo
# y-sort que "ContenedorNivel" (y, dentro del nivel, "Decoraciones"/
# "Enemigos").
#
# Bug reportado: un jugador parado detrás de un árbol se dibujaba POR
# ENCIMA del árbol en la pantalla de los DEMÁS jugadores (los mobs sí se
# dibujaban bien detrás). Causa: en Godot, el y-sort solo compara la
# posición Y real entre dos ramas si TODOS los nodos intermedios entre el
# ancestro común y cada hoja tienen y_sort_enabled=true. "Jugadores" no lo
# tenía (a diferencia de su hermano "ContenedorNivel"), así que esa rama
# entera se trataba como un solo bloque fijo en vez de ordenarse por la
# posición real de cada jugador — el orden de dibujado no cambiaba nunca
# sin importar dónde estuviera parado.
#
# Esto NO se puede verificar con un pixel-perfect check de render (el
# y-sort es una decisión del RenderingServer, no una propiedad consultable
# por script), así que la prueba verifica la causa raíz directamente: la
# configuración real de y_sort_enabled en toda la cadena de escenas.
#   godot --headless --path . --script res://pruebas/prueba_ysort_jugadores_arboles.gd
# =============================================================================
extends SceneTree


func _process(_delta: float) -> bool:
	var mundo := (load("res://escenas/mundo/Mundo.tscn") as PackedScene).instantiate()
	var jugadores: Node2D = mundo.get_node("Jugadores")
	var contenedor_nivel: Node2D = mundo.get_node("ContenedorNivel")

	var mundo_ok: bool = mundo.y_sort_enabled
	var contenedor_ok: bool = contenedor_nivel.y_sort_enabled
	var jugadores_ok: bool = jugadores.y_sort_enabled

	var nivel := (load("res://escenas/niveles/NivelPradera.tscn") as PackedScene).instantiate()
	var decoraciones: Node2D = nivel.get_node("Decoraciones")
	var enemigos: Node2D = nivel.get_node("Enemigos")

	var nivel_ok: bool = nivel.y_sort_enabled
	var decoraciones_ok: bool = decoraciones.y_sort_enabled
	var enemigos_ok: bool = enemigos.y_sort_enabled

	print("Mundo.y_sort_enabled: %s" % mundo_ok)
	print("Mundo/ContenedorNivel.y_sort_enabled: %s" % contenedor_ok)
	print("Mundo/Jugadores.y_sort_enabled: %s" % jugadores_ok)
	print("NivelPradera.y_sort_enabled: %s" % nivel_ok)
	print("NivelPradera/Decoraciones.y_sort_enabled: %s" % decoraciones_ok)
	print("NivelPradera/Enemigos.y_sort_enabled: %s" % enemigos_ok)

	var exito := mundo_ok and contenedor_ok and jugadores_ok \
		and nivel_ok and decoraciones_ok and enemigos_ok
	print("PRUEBA YSORT JUGADORES ARBOLES %s" % ("OK" if exito else "FALLIDA"))

	mundo.free()
	nivel.free()
	quit(0 if exito else 1)
	return true
