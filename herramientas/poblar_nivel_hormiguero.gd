# =============================================================================
# poblar_nivel_hormiguero.gd — agrega SpawnerMobs + ActivadorSalaSpawners a
# NivelHormiguero.tscn (ya generado por generar_nivel_hormiguero.gd). Salas
# 1-8 pobladas (mezcla Obrera/Soldado, 7 mobs c/u = 56 teóricos), sala 0
# (entrada) y 9 (Reina) sin spawner ambiente. La sala 1 arranca activa
# (activo=true, primer contacto apenas se sale de la entrada); las salas
# 2-8 arrancan desactivadas y las prende un ActivadorSalaSpawners puesto en
# el túnel de entrada a esa sala (no en su centro: así se cruza al avanzar,
# no solo si el jugador explora hasta el medio).
#   godot --headless --path . --script res://herramientas/poblar_nivel_hormiguero.gd
# =============================================================================
extends SceneTree

const RUTA_NIVEL := "res://escenas/niveles/NivelHormiguero.tscn"
const ESCENA_OBRERA := "res://escenas/enemigos/EnemigoHormigaObrera.tscn"
const ESCENA_SOLDADO := "res://escenas/enemigos/EnemigoHormigaSoldado.tscn"
const ESCENA_ACTIVADOR := "res://escenas/objetos/ActivadorSalaSpawners.tscn"
const GUION_SPAWNER := "res://escenas/enemigos/SpawnerMobs.gd"

# Mismos centros que generar_nivel_hormiguero.gd (sala 0=entrada, 9=Reina).
const CENTROS_SALA: Array[Vector2i] = [
	Vector2i(-100, -20), Vector2i(-50, -20), Vector2i(0, -20), Vector2i(50, -20), Vector2i(100, -20),
	Vector2i(100, 25), Vector2i(50, 25), Vector2i(0, 25), Vector2i(-50, 25), Vector2i(-100, 25),
]
const MOBS_POR_SALA := 7


func _process(_d: float) -> bool:
	var nivel := (load(RUTA_NIVEL) as PackedScene).instantiate()
	var enemigos := nivel.get_node("Enemigos") as Node2D
	var decoraciones := nivel.get_node("Decoraciones") as Node2D

	var mobs: Array[PackedScene] = [load(ESCENA_OBRERA), load(ESCENA_SOLDADO)]
	var total_teorico := 0

	for i in range(1, 9):  # salas 1..8 -- 0 es entrada, 9 es la Reina.
		var centro := _tile_a_px(CENTROS_SALA[i])
		var spawner := Node2D.new()
		spawner.name = "SpawnerMobs%d" % i
		spawner.set_script(load(GUION_SPAWNER))
		spawner.position = centro
		spawner.set("lista_mobs", mobs)
		spawner.set("maximo_mobs", MOBS_POR_SALA)
		spawner.set("radio_spawn", 140.0)
		spawner.set("intervalo_spawn", 8.0)
		# Solo la sala YA activa arranca con mobs de una -- cantidad_inicial
		# ignora "activo" al generar (ver SpawnerMobs._ready), así que dejarlo
		# en MOBS_POR_SALA para las 8 salas por igual hacía que las 56
		# hormigas aparecieran TODAS apenas carga el nivel, sin importar el
		# activador: un enjambre entero concentrado desde el arranque en vez
		# del goteo progresivo pensado (bug real, encontrado reproduciendo en
		# una prueba con el jugador muriendo en loop apenas entraba a una
		# sala — desde el juego se veía como "las hormigas no reaccionan").
		spawner.set("cantidad_inicial", MOBS_POR_SALA if i == 1 else 0)
		spawner.set("activo", i == 1)  # sala 1 arranca activa, el resto no.
		enemigos.add_child(spawner)
		spawner.owner = nivel
		total_teorico += MOBS_POR_SALA

		if i > 1:
			var activador := (load(ESCENA_ACTIVADOR) as PackedScene).instantiate()
			activador.name = "ActivadorSala%d" % i
			var previo := _tile_a_px(CENTROS_SALA[i - 1])
			activador.position = previo.lerp(centro, 0.5)
			decoraciones.add_child(activador)
			activador.owner = nivel
			# get_path_to() DESPUÉS de add_child(): necesita a los dos ya
			# colgando del mismo árbol para calcular la ruta relativa real
			# (activador vive en Decoraciones, spawner en Enemigos -- una
			# ruta ABSOLUTA tipo spawner.get_path() apuntaría mal, ya que
			# ActivadorSalaSpawners.get_node_or_null() resuelve anclado en
			# SÍ MISMO, no en la raíz del nivel).
			var rutas: Array[NodePath] = [activador.get_path_to(spawner)]
			activador.set("spawners", rutas)

	var escena := PackedScene.new()
	if escena.pack(nivel) != OK:
		push_error("No se pudo empaquetar el nivel.")
		quit(1)
		return true
	if ResourceSaver.save(escena, RUTA_NIVEL) != OK:
		push_error("No se pudo guardar %s" % RUTA_NIVEL)
		quit(1)
		return true

	print("Guardado %s: 8 salas pobladas (1-8), %d mobs teóricos (sala 1 activa, 2-8 con activador)." % [
		RUTA_NIVEL, total_teorico])
	quit(0)
	return true


func _tile_a_px(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * 32.0 + 16.0, tile.y * 32.0 + 16.0)
