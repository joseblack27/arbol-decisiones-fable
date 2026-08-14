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


func _process(_delta: float) -> bool:
	_montar()
	_probar_inventario_a_cofre()
	_probar_cofre_a_inventario()
	_probar_cofre_lleno_no_pierde_el_item()
	_probar_recurso_se_puede_arrastrar()
	_probar_casilla_a_casilla_misma_grilla_no_hace_nada()
	_probar_casilla_a_casilla_distinta_grilla_agrega()
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

	# Intenta meter un tercero (la hoja, que sigue en el inventario) — debe
	# rechazarse sin que la hoja desaparezca de ningún lado.
	var origen = _casilla_con(_grilla_inventario, "Hoja Verde")
	var scroll_cofre = _grilla_cofre.get_node("%ScrollContainer")
	scroll_cofre._drop_data(Vector2.ZERO, origen)

	print("El cofre lleno sigue con 2 ítems, no aceptó el tercero (esperado 2): %d" % \
		_cofres.obtener_contenido(_ID_COFRE).size())
	print("La hoja sigue en el inventario, no se perdió (esperado 1): %d" % _cantidad_en_inventario("Hoja Verde"))
	_cofre_lleno_no_pierde_el_item_ok = _cofres.obtener_contenido(_ID_COFRE).size() == 2 \
		and _cantidad_en_inventario("Hoja Verde") == 1


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
## uno para hacer lugar (directo, no es lo que se prueba acá).
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

	print("Soltar sobre una casilla de OTRA grilla sí agrega (esperado 0 en inventario): %d" % \
		_cantidad_en_inventario("Poción de Vida"))
	print("... y entra al cofre (esperado true): %s" % (item_real in _cofres.obtener_contenido(_ID_COFRE)))
	_casilla_distinta_grilla_agrega_ok = _cantidad_en_inventario("Poción de Vida") == 0 \
		and item_real in _cofres.obtener_contenido(_ID_COFRE)


func _informar() -> bool:
	var exito := _inventario_a_cofre_ok and _cofre_a_inventario_ok \
		and _cofre_lleno_no_pierde_el_item_ok and _recurso_se_puede_arrastrar_ok \
		and _casilla_misma_grilla_no_hace_nada_ok and _casilla_distinta_grilla_agrega_ok
	print("  inventario -> cofre (vía ScrollContainer): %s" % _inventario_a_cofre_ok)
	print("  cofre -> inventario (vía ScrollContainer): %s" % _cofre_a_inventario_ok)
	print("  cofre lleno no pierde el ítem: %s" % _cofre_lleno_no_pierde_el_item_ok)
	print("  un ítem de Recursos se puede arrastrar: %s" % _recurso_se_puede_arrastrar_ok)
	print("  casilla a casilla, misma grilla, no hace nada: %s" % _casilla_misma_grilla_no_hace_nada_ok)
	print("  casilla a casilla, distinta grilla, agrega: %s" % _casilla_distinta_grilla_agrega_ok)
	print("PRUEBA CASILLA OBJETO ARRASTRE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
