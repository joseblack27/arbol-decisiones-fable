# =============================================================================
# Regresión (reportado en juego real, 24 sep 2026, justo al desactivar el
# sueño por distancia como diagnóstico -- ver ArbolComportamiento.
# radio_actividad): "no he atacado ni nada y desaparecieron 4 [de 6
# hormigas]" -- hormigas completamente sanas, sin pelear, desaparecían
# solas. Causa probable: SpawnerMobs._TOLERANCIA_NAVEGACION (6px) es
# ajustada para un NavigationAgent2D activamente en movimiento -- un mob
# de verdad sobre la malla puede estar TRANSITORIAMENTE unos pocos px más
# allá justo en el instante puntual de _revisar_mobs_fuera_de_limites()
# (cada 5s). _revisar_mobs_fuera_de_limites() ahora exige DOS revisiones
# consecutivas fuera de la malla antes de borrar.
#
# Confirma:
#   1. Un mob fuera de la malla en la PRIMERA revisión NO se borra todavía
#      (podría ser transitorio).
#   2. Si en la revisión SIGUIENTE sigue adentro de tolerancia (se
#      corrigió solo), NO se borra -- el "sospechoso" no se arrastra para
#      siempre.
#   3. Un mob fuera de la malla DOS revisiones seguidas SÍ se borra.
#   godot --headless --path . --script res://pruebas/prueba_spawner_fuera_de_limites_requiere_dos_revisiones.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _nivel: Node
var _spawner
var _mapa: RID
var _mob_transitorio: Node2D
var _mob_persistente: Node2D
var _punto_valido: Vector2
var _limites: Rect2

var _no_borra_a_la_primera_ok := false
var _no_borra_si_se_corrigio_ok := false
var _borra_a_la_segunda_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_cargar_nivel()
		20:
			_montar_spawner_y_mobs()
		25:
			# Primera revisión: los dos mobs están fuera de la malla.
			_spawner._revisar_mobs_fuera_de_limites()
			_no_borra_a_la_primera_ok = is_instance_valid(_mob_transitorio) and is_instance_valid(_mob_persistente)
			print("Fuera de la malla una sola vez, ninguno se borra todavía (esperado true): %s" % \
				_no_borra_a_la_primera_ok)
			# El "transitorio" se corrige solo antes de la próxima revisión
			# (simula que ya terminó de cruzar la esquina/evitar algo).
			_mob_transitorio.global_position = _punto_valido
		26:
			# Segunda revisión: transitorio ya está adentro, persistente sigue afuera.
			_spawner._revisar_mobs_fuera_de_limites()
			_no_borra_si_se_corrigio_ok = is_instance_valid(_mob_transitorio)
			print("El que se corrigió solo NO se borra (esperado true): %s" % _no_borra_si_se_corrigio_ok)
		30:
			_borra_a_la_segunda_ok = not is_instance_valid(_mob_persistente)
			print("El que sigue fuera dos veces seguidas SÍ se borra (esperado true): %s" % \
				_borra_a_la_segunda_ok)
			return _informar()
	return false


func _cargar_nivel() -> void:
	_nivel = (load("res://escenas/niveles/NivelPradera.tscn") as PackedScene).instantiate()
	root.add_child(_nivel)
	current_scene = _nivel
	_mapa = _nivel.mapa_navegacion()


func _montar_spawner_y_mobs() -> void:
	_limites = _nivel.call("limites_camara")
	_punto_valido = NavigationServer2D.map_get_closest_point(_mapa, _limites.position + _limites.size / 2.0)

	_spawner = (load("res://escenas/enemigos/SpawnerMobs.gd") as GDScript).new()
	var mobs: Array[PackedScene] = [load("res://escenas/enemigos/EnemigoRaton.tscn")]
	_spawner.lista_mobs = mobs
	_spawner.maximo_mobs = 10
	_spawner.cantidad_inicial = 0
	_nivel.get_node("Enemigos").add_child(_spawner)
	_spawner.global_position = _punto_valido
	# limpieza_fuera_de_limites_activa default TEMPORALMENTE en false (ver
	# el comentario grande en SpawnerMobs.gd) -- esta prueba sigue probando
	# el MECANISMO en sí, así que lo prende a mano acá.
	_spawner.limpieza_fuera_de_limites_activa = true

	_mob_transitorio = (load("res://escenas/enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	_nivel.get_node("Enemigos").add_child(_mob_transitorio, true)
	_mob_transitorio.global_position = _limites.position - Vector2(5000, 5000)
	_spawner.get("_vivos").append(_mob_transitorio)

	_mob_persistente = (load("res://escenas/enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	_nivel.get_node("Enemigos").add_child(_mob_persistente, true)
	_mob_persistente.global_position = _limites.position - Vector2(5000, 5000)
	_spawner.get("_vivos").append(_mob_persistente)


func _informar() -> bool:
	var exito := _no_borra_a_la_primera_ok and _no_borra_si_se_corrigio_ok and _borra_a_la_segunda_ok
	print("PRUEBA SPAWNER FUERA DE LIMITES REQUIERE DOS REVISIONES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
