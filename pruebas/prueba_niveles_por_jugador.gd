# =============================================================================
# Prueba del modelo de UN NIVEL POR JUGADOR en el servidor dedicado.
#
# Antes el servidor tenía un único nivel para todos: el primero que cruzaba un
# portal le cambiaba el mundo abajo de los pies a los demás (se los llevaba a
# la cueva sin que hicieran nada). Ahora conviven N niveles cargados a la vez,
# desplazados entre sí (ver GestorNiveles.desplazamiento_de_nivel), y cada
# jugador pertenece a uno.
#
# Verifica:
#   1. preparar_servidor() deja cargado el nivel inicial.
#   2. Dos jugadores nuevos aparecen en el punto de aparición de ese nivel.
#   3. Mover a UNO a la cueva NO toca al otro — lo central de todo el cambio.
#   4. Los dos niveles quedan cargados A LA VEZ en el contenedor.
#   5. Están separados de verdad en el espacio (no se pisan ni por física ni
#      por el radio de interés de red, que es de 1400 px).
#   6. nivel_de_jugador() devuelve el nivel de cada uno, no "el del mundo".
#   7. El de la cueva puede volver, y el otro sigue sin enterarse.
#   godot --headless --path . --script res://pruebas/prueba_niveles_por_jugador.gd
# =============================================================================
extends SceneTree

const PRADERA := "res://escenas/niveles/NivelPradera.tscn"
const CUEVA := "res://escenas/niveles/NivelCueva.tscn"

var _gestor
var _contenedor: Node2D
var _jugador_a: CharacterBody2D
var _jugador_b: CharacterBody2D
var _fotogramas := 0

var _carga_nivel_inicial := false
var _ambos_en_el_spawn := false
var _solo_viaja_el_que_cruza := false
var _dos_niveles_a_la_vez := false
var _niveles_bien_separados := false
var _nivel_por_jugador_correcto := false
var _puede_volver_sin_arrastrar := false


func _process(_d: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_probar_aparicion()
			_probar_viaje_individual()
		# La gracia anti-rebote por jugador dura GRACIA_TRAS_CARGA (1s): hasta
		# que no vence, el servidor ignora otro viaje de ese mismo jugador.
		100:
			_probar_vuelta()
			return _informar()
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

	# Igual que ServidorDedicado: contenedor propio y jugador registrado en
	# null (acá hay N jugadores, no uno).
	_gestor.registrar(_contenedor, null)
	_gestor.preparar_servidor(PRADERA)

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	# El nombre del nodo ES el peer id (ver Jugador.gd) — de ahí saca el
	# portal a quién mover.
	_jugador_a = escena_jugador.instantiate()
	_jugador_a.name = "1"
	jugadores.add_child(_jugador_a)
	_jugador_b = escena_jugador.instantiate()
	_jugador_b.name = "2"
	jugadores.add_child(_jugador_b)

	_carga_nivel_inicial = _gestor.nivel_actual() != null \
		and _gestor.nivel_actual().nombre_nivel == "Pradera"
	print("preparar_servidor deja cargado el nivel inicial (esperado true): %s" % _carga_nivel_inicial)

	_gestor.colocar_jugador_nuevo(1, _jugador_a)
	_gestor.colocar_jugador_nuevo(2, _jugador_b)


func _probar_aparicion() -> void:
	var spawn := _spawn_de(PRADERA)
	var da: float = _jugador_a.global_position.distance_to(spawn)
	var db: float = _jugador_b.global_position.distance_to(spawn)
	_ambos_en_el_spawn = da < 50.0 and db < 50.0
	print("Los dos aparecen en el spawn de la Pradera (esperado true, %.0f y %.0f px): %s" % [
		da, db, _ambos_en_el_spawn])


func _probar_viaje_individual() -> void:
	var pos_b_antes := _jugador_b.global_position
	_gestor.mover_peer_a_nivel(1, CUEVA)

	var spawn_cueva := _spawn_de(CUEVA)
	var a_en_cueva: bool = _jugador_a.global_position.distance_to(spawn_cueva) < 50.0
	var b_no_se_movio: bool = _jugador_b.global_position.distance_to(pos_b_antes) < 1.0
	_solo_viaja_el_que_cruza = a_en_cueva and b_no_se_movio
	print("Viaja SOLO el que cruza (A en la cueva=%s, B quieto=%s): %s" % [
		a_en_cueva, b_no_se_movio, _solo_viaja_el_que_cruza])

	var cargados: Array[String] = []
	for hijo in _contenedor.get_children():
		if hijo is NivelBase:
			cargados.append((hijo as NivelBase).nombre_nivel)
	_dos_niveles_a_la_vez = cargados.size() == 2 \
		and cargados.has("Pradera") and cargados.has("Cueva")
	print("Los dos niveles quedan cargados a la vez (esperado true, %s): %s" % [
		cargados, _dos_niveles_a_la_vez])

	# Separación real: más que el radio de interés de red (1400 px), así el
	# filtrado por nivel sale gratis y no hay colisiones cruzadas.
	var separacion: float = _jugador_a.global_position.distance_to(_jugador_b.global_position)
	_niveles_bien_separados = separacion > 10000.0
	print("Los jugadores quedan en mundos separados (esperado >10000 px, %.0f): %s" % [
		separacion, _niveles_bien_separados])

	var nivel_a = _gestor.nivel_de_jugador(_jugador_a)
	var nivel_b = _gestor.nivel_de_jugador(_jugador_b)
	_nivel_por_jugador_correcto = nivel_a != null and nivel_b != null \
		and nivel_a.nombre_nivel == "Cueva" and nivel_b.nombre_nivel == "Pradera"
	print("nivel_de_jugador da el de cada uno (A=%s, B=%s): %s" % [
		nivel_a.nombre_nivel if nivel_a else "<null>",
		nivel_b.nombre_nivel if nivel_b else "<null>",
		_nivel_por_jugador_correcto])


func _probar_vuelta() -> void:
	var pos_b_antes := _jugador_b.global_position
	_gestor.mover_peer_a_nivel(1, PRADERA)
	var spawn := _spawn_de(PRADERA)
	var a_volvio: bool = _jugador_a.global_position.distance_to(spawn) < 50.0
	var b_quieto: bool = _jugador_b.global_position.distance_to(pos_b_antes) < 1.0
	_puede_volver_sin_arrastrar = a_volvio and b_quieto
	print("A vuelve a la Pradera y B sigue sin enterarse (A=%s, B quieto=%s): %s" % [
		a_volvio, b_quieto, _puede_volver_sin_arrastrar])


func _spawn_de(ruta: String) -> Vector2:
	for hijo in _contenedor.get_children():
		if hijo is NivelBase and (hijo as NivelBase).scene_file_path == ruta:
			return ((hijo as NivelBase).punto_aparicion() as Node2D).global_position
	return Vector2.ZERO


func _informar() -> bool:
	var exito := _carga_nivel_inicial and _ambos_en_el_spawn \
		and _solo_viaja_el_que_cruza and _dos_niveles_a_la_vez \
		and _niveles_bien_separados and _nivel_por_jugador_correcto \
		and _puede_volver_sin_arrastrar
	print("PRUEBA NIVELES POR JUGADOR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
