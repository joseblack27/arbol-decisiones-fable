# =============================================================================
# ReplicadorEnemigos (27 sep 2026): única fuente de verdad, en red, de qué
# mobs existen en "Enemigos". Reemplazó al MultiplayerSpawner del nivel y a
# los respaldos manuales que se le sumaron — con dos mecanismos creando el
# mismo nodo aparecían mobs huérfanos en el cliente ("hormigas fantasma").
#
# Se prueba sin red: las funciones de cliente/servidor se llaman directo.
# El contenedor está DESPLAZADO como un nivel real (GestorNiveles.
# desplazamiento_de_nivel) para atrapar el bug de fijar global_position
# antes de add_child.
#
# Cliente:
#   1. Un alta crea el mob con el nombre y la posición GLOBAL exactos.
#   2. Un alta repetida no lo duplica.
#   3. Una baja lo despacha (queda desvaneciéndose).
#   4. Un alta con el nombre de uno que se está desvaneciendo crea uno nuevo.
#   5. La reconciliación crea lo que falta y despacha lo que sobra (el
#      fantasma), sin tocarle la posición a lo que ya estaba.
# Servidor:
#   6. Entrar/salir del contenedor encola altas/bajas; lo que no es Enemigo
#      (p. ej. un SpawnerMobs) se ignora.
#   7. El manifiesto excluye mobs muertos.
#   8. ReplicadorEnemigos.de() encuentra el replicador desde un mob del nivel.
#   godot --headless --path . --script res://pruebas/prueba_replicador_enemigos.gd
# =============================================================================
extends SceneTree

const _RUTA_RATON := "res://escenas/enemigos/EnemigoRaton.tscn"
const _DESPLAZAMIENTO := Vector2(700000.0, 0.0)

var _f := 0
var _script_replicador: GDScript
var _nivel: Node2D
var _contenedor: Node2D
var _replicador
var _resultados: Dictionary = {}


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		3:
			_probar_cliente()
			_probar_servidor()
			return _informar()
	return false


func _montar() -> void:
	# Jugador.tscn primero: fuerza que los autoloads ya estén resueltos (ver
	# memoria del proyecto) antes de compilar scripts que los usan.
	var jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(jugador)
	jugador.queue_free()

	_script_replicador = load("res://escenas/niveles/ReplicadorEnemigos.gd")
	_nivel = (load("res://escenas/niveles/NivelBase.gd") as GDScript).new()
	_nivel.name = "NivelPrueba"
	_nivel.position = _DESPLAZAMIENTO
	_contenedor = Node2D.new()
	_contenedor.name = "Enemigos"
	_nivel.add_child(_contenedor)
	root.add_child(_nivel)
	current_scene = _nivel

	_replicador = _script_replicador.new()
	_replicador.name = "ReplicadorEnemigos"
	_replicador.configurar(_contenedor, _nivel)
	_nivel.add_child(_replicador)


func _probar_cliente() -> void:
	var pos := _DESPLAZAMIENTO + Vector2(120.0, -40.0)
	_replicador._recibir_altas([[_RUTA_RATON, "Raton1", pos]])
	var raton = _contenedor.get_node_or_null("Raton1")
	_anotar("1. el alta crea el mob en la posición global exacta",
		raton != null and raton.global_position.is_equal_approx(pos)
		and raton.get("_posicion_replicada").is_equal_approx(pos))

	_replicador._recibir_altas([[_RUTA_RATON, "Raton1", pos]])
	_anotar("2. un alta repetida no duplica", _contar_enemigos() == 1)

	_replicador._recibir_bajas(["Raton1"])
	_anotar("3. la baja lo despacha", raton.esta_muerto())

	_replicador._recibir_altas([[_RUTA_RATON, "Raton1", pos]])
	var nuevo = _contenedor.get_node_or_null("Raton1")
	_anotar("4. alta sobre uno desvaneciéndose crea uno nuevo",
		nuevo != null and nuevo != raton and not nuevo.esta_muerto())

	# Reconciliación: "Raton1" sigue en el servidor (movido: no se debe tocar),
	# "Raton2" le falta a este cliente, y "Fantasma" ya no existe allá.
	var pos_local_raton1: Vector2 = nuevo.global_position
	var fantasma = (load(_RUTA_RATON) as PackedScene).instantiate()
	fantasma.name = "Fantasma"
	_contenedor.add_child(fantasma)
	var pos_raton2 := _DESPLAZAMIENTO + Vector2(-300.0, 80.0)
	_replicador._reconciliar([
		[_RUTA_RATON, "Raton1", _DESPLAZAMIENTO + Vector2(999.0, 999.0)],
		[_RUTA_RATON, "Raton2", pos_raton2],
	])
	var raton2 = _contenedor.get_node_or_null("Raton2")
	_anotar("5a. la reconciliación crea el que falta",
		raton2 != null and raton2.global_position.is_equal_approx(pos_raton2))
	_anotar("5b. la reconciliación despacha al fantasma", fantasma.esta_muerto())
	_anotar("5c. la reconciliación no mueve al que ya estaba",
		nuevo.global_position.is_equal_approx(pos_local_raton1) and not nuevo.esta_muerto())


func _probar_servidor() -> void:
	var otro_nivel: Node2D = (load("res://escenas/niveles/NivelBase.gd") as GDScript).new()
	var contenedor := Node2D.new()
	contenedor.name = "Enemigos"
	otro_nivel.add_child(contenedor)
	root.add_child(otro_nivel)
	var replicador = _script_replicador.new()
	replicador.name = "ReplicadorEnemigos"
	replicador.configurar(contenedor, otro_nivel)
	otro_nivel.add_child(replicador)

	var vivo = (load(_RUTA_RATON) as PackedScene).instantiate()
	vivo.name = "Vivo"
	contenedor.add_child(vivo)
	var muerto = (load(_RUTA_RATON) as PackedScene).instantiate()
	muerto.name = "Muerto"
	contenedor.add_child(muerto)
	var spawner = (load("res://escenas/enemigos/SpawnerMobs.gd") as GDScript).new()
	contenedor.add_child(spawner)

	replicador._al_entrar_hijo(vivo)
	replicador._al_entrar_hijo(spawner)
	_anotar("6a. entrar encola alta solo de lo que es Enemigo",
		replicador._altas_pendientes == [vivo])
	replicador._al_salir_hijo(vivo)
	replicador._al_salir_hijo(spawner)
	_anotar("6b. salir encola la baja y cancela el alta pendiente",
		replicador._altas_pendientes.is_empty() and replicador._bajas_pendientes == ["Vivo"])

	muerto.set("_muerto", true)
	var nombres: Array = replicador.manifiesto().map(func(e): return e[1])
	_anotar("7. el manifiesto excluye muertos y lo que no es Enemigo", nombres == ["Vivo"])

	_anotar("8. de() encuentra el replicador desde un mob del nivel",
		_script_replicador.de(vivo) == replicador)


func _contar_enemigos() -> int:
	var n := 0
	for hijo in _contenedor.get_children():
		if hijo.has_method("esta_muerto"):
			n += 1
	return n


func _anotar(nombre: String, ok: bool) -> void:
	_resultados[nombre] = ok
	print("%s (esperado true): %s" % [nombre, ok])


func _informar() -> bool:
	var exito := _resultados.size() == 11
	if not exito:
		print("Faltan chequeos: se esperaban 11, llegaron %d (revisar SCRIPT ERROR arriba)" % _resultados.size())
	for ok in _resultados.values():
		exito = exito and ok
	print("PRUEBA REPLICADOR ENEMIGOS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
