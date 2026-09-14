# =============================================================================
# Prueba de humo del esqueleto de NivelHormiguero.tscn: instancia sin
# errores, tiene los nodos que exige el contrato de NivelBase, el portal
# ida-y-vuelta con Pradera está bien enlazado, y el mapa de navegación se
# hornea sin problemas. Esta primera versión cubre solo estructura + portal
# (registrado en el plan como el paso 1-3) -- todavía no hay jefa/compuerta/
# spawners, eso se suma más adelante extendiendo esta misma prueba (mismo
# criterio que prueba_mina_nivel_carga.gd, que creció junto con cada rama).
#   godot --headless --path . --script res://pruebas/prueba_hormiguero_nivel_carga.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _nivel
var _nivel_pradera


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
	if _fotogramas == 5:
		return _informar()
	return false


func _montar() -> void:
	_nivel = (load("res://escenas/niveles/NivelHormiguero.tscn") as PackedScene).instantiate()
	root.add_child(_nivel)
	current_scene = _nivel

	_nivel_pradera = (load("res://escenas/niveles/NivelPradera.tscn") as PackedScene).instantiate()
	root.add_child(_nivel_pradera)


func _informar() -> bool:
	var nombre_nivel_ok: bool = _nivel.nombre_nivel == "Hormiguero"
	print("Nombre del nivel correcto (esperado true): %s" % nombre_nivel_ok)

	var punto_aparicion = _nivel.get_node_or_null("PuntoAparicion")
	var punto_aparicion_ok := punto_aparicion != null
	print("Punto de aparición presente (esperado true): %s" % punto_aparicion_ok)

	var terreno = _nivel.get_node_or_null("Terreno") as TileMapLayer
	var navegacion = _nivel.get_node_or_null("Navegacion") as TileMapLayer
	var terreno_ok: bool = terreno != null and terreno.get_used_cells().size() > 0
	var navegacion_ok: bool = navegacion != null and navegacion.get_used_cells().size() > 0
	print("Terreno pintado (esperado true): %s" % terreno_ok)
	print("Navegación pintada (esperado true): %s" % navegacion_ok)

	var mapa_nav_ok: bool = _nivel.mapa_navegacion().is_valid()
	print("Mapa de navegación propio del nivel horneado (esperado true): %s" % mapa_nav_ok)

	var enemigos = _nivel.get_node_or_null("Enemigos")
	var decoraciones = _nivel.get_node_or_null("Decoraciones")
	var contenedores_ok: bool = enemigos != null and decoraciones != null
	print("Contenedores Enemigos/Decoraciones presentes (esperado true): %s" % contenedores_ok)

	var portal_salida = _nivel.get_node_or_null("PortalAPradera")
	var portal_entrada = _nivel_pradera.get_node_or_null("PortalAHormiguero")

	var portal_salida_ok: bool = portal_salida != null \
		and portal_salida.ruta_nivel_destino == "res://escenas/niveles/NivelPradera.tscn"
	print("Portal de salida hacia Pradera presente (esperado true): %s" % portal_salida_ok)

	var portal_entrada_ok: bool = portal_entrada != null \
		and portal_entrada.ruta_nivel_destino == "res://escenas/niveles/NivelHormiguero.tscn"
	print("Portal de entrada desde Pradera presente (esperado true): %s" % portal_entrada_ok)

	var registrado_ok: bool = "res://escenas/niveles/NivelHormiguero.tscn" in GestorNiveles.NIVELES
	print("NivelHormiguero.tscn registrado en GestorNiveles.NIVELES (esperado true): %s" % registrado_ok)

	var exito := nombre_nivel_ok and punto_aparicion_ok and terreno_ok and navegacion_ok \
		and mapa_nav_ok and contenedores_ok and portal_salida_ok and portal_entrada_ok and registrado_ok
	print("PRUEBA HORMIGUERO NIVEL CARGA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
