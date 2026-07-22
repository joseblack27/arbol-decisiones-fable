# =============================================================================
# Prueba de la Fase 4 del plan de multijugador: el botín/XP de un mob deben
# ir a quien de verdad lo mató, no "al primer jugador de la escena" (que
# era el comportamiento de GestorInventario/GestorExperiencia antes de este
# fix — incorrecto en cuanto hay más de un jugador conectado).
#
# Arma DOS jugadores en el grupo "jugadores" (JugadorA primero en el árbol,
# JugadorB segundo — así, si el bug siguiera vivo, el botín caería en A por
# ser "el primero", aunque quien atacó fue B). Solo B ataca al mob.
#   godot --headless --path . --script res://pruebas/prueba_loot_atacante_correcto.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jugador_a: Node
var _jugador_b: Node
var _raton: Node
var _pocion: DatosItem


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			# Solo B ataca: simula lo que haría una habilidad real al pegarle
			# al ratón (emitir daño_aplicado con "fuente" = quien atacó).
			var bus := root.get_node("/root/BusEventos")
			bus.daño_aplicado.emit(_raton, 10.0, _jugador_b, 2, false)
			var vida := _raton.get_node("VidaComponente")
			vida.quitar_vida(9999.0)
		3:
			return _informar()
	return false


func _montar() -> void:
	var gestor_inv := root.get_node("/root/GestorInventario")
	var gestor_xp := root.get_node("/root/GestorExperiencia")
	gestor_inv.items.clear()
	gestor_xp.xp_total = 0

	_jugador_a = _crear_jugador_de_prueba()
	root.add_child(_jugador_a)  # primero en el árbol → "el primero del grupo"

	_jugador_b = _crear_jugador_de_prueba()
	root.add_child(_jugador_b)  # segundo — el que de verdad va a atacar

	_raton = (load("res://escenas/enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	root.add_child(_raton)
	_pocion = DatosItem.new()
	_pocion.name = "Loot de Prueba Fase4"
	_pocion.type = 2  # CONSUMIBLE
	var gota := LootDrop.new()
	gota.item = _pocion
	gota.probabilidad = 1.0
	var tabla: Array[LootDrop] = [gota]
	_raton.tabla_botin = tabla
	_raton.xp_otorgada = 9


func _crear_jugador_de_prueba() -> Node:
	var jugador := CharacterBody2D.new()
	jugador.add_to_group("jugadores")
	var inventario: Variant = (load("res://componentes/InventarioComponente.gd") as GDScript).new()
	inventario.name = "InventarioComponente"
	jugador.add_child(inventario)
	var experiencia: Variant = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	experiencia.name = "ExperienciaComponente"
	jugador.add_child(experiencia)
	return jugador


func _informar() -> bool:
	var inv_a: Variant = _jugador_a.get_node("InventarioComponente")
	var inv_b: Variant = _jugador_b.get_node("InventarioComponente")
	var xp_a: int = _jugador_a.get_node("ExperienciaComponente").xp_total
	var xp_b: int = _jugador_b.get_node("ExperienciaComponente").xp_total

	var a_no_recibio_nada: bool = inv_a.items.is_empty() and xp_a == 0
	var b_recibio_el_item: bool = false
	for i in inv_b.items:
		if i.name == _pocion.name:
			b_recibio_el_item = true
	var b_recibio_xp: bool = xp_b == 9

	print("Jugador A (no atacó) sin botín ni XP (esperado true): %s (items=%d xp=%d)" % [a_no_recibio_nada, inv_a.items.size(), xp_a])
	print("Jugador B (sí atacó) recibió el ítem (esperado true): %s" % b_recibio_el_item)
	print("Jugador B (sí atacó) recibió la XP (esperado 9): %s (xp=%d)" % [b_recibio_xp, xp_b])

	var exito := a_no_recibio_nada and b_recibio_el_item and b_recibio_xp
	print("PRUEBA LOOT ATACANTE CORRECTO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
