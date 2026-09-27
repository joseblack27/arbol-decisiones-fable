# =============================================================================
# Regresión (27 sep 2026): HabilidadPuestaHuevos fijaba global_position
# ANTES de add_child. Fuera del árbol eso se toma como posición LOCAL, así
# que en un nivel desplazado (el Hormiguero está a 700.000 px, ver
# GestorNiveles.desplazamiento_de_nivel) la guardiana que nace del huevo
# aparecía al DOBLE de distancia, fuera del mapa — viva, inalcanzable y
# dándole resistencia a la Reina. Las pruebas anteriores usaban un
# contenedor en el origen, donde el bug no se nota.
#
# Confirma, con el contenedor desplazado como en un nivel real:
#   1. Los huevos nacen en la posición global de la Reina (antes de volar).
#   2. La guardiana nace en la posición global exacta del huevo — pedido del
#      usuario: "quiero que las hormigas que eclosionan de las larvas
#      aparezcan en las mismas posiciones de las larvas".
#   3. El huevo se libera al eclosionar.
#   godot --headless --path . --script res://pruebas/prueba_puesta_huevos_posicion_en_nivel_desplazado.gd
# =============================================================================
extends SceneTree

const _DESPLAZAMIENTO := Vector2(700000.0, 0.0)

var _f := 0
var _contenedor: Node2D
var _reina
var _habilidad
var _resultados: Dictionary = {}


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		3:
			_probar()
			return _informar()
	return false


func _montar() -> void:
	var nivel := Node2D.new()
	nivel.position = _DESPLAZAMIENTO
	_contenedor = Node2D.new()
	_contenedor.name = "Enemigos"
	nivel.add_child(_contenedor)
	root.add_child(nivel)
	current_scene = nivel

	_reina = (load("res://escenas/enemigos/EnemigoReinaHormigas.tscn") as PackedScene).instantiate()
	_contenedor.add_child(_reina)
	_reina.global_position = _DESPLAZAMIENTO + Vector2(200.0, 100.0)
	_habilidad = _reina.get_node("Habilidades/HabilidadPuestaHuevos")


func _probar() -> void:
	_habilidad._ejecutar(Vector2.ZERO, 1.0)
	var huevos: Array = _habilidad._huevos_activos.duplicate()
	var todos_en_la_reina := not huevos.is_empty()
	for huevo in huevos:
		todos_en_la_reina = todos_en_la_reina \
			and huevo.global_position.is_equal_approx(_reina.global_position)
	_anotar("1. los huevos nacen en la posición global de la Reina (reina=%s, primer huevo=%s)" % [
		_reina.global_position, huevos[0].global_position if not huevos.is_empty() else "ninguno"],
		todos_en_la_reina)

	var huevo = huevos[0]
	huevo.global_position = _DESPLAZAMIENTO + Vector2(260.0, 140.0)
	var pos_huevo: Vector2 = huevo.global_position
	_habilidad._eclosionar(huevo, _contenedor)
	var guardian = _habilidad._guardianes_vivos[0] if not _habilidad._guardianes_vivos.is_empty() else null
	_anotar("2. la guardiana nace en la posición global exacta del huevo (huevo=%s, guardiana=%s)" % [
		pos_huevo, guardian.global_position if guardian else "ninguna"],
		guardian != null and guardian.global_position.is_equal_approx(pos_huevo))
	_anotar("3. el huevo se libera al eclosionar", huevo.is_queued_for_deletion())


func _anotar(nombre: String, ok: bool) -> void:
	_resultados[nombre] = ok
	print("%s (esperado true): %s" % [nombre, ok])


func _informar() -> bool:
	var exito := _resultados.size() == 3
	for ok in _resultados.values():
		exito = exito and ok
	print("PRUEBA PUESTA HUEVOS POSICION EN NIVEL DESPLAZADO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
