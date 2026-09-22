# =============================================================================
# Regresión (investigación real, 21 sep 2026 -- ver memoria bug-huevos-
# multiplayerspawner-desincronizado.md): el log del depurador de Godot de
# un cliente real mostró miles de errores "get_cached_object: ID N not
# found" / "on_spawn_receive: spawner is null" -- confirmado que un
# cliente conectado a un nivel YA poblado (típico del Hormiguero) queda con
# la réplica automática del MultiplayerSpawner desincronizada, y NO SOLO
# para los huevos: también para hormigas ambiente comunes creadas después
# de ese momento. HabilidadPuestaHuevos ya no confía en esa réplica
# automática para HuevoHormiga (sacado de escenas_replicables(), ver ese
# comentario) -- ahora crea el huevo A MANO en cada cliente vía RPC
# explícito (_crear_huevos_red), mismo criterio que SpawnerMobs._recibir_
# mobs_existentes ya usa para resincronizar peers tardíos.
#
# Prueba DIRECTA sobre _crear_huevos_red() (mismo criterio que "CLIENTE" en
# prueba_puesta_huevos_tope_resistencia.gd: llamar el RPC directo, sin
# armar una conexión de red real):
#   1. Crea un HuevoHormiga con el nombre exacto pasado, nace en origen_pos
#      y vuela hasta destino (mismo lanzar_hacia() que el servidor).
#   2. Es idempotente: si el nombre ya existe (llegó por MultiplayerSpawner
#      normal, o se llamó dos veces), NO lo duplica.
#   godot --headless --path . --script res://pruebas/prueba_huevo_hormiga_creacion_manual_cliente.gd
# =============================================================================
extends SceneTree

const DURACION_VUELO_ESPERADA_MS := 1500  # margen de sobra sobre 0.3s reales.

var _reina
var _habilidad
var _contenedor: Node2D
var _momento_inicio_ms := 0
var _verificado := false

var _origen_pos := Vector2(500.0, 300.0)
var _destino_pos := Vector2(560.0, 340.0)

var _se_crea_con_nombre_correcto_ok := false
var _nace_en_origen_ok := false
var _llega_a_destino_ok := false
var _no_duplica_si_ya_existe_ok := false


func _process(_delta: float) -> bool:
	if _momento_inicio_ms == 0:
		_montar()
		_momento_inicio_ms = Time.get_ticks_msec()
		return false
	if _verificado:
		return false
	if Time.get_ticks_msec() - _momento_inicio_ms >= DURACION_VUELO_ESPERADA_MS:
		_verificado = true
		_verificar()
		return _informar()
	return false


func _montar() -> void:
	_contenedor = Node2D.new()
	_contenedor.name = "Enemigos"
	root.add_child(_contenedor)
	current_scene = _contenedor

	_reina = (load("res://escenas/enemigos/EnemigoReinaHormigas.tscn") as PackedScene).instantiate()
	_contenedor.add_child(_reina)
	_reina.global_position = Vector2(1000.0, 1000.0)

	_habilidad = _reina.get_node("Habilidades/HabilidadPuestaHuevos")

	# Simula el RPC "_crear_huevos_red" tal como lo mandaría el servidor --
	# mismo criterio que "CLIENTE" en prueba_puesta_huevos_tope_resistencia.
	_habilidad._crear_huevos_red(_origen_pos, [["HuevoHormigaManual", _destino_pos]])

	var creado = _contenedor.get_node_or_null("HuevoHormigaManual")
	_se_crea_con_nombre_correcto_ok = creado != null
	print("_crear_huevos_red() crea el nodo con el nombre exacto (esperado true): %s" % \
		_se_crea_con_nombre_correcto_ok)

	if creado:
		_nace_en_origen_ok = creado.global_position.distance_to(_origen_pos) < 1.0
	print("El huevo creado a mano nace en origen_pos (esperado true): %s" % _nace_en_origen_ok)

	# Segunda llamada con el MISMO nombre -- no debe duplicar (idempotencia:
	# el nodo pudo haber llegado también por el MultiplayerSpawner normal en
	# algún cliente sin el bug, o el RPC pudo reintentarse).
	_habilidad._crear_huevos_red(_origen_pos, [["HuevoHormigaManual", _destino_pos]])
	var hijos_con_ese_nombre = 0
	for hijo in _contenedor.get_children():
		if hijo.name == "HuevoHormigaManual":
			hijos_con_ese_nombre += 1
	_no_duplica_si_ya_existe_ok = hijos_con_ese_nombre == 1
	print("Llamarlo dos veces con el mismo nombre no duplica (esperado true, cantidad=%d): %s" % [
		hijos_con_ese_nombre, _no_duplica_si_ya_existe_ok])


func _verificar() -> void:
	var creado = _contenedor.get_node_or_null("HuevoHormigaManual")
	_llega_a_destino_ok = creado != null and creado.global_position.distance_to(_destino_pos) < 3.0
	print("Tras el vuelo, el huevo creado a mano llega a destino (esperado true, pos=%s): %s" % [
		creado.global_position if creado else "null", _llega_a_destino_ok])


func _informar() -> bool:
	var exito := _se_crea_con_nombre_correcto_ok and _nace_en_origen_ok \
		and _llega_a_destino_ok and _no_duplica_si_ya_existe_ok
	print("PRUEBA HUEVO HORMIGA CREACION MANUAL CLIENTE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
