# =============================================================================
# Prueba del sistema de botín (GestorInventario / EnemigoDatos.tabla_botin):
#   1. GestorInventario.agregar_item() añade una entrada nueva la primera vez.
#   2. Un ítem NO equipable (consumible/recurso) se apila con el existente en
#      vez de crear una segunda entrada (mismo nombre + tipo).
#   3. Un ítem equipable NUNCA se apila: cada vez crea una entrada nueva.
#   4. Al morir un enemigo con tabla_botin (probabilidad 1.0 = garantizado),
#      el ítem termina en GestorInventario — nunca queda tirado en el suelo
#      (no se instancia nada en la escena aparte del propio mob).
#   godot --headless --path . --script res://pruebas/prueba_loot.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _gestor: Node
var _item_consumible: DatosItem
var _item_equipable: DatosItem
var _raton: Node
var _hijos_antes_morir := 0
var _stack_ok := false
var _no_stack_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		10:
			# Matar de un golpe; ya debería haber repartido el botín antes de
			# empezar el desvanecido.
			var vida := _raton.get_node("VidaComponente")
			vida.quitar_vida(9999.0)
		11:
			return _informar()
	return false


func _montar() -> void:
	_gestor = root.get_node("/root/GestorInventario")
	_gestor.items.clear()

	_item_consumible = DatosItem.new()
	_item_consumible.name = "Poción"
	_item_consumible.type = 2  # CONSUMIBLE
	_item_consumible.quantity = 1

	_item_equipable = DatosItem.new()
	_item_equipable.name = "Espada"
	_item_equipable.type = 3  # EQUIPABLE
	_item_equipable.quantity = 1

	# --- Apilado de consumibles ---
	_gestor.agregar_item(_item_consumible)
	_gestor.agregar_item(_item_consumible)
	print("Consumibles apilados en una sola entrada (esperado 1 entrada, cantidad 2): %d entradas, cantidad=%d" % [
		_contar_entradas("Poción"), _obtener_cantidad("Poción"),
	])

	_stack_ok = _contar_entradas("Poción") == 1 and _obtener_cantidad("Poción") == 2

	# --- Equipables nunca se apilan ---
	_gestor.agregar_item(_item_equipable)
	_gestor.agregar_item(_item_equipable)
	print("Equipables NO se apilan (esperado 2 entradas): %d" % _contar_entradas("Espada"))
	_no_stack_ok = _contar_entradas("Espada") == 2

	_gestor.items.clear()

	# --- Botín real al morir un mob ---
	var escena := (load("res://escenas/enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	_raton = escena

	var entrada := LootDrop.new()
	entrada.item = _item_consumible
	entrada.probabilidad = 1.0
	var tabla: Array[LootDrop] = [entrada]
	_raton.tabla_botin = tabla

	_hijos_antes_morir = root.get_child_count()


func _contar_entradas(nombre: String) -> int:
	var cuenta := 0
	for i: DatosItem in _gestor.items:
		if i.name == nombre:
			cuenta += 1
	return cuenta


func _obtener_cantidad(nombre: String) -> int:
	for i: DatosItem in _gestor.items:
		if i.name == nombre:
			return i.quantity
	return 0


func _informar() -> bool:
	var botin_llego := _contar_entradas("Poción") >= 1  # limpiado antes de morir; reapareció por la muerte
	var sin_instancias_extra := root.get_child_count() == _hijos_antes_morir  # el ratón sigue vivo (fade), nada más se añadió
	print("Botín del enemigo llegó al inventario tras morir (esperado true): %s" % botin_llego)
	print("Nada quedó tirado en la escena aparte del propio mob (esperado true): %s" % sin_instancias_extra)

	var exito := _stack_ok and _no_stack_ok and botin_llego and sin_instancias_extra
	print("PRUEBA LOOT %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
