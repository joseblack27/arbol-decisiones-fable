extends Control
class_name CasillaObjeto
## Casilla genérica para una GrillaObjetos — visual idéntico a SlotItem,
## pero SIN su lógica de equipar/reemplazar por tipo: acá el arrastre es
## un movimiento simple entre dos colecciones, sin más reglas. Pedido del
## usuario: "el inventario que se mostraria aqui no debe tener la misma
## funcionalidad que el inventario del OS... si se arrastra de un lado a
## otro lo quita de uno y lo agrega en el otro".
##
## Acepta drops de OTRAS casillas (con o sin la misma grilla dueña) además
## de ser origen de arrastre — el ScrollContainerObjetos de la grilla (ver
## ese archivo) acepta el hueco vacío alrededor/debajo de las casillas,
## pero una casilla individual cubre casi toda el área visible, así que
## TAMBIÉN necesita aceptar el drop ella misma: Control.mouse_filter (STOP
## por defecto) no burbujea hacia el padre cuando el control bajo el
## cursor no implementa _can_drop_data (equivale a un rechazo silencioso)
## — sin este override, soltar sobre CUALQUIER casilla nunca llegaría al
## ScrollContainer de abajo. La lógica real de "hacer algo o no" vive en
## GrillaObjetos.recibir_desde() (compartida con ScrollContainerObjetos):
## soltar dentro de la MISMA grilla no hace nada — pedido del usuario:
## "que se pueda soltar encima de los mismos objetos, pero... si el padre
## o la escena que lo contiene es diferente a donde se suelta, mande la
## señal para que lo agregue, así no permite que si agarras un item y lo
## sueltas ahí mismo, se añada de nuevo al final".
##
## "fuente" (ver FuenteObjetos) es quien de verdad persiste el cambio —
## GrillaObjetos.recibir_desde() llama agregar()/quitar() sobre la fuente
## de CADA lado, nunca muta ninguna colección directo. "grilla_dueña" es a
## quién avisarle que se reconstruya (ver GrillaObjetos.notificar_cambio):
## NUNCA se busca ningún panel por nombre en el árbol — ese patrón
## (get_tree().get_root().find_child(...)) fue la causa real de dos bugs
## de "self" destruido a mitad de un método, encontrados y corregidos en
## SlotItem.gd esta misma sesión.

signal tocada(item: DatosItem)

## Ventana para contar dos toques seguidos como doble-tap (ver _procesar_
## tap) — NO se usa InputEventMouseButton.double_click: en touch emulado
## (el juego es 100% táctil, sin mouse real) ese flag es poco confiable
## (issue conocido de Godot). Se mide a mano contra el reloj.
const _VENTANA_DOBLE_TAP_MS := 350

@export var item_data: DatosItem:
	set(value):
		item_data = value
		_actualizar_visual()
	get:
		return item_data

var fuente: FuenteObjetos = null
var grilla_dueña: GrillaObjetos = null

var _arrastrando := false
static var _arrastrando_ahora: CasillaObjeto = null
var _ultimo_tap_msec: int = -1000000


func _ready() -> void:
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			_arrastrando = false
		elif event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
			if not _arrastrando:
				_procesar_tap()


## Pedido del usuario: "el doble-tap para transferencia rápida" — el
## primer toque sigue mostrando el detalle como siempre (tocada.emit); si
## llega un segundo toque dentro de _VENTANA_DOBLE_TAP_MS, además dispara
## la transferencia. _transferencia_rapida() va AL FINAL: puede terminar
## reconstruyendo grilla_dueña entera (remove_child+queue_free, ver
## GrillaObjetos.notificar_cambio) y destruir este "self" en el camino —
## mismo cuidado que _drop_data, nada de self después de esa llamada.
func _procesar_tap() -> void:
	tocada.emit(item_data)
	var ahora := Time.get_ticks_msec()
	var es_doble_tap := ahora - _ultimo_tap_msec <= _VENTANA_DOBLE_TAP_MS
	_ultimo_tap_msec = -1000000 if es_doble_tap else ahora
	if es_doble_tap:
		_transferencia_rapida()


## Manda item_data a grilla_dueña.grilla_destino_rapida — la MISMA lógica
## que ya usa el arrastre (recibir_desde ya decide si hace falta preguntar
## la cantidad con PopupCantidad, ver GrillaObjetos). Sin destino
## configurado (grilla suelta, sin contraparte armada por su panel) no
## hace nada.
func _transferencia_rapida() -> void:
	if item_data == null or grilla_dueña == null or grilla_dueña.grilla_destino_rapida == null:
		return
	grilla_dueña.grilla_destino_rapida.recibir_desde(fuente, grilla_dueña, item_data)


func _actualizar_visual() -> void:
	if item_data:
		$Icon.texture = item_data.icon
		$QuantityLabel.text = str(item_data.quantity) if item_data.quantity > 1 else ""
		$QuantityLabel.visible = true
	else:
		$Icon.texture = null
		$QuantityLabel.text = ""
		$QuantityLabel.visible = false


func _get_drag_data(_at_position):
	_arrastrando = true
	if item_data == null:
		return null
	_arrastrando_ahora = self

	var size_icon := Vector2(32, 32)
	var wrapper := Control.new()
	wrapper.custom_minimum_size = size_icon
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview := TextureRect.new()
	preview.texture = item_data.icon
	preview.expand = true
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = size_icon
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.position = -size_icon / 2

	wrapper.add_child(preview)
	set_drag_preview(wrapper)
	return self


## Acepta cualquier CasillaObjeto con ítem — el rechazo real (misma
## grilla = no hace nada) vive en GrillaObjetos.recibir_desde(), no acá:
## Control.mouse_filter (STOP por defecto) NO burbujea hacia el padre
## cuando el control bajo el cursor no implementa _can_drop_data en
## absoluto (equivale a "rechaza" — el mismo mecanismo ya documentado para
## el rechazo EXPLÍCITO, ver EquipoSlot.gd) — sin este override, soltar
## sobre CUALQUIER casilla (que cubre casi toda el área visible de la
## grilla) nunca llegaría al ScrollContainerObjetos de abajo.
func _can_drop_data(_at_position, data) -> bool:
	return data is CasillaObjeto and data.item_data != null


func _drop_data(_at_position, data) -> void:
	var origen: CasillaObjeto = data
	if origen.item_data == null or grilla_dueña == null:
		return
	grilla_dueña.recibir_desde(origen.fuente, origen.grilla_dueña, origen.item_data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _arrastrando_ahora == self:
		_arrastrando_ahora = null
