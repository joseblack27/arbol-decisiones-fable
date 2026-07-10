# =============================================================================
# Prueba de la Fase 1 del plan de migración a multijugador: el estado de
# inventario/XP/equipo debe salir del InventarioComponente/ExperienciaComponente/
# EquipoComponente colgados del Jugador REAL (Jugador.tscn), no de un
# almacenamiento propio del autoload — y los autoloads (GestorInventario,
# GestorExperiencia, GestorEquipo) deben seguir funcionando como fachada
# transparente hacia esos componentes para todo el código que ya los usaba.
#   godot --headless --path . --script res://pruebas/prueba_componentes_por_jugador.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jugador: Node
var _pocion: DatosItem


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)

	var gestor_inv := root.get_node("/root/GestorInventario")
	var gestor_xp := root.get_node("/root/GestorExperiencia")

	_pocion = DatosItem.new()
	_pocion.name = "Poción de Prueba Fase1"
	_pocion.type = 2  # CONSUMABLE

	gestor_inv.agregar_item(_pocion, 5)
	gestor_xp.agregar_xp(12)


func _informar() -> bool:
	var componente_inv := _jugador.get_node("InventarioComponente")
	var componente_xp := _jugador.get_node("ExperienciaComponente")

	var esta_en_componente := false
	for i in componente_inv.items:
		if i.name == _pocion.name and i.quantity == 5:
			esta_en_componente = true

	var xp_en_componente: int = componente_xp.xp_total
	var gestor_inv := root.get_node("/root/GestorInventario")
	var xp_via_fachada: int = root.get_node("/root/GestorExperiencia").xp_total
	var items_via_fachada: Array = gestor_inv.items

	print("El ítem quedó en InventarioComponente del jugador real (esperado true): %s" % esta_en_componente)
	print("XP en ExperienciaComponente del jugador real (esperado 12): %d" % xp_en_componente)
	print("La fachada GestorExperiencia.xp_total ve lo mismo (esperado 12): %d" % xp_via_fachada)
	var misma_lista: bool = items_via_fachada == componente_inv.items
	print("La fachada GestorInventario.items es LA MISMA lista que la del componente (esperado true): %s" % misma_lista)

	var exito: bool = esta_en_componente and xp_en_componente == 12 and xp_via_fachada == 12 \
		and misma_lista
	print("PRUEBA COMPONENTES POR JUGADOR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
