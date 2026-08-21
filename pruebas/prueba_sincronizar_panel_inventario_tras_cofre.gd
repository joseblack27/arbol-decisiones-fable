# =============================================================================
# Bug real reportado: "cuando paso objetos del cofre al inventario, y luego
# miro el inventario del jugador, lo que haya hecho no se sincroniza acá
# [PanelInventario]". Causa: FuenteInventario.agregar()/quitar_cantidad()
# (ver ese archivo) siempre pasan silencioso=true a InventarioComponente —
# apaga BusEventos.item_agregado, la ÚNICA señal a la que escuchaba
# PanelInventario para refrescarse en caliente. Fix: BusEventos.
# inventario_cambiado, emitida SIEMPRE (sin importar silencioso) desde
# InventarioComponente.agregar_item/quitar_item/quitar_cantidad —
# PanelInventario ahora también la escucha (refrescar_diferido()).
#
# Instancia PanelCofre Y PanelInventario REALES a la vez (los dos abiertos,
# como estarían si el jugador mira el inventario del OS mientras el cofre
# sigue abierto atrás) y arrastra a través de PanelCofre — sin llamar a
# PanelInventario.refrescar() a mano en ningún momento, que sería trampa.
#   godot --headless --path . --script res://pruebas/prueba_sincronizar_panel_inventario_tras_cofre.gd
# =============================================================================
extends SceneTree

const _ID_COFRE := "cofre_sincronizar_panel_de_prueba"

var _jugador
var _inventario
var _cofres
var _panel_cofre
var _panel_inventario

var _cofre_a_inventario_sincroniza_ok := false
var _inventario_a_cofre_sincroniza_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_cofre_a_inventario_sincroniza_panel_inventario()
	_probar_inventario_a_cofre_sincroniza_panel_inventario()
	return _informar()


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_inventario = _jugador.get_node("InventarioComponente")
	_cofres = _jugador.get_node("CofresComponente")

	var datos := DatosCofre.new()
	datos.id = _ID_COFRE
	datos.capacidad = 8
	var gestor_cofres := root.get_node("/root/GestorCofres")
	gestor_cofres.catalogo.append(datos)
	_cofres.obtener_contenido(_ID_COFRE)  # arranca vacío.

	var pocion := load("res://recursos/items/consumibles/pocion_vida.tres") as DatosItem
	_inventario.agregar_item(pocion, 1, true)

	_panel_cofre = (load("res://escenas/ui/panel_cofre/PanelCofre.tscn") as PackedScene).instantiate()
	root.add_child(_panel_cofre)
	_panel_inventario = (load("res://escenas/ui/panel_os/paneles/inventario/PanelInventario.tscn") as PackedScene).instantiate()
	root.add_child(_panel_inventario)

	root.get_node("/root/BusEventos").cofre_solicitado.emit(_ID_COFRE, "Cofre de Prueba")


func _slot_en_panel_inventario(nombre: String) -> SlotItem:
	for slot: SlotItem in _panel_inventario.flow.get_children():
		if slot.item_data and slot.item_data.name == nombre:
			return slot
	return null


## Siembra la hoja DIRECTO en el cofre (sin arrastre, no es lo que se
## prueba acá) y la pasa al inventario a través de PanelCofre real —
## PanelInventario (ya abierto, mostrando la grilla vieja) debe reflejarla
## SOLO — nunca se llama a _panel_inventario.refrescar() a mano acá.
## hoja_1.tres tiene quantity=3 (>1): el arrastre abre PopupCantidad (ver
## GrillaObjetos.recibir_desde) — hay que confirmarlo con el máximo por
## defecto para que la transferencia se complete de verdad.
func _probar_cofre_a_inventario_sincroniza_panel_inventario() -> void:
	var hoja := load("res://recursos/items/recursos/hoja_1.tres") as DatosItem
	_cofres.agregar(_ID_COFRE, hoja)
	_panel_cofre._grilla_cofre.notificar_cambio()

	print("Antes de mover, PanelInventario no tiene la hoja (esperado true): %s" % \
		(_slot_en_panel_inventario("Hoja Verde") == null))
	var arranca_sin_hoja_ok: bool = _slot_en_panel_inventario("Hoja Verde") == null

	var origen = null
	for casilla in _panel_cofre._grilla_cofre._contenedor.get_children():
		if casilla.item_data and casilla.item_data.name == "Hoja Verde":
			origen = casilla
			break
	var scroll_inventario = _panel_cofre._grilla_jugador.get_node("%ScrollContainer")
	scroll_inventario._drop_data(Vector2.ZERO, origen)
	if _panel_cofre._grilla_jugador._popup_cantidad.visible:
		_panel_cofre._grilla_jugador._popup_cantidad._aceptar()

	print("Tras mover del cofre al inventario, PanelInventario la muestra SOLO, sin refrescar a mano (esperado true): %s" % \
		(_slot_en_panel_inventario("Hoja Verde") != null))
	var se_sincroniza_ok: bool = _slot_en_panel_inventario("Hoja Verde") != null

	_cofre_a_inventario_sincroniza_ok = arranca_sin_hoja_ok and se_sincroniza_ok


## Camino inverso: pasar la poción del inventario al cofre debe hacerla
## DESAPARECER de PanelInventario sin llamar a refrescar() a mano.
func _probar_inventario_a_cofre_sincroniza_panel_inventario() -> void:
	print("Antes de mover, PanelInventario tiene la poción (esperado true): %s" % \
		(_slot_en_panel_inventario("Poción de Vida") != null))
	var arranca_con_pocion_ok: bool = _slot_en_panel_inventario("Poción de Vida") != null

	var origen = null
	for casilla in _panel_cofre._grilla_jugador._contenedor.get_children():
		if casilla.item_data and casilla.item_data.name == "Poción de Vida":
			origen = casilla
			break
	var scroll_cofre = _panel_cofre._grilla_cofre.get_node("%ScrollContainer")
	scroll_cofre._drop_data(Vector2.ZERO, origen)

	print("Tras mover del inventario al cofre, PanelInventario ya no la tiene, sin refrescar a mano (esperado true): %s" % \
		(_slot_en_panel_inventario("Poción de Vida") == null))
	var se_sincroniza_ok: bool = _slot_en_panel_inventario("Poción de Vida") == null

	_inventario_a_cofre_sincroniza_ok = arranca_con_pocion_ok and se_sincroniza_ok


func _informar() -> bool:
	var exito := _cofre_a_inventario_sincroniza_ok and _inventario_a_cofre_sincroniza_ok
	print("  cofre -> inventario sincroniza PanelInventario abierto: %s" % _cofre_a_inventario_sincroniza_ok)
	print("  inventario -> cofre sincroniza PanelInventario abierto: %s" % _inventario_a_cofre_sincroniza_ok)
	print("PRUEBA SINCRONIZAR PANEL INVENTARIO TRAS COFRE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
