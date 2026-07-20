# =============================================================================
# Prueba de la lista de características del panel de detalle de inventario:
#   1. Un ítem SIN bonos (bonos == null) no agrega ninguna fila.
#   2. Un ítem CON bonos agrega una fila por cada atributo != 0, con el
#      nombre a la izquierda y el valor a la derecha, y NO agrega fila para
#      los atributos en 0 (p. ej. tenacidad = 0 en este caso).
#   3. Al seleccionar otro ítem, la lista anterior se limpia (sin arrastrar
#      filas del ítem previo).
#   godot --headless --path . --script res://pruebas/prueba_caracteristicas_item.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _panel: Node
var _armadura: DatosItem
var _pocion: DatosItem


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			return _informar()
	return false


func _montar() -> void:
	_armadura = DatosItem.new()
	_armadura.name = "Armadura de Prueba"
	_armadura.type = 3  # EQUIPABLE
	_armadura.can_equip = true
	var bonos := AtributosBase.new()
	bonos.defensa = 10.0
	bonos.tenacidad = 0.0  # debe quedar fuera de la lista
	bonos.fortaleza = 5.0
	_armadura.bonos = bonos

	_pocion = DatosItem.new()
	_pocion.name = "Poción de Prueba"
	_pocion.type = 2  # CONSUMIBLE

	_panel = (load("res://escenas/ui/panel_os/paneles/inventario/PanelInventario.tscn") as PackedScene).instantiate()
	root.add_child(_panel)


func _informar() -> bool:
	var slot_armadura := (load("res://escenas/ui/panel_os/paneles/inventario/SlotItem.tscn") as PackedScene).instantiate()
	slot_armadura.item_data = _armadura
	root.add_child(slot_armadura)

	_panel._update_details(slot_armadura)
	var filas_con_bonos: int = _panel.vbox_caracteristicas.get_child_count()
	var texto_defensa := ""
	var texto_fortaleza := ""
	for fila in _panel.vbox_caracteristicas.get_children():
		var nombre: String = fila.get_child(0).text
		var valor: String = fila.get_child(1).text
		if nombre == "Defensa":
			texto_defensa = valor
		elif nombre == "Fortaleza":
			texto_fortaleza = valor
	print("Filas con bonos (esperado 2: Defensa y Fortaleza, sin Tenacidad): %d" % filas_con_bonos)
	print("Valor mostrado de Defensa (esperado '+10'): %s" % texto_defensa)
	print("Valor mostrado de Fortaleza (esperado '+5'): %s" % texto_fortaleza)

	var slot_pocion := (load("res://escenas/ui/panel_os/paneles/inventario/SlotItem.tscn") as PackedScene).instantiate()
	slot_pocion.item_data = _pocion
	root.add_child(slot_pocion)
	_panel._update_details(slot_pocion)
	var filas_sin_bonos: int = _panel.vbox_caracteristicas.get_child_count()
	print("Filas al seleccionar ítem sin bonos (esperado 0): %d" % filas_sin_bonos)

	var exito: bool = filas_con_bonos == 2 \
		and texto_defensa == "+10" \
		and texto_fortaleza == "+5" \
		and filas_sin_bonos == 0
	print("PRUEBA CARACTERISTICAS ITEM %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
