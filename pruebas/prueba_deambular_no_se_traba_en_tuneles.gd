# =============================================================================
# Regresión: en topología de túneles angostos (Hormiguero), AccionDeambular
# podía elegir un destino que cae fuera de lo caminable (dentro de una
# pared) y quedarse comandando movimiento hacia ESE MISMO punto para
# siempre -- la condición de "llegué" original (distancia cruda) nunca se
# cumplía contra un punto inalcanzable. Reportado por el usuario: "las
# hormigas siempre tratan de volver a un mismo sitio que está como fuera
# del mapa".
#
# Verifica sobre una hormiga real en el Hormiguero real, 20s simulados:
#   1. La hormiga NUNCA pisa una celda que no sea piso real (PIEDRA/
#      PIEDRA_GRIETA) -- chequeado contra el propio TileMapLayer Terreno,
#      no contra NavigationServer2D (su mapa privado por nivel no responde
#      a map_get_regions()/map_get_closest_point() para este tipo de malla
#      por TileMapLayer -- confirmado investigando este mismo bug -- así
#      que la validación real de "está en el mapa" tiene que salir de la
#      celda pintada, no de esa API).
#   2. Elige MÁS DE UN destino en esa ventana -- si algo la deja fija en
#      un solo punto (el bug original), esto se queda en 1 para siempre.
#   godot --headless --path . --script res://pruebas/prueba_deambular_no_se_traba_en_tuneles.gd
# =============================================================================
extends SceneTree

const HORMIGUERO := "res://escenas/niveles/NivelHormiguero.tscn"
const PRADERA := "res://escenas/niveles/NivelPradera.tscn"

var _gestor
var _contenedor: Node2D
var _nivel_hormiguero
var _hormiga
var _fotogramas := 0
var _piso_fuera_del_mapa := false
var _deambular
var _ultimo_destino := Vector2.INF
var _destinos_vistos := 0


func _process(_d: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_agregar_hormiga()
		60:
			_deambular = _hormiga.get_node("ArbolComportamiento/Selector/Deambular")
		1260:
			return _informar()
	if _fotogramas > 60:
		_revisar_piso()
	return false


func _montar() -> void:
	_gestor = root.get_node("/root/GestorNiveles")
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena
	_contenedor = Node2D.new()
	_contenedor.name = "ContenedorNivel"
	escena.add_child(_contenedor)
	var jugadores := Node2D.new()
	jugadores.name = "Jugadores"
	escena.add_child(jugadores)
	_gestor.registrar(_contenedor, null)
	_gestor.preparar_servidor(PRADERA)
	var jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	jugador.name = "1"
	jugadores.add_child(jugador)
	_gestor.colocar_jugador_nuevo(1, jugador)
	_gestor.mover_peer_a_nivel(1, HORMIGUERO)
	for hijo in _contenedor.get_children():
		if hijo is NivelBase and (hijo as NivelBase).scene_file_path == HORMIGUERO:
			_nivel_hormiguero = hijo
			break


func _agregar_hormiga() -> void:
	_hormiga = (load("res://escenas/enemigos/EnemigoHormigaObrera.tscn") as PackedScene).instantiate()
	_nivel_hormiguero.get_node("Enemigos").add_child(_hormiga)
	_hormiga.global_position = _nivel_hormiguero.get_node("PuntoAparicion").global_position
	# El jugador (necesario para que el nivel quede activo, ver _montar())
	# aparece en el mismo PuntoAparicion -- sin alejarlo, la hormiga lo
	# detecta y pelea/persigue en vez de deambular, y esta prueba
	# terminaría verificando combate por accidente, no deambular.
	var jugador := _contenedor.get_parent().get_node("Jugadores").get_child(0)
	jugador.global_position = _hormiga.global_position + Vector2(3000, 3000)


func _revisar_piso() -> void:
	var terreno: TileMapLayer = _nivel_hormiguero.get_node("Terreno")
	var celda := terreno.local_to_map(terreno.to_local(_hormiga.global_position))
	var atlas := terreno.get_cell_atlas_coords(celda)
	var es_piso := atlas == Vector2i(17, 30) or atlas == Vector2i(16, 29)
	if not es_piso:
		_piso_fuera_del_mapa = true

	var destino_actual: Vector2 = _deambular.get("_destino")
	if destino_actual != _ultimo_destino:
		_ultimo_destino = destino_actual
		_destinos_vistos += 1


func _informar() -> bool:
	var no_se_sale_ok := not _piso_fuera_del_mapa
	print("La hormiga nunca pisa una celda fuera del piso real (esperado true): %s" % no_se_sale_ok)

	var cambia_de_destino_ok := _destinos_vistos > 1
	print("Elige más de un destino en 20s, no se fija en uno solo (esperado true, vistos=%d): %s" % [
		_destinos_vistos, cambia_de_destino_ok])

	var exito := no_se_sale_ok and cambia_de_destino_ok
	print("PRUEBA DEAMBULAR NO SE TRABA EN TUNELES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
