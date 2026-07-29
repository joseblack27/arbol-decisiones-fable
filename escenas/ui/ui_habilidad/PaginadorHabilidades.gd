extends Button
class_name PaginadorHabilidades
## Botón "1/2" que cambia de página del HUD de habilidades: reasigna qué
## slot_index (0..total_slots-1) representa cada uno de los botones físicos
## en pantalla (ver UIHabilidad.cambiar_slot). Puramente de presentación —
## SlotHabilidades no tiene concepto de "página", solo un array plano de
## slots; acá solo se decide qué tramo de ese array se muestra ahora.

## Cuántos slots por página — debe coincidir con la cantidad de botones
## físicos en pantalla (ver "rutas_botones" abajo).
const POR_PAGINA := 5

## Rutas (relativas a este nodo) a los N botones físicos que controla, en
## orden — asignar en el Inspector. Array[NodePath] en vez de Array[Node]
## a propósito: Godot no resuelve arrays de referencias a nodo solas, hay
## que buscarlas a mano en _ready() (ver "botones" abajo, ya resuelto).
@export var rutas_botones: Array[NodePath] = []
## SlotHabilidades.total_slots / POR_PAGINA, redondeado hacia arriba.
@export var total_paginas: int = 2

var botones: Array[UIHabilidad] = []
var _pagina_actual := 0


func _ready() -> void:
	for ruta in rutas_botones:
		var boton := get_node_or_null(ruta) as UIHabilidad
		if boton:
			botones.append(boton)
	# Cada botón físico i va a representar los slots i, i+POR_PAGINA,
	# i+2*POR_PAGINA... a lo largo de las páginas — registrar TODOS esos
	# índices de una (ver UIHabilidad.registrar_indices_adicionales), no
	# solo el de la página inicial: Jugador/IndicadorApunte escuchan los
	# total_slots completos desde que aparecen, sin esperar a que alguien
	# visite cada página primero.
	for i in botones.size():
		var indices := []
		for pagina in total_paginas:
			indices.append(pagina * POR_PAGINA + i)
		botones[i].registrar_indices_adicionales(indices)
	_actualizar_texto()


## Toque crudo en vez de la señal pressed del Button: pressed depende del
## "mouse emulado desde touch", que en Android SOLO sigue al PRIMER dedo —
## con el joystick de movimiento sostenido, un segundo dedo sobre este botón
## no hacía nada (reportado). Manejando InputEventScreenTouch directo,
## cualquier dedo funciona (mismo enfoque que UIHabilidad/Joystick). En
## escritorio sigue andando igual: emulate_touch_from_mouse=true (ver
## project.godot) convierte el clic en un toque sintético que entra por acá.
## set_input_as_handled() evita que el Button además dispare pressed con el
## primer dedo (doble cambio de página).
func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch) or not event.pressed:
		return
	if not get_global_rect().has_point(event.position):
		return
	get_viewport().set_input_as_handled()
	_siguiente_pagina()


func _siguiente_pagina() -> void:
	_pagina_actual = (_pagina_actual + 1) % maxi(1, total_paginas)
	for i in botones.size():
		if is_instance_valid(botones[i]):
			botones[i].cambiar_slot(_pagina_actual * POR_PAGINA + i)
	_actualizar_texto()


func _actualizar_texto() -> void:
	# Solo el número de la página actual (antes "1/2") — pedido del usuario.
	text = str(_pagina_actual + 1)
