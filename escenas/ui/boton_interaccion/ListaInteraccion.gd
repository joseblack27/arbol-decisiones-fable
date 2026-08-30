extends PanelContainer
## Reemplaza al botón fijo de interacción de antes (mismo lugar en pantalla,
## junto al paginador de habilidades) — ahora puede mostrar UN botón (caso
## de siempre: un solo interactuable con una sola acción, tocarlo ejecuta
## directo, cero pasos nuevos) o una LISTA chica en el mismo lugar cuando
## hace falta elegir: pedido real del usuario, con dos cofres uno al lado
## del otro no había forma de elegir cuál abrir.
##
## A propósito NUNCA pasa por GestorUI ni cambia ningún modo — el jugador
## sigue moviéndose, usando habilidades y abriendo cualquier otro panel con
## esta lista en pantalla, igual que puede hacerlo hoy con el botón simple
## (pedido explícito del usuario: "no quiero que esto detenga el
## funcionamiento de las demás interfaces").
##
## No sabe nada de NPCs/cofres/árboles: solo consume lo que
## GestorInteraccion.cambio(items) transmite (nombre + acciones() de cada
## interactuable en rango). Raíz PanelContainer (en vez de VBoxContainer a
## secas, como al principio) — pedido del usuario: "no tiene fondo y solo se
## ve las letras y los bordes de los botones" — el estilo de fondo/borde ya
## viene del tema compartido (ver Mundo.tscn, PanelContainer/styles/panel en
## recursos/temas/tema.tres), la lista de botones de verdad vive en
## %Lista, adentro de un MarginContainer para el margen contra el borde.

## Un poco más chico que el tamaño por defecto del tema (12, ver
## recursos/temas/tema.tres) — acá el espacio es angosto y fijo (ver
## Mundo.tscn), no sobra lugar para el tamaño normal de un botón grande.
const _TAMANO_FUENTE := 10

@onready var _lista: VBoxContainer = %Lista
@onready var _etiqueta_nombre: Label = %EtiquetaNombre

var _items: Array[Dictionary] = []
## Índice en _items del objeto elegido en la lista de objetos — -1
## mientras se muestra esa lista (o cuando solo hay un objeto en rango, se
## salta directo a sus acciones sin pasar por una lista de un solo ítem).
var _objeto_elegido: int = -1


func _ready() -> void:
	visible = false
	GestorInteraccion.cambio.connect(_al_cambiar)


func _al_cambiar(items: Array[Dictionary]) -> void:
	_items = items
	_objeto_elegido = -1
	_reconstruir()


func _reconstruir() -> void:
	_limpiar()
	if _items.is_empty():
		visible = false
		return
	visible = true
	if _objeto_elegido == -1 and _items.size() == 1:
		_objeto_elegido = 0
	if _objeto_elegido == -1:
		_etiqueta_nombre.visible = false
		_mostrar_objetos()
	else:
		# Pedido del usuario: mostrar el nombre del objeto arriba SOLO
		# cuando ya se sabe cuál es — eligiéndolo de la lista, o directo si
		# era el único en rango. Mientras se ve la lista de objetos (elegir
		# entre varios) el label queda invisible: ahí el nombre de cada uno
		# ya está en su propio botón.
		_etiqueta_nombre.text = _items[_objeto_elegido]["nombre"]
		_etiqueta_nombre.visible = true
		_mostrar_acciones(_objeto_elegido)
	_ajustar_alto()


## El ancho de todo el panel queda FIJO a propósito (ver Mundo.tscn — pedido
## del usuario, para que no cambie de tamaño según el texto de turno), pero
## el alto sí tiene que acompañar cuántos botones hay en pantalla ahora
## mismo — sin esto, el fondo quedaría siempre con el alto de un solo botón
## y el resto de la lista se vería sin fondo por debajo/arriba.
##
## Pedido del usuario: que crezca hacia ARRIBA, no hacia abajo (el botón de
## paginador de habilidades queda justo debajo, no hay lugar ahí). "size.y =
## 0" (probado primero) no sirve para eso: Control.set_size() mantiene fija
## la posición actual (la esquina superior) y estira el alto nuevo hacia
## abajo desde ahí — exactamente al revés de lo que hace falta. En cambio,
## acá se fija directo offset_top a partir de offset_bottom (que sí queda
## fijo siempre, anclado a la esquina inferior derecha, ver Mundo.tscn) menos
## el alto real que necesita el contenido actual — así el borde de ABAJO
## nunca se mueve y el que sube/baja es el de ARRIBA.
func _ajustar_alto() -> void:
	offset_top = offset_bottom - get_combined_minimum_size().y


## Alto mínimo táctil (px) — el ancho queda en 0 (sin restricción propia):
## ya lo fija el panel que lo contiene (ver Mundo.tscn), acá solo hace falta
## garantizar que el botón no quede más bajo que esto con la fuente chica.
const _ALTO_MINIMO_BOTON := 30.0


## Botón con la fuente reducida del tema (ver _TAMANO_FUENTE) y truncado con
## "..." en vez de desbordar — así el ancho de la lista se mantiene fijo
## (ver Mundo.tscn) sin importar qué tan largo sea el nombre/acción de turno.
func _crear_boton(texto: String) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(0, _ALTO_MINIMO_BOTON)
	boton.add_theme_font_size_override("font_size", _TAMANO_FUENTE)
	boton.clip_text = true
	boton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return boton


## 2+ objetos en rango: un botón por objeto (su nombre) — tocar uno pasa a
## sus acciones, en este MISMO lugar.
func _mostrar_objetos() -> void:
	for i in _items.size():
		var boton := _crear_boton(_items[i]["nombre"])
		boton.pressed.connect(_elegir_objeto.bind(i))
		_lista.add_child(boton)


## Acciones del objeto elegido — un botón por acción (su texto). Con un
## solo objeto en rango esto ES la lista completa (sin "Volver": no hay a
## dónde volver) y, si ese objeto tiene una sola acción, se ve y se
## comporta EXACTAMENTE como el botón único de siempre — el caso simple no
## quedó forzado a pasar por ningún paso nuevo, solo es una lista de UN
## botón. Sin ícono en "Volver" (pedido del usuario: satura el poco espacio
## disponible) — solo el texto, como cualquier otro botón de la lista.
func _mostrar_acciones(indice: int) -> void:
	var acciones: Array = _items[indice]["acciones"]
	for accion in acciones:
		var boton := _crear_boton(accion["texto"])
		boton.pressed.connect(_ejecutar_accion.bind(accion["callback"]))
		_lista.add_child(boton)
	if _items.size() > 1:
		var volver := _crear_boton("Volver")
		volver.pressed.connect(_volver_a_objetos)
		_lista.add_child(volver)


func _elegir_objeto(indice: int) -> void:
	_objeto_elegido = indice
	_reconstruir()


func _volver_a_objetos() -> void:
	_objeto_elegido = -1
	_reconstruir()


func _ejecutar_accion(callback: Callable) -> void:
	callback.call()
	# Vuelve a la vista inicial (objetos, o directo a acciones si sigue
	# habiendo uno solo) para el próximo toque — GestorInteraccion no
	# necesariamente dispara "cambio" de nuevo solo porque se ejecutó una
	# acción (el objeto puede seguir en rango, ej. un cofre que se puede
	# volver a abrir).
	_objeto_elegido = -1
	_reconstruir()


## remove_child() inmediato + queue_free() diferido — nunca uno solo (mismo
## motivo que PanelDialogo._limpiar_opciones(): un botón tocado sigue
## "locked" por su propia señal pressed en emisión, y esto puede correr
## dentro de _ejecutar_accion, en plena emisión de pressed).
func _limpiar() -> void:
	for hijo in _lista.get_children():
		_lista.remove_child(hijo)
		hijo.queue_free()
