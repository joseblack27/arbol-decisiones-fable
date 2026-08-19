# =============================================================================
# Prueba de CasillaObjeto + ScrollContainerObjetos + FuenteObjetos — el
# arrastre genérico entre dos colecciones, a través de GrillaObjetos reales
# (hace falta: ScrollContainerObjetos._drop_data usa "owner" para encontrar
# su GrillaObjetos dueña, y "owner" solo se arma bien para nodos que vienen
# de una escena instanciada de verdad, no de .new() suelto). Mismo criterio
# que el resto de la suite: llama _can_drop_data/_drop_data DIRECTO sobre
# el ScrollContainer (ver el comentario grande en
# prueba_inventario_reemplazar_por_arrastre.gd) — pedido del usuario:
# "quien debe recibir el arrastre no son los otros slots, debe ser el
# scroll container".
#
# Cubre:
#   1. Inventario -> cofre (vía el ScrollContainer del cofre): sale de
#      GestorInventario, entra al cofre.
#   2. Cofre -> inventario (vía el ScrollContainer del inventario): sale
#      del cofre, entra a GestorInventario (silencioso).
#   3. Cofre LLENO rechaza el drop SIN perder el ítem — sigue en el
#      origen, no desaparece. Encontrado diseñando esto: agregar() puede
#      fallar (capacidad), y si quitar() del origen corriera ANTES de
#      confirmar que el destino aceptó, el ítem se perdería sin entrar a
#      ningún lado — ver el orden en ScrollContainerObjetos._drop_data.
#   4. Un ítem de categoría Recursos (can_equip=false, can_use=false, ej.
#      "Hoja Verde") sí arranca el arrastre — CasillaObjeto no filtra por
#      esos flags en absoluto (a diferencia de SlotItem).
#   5. Soltar sobre una casilla de la MISMA grilla no hace nada — pedido
#      del usuario: "no permite que si agarras un item y lo sueltas ahí
#      mismo, se añada de nuevo al final".
#   6. Soltar sobre una casilla de OTRA grilla sí agrega — pedido del
#      usuario: "que se pueda soltar encima de los mismos objetos... aunque
#      lo sueltes encima de otro CasillaObjeto, sea agregado siempre y
#      cuando la escena padre sea diferente". Necesario porque Control.
#      mouse_filter (STOP por defecto) no burbujea el rechazo hacia el
#      ScrollContainer si la casilla bajo el cursor no acepta el drop ella
#      misma — sin esto, soltar sobre CUALQUIER casilla (que cubre casi
#      toda el área visible) nunca llegaría a ningún lado.
#   godot --headless --path . --script res://pruebas/prueba_casilla_objeto_arrastre.gd
# =============================================================================
extends SceneTree

const _ID_COFRE := "cofre_casilla_de_prueba"
const _GRILLA_SCENE_PATH := "res://escenas/ui/comunes/grilla_objetos/GrillaObjetos.tscn"
const _CASILLA_SCENE_PATH := "res://escenas/ui/comunes/casilla_objeto/CasillaObjeto.tscn"
const _FUENTE_COFRE_SCRIPT_PATH := "res://escenas/ui/comunes/casilla_objeto/FuenteCofre.gd"
const _FUENTE_INVENTARIO_SCRIPT_PATH := "res://escenas/ui/comunes/casilla_objeto/FuenteInventario.gd"

var _jugador
var _cofres: CofresComponente
var _gestor_cofres: Node
var _gestor_inventario: Node
var _pocion: DatosItem
var _hoja: DatosItem

var _grilla_cofre
var _grilla_inventario

var _inventario_a_cofre_ok := false
var _cofre_a_inventario_ok := false
var _cofre_lleno_no_pierde_el_item_ok := false
var _recurso_se_puede_arrastrar_ok := false
var _casilla_misma_grilla_no_hace_nada_ok := false
var _casilla_distinta_grilla_agrega_ok := false
var _popup_cantidad_ok := false
var _filtro_categorias_ok := false
var _recurso_se_acumula_en_cofre_ok := false
var _ordenar_items_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_inventario_a_cofre()
	_probar_cofre_a_inventario()
	_probar_cofre_lleno_no_pierde_el_item()
	_probar_recurso_se_puede_arrastrar()
	_probar_casilla_a_casilla_misma_grilla_no_hace_nada()
	_probar_casilla_a_casilla_distinta_grilla_agrega()
	_probar_popup_cantidad_transferencia_parcial()
	_probar_filtro_categorias()
	_probar_recurso_se_acumula_en_cofre()
	_probar_ordenar_items()
	return _informar()


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_cofres = _jugador.get_node("CofresComponente")

	var datos := DatosCofre.new()
	datos.id = _ID_COFRE
	datos.capacidad = 2
	_gestor_cofres = root.get_node("/root/GestorCofres")
	_gestor_cofres.catalogo.append(datos)
	_cofres.obtener_contenido(_ID_COFRE)  # arranca vacío.

	_pocion = load("res://recursos/items/consumibles/pocion_vida.tres") as DatosItem
	_hoja = load("res://recursos/items/recursos/hoja_1.tres") as DatosItem
	_gestor_inventario = root.get_node("/root/GestorInventario")
	_gestor_inventario.items.clear()
	_gestor_inventario.agregar_item(_pocion, 1, true)
	_gestor_inventario.agregar_item(_hoja, 1, true)

	# Dos GrillaObjetos REALES (no sueltas): ScrollContainerObjetos._drop_
	# data usa "owner" para encontrar su GrillaObjetos dueña, y eso solo se
	# arma bien viniendo de una escena instanciada de verdad — ver el
	# comentario grande del archivo. Esto prueba solo el mecanismo de
	# arrastre; prueba_panel_cofre.gd cubre el panel entero armado igual
	# que en juego real.
	_grilla_cofre = load(_GRILLA_SCENE_PATH).instantiate()
	root.add_child(_grilla_cofre)
	var fuente_cofre = (load(_FUENTE_COFRE_SCRIPT_PATH) as GDScript).new()
	fuente_cofre.cofres = _cofres
	fuente_cofre.id_cofre = _ID_COFRE
	_grilla_cofre.poblar(func(): return _cofres.obtener_contenido(_ID_COFRE), fuente_cofre)

	_grilla_inventario = load(_GRILLA_SCENE_PATH).instantiate()
	root.add_child(_grilla_inventario)
	var fuente_inventario = (load(_FUENTE_INVENTARIO_SCRIPT_PATH) as GDScript).new()
	_grilla_inventario.poblar(func(): return _gestor_inventario.items, fuente_inventario)


func _cantidad_en_inventario(nombre: String) -> int:
	var total := 0
	for item: DatosItem in _gestor_inventario.items:
		if item.name == nombre:
			total += 1
	return total


func _casilla_con(grilla, nombre: String):
	var contenedor = grilla.find_child("Contenedor", true, false)
	for casilla in contenedor.get_children():
		if casilla.item_data and casilla.item_data.name == nombre:
			return casilla
	return null


func _probar_inventario_a_cofre() -> void:
	var origen = _casilla_con(_grilla_inventario, "Poción de Vida")
	var item_real_en_inventario: DatosItem = origen.item_data
	var scroll_cofre = _grilla_cofre.get_node("%ScrollContainer")

	var acepta: bool = scroll_cofre._can_drop_data(Vector2.ZERO, origen)
	scroll_cofre._drop_data(Vector2.ZERO, origen)

	print("El ScrollContainer del cofre acepta un ítem del inventario (esperado true): %s" % acepta)
	print("La poción sale de GestorInventario (esperado 0): %d" % _cantidad_en_inventario("Poción de Vida"))
	print("La poción entra al cofre, la MISMA instancia que salió del inventario (esperado true): %s" % \
		(item_real_en_inventario in _cofres.obtener_contenido(_ID_COFRE)))
	_inventario_a_cofre_ok = acepta and _cantidad_en_inventario("Poción de Vida") == 0 \
		and item_real_en_inventario in _cofres.obtener_contenido(_ID_COFRE)


func _probar_cofre_a_inventario() -> void:
	var origen = _casilla_con(_grilla_cofre, "Poción de Vida")  # entró en el paso anterior.
	var scroll_inventario = _grilla_inventario.get_node("%ScrollContainer")

	var acepta: bool = scroll_inventario._can_drop_data(Vector2.ZERO, origen)
	scroll_inventario._drop_data(Vector2.ZERO, origen)

	print("El ScrollContainer del inventario acepta un ítem del cofre (esperado true): %s" % acepta)
	print("La poción vuelve al inventario (esperado 1): %d" % _cantidad_en_inventario("Poción de Vida"))
	print("La poción sale del cofre (esperado false): %s" % (_pocion in _cofres.obtener_contenido(_ID_COFRE)))
	_cofre_a_inventario_ok = acepta and _cantidad_en_inventario("Poción de Vida") == 1 \
		and not (_pocion in _cofres.obtener_contenido(_ID_COFRE))


func _probar_cofre_lleno_no_pierde_el_item() -> void:
	# Capacidad=2, el cofre está vacío en este punto — lo llena con 2
	# ítems directo (sin arrastre, no es lo que se prueba acá).
	_cofres.agregar(_ID_COFRE, _pocion)
	_cofres.agregar(_ID_COFRE, _hoja)
	_grilla_cofre.notificar_cambio()

	# Intenta meter un TERCER ítem DISTINTO (una batería, no otra hoja: el
	# cofre ya tiene una entrada "Hoja Verde", y desde el fix de fusión de
	# agregar() — bug real reportado: "si paso dos veces el mismo recurso,
	# se crean 2 slots diferentes en vez de acumularse" — una segunda hoja
	# se FUSIONARÍA con la que ya está en vez de chocar contra la
	# capacidad. Acá se prueba específicamente el rechazo por capacidad
	# real, con un ítem sin ninguna entrada existente para fusionar) —
	# debe rechazarse sin que desaparezca de ningún lado.
	var bateria := load("res://recursos/items/recursos/bateria_1.tres") as DatosItem
	_gestor_inventario.agregar_item(bateria, 1, true)
	_grilla_inventario.notificar_cambio()

	var origen = _casilla_con(_grilla_inventario, bateria.name)
	var scroll_cofre = _grilla_cofre.get_node("%ScrollContainer")
	scroll_cofre._drop_data(Vector2.ZERO, origen)

	print("El cofre lleno sigue con 2 ítems, no aceptó el tercero (esperado 2): %d" % \
		_cofres.obtener_contenido(_ID_COFRE).size())
	print("La batería sigue en el inventario, no se perdió (esperado 1): %d" % \
		_cantidad_en_inventario(bateria.name))
	_cofre_lleno_no_pierde_el_item_ok = _cofres.obtener_contenido(_ID_COFRE).size() == 2 \
		and _cantidad_en_inventario(bateria.name) == 1


## Llama _get_drag_data() DIRECTO (no hay otra forma de probar esto sin un
## arrastre real de mouse) — Godot loguea "ERROR: Condition '!get_viewport
## ()->gui_is_dragging()' is true" desde set_drag_preview(), esperable:
## esa función asume un arrastre interactivo real en curso, que acá no
## hay. No afecta el resultado (_get_drag_data sigue devolviendo "self"
## con normalidad) — mismo tipo de limitación ya documentada para
## gui_is_drag_successful() en prueba_inventario_reemplazar_por_arrastre.gd.
func _probar_recurso_se_puede_arrastrar() -> void:
	var casilla = load(_CASILLA_SCENE_PATH).instantiate()
	root.add_child(casilla)
	casilla.item_data = _hoja
	var datos = casilla._get_drag_data(Vector2.ZERO)
	print("Un ítem de categoría Recursos (can_equip=false, can_use=false) sí arranca el arrastre (esperado true): %s" % \
		(datos != null))
	_recurso_se_puede_arrastrar_ok = datos != null


## En este punto (tras _probar_cofre_lleno_no_pierde_el_item) el inventario
## quedó vacío (poción y hoja terminaron en el cofre) — agrega dos ítems
## nuevos directo para tener DOS casillas en la MISMA grilla de inventario.
func _probar_casilla_a_casilla_misma_grilla_no_hace_nada() -> void:
	_gestor_inventario.agregar_item(_pocion, 1, true)
	_gestor_inventario.agregar_item(_hoja, 1, true)
	_grilla_inventario.notificar_cambio()

	var origen = _casilla_con(_grilla_inventario, "Poción de Vida")
	var destino = _casilla_con(_grilla_inventario, "Hoja Verde")  # MISMA grilla que origen.
	destino._drop_data(Vector2.ZERO, origen)

	print("Soltar sobre una casilla de la MISMA grilla no hace nada (esperado 1 poción, 1 hoja): %d, %d" % [
		_cantidad_en_inventario("Poción de Vida"), _cantidad_en_inventario("Hoja Verde")
	])
	_casilla_misma_grilla_no_hace_nada_ok = _cantidad_en_inventario("Poción de Vida") == 1 \
		and _cantidad_en_inventario("Hoja Verde") == 1


## El cofre sigue lleno (2/2, poción+hoja) desde el paso anterior — saca
## uno para hacer lugar (directo, no es lo que se prueba acá). La poción
## del inventario llegó a quantity=2 en el paso anterior (agregar_item()
## fusionó con la que ya había ahí) — soltarla sobre OTRA grilla dispara
## PopupCantidad (ver GrillaObjetos.recibir_desde), así que hace falta
## confirmarlo (con el valor por defecto, el stack entero) para que la
## transferencia se complete de verdad.
func _probar_casilla_a_casilla_distinta_grilla_agrega() -> void:
	_cofres.quitar(_ID_COFRE, _pocion)
	_grilla_cofre.notificar_cambio()

	var origen = _casilla_con(_grilla_inventario, "Poción de Vida")
	# La COPIA real que agregar_item() guardó (nunca es "== _pocion": ese
	# es el .tres original cargado de disco — agregar_item() SIEMPRE
	# duplica antes de guardar, mismo motivo que otras pruebas de esta
	# sesión). Se captura ANTES del drop.
	var item_real: DatosItem = origen.item_data
	var destino_cofre = _grilla_cofre.find_child("Contenedor", true, false).get_child(0)  # OTRA grilla que origen.
	destino_cofre._drop_data(Vector2.ZERO, origen)
	if _grilla_cofre._popup_cantidad.visible:
		_grilla_cofre._popup_cantidad._aceptar()  # confirma el máximo (default de abrir()).

	print("Soltar sobre una casilla de OTRA grilla sí agrega (esperado 0 en inventario): %d" % \
		_cantidad_en_inventario("Poción de Vida"))
	print("... y entra al cofre (esperado true): %s" % (item_real in _cofres.obtener_contenido(_ID_COFRE)))
	_casilla_distinta_grilla_agrega_ok = _cantidad_en_inventario("Poción de Vida") == 0 \
		and item_real in _cofres.obtener_contenido(_ID_COFRE)


## Pedido del usuario: "que me deje elegir cuantos quiero pasar" — arma un
## stack de 5 hojas SOLO para esta prueba (limpia inventario/cofre antes,
## así queda aislado de lo que dejaron las pruebas anteriores) y cubre: el
## popup se abre en vez de mover directo, Cancelar no mueve nada, y MIN+"+"
## +"+" (1, 2, 3) confirmado con Aceptar mueve solo esa cantidad — el resto
## se queda en el inventario, en la MISMA instancia (ver FuenteObjetos, el
## origen nunca se duplica, solo se le resta "quantity").
func _probar_popup_cantidad_transferencia_parcial() -> void:
	_gestor_inventario.items.clear()
	var vacio: Array[DatosItem] = []
	_cofres.contenidos[_ID_COFRE] = vacio

	var hoja_stack := _hoja.duplicate() as DatosItem
	hoja_stack.quantity = 5
	_gestor_inventario.items.append(hoja_stack)
	_grilla_inventario.notificar_cambio()
	_grilla_cofre.notificar_cambio()

	var origen = _casilla_con(_grilla_inventario, "Hoja Verde")
	var scroll_cofre = _grilla_cofre.get_node("%ScrollContainer")
	var popup: PopupCantidad = _grilla_cofre._popup_cantidad

	scroll_cofre._drop_data(Vector2.ZERO, origen)
	print("Arrastrar un stack >1 abre PopupCantidad en vez de mover directo (esperado true): %s" % popup.visible)
	var popup_abre_ok: bool = popup.visible

	popup._cancelar()
	print("Cancelar deja todo intacto (esperado 5 en inventario, 0 en cofre): %d, %d" % [
		hoja_stack.quantity, _cofres.obtener_contenido(_ID_COFRE).size()
	])
	var cancelar_no_mueve_ok: bool = hoja_stack in _gestor_inventario.items \
		and hoja_stack.quantity == 5 and _cofres.obtener_contenido(_ID_COFRE).size() == 0

	scroll_cofre._drop_data(Vector2.ZERO, origen)
	popup._boton_min.pressed.emit()
	popup._boton_mas.pressed.emit()
	popup._boton_mas.pressed.emit()  # MIN(1) + "+" + "+" = 3.
	popup._boton_aceptar.pressed.emit()

	var contenido_cofre := _cofres.obtener_contenido(_ID_COFRE)
	print("Cofre recibe solo la cantidad parcial elegida (esperado 3): %d" % \
		(contenido_cofre[0].quantity if contenido_cofre.size() > 0 else -1))
	print("El resto se queda en el inventario, MISMA instancia (esperado 2): %d" % \
		(hoja_stack.quantity if hoja_stack in _gestor_inventario.items else -1))
	var parcial_ok: bool = contenido_cofre.size() == 1 and contenido_cofre[0].quantity == 3 \
		and hoja_stack in _gestor_inventario.items and hoja_stack.quantity == 2

	# Pedido del usuario: "un cuadro de texto donde si se desea se coloque
	# el numero manualmente" — escribe "1" a mano (sin tocar +/-/MIN/MAX,
	# quedan 2 en el stack) y confirma con Enter (text_submitted), como en
	# un teclado táctil real. La entrada existente del cofre (quantity=3,
	# mismo nombre/tipo) fusiona el nuevo 1 → 4 (ver CofresComponente
	# .agregar_cantidad).
	scroll_cofre._drop_data(Vector2.ZERO, origen)
	popup._valor_input.text = "1"
	popup._valor_input.text_submitted.emit("1")
	popup._boton_aceptar.pressed.emit()

	contenido_cofre = _cofres.obtener_contenido(_ID_COFRE)
	print("Cuadro de texto manual mueve la cantidad tipeada (esperado 4): %d" % \
		(contenido_cofre[0].quantity if contenido_cofre.size() > 0 else -1))
	print("El resto se queda en el inventario (esperado 1): %d" % \
		(hoja_stack.quantity if hoja_stack in _gestor_inventario.items else -1))
	var texto_manual_ok: bool = contenido_cofre.size() == 1 and contenido_cofre[0].quantity == 4 \
		and hoja_stack in _gestor_inventario.items and hoja_stack.quantity == 1

	_popup_cantidad_ok = popup_abre_ok and cancelar_no_mueve_ok and parcial_ok and texto_manual_ok


## Pedido del usuario: "filtros como lo del inventario por categoría de
## objetos... parametrizable por un booleano para quitarlo o ponerlo".
## Apagado por defecto: TabsFiltro invisible y la grilla muestra TODO sin
## importar el tipo. Encendido (mostrar_filtro_categorias = true): aparece
## la fila de tabs y tocar una categoría reconstruye la grilla mostrando
## solo esa (misma lógica que FlujoItems.gd/PanelTienda, pero acá se
## filtra la LISTA antes de instanciar casillas en vez de esconder slots
## ya creados, porque GrillaObjetos ya reconstruye entera en cada cambio).
func _probar_filtro_categorias() -> void:
	_gestor_inventario.items.clear()
	var accesorio := load("res://recursos/items/equipables/accesorio_1.tres") as DatosItem
	_gestor_inventario.agregar_item(_pocion, 1, true)
	_gestor_inventario.agregar_item(_hoja, 1, true)
	_gestor_inventario.agregar_item(accesorio, -1, true)
	_grilla_inventario.notificar_cambio()

	print("Apagado por defecto: TabsFiltro invisible (esperado true): %s" % \
		(not _grilla_inventario._tabs_filtro.visible))
	print("... y muestra los 3 ítems sin filtrar (esperado 3): %d" % \
		_grilla_inventario._contenedor.get_child_count())
	var apagado_no_filtra_ok: bool = not _grilla_inventario._tabs_filtro.visible \
		and _grilla_inventario._contenedor.get_child_count() == 3

	_grilla_inventario.mostrar_filtro_categorias = true
	print("Encendido: TabsFiltro visible (esperado true): %s" % _grilla_inventario._tabs_filtro.visible)
	var tabs_visibles_ok: bool = _grilla_inventario._tabs_filtro.visible

	# Orden de _botones_filtro == _TIPOS_FILTRO: Todos, Equipables,
	# Consumibles, Recursos (índice 2 = Consumibles, 0 = Todos).
	_grilla_inventario._botones_filtro[2].pressed.emit()
	print("Filtro 'Consumibles' deja solo la poción (esperado 1): %d" % \
		_grilla_inventario._contenedor.get_child_count())
	var filtro_consumibles_ok: bool = _grilla_inventario._contenedor.get_child_count() == 1 \
		and _grilla_inventario._contenedor.get_child(0).item_data.name == "Poción de Vida"

	_grilla_inventario._botones_filtro[0].pressed.emit()
	print("Volver a 'Todos' muestra los 3 de nuevo (esperado 3): %d" % \
		_grilla_inventario._contenedor.get_child_count())
	var vuelve_a_todos_ok: bool = _grilla_inventario._contenedor.get_child_count() == 3

	_filtro_categorias_ok = apagado_no_filtra_ok and tabs_visibles_ok \
		and filtro_consumibles_ok and vuelve_a_todos_ok


## Bug real reportado: "cuando paso un recurso del inventario al cofre, si
## paso dos veces el mismo recurso, se crean 2 slots diferentes... quiero
## que en el del cofre también se acumule" — arrastra la MISMA hoja al
## cofre dos veces seguidas (cada vez, un ítem NUEVO recolectado en el
## inventario, no la misma instancia arrastrada de vuelta) y verifica que
## el cofre termine con UNA sola entrada de quantity=2, no dos entradas de
## quantity=1 (ver el fix de fusión en CofresComponente.agregar()).
func _probar_recurso_se_acumula_en_cofre() -> void:
	_gestor_inventario.items.clear()
	var vacio: Array[DatosItem] = []
	_cofres.contenidos[_ID_COFRE] = vacio

	var scroll_cofre = _grilla_cofre.get_node("%ScrollContainer")

	_gestor_inventario.agregar_item(_hoja, 1, true)
	_grilla_inventario.notificar_cambio()
	scroll_cofre._drop_data(Vector2.ZERO, _casilla_con(_grilla_inventario, "Hoja Verde"))

	_gestor_inventario.agregar_item(_hoja, 1, true)
	_grilla_inventario.notificar_cambio()
	scroll_cofre._drop_data(Vector2.ZERO, _casilla_con(_grilla_inventario, "Hoja Verde"))

	var contenido_cofre := _cofres.obtener_contenido(_ID_COFRE)
	print("El cofre acumula las 2 hojas en UNA sola entrada (esperado 1 entrada): %d" % contenido_cofre.size())
	print("... con quantity = 2 (esperado 2): %d" % \
		(contenido_cofre[0].quantity if contenido_cofre.size() > 0 else -1))
	_recurso_se_acumula_en_cofre_ok = contenido_cofre.size() == 1 and contenido_cofre[0].quantity == 2


## Pedido del usuario: "organizar los ítems por orden alfabético de las
## categorías ascendente y descendente, orden alfabético ascendente y
## descendente [por nombre]" — la categoría es Enums.Inventario.
## TipoItemEquipable (el slot real: casco, amuleto...), no el TipoItem
## genérico, y "los recursos van al final" (cualquier ítem sin slot —
## consumibles, recursos — queda siempre después de los equipables, sin
## importar la dirección). 2 equipables de slot distinto + 2 sin slot,
## nombres todos distintos, para que las 4 combinaciones den un orden
## inequívoco.
func _probar_ordenar_items() -> void:
	_gestor_inventario.items.clear()
	var anillo := load("res://recursos/items/equipables/accesorio_1.tres") as DatosItem  # AMULETO
	var armadura := load("res://recursos/items/equipables/armadura_1.tres") as DatosItem  # CASCO
	var hoja := load("res://recursos/items/recursos/hoja_1.tres") as DatosItem  # sin slot
	var pocion := load("res://recursos/items/consumibles/pocion_vida.tres") as DatosItem  # sin slot
	_gestor_inventario.agregar_item(anillo, -1, true)
	_gestor_inventario.agregar_item(armadura, -1, true)
	_gestor_inventario.agregar_item(hoja, 1, true)
	_gestor_inventario.agregar_item(pocion, 1, true)

	_grilla_inventario.mostrar_ordenar = true
	_grilla_inventario.notificar_cambio()

	var casos := [
		[GrillaObjetos.OrdenItems.CATEGORIA_ASC, ["Anillo Sencillo", "Armadura Ligera", "Hoja Verde", "Poción de Vida"]],
		[GrillaObjetos.OrdenItems.CATEGORIA_DESC, ["Armadura Ligera", "Anillo Sencillo", "Hoja Verde", "Poción de Vida"]],
		[GrillaObjetos.OrdenItems.NOMBRE_ASC, ["Anillo Sencillo", "Armadura Ligera", "Hoja Verde", "Poción de Vida"]],
		[GrillaObjetos.OrdenItems.NOMBRE_DESC, ["Poción de Vida", "Hoja Verde", "Armadura Ligera", "Anillo Sencillo"]],
	]

	var todo_ok := true
	for caso in casos:
		var orden: GrillaObjetos.OrdenItems = caso[0]
		var esperado: Array = caso[1]
		_grilla_inventario._on_orden_seleccionado(orden)
		var real: Array = []
		for c in _grilla_inventario._contenedor.get_children():
			real.append(c.item_data.name)
		print("Orden %d da %s (esperado %s)" % [orden, real, esperado])
		if real != esperado:
			todo_ok = false

	_ordenar_items_ok = todo_ok


func _informar() -> bool:
	var exito := _inventario_a_cofre_ok and _cofre_a_inventario_ok \
		and _cofre_lleno_no_pierde_el_item_ok and _recurso_se_puede_arrastrar_ok \
		and _casilla_misma_grilla_no_hace_nada_ok and _casilla_distinta_grilla_agrega_ok \
		and _popup_cantidad_ok and _filtro_categorias_ok and _recurso_se_acumula_en_cofre_ok \
		and _ordenar_items_ok
	print("  inventario -> cofre (vía ScrollContainer): %s" % _inventario_a_cofre_ok)
	print("  cofre -> inventario (vía ScrollContainer): %s" % _cofre_a_inventario_ok)
	print("  cofre lleno no pierde el ítem: %s" % _cofre_lleno_no_pierde_el_item_ok)
	print("  un ítem de Recursos se puede arrastrar: %s" % _recurso_se_puede_arrastrar_ok)
	print("  casilla a casilla, misma grilla, no hace nada: %s" % _casilla_misma_grilla_no_hace_nada_ok)
	print("  casilla a casilla, distinta grilla, agrega: %s" % _casilla_distinta_grilla_agrega_ok)
	print("  PopupCantidad: abre, cancela, transfiere parcial: %s" % _popup_cantidad_ok)
	print("  filtro de categorías: apagado no filtra, encendido sí: %s" % _filtro_categorias_ok)
	print("  recurso repetido se acumula en el cofre: %s" % _recurso_se_acumula_en_cofre_ok)
	print("  ordenar por categoría/nombre asc/desc: %s" % _ordenar_items_ok)
	print("PRUEBA CASILLA OBJETO ARRASTRE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
