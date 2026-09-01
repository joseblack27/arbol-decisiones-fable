# =============================================================================
# Dos pedidos explícitos del usuario (1 sep 2026) sobre el panel de detalle
# del inventario:
#   1. Al equipar un ítem (por botón "Equipar"), el panel de detalle debe
#      CERRARSE — antes quedaba abierto mostrando la referencia VIEJA
#      (item_data_details), así que si el ítem era de un CONJUNTO, la
#      cuenta "X/N piezas equipadas" se congelaba con el valor de ANTES de
#      poner esta pieza. Cerrarlo fuerza a recalcularla de cero la próxima
#      vez que se abra cualquier detalle.
#   2. El detalle de un ítem con conjunto debe decir QUÉ otorga cada tramo
#      (antes solo se veía "(2/4)" sin decir qué bono da), no solo cuántas
#      piezas hacen falta.
#   godot --headless --path . --script res://pruebas/prueba_equipar_cierra_detalle.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _panel: Node
var _gestor: Node
var _casco: DatosItem
var _pechera: DatosItem

var _cierra_panel_al_equipar_ok := false
var _texto_bonos_tramo_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_probar_equipar_cierra_detalle()
			_probar_texto_de_bonos_por_tramo()
			return _informar()
	return false


func _montar() -> void:
	_gestor = root.get_node("/root/GestorInventario")
	_gestor.items.clear()

	var conjunto := ConjuntoDatos.new()
	conjunto.nombre = "Conjunto de Prueba"
	var tramo_2 := TramoConjunto.new()
	tramo_2.piezas_requeridas = 2
	tramo_2.bonos = AtributosBase.new()
	tramo_2.bonos.defensa = 5.0
	tramo_2.bonos.resistencia_tierra = 10.0
	conjunto.tramos = [tramo_2]

	_casco = DatosItem.new()
	_casco.name = "Casco de Prueba"
	_casco.type = 3  # EQUIPABLE
	_casco.type_equippable = 1  # CASCO
	_casco.can_equip = true
	_casco.conjunto = conjunto

	_pechera = DatosItem.new()
	_pechera.name = "Pechera de Prueba"
	_pechera.type = 3
	_pechera.type_equippable = 2  # CUERPO
	_pechera.can_equip = true
	_pechera.conjunto = conjunto

	_gestor.agregar_item(_casco)
	_gestor.agregar_item(_pechera)

	_panel = (load("res://escenas/ui/panel_os/paneles/inventario/PanelInventario.tscn") as PackedScene).instantiate()
	root.add_child(_panel)


func _probar_equipar_cierra_detalle() -> void:
	var slot_casco := _buscar_slot_de(_panel.flow, _casco)
	_panel._on_slot_clicked(slot_casco)
	var abierto_antes: bool = _panel.detail_panel_margin.visible and _panel.item_data_details == slot_casco
	_panel._equip_item(slot_casco)
	_cierra_panel_al_equipar_ok = abierto_antes and not _panel.detail_panel_margin.visible \
		and _panel.item_data_details == null
	print("El detalle se cierra al equipar (esperado true — abierto_antes=%s, cerrado_despues=%s, referencia_limpia=%s): %s" % [
		abierto_antes, not _panel.detail_panel_margin.visible, _panel.item_data_details == null, _cierra_panel_al_equipar_ok])


## Con el casco ya puesto (dejó _probar_equipar_cierra_detalle arriba),
## equipar la pechera completa las 2 piezas del conjunto — el detalle de
## CUALQUIERA de las dos piezas tiene que mostrar el tramo de 2 piezas
## activo (✓) y el texto de qué otorga ("+5 Defensa, +10 Resist. Tierra").
func _probar_texto_de_bonos_por_tramo() -> void:
	var slot_pechera := _buscar_slot_de(_panel.flow, _pechera)
	_panel._equip_item(slot_pechera)

	_panel._on_slot_clicked(_panel.equip_slot_helmet)
	# El nombre del conjunto ahora vive arriba (junto a Tipo/Cantidad), no
	# como título dentro de la lista — ver PanelInventario.conjunto_label/
	# conjunto_value.
	var nombre_arriba_ok: bool = _panel.conjunto_label.visible and _panel.conjunto_value.text == "Conjunto de Prueba"
	var filas: Array = _panel.vbox_caracteristicas.get_children()
	# Fila 0 = espaciador (Control), fila 1 = "2 piezas | ✓", filas 2 y 3 =
	# una POR CADA bono del tramo (pedido: "colocar en lista las
	# bonificaciones") — todas HBoxContainer DIRECTOS, sin sangría, pegadas
	# a la izquierda igual que las estadísticas propias del ítem (pedido
	# explícito tras ver una sangría de 12px agregada en la vuelta anterior).
	var sin_sangria_ok: bool = filas.size() > 1 and not (filas[1] is MarginContainer)
	var fila_estado: HBoxContainer = filas[1] if filas.size() > 1 else null
	var texto_estado: String = (fila_estado.get_child(1) as Label).text if fila_estado else ""
	var fila_defensa: HBoxContainer = filas[2] if filas.size() > 2 else null
	var nombre_defensa: String = (fila_defensa.get_child(0) as Label).text if fila_defensa else ""
	var valor_defensa: String = (fila_defensa.get_child(1) as Label).text if fila_defensa else ""
	var fila_resistencia: HBoxContainer = filas[3] if filas.size() > 3 else null
	var nombre_resistencia: String = (fila_resistencia.get_child(0) as Label).text if fila_resistencia else ""
	var valor_resistencia: String = (fila_resistencia.get_child(1) as Label).text if fila_resistencia else ""
	_texto_bonos_tramo_ok = nombre_arriba_ok and sin_sangria_ok and filas.size() == 4 and texto_estado == "✓" \
		and nombre_defensa == "Defensa" and valor_defensa == "+5" \
		and nombre_resistencia == "Resist. Tierra" and valor_resistencia == "+10"
	print("Con 2/2 piezas puestas, cada bono del tramo tiene su propia fila indentada, y el nombre del conjunto aparece arriba (esperado true, obtenido '%s'=%s '%s'=%s): %s" % [
		nombre_defensa, valor_defensa, nombre_resistencia, valor_resistencia, _texto_bonos_tramo_ok])


func _buscar_slot_de(flow: Node, item: DatosItem) -> Node:
	for hijo in flow.get_children():
		if hijo.item_data and hijo.item_data.name == item.name:
			return hijo
	return null


func _informar() -> bool:
	var exito := _cierra_panel_al_equipar_ok and _texto_bonos_tramo_ok
	print("PRUEBA EQUIPAR CIERRA DETALLE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
