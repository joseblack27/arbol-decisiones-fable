# =============================================================================
# Prueba de SpawnerMobs:
#   1. cantidad_inicial genera de golpe al arrancar.
#   2. Respeta maximo_mobs: nunca sobrepasa el tope aunque pasen muchos
#      intervalos de generación.
#   3. Al morir uno, se libera un hueco y el spawner genera otro para
#      volver a llenarlo (tree_exiting -> bookkeeping de _vivos).
#   godot --headless --path . --script res://pruebas/prueba_spawner_mobs.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
# Sin tipar como SpawnerMobs: ese script referencia el autoload Utils
# (en_red()), y el análisis estático del --script de esta prueba lo
# compilaría antes de que los autoloads existan (mismo artefacto de
# siempre, ver otras pruebas).
var _spawner
var _contenedor: Node2D
var _maximo_observado := 0
var _genero_inicial := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			# La generación inicial espera al menos un physics_frame (para
			# que la malla de navegación del mundo sincronice), y _process no
			# genera nada por intervalo hasta que termine esa espera — pero
			# el intervalo de esta prueba es tan corto (0.05s) que hay que
			# comprobarlo apenas un fotograma después, antes de que alcance
			# a disparar un ciclo extra.
			_genero_inicial = _spawner.cantidad_viva() == 1
			print("Generó la cantidad_inicial (1): %s (vivos=%d)" % [
				_genero_inicial, _spawner.cantidad_viva(),
			])
		200:
			# Con intervalo 0.05s durante ~3s, de sobra para llenar el tope
			# (2) muchas veces si no se respetara el máximo.
			_maximo_observado = _spawner.cantidad_viva()
			print("Vivos tras dar tiempo de sobra (esperado <= 2): %d" % _maximo_observado)
			_matar_uno()
		# El desvanecido de muerte ahora dura más (dos etapas, ~0.8s +
		# margen real observado ~2s): dar más tiempo tras matar antes de
		# comprobar que el hueco se liberó y se rellenó.
		420:
			return _informar()
	return false


func _montar() -> void:
	_contenedor = Node2D.new()
	root.add_child(_contenedor)
	current_scene = _contenedor

	_spawner = (load("res://escenas/enemigos/SpawnerMobs.gd") as GDScript).new()
	# Con _spawner sin tipar, una asignación directa de array literal no
	# arma un Array[PackedScene] de verdad — Godot rechaza en runtime
	# guardar un Array genérico en una propiedad @export tipada.
	var mobs: Array[PackedScene] = [load("res://escenas/enemigos/EnemigoRaton.tscn")]
	_spawner.lista_mobs = mobs
	_spawner.maximo_mobs = 2
	_spawner.intervalo_spawn = 0.05
	_spawner.radio_spawn = 10.0
	_spawner.cantidad_inicial = 1
	_contenedor.add_child(_spawner)


func _matar_uno() -> void:
	var candidatos: Array[Node] = _contenedor.get_children().filter(
		func(n: Node) -> bool: return n != _spawner
	)
	var mob: Node = candidatos[0]
	# Sin tipar como VidaComponente por el mismo motivo de arriba (ese
	# script también referencia Utils.en_red() ahora).
	var vida = mob.get_node("VidaComponente")
	vida.quitar_vida(9999.0)


func _informar() -> bool:
	# Tras matar uno (con desvanecido 0.6s) debería quedar 1 vivo mientras el
	# muerto se desvanece, y el spawner ya habrá rellenado el hueco liberado.
	var vivos_ahora: int = _spawner.cantidad_viva()
	print("cantidad_viva() tras liberar un hueco y rellenarlo (esperado 2): %d" % vivos_ahora)
	var exito := _genero_inicial and _maximo_observado <= 2 and vivos_ahora == 2
	print("PRUEBA SPAWNER MOBS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
