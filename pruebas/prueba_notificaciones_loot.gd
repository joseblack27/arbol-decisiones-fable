# =============================================================================
# Prueba de PanelNotificacionesLoot:
#   1. Al emitir BusEventos.item_agregado, aparece una fila nueva en la lista.
#   2. Varios ítems seguidos generan varias filas (una debajo de otra, en
#      orden de llegada) — no reemplazan a las anteriores.
#   3. Toda la fila (y el panel) es no-interactuable: mouse_filter=IGNORE
#      en el contenedor raíz y en cada pieza de la fila.
#   4. Cada fila se autodestruye sola pasado su tiempo (no hace falta que
#      nadie más la limpie).
#   godot --headless --path . --script res://pruebas/prueba_notificaciones_loot.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _panel: Node
var _item: DatosItem
var _bus: Node


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_bus.emit_signal("item_agregado", _item, 3)
		3:
			print("Filas tras 1 emisión (esperado 1): %d" % _panel.get_child_count())
			_bus.emit_signal("item_agregado", _item, 1)
			_bus.emit_signal("item_agregado", _item, 5)
		4:
			print("Filas tras 2 emisiones más (esperado 3): %d" % _panel.get_child_count())
			return _informar()
	return false


func _montar() -> void:
	_bus = root.get_node("/root/BusEventos")
	_item = DatosItem.new()
	_item.name = "Poción"
	_item.type = 2

	_panel = (load("res://escenas/ui/notificaciones_loot/PanelNotificacionesLoot.tscn") as PackedScene).instantiate()
	root.add_child(_panel)


func _informar() -> bool:
	var filas := _panel.get_child_count()
	var mouse_filter_panel: int = _panel.get("mouse_filter")
	var fila: Node = _panel.get_child(0)
	var mouse_filter_fila: int = fila.get("mouse_filter")

	print("Filas totales (esperado 3): %d" % filas)
	print("Panel no interactuable (mouse_filter=2 IGNORE): %d" % mouse_filter_panel)
	print("Fila no interactuable (mouse_filter=2 IGNORE): %d" % mouse_filter_fila)

	var texto: String = fila.get_node("Margen/HBox/Texto").text
	print("Texto de la primera fila (esperado '+3 Poción'): %s" % texto)

	var exito := filas == 3 \
		and mouse_filter_panel == 2 \
		and mouse_filter_fila == 2 \
		and texto == "+3 Poción"
	print("PRUEBA NOTIFICACIONES LOOT %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
