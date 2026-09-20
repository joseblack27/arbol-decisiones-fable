# =============================================================================
# Regresión (bug reportado 19 sep 2026, probado en celular real): "hay
# algunas puntas del mapa de hormiguero donde si el jugador pasa o se para
# alli ya no lo deja mover mas a menos que use una habilidad que lo
# desplace". Causa real: a diferencia de NivelMina.tscn/NivelCueva.tscn
# (que ya desactivan collision_enabled en su capa "Navegacion", una capa
# de AYUDA que no debería chocar con nada -- el colisionador real es
# "Terreno"), NivelHormiguero.tscn dejaba "Navegacion" con el default
# (collision_enabled=true). Con las dos capas de piso solapadas
# aportando colisión a la vez, un CharacterBody2D podía trabarse contra
# las costuras entre celdas vecinas en las esquinas cóncavas que deja el
# cavado orgánico de este nivel (elipses+túneles, a diferencia de Mina/
# Cueva armados a mano) -- exactamente el síntoma reportado.
#
# Arreglo: NivelHormiguero.tscn ahora trae collision_enabled=false en
# "Navegacion", igual que Mina/Cueva.
#   godot --headless --path . --script res://pruebas/prueba_hormiguero_navegacion_sin_colision.gd
# =============================================================================
extends SceneTree

var _nivel_sin_colision_navegacion_ok := false
var _terreno_si_tiene_colision_ok := false


func _process(_delta: float) -> bool:
	var nivel = (load("res://escenas/niveles/NivelHormiguero.tscn") as PackedScene).instantiate()
	root.add_child(nivel)

	var navegacion := nivel.get_node("Navegacion") as TileMapLayer
	_nivel_sin_colision_navegacion_ok = not navegacion.collision_enabled
	print("Navegacion del Hormiguero sin colisión, igual que Mina/Cueva (esperado true): %s" % \
		_nivel_sin_colision_navegacion_ok)

	var terreno := nivel.get_node("Terreno") as TileMapLayer
	_terreno_si_tiene_colision_ok = terreno.collision_enabled
	print("Terreno del Hormiguero SÍ sigue siendo el colisionador real (esperado true): %s" % \
		_terreno_si_tiene_colision_ok)

	var exito := _nivel_sin_colision_navegacion_ok and _terreno_si_tiene_colision_ok
	print("PRUEBA HORMIGUERO NAVEGACION SIN COLISION %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
