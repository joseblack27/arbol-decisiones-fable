extends SlotItem
class_name EquipoSlot

@export var icon: Texture2D:
	set(value):
		icon = value
		update_item()

## 0=NINGUNO,1=CASCO,2=CUERPO,3=PANTALON,4=BOTAS,5=AMULETO,6=ANILLO,7=CINTURON,8=ARMA,9=ESCUDO
@export var type_equippable: int = 0

func update_item():
	if item_data:
		$Icon.texture = item_data.icon
	elif icon:
		$Icon.texture = icon
	else:
		$Icon.texture = null

func _can_drop_data(_position, data) -> bool:
	if data.item_data == null:
		return false
	if item_data and data.item_data.type_equippable != item_data.type_equippable:
		return false
	return data.item_data.type_equippable == type_equippable

func _drop_data(_position, data):
	if data == self:
		return
	var item: DatosItem = data.item_data
	if item == null:
		return
	var item_anterior := item_data
	item_data = item
	# El setter de item_data (heredado de SlotItem) copia can_equip desde el
	# DatosItem — que para un equipable es SIEMPRE true. Sin esto, un ítem
	# equipado por arrastre queda con el botón "Equipar" habilitado si volvés
	# a abrir su detalle; presionarlo entonces lo "reequipa consigo mismo" y
	# lo duplica en GestorInventario sin sacarlo del slot (ver bug reportado).
	can_equip = false

	if data is EquipoSlot:
		# Intercambio directo entre dos slots de equipo: ninguno de los dos
		# pasa por el inventario general, así que GestorInventario no se toca.
		data.item_data = item_anterior
		data.can_equip = false
		data.update_item()
	else:
		# Viene del inventario general: deja de estar "suelto" ahí — si no
		# se saca de GestorInventario aquí, reaparecería duplicado la
		# próxima vez que la lista se reconstruya (sigue en el autoload
		# aunque su slot de la UI ya se haya destruido). Si había algo
		# puesto en este slot, vuelve al inventario.
		var panel := _obtener_panel_inventario()
		GestorInventario.quitar_item(item)
		if item_anterior != null:
			# silencioso=true: el ítem que traías puesto vuelve al
			# inventario, no es botín nuevo — bug reportado: al desequipar
			# aparecía la notificación como si hubiera llegado equipo nuevo.
			GestorInventario.agregar_item(item_anterior, -1, true)
		if panel:
			panel.refrescar()

	slot_dragging.emit(false, item_data.type_equippable)
	update_item()
	_notificar_equipo_cambiado()


## El equipo cambió por arrastre directo (sin pasar por
## PanelInventario._equip_item()) — avisarle igual para que recalcule bonos.
func _notificar_equipo_cambiado() -> void:
	var panel := _obtener_panel_inventario()
	if panel and panel.has_method("notificar_equipo_cambiado"):
		panel.notificar_equipo_cambiado()


## Red de seguridad final: soltar un ítem equipado en cualquier lugar que
## NINGÚN _can_drop_data haya aceptado (otro EquipoSlot de otro tipo — el
## anillo reportado —, un ítem de otro tipo en la grilla general, el fondo
## del panel, fuera de la ventana...) debe desequiparlo igual, sin importar
## dónde. Depender de que el rechazo "burbujee" hacia un padre que sí lo
## acepte NO es confiable acá: mouse_filter por defecto es STOP en todo
## Control, así que un hijo que rechaza el drop corta la cadena ahí mismo
## en vez de dejar que el padre lo intente — confirmado, no es solo lectura
## de código (ver https://github.com/godotengine/godot/issues/104609 y la
## documentación de mouse_filter). NOTIFICATION_DRAG_END sí llega siempre,
## pero a TODOS los controles del árbol (no solo al que arrancó el
## arrastre) — arrastrando_ahora (ver SlotItem._get_drag_data) es lo que
## permite confirmar que ESTE fue el slot que se estaba arrastrando antes
## de reaccionar. Reportado dos veces: "trate de mover el sombrero al
## inventario sobre un anillo y no se desequipó" / "arrastro desde un
## equiposlot hacia el flowItems... sin importar donde caiga... y no se
## desequipó".
func _notification(what):
	if what != NOTIFICATION_DRAG_END:
		return
	modulate = Color(1, 1, 1, 1)
	var era_mi_arrastre := arrastrando_ahora == self
	super._notification(what)
	if era_mi_arrastre and item_data != null and not get_viewport().gui_is_drag_successful():
		_desequipar()


## Extraído de _notification para poder probarlo directo, sin depender de
## gui_is_drag_successful() (solo tiene sentido durante un arrastre real de
## mouse, no en una prueba headless que llama a las funciones sin pasar por
## el sistema de arrastre de Godot).
func _desequipar() -> void:
	var item := item_data
	item_data = null
	update_item()
	# silencioso=true: mismo criterio que arriba en _drop_data — desequipar
	# no es botín nuevo, no debe disparar la notificación de "recibiste".
	GestorInventario.agregar_item(item, -1, true)
	var panel := _obtener_panel_inventario()
	if panel:
		panel.refrescar()
	_notificar_equipo_cambiado()
