# =============================================================================
# Prueba: el color del {damage1} en la descripción de una habilidad sale del
# ELEMENTO real (DatosHabilidad.tipo_dano) vía Enums.Habilidad.
# valor_color_dano — ya no de un [color=...] pegado a mano en cada .tres
# (varios habían quedado desincronizados: Ráfaga es AIRE pero se pintaba con
# el cyan de AGUA; Golpe Básico/Carga/Muro son FÍSICO pero usaban colores de
# otros elementos — con el color derivado del mismo dato que el gameplay,
# es imposible que se desincronicen de nuevo).
#   godot --headless --path . --script res://pruebas/prueba_color_dano_descripcion.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _panel_detalle: Node


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 2:
		return _informar()
	if _fotogramas == 1:
		_montar()
	return false


func _montar() -> void:
	var panel := (load("res://escenas/ui/panel_os/paneles/habilidades/PanelHabilidades.tscn") as PackedScene).instantiate()
	root.add_child(panel)
	current_scene = panel
	_panel_detalle = panel.get_node("MarginContainer/VBoxContainer/TabContainer/TabActivas/HBoxContainer/PanelDetalle")


func _informar() -> bool:
	var desc_label: RichTextLabel = _panel_detalle.get("description_label")
	var casos := [
		[Enums.Habilidad.TipoDano.TIERRA, "#905010"],
		[Enums.Habilidad.TipoDano.FUEGO, "red"],
		[Enums.Habilidad.TipoDano.FISICO, "ghostwhite"],
		[Enums.Habilidad.TipoDano.AGUA, "#00c4ff"],
		[Enums.Habilidad.TipoDano.AIRE, "#008f39"],
	]
	var todos_ok := true
	for caso in casos:
		var tipo: Enums.Habilidad.TipoDano = caso[0]
		var color_esperado: String = caso[1]
		var datos := DatosHabilidad.new()
		datos.nombre        = "Prueba"
		datos.descripcion   = "Pega {damage1}"
		datos.dano_base_min = 10
		datos.dano_base_max = 10
		datos.tipo_dano     = tipo
		_panel_detalle.call("show_skill", datos)
		var esperado := "Pega [color=%s][b]10 - 10[/b][/color]" % color_esperado
		var ok := desc_label.text == esperado
		if not ok:
			todos_ok = false
		print("%s -> '%s' (esperado '%s'): %s" % [
			Enums.Habilidad.TipoDano.keys()[tipo], desc_label.text, esperado, ok,
		])

	print("PRUEBA COLOR DAÑO DESCRIPCIÓN %s" % ("OK" if todos_ok else "FALLIDA"))
	quit(0 if todos_ok else 1)
	return true
