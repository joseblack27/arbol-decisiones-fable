extends SlotItem
class_name SlotConsumibleRapido
## Casilla de la barra rápida de consumibles. Hay DOS vistas de estas mismas
## 4 casillas (la barra flotante del HUD y la fila dentro de PanelInventario,
## ver GestorBarraRapida) — esta instancia solo DIBUJA lo que hay en
## GestorBarraRapida.casillas[slot_index], nunca guarda su propio estado, así
## que arrastrar/usar desde cualquiera de las dos vistas se refleja solo en
## la otra.
##
## Asignar un ítem acá es SOLO una referencia — a diferencia de un
## EquipoSlot, NUNCA se saca de GestorInventario.items. La casilla es un
## atajo hacia un ítem que sigue estando en el inventario normal.

## Índice (0-3) dentro de GestorBarraRapida.casillas que esta casilla
## representa — hay que asignarlo distinto en cada instancia (0,1,2,3) desde
## la escena que las contiene (BarraConsumibles.tscn, PanelInventario.tscn).
@export var slot_index: int = 0

## true en la barra flotante del HUD (un toque usa el ítem directo, es la
## idea de una barra rápida en pleno combate). false en la fila dentro de
## PanelInventario: ahí un toque solo abre el detalle de siempre (mismo
## flujo que la grilla general) y hace falta el botón "Usar" — evita usar
## algo sin querer mientras estás revisando el inventario con calma.
@export var usar_al_tocar: bool = true


func _ready() -> void:
	super._ready()
	if usar_al_tocar:
		slot_clicked.connect(_on_click)
	GestorBarraRapida.casilla_cambiada.connect(_on_casilla_cambiada)
	_sincronizar()


## Segundo dedo (index > 0) con toque crudo: el "mouse emulado" de Android
## solo sigue al PRIMER dedo, así que con el joystick sostenido las casillas
## nunca recibían el tap (reportado: "cuando te mueves no puedes interactuar
## con los consumibles"). Solo en la barra flotante (usar_al_tocar): el
## primer dedo conserva el flujo normal de SlotItem (clic y arrastre).
func _input(event: InputEvent) -> void:
	if not usar_al_tocar or not visible or not is_visible_in_tree():
		return
	if not (event is InputEventScreenTouch) or not event.pressed or event.index == 0:
		return
	if not get_global_rect().has_point(event.position):
		return
	get_viewport().set_input_as_handled()
	_on_click(self)


func _sincronizar() -> void:
	item_data = GestorBarraRapida.casillas[slot_index]


func _on_casilla_cambiada(indice: int) -> void:
	if indice == slot_index:
		_sincronizar()


func _on_click(_slot: SlotItem) -> void:
	var item := GestorBarraRapida.casillas[slot_index]
	if item == null or not item.can_use:
		return
	GestorInventario.usar_item(item)
	if item.quantity <= 0:
		GestorBarraRapida.limpiar(slot_index)
	else:
		# Sigue siendo el mismo ítem (stack no agotado) — solo refrescar la
		# cantidad mostrada en ambas vistas.
		GestorBarraRapida.refrescar(slot_index)
	# La grilla general del inventario tiene su PROPIA instancia de SlotItem
	# para este mismo ítem (item_data es el mismo Resource, pero el nodo y
	# su QuantityLabel son otros) — sin refrescarla acá, esa cantidad
	# quedaba desactualizada hasta el próximo refresco por otra vía (abrir/
	# cerrar el panel, lootear algo). Usar desde "Usar" en el detalle sí
	# refrescaba (ver PanelInventario._on_use_button); usar desde acá no.
	var panel := get_tree().get_root().find_child("PanelInventario", true, false)
	if panel and panel.has_method("refrescar"):
		panel.refrescar()


func _can_drop_data(_position, data) -> bool:
	if data == self or not (data is SlotItem):
		return false
	var item: DatosItem = data.item_data
	return item != null and item.can_use


func _drop_data(_position, data) -> void:
	var item: DatosItem = data.item_data
	if item == null:
		return

	if data is SlotConsumibleRapido:
		# Intercambio entre dos casillas rápidas (misma vista o la otra):
		# ninguna toca el inventario general, solo referencias.
		var item_anterior := GestorBarraRapida.casillas[slot_index]
		GestorBarraRapida.asignar(data.slot_index, item_anterior)
		GestorBarraRapida.asignar(slot_index, item)
	else:
		# Viene de la grilla general del inventario: SOLO se guarda la
		# referencia acá, el ítem sigue estando en GestorInventario.items —
		# la casilla es un atajo, no un contenedor que lo saca de ahí.
		GestorBarraRapida.asignar(slot_index, item)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color(1, 1, 1, 1)
