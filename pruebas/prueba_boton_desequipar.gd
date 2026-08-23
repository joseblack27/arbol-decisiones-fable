# =============================================================================
# Prueba: el botón de acción principal del detalle ya desequipaba de verdad
# un ítem EQUIPADO (PanelInventario._on_drop_button, item_data_details is
# EquipoSlot) pero decía "Soltar" para cualquier ítem — reportado: "necesito
# que agregues la accion de desequipar en los objetos que ya estan
# equipados", sin saber que ya existía bajo ese nombre confuso. Ahora dice
# "Desequipar" cuando el ítem seleccionado está puesto, y sigue diciendo
# "Soltar" para un ítem suelto del inventario general.
#
# Verifica:
#   1. Click en un ítem EQUIPADO -> el botón dice "Desequipar" y está visible.
#   2. Click en un ítem SUELTO (inventario general) -> el botón sigue
#      diciendo "Soltar".
#   3. Presionarlo sobre el ítem equipado lo desequipa de verdad (ya
#      cubierto por prueba_inventario_equipar.gd, se reconfirma acá junto
#      con el texto para no perder de vista que ambas cosas van juntas).
#   4. Bug real reportado: "cuando me desequipo un objeto... se ve la
#      notificación como si hubiera recibido equipo nuevo, no quiero que
#      salga ahí" — desequipar NO debe emitir BusEventos.item_agregado (la
#      notificación de botín), pero SÍ debe emitir inventario_cambiado (para
#      que la grilla igual se refresque).
#   godot --headless --path . --script res://pruebas/prueba_boton_desequipar.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _panel: Node
var _gestor: Node
var _armadura: DatosItem
var _pocion: DatosItem

var _dice_desequipar_en_equipado := false
var _visible_en_equipado := false
var _dice_soltar_en_suelto := false
var _desequipa_al_presionar := false
var _no_dispara_notificacion_botin := false
var _dispara_inventario_cambiado := false

var _contador_item_agregado := 0
var _contador_antes_desequipar := 0
var _inventario_cambiado_disparo := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			var slot_armadura := _buscar_slot_de(_panel.flow, _armadura)
			_panel._equip_item(slot_armadura)
		3:
			_panel._on_slot_clicked(_panel.equip_slot_body)
			_dice_desequipar_en_equipado = _panel.drop_action_button.text == "Desequipar"
			_visible_en_equipado = _panel.drop_action_button.visible
			print("Dice 'Desequipar' con un ítem equipado seleccionado (esperado true): %s" % \
				_dice_desequipar_en_equipado)
			print("El botón está visible (esperado true): %s" % _visible_en_equipado)

			var slot_pocion := _buscar_slot_de(_panel.flow, _pocion)
			_panel._on_slot_clicked(slot_pocion)
			_dice_soltar_en_suelto = _panel.drop_action_button.text == "Soltar"
			print("Sigue diciendo 'Soltar' con un ítem suelto seleccionado (esperado true): %s" % \
				_dice_soltar_en_suelto)

			# Volver a seleccionar la armadura equipada y presionar el botón.
			_panel._on_slot_clicked(_panel.equip_slot_body)
			_contador_antes_desequipar = _contador_item_agregado
			_inventario_cambiado_disparo = false
			_panel._on_drop_button()
		4:
			_desequipa_al_presionar = _panel.equip_slot_body.item_data == null \
				and _contar_en_lista(_gestor.items, "Armadura de Prueba") == 1
			print("Presionarlo desequipa de verdad, sin duplicar (esperado true): %s" % _desequipa_al_presionar)
			_no_dispara_notificacion_botin = _contador_item_agregado == _contador_antes_desequipar
			print("Desequipar NO dispara la notificacion de botin (esperado true): %s" % _no_dispara_notificacion_botin)
			_dispara_inventario_cambiado = _inventario_cambiado_disparo
			print("Desequipar SI dispara inventario_cambiado (esperado true): %s" % _dispara_inventario_cambiado)
			return _informar()
	return false


func _montar() -> void:
	_gestor = root.get_node("/root/GestorInventario")
	_gestor.items.clear()

	_armadura = DatosItem.new()
	_armadura.name = "Armadura de Prueba"
	_armadura.type = 3            # EQUIPABLE
	_armadura.type_equippable = 2  # CUERPO
	_armadura.can_equip = true
	_armadura.can_drop = true

	_pocion = DatosItem.new()
	_pocion.name = "Poción de Prueba"
	_pocion.type = 2  # CONSUMIBLE
	_pocion.can_use = true
	_pocion.can_drop = true

	_gestor.agregar_item(_armadura)
	_gestor.agregar_item(_pocion)

	_panel = (load("res://escenas/ui/panel_os/paneles/inventario/PanelInventario.tscn") as PackedScene).instantiate()
	root.add_child(_panel)

	var bus := root.get_node("/root/BusEventos")
	bus.item_agregado.connect(func(_item, _cantidad): _contador_item_agregado += 1)
	bus.inventario_cambiado.connect(func(): _inventario_cambiado_disparo = true)


## Busca por NOMBRE, no por referencia: GestorInventario.agregar_item()
## duplica el recurso de los equipables antes de guardarlo.
func _buscar_slot_de(flow: Node, item: DatosItem) -> Node:
	for hijo in flow.get_children():
		if hijo.item_data and hijo.item_data.name == item.name:
			return hijo
	return null


func _contar_en_lista(items: Array, nombre: String) -> int:
	var cuenta := 0
	for i in items:
		if i.name == nombre:
			cuenta += 1
	return cuenta


func _informar() -> bool:
	var exito := _dice_desequipar_en_equipado and _visible_en_equipado \
		and _dice_soltar_en_suelto and _desequipa_al_presionar \
		and _no_dispara_notificacion_botin and _dispara_inventario_cambiado
	print("PRUEBA BOTON DESEQUIPAR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
