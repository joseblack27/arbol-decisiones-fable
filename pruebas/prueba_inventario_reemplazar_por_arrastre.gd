# =============================================================================
# Prueba del pedido del usuario: al arrastrar un ítem EQUIPADO hacia el
# inventario general, si se suelta justo sobre un ítem del MISMO tipo
# equipable, ese ítem pasa a equipado (reemplazo) y el que estaba puesto
# vuelve al inventario. En cualquier OTRO caso (tipo distinto, vacío, el
# fondo del panel, otro slot de equipo que no coincide como un anillo...)
# simplemente se desequipa, sin importar dónde se soltó.
#
# MECANISMO REAL (por qué esto necesitó dos vueltas): Godot NO hace
# "burbujear" _can_drop_data/_drop_data hacia el padre cuando el control
# bajo el mouse lo rechaza — depende de mouse_filter, y el valor por
# defecto (STOP) corta la cadena ahí mismo (confirmado, no solo lectura de
# código: https://github.com/godotengine/godot/issues/104609 y la
# documentación de mouse_filter/MOUSE_FILTER_PASS). Por eso un intento
# anterior (mirar la posición del drop desde FlujoItems, o un "catch-all"
# en la raíz de PanelInventario) nunca llegaba a ejecutarse de verdad en el
# juego real, aunque la prueba "pasara" (llamaba a _drop_data() directo,
# sin pasar por el sistema de arrastre de Godot).
#   - SlotItem._can_drop_data/_drop_data: cada celda de la grilla general
#     acepta y actúa POR SÍ MISMA si el ítem que tiene coincide en
#     type_equippable con el que se está soltando -> reemplazo real.
#   - EquipoSlot._notification(NOTIFICATION_DRAG_END): red de seguridad
#     final -- si el arrastre terminó sin que NADA lo aceptara
#     (Viewport.gui_is_drag_successful() == false) y el slot de origen
#     sigue con su item_data (nadie se lo sacó), desequipa.
#     _desequipar() es esa misma lógica extraída a una función aparte para
#     poder probarla sin depender de un arrastre real de mouse (headless no
#     tiene un Viewport con un arrastre en curso).
#
# Verifica:
#   1. SlotItem._can_drop_data acepta SOLO si coincide el type_equippable.
#   2. SlotItem._drop_data reemplaza correctamente (sin duplicar en
#      GestorInventario) cuando sí coincide.
#   3. EquipoSlot._desequipar() (la red de seguridad final) desequipa y
#      actualiza GestorInventario sin duplicar para el caso "no hubo
#      reemplazo válido" (mismo caso que el anillo reportado).
#   4. Bug real reportado: "tengo el escudo equipado y lo arrastro hacia
#      donde está la lista de ítems y lo suelto" -> aparecía la
#      notificación de botín. Ese drop cae en FlujoItems._drop_data (fondo
#      del panel, sin ningún SlotItem hijo debajo) — a ese call site
#      también le faltaba silencioso=true.
#   godot --headless --path . --script res://pruebas/prueba_inventario_reemplazar_por_arrastre.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _panel: Node
var _gestor: Node
var _bus: Node
var _armadura_a: DatosItem
var _armadura_b: DatosItem
var _casco: DatosItem

var _no_acepta_tipo_distinto := false
var _acepta_mismo_tipo := false
var _reemplaza_por_mismo_tipo := false
var _armadura_vieja_vuelve_al_inventario_sin_duplicar := false
var _desequipa_por_red_de_seguridad := false
var _sin_duplicar_tras_desequipar_por_red_de_seguridad := false
var _flujo_items_desequipa_sin_duplicar := false
var _flujo_items_no_dispara_notificacion_botin := false

var _contador_item_agregado := 0
var _contador_antes_de_soltar_en_flujo := 0


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			# Equipar Armadura A por botón — queda puesta en equip_slot_body.
			var slot_a := _buscar_slot_de(_panel.flow, _armadura_a)
			_panel._equip_item(slot_a)
		3:
			var slot_armadura_b := _buscar_slot_de(_panel.flow, _armadura_b)
			var slot_casco := _buscar_slot_de(_panel.flow, _casco)
			_no_acepta_tipo_distinto = not slot_casco._can_drop_data(Vector2.ZERO, _panel.equip_slot_body)
			_acepta_mismo_tipo = slot_armadura_b._can_drop_data(Vector2.ZERO, _panel.equip_slot_body)
			print("La celda del casco (otro tipo) rechaza el drop (esperado true): %s" % _no_acepta_tipo_distinto)
			print("La celda de Armadura B (mismo tipo) acepta el drop (esperado true): %s" % _acepta_mismo_tipo)

			# Soltar Armadura A (equipada) sobre la celda de Armadura B
			# (mismo type_equippable=CUERPO) -> reemplazo real.
			slot_armadura_b._drop_data(Vector2.ZERO, _panel.equip_slot_body)
		4:
			_reemplaza_por_mismo_tipo = _panel.equip_slot_body.item_data != null \
				and _panel.equip_slot_body.item_data.name == "Armadura B"
			_armadura_vieja_vuelve_al_inventario_sin_duplicar = \
				_contar_en_lista(_gestor.items, "Armadura A") == 1
			print("Reemplaza por el ítem del mismo tipo bajo el cursor (esperado true): %s" % _reemplaza_por_mismo_tipo)
			print("La armadura vieja vuelve al inventario sin duplicar (esperado true, 1 copia): %s" % \
				_armadura_vieja_vuelve_al_inventario_sin_duplicar)

			# Ahora Armadura B quedó equipada. Simular el caso reportado
			# (soltar sobre un anillo, o cualquier otro punto que ningún
			# _can_drop_data haya aceptado): el arrastre termina sin
			# resolverse, y la red de seguridad final debe desequipar.
			_panel.equip_slot_body._desequipar()
		5:
			_desequipa_por_red_de_seguridad = _panel.equip_slot_body.item_data == null
			_sin_duplicar_tras_desequipar_por_red_de_seguridad = _contar_en_lista(_gestor.items, "Armadura B") == 1
			print("La red de seguridad desequipa cuando nada más aceptó el drop (esperado true): %s" % \
				_desequipa_por_red_de_seguridad)
			print("Sin duplicar tras desequipar por la red de seguridad (esperado true, 1 copia): %s" % \
				_sin_duplicar_tras_desequipar_por_red_de_seguridad)

			# Caso del bug reportado: casco equipado, soltado directo en el
			# fondo de FlujoItems (sin ningún SlotItem hijo debajo) — llama a
			# _drop_data() del contenedor directo, como haría Godot cuando el
			# drop no cae sobre ninguna celda.
			var slot_casco := _buscar_slot_de(_panel.flow, _casco)
			_panel._equip_item(slot_casco)
		6:
			_contador_antes_de_soltar_en_flujo = _contador_item_agregado
			_panel.flow._drop_data(Vector2.ZERO, _panel.equip_slot_helmet)
		7:
			_flujo_items_desequipa_sin_duplicar = _panel.equip_slot_helmet.item_data == null \
				and _contar_en_lista(_gestor.items, "Casco de Prueba") == 1
			print("Soltar en el fondo de FlujoItems desequipa sin duplicar (esperado true): %s" % \
				_flujo_items_desequipa_sin_duplicar)
			_flujo_items_no_dispara_notificacion_botin = \
				_contador_item_agregado == _contador_antes_de_soltar_en_flujo
			print("Soltar en el fondo de FlujoItems NO dispara la notificacion de botin (esperado true): %s" % \
				_flujo_items_no_dispara_notificacion_botin)
			return _informar()
	return false


func _montar() -> void:
	_gestor = root.get_node("/root/GestorInventario")
	_gestor.items.clear()

	_armadura_a = DatosItem.new()
	_armadura_a.name = "Armadura A"
	_armadura_a.type = 3            # EQUIPABLE
	_armadura_a.type_equippable = 2  # CUERPO
	_armadura_a.can_equip = true

	_armadura_b = DatosItem.new()
	_armadura_b.name = "Armadura B"
	_armadura_b.type = 3
	_armadura_b.type_equippable = 2  # CUERPO, mismo tipo que la A.
	_armadura_b.can_equip = true

	_casco = DatosItem.new()
	_casco.name = "Casco de Prueba"
	_casco.type = 3
	_casco.type_equippable = 1  # CASCO, tipo distinto.
	_casco.can_equip = true

	_gestor.agregar_item(_armadura_a)
	_gestor.agregar_item(_armadura_b)
	_gestor.agregar_item(_casco)

	_panel = (load("res://escenas/ui/panel_os/paneles/inventario/PanelInventario.tscn") as PackedScene).instantiate()
	root.add_child(_panel)

	_bus = root.get_node("/root/BusEventos")
	_bus.item_agregado.connect(func(_item, _cantidad): _contador_item_agregado += 1)


## Busca por NOMBRE, no por referencia: GestorInventario.agregar_item()
## duplica el recurso de los equipables antes de guardarlo, así que el
## objeto en la grilla nunca es el mismo que el que se creó acá (mismo
## criterio que prueba_inventario_equipar.gd).
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
	var exito := _no_acepta_tipo_distinto and _acepta_mismo_tipo \
		and _reemplaza_por_mismo_tipo and _armadura_vieja_vuelve_al_inventario_sin_duplicar \
		and _desequipa_por_red_de_seguridad and _sin_duplicar_tras_desequipar_por_red_de_seguridad \
		and _flujo_items_desequipa_sin_duplicar and _flujo_items_no_dispara_notificacion_botin
	print("PRUEBA INVENTARIO REEMPLAZAR POR ARRASTRE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
