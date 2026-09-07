# =============================================================================
# Bug real reportado (2 sep 2026): "mato un mob y me da como 9 objetos cuando
# un mob da como mucho 4" — la hurtbox del mob recién se desactiva en el
# PRÓXIMO frame físico (_apagar_colision_de_muerto usa set_deferred), así que
# un segundo golpe que aterriza en el MISMO frame que el golpe letal (área de
# efecto con dos fuentes, combo multi-golpe, dos proyectiles simultáneos)
# volvía a restar vida y VidaComponente.quitar_vida() emitía "muerte" DE
# NUEVO — Enemigo._on_muerte() no protegía contra reentradas, así que
# _procesar_muerte() (botín + XP) corría dos veces por la misma muerte.
#
# Verifica:
#   1. VidaComponente.muerte se emite UNA sola vez aunque lleguen dos golpes
#      letales/overkill en el mismo frame (quitar_vida() llamado dos veces
#      antes de que nada procese la primera muerte).
#   2. El botín (probabilidad 1.0, cantidad 1) llega UNA sola vez al
#      inventario, no duplicado.
#   godot --headless --path . --script res://pruebas/prueba_muerte_no_duplica_golpe_doble.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _gestor: Node
var _item: DatosItem
var _raton: Node
var _veces_muerte := 0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			# Dos golpes letales en el MISMO frame, antes de que
			# _apagar_colision_de_muerto (set_deferred) o _procesar_muerte
			# (call_deferred) hayan corrido — simula dos fuentes de daño
			# pegando a la vez (área de efecto, combo, proyectiles dobles).
			var vida := _raton.get_node("VidaComponente")
			vida.quitar_vida(9999.0)
			vida.quitar_vida(9999.0)
		4:
			return _informar()
	return false


func _montar() -> void:
	_gestor = root.get_node("/root/GestorInventario")
	_gestor.items.clear()

	_item = DatosItem.new()
	_item.name = "Poción"
	_item.type = 2  # CONSUMIBLE
	_item.quantity = 1

	_raton = (load("res://escenas/enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	root.add_child(_raton)

	var entrada := LootDrop.new()
	entrada.item = _item
	entrada.probabilidad = 1.0
	var tabla: Array[LootDrop] = [entrada]
	_raton.tabla_botin = tabla

	var vida := _raton.get_node("VidaComponente")
	vida.muerte.connect(func(_v: float) -> void: _veces_muerte += 1)


func _obtener_cantidad(nombre: String) -> int:
	for i: DatosItem in _gestor.items:
		if i.name == nombre:
			return i.quantity
	return 0


func _informar() -> bool:
	print("VidaComponente.muerte se emitió N veces (esperado 1): %d" % _veces_muerte)
	var cantidad := _obtener_cantidad("Poción")
	print("Cantidad de 'Poción' en el inventario (esperado 1, no duplicado): %d" % cantidad)

	var exito := _veces_muerte == 1 and cantidad == 1
	print("PRUEBA MUERTE NO DUPLICA GOLPE DOBLE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
